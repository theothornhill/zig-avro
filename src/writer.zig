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
                .@"enum" => return try writeEnum(T, v.*, buf),
                .@"union" => return try writeUnion(T, v, buf),
                .pointer => return try writeFixed(v.*.len, v.*, buf),
                .optional => |opt| return try writeOptional(opt.child, v, buf),
                else => {},
            }
            @compileError("unsupported field type " ++ @typeName(T));
        },
    }
}

fn writeOptional(comptime O: type, o: *?O, buf: []u8) ![]const u8 {
    if (o.*) |v| {
        buf[0] = 2;
        const out = try write(O, @constCast(&v), buf[1..]);
        return buf[0..(1 + out.len)];
    }
    buf[0] = 0;
    return buf[0..1];
}

fn writeFixed(len: comptime_int, v: *[len]u8, buf: []u8) ![]const u8 {
    @memcpy(buf[0..len], v);
    return buf[0..len];
}

fn writeUnion(comptime U: type, u: *U, buf: []u8) ![]const u8 {
    const tagId: i32 = @intFromEnum(u.*);
    inline for (@typeInfo(U).@"union".fields, 0..) |tag, id| {
        if (tagId == id) {
            const wTag = try number.writeInt(tagId, buf);
            if (tag.type == void)
                return buf[0..wTag.len];
            const wVal = try write(tag.type, &@field(u, tag.name), buf[wTag.len..]);
            return buf[0..(wTag.len + wVal.len)];
        }
    }
    unreachable;
}

fn writeEnum(comptime E: type, e: E, buf: []u8) ![]const u8 {
    return try number.writeInt(@as(i32, @intFromEnum(e)), buf);
}

fn writeRecord(comptime R: type, r: *R, buf: []u8) ![]const u8 {
    var written: usize = 0;
    inline for (@typeInfo(R).@"struct".fields) |field|
        written += (try write(field.type, &@field(r, field.name), buf[written..])).len;
    return buf[0..written];
}

test "write optional" {
    var writeBuffer: [100]u8 = undefined;
    const Record = struct { troolean: ?bool };
    var r: Record = .{ .troolean = null };
    const out = try write(Record, &r, writeBuffer[0..100]);
    try std.testing.expectEqual(1, out.len);
    try std.testing.expectEqual(0, out[0]);
    r.troolean = true;
    const out2 = try write(Record, &r, writeBuffer[0..100]);
    try std.testing.expectEqual(2, out2.len);
    try std.testing.expectEqual(2, out2[0]);
    try std.testing.expectEqual(1, out2[1]);
}

test "write fixed" {
    var writeBuffer: [100]u8 = undefined;
    var txt: [7]u8 = undefined;
    @memcpy(&txt, "Bonjour");
    const Record = struct { fixed: *[7]u8 };
    var r: Record = .{ .fixed = &txt };
    const out = try write(Record, &r, writeBuffer[0..100]);
    try std.testing.expectEqual(7, out.len);
    try std.testing.expectEqualStrings("Bonjour", (writeBuffer)[0..out.len]);
}

test "write record with union" {
    const Temperature = union(enum) {
        unmeasured,
        celsius: f32,
    };
    const Record = struct {
        measurement: Temperature,
    };
    var writeBuffer: [100]u8 = undefined;
    var buf: []u8 = writeBuffer[0..100];
    var r1: Record = .{
        .measurement = .unmeasured,
    };
    const msg1 = try write(Record, &r1, buf);
    var r2: Record = .{
        .measurement = Temperature{ .celsius = 37.5 },
    };
    _ = try write(Record, &r2, buf[msg1.len..]);
    var ro: Record = undefined;
    const rem = try reader.read(Record, &ro, buf);
    try std.testing.expectEqual(r1, ro);
    _ = try reader.read(Record, &ro, rem);
    try std.testing.expectEqual(r2, ro);
}

test "write record with enum" {
    const Language = enum {
        zig,
        go,
        rust,
        java,
    };
    const Record = struct {
        cool: Language,
        cooler: Language,
    };
    var writeBuffer: [100]u8 = undefined;
    var buf: []u8 = writeBuffer[0..100];
    var r1: Record = .{
        .cool = .go,
        .cooler = .rust,
    };
    const msg1 = try write(Record, &r1, buf);
    var r2: Record = .{
        .cool = .rust,
        .cooler = .zig,
    };
    _ = try write(Record, &r2, buf[msg1.len..]);
    var ro: Record = undefined;
    const rem = try reader.read(Record, &ro, buf);
    try std.testing.expectEqual(r1, ro);
    _ = try reader.read(Record, &ro, rem);
    try std.testing.expectEqual(r2, ro);
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
