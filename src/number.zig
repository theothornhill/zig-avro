const std = @import("std");
const leb = std.leb;

pub const ReadLongError = error{
    Overflow,
    InvalidEOF,
};

pub const WriteLongError = error{
    Overflow,
};

pub fn readUint(dst: *u32, buf: []const u8) ![]const u8 {
    return readNumber(u32, dst, buf);
}

pub fn readInt(dst: *i32, buf: []const u8) ![]const u8 {
    return readNumber(i32, dst, buf);
}

pub fn readUlong(dst: *u64, buf: []const u8) ![]const u8 {
    return readNumber(u64, dst, buf);
}

pub fn readLong(dst: *i64, buf: []const u8) ![]const u8 {
    return readNumber(i64, dst, buf);
}

pub fn writeUint(value: u32, buf: []u8) !void {
    return writeNumber(u32, value, buf);
}

pub fn writeInt(value: i32, buf: []u8) !void {
    return writeNumber(i32, value, buf);
}

pub fn writeUlong(value: u64, buf: []u8) !void {
    return writeNumber(u64, value, buf);
}

pub fn writeLong(value: i64, buf: []u8) !void {
    return writeNumber(i64, value, buf);
}

pub fn readFloat(dst: *f32, buf: []const u8) ![]const u8 {
    return readFloatingPointNumber(f32, dst, buf);
}

pub fn readDouble(dst: *f64, buf: []const u8) ![]const u8 {
    return readFloatingPointNumber(f64, dst, buf);
}

pub fn writeFloat(value: f32, buf: []u8) !void {
    return writeFloatingPointNumber(f32, value, buf);
}

pub fn writeDouble(value: f64, buf: []u8) !void {
    return writeFloatingPointNumber(f64, value, buf);
}

inline fn readNumber(comptime T: type, dst: *T, buf: []const u8) ![]const u8 {
    const U: type = switch (T) {
        i32 => u32,
        i64 => u64,
        u32 => u32,
        u64 => u64,
        usize => usize,
        isize => usize,
        else => @compileError("supported types: i32, u32, i64, u64, usize, isize. Got " ++ @typeName(T)),
    };
    var stream = std.io.fixedBufferStream(buf);
    const num = try leb.readUleb128(U, stream.reader());
    dst.* = @as(T, @bitCast(zigZagDecode(U, num)));

    return buf[try stream.getPos()..];
}

inline fn writeNumber(comptime T: type, value: T, buf: []u8) !void {
    const U: type = switch (T) {
        i32 => u32,
        i64 => u64,
        u32 => u32,
        u64 => u64,
        usize => usize,
        isize => usize,
        else => @compileError("supported types: i32, u32, i64, u64, usize, isize. Got " ++ @typeName(T)),
    };
    var stream = std.io.fixedBufferStream(buf);
    try leb.writeUleb128(
        stream.writer(),
        zigZagEncode(U, @as(U, @bitCast(value))),
    );
}

inline fn zigZagEncode(comptime T: type, n: T) T {
    comptime if (@typeInfo(T).int.signedness == std.builtin.Signedness.signed)
        @compileError("only works on unsigned integers");
    return if (@clz(n) == 0) ~(n << 1) else (n << 1);
}

inline fn zigZagDecode(comptime T: type, n: T) T {
    comptime if (@typeInfo(T).int.signedness == std.builtin.Signedness.signed)
        @compileError("only works on unsigned integers");
    return if (n & 1 == 1) ~(n >> 1) else (n >> 1);
}

pub const ReadFloatingPointError = error{
    Overflow,
    InvalidEOF,
};

pub const WriteFloatingPointError = error{
    Overflow,
};

inline fn readFloatingPointNumber(comptime T: type, dst: *T, buf: []const u8) ![]const u8 {
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

inline fn writeFloatingPointNumber(comptime T: type, value: T, buf: []u8) !void {
    const U: type = switch (T) {
        f32 => u32,
        f64 => u64,
        else => @compileError("unsupported type: " ++ @typeName(T)),
    };
    var stream = std.io.fixedBufferStream(buf);
    try stream.writer().writeInt(U, @bitCast(value), .big);
}

test "read float and double" {
    var test_f32: f32 = undefined;

    const rem_f32 = try readFloat(&test_f32, &[_]u8{
        0x40, 0x49, 0x0F, 0xD8,
    });
    try std.testing.expectApproxEqRel(3.141592, test_f32, std.math.floatEps(f32));
    try std.testing.expectEqual(0, rem_f32.len);

    var test_f64: f64 = undefined;

    const rem_f64 = try readDouble(&test_f64, &[_]u8{
        0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18,
    });
    try std.testing.expectApproxEqRel(
        3.141592653589793115997963468544185161590576171875,
        test_f64,
        std.math.floatEps(f64),
    );
    try std.testing.expectEqual(0, rem_f64.len);
}

test "write float and double" {
    var res = &[_]u8{
        0x40, 0x49, 0x0F, 0xD8,
    };

    var buf: [4]u8 = undefined;
    try writeFloat(3.141592, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    res = &[_]u8{
        0xC0, 0x49, 0x0F, 0xD8,
    };
    buf = undefined;
    try writeFloat(-3.141592, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const res2 = &[_]u8{
        0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18,
    };

    var buf2: [8]u8 = undefined;
    try writeDouble(3.141592653589793115997963468544185161590576171875, &buf2);
    try std.testing.expectEqualSlices(u8, res2, &buf2);
}

test "zig zag fuzz" {
    const testFuncs = struct {
        fn test64(input: []const u8) !void {
            if (input.len < 8) return;
            const blep: [8]u8 = input[0..8].*;
            const n: u64 = std.mem.readInt(u64, &blep, std.builtin.Endian.big);
            try std.testing.expectEqual(n, zigZagDecode(u64, zigZagEncode(u64, n)));
        }
        fn test32(input: []const u8) !void {
            if (input.len < 4) return;
            const blep: [4]u8 = input[0..4].*;
            const n: u32 = std.mem.readInt(u32, &blep, std.builtin.Endian.big);
            try std.testing.expectEqual(n, zigZagDecode(u32, zigZagEncode(u32, n)));
        }
    };
    try std.testing.fuzz(testFuncs.test32, .{});
}

test "read int and long" {
    var test_i32: i32 = 123;
    var test_u64: u64 = 123;

    try std.testing.expectError(error.EndOfStream, readUlong(&test_u64, &[_]u8{
        0b10010110,
        0b10010110,
        0b10010110,
        0b10010110,
    }));

    const rem_i32 = try readInt(&test_i32, &[_]u8{
        0b10010110,
        0b1,
        0b1,
    });
    try std.testing.expectEqual(rem_i32.len, 1);
    try std.testing.expectEqual(75, test_i32);

    const rem_u64 = try readUlong(&test_u64, &[_]u8{
        0b10010110,
        0b1,
        0b1,
    });
    try std.testing.expectEqual(rem_u64.len, 1);
    try std.testing.expectEqual(75, test_u64);
}

test "write int and long" {
    const res = &[_]u8{ 0xAC, 0x02 };

    var buf: [2]u8 = undefined;
    try writeUint(150, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const negativeTwo = &[_]u8{
        0b00000011,
    };

    var negBuf: [1]u8 = undefined;
    try writeUlong(0xfffffffffffffffe, &negBuf);
    try std.testing.expectEqualSlices(u8, negativeTwo, &negBuf);

    var negBuf2: [0]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, writeUlong(0xfffffffffffffffe, &negBuf2));

    var buf3: [0]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, writeUlong(1, &buf3));
}

test zigZagEncode {
    try std.testing.expectEqual(0, zigZagEncode(u64, 0));
    try std.testing.expectEqual(1, zigZagEncode(u64, 0xffffffffffffffff));
    try std.testing.expectEqual(2, zigZagEncode(u64, 1));
    try std.testing.expectEqual(3, zigZagEncode(u64, 0xfffffffffffffffe));
    try std.testing.expectEqual(4, zigZagEncode(u64, 2));
    try std.testing.expectEqual(4294967294, zigZagEncode(u32, 2147483647));
    try std.testing.expectEqual(4294967295, zigZagEncode(u32, 0x80000000));
}

test zigZagDecode {
    try std.testing.expectEqual(0, zigZagDecode(u64, 0));
    try std.testing.expectEqual(0xffffffffffffffff, zigZagDecode(u64, 1));
    try std.testing.expectEqual(1, zigZagDecode(u64, 2));
    try std.testing.expectEqual(0xfffffffffffffffe, zigZagDecode(u64, 3));
    try std.testing.expectEqual(2, zigZagDecode(u64, 4));
    try std.testing.expectEqual(3, zigZagDecode(u64, 6));
    try std.testing.expectEqual(3, zigZagDecode(u64, 0x6));
    try std.testing.expectEqual(2147483647, zigZagDecode(u64, 4294967294));
    try std.testing.expectEqual(0x80000000, zigZagDecode(u32, 4294967295));
}
