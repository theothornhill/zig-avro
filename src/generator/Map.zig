const std = @import("std");
const Writer = std.Io.Writer;
const Ast = std.zig.Ast;

const Schema = @import("Schema.zig").Schema;
const Default = @import("Default.zig").Default;

values: *Schema,
default: Default = .none,
namespace: ?[]const u8 = null,

pub fn source(self: @This(), allocator: std.mem.Allocator) ![:0]const u8 {
    const default = if (self.default == .none) "" else " = .{}";

    return try std.fmt.allocPrintSentinel(
        allocator,
        "avro.Map({s}){s}",
        .{ try self.values.source(allocator, false, true), default },
        0,
    );
}

test "Map" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var schema: Schema = .{ .literal = .{ .value = "int", .namespace = "lol" } };
    var arr: @This() = .{ .values = &schema, .default = .{ .val = .null } };

    var w: Writer.Allocating = .init(allocator);
    defer w.deinit();

    const a = try Ast.parse(allocator, try arr.source(allocator), .zig);
    try a.render(allocator, &w.writer, .{});
    const expected =
        \\avro.Map(i32) = .{}
        \\
    ;
    try std.testing.expectEqualStrings(expected, w.written());
}
