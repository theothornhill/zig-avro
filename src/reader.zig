const std = @import("std");
const long = @import("long.zig");
const float = @import("float.zig");
const string = @import("string.zig");

pub const ReadError = error{
    UninitializedOrSpentIterator,
    UnionIdOutOfBounds,
    UnexpectedEndOfBuffer,
};

pub fn Float() type {
    return struct {
        v: f32 = 0.0,
        pub fn consume(self: *Float(), buf: []const u8) ![]const u8 {
            return try float.read(f32, &self.v, buf);
        }
    };
}

pub fn Double() type {
    return struct {
        v: f64 = 0.0,
        pub fn consume(self: *Double(), buf: []const u8) ![]const u8 {
            return try float.read(f64, &self.v, buf);
        }
    };
}

pub fn Integer(comptime T: type) type {
    return struct {
        v: T = 0,
        pub fn consume(self: *Integer(T), buf: []const u8) ![]const u8 {
            return try long.read(T, &self.v, buf);
        }
    };
}

pub const String = struct {
    v: []const u8 = &.{},
    pub fn consume(self: *String, buf: []const u8) ![]const u8 {
        return try string.read(&self.v, buf);
    }
};

pub fn Enum(comptime T: type) type {
    return struct {
        v: T = undefined,
        pub fn consume(self: *@This(), buf: []const u8) ![]const u8 {
            var rem = buf;
            var enumId: u32 = undefined;
            rem = try long.read(u32, &enumId, rem);
            self.v = @enumFromInt(enumId);
            return rem;
        }
    };
}

test "parse enum from avro" {
    var e: Enum(enum {
        take,
        off,
        every,
        zig,
        move,
    }) = undefined;
    const buf = &[_]u8{
        4 << 1, // move
        3 << 1, // zig
        4 << 1, // move
        3 << 1, // zig
    };
    var rem = try e.consume(buf);
    try std.testing.expectEqual(.move, e.v);
    rem = try e.consume(rem);
    try std.testing.expectEqual(.zig, e.v);
    rem = try e.consume(rem);
    try std.testing.expectEqual(.move, e.v);
    rem = try e.consume(rem);
    try std.testing.expectEqual(.zig, e.v);
    try std.testing.expectEqual(0, rem.len);
}

pub fn Fixed(length: usize) type {
    return struct {
        v: []const u8 = undefined,
        pub fn consume(self: *@This(), buf: []const u8) ![]const u8 {
            if (buf.len < length)
                return ReadError.UnexpectedEndOfBuffer;
            self.v = buf[0..length];
            return buf[length..];
        }
    };
}

test "parse fixed from avro" {
    var e: Fixed(12) = undefined;
    _ = try e.consume("hello my good friend");
    try std.testing.expectEqualStrings("hello my goo", e.v);
}

test "parse fixed fail" {
    var e: Fixed(12) = undefined;
    try std.testing.expectError(ReadError.UnexpectedEndOfBuffer, e.consume("hello you"));
}

test "parse fixed 0 lol" {
    var e: Fixed(0) = undefined;
    const rem = try e.consume("untouched");
    try std.testing.expectEqualStrings("untouched", rem);
}

pub fn Record(comptime T: type) type {
    return struct {
        record: T = undefined,
        pub fn consume(self: *@This(), buf: []const u8) ![]const u8 {
            var rem = buf;
            inline for (
                std.meta.fields(T),
            ) |field| {
                rem = try @field(self.record, field.name).consume(rem);
            }
            return rem;
        }
    };
}

test "parse record from avro" {
    var s: Record(struct {
        title: String,
        count: Integer(i32),
        sum: Integer(i64),
    }) = undefined;
    const buf = &[_]u8{
        3 << 1, // title(len 3)
        'H',
        'A',
        'Y',
        0b10010110, // count: 15755
        0b11110110, // |
        0b00000001, // |
        0b10100111, // sum: -8468
        0b10000100, // |
        0b00000001, // |
    };
    const rem = try s.consume(buf);
    try std.testing.expectEqualStrings("HAY", s.record.title.v);
    try std.testing.expectEqual(-8468, s.record.sum.v);
    try std.testing.expectEqual(15755, s.record.count.v);
    try std.testing.expectEqual(0, rem.len);
}

pub fn Union(comptime T: type) type {
    return struct {
        type: T,
        pub fn consume(self: *@This(), buf: []const u8) ![]const u8 {
            var typeId: u32 = undefined;
            var rem = buf;
            rem = try long.read(u32, &typeId, buf);
            inline for (std.meta.fields(T), 0..) |field, id| {
                if (typeId == id) {
                    self.type = @unionInit(T, field.name, undefined);
                    if (field.type == void)
                        return rem;
                    return try @field(self.type, field.name).consume(rem);
                }
            }
            return ReadError.UnionIdOutOfBounds;
        }
    };
}

test "parse union" {
    var e: Union(union(enum) {
        number: Integer(i32),
        string: String,
        none,
    }) = undefined;
    const buf = &[_]u8{
        1 << 1, // enum 1: string
        1 << 1, // string length 1
        '!',
        // ---- next value in buffer:
        0, // enum 0: number
        3 << 1, // i32: 3
    };
    var rem: []const u8 = buf;
    rem = try e.consume(rem);
    try std.testing.expectEqual(2, rem.len);
    try std.testing.expectEqualStrings("!", e.type.string.v);
    rem = try e.consume(rem);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(3, e.type.number.v);
}

test "parse union with invalid enum" {
    var e: Union(union(enum) {
        none,
    }) = undefined;
    const buf = &[_]u8{
        1 << 1, // enum 1: invalid
    };
    try std.testing.expectError(ReadError.UnionIdOutOfBounds, e.consume(buf));
}

test "union over two enums" {
    var e: Union(union(enum) {
        wordsA: Enum(enum { enjoy, your, time }),
        wordsB: Enum(enum { make, a, coffee }),
    }) = undefined;
    const buf = &[_]u8{
        1 << 1, // wordsB
        0 << 1, // .make
        0 << 1, // wordsA
        1 << 1, // .your
        0 << 1, // wordsA
        2 << 1, // .time
    };
    var rem = try e.consume(buf);
    try std.testing.expectEqual(.make, e.type.wordsB.v);
    rem = try e.consume(rem);
    try std.testing.expectEqual(.your, e.type.wordsA.v);
    rem = try e.consume(rem);
    try std.testing.expectEqual(.time, e.type.wordsA.v);
    try std.testing.expectEqual(0, rem.len);
}

pub fn Array(comptime T: type) type {
    return struct {
        item: T = .{},
        len: usize = 0,
        currentBlockLen: usize = 0,
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
                self.restBuf = try long.read(usize, &self.currentBlockLen, self.restBuf);
            if (self.currentBlockLen == 0) {
                self.valid = false;
                return null;
            }
            self.currentBlockLen -= 1;
            self.restBuf = try self.item.consume(self.restBuf);
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
        pub fn consume(self: *Array(T), buf: []const u8) ![]const u8 {
            self.len = 0;
            self.restBuf = buf;
            self.currentBlockLen = 0;
            var blockItems: i64 = 0;
            var blockBytesLength: usize = 0;
            var rem: []const u8 = buf;
            while (true) {
                rem = try long.read(i64, &blockItems, rem);
                if (blockItems == 0) {
                    self.valid = true;
                    return rem;
                } else if (blockItems < 0) {
                    blockItems = -blockItems;
                    rem = try long.read(usize, &blockBytesLength, rem);
                    rem = rem[blockBytesLength..];
                } else {
                    for (0..@bitCast(blockItems)) |_|
                        rem = try self.item.consume(rem);
                }
                self.len += @bitCast(blockItems);
            }
        }
    };
}

test "array of double" {
    var a = Array(Double()){};
    const buf = &[_]u8{
        1 << 1, // array block length 1
        0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18, // 3.141592653589793115997963468544185161590576171875
        0, // array end
        '?', // stuff beyond the array
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(1, rem.len);
    try std.testing.expectEqual(1, a.len);
    const i = (try a.next()).?;
    try std.testing.expectEqual(3.141592653589793115997963468544185161590576171875, i.v);
    try std.testing.expectEqual(null, a.next());
}

test "array of float" {
    var a = Array(Float()){};
    const buf = &[_]u8{
        1 << 1, // array block length 1
        0x40, 0x49, 0x0F, 0xD8, // 3.141592
        0, // array end
        '?', // stuff beyond the array
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(1, rem.len);
    try std.testing.expectEqual(1, a.len);
    const i = (try a.next()).?;
    try std.testing.expectEqual(3.141592, i.v);
    try std.testing.expectEqual(null, a.next());
}

test "array of 1" {
    var a = Array(Integer(i64)){};
    const buf = &[_]u8{
        1 << 1, // array block length 1
        2 << 1, // number 2
        0, // array end
        '?', // stuff beyond the array
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(1, rem.len);
    try std.testing.expectEqual(1, a.len);
    const i = (try a.next()).?;
    try std.testing.expectEqual(2, i.v);
    try std.testing.expectEqual(null, a.next());
}

test "array of 2" {
    var a = Array(String){};
    const buf = &[_]u8{
        2 << 1, // array block length 2
        1 << 1, // string(len 1)
        'A',
        2 << 1, // string(len 2)
        'B',
        'C',
        0, // array end
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(2, a.len);
    var i = (try a.next()).?;
    try std.testing.expectEqualStrings("A", i.v);
    i = (try a.next()).?;
    try std.testing.expectEqualStrings("BC", i.v);
    try std.testing.expectEqual(null, a.next());
}

test "array of 2 in 2 blocks" {
    var a = Array(String){};
    const buf = &[_]u8{
        1 << 1, // array block#1 length 1
        1 << 1, // title(len 2)
        'A',
        1 << 1, // array block#2 length 1
        2 << 1, // title(len 2)
        'B',
        'C',
        0, // array end
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(2, a.len);
    var i = (try a.next()).?;
    try std.testing.expectEqualStrings("A", i.v);
    i = (try a.next()).?;
    try std.testing.expectEqualStrings("BC", i.v);
    try std.testing.expectEqual(null, a.next());
}

// Array blocks are purposefully given invalid data, as the array consume()
// should skip over them. They will only cause trouble once iterated over.
test "array with marked-length blocks" {
    var a = Array(String){};
    const buf = &[_]u8{
        (3 << 1) - 1, // block#1 size -3
        12 << 1, // block#1 byte length 12
        'I', 'N', 'V', 'A', 'L', 'I', 'D', ' ', 'D', 'A', 'T', 'A', // block#2 garbage data
        (13 << 1) - 1, // block#2 size -13
        0, // block#2 byte length 0
        0, // array end
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(16, a.len);
}

test "array of 0" {
    var a = Array(Integer(i64)){};
    const buf = &[_]u8{
        0, // array end
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(null, a.next());
}

test "incorrect usage" {
    var a = Array(Integer(i32)){};
    const buf = &[_]u8{
        0, // array end
    };
    try std.testing.expectError(ReadError.UninitializedOrSpentIterator, a.next());
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(null, a.next());
    try std.testing.expectError(ReadError.UninitializedOrSpentIterator, a.next());
}

// +-+-+
// |1|2|
// +-+-+
// |3|4|
// +-+-+
test "2d array" {
    var a = Array(Array(Integer(i32))){};
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
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(2, a.len);
    const row1 = (try a.next()).?;
    try std.testing.expectEqual(2, row1.len);
    var cell = (try row1.next()).?;
    try std.testing.expectEqual(1, cell.v);
    cell = (try row1.next()).?;
    try std.testing.expectEqual(2, cell.v);
    try std.testing.expectEqual(null, row1.next());
    const row2 = (try a.next()).?;
    try std.testing.expectEqual(2, row2.len);
    cell = (try row2.next()).?;
    try std.testing.expectEqual(3, cell.v);
    cell = (try row2.next()).?;
    try std.testing.expectEqual(4, cell.v);
    try std.testing.expectEqual(null, row2.next());
    try std.testing.expectEqual(null, a.next());
}

fn Map(comptime K: type, comptime V: type) type {
    const Entry = struct {
        key: K = undefined,
        value: V = undefined,
        pub fn consume(self: *@This(), buf: []const u8) ![]const u8 {
            const rem = try self.key.consume(buf);
            return try self.value.consume(rem);
        }
    };
    return Array(Entry);
}

test "map of 2" {
    var m: Map(Integer(i32), String) = undefined;
    const buf = &[_]u8{
        2 << 1, // array block length 2
        4 << 1, // number 4
        1 << 1, // string(len 1)
        'A',
        5 << 1, // number 5
        2 << 1, // string(len 2)
        'B',
        'C',
        0, // array end
    };
    _ = try m.consume(buf);
    try std.testing.expectEqual(2, m.len);
    var i = (try m.next()).?;
    try std.testing.expectEqual(4, i.key.v);
    try std.testing.expectEqualStrings("A", i.value.v);
    i = (try m.next()).?;
    try std.testing.expectEqual(5, i.key.v);
    try std.testing.expectEqualStrings("BC", i.value.v);
}
