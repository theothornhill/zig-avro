const std = @import("std");
const WriteError = @import("errors.zig").WriteError;

pub const ReadBoolError = error{
    InvalidBool,
    InvalidEOF,
};

pub fn read(dst: *bool, buf: []const u8) ![]const u8 {
    if (buf.len < 1) {
        return ReadBoolError.InvalidEOF;
    }
    const num = buf[0];
    dst.* = switch (num) {
        0 => false,
        1 => true,
        else => return ReadBoolError.InvalidBool,
    };

    return buf[1..];
}

pub fn write(value: bool, buf: []u8) ![]const u8 {
    if (buf.len < 1) return WriteError.UnexpectedEndOfBuffer;
    var stream = std.io.fixedBufferStream(buf);
    try stream.writer().writeByte(if (value) 1 else 0);
    return buf[0..1];
}

test read {
    var b: bool = undefined;

    const rem_false = try read(&b, &[_]u8{
        0x00, 0x03,
    });

    try std.testing.expect(!b);
    try std.testing.expectEqual(1, rem_false.len);

    b = undefined;
    const rem_true = try read(&b, &[_]u8{
        0x01, 0x03,
    });

    try std.testing.expect(b);
    try std.testing.expectEqual(1, rem_true.len);
}

test write {
    var buf: [1]u8 = undefined;

    var b: bool = undefined;
    _ = try write(false, &buf);
    _ = try read(&b, &buf);
    try std.testing.expect(!b);

    b = undefined;
    _ = try write(true, &buf);
    _ = try read(&b, &buf);
    try std.testing.expect(b);
}
