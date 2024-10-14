const std = @import("std");
const string = @import("string.zig");
const long = @import("long.zig");
const main = @import("main.zig");
const reader = @import("reader.zig");

const ExampleStruct = struct {
    title: reader.String = .{},
    count: reader.Number(i32) = .{},
    sum: reader.Number(i64) = .{},
    pub fn consume(self: *ExampleStruct, buf: []const u8) ![]const u8 {
        var rem = buf;
        rem = try self.title.consume(rem);
        rem = try self.count.consume(rem);
        rem = try self.sum.consume(rem);
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
    try std.testing.expectEqualStrings("HAY", s.title.value);
    try std.testing.expectEqual(-8468, s.sum.value);
    try std.testing.expectEqual(15755, s.count.value);
    try std.testing.expectEqual(0, rem.len);
}

test "array of 1 ExampleStruct" {
    var a = reader.Array(ExampleStruct){};
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
    try std.testing.expectEqualStrings(":)", s.title.value);
    try std.testing.expectEqual(1, s.count.value);
    try std.testing.expectEqual(2, s.sum.value);
    try std.testing.expectEqual(null, a.next());
}
