const number = @import("number.zig");
const std = @import("std");
const WriteError = @import("errors.zig").WriteError;

pub const ReadStringError = error{
    InvalidEOF,
};

/// Read a string from input `in`.
/// Returns slice of `in` after end of string.
/// `dst` is set to a slice of `in` containing the string.
pub fn read(dst: *[]const u8, in: []const u8) ![]const u8 {
    var len: i64 = 0;
    const rem = try number.readLong(&len, in);
    if (in.len < len) {
        return ReadStringError.InvalidEOF;
    }
    dst.* = rem[0..@bitCast(len)];
    return rem[@bitCast(len)..];
}

test read {
    var out: []u8 = &.{};
    try std.testing.expectError(ReadStringError.InvalidEOF, read(&out, &[_]u8{20} ++ "hello"));

    var rem = try read(&out, &[_]u8{5 << 1} ++ "hello");
    try std.testing.expectEqual(0, rem.len);
    try std.testing.expectEqualStrings("hello", out);

    rem = try read(&out, &[_]u8{4 << 1} ++ "hello");
    try std.testing.expectEqual(1, rem.len);
    try std.testing.expectEqualStrings("hell", out);

    var buf = [_]u8{ 3 << 1, 'D', 'O', 'G' };
    rem = try read(&out, &buf);
    try std.testing.expectEqual(0, rem.len);
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
