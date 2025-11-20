const std = @import("std");
const Ast = std.zig.Ast;
const Writer = std.Io.Writer;

const Record = @import("Record.zig");
const Schema = @import("Schema.zig").Schema;
const Default = @import("Default.zig").Default;

items: *Schema,
default: Default = .none,
namespace: ?[]const u8 = null,

pub fn source(
    self: @This(),
    allocator: std.mem.Allocator,
    comptime top_level: bool,
) ![:0]const u8 {
    const default = if (self.default == .none) "" else " = .{}";
    return try std.fmt.allocPrintSentinel(
        allocator,
        "avro.Array({s}){s}",
        .{ try self.items.source(allocator, top_level, true), default },
        0,
    );
}

test "Array" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var schema: Schema = .{
        .literal = .{ .value = "string", .namespace = "lol" },
    };
    var arr: @This() = .{ .items = &schema, .default = .{ .val = .null } };

    var w: Writer.Allocating = .init(allocator);
    defer w.deinit();

    const a = try Ast.parse(allocator, try arr.source(allocator, false), .zig);
    try a.render(allocator, &w.writer, .{});
    const expected =
        \\avro.Array([]const u8) = .{}
        \\
    ;
    try std.testing.expectEqualStrings(expected, w.written());
}
