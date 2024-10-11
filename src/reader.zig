const std = @import("std");
const string = @import("string.zig");
const long = @import("long.zig");
const main = @import("main.zig");

const ExampleStruct = struct {
    title: []u8 = &.{},
    count: i16 = 0,
    sum: i64 = 0,
    fn parse(self: *ExampleStruct, buf: []const u8) ![]const u8 {
        var rem = buf;
        rem = try string.read(&self.title, rem);
        rem = try long.read(i16, &self.count, rem);
        rem = try long.read(i64, &self.sum, rem);
        return rem;
    }
};

test "parse from avro" {
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
    const rem = try s.parse(buf);
    try std.testing.expectEqualStrings("HAY", s.title);
    try std.testing.expectEqual(-8468, s.sum);
    try std.testing.expectEqual(15755, s.count);
    try std.testing.expectEqual(0, rem.len);
}
