const std = @import("std");
const Writer = std.Io.Writer;
const Ast = std.zig.Ast;

const Default = @import("Default.zig").Default;
const names = @import("names.zig");

name: []const u8,
namespace: ?[]const u8 = null,
aliases: ?[][]const u8 = null,
doc: ?[]const u8 = null,
symbols: ?[][]const u8 = null,
default: Default = .none,

const FmtSymbols = struct {
    symbols: ?[][]const u8,

    pub fn format(
        self: @This(),
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var w: Writer.Allocating = .init(allocator);
        if (self.symbols) |symbols| {
            for (symbols) |sym| {
                try w.writer.print("{s},", .{sym});
            }
        }
        return w.written();
    }
};

pub fn source(self: @This(), allocator: std.mem.Allocator) ![:0]const u8 {
    const symbols = try (FmtSymbols{ .symbols = self.symbols }).format(allocator);
    return try std.fmt.allocPrintSentinel(
        allocator,
        "enum {{ {s} }}",
        .{symbols},
        0,
    );
}

pub fn typeRef(
    self: @This(),
    allocator: std.mem.Allocator,
) ![:0]const u8 {
    if (self.name.len > 0) {
        return if (self.namespace) |ns|
            try std.fmt.allocPrintSentinel(
                allocator,
                "@\"{s}\".{s}",
                .{ ns, try names.typeName(allocator, self.name) },
                0,
            )
        else
            try names.typeName(allocator, self.name);
    }

    return self.source(allocator);
}

test "Enum" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var symbols: [2][]const u8 = [_][]const u8{ "ONE", "TWO" };
    var e: @This() = .{ .name = "Foo", .namespace = "com.example.record", .doc = "These are some docs", .symbols = &symbols };

    var w: Writer.Allocating = .init(allocator);
    defer w.deinit();

    const a = try Ast.parse(allocator, try e.source(allocator), .zig);
    try a.render(allocator, &w.writer, .{});
    const expected =
        \\enum {
        \\    ONE,
        \\    TWO,
        \\}
        \\
    ;
    try std.testing.expectEqualStrings(expected, w.written());
}
