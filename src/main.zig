const std = @import("std");
const long = @import("long.zig");

pub fn main() !void {
    var num: u64 = undefined;
    _ = try long.read(u64, &num, &[_]u8{ 0b10010110, 0b1, 0b1 });

    var buf: [2]u8 = undefined;
    try long.write(u64, num, &buf);

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
