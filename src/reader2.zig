const std = @import("std");
const number = @import("number.zig");
const boolean = @import("bool.zig");
const string = @import("string.zig");

pub fn consumeRecord(comptime R: type, r: *R, buf: []const u8) ![]const u8 {
    var rem = buf;
    inline for (@typeInfo(R).@"struct".fields) |field|
        rem = try consume(field.type, &@field(r, field.name), rem);
    return rem;
}

pub fn consume(comptime T: type, v: *T, buf: []const u8) ![]const u8 {
    return switch (T) {
        bool => try boolean.read(v, buf),
        []const u8 => try string.read(v, buf),
        else => switch (@typeInfo(T)) {
            .@"struct" => try consumeRecord(T, v, buf),
            else => @compileError("unsupported field type " ++ @typeName(T)),
        },
    };
}

test "hm" {
    const buf = &[_]u8{
        1, // valid: true
        2 << 1, // message:len 2
        'H',
        'I',
        1, // logged: true
        0, // terrible: false
    };
    const Record = struct {
        valid: bool,
        message: []const u8,
        flags: struct {
            logged: bool,
            terrible: bool,
        },
    };
    var r: Record = undefined;
    const rem = try consume(Record, &r, buf);
    try std.testing.expectEqual(true, r.valid);
    try std.testing.expectEqualStrings("HI", r.message);
    try std.testing.expectEqual(true, r.flags.logged);
    try std.testing.expectEqual(false, r.flags.terrible);
    try std.testing.expectEqual(0, rem.len);
}
