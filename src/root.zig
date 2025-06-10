const std = @import("std");

pub const Reader = @import("reader.zig");
pub const Writer = @import("writer.zig");

pub const Generator = @import("generator/generator.zig");

pub fn CreateIterator(
    comptime IteratorType: type,
    comptime Mapper: type,
    arena: std.mem.Allocator,
    u: Mapper,
) IteratorType {
    // It's expected to clean up this memory using an arena.
    const uu = arena.create(Mapper) catch @panic("OOM");
    uu.* = u;

    return .{ .iterator = uu.iterator() };
}

pub fn Map(comptime T: type) type {
    return struct {
        reader: Array(Entry) = .{},
        iterator: ?Iterator(Entry) = null,

        pub const Entry = struct {
            key: []const u8,
            value: T,

            pub fn readOwn(self: *@This(), buf: []const u8) !usize {
                const n = try Reader.read([]const u8, &self.key, buf);
                return n + try Reader.read(T, &self.value, buf[n..]);
            }

        };

        pub fn readOwn(self: *@This(), buf: []const u8) !usize {
            return self.reader.readOwn(buf);
        }

        pub fn next(self: *@This()) !?*Entry {
            return try self.reader.next();
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
    var i = (try m.next()).?;
    try std.testing.expectEqual(4, i.value);
    try std.testing.expectEqualStrings("A", i.key);
    i = (try m.next()).?;
    try std.testing.expectEqual(5, i.value);
    try std.testing.expectEqualStrings("BC", i.key);
}

test "Map iteration" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const Properties = struct {
        pub const Entry = Map([]const u8).Entry;

        entries: []Entry,
        pos: usize = 0,

        pub fn next(self: *@This()) !?Entry {
            if (self.pos == self.entries.len)
                return null;
            const val = self.entries[self.pos];
            self.pos += 1;
            return val;
        }

        pub fn iterator(self: *@This()) Iterator(Entry) {
            return Iterator(Entry).init(self);
        }
    };

    var xs = std.ArrayList(Properties.Entry).init(allocator);
    (try xs.addOne()).* = Properties.Entry{ .key = "hello", .value = "world" };

    const T = struct {
        properties: Map([]const u8),
    };

    var t: T = .{
        .properties = CreateIterator(
            Map([]const u8),
            Properties,
            allocator,
            .{ .entries = xs.items },
        ),
    };

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
        iterator: ?Iterator(T) = null,

        pub fn readOwn(self: *@This(), buf: []const u8) !usize {
            return self.reader.readOwn(buf);
        }

        pub fn next(self: *@This()) !?*T {
            return try self.reader.next();
        }
    };
}

pub fn Iterator(comptime T: type) type {
    return struct {
        ptr: *anyopaque,
        nextFn: *const fn (ptr: *anyopaque) anyerror!?T,

        pub fn init(ptr: anytype) Iterator(T) {
            const U = @TypeOf(ptr);
            const ptr_info = @typeInfo(U);

            const gen = struct {
                pub fn next(pointer: *anyopaque) !?T {
                    const self: U = @ptrCast(@alignCast(pointer));
                    return ptr_info.pointer.child.next(self);
                }
            };

            return .{
                .ptr = ptr,
                .nextFn = gen.next,
            };
        }

        pub fn next(self: *Iterator(T)) !?T {
            return self.nextFn(self.ptr);
        }
    };
}

pub fn encode(comptime T: type, self: *T, writer: anytype) !usize {
    return try Writer.write(T, writer, self);
}

test {
    @import("std").testing.refAllDecls(@This());
}
