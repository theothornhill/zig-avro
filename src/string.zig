const std = @import("std");

const ReadStringError = error{
    InvalidEOF,
};

/// Read a string from input `in`.
///
/// Makes assumption that index 0 in the input is the start of the string, and
/// that `len` tells us how many characters we should read.
pub fn read(in: []const u8, len: usize) ReadStringError![]const u8 {
    if (in.len < len) {
        return ReadStringError.InvalidEOF;
    }

    return in[0..len];
}

test read {
    try std.testing.expectError(ReadStringError.InvalidEOF, read("hello", 10));

    try std.testing.expectEqualStrings("hello", try read("hello", 5));
    try std.testing.expectEqualStrings("hello", try read("hello there", 5));

    var str: []const u8 = "hello there dude! ";
    var offset: usize = 0;
    const increment: usize = 6;
    const results = [_][]const u8{
        "hello ",
        "there ",
        "dude! ",
    };
    var iteration: usize = 0;

    while (offset <= str.len) {
        try std.testing.expectEqualStrings(results[iteration], try read(str, increment));
        offset += increment;
        str = str[offset..];
        iteration += 1;
    }

    const emojistr: []const u8 = "🤪🤑🤑🤑🤑";
    try std.testing.expectEqualStrings(emojistr, try read(emojistr, emojistr.len));
}

pub const WriteStringError = error{
    BufferTooSmall,
};

/// Do bounds check on the buffer, then write contents to the buffer.
///
/// Returns error if buffer is too small.
pub inline fn write(value: []const u8, buf: []u8) !void {
    if (value.len > buf.len) {
        return WriteStringError.BufferTooSmall;
    }

    for (value, 0..) |b, i| {
        buf[i] = b;
    }
}

test write {
    const res = "hi";
    var buf: [2]u8 = undefined;
    try write(res, &buf);
    try std.testing.expectEqualSlices(u8, res, &buf);

    const res2 = "🤪🤑🤑🤑🤑";
    var buf2: [2]u8 = undefined;
    try std.testing.expectError(WriteStringError.BufferTooSmall, write(res2, &buf2));

    const res3 = "🤪🤑🤑🤑🤑";
    var buf3: [res3.len]u8 = undefined;
    try write(res3, &buf3);
    try std.testing.expectEqualSlices(u8, res3, &buf3);
}
