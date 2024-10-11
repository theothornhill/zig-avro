const std = @import("std");
const long = @import("long.zig");
const main = @import("main.zig");

const ExampleStruct = struct {
    count: i16 = 0,
    sum: i64 = 0,
    fn parse(self: *ExampleStruct, buf: []const u8) ![]const u8 {
        var rem = buf;
        rem = try long.read(i16, &self.count, rem);
        rem = try long.read(i64, &self.sum, rem);
        return rem;
    }
};

test "parse from avro" {
    var s = ExampleStruct{};
    const buf = &[_]u8{
        0b10010110,
        0b11110110,
        0b00000001,
        0b10100111,
        0b10000100,
        0b00000001,
    };
    const rem = try s.parse(buf);
    try std.testing.expectEqual(s.sum, -8468);
    try std.testing.expectEqual(s.count, 15755);
    try std.testing.expectEqual(rem.len, 0);
}
