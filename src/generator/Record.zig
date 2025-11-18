const std = @import("std");
const Writer = std.Io.Writer;
const Ast = std.zig.Ast;

const s = @import("Schema.zig");
const Schema = s.Schema;
const Field = @import("Field.zig");
const Default = @import("Default.zig").Default;

name: []const u8,
namespace: ?[]const u8 = null,
doc: ?[]const u8 = null,
aliases: ?[][]const u8 = null,
fields: []Field,
default: Default = .none,

const FmtFields = struct {
    fields: []Field,

    pub fn format(self: @This(), allocator: std.mem.Allocator) ![]const u8 {
        var w: Writer.Allocating = .init(allocator);
        for (self.fields) |f| {
            try w.writer.print("{s}\n", .{try f.source(allocator)});
        }
        return w.written();
    }
};

pub fn source(
    self: @This(),
    allocator: std.mem.Allocator,
    comptime top_level: bool,
) ![:0]const u8 {
    const fields = try (FmtFields{ .fields = self.fields }).format(allocator);
    const fmt = if (top_level)
        "{s}"
    else
        "struct {{ {s} }}";

    return try std.fmt.allocPrintSentinel(allocator, fmt, .{fields}, 0);
}

test "Record" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ns = "com.example.record";
    var t1: Schema = .{ .literal = .{ .value = "long", .namespace = ns } };
    const f1: Field = .{
        .name = "field_one",
        .doc = "This is the first field",
        .type = &t1,
        .namespace = ns,
    };
    var t2: Schema = .{ .literal = .{ .value = "int", .namespace = ns } };
    const f2: Field = .{
        .name = "field_two",
        .doc = "This is the second field",
        .type = &t2,
        .namespace = ns,
    };

    var fields: [2]Field = [2]Field{
        f1,
        f2,
    };
    var r: @This() = .{
        .name = "Foo",
        .namespace = ns,
        .doc = "These are some docs",
        .fields = &fields,
    };

    var w: Writer.Allocating = .init(allocator);
    defer w.deinit();

    var schema: Schema = .{ .record = r };
    try s.expectNamespacing(&schema);

    const a = try Ast.parse(allocator, try r.source(allocator, false), .zig);
    try a.render(allocator, &w.writer, .{});
    const expected =
        \\struct {
        \\    field_one: i64,
        \\    field_two: i32,
        \\}
        \\
    ;
    try std.testing.expectEqualStrings(expected, w.written());
}
