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

pub fn encode(comptime T: type, self: *T, writer: *Io.Writer) !usize {
    return try Serialize.write(T, writer, self);
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
