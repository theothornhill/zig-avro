const std = @import("std");
const Ast = std.zig.Ast;
const Writer = std.Io.Writer;

const Record = @import("Record.zig");
const s = @import("Schema.zig");
const Schema = s.Schema;
const Default = @import("Default.zig").Default;

items: *Schema,
namespace: ?[]const u8 = null,

pub fn source(
    self: @This(),
    allocator: std.mem.Allocator,
    comptime opts: s.SourceOptions,
) ![:0]const u8 {
    return try switch (opts.serde_type) {
        .deserialize => std.fmt.allocPrintSentinel(
            allocator,
            "avro.Deserialize.Array({s})",
            .{
                try self.items.source(allocator, opts.allowTypeRef()),
            },
            0,
        ),
        .serialize => std.fmt.allocPrintSentinel(
            allocator,
            "avro.Serialize.SliceArray({s})",
            .{
                try self.items.source(allocator, opts.allowTypeRef()),
            },
            0,
        ),
    };
}

test "Serialize Array" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var schema: Schema = .{
        .literal = .{ .value = "string", .namespace = "lol" },
    };
    var arr: @This() = .{ .items = &schema };

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
        \\avro.Serialize.SliceArray([]const u8)
        \\
    ;
    try std.testing.expectEqualStrings(expected, w.written());
}

test "Deserialize Array" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var schema: Schema = .{
        .literal = .{ .value = "string", .namespace = "lol" },
    };
    var arr: @This() = .{ .items = &schema };

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
        \\avro.Deserialize.Array([]const u8)
        \\
    ;
    try std.testing.expectEqualStrings(expected, w.written());
}
