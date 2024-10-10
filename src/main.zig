const std = @import("std");
const long = @import("long.zig");

pub fn main() !void {
    const l = try long.read(i64, &[_]u8{ 0b10010110, 0b1, 0b1 });

    var buf: [2]u8 = undefined;
    try long.write(i64, l, &buf);

    const str: []const u8 =
        \\long:
        \\  {}
        \\  {x}
        \\  {b}
    ;

    std.debug.print(str, .{l, buf, buf});
}

fn encode(n: i64) i64 {
    return (n << 1) ^ (n >> 63);
}

test encode {
    try std.testing.expectEqual(0, encode(0));
    try std.testing.expectEqual(1, encode(-1));
    try std.testing.expectEqual(2, encode(1));
    try std.testing.expectEqual(3, encode(-2));
    try std.testing.expectEqual(4, encode(2));
    try std.testing.expectEqual(4294967294, encode(2147483647));
    try std.testing.expectEqual(4294967293, encode(-2147483647));

    try std.testing.expectEqual(2, encode(std.mem.readVarInt(i64, &[_]u8{1}, .little)));
    try std.testing.expectEqual(4, encode(std.mem.readVarInt(i64, &[_]u8{2}, .little)));
}

fn decode(n: i64) i64 {
    return (n >> 1) ^ (-(n & 1));
}

test decode {
    try std.testing.expectEqual(0, decode(0));
    try std.testing.expectEqual(-1, decode(1));
    try std.testing.expectEqual(1, decode(2));
    try std.testing.expectEqual(-2, decode(3));
    try std.testing.expectEqual(2, decode(4));
    try std.testing.expectEqual(3, decode(6));
    try std.testing.expectEqual(3, decode(0x6));
    try std.testing.expectEqual(2147483647, decode(4294967294));
    try std.testing.expectEqual(-2147483647, decode(4294967293));

    try std.testing.expectEqual(-1, decode(std.mem.readVarInt(i64, &[_]u8{1}, .little)));
    try std.testing.expectEqual(1, decode(std.mem.readVarInt(i64, &[_]u8{2}, .little)));
}
