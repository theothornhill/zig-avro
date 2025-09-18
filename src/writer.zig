const number = @import("number.zig");
const std = @import("std");
const string = @import("string.zig");
const boolean = @import("bool.zig");
const reader = @import("reader.zig");
const WriteError = @import("errors.zig").WriteError;
const root = @import("root.zig");
const iter = @import("iterable.zig");
const Writer = std.Io.Writer;


pub fn write(comptime T: type, writer: *Writer, v: *T) !usize {
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
                    if (@hasField(T, "array"))
                        return try writeArray(@TypeOf(v.array), writer, &v.array);
                    if (@hasField(T, "iterable"))
                        return try writeArray(T, writer, v);
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

fn writeArray(comptime A: type, writer: *Writer, a: *A) !usize {
    var pos: usize = 0;
    var it = a.iterable.iterator();
    if (@hasField(A, "len")) {
        pos += try number.writeLong(writer, @as(i64, @intCast(a.len)));
        var count: u64 = 0;
        while (try it.next()) |val| {
            const V = @typeInfo(@TypeOf(val)).pointer.child;
            count += 1;
            if (count > a.len) return WriteError.ArrayTooLong;
            pos += try write(V, writer, val);
        }
        if (count < a.len) return WriteError.ArrayTooShort;
    } else {
        while (try it.next()) |val| {
            const V = @typeInfo(@TypeOf(val)).pointer.child;
            pos += try number.writeInt(writer, 1);
            pos += try write(V, writer, val);
        }
    }
    try writer.writeByte(0);
    return pos + 1;
}

fn writeOptional(comptime O: type, writer: *Writer, o: *?O) !usize {
    if (o.*) |*v| {
        try writer.writeByte(2);
        return 1 + try write(O, writer, v);
    }
    try writer.writeByte(0);
    return 1;
}

fn writeFixed(len: comptime_int, writer: *Writer, v: *[len]u8) !usize {
    return try writer.write(v);
}

fn writeUnion(comptime U: type, writer: *Writer, u: *U) !usize {
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

fn writeEnum(comptime E: type, writer: *Writer, e: E) !usize {
    return try number.writeInt(writer, @as(i32, @intFromEnum(e)));
}

fn writeRecord(comptime R: type, writer: *Writer, r: *R) !usize {
    var written: usize = 0;
    inline for (@typeInfo(R).@"struct".fields) |field|
        written += try write(field.type, writer, &@field(r, field.name));
    return written;
}

test "write array with unknown length" {
    var writeBuffer: [100]u8 = undefined;
    var writer: Writer = .fixed(&writeBuffer);

    const Record = struct {
        list: struct {
            iterable: iter.Iterable(i32),
        },
    };
    var nums = [_]i32{ 1, 1 };
    var numsItCtx = iter.SliceIterableContext(i32){};
    var r = Record{ .list = .{ .iterable = numsItCtx.iterable(&nums) } };
    const out = try write(Record, &writer, &r);
    try std.testing.expectEqual(5, out);
}

test "write array with known length" {
    var buf: [100]u8 = undefined;
    var writer: Writer = .fixed(&buf);

    const Record = struct {
        list: struct {
            len: usize = 2,
            iterable: iter.Iterable(i32),
        },
    };
    var nums = [_]i32{ 1, 1 };
    var numsItCtx = iter.SliceIterableContext(i32){};
    var r = Record{ .list = .{ .iterable = numsItCtx.iterable(&nums) } };
    const out = try write(Record, &writer, &r);
    try std.testing.expectEqual(4, out);
}

test "write optional" {
    var writeBuffer: [100]u8 = undefined;
    var writer: Writer = .fixed(&writeBuffer);

    const Record = struct { troolean: ?bool };
    var r: Record = .{ .troolean = null };
    var written = try write(Record, &writer, &r);
    try std.testing.expectEqual(1, written);
    try std.testing.expectEqual(0, writeBuffer[0]);
    r.troolean = true;

    _ = writer.consumeAll();
    written = try write(Record, &writer, &r);
    try std.testing.expectEqual(2, written);
    try std.testing.expectEqual(2, writeBuffer[0]);
    try std.testing.expectEqual(1, writeBuffer[1]);
}

test "write fixed" {
    var writeBuffer: [100]u8 = undefined;
    var writer: Writer = .fixed(&writeBuffer);

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
    var writer: Writer = .fixed(&writeBuffer);

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
    var writer: Writer = .fixed(&writeBuffer);

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
    var writer: Writer = .fixed(&buf);
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
