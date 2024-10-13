const std = @import("std");
const leb = std.leb;

pub const ReadLongError = error{
    Overflow,
    InvalidEOF,
};

pub const WriteLongError = error{
    Overflow,
};

pub fn read(comptime T: type, dst: *T, buf: []const u8) ![]const u8 {
    var stream = std.io.fixedBufferStream(buf);
    const num = try leb.readUleb128(T, stream.reader());
    dst.* = zigZagDecode(T, num);

    return buf[try stream.getPos()..];
}

pub fn write(comptime T: type, value: T, buf: []u8) !void {
    var stream = std.io.fixedBufferStream(buf);
    const signedness = @typeInfo(T).int.signedness;
    const fun = if (signedness == .signed) leb.writeIleb128 else leb.writeUleb128;

    try fun(
        stream.writer(),
        zigZagEncode(T, value),
    );
}

inline fn zigZagEncode(comptime T: type, n: T) T {
    return (n << 1) ^ (n >> @bitSizeOf(T) - 1);
}

inline fn zigZagDecode(comptime T: type, n: T) T {
    return (n >> 1) ^ (0 -% (n & 1));
}

test read {
    var test_i16: i16 = 123;
    var test_i32: i32 = 123;
    var test_i64: i64 = 123;
    var test_u64: u64 = 123;

    try std.testing.expectError(ReadLongError.Overflow, read(i16, &test_i16, &[_]u8{
        0b10010110,
        0b10010110,
        0b10010110,
        0b10010110,
        0b00000001,
        0b1,
    }));

    try std.testing.expectError(ReadLongError.Overflow, read(i16, &test_i16, &[_]u8{
        0b10010110,
        0b10010110,
        0b10010110,
        0b10010110,
        0b00000001,
        0b1,
    }));

    try std.testing.expectError(error.EndOfStream, read(i64, &test_i64, &[_]u8{
        0b10010110,
        0b10010110,
        0b10010110,
        0b10010110,
    }));

    const rem_i16 = try read(i16, &test_i16, &[_]u8{
        0b10010110,
        0b00000001,
        0b1,
    });
    try std.testing.expectEqual(1, rem_i16.len);
    try std.testing.expectEqual(75, test_i16);

    const rem_i32 = try read(i32, &test_i32, &[_]u8{
        0b10010110,
        0b1,
        0b1,
    });
    try std.testing.expectEqual(rem_i32.len, 1);
    try std.testing.expectEqual(75, test_i32);

    const rem_i64 = try read(i64, &test_i64, &[_]u8{
        0b10010110,
        0b1,
        0b1,
    });
    try std.testing.expectEqual(rem_i64.len, 1);
    try std.testing.expectEqual(75, test_i64);

    const rem_large = try read(u64, &test_u64, &[_]u8{
        0b11111110,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b11111111,
        0b00000001,
    });
    try std.testing.expectEqual(rem_large.len, 0);
    try std.testing.expectEqual(9223372036854775807, test_u64);

    const rem_maxU64 = try read(u64, &test_u64, &[_]u8{
        0b00000001,
    });
    try std.testing.expectEqual(rem_maxU64.len, 0);
    try std.testing.expectEqual(18446744073709551615, test_u64);
}

test write {
    const res = &[_]u8{ 0xAC, 0x02 };

    var buf: [2]u8 = undefined;
    try write(i64, 150, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const negativeTwo = &[_]u8{
        0b00000011,
    };

    var negBuf: [1]u8 = undefined;
    try write(i64, -2, &negBuf);
    try std.testing.expectEqualSlices(u8, negativeTwo, &negBuf);

    var negBuf2: [0]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, write(i64, -2, &negBuf2));

    var buf3: [0]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, write(i64, 1, &buf3));
}

test zigZagEncode {
    try std.testing.expectEqual(0, zigZagEncode(i64, 0));
    try std.testing.expectEqual(1, zigZagEncode(i64, -1));
    try std.testing.expectEqual(2, zigZagEncode(i64, 1));
    try std.testing.expectEqual(3, zigZagEncode(i64, -2));
    try std.testing.expectEqual(4, zigZagEncode(i64, 2));
    try std.testing.expectEqual(4294967294, zigZagEncode(i64, 2147483647));
    try std.testing.expectEqual(4294967293, zigZagEncode(i64, -2147483647));

    try std.testing.expectEqual(2, zigZagEncode(i64, std.mem.readVarInt(i64, &[_]u8{1}, .little)));
    try std.testing.expectEqual(4, zigZagEncode(i64, std.mem.readVarInt(i64, &[_]u8{2}, .little)));
}

test zigZagDecode {
    try std.testing.expectEqual(0, zigZagDecode(i64, 0));
    try std.testing.expectEqual(-1, zigZagDecode(i64, 1));
    try std.testing.expectEqual(1, zigZagDecode(i64, 2));
    try std.testing.expectEqual(-2, zigZagDecode(i64, 3));
    try std.testing.expectEqual(2, zigZagDecode(i64, 4));
    try std.testing.expectEqual(3, zigZagDecode(i64, 6));
    try std.testing.expectEqual(3, zigZagDecode(i64, 0x6));
    try std.testing.expectEqual(2147483647, zigZagDecode(i64, 4294967294));
    try std.testing.expectEqual(-2147483647, zigZagDecode(i64, 4294967293));

    try std.testing.expectEqual(-1, zigZagDecode(i64, std.mem.readVarInt(i64, &[_]u8{1}, .little)));
    try std.testing.expectEqual(1, zigZagDecode(i64, std.mem.readVarInt(i64, &[_]u8{2}, .little)));
}
