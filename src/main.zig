const std = @import("std");
const number = @import("number.zig");

pub fn main() !void {
    var num: i64 = undefined;
    _ = try number.readLong(&num, &[_]u8{ 0b10010110, 0b1, 0b1 });

    var buf: [2]u8 = undefined;
    try number.writeLong(num, &buf);

    const str: []const u8 =
        \\long:
        \\  {}
        \\  {x}
        \\  {b}
    ;

    std.debug.print(str, .{ num, buf, buf });
}

test {
    std.testing.refAllDecls(@This());
}
