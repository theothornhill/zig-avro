const number = @import("number.zig");
const std = @import("std");
const string = @import("string.zig");
const boolean = @import("bool.zig");
const reader = @import("reader.zig");

pub fn write(comptime T: type, v: *T, buf: []u8) ![]const u8 {
    switch (T) {
        bool => return try boolean.write(v.*, buf),
        i32 => return try number.writeInt(v.*, buf),
        i64 => return try number.writeLong(v.*, buf),
        f32 => return try number.writeFloat(v.*, buf),
        f64 => return try number.writeDouble(v.*, buf),
        []const u8 => return try string.write(v.*, buf),
        else => {
            switch (@typeInfo(T)) {
                .@"struct" => {
                    return try writeRecord(T, v, buf);
                },
                else => {},
            }
            @compileError("unsupported field type " ++ @typeName(T));
        },
    }
}

fn writeRecord(comptime R: type, r: *R, buf: []u8) ![]const u8 {
    var written: usize = 0;
    inline for (@typeInfo(R).@"struct".fields) |field|
        written += (try write(field.type, &@field(r, field.name), buf[written..])).len;
    return buf[0..written];
}

test "write record of primitives" {
    const Record = struct {
        happy: bool,
        arms: i32,
        legs: i64,
        width: f32,
        height: f64,
    };
    var writeBuffer: [100]u8 = undefined;
    var buf: []u8 = writeBuffer[0..100];
    var r1: Record = .{
        .happy = true,
        .arms = 1_000_000,
        .legs = 0,
        .width = 5.5,
        .height = 93203291039213.9012,
    };
    const msg1 = try write(Record, &r1, buf);
    var r2: Record = .{
        .happy = false,
        .arms = -2,
        .legs = 0x7fffffff,
        .width = -111111.11111,
        .height = 0.0,
    };
    _ = try write(Record, &r2, buf[msg1.len..]);
    var ro: Record = undefined;
    const rem = try reader.read(Record, &ro, buf);
    try std.testing.expectEqual(r1, ro);
    _ = try reader.read(Record, &ro, rem);
    try std.testing.expectEqual(r2, ro);
}
