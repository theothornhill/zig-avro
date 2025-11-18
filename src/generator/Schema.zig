const std = @import("std");
const json = std.json;
const Ast = std.zig.Ast;
const Writer = std.Io.Writer;

const Field = @import("Field.zig");
const Record = @import("Record.zig");
const Default = @import("Default.zig");
const Enum = @import("Enum.zig");
const Array = @import("Array.zig");
const Map = @import("Map.zig");
const Fixed = @import("Fixed.zig");
const Literal = @import("Literal.zig");

pub var SchemaMap: std.StringHashMap(Schema) = .init(std.heap.page_allocator);
fn put(namespace: []const u8, name: []const u8, value: Schema) !void {
    const key = try std.fmt.allocPrint(
        SchemaMap.allocator,
        "{s}.{s}",
        .{ namespace, name },
    );
    try SchemaMap.put(key, value);
}

pub fn get(namespace: []const u8, name: []const u8) !?Schema {
    // Hack to account for names that contain namespace in the literal value
    const key = if (std.mem.containsAtLeast(u8, name, 1, "."))
        try std.fmt.allocPrint(SchemaMap.allocator, "{s}", .{name})
    else
        try std.fmt.allocPrint(SchemaMap.allocator, "{s}.{s}", .{ namespace, name });
    return SchemaMap.get(key);
}

pub const parse_opts: json.ParseOptions = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
};

pub const SchemaType = enum {
    record,
    @"enum",
    array,
    map,
    literal,
    fixed,
    @"union",
};

pub const Schema = union(SchemaType) {
    record: Record,
    @"enum": Enum,
    array: Array,
    map: Map,
    literal: Literal,
    fixed: Fixed,
    @"union": []Schema,

    pub fn jsonParse(
        allocator: std.mem.Allocator,
        src: anytype,
        options: std.json.ParseOptions,
    ) !Schema {
        return jsonParseFromValue(allocator, switch (try src.peekNextTokenType()) {
            .string => return .{
                .literal = .{ .value = try std.json.innerParse([]const u8, allocator, src, options) },
            },
            .object_begin => try std.json.innerParse(json.Value, allocator, src, options),
            else => return error.UnexpectedToken,
        }, options);
    }

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        src: json.Value,
        options: std.json.ParseOptions,
    ) !@This() {
        if (src == .object) {
            const kind = src.object.get("type") orelse return error.MissingField;
            if (kind != .string) return error.UnexpectedToken;
            const tag = std.meta.stringToEnum(SchemaType, kind.string) orelse .literal;
            return switch (tag) {
                .record => .{
                    .record = try std.json.parseFromValueLeaky(Record, allocator, src, options),
                },
                .@"enum" => .{
                    .@"enum" = try std.json.parseFromValueLeaky(Enum, allocator, src, options),
                },
                .array => .{
                    .array = try std.json.parseFromValueLeaky(Array, allocator, src, options),
                },
                .map => .{
                    .map = try std.json.parseFromValueLeaky(Map, allocator, src, options),
                },
                else => .{
                    .literal = .{ .value = kind.string },
                },
            };
        }

        if (src == .string) {
            return .{ .literal = .{ .value = src.string } };
        }

        if (src == .array) {
            return .{ .@"union" = try std.json.parseFromValueLeaky([]Schema, allocator, src, options) };
        }

        return error.UnexpectedToken;
    }

    pub fn decorate(self: *@This(), default_namespace: []const u8) !void {
        switch (self.*) {
            .record => |*r| {
                if (r.namespace == null) r.namespace = default_namespace;
                try put(r.namespace orelse return error.MissingDefaultNamespace, r.name, self.*);
                for (r.fields) |*field| {
                    if (field.namespace == null) field.namespace = r.namespace;
                    try field.type.decorate(r.namespace orelse default_namespace);
                }
            },
            .@"enum" => |*e| {
                if (e.namespace == null) e.namespace = default_namespace;
                try put(e.namespace orelse return error.MissingDefaultNamespace, e.name, self.*);
            },
            .@"union" => |union_members| {
                for (union_members) |*u| {
                    try u.decorate(default_namespace);
                }
            },
            .array => |*a| {
                if (a.namespace == null) a.namespace = default_namespace;
                try a.items.decorate(default_namespace);
            },
            .map => |*m| {
                if (m.namespace == null) m.namespace = default_namespace;
                try m.values.decorate(default_namespace);
            },
            .literal => |*l| {
                if (l.namespace == null) l.namespace = default_namespace;
            },
            .fixed => {},
        }
    }

    test decorate {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var w: Writer.Allocating = .init(allocator);
        defer w.deinit();

        const schema_files = comptime &[_][]const u8{
            @embedFile("./test-files/EventLarge.avsc"),
        };

        const default_ns = comptime &[_][]const u8{
            "no.tv2.sport.resultatservice.avro",
        };

        const schemas = comptime &[_]usize{
            21,
        };

        for (schema_files, default_ns, schemas) |file, ns, num| {
            var schema: Schema = try json.parseFromSliceLeaky(Schema, allocator, file, parse_opts);
            try schema.decorate(ns);
            try std.testing.expectEqual(num, SchemaMap.count());

            try expectNamespacing(&schema);
            SchemaMap.clearRetainingCapacity();
            try w.writer.flush();
            w.clearRetainingCapacity();
        }
    }

    fn namespace(self: @This()) []const u8 {
        return switch (self) {
            .record => |r| r.namespace,
            .@"enum" => |e| e.namespace,
            .array => |a| a.namespace,
            .map => |m| m.namespace,
            .literal => |l| l.namespace,
            else => @panic("Unimplemented namespace()"),
        } orelse @panic("Missing namespace");
    }

    pub fn source(
        self: @This(),
        allocator: std.mem.Allocator,
        comptime top_level: bool,
    ) anyerror![:0]const u8 {
        return try switch (self) {
            .record => |r| r.source(allocator, top_level),
            .@"enum" => |e| e.source(allocator),
            .array => |a| a.source(allocator, top_level),
            .map => |m| m.source(allocator),
            .literal => |l| {
                const schema = try get(
                    self.namespace(),
                    l.value,
                );

                return try if (schema) |s|
                    s.source(allocator, top_level)
                else
                    l.source(allocator);
            },
            .@"union" => |un| {
                if (un.len == 2) {
                    const first = un[0];
                    if (first == .literal) {
                        if (std.mem.eql(u8, first.literal.value, "null")) {
                            if (un[1] == .literal) {
                                const schema = try get(
                                    un[1].namespace(),
                                    un[1].literal.value,
                                ) orelse un[1];

                                return try std.fmt.allocPrintSentinel(allocator, "?{s}", .{
                                    try schema.source(allocator, top_level),
                                }, 0);
                            }
                            return try std.fmt.allocPrintSentinel(allocator, "?{s}", .{
                                try un[1].source(allocator, top_level),
                            }, 0);
                        }
                    }
                }
                var writer: Writer.Allocating = .init(allocator);
                try writer.writer.writeAll("union(enum) { ");
                for (un) |u| {
                    const name = switch (u) {
                        .record => |r| r.name,
                        .literal => |l| l.value,
                        .@"enum" => |e| e.name,
                        else => @panic("Unsupported name for union!"),
                    };

                    // Special case for the null value
                    if (std.mem.eql(u8, "null", name)) {
                        try writer.writer.writeAll("null, ");
                        continue;
                    }

                    const src = try std.fmt.allocPrintSentinel(
                        allocator,
                        "{s}",
                        .{try u.source(allocator, top_level)},
                        0,
                    );

                    try writer.writer.print("{s}: {s}, ", .{ name, src });
                }
                try writer.writer.writeAll("}");
                return try std.fmt.allocPrintSentinel(
                    allocator,
                    "{s}",
                    .{writer.written()},
                    0,
                );
            },
            else => @panic("Unimplemented source()"),
        };
    }

    pub fn render(
        self: *@This(),
        allocator: std.mem.Allocator,
        writer: *Writer,
    ) !void {
        if (self.* != .record) return error.InvalidSchema;

        try writer.writeAll("//! This is a generated file - DO NOT EDIT!\n\n");
        try writer.print("const std = @import(\"std\");\n", .{});
        try writer.print("const avro = @import(\"zig-avro\");\n\n", .{});

        try self.decorate(self.record.namespace orelse return error.MissingDefaultNamespace);
        const src = try self.source(allocator, true);
        var a = try Ast.parse(allocator, src, .zig);
        try a.render(allocator, writer, .{});
    }

    test Schema {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var w: Writer.Allocating = .init(allocator);
        defer w.deinit();

        const schema_files = comptime &[_][]const u8{
            @embedFile("./test-files/EventLarge.avsc"),
        };

        const result_files = comptime &[_][]const u8{
            @embedFile("./test-files/EventLargeTest.zig"),
        };

        const default_ns = comptime &[_][]const u8{
            "no.tv2.sport.resultatservice.avro",
        };

        for (schema_files, result_files, default_ns) |file, expected, _| {
            var schema = try json.parseFromSliceLeaky(Schema, allocator, file, parse_opts);
            try schema.render(allocator, &w.writer);
            try std.testing.expectEqualStrings(expected, w.written());
            try w.writer.flush();
            w.clearRetainingCapacity();
        }
    }
};

pub fn expectNamespacing(schema: *Schema) !void {
    return switch (schema.*) {
        .record => |r| {
            try std.testing.expect(r.namespace != null);
            for (r.fields) |field| {
                try expectNamespacing(field.type);
            }
        },
        .@"enum" => |e| try std.testing.expect(e.namespace != null),
        .array => |a| try expectNamespacing(a.items),
        .map => |m| try expectNamespacing(m.values),
        .literal => {},
        .fixed => {},
        .@"union" => |@"union"| {
            for (@"union") |*u| {
                try expectNamespacing(u);
            }
        },
    };
}

test "parse schemas" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const test_files = comptime &[_][]const u8{
        @embedFile("./test-files/SuperDuperSimple.avsc"),
        @embedFile("./test-files/SuperSimple.avsc"),
        @embedFile("./test-files/Simple.avsc"),
        @embedFile("./test-files/Enum.avsc"),
        @embedFile("./test-files/Array.avsc"),
        @embedFile("./test-files/Map.avsc"),
        @embedFile("./test-files/LivesportEvent.avsc"),
        @embedFile("./test-files/CodiEvent.avsc"),
        @embedFile("./test-files/EventLarge.avsc"),
        @embedFile("./test-files/Incident.avsc"),
    };

    for (test_files) |file| {
        _ = try json.parseFromSlice(Schema, allocator, file, parse_opts);
    }
}

test "verify schema" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const p = try json.parseFromSlice(
        Schema,
        allocator,
        @embedFile("./test-files/Simple.avsc"),
        parse_opts,
    );
    defer p.deinit();

    const record = p.value.record;
    try std.testing.expectEqual(2, record.fields.len);
    try std.testing.expectEqualStrings("A linked list of longs", record.doc.?);
    try std.testing.expectEqualStrings("LongList", record.name);
    try std.testing.expectEqualStrings("some.namespace", record.namespace.?);
}
