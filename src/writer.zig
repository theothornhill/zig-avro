const number = @import("number.zig");
const std = @import("std");
const string = @import("string.zig");
const boolean = @import("bool.zig");
const reader = @import("reader.zig");
const WriteError = @import("errors.zig").WriteError;
const root = @import("root.zig");

pub fn write(comptime T: type, writer: anytype, v: *T) !usize {
    switch (T) {
        bool => return try boolean.write(writer, v.*),
        i32 => return try number.writeInt(writer, v.*),
        i64 => return try number.writeLong(writer, v.*),
        f32 => return try number.writeFloat(writer, v.*),
        f64 => return try number.writeDouble(writer, v.*),
        []const u8 => return try string.write(writer, v.*),
        else => {
            switch (@typeInfo(T)) {
                .@"struct" => {
                    if (@hasField(T, "iterator")) {
                        var it = v.iterator orelse return error.ArrayTooShort;
                        return try writeArray(@TypeOf(it), writer, &it);
                    }

                    if (@hasDecl(T, "next")) {
                        return try writeArray(T, writer, v);
                    }

                    return try writeRecord(T, writer, v);
                },
                .@"enum" => return try writeEnum(T, writer, v.*),
                .@"union" => return try writeUnion(T, writer, v),
                .pointer => return try writeFixed(v.*.len, writer, v.*),
                .optional => |opt| return try writeOptional(opt.child, writer, v),
                else => {},
            }
            @compileError("unsupported field type " ++ @typeName(T));
        },
    }
}

fn writeArray(comptime A: type, writer: anytype, a: *A) !usize {
    var pos: usize = 0;
    if (@hasField(A, "len")) {
        pos += try number.writeLong(writer, @as(i64, a.len));
        var count: u64 = 0;
        while (try a.next()) |*val| {
            const V = @TypeOf(val.*);
            count += 1;
            if (count > a.len) return WriteError.ArrayTooLong;
            pos += try write(V, writer, @constCast(val));
        }
        if (count < a.len) return WriteError.ArrayTooShort;
    } else {
        while (try a.next()) |*val| {
            const V = @TypeOf(val.*);
            pos += try number.writeInt(writer, 1);
            pos += try write(V, writer, @constCast(val));
        }
    }
    try writer.writeByte(0);
    return pos + 1;
}

fn writeOptional(comptime O: type, writer: anytype, o: *?O) !usize {
    if (o.*) |*v| {
        try writer.writeByte(2);
        return 1 + try write(O, writer, v);
    }
    try writer.writeByte(0);
    return 1;
}

fn writeFixed(len: comptime_int, writer: anytype, v: *[len]u8) !usize {
    return try writer.write(v);
}

fn writeUnion(comptime U: type, writer: anytype, u: *U) !usize {
    const tagId: i32 = @intFromEnum(u.*);
    inline for (@typeInfo(U).@"union".fields, 0..) |tag, id| {
        if (tagId == id) {
            const wTag = try number.writeInt(writer, tagId);
            if (tag.type == void)
                return wTag;
            const wVal = try write(tag.type, writer, &@field(u, tag.name));
            return wTag + wVal;
        }
    }
    unreachable;
}

fn writeEnum(comptime E: type, writer: anytype, e: E) !usize {
    return try number.writeInt(writer, @as(i32, @intFromEnum(e)));
}

fn writeRecord(comptime R: type, writer: anytype, r: *R) !usize {
    var written: usize = 0;
    inline for (@typeInfo(R).@"struct".fields) |field|
        written += try write(field.type, writer, &@field(r, field.name));
    return written;
}

test "write array" {
    var writeBuffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&writeBuffer);
    var writer = fbs.writer();

    const Record = struct {
        list: struct {
            itemsLeft: u4,
            pub fn next(self: *@This()) !?i32 {
                if (self.itemsLeft == 0) return null;
                self.itemsLeft -= 1;
                return 1;
            }
        },
    };
    var r: Record = undefined;
    r.list.itemsLeft = 2;
    const out = try write(Record, &writer, &r);
    try std.testing.expectEqual(5, out);
}

test "write array with known length" {
    var buf: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var writer = fbs.writer();

    const Record = struct {
        list: struct {
            len: u4,
            yielded: u4,
            pub fn next(self: *@This()) !?i32 {
                if (self.yielded == self.len) return null;
                self.yielded += 1;
                return 1;
            }
        },
    };
    var r: Record = undefined;
    r.list.len = 2;
    r.list.yielded = 0;
    const out = try write(Record, &writer, &r);
    try std.testing.expectEqual(4, out);
}

test "write optional" {
    var writeBuffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&writeBuffer);
    var writer = fbs.writer();

    const Record = struct { troolean: ?bool };
    var r: Record = .{ .troolean = null };
    var written = try write(Record, &writer, &r);
    try std.testing.expectEqual(1, written);
    try std.testing.expectEqual(0, writeBuffer[0]);
    r.troolean = true;

    fbs.reset();
    written = try write(Record, &writer, &r);
    try std.testing.expectEqual(2, written);
    try std.testing.expectEqual(2, writeBuffer[0]);
    try std.testing.expectEqual(1, writeBuffer[1]);
}

test "write fixed" {
    var writeBuffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&writeBuffer);
    var writer = fbs.writer();

    var txt: [7]u8 = undefined;
    @memcpy(&txt, "Bonjour");
    const Record = struct { fixed: *[7]u8 };
    var r: Record = .{ .fixed = &txt };
    const out = try write(Record, &writer, &r);
    try std.testing.expectEqual(7, out);
    try std.testing.expectEqualStrings("Bonjour", (writeBuffer)[0..out]);
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
    var fbs = std.io.fixedBufferStream(&writeBuffer);
    var writer = fbs.writer();

    var r1: Record = .{
        .measurement = .unmeasured,
    };
    _ = try write(Record, &writer, &r1);
    var r2: Record = .{
        .measurement = Temperature{ .celsius = 37.5 },
    };
    _ = try write(Record, &writer, &r2);
    var ro: Record = undefined;
    const rem = try reader.read(Record, &ro, &writeBuffer);
    try std.testing.expectEqual(r1, ro);
    _ = try reader.read(Record, &ro, writeBuffer[rem..]);
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
    var fbs = std.io.fixedBufferStream(&writeBuffer);
    var writer = fbs.writer();

    var r1: Record = .{
        .cool = .go,
        .cooler = .rust,
    };
    _ = try write(Record, &writer, &r1);

    var r2: Record = .{
        .cool = .rust,
        .cooler = .zig,
    };
    _ = try write(Record, &writer, &r2);
    var ro: Record = undefined;
    const rem = try reader.read(Record, &ro, &writeBuffer);
    try std.testing.expectEqual(r1, ro);
    _ = try reader.read(Record, &ro, writeBuffer[rem..]);
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
    var buf: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var writer = fbs.writer();
    var r1: Record = .{
        .happy = true,
        .arms = 1_000_000,
        .legs = 0,
        .width = 5.5,
        .height = 93203291039213.9012,
    };
    _ = try write(Record, &writer, &r1);

    var r2: Record = .{
        .happy = false,
        .arms = -2,
        .legs = 0x7fffffff,
        .width = -111111.11111,
        .height = 0.0,
    };
    _ = try write(Record, &writer, &r2);
    var ro: Record = undefined;
    const rem = try reader.read(Record, &ro, &buf);
    try std.testing.expectEqual(r1, ro);
    _ = try reader.read(Record, &ro, buf[rem..]);
    try std.testing.expectEqual(r2, ro);
}
