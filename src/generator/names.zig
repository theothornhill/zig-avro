const std = @import("std");

// Handle namespace attributes being overrideable by name
pub const NS = struct {
    namespace: ?[]const u8,
    name: []const u8,
    pub fn resolve(specified_namespace: ?[]const u8, specified_name: []const u8) NS {
        return if (std.mem.lastIndexOfScalar(u8, specified_name, '.')) |i|
            .{ .namespace = specified_name[0..i], .name = specified_name[i + 1 ..] }
        else
            .{ .namespace = specified_namespace, .name = specified_name };
    }
};

pub fn typeName(allocator: std.mem.Allocator, id: []const u8) ![:0]const u8 {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    return if (isValidIdentifier(id))
        try std.fmt.allocPrintSentinel(allocator, "{s}", .{id}, 0)
    else
        try std.fmt.allocPrintSentinel(allocator, "@\"{s}\"", .{id}, 0);
}

fn isValidIdentifier(id: []const u8) bool {
    for (id, 0..) |byte, index| switch (byte) {
        'A'...'Z', '_', 'a'...'z' => {},
        '0'...'9' => if (index == 0) return false,
        else => return false,
    };
    return !std.zig.Token.keywords.has(id);
}
