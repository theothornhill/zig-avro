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
