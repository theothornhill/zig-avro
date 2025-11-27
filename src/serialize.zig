const number = @import("number.zig");
const std = @import("std");
const string = @import("string.zig");
const boolean = @import("bool.zig");
const deserialize = @import("deserialize.zig");
const WriteError = @import("errors.zig").WriteError;
const root = @import("root.zig");
const Writer = std.Io.Writer;

pub fn write(comptime T: type, writer: *Writer, v: *const T) !usize {
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
                    if (@hasDecl(T, "⚙️iterator"))
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

pub fn SliceArray(T: type) type {
    return struct {
        const ThisSliceArray = @This();
        src: []const T,
        @"⚙️len": usize,
        const Iterator = struct {
            pos: usize,
            src: []const T,
            pub fn next(self: *@This()) !?T {
                if (self.pos == self.src.len) return null;
                defer self.pos += 1;
                return self.src[self.pos];
            }
        };
        pub fn @"⚙️iterator"(self: ThisSliceArray) Iterator {
            return .{ .src = self.src, .pos = 0 };
        }
        pub fn from(slice: []const T) ThisSliceArray {
            return .{ .src = slice, .@"⚙️len" = slice.len };
        }
    };
}

// Supports things that quack like std.StringHashMapUnmanaged
pub fn StringMap(Map: type) type {
    return struct {
        pub const Entry = struct { key: []const u8, value: @FieldType(Map.KV, "value") };
        const ThisStringMap = @This();
        src: *const Map,
        @"⚙️len": usize,
        const Iterator = struct {
            it: Map.Iterator,
            entry: Entry = undefined,
            pub fn next(self: *Iterator) !?Entry {
                return if (self.it.next()) |kv|
                    .{ .key = kv.key_ptr.*, .value = kv.value_ptr.* }
                else
                    null;
            }
        };
        pub fn @"⚙️iterator"(self: ThisStringMap) Iterator {
            return .{ .it = self.src.iterator() };
        }
        pub fn from(map: *const Map) ThisStringMap {
            return .{ .src = map, .@"⚙️len" = map.count() };
        }
    };
}

/// We use the ⚙️ symbol in identifiers to differentiate our own
/// parser logic from Avro fields, as they are not valid in Avro field names.
fn writeArray(comptime A: type, writer: *Writer, a: *const A) !usize {
    var pos: usize = 0;
    var it = a.@"⚙️iterator"();
    if (@hasField(A, "⚙️len") and a.@"⚙️len" > 0) {
        pos += try number.writeLong(writer, @as(i64, @intCast(a.@"⚙️len")));
        var count: u64 = 0;
        while (try it.next()) |val| {
            const V = @TypeOf(val);
            count += 1;
            if (count > a.@"⚙️len") return WriteError.ArrayTooLong;
            pos += try write(V, writer, &val);
        }
        if (count < a.@"⚙️len") return WriteError.ArrayTooShort;
    } else {
        while (try it.next()) |val| {
            const V = @TypeOf(val);
            pos += try number.writeInt(writer, 1);
            pos += try write(V, writer, &val);
        }
    }
    try writer.writeByte(0);
    return pos + 1;
}

fn writeOptional(comptime O: type, writer: *Writer, o: *const ?O) !usize {
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

fn writeUnion(comptime U: type, writer: *Writer, u: *const U) !usize {
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

fn writeRecord(comptime R: type, writer: *Writer, r: *const R) !usize {
    var written: usize = 0;
    inline for (@typeInfo(R).@"struct".fields) |field|
        written += try write(field.type, writer, &@field(r, field.name));
    return written;
}

test SliceArray {
    var empty: SliceArray(i32) = .from(&.{});
    try std.testing.expectEqual(empty.@"⚙️len", 0);
    var empty_it = empty.@"⚙️iterator"();
    try std.testing.expectEqual(try empty_it.next(), null);
    var fibbles: SliceArray(i32) = .from(&.{ 0, 1, 1, 3, 5 });
    try std.testing.expectEqual(fibbles.@"⚙️len", 5);
    var fibbles_it = fibbles.@"⚙️iterator"();
    try std.testing.expectEqual((try fibbles_it.next()).?, 0);
    try std.testing.expectEqual((try fibbles_it.next()).?, 1);
    try std.testing.expectEqual((try fibbles_it.next()).?, 1);
    try std.testing.expectEqual((try fibbles_it.next()).?, 3);
    try std.testing.expectEqual((try fibbles_it.next()).?, 5);
    try std.testing.expectEqual(fibbles_it.next(), null);
}

test "write empty arrays" {
    var writeBuffer: [2]u8 = undefined;
    var writer: Writer = .fixed(&writeBuffer);

    const EmptyArray = struct {
        const EmptyIterator = struct {
            pub fn next(_: *EmptyIterator) !?i32 {
                return null;
            }
        };
        pub fn @"⚙️iterator"(_: @This()) EmptyIterator {
            return .{};
        }
    };

    const Record = struct { list: EmptyArray, list2: EmptyArray };
    var r: Record = .{ .list = .{}, .list2 = .{} };
    const out = try write(Record, &writer, &r);
    try std.testing.expectEqual(2, out);
    try std.testing.expectEqual(.{ 0, 0 }, writeBuffer);
}

test "write empty array from helper" {
    var writeBuffer: [2]u8 = .{ 111, 111 };
    var writer: Writer = .fixed(&writeBuffer);

    const Record = struct { list: SliceArray(i32) };
    var r: Record = .{ .list = .from(&.{}) };
    const out = try write(Record, &writer, &r);
    try std.testing.expectEqual(1, out);
    try std.testing.expectEqual(.{ 0, 111 }, writeBuffer);
}

test "write array with unknown length" {
    var writeBuffer: [100]u8 = undefined;
    var writer: Writer = .fixed(&writeBuffer);

    const MyArray = struct {
        const MyIterator = struct {
            pos: usize = 0,
            pub fn next(self: *MyIterator) !?i32 {
                if (self.pos == 2) return null;
                defer self.pos += 1;
                return 1;
            }
        };
        pub fn @"⚙️iterator"(_: @This()) MyIterator {
            return .{};
        }
    };

    const Record = struct { list: MyArray };
    var r: Record = .{ .list = .{} };
    const out = try write(Record, &writer, &r);
    try std.testing.expectEqual(5, out);
}

test "write array with known length" {
    var writeBuffer: [100]u8 = undefined;
    var writer: Writer = .fixed(&writeBuffer);

    const MyArray = struct {
        const MyIterator = struct {
            pos: usize = 0,
            pub fn next(self: *MyIterator) !?i32 {
                if (self.pos == 2) return null;
                defer self.pos += 1;
                return 1;
            }
        };
        @"⚙️len": usize = 2,
        pub fn @"⚙️iterator"(_: @This()) MyIterator {
            return .{};
        }
    };

    const Record = struct { list: MyArray };
    var r: Record = .{ .list = .{} };
    const out = try write(Record, &writer, &r);
    try std.testing.expectEqual(4, out);
}

test "Map iteration" {
    const Properties = std.StringHashMap([]const u8);

    const T = struct {
        properties: StringMap(Properties),
    };

    var propsMap: Properties = .init(std.testing.allocator);
    defer propsMap.deinit();
    try propsMap.put("hello", "world");
    var t: T = .{ .properties = .from(&propsMap) };

    var buf: [100]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    const written = try write(T, &writer, &t);

    try std.testing.expectEqual(14, written);

    try std.testing.expectEqualStrings("hello", buf[2..7]);
    try std.testing.expectEqualStrings("world", buf[8..13]);
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
    const rem = try deserialize.read(Record, &ro, &writeBuffer);
    try std.testing.expectEqual(r1, ro);
    _ = try deserialize.read(Record, &ro, writeBuffer[rem..]);
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
    const rem = try deserialize.read(Record, &ro, &writeBuffer);
    try std.testing.expectEqual(r1, ro);
    _ = try deserialize.read(Record, &ro, writeBuffer[rem..]);
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
    const rem = try deserialize.read(Record, &ro, &buf);
    try std.testing.expectEqual(r1, ro);
    _ = try deserialize.read(Record, &ro, buf[rem..]);
    try std.testing.expectEqual(r2, ro);
}
