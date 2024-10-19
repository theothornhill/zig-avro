const std = @import("std");

pub const ReadFloatError = error{
    Overflow,
    InvalidEOF,
};

pub const WriteFloatError = error{
    Overflow,
};

pub fn read(comptime T: type, dst: *T, buf: []const u8) ![]const u8 {
    const U: type = switch (T) {
        f32 => u32,
        f64 => u64,
        else => @compileError("unsupported type: " ++ @typeName(T)),
    };

    if (buf.len < @sizeOf(U)) {
        return error.InvalidEOF;
    }

    var stream = std.io.fixedBufferStream(buf);
    dst.* = @bitCast(try stream.reader().readInt(U, .big));

    return buf[@sizeOf(U)..];
}

pub fn write(comptime T: type, value: T, buf: []u8) !void {
    const U: type = switch (T) {
        f32 => u32,
        f64 => u64,
        else => @compileError("unsupported type: " ++ @typeName(T)),
    };
    var stream = std.io.fixedBufferStream(buf);
    try stream.writer().writeInt(U, @bitCast(value), .big);
}

test read {
    var test_f32: f32 = undefined;

    const rem_f32 = try read(f32, &test_f32, &[_]u8{
        0x40, 0x49, 0x0F, 0xD8,
    });
    try std.testing.expectApproxEqRel(3.141592, test_f32, std.math.floatEps(f32));
    try std.testing.expectEqual(0, rem_f32.len);

    var test_f64: f64 = undefined;

    const rem_f64 = try read(f64, &test_f64, &[_]u8{
        0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18,
    });
    try std.testing.expectApproxEqRel(
        3.141592653589793115997963468544185161590576171875,
        test_f64,
        std.math.floatEps(f64),
    );
    try std.testing.expectEqual(0, rem_f64.len);
}

test write {
    var res = &[_]u8{
        0x40, 0x49, 0x0F, 0xD8,
    };

    var buf: [4]u8 = undefined;
    try write(f32, 3.141592, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    res = &[_]u8{
        0xC0, 0x49, 0x0F, 0xD8,
    };
    buf = undefined;
    try write(f32, -3.141592, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const res2 = &[_]u8{
        0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18,
    };

    var buf2: [8]u8 = undefined;
    try write(f64, 3.141592653589793115997963468544185161590576171875, &buf2);
    try std.testing.expectEqualSlices(u8, res2, &buf2);
}
