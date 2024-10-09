const std = @import("std");

pub fn main() !void {
    const l = readLong(i64, &[_]u8{ 0b10010110, 0b1, 0b1 });
    std.debug.print("long {}", .{l});
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

fn readLong(comptime T: type, in: []const u8) T {
    const shift_type = switch (@typeInfo(T).int.bits) {
        64 => u6,
        32 => u5,
        16 => u4,
        8 => u3,
        else => @compileError("type not supported"),
    };
    var res: T = 0;
    var shift: shift_type = 0;
    for (in[0..]) |b| {
        if (b & 0x80 == 0) {
            return @as(T, b & 0x7f) << shift | res;
        }

        res = @as(T, b & 0x7f) << shift | res;
        shift += 7;
    }

    return res;
}

test "read long" {
    // try std.testing.expectEqual(150, readLong(i16, &[_]u8{ 0b10010110, 0b10010110, 0b10010110, 0b10010110, 0b00000001, 0b1 }));
    try std.testing.expectEqual(150, readLong(i16, &[_]u8{ 0b10010110, 0b00000001, 0b1 }));

    try std.testing.expectEqual(150, readLong(i32, &[_]u8{ 0b10010110, 0b1, 0b1 }));

    try std.testing.expectEqual(150, readLong(i64, &[_]u8{ 0b10010110, 0b1, 0b1 }));

    const negativeTwo = readLong(i64, &[_]u8{
        0b11111110,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b00000001
    });

    try std.testing.expectEqual(-2, negativeTwo);

    try std.testing.expectEqual(3, encode(negativeTwo));
}
