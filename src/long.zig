const std = @import("std");

const ReadLongError = error{
    Overflow,
    InvalidEOF,
};

inline fn zigZagDecode(comptime T: type, n: T) T {
    return (n >> 1) ^ (-(n & 1));
}

pub fn read(comptime T: type, dst: *T, in: []const u8) ReadLongError![]const u8 {
    var res: T = 0;
    // We need an unsigned int that will not shift past the size of T.  For
    // example, i64 will create a u6, because 0b111111 == 63. Thus we cannot
    // shift outside of the integer range.
    var shift: std.math.Log2Int(T) = 0;
    for (in, 0..) |b, i| {
        res |= @as(T, b & 0x7f) << shift;
        if (b & 0x80 == 0) {
            dst.* = zigZagDecode(T, res);
            return in[i + 1 ..];
        }

        const shifted = @addWithOverflow(shift, 7);
        if (shifted[1] == 0) {
            shift = shifted[0];
        } else {
            return ReadLongError.Overflow;
        }
    }
    return ReadLongError.InvalidEOF;
}

pub const WriteLongError = error{
    BufferTooSmall,
};

inline fn zigZagEncode(comptime T: type, n: T) T {
    return (n << 1) ^ (n >> @bitSizeOf(T) - 1);
}

pub fn write(comptime T: type, value: T, buf: []u8) !void {
    var v: T = zigZagEncode(T, value);
    var offset: usize = 0;

    // As long as we have continuation bits as the most significant bit per
    // byte, we chomp 7 bits and add continuation bit.
    while (v >= 0x80) : ({
        v >>= 7;
        offset += 1;
    }) {
        if (offset >= buf.len) {
            return WriteLongError.BufferTooSmall;
        }
        buf[offset] = @as(u8, @intCast(v & 0x7F)) | 0x80;
    }

    if (offset >= buf.len) {
        return WriteLongError.BufferTooSmall;
    }
    // Add the last byte, now without continuation bits.
    buf[offset] = @as(u8, @intCast(v & 0x7F));
}

test read {
    var test_i16: i16 = 123;
    var test_i32: i32 = 123;
    var test_i64: i64 = 123;

    try std.testing.expectError(ReadLongError.Overflow, read(i16, &test_i16, &[_]u8{
        0b10010110,
        0b10010110,
        0b10010110,
        0b10010110,
        0b00000001,
        0b1,
    }));

    try std.testing.expectError(ReadLongError.InvalidEOF, read(i64, &test_i64, &[_]u8{
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
    try std.testing.expectEqual(rem_i16.len, 1);
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

    const rem_neg1 = try read(i64, &test_i64, &[_]u8{
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
    try std.testing.expectEqual(rem_neg1.len, 0);
    try std.testing.expectEqual(18446744073709551615, @as(u64, @bitCast(test_i64)));
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
    try std.testing.expectError(WriteLongError.BufferTooSmall, write(i64, -2, &negBuf2));

    var buf3: [0]u8 = undefined;
    try std.testing.expectError(WriteLongError.BufferTooSmall, write(i64, 1, &buf3));
}
