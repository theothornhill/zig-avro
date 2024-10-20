const std = @import("std");
const number = @import("number.zig");
const boolean = @import("bool.zig");
const string = @import("string.zig");

pub fn consumeRecord(comptime R: type, r: *R, buf: []const u8) ![]const u8 {
    var rem = buf;
    inline for (
        @typeInfo(R).@"struct".fields,
    ) |field| {
        switch (field.type) {
            bool => rem = try boolean.read(&@field(r, field.name), rem),
            []const u8 => rem = try string.read(&@field(r, field.name), rem),
            else => switch (@typeInfo(field.type)) {
                .@"struct" => {
                    rem = try consumeRecord(field.type, &@field(r, field.name), rem);
                },
                else => {
                    @compileError("unsupported field type " ++ @typeName(field.type));
                },
            },
        }
    }
    return rem;
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
    const rem = try consumeRecord(Record, &r, buf);
    try std.testing.expectEqual(true, r.valid);
    try std.testing.expectEqualStrings("HI", r.message);
    try std.testing.expectEqual(true, r.flags.logged);
    try std.testing.expectEqual(false, r.flags.terrible);
    try std.testing.expectEqual(0, rem.len);
}
