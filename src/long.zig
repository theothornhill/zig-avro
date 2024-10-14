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
    try leb.writeUleb128(
        stream.writer(),
        zigZagEncode(T, @as(T, @bitCast(value))),
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

test read {
    var test_u32: u32 = 123;
    var test_u64: u64 = 123;

    try std.testing.expectError(error.EndOfStream, read(u64, &test_u64, &[_]u8{
        0b10010110,
        0b10010110,
        0b10010110,
        0b10010110,
    }));

    const rem_u32 = try read(u32, &test_u32, &[_]u8{
        0b10010110,
        0b1,
        0b1,
    });
    try std.testing.expectEqual(rem_u32.len, 1);
    try std.testing.expectEqual(75, test_u32);

    const rem_u64 = try read(u64, &test_u64, &[_]u8{
        0b10010110,
        0b1,
        0b1,
    });
    try std.testing.expectEqual(rem_u64.len, 1);
    try std.testing.expectEqual(75, test_u64);
}

test write {
    const res = &[_]u8{ 0xAC, 0x02 };

    var buf: [2]u8 = undefined;
    try write(u64, 150, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const negativeTwo = &[_]u8{
        0b00000011,
    };

    var negBuf: [1]u8 = undefined;
    try write(u64, 0xfffffffffffffffe, &negBuf);
    try std.testing.expectEqualSlices(u8, negativeTwo, &negBuf);

    var negBuf2: [0]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, write(u64, 0xfffffffffffffffe, &negBuf2));

    var buf3: [0]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, write(u64, 1, &buf3));
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
