const std = @import("std");

const R = @import("reader.zig");
const W = @import("writer.zig");

pub const Reader = R;
pub const Writer = W;

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
        reader: R.Map(T) = .{},
        iterator: ?Iterator(R.Entry(T)) = null,

        pub fn readOwn(self: *@This(), buf: []const u8) !usize {
            return self.reader.readOwn(buf);
        }

        pub fn next(self: *@This()) !?*R.Entry(T) {
            return try self.reader.next();
        }
    };
}

pub fn Array(comptime T: type) type {
    return struct {
        reader: R.Array(T) = .{},
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

test {
    @import("std").testing.refAllDecls(@This());
}
