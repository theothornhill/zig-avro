const std = @import("std");
const number = @import("number.zig");
const boolean = @import("bool.zig");
const string = @import("string.zig");

pub const ReadError = error{
    UninitializedOrSpentIterator,
    UnionIdOutOfBounds,
    UnexpectedEndOfBuffer,
};

pub fn consume(comptime T: type, v: *T, buf: []const u8) ![]const u8 {
    switch (T) {
        bool => return try boolean.read(v, buf),
        i32 => return try number.readInt(v, buf),
        []const u8 => return try string.read(v, buf),
        else => {
            if (@hasDecl(T, "consumeOwn"))
                return try v.consumeOwn(buf);
            return switch (@typeInfo(T)) {
                .@"struct" => try consumeRecord(T, v, buf),
                .@"union" => try consumeUnion(T, v, buf),
                else => @compileError("unsupported field type " ++ @typeName(T)),
            };
        },
    }
}

pub fn Array(comptime T: type) type {
    return struct {
        item: T = undefined,
        len: usize = 0,
        currentBlockLen: i64 = 0,
        restBuf: []const u8 = &.{},
        valid: bool = false,

        /// If there are remaining items in the array, consume the next and return it.
        /// Returns null if there are no remaining items.
        ///
        /// This iterator can only be used once.
        pub fn next(self: *Array(T)) !?*T {
            if (!self.valid)
                return ReadError.UninitializedOrSpentIterator;
            if (self.currentBlockLen == 0)
                self.restBuf = try number.readLong(&self.currentBlockLen, self.restBuf);
            if (self.currentBlockLen < 0) {
                var blockByteCount: i64 = undefined;
                self.currentBlockLen = -self.currentBlockLen;
                self.restBuf = try number.readLong(&blockByteCount, self.restBuf);
            }
            if (self.currentBlockLen == 0) {
                self.valid = false;
                return null;
            }
            self.currentBlockLen -= 1;
            self.restBuf = try consume(T, &self.item, self.restBuf);
            return &self.item;
        }
        /// Prepares an iterator an returns buffer after end of array.
        /// Total count of array items stored in self.len.
        ///
        /// Arrays contain 0 or more items arranged in 0 or more blocks.
        /// Each block is a varint `blockItems` describing the number of items in that block.
        ///
        /// Large blocks can additionally contain information about the block size in
        /// bytes allowing us to skip past it faster. This is signalled by having a negative
        /// `blockItems`, in which we should flip it to positive and read another varint
        /// describing the `blockBytesLength`.
        pub fn consumeOwn(self: *Array(T), buf: []const u8) ![]const u8 {
            self.len = 0;
            self.restBuf = buf;
            self.currentBlockLen = 0;
            var blockItems: i64 = 0;
            var blockBytesLength: i64 = 0;
            var rem: []const u8 = buf;
            while (true) {
                rem = try number.readLong(&blockItems, rem);
                if (blockItems == 0) {
                    self.valid = true;
                    return rem;
                } else if (blockItems < 0) {
                    blockItems = -blockItems;
                    rem = try number.readLong(&blockBytesLength, rem);
                    rem = rem[@bitCast(blockBytesLength)..];
                } else {
                    for (0..@bitCast(blockItems)) |_|
                        rem = try consume(T, &self.item, rem);
                }
                self.len += @bitCast(blockItems);
            }
        }
    };
}

test "consume array" {
    const buf = &[_]u8{
        1 << 1,
        0,
        0,
    };
    var a: Array(i32) = undefined;
    _ = try a.consumeOwn(buf);
}

pub fn consumeRecord(comptime R: type, r: *R, buf: []const u8) ![]const u8 {
    var rem = buf;
    inline for (@typeInfo(R).@"struct".fields) |field|
        rem = try consume(field.type, &@field(r, field.name), rem);
    return rem;
}

fn consumeUnion(comptime U: type, u: *U, buf: []const u8) ![]const u8 {
    var typeId: i32 = undefined;
    var rem = buf;
    rem = try number.readInt(&typeId, buf);
    inline for (std.meta.fields(U), 0..) |field, id| {
        if (typeId == id) {
            u.* = @unionInit(U, field.name, undefined);
            if (field.type == void)
                return rem;
            return try consume(field.type, &@field(u, field.name), rem);
        }
    }
    return ReadError.UnionIdOutOfBounds;
}

test "consume record" {
    const buf = &[_]u8{
        1, // valid: true
        2 << 1, // message:len 2
        'H',
        'I',
        1, // logged: true
        0, // terrible: false
        1 << 1, // items array: len 1
        5 << 1, // items[0] = 5
        0, // end of array
        0, // onion type: the i32 thing
        2 << 1, // onion.number = 2
    };
    const Record = struct {
        valid: bool,
        message: []const u8,
        flags: struct {
            logged: bool,
            terrible: bool,
        },
        items: Array(i32),
        onion: union(enum) {
            number: i32,
            none,
        },
    };
    var r: Record = undefined;
    const rem = try consume(Record, &r, buf);
    try std.testing.expectEqual(true, r.valid);
    try std.testing.expectEqualStrings("HI", r.message);
    try std.testing.expectEqual(true, r.flags.logged);
    try std.testing.expectEqual(false, r.flags.terrible);
    try std.testing.expectEqual(5, (try r.items.next()).?.*);
    try std.testing.expectEqual(2, r.onion.number);
    try std.testing.expectEqual(0, rem.len);
}
