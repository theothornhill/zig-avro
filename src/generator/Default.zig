const std = @import("std");
const json = std.json;

const schema = @import("Schema.zig");
const SchemaType = schema.SchemaType;

pub const Default = union(enum) {
    none,
    val: json.Value,

    pub fn jsonParse(
        allocator: std.mem.Allocator,
        src: anytype,
        options: std.json.ParseOptions,
    ) !@This() {
        const v = std.json.innerParse(
            json.Value,
            allocator,
            src,
            options,
        ) catch |err| switch (err) {
            error.MissingField => return .none,
            else => return err,
        };

        return try jsonParseFromValue(allocator, v, options);
    }

    pub fn jsonParseFromValue(
        _: std.mem.Allocator,
        src: json.Value,
        _: std.json.ParseOptions,
    ) !@This() {
        return .{ .val = src };
    }

    pub fn source(
        self: @This(),
        schema_type: SchemaType,
        comptime opts: schema.SourceOptions,
    ) ![:0]const u8 {
        return switch (self) {
            .none => "",
            .val => |v| switch (v) {
                .null => " = null",
                .string => |s| if (std.mem.eql(u8, s, "null"))
                    " = null"
                else if (schema_type == .@"enum")
                    try std.fmt.allocPrintSentinel(std.heap.page_allocator, " = .{s}", .{s}, 0)
                else
                    try std.fmt.allocPrintSentinel(std.heap.page_allocator, " = \"{s}\"", .{s}, 0),
                .bool => " = false",
                .integer => " = 0",
                .float => " = 0.0",
                .object => switch (opts.serde_type) {
                    .deserialize => " = .{}",
                    .serialize => " = .from(&.empty)",
                },
                .array => switch (opts.serde_type) {
                    .deserialize => " = .{}",
                    .serialize => " = .from(&.{})",
                },
                else => " = null",
            },
        };
    }
};
