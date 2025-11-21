const std = @import("std");
const Writer = std.Io.Writer;
const Ast = std.zig.Ast;

const s = @import("Schema.zig");
const Schema = s.Schema;
const Default = @import("Default.zig").Default;

values: *Schema,
namespace: ?[]const u8 = null,

pub fn source(self: @This(), allocator: std.mem.Allocator, comptime opts: s.SourceOptions) ![:0]const u8 {
    return try switch (opts.serde_type) {
        .deserialize => std.fmt.allocPrintSentinel(
            allocator,
            "avro.Deserialize.Map({s})",
            .{
                try self.values.source(allocator, opts.allowTypeRef()),
            },
            0,
        ),
        .serialize => std.fmt.allocPrintSentinel(
            allocator,
            "avro.Serialize.StringMap(std.StringHashMapUnmanaged({s}))",
            .{
                try self.values.source(allocator, opts.allowTypeRef()),
            },
            0,
        ),
    };
}

test "Serialize Map" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var schema: Schema = .{ .literal = .{ .value = "int", .namespace = "lol" } };
    var arr: @This() = .{ .values = &schema };

    var w: Writer.Allocating = .init(allocator);
    defer w.deinit();

    const opts: s.SourceOptions = .{
        .can_be_typeref = false,
        .serde_type = .serialize,
        .top_level = false,
    };
    const a = try Ast.parse(allocator, try arr.source(allocator, opts), .zig);
    try a.render(allocator, &w.writer, .{});
    const expected =
        \\avro.Serialize.StringMap(std.StringHashMapUnmanaged(i32))
        \\
    ;
    try std.testing.expectEqualStrings(expected, w.written());
}

test "Deserialize Map" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var schema: Schema = .{ .literal = .{ .value = "int", .namespace = "lol" } };
    var arr: @This() = .{ .values = &schema };

    var w: Writer.Allocating = .init(allocator);
    defer w.deinit();

    const opts: s.SourceOptions = .{
        .can_be_typeref = false,
        .serde_type = .deserialize,
        .top_level = false,
    };
    const a = try Ast.parse(allocator, try arr.source(allocator, opts), .zig);
    try a.render(allocator, &w.writer, .{});
    const expected =
        \\avro.Deserialize.Map(i32)
        \\
    ;
    try std.testing.expectEqualStrings(expected, w.written());
}
