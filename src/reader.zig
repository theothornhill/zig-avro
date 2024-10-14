const std = @import("std");
const long = @import("long.zig");
const string = @import("string.zig");

pub const ReadError = error{
    UninitializedOrSpentIterator,
};

pub fn Number(comptime T: type) type {
    return struct {
        value: T = 0,
        pub fn consume(self: *Number(T), buf: []const u8) ![]const u8 {
            return try long.read(T, &self.value, buf);
        }
    };
}

pub const String = struct {
    value: []const u8 = &.{},
    pub fn consume(self: *String, buf: []const u8) ![]const u8 {
        return try string.read(&self.value, buf);
    }
};

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
            var blockItems: u64 = 0;
            var blockBytesLength: usize = 0;
            var rem: []const u8 = buf;
            while (true) {
                rem = try long.read(u64, &blockItems, rem);
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

test "array of 1" {
    var a = Array(Number(u64)){};
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
    try std.testing.expectEqual(2, i.value);
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
    try std.testing.expectEqualStrings("A", i.value);
    i = (try a.next()).?;
    try std.testing.expectEqualStrings("BC", i.value);
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
    try std.testing.expectEqualStrings("A", i.value);
    i = (try a.next()).?;
    try std.testing.expectEqualStrings("BC", i.value);
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
    var a = Array(Number(u64)){};
    const buf = &[_]u8{
        0, // array end
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(null, a.next());
}

test "incorrect usage" {
    var a = Array(Number(u32)){};
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
    var a = Array(Array(Number(u32))){};
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
    try std.testing.expectEqual(1, cell.value);
    cell = (try row1.next()).?;
    try std.testing.expectEqual(2, cell.value);
    try std.testing.expectEqual(null, row1.next());
    const row2 = (try a.next()).?;
    try std.testing.expectEqual(2, row2.len);
    cell = (try row2.next()).?;
    try std.testing.expectEqual(3, cell.value);
    cell = (try row2.next()).?;
    try std.testing.expectEqual(4, cell.value);
    try std.testing.expectEqual(null, row2.next());
    try std.testing.expectEqual(null, a.next());
}
