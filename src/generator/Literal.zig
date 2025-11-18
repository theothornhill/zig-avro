const std = @import("std");

value: []const u8,
namespace: ?[]const u8 = null,

pub fn source(self: @This(), allocator: std.mem.Allocator) ![:0]const u8 {
    const v =
        if (std.mem.eql(u8, self.value, "long"))
            "i64"
        else if (std.mem.eql(u8, self.value, "int"))
            "i32"
        else if (std.mem.eql(u8, self.value, "null"))
            "null"
        else if (std.mem.eql(u8, self.value, "string"))
            "[]const u8"
        else if (std.mem.eql(u8, self.value, "bytes"))
            "[]u8"
        else if (std.mem.eql(u8, self.value, "double"))
            "f64"
        else if (std.mem.eql(u8, self.value, "float"))
            "f32"
        else if (std.mem.eql(u8, self.value, "boolean"))
            "bool"
        else
            std.fmt.allocPrint(allocator, "{s}", .{self.value}) catch @panic("OOMLOL");

    return try std.fmt.allocPrintSentinel(allocator, "{s}", .{v}, 0);
}
