const std = @import("std");

pub const Deserialize = @import("deserialize.zig");
pub const Serialize = @import("serialize.zig");
pub const Generator = @import("generator/generator.zig");

test "array example from readme" {
    const FootballTeam = struct {
        name: []const u8,
        player_ids: Serialize.SliceArray(i32),
    };

    var buf: [50]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    var t = FootballTeam{
        .name = "Zig Avro Oldboys",
        .player_ids = .from(&.{ 11, 23, 99, 45, 22, 84, 92, 88, 24, 1, 8 }),
    };

    const written = try Serialize.write(FootballTeam, &writer, &t);

    try std.testing.expectEqualStrings("Avro", buf[5..9]);
    try std.testing.expectEqual(34, written);
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
