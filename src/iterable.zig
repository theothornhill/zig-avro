const std = @import("std");

/// Interface that is satisfied by the Array deserializers, but
/// is dynamic in order to be interchangable with client provided
/// Iterable implementations during seralization.
///
/// Note that due to the library being allocation free and zero-copy,
/// there is only ever one underlying iterator for a data structure.
/// I.e. any call to iterator() will invalidate any previously returned
/// iterator from this iterable.
pub fn Iterable(comptime T: type) type {
    return struct {
        ptr: *anyopaque,
        iteratorFn: *const fn (ptr: *anyopaque) Iterator(T),

        /// Invalidates previously returned iterators
        pub fn iterator(self: *Iterable(T)) Iterator(T) {
            return self.iteratorFn(self.ptr);
        }
    };
}

/// Interface that is satisfied by the Array deserializers, but
/// is dynamic in order to be interchangable with client provided
/// Iterable implementations during seralization.
///
/// Note that due to the library being allocation free and zero-copy,
/// there is only ever one underlying value for a data structure.
/// I.e. any call to next() will invalidate any previously returned
/// value from this iterator.
pub fn Iterator(comptime T: type) type {
    return struct {
        ptr: *anyopaque,
        nextFn: *const fn (ptr: *anyopaque) anyerror!?*T,

        /// Invalidates previously returned items
        pub fn next(self: *@This()) !?*T {
            return self.nextFn(self.ptr);
        }
    };
}

pub fn HashMapWithIterable(comptime MapEntry: type) type {
    const V = std.meta.fieldInfo(MapEntry, .value).type;
    const Ctx = struct {
        stuff: *std.StringHashMap(V) = undefined,
        it: std.StringHashMap(V).Iterator = undefined,
        entry: MapEntry = undefined,
    };
    const Gen = struct {
        pub fn iterator(ptr: *anyopaque) Iterator(MapEntry) {
            var ctx: *Ctx = @ptrCast(@alignCast(ptr));
            ctx.it = ctx.stuff.iterator();
            return .{
                .ptr = ptr,
                .nextFn = @This().next,
            };
        }
        pub fn next(ptr: *anyopaque) !?*MapEntry {
            var ctx: *Ctx = @ptrCast(@alignCast(ptr));
            if (ctx.it.next()) |entry| {
                ctx.entry = .{ .key = entry.key_ptr.*, .value = entry.value_ptr.* };
                return &ctx.entry;
            }
            return null;
        }
    };
    return struct {
        ctx: Ctx = .{},
        map: std.StringHashMap(V),
        pub fn init(allocator: std.mem.Allocator) @This() {
            const m = std.StringHashMap(V).init(allocator);
            return .{ .map = m };
        }
        pub fn deinit(self: *@This()) void {
            self.map.deinit();
        }
        pub fn iterable(self: *@This()) Iterable(MapEntry) {
            self.ctx.stuff = &self.map;
            return .{ .ptr = &self.ctx, .iteratorFn = Gen.iterator };
        }
    };
}

pub fn IterableMappingContext(comptime In: type, comptime Out: type, comptime Mapper: type) type {
    const Ctx = struct {
        mapper: *Mapper = undefined,
        src: *Iterable(In) = undefined,
        srcIt: Iterator(In) = undefined,
        cursor: Out = undefined,
    };
    const Gen = struct {
        pub fn iterator(ptr: *anyopaque) Iterator(Out) {
            var ctx: *Ctx = @ptrCast(@alignCast(ptr));
            ctx.srcIt = ctx.src.iterator();
            return .{
                .ptr = ptr,
                .nextFn = @This().next,
            };
        }
        pub fn next(ptr: *anyopaque) !?*Out {
            var ctx: *Ctx = @ptrCast(@alignCast(ptr));
            if (try ctx.srcIt.next()) |v| {
                try ctx.mapper.map(v, &ctx.cursor);
                return &ctx.cursor;
            }
            return null;
        }
    };
    return struct {
        ctx: Ctx = undefined,
        pub fn iterable(self: *@This(), mapper: *Mapper, src: *Iterable(In)) Iterable(Out) {
            self.ctx = .{ .mapper = mapper, .src = src };
            return .{ .ptr = &self.ctx, .iteratorFn = Gen.iterator };
        }
    };
}

pub fn SliceIterableContext(comptime T: type) type {
    const Ctx = struct {
        items: []T = undefined,
        pos: usize = undefined,
    };
    const Gen = struct {
        pub fn iterator(ptr: *anyopaque) Iterator(T) {
            var ctx: *Ctx = @ptrCast(@alignCast(ptr));
            ctx.pos = 0;
            return .{
                .ptr = ptr,
                .nextFn = @This().next,
            };
        }
        pub fn next(ptr: *anyopaque) !?*T {
            var ctx: *Ctx = @ptrCast(@alignCast(ptr));
            if (ctx.pos > ctx.items.len) return error.SpentIterator;
            defer ctx.pos += 1;
            if (ctx.pos == ctx.items.len) return null;
            const c: *T = &ctx.items[ctx.pos];
            return c;
        }
    };
    return struct {
        ctx: Ctx = undefined,
        pub fn iterable(self: *@This(), items: []T) Iterable(T) {
            self.ctx = .{ .items = items };
            return .{ .ptr = &self.ctx, .iteratorFn = Gen.iterator };
        }
    };
}

test "hashmapiterator" {
    const MapEntry = struct {
        key: []const u8,
        value: i32,
        pub fn enjoy(self: @This()) bool {
            return self.key.len == self.value;
        }
    };
    var hm = HashMapWithIterable(MapEntry).init(std.testing.allocator);
    defer hm.deinit();
    try hm.map.put("cheese", 6);
    var hmi = hm.iterable();
    var it = hmi.iterator();
    try std.testing.expect((try it.next()).?.enjoy());
    try std.testing.expectEqual(null, try it.next());
    try hm.map.put("ham", 3);
    it = hmi.iterator();
    try std.testing.expect((try it.next()).?.enjoy());
    try std.testing.expect((try it.next()).?.enjoy());
    try std.testing.expectEqual(null, try it.next());
}

test "sliceiterable" {
    var ic = SliceIterableContext(i37){};
    var arr = [_]i37{ 1, 1, 3, 5, 8 };
    var i = ic.iterable(&arr);
    var it = i.iterator();
    try std.testing.expectEqual(1, (try it.next()).?.*);
    try std.testing.expectEqual(1, (try it.next()).?.*);
    try std.testing.expectEqual(3, (try it.next()).?.*);
    it = i.iterator();
    try std.testing.expectEqual(1, (try it.next()).?.*);
    try std.testing.expectEqual(1, (try it.next()).?.*);
    try std.testing.expectEqual(3, (try it.next()).?.*);
    try std.testing.expectEqual(5, (try it.next()).?.*);
    try std.testing.expectEqual(8, (try it.next()).?.*);
    try std.testing.expectEqual(null, try it.next());
    try std.testing.expectError(error.SpentIterator, it.next());
}

test "mapping" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const FmtMapper = struct {
        alloc: std.mem.Allocator,
        pub fn map(self: @This(), n: *const i37, m: *[]const u8) !void {
            m.* = try std.fmt.allocPrint(self.alloc, "Number({d})", .{n.*});
        }
    };
    var mapper = FmtMapper{ .alloc = arena.allocator() };
    var srcCtx = SliceIterableContext(i37){};
    var arr = [_]i37{ 1, 1, 3, 5, 8 };
    var src = srcCtx.iterable(&arr);
    var mapCtx = IterableMappingContext(i37, []const u8, FmtMapper){};
    var mapperIterable = mapCtx.iterable(&mapper, &src);
    var it = mapperIterable.iterator();
    try std.testing.expectEqualStrings("Number(1)", (try it.next()).?.*);
    try std.testing.expectEqualStrings("Number(1)", (try it.next()).?.*);
    try std.testing.expectEqualStrings("Number(3)", (try it.next()).?.*);
    try std.testing.expectEqualStrings("Number(5)", (try it.next()).?.*);
    try std.testing.expectEqualStrings("Number(8)", (try it.next()).?.*);
    try std.testing.expectEqual(null, try it.next());
    try std.testing.expectError(error.SpentIterator, it.next());
}

test {
    @import("std").testing.refAllDecls(@This());
}
