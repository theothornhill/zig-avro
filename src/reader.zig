const std = @import("std");
const number = @import("number.zig");
const boolean = @import("bool.zig");
const string = @import("string.zig");
const ReadError = @import("errors.zig").ReadError;

pub fn read(comptime T: type, v: *T, buf: []const u8) ![]const u8 {
    const n = try readAny(T, v, buf);
    return buf[n..];
}

pub fn readAny(comptime T: type, v: *T, buf: []const u8) !usize {
    switch (T) {
        bool => return try boolean.read(v, buf),
        i32 => return try number.readInt(v, buf),
        i64 => return try number.readLong(v, buf),
        f32 => return try number.readFloat(v, buf),
        f64 => return try number.readDouble(v, buf),
        []const u8 => return try string.read(v, buf),
        else => {
            switch (@typeInfo(T)) {
                .@"struct" => {
                    if (@hasDecl(T, "readOwn"))
                        return (try v.readOwn(buf));
                    return try readRecord(T, v, buf);
                },
                .@"enum" => return try readEnum(T, v, buf),
                .@"union" => return try readUnion(T, v, buf),
                .pointer => return try readFixed(v.*.len, v, buf),
                .optional => |opt| return try readOptional(opt.child, v, buf),
                else => {},
            }
            @compileError("unsupported field type " ++ @typeName(T));
        },
    }
}

pub fn readOptional(comptime T: type, v: *?T, buf: []const u8) !usize {
    if (buf.len < 1) {
        return error.UnexpectedEndOfBuffer;
    }
    if (buf[0] == 0) {
        v.* = null;
        return 1;
    }
    v.* = std.mem.zeroes(T);
    return 1 + try readAny(T, &(v.*.?), buf[1..]);
}

fn readEnum(comptime E: type, e: *E, buf: []const u8) !usize {
    var enumId: i32 = undefined;
    const n = try number.readInt(&enumId, buf);
    e.* = @enumFromInt(enumId);
    return n;
}

fn readFixed(len: comptime_int, tgt: **[len]u8, buf: []const u8) !usize {
    if (buf.len < len)
        return ReadError.UnexpectedEndOfBuffer;
    const fixedStart: *u8 = @constCast(&buf[0]);
    tgt.* = @ptrCast(fixedStart);
    return len;
}

fn readRecord(comptime R: type, r: *R, buf: []const u8) !usize {
    var n: usize = 0;
    inline for (@typeInfo(R).@"struct".fields) |field|
        n += try readAny(field.type, &@field(r, field.name), buf[n..]);
    return n;
}

fn readUnion(comptime U: type, u: *U, buf: []const u8) !usize {
    var typeId: i32 = undefined;
    const n = try number.readInt(&typeId, buf);
    inline for (std.meta.fields(U), 0..) |field, id| {
        if (typeId == id) {
            u.* = @unionInit(U, field.name, undefined);
            if (field.type == void)
                return n;
            return n + try readAny(field.type, &@field(u, field.name), buf[n..]);
        }
    }
    return ReadError.UnionIdOutOfBounds;
}

pub fn Array(comptime T: type) type {
    return struct {
        item: T = undefined,
        len: usize = 0,
        currentBlockLen: i64 = 0,
        restBuf: []const u8 = &.{},
        valid: bool = false,

        /// If there are remaining items in the array, read the next and return it.
        /// Returns null if there are no remaining items.
        ///
        /// This iterator can only be used once.
        pub fn next(self: *Array(T)) !?*T {
            if (!self.valid)
                return ReadError.UninitializedOrSpentIterator;
            if (self.currentBlockLen == 0) {
                const n = try number.readLong(&self.currentBlockLen, self.restBuf);
                self.restBuf = self.restBuf[n..];
            }
            if (self.currentBlockLen < 0) {
                var blockByteCount: i64 = undefined;
                self.currentBlockLen = -self.currentBlockLen;
                const n = try number.readLong(&blockByteCount, self.restBuf);
                self.restBuf = self.restBuf[n..];
            }
            if (self.currentBlockLen == 0) {
                self.valid = false;
                return null;
            }
            self.currentBlockLen -= 1;
            self.restBuf = self.restBuf[try readAny(T, &self.item, self.restBuf)..];
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
        pub fn readOwn(self: *Array(T), buf: []const u8) !usize {
            self.len = 0;
            self.restBuf = buf;
            self.currentBlockLen = 0;
            var blockItems: i64 = 0;
            var blockBytesLength: i64 = 0;
            var n: usize = 0;
            while (true) {
                n += try number.readLong(&blockItems, buf[n..]);
                if (blockItems == 0) {
                    self.valid = true;
                    return n;
                } else if (blockItems < 0) {
                    blockItems = -blockItems;
                    n += try number.readLong(&blockBytesLength, buf[n..]);
                    n += @intCast(blockBytesLength);
                } else {
                    for (0..@intCast(blockItems)) |_|
                        n += try readAny(T, &self.item, buf[n..]);
                }
                self.len += @intCast(blockItems);
            }
        }
    };
}

pub fn Entry(comptime V: type) type {
    return struct {
        key: []const u8 = undefined,
        value: V = undefined,
        pub fn readOwn(self: *@This(), buf: []const u8) !usize {
            const n = try readAny([]const u8, &self.key, buf);
            return n + try readAny(V, &self.value, buf[n..]);
        }
    };
}

pub fn Map(comptime V: type) type {
    return Array(Entry(V));
}

test "read array" {
    const buf = &[_]u8{
        1 << 1,
        0,
        0,
    };
    var a: Array(i32) = undefined;
    const n = try a.readOwn(buf);
    try std.testing.expectEqual(3, n);
}

// +-+-+
// |1|2|
// +-+-+
// |3|4|
// +-+-+
test "2d array" {
    var a = Array(Array(i32)){};
    const buf = &[_]u8{
        2 << 1, // 2 rows
        2 << 1, // 1st row: 2 columns
        1 << 1, // R1C1=1
        2 << 1, // R1C2=2
        0, // cols end
        2 << 1, // 2nd row: 2 columns
        3 << 1, // R2C1=3
        4 << 1, // R2C2=4
        0, // cols end
        0, // rows end
    };
    const rem = try read(Array(Array(i32)), &a, buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(2, a.len);
    const row1 = (try a.next()).?;
    try std.testing.expectEqual(2, row1.len);
    var cell = (try row1.next()).?.*;
    try std.testing.expectEqual(1, cell);
    cell = (try row1.next()).?.*;
    try std.testing.expectEqual(2, cell);
    try std.testing.expectEqual(null, row1.next());
    const row2 = (try a.next()).?;
    try std.testing.expectEqual(2, row2.len);
    cell = (try row2.next()).?.*;
    try std.testing.expectEqual(3, cell);
    cell = (try row2.next()).?.*;
    try std.testing.expectEqual(4, cell);
    try std.testing.expectEqual(null, row2.next());
    try std.testing.expectEqual(null, a.next());
}

test "map of 2" {
    var m: Map(i32) = undefined;
    const buf = &[_]u8{
        2 << 1, // array block length 2
        1 << 1, // string(len 1)
        'A',
        4 << 1, // number 4
        2 << 1, // string(len 2)
        'B',
        'C',
        5 << 1, // number 5
        0, // array end
    };
    _ = try read(Map(i32), &m, buf);
    try std.testing.expectEqual(2, m.len);
    var i = (try m.next()).?;
    try std.testing.expectEqual(4, i.value);
    try std.testing.expectEqualStrings("A", i.key);
    i = (try m.next()).?;
    try std.testing.expectEqual(5, i.value);
    try std.testing.expectEqualStrings("BC", i.key);
}

test "read record" {
    const buf = &[_]u8{
        0,
        0,
        1 << 1,
        1, // logged: true
        0, // terrible: false
        1 << 1, // items array: len 1
        5 << 1, // items[0] = 5
        0, // end of array
        0, // onion type: the i32 thing
        2 << 1, // onion.number = 2

        1 << 1,
        1, // valid: true
        1 << 1,
        2 << 1, // message:len 2
        'H',
        'I',
        0, // null record
        1 << 1, // items array: len 1
        5 << 1, // items[0] = 5
        0, // end of array
        0, // onion type: the i32 thing
        2 << 1, // onion.number = 2
    };
    const Record = struct {
        valid: ?i32,
        message: ?[]const u8,
        flags: ?struct {
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
    var rem = try read(Record, &r, buf);
    try std.testing.expectEqual(null, r.valid);
    try std.testing.expectEqual(null, r.message);
    try std.testing.expectEqual(true, r.flags.?.logged);
    try std.testing.expectEqual(false, r.flags.?.terrible);

    rem = try read(Record, &r, rem);
    try std.testing.expectEqual(-1, r.valid.?);

    try std.testing.expectEqualStrings("HI", r.message.?);
    try std.testing.expectEqual(null, r.flags);
    try std.testing.expectEqual(5, (try r.items.next()).?.*);
    try std.testing.expectEqual(2, r.onion.number);
    try std.testing.expectEqual(0, rem.len);
}

test "read fixed" {
    const buf = "Bonjourno";
    const Record = struct {
        fixed: *[7]u8,
    };
    var r: Record = undefined;
    const rem = try read(Record, &r, buf);
    try std.testing.expectEqual(2, rem.len);
    try std.testing.expectEqualStrings("Bonjour", (r.fixed.*)[0..7]);
}

test "assert fixed does not copy" {
    var origBuf: [9]u8 = undefined;
    @memcpy(&origBuf, "Bonjourno");
    var buf = origBuf[0..origBuf.len];

    const Record = struct {
        fixed: *[7]u8,
    };
    var r: Record = undefined;
    const rem = try read(Record, &r, buf);
    try std.testing.expectEqual(2, rem.len);
    try std.testing.expectEqualStrings("Bonjour", (r.fixed.*)[0..7]);
    buf[3] = 's';
    buf[5] = 'i';
    try std.testing.expectEqualStrings("Bonsoir", (r.fixed.*)[0..7]);
}

test "parse enum from avro" {
    const Gabber = enum {
        take,
        off,
        every,
        zig,
        move,
    };
    var e: Gabber = undefined;
    const buf = &[_]u8{
        4 << 1, // move
        3 << 1, // zig
        4 << 1, // move
        3 << 1, // zig
    };
    var rem = try read(Gabber, &e, buf);
    try std.testing.expectEqual(.move, e);
    rem = try read(Gabber, &e, rem);
    try std.testing.expectEqual(.zig, e);
    rem = try read(Gabber, &e, rem);
    try std.testing.expectEqual(.move, e);
    rem = try read(Gabber, &e, rem);
    try std.testing.expectEqual(.zig, e);
    try std.testing.expectEqual(0, rem.len);
}
