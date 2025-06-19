const std = @import("std");

pub const Reader = @import("reader.zig");
pub const Writer = @import("writer.zig");

pub const iter = @import("iterable.zig");
pub const Generator = @import("generator/generator.zig");

pub fn Map(comptime T: type) type {
    return struct {
        array: Array(Entry) = .{},

        pub const Entry = struct {
            key: []const u8,
            value: T,

            pub fn deserialize(self: *@This(), buf: []const u8) !usize {
                const n = try Reader.read([]const u8, &self.key, buf);
                return n + try Reader.read(T, &self.value, buf[n..]);
            }
        };

        pub fn deserialize(self: *@This(), buf: []const u8) !usize {
            return self.array.deserialize(buf);
        }
    };
}

test "map of 2" {
    var m: Map(i32) = undefined;
    const buf = &[_]u8{
        2 << 1, // array block length 2
        1 << 1, // string(len 1)
        'A',
        4 << 1, // number 4
        2 << 1, // string(len 2)
        'B',
        'C',
        5 << 1, // number 5
        0, // array end
    };
    _ = try Reader.read(Map(i32), &m, buf);
    var arri = m.array.iterable.iterator();
    var i = (try arri.next()).?;
    try std.testing.expectEqual(4, i.value);
    try std.testing.expectEqualStrings("A", i.key);
    i = (try arri.next()).?;
    try std.testing.expectEqual(5, i.value);
    try std.testing.expectEqualStrings("BC", i.key);
}

test "Map iteration" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const Properties = Map([]const u8);
    const T = struct {
        properties: Properties = .{},
    };

    var t = T{};
    var hmi = iter.HashMapWithIterable(Properties.Entry).init(allocator);
    try hmi.map.put("hello", "world");
    const propIterable = hmi.iterable();
    t.properties.array.iterable = propIterable;

    var buf: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var writer = fbs.writer();

    const written = try encode(T, &t, &writer);

    try std.testing.expectEqual(14, written);

    try std.testing.expectEqualStrings("hello", buf[2..7]);
    try std.testing.expectEqualStrings("world", buf[8..13]);
}

pub fn Array(comptime T: type) type {
    return struct {
        reader: Reader.Array(T) = .{},
        iterable: iter.Iterable(T) = Noterator(T).iterable(),
        pub fn deserialize(self: *@This(), buf: []const u8) !usize {
            const n = try self.reader.deserialize(buf);
            self.iterable = self.reader.iterable();
            return n;
        }
    };
}

fn Noterator(comptime T: type) type {
    return struct {
        pub fn iterable() iter.Iterable(T) {
            return iter.Iterable(T){ .ptr = @constCast(@ptrCast(&0)), .iteratorFn = @This().iterator };
        }
        pub fn iterator(_: *anyopaque) iter.Iterator(T) {
            return iter.Iterator(T){ .ptr = @constCast(@ptrCast(&0)), .nextFn = @This().next };
        }
        pub fn next(_: *anyopaque) !?*T {
            return error.NoIterator;
        }
    };
}

test "uninitialized iterators are bad" {
    var a: Array(i32) = .{};
    var it = a.iterable.iterator();
    try std.testing.expectError(error.NoIterator, it.next());
}

pub fn encode(comptime T: type, self: *T, writer: anytype) !usize {
    return try Writer.write(T, writer, self);
}

test {
    @import("std").testing.refAllDecls(@This());
}
