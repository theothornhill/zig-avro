const std = @import("std");
const Writer = std.Io.Writer;
const Ast = std.zig.Ast;

const Schema = @import("Schema.zig").Schema;
const Default = @import("Default.zig").Default;

name: []const u8,
doc: ?[]const u8 = null,
type: *Schema,
order: ?[]const u8 = "ascending",
aliases: ?[][]const u8 = null,
default: Default = .none,
namespace: ?[]const u8 = null,

pub fn source(self: @This(), allocator: std.mem.Allocator) ![:0]const u8 {
    return try std.fmt.allocPrintSentinel(allocator, "{s}: {s}{s},", .{
        self.name,
        try self.type.source(allocator, false),
        try self.default.source(self.type.*),
    }, 0);
}

test "Field" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var t: Schema = .{
        .literal = .{ .value = "string", .namespace = "lol" },
    };
    const f: @This() = .{
        .name = "field_foo",
        .doc = "These are some field docs",
        .type = &t,
    };

    var w: Writer.Allocating = .init(allocator);
    defer w.deinit();

    const a = try Ast.parse(allocator, try f.source(allocator), .zig);
    try a.render(allocator, &w.writer, .{});

    const expected =
        \\field_foo: []const u8,
        \\
    ;
    try std.testing.expectEqualStrings(expected, w.written());
}
