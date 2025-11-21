const std = @import("std");

pub const Deserialize = @import("deserialize.zig");
pub const Serialize = @import("serialize.zig");

pub const iter = @import("iterable.zig");
pub const Generator = @import("generator/generator.zig");

const Io = std.Io;

test "array example from readme" {
    const FootballTeam = struct {
        name: []const u8,
        player_ids: Serialize.SliceArray(i32),
    };

    var buf: [50]u8 = undefined;
    var writer: Io.Writer = .fixed(&buf);

    var t = FootballTeam{
        .name = "Zig Avro Oldboys",
        .player_ids = .from(&.{ 11, 23, 99, 45, 22, 84, 92, 88, 24, 1, 8 }),
    };

    const written = try Serialize.write(FootballTeam, &writer, &t);

    try std.testing.expectEqualStrings("Avro", buf[5..9]);
    try std.testing.expectEqual(34, written);
}

// test "map of 2" {
//     var m: Map(i32) = undefined;
//     const buf = &[_]u8{
//         2 << 1, // array block length 2
//         1 << 1, // string(len 1)
//         'A',
//         4 << 1, // number 4
//         2 << 1, // string(len 2)
//         'B',
//         'C',
//         5 << 1, // number 5
//         0, // array end
//     };
//     _ = try Deserialize.read(Map(i32), &m, buf);
//     var arri = m.array.iterable.iterator();
//     var i = (try arri.next()).?;
//     try std.testing.expectEqual(4, i.value);
//     try std.testing.expectEqualStrings("A", i.key);
//     i = (try arri.next()).?;
//     try std.testing.expectEqual(5, i.value);
//     try std.testing.expectEqualStrings("BC", i.key);
// }

test "Map iteration" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const Properties = std.StringHashMap([]const u8);

    const T = struct {
        properties: Serialize.StringMap(Properties),
    };

    var propsMap: Properties = .init(allocator);
    defer propsMap.deinit();
    try propsMap.put("hello", "world");
    var t: T = .{ .properties = .from(&propsMap) };

    var buf: [100]u8 = undefined;
    var writer: Io.Writer = .fixed(&buf);

    const written = try encode(T, &t, &writer);

    try std.testing.expectEqual(14, written);

    try std.testing.expectEqualStrings("hello", buf[2..7]);
    try std.testing.expectEqualStrings("world", buf[8..13]);
}

pub fn encode(comptime T: type, self: *T, writer: *Io.Writer) !usize {
    return try Serialize.write(T, writer, self);
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
