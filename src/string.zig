const number = @import("number.zig");
const std = @import("std");
const WriteError = @import("errors.zig").WriteError;

pub const ReadStringError = error{
    InvalidEOF,
};

/// Read a string from input `in`.
/// Returns slice of `in` after end of string.
/// `dst` is set to a slice of `in` containing the string.
pub fn read(dst: *[]const u8, in: []const u8) !usize {
    var len_i64: i64 = 0;
    const n = try number.readLong(&len_i64, in);
    const len: u64 = @intCast(len_i64);
    if (in.len < len) {
        return ReadStringError.InvalidEOF;
    }
    dst.* = in[n .. n + len];
    return n + len;
}

test read {
    var out: []u8 = &.{};
    try std.testing.expectError(ReadStringError.InvalidEOF, read(&out, &[_]u8{20} ++ "hello"));

    var n = try read(&out, &[_]u8{5 << 1} ++ "hello");
    try std.testing.expectEqual(6, n);
    try std.testing.expectEqualStrings("hello", out);

    n = try read(&out, &[_]u8{4 << 1} ++ "hello");
    try std.testing.expectEqual(5, n);
    try std.testing.expectEqualStrings("hell", out);

    var buf = [_]u8{ 3 << 1, 'D', 'O', 'G' };
    n = try read(&out, &buf);
    try std.testing.expectEqual(4, n);
    buf[2] = 'I';
    try std.testing.expectEqualStrings("DIG", out);
}

/// Do bounds check on the buffer, then write contents to the buffer.
///
/// Returns error if buffer is too small.
pub inline fn write(value: []const u8, buf: []u8) ![]const u8 {
    const pos = (try number.writeLong(@intCast(value.len), buf)).len;
    if (value.len > buf.len - pos) return WriteError.UnexpectedEndOfBuffer;
    @memcpy(buf[pos .. pos + value.len], value);
    return buf[0 .. pos + value.len];
}

test write {
    const res = "hi";
    var buf: [3]u8 = undefined;
    const out = try write(res, &buf);
    try std.testing.expectEqual(3, out.len);
    try std.testing.expectEqualSlices(u8, res, buf[1..]);

    const res2 = "🤪🤑🤑🤑🤑";
    var buf2: [2]u8 = undefined;
    try std.testing.expectError(WriteError.UnexpectedEndOfBuffer, write(res2, &buf2));

    const res3 = "🤪🤑🤑🤑🤑";
    var buf3: [res3.len + 1]u8 = undefined;
    const out3 = try write(res3, &buf3);
    try std.testing.expectEqual(res3.len + 1, out3.len);
    try std.testing.expectEqualSlices(u8, res3, buf3[1..]);
}

test "can write then read" {
    var buf: [10]u8 = undefined;
    const msg = "MEEP";
    _ = try write(msg, &buf);
    var beb: []const u8 = undefined;
    _ = try read(&beb, &buf);
    try std.testing.expectEqualSlices(u8, msg, beb);
}
