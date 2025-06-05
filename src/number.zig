const std = @import("std");
const errors = @import("errors.zig");
const leb = std.leb;
const ReadError = errors.ReadError;

pub fn readInt(dst: *i32, buf: []const u8) !usize {
    return readNumber(i32, dst, buf);
}

pub fn readLong(dst: *i64, buf: []const u8) !usize {
    return readNumber(i64, dst, buf);
}

pub fn writeInt(writer: anytype, value: i32) !usize {
    return try writeNumber(i32, writer, value);
}

pub fn writeLong(writer: anytype, value: i64) !usize {
    return try writeNumber(i64, writer, value);
}

pub fn readFloat(dst: *f32, buf: []const u8) !usize {
    return readFloatingPointNumber(f32, dst, buf);
}

pub fn readDouble(dst: *f64, buf: []const u8) !usize {
    return readFloatingPointNumber(f64, dst, buf);
}

pub fn writeFloat(writer: anytype, value: f32) !usize {
    try writeFloatingPointNumber(f32, writer, value);
    return @sizeOf(f32);
}

pub fn writeDouble(writer: anytype, value: f64) !usize {
    try writeFloatingPointNumber(f64, writer, value);
    return @sizeOf(f64);
}

pub fn Uleb128(comptime T: type) type {
    return struct { size: usize, val: T };
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
        .size = i + 1,
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
    return num.size;
}

/// Vendored and modified from std.leb128 to return the number of bytes written.
pub fn writeUleb128(writer: anytype, arg: anytype) !usize {
    const Arg = @TypeOf(arg);
    const Int = switch (Arg) {
        comptime_int => std.math.IntFittingRange(arg, arg),
        else => Arg,
    };
    const Value = if (@typeInfo(Int).int.bits < 8) u8 else Int;
    var value: Value = arg;

    var size: usize = 1;
    while (true) : (size += 1) {
        const byte: u8 = @truncate(value & 0x7f);
        value >>= 7;
        if (value == 0) {
            try writer.writeByte(byte);
            break;
        }
        try writer.writeByte(byte | 0x80);
    }
    return size;
}

inline fn writeNumber(comptime T: type, writer: anytype, value: T) !usize {
    const U: type = switch (T) {
        i32 => u32,
        i64 => u64,
        u32 => u32,
        u64 => u64,
        usize => usize,
        isize => usize,
        else => @compileError("supported types: i32, u32, i64, u64, usize, isize. Got " ++ @typeName(T)),
    };
    return try writeUleb128(writer, zigZagEncode(U, @as(U, @bitCast(value))));
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

inline fn writeFloatingPointNumber(comptime T: type, writer: anytype, value: T) !void {
    const U: type = switch (T) {
        f32 => u32,
        f64 => u64,
        else => @compileError("unsupported type: " ++ @typeName(T)),
    };
    try writer.writeInt(U, @bitCast(value), .big);
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

    var fbs = std.io.fixedBufferStream(&buf);
    var writer = fbs.writer();

    _ = try writeFloat(&writer, 3.141592);
    try std.testing.expectEqualSlices(u8, res, &buf);

    res = &[_]u8{ 0xC0, 0x49, 0x0F, 0xD8 };
    fbs.reset();

    const fwritten = try writeFloat(&writer, -3.141592);
    try std.testing.expectEqual(4, fwritten);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const res2 = &[_]u8{ 0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18 };

    var buf2: [8]u8 = undefined;
    var fbs2 = std.io.fixedBufferStream(&buf2);
    var writer2 = fbs2.writer();

    const written = try writeDouble(&writer2, 3.141592653589793115997963468544185161590576171875);
    try std.testing.expectEqual(8, written);
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
    var fbs = std.io.fixedBufferStream(&buf);
    var writer = fbs.writer();

    _ = try writeInt(&writer, 150);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const negativeTwo = &[_]u8{0b00000011};

    var negBuf: [1]u8 = undefined;
    var nfbs = std.io.fixedBufferStream(&negBuf);
    var writer2 = nfbs.writer();
    _ = try writeLong(&writer2, -2);
    try std.testing.expectEqualSlices(u8, negativeTwo, &negBuf);

    var negBuf2: [0]u8 = undefined;
    var nfbs2 = std.io.fixedBufferStream(&negBuf2);
    var writer3 = nfbs2.writer();
    try std.testing.expectError(error.NoSpaceLeft, writeLong(&writer3, -2));

    var buf3: [0]u8 = undefined;
    var fbs3 = std.io.fixedBufferStream(&buf3);
    var writer4 = fbs3.writer();
    try std.testing.expectError(error.NoSpaceLeft, writeLong(&writer4, 1));
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
