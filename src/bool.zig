const std = @import("std");
const Writer = std.Io.Writer;

pub fn read(dst: *bool, buf: []const u8) !usize {
    if (buf.len < 1) {
        return error.UnexpectedEndOfBuffer;
    }
    const num = buf[0];
    dst.* = switch (num) {
        0 => false,
        1 => true,
        else => return error.IntegerOverflow,
    };

    return 1;
}

pub fn write(writer: *Writer, value: bool) !usize {
    try writer.writeByte(if (value) 1 else 0);
    return 1;
}

test read {
    var b: bool = undefined;

    const false_len = try read(&b, &[_]u8{ 0x00, 0x03 });

    try std.testing.expect(!b);
    try std.testing.expectEqual(1, false_len);

    b = undefined;
    const true_len = try read(&b, &[_]u8{ 0x01, 0x03 });

    try std.testing.expect(b);
    try std.testing.expectEqual(1, true_len);
}

test write {
    var buf: [2]u8 = undefined;
    var writer: Writer = .fixed(&buf);

    const firstWrite = try write(&writer, false);
    try std.testing.expectEqual(1, firstWrite);
    try std.testing.expectEqual(0, buf[0]);

    const secondWrite = try write(&writer, true);
    try std.testing.expectEqual(1, secondWrite);
    try std.testing.expectEqual(1, buf[1]);
}
