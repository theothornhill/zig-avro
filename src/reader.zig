const std = @import("std");
const string = @import("string.zig");
const long = @import("long.zig");
const main = @import("main.zig");

const ReadRecordError = long.ReadLongError || string.ReadStringError;

const ReadArrayError = error{
    UninitializedOrSpentIterator,
} || ReadRecordError;

const ExampleStruct = struct {
    title: []u8 = &.{},
    count: i16 = 0,
    sum: i64 = 0,
    pub fn consume(self: *ExampleStruct, buf: []const u8) ReadRecordError![]const u8 {
        var rem = buf;
        rem = try string.read(&self.title, rem);
        rem = try long.read(i16, &self.count, rem);
        rem = try long.read(i64, &self.sum, rem);
        return rem;
    }
};

test "parse ExampleStruct from avro" {
    var s = ExampleStruct{};
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
    try std.testing.expectEqualStrings("HAY", s.title);
    try std.testing.expectEqual(-8468, s.sum);
    try std.testing.expectEqual(15755, s.count);
    try std.testing.expectEqual(0, rem.len);
}

const ArrayOfExampleStruct = struct {
    item: ExampleStruct = .{},
    len: usize = 0,
    currentBlockLen: usize = 0,
    restBuf: []const u8 = &.{},
    valid: bool = false,
    /// If there are remaining items in the array, consume the next and return it.
    /// Returns null if there are no remaining items.
    ///
    /// This iterator can only be used once.
    pub fn next(self: *ArrayOfExampleStruct) ReadArrayError!?*ExampleStruct {
        if (!self.valid) {
            return ReadArrayError.UninitializedOrSpentIterator;
        }
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
    pub fn consume(self: *ArrayOfExampleStruct, buf: []const u8) ReadArrayError![]const u8 {
        self.restBuf = buf;
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
                for (0..@bitCast(blockItems)) |_| {
                    rem = try self.item.consume(rem);
                }
            }
            self.len += @bitCast(blockItems);
        }
    }
};

test "array of 1" {
    var a = ArrayOfExampleStruct{};
    const buf = &[_]u8{
        1 << 1, // array block length 1
        2 << 1, // title(len 2)
        ':',
        ')',
        1 << 1, // count: 1
        2 << 1, // sum: 2
        0, // array end
        '?', // stuff beyond the array
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(1, rem.len);
    try std.testing.expectEqual(1, a.len);
    const s = try a.next() orelse unreachable;
    try std.testing.expectEqualStrings(":)", s.title);
    try std.testing.expectEqual(1, s.count);
    try std.testing.expectEqual(2, s.sum);
    try std.testing.expectEqual(null, a.next());
}

test "array of 2" {
    var a = ArrayOfExampleStruct{};
    const buf = &[_]u8{
        2 << 1, // array block length 2
        1 << 1, // title(len 2)
        'A',
        1 << 1, // count: 1
        2 << 1, // sum: 2
        2 << 1, // title(len 2)
        'B',
        'C',
        3 << 1, // count: 3
        4 << 1, // sum: 4
        0, // array end
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(2, a.len);
    var s = try a.next() orelse unreachable;
    try std.testing.expectEqualStrings("A", s.title);
    try std.testing.expectEqual(1, s.count);
    try std.testing.expectEqual(2, s.sum);
    s = try a.next() orelse unreachable;
    try std.testing.expectEqualStrings("BC", s.title);
    try std.testing.expectEqual(3, s.count);
    try std.testing.expectEqual(4, s.sum);
    try std.testing.expectEqual(null, a.next());
}

test "array of 2 in 2 blocks" {
    var a = ArrayOfExampleStruct{};
    const buf = &[_]u8{
        1 << 1, // array block#1 length 1
        1 << 1, // title(len 2)
        'A',
        1 << 1, // count: 1
        2 << 1, // sum: 2
        1 << 1, // array block#2 length 1
        2 << 1, // title(len 2)
        'B',
        'C',
        3 << 1, // count: 3
        4 << 1, // sum: 4
        0, // array end
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(2, a.len);
    var s = try a.next() orelse unreachable;
    try std.testing.expectEqualStrings("A", s.title);
    try std.testing.expectEqual(1, s.count);
    try std.testing.expectEqual(2, s.sum);
    s = try a.next() orelse unreachable;
    try std.testing.expectEqualStrings("BC", s.title);
    try std.testing.expectEqual(3, s.count);
    try std.testing.expectEqual(4, s.sum);
    try std.testing.expectEqual(null, a.next());
}

// Array blocks are purposefully given invalid data, as the array consume()
// should skip over them. They will only cause trouble once iterated over.
test "array with marked-length blocks" {
    var a = ArrayOfExampleStruct{};
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
    var a = ArrayOfExampleStruct{};
    const buf = &[_]u8{
        0, // array end
    };
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(null, a.next());
}

test "incorrect usage" {
    var a = ArrayOfExampleStruct{};
    const buf = &[_]u8{
        0, // array end
    };
    try std.testing.expectError(ReadArrayError.UninitializedOrSpentIterator, a.next());
    const rem = try a.consume(buf);
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqual(null, a.next());
    try std.testing.expectError(ReadArrayError.UninitializedOrSpentIterator, a.next());
}
