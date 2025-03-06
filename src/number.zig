const std = @import("std");
const errors = @import("errors.zig");
const leb = std.leb;
const WriteError = errors.WriteError;
const ReadError = errors.ReadError;

pub fn readInt(dst: *i32, buf: []const u8) !usize {
    return readNumber(i32, dst, buf);
}

pub fn readLong(dst: *i64, buf: []const u8) !usize {
    return readNumber(i64, dst, buf);
}

pub fn writeInt(value: i32, buf: []u8) ![]const u8 {
    return writeNumber(i32, value, buf);
}

pub fn writeLong(value: i64, buf: []u8) ![]const u8 {
    return writeNumber(i64, value, buf);
}

pub fn readFloat(dst: *f32, buf: []const u8) !usize {
    return readFloatingPointNumber(f32, dst, buf);
}

pub fn readDouble(dst: *f64, buf: []const u8) !usize {
    return readFloatingPointNumber(f64, dst, buf);
}

pub fn writeFloat(value: f32, buf: []u8) ![]const u8 {
    return writeFloatingPointNumber(f32, value, buf);
}

pub fn writeDouble(value: f64, buf: []u8) ![]const u8 {
    return writeFloatingPointNumber(f64, value, buf);
}

pub fn Uleb128(comptime T: type) type {
    return struct {
        bytes_read: usize,
        val: T,
    };
}

/// We should rather try to create a io.Reader that won't copy, but for now,
/// this vendored function doubles the read speed of our parser.
pub fn readUleb128(comptime T: type, buf: []const u8) !Uleb128(T) {
    const ShiftT = std.math.Log2Int(T);

    const max_group = (@typeInfo(T).int.bits + 6) / 7;

    var value: T = 0;
    var group: ShiftT = 0;

    var i: usize = 0;
    while (group < max_group) : ({
        group += 1;
        i += 1;
    }) {
        if (i >= buf.len) {
            return ReadError.UnexpectedEndOfBuffer;
        }
        const byte = buf[i];

        value |= @as(T, byte & 0x7f) << group * 7;
        if (byte & 0x80 == 0) break;
    } else {
        return ReadError.IntegerOverflow;
    }

    return .{
        .bytes_read = i + 1,
        .val = @as(T, @truncate(value)),
    };
}

inline fn readNumber(comptime T: type, dst: *T, buf: []const u8) !usize {
    const U: type = switch (T) {
        i32 => u32,
        i64 => u64,
        u32 => u32,
        u64 => u64,
        usize => usize,
        isize => usize,
        else => @compileError("supported types: i32, u32, i64, u64, usize, isize. Got " ++ @typeName(T)),
    };
    const num = try readUleb128(U, buf);
    dst.* = @as(T, @bitCast(zigZagDecode(U, num.val)));
    return num.bytes_read;
}

inline fn writeNumber(comptime T: type, value: T, buf: []u8) ![]const u8 {
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
    leb.writeUleb128(
        stream.writer(),
        zigZagEncode(U, @as(U, @bitCast(value))),
    ) catch |err| {
        switch (err) {
            error.NoSpaceLeft => return WriteError.UnexpectedEndOfBuffer,
        }
    };
    return buf[0..stream.pos];
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

inline fn readFloatingPointNumber(comptime T: type, dst: *T, buf: []const u8) !usize {
    const U: type = switch (T) {
        f32 => u32,
        f64 => u64,
        else => @compileError("unsupported type: " ++ @typeName(T)),
    };

    if (buf.len < @sizeOf(U)) {
        return ReadError.UnexpectedEndOfBuffer;
    }

    var stream = std.io.fixedBufferStream(buf);
    dst.* = @bitCast(try stream.reader().readInt(U, .big));

    return @sizeOf(U);
}

inline fn writeFloatingPointNumber(comptime T: type, value: T, buf: []u8) ![]const u8 {
    const U: type = switch (T) {
        f32 => u32,
        f64 => u64,
        else => @compileError("unsupported type: " ++ @typeName(T)),
    };
    var stream = std.io.fixedBufferStream(buf);
    try stream.writer().writeInt(U, @bitCast(value), .big);
    return buf[0..stream.pos];
}

test "read float and double" {
    var test_f32: f32 = undefined;

    const read_f32 = try readFloat(&test_f32, &[_]u8{
        0x40, 0x49, 0x0F, 0xD8,
    });
    try std.testing.expectApproxEqRel(3.141592, test_f32, std.math.floatEps(f32));
    try std.testing.expectEqual(4, read_f32);

    var test_f64: f64 = undefined;

    const read_f64 = try readDouble(&test_f64, &[_]u8{
        0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18,
    });
    try std.testing.expectApproxEqRel(
        3.141592653589793115997963468544185161590576171875,
        test_f64,
        std.math.floatEps(f64),
    );
    try std.testing.expectEqual(8, read_f64);
}

test "write float and double" {
    var res = &[_]u8{
        0x40, 0x49, 0x0F, 0xD8,
    };

    var buf: [4]u8 = undefined;
    _ = try writeFloat(3.141592, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    res = &[_]u8{
        0xC0, 0x49, 0x0F, 0xD8,
    };
    buf = undefined;
    _ = try writeFloat(-3.141592, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const res2 = &[_]u8{
        0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18,
    };

    var buf2: [8]u8 = undefined;
    _ = try writeDouble(3.141592653589793115997963468544185161590576171875, &buf2);
    try std.testing.expectEqualSlices(u8, res2, &buf2);
}

// test "zig zag fuzz" {
//     const testFuncs = struct {
//         fn test64(input: []const u8) !void {
//             if (input.len < 8) return;
//             const blep: [8]u8 = input[0..8].*;
//             const n: u64 = std.mem.readInt(u64, &blep, std.builtin.Endian.big);
//             try std.testing.expectEqual(n, zigZagDecode(u64, zigZagEncode(u64, n)));
//         }
//         fn test32(input: []const u8) !void {
//             if (input.len < 4) return;
//             const blep: [4]u8 = input[0..4].*;
//             const n: u32 = std.mem.readInt(u32, &blep, std.builtin.Endian.big);
//             try std.testing.expectEqual(n, zigZagDecode(u32, zigZagEncode(u32, n)));
//         }
//     };
//     try std.testing.fuzz(testFuncs.test32, .{});
// }

test "read int and long" {
    var test_i32: i32 = 123;
    var test_i64: i64 = 123;

    try std.testing.expectError(ReadError.UnexpectedEndOfBuffer, readLong(&test_i64, &[_]u8{
        0b10010110,
        0b10010110,
        0b10010110,
        0b10010110,
    }));

    const read_i32 = try readInt(&test_i32, &[_]u8{
        0b10010110,
        0b1,
        0b1,
    });
    try std.testing.expectEqual(2, read_i32);
    try std.testing.expectEqual(75, test_i32);

    const read_u64 = try readLong(&test_i64, &[_]u8{
        0b10010110,
        0b1,
        0b1,
    });
    try std.testing.expectEqual(2, read_u64);
    try std.testing.expectEqual(75, test_i64);
}

test "write int and long" {
    const res = &[_]u8{ 0xAC, 0x02 };

    var buf: [2]u8 = undefined;
    _ = try writeInt(150, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const negativeTwo = &[_]u8{
        0b00000011,
    };

    var negBuf: [1]u8 = undefined;
    _ = try writeLong(-2, &negBuf);
    try std.testing.expectEqualSlices(u8, negativeTwo, &negBuf);

    var negBuf2: [0]u8 = undefined;
    try std.testing.expectError(WriteError.UnexpectedEndOfBuffer, writeLong(-2, &negBuf2));

    var buf3: [0]u8 = undefined;
    try std.testing.expectError(WriteError.UnexpectedEndOfBuffer, writeLong(1, &buf3));
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
