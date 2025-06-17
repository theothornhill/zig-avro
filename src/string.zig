const number = @import("number.zig");
const std = @import("std");

/// Read a string from input `in`.
/// Returns slice of `in` after end of string.
/// `dst` is set to a slice of `in` containing the string.
pub fn read(dst: *[]const u8, in: []const u8) !usize {
    var len_i64: i64 = 0;
    const n = try number.readLong(&len_i64, in);
    const len: usize = @intCast(len_i64);
    if (in.len < len)
        return error.UnexpectedEndOfBuffer;
    dst.* = in[n .. n + len];
    return n + len;
}

test read {
    var out: []const u8 = &.{};
    try std.testing.expectError(error.UnexpectedEndOfBuffer, read(&out, &[_]u8{20} ++ "hello"));

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

pub inline fn write(writer: anytype, value: []const u8) !usize {
    const num_len = try number.writeLong(writer, @intCast(value.len));
    const str_len = try writer.write(value);
    return num_len + str_len;
}

test write {
    const res = "hi";
    var buf: [3]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var writer = fbs.writer();

    const out = try write(&writer, res);
    try std.testing.expectEqual(3, out);
    try std.testing.expectEqualStrings(res, buf[1..]);

    const res2 = "🤪🤑🤑🤑🤑";
    var buf2: [res2.len + 1]u8 = undefined;
    var fbs2 = std.io.fixedBufferStream(&buf2);
    var writer2 = fbs2.writer();
    const out2 = try write(&writer2, res2);
    try std.testing.expectEqual(res2.len + 1, out2);
    try std.testing.expectEqualSlices(u8, res2, buf2[1..]);
}

test "can write then read" {
    var buf: [10]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var writer = fbs.writer();

    const msg = "MEEP";
    _ = try write(&writer, msg);
    var beb: []const u8 = undefined;
    _ = try read(&beb, &buf);
    try std.testing.expectEqualSlices(u8, msg, beb);
}
