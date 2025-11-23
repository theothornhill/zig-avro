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
const names = @import("names.zig");

pub const SerdeType = enum {
    serialize,
    deserialize,
    pub fn invocation(self: SerdeType) [:0]const u8 {
        return switch (self) {
            .serialize =>
            \\pub fn @"⚙️serialize"(self: *const @This(), writer: *std.Io.Writer) !void {
            \\  _ = try avro.Serialize.write(@This(), writer, self);
            \\}
            \\
            ,
            .deserialize =>
            \\pub fn @"⚙️deserialize"(self: *@This(), data: []const u8) !void {
            \\  _ = try avro.Deserialize.read(@This(), self, data);
            \\}
            \\
            ,
        };
    }
};
pub const SourceOptions = struct {
    top_level: bool,
    can_be_typeref: bool,
    serde_type: SerdeType,
    pub fn allowTypeRef(self: SourceOptions) SourceOptions {
        var new = self;
        new.top_level = false;
        new.can_be_typeref = true;
        return new;
    }
    pub fn clearTopLevel(self: SourceOptions) SourceOptions {
        var new = self;
        new.top_level = false;
        return new;
    }
};
pub var SchemaMap: std.StringHashMap(std.StringHashMap(Schema)) = .init(std.heap.page_allocator);
fn put(spec_namespace: ?[]const u8, spec_name: []const u8, value: Schema) !void {
    if (spec_name.len == 0) @panic("no name");
    const ns = names.NS.resolve(spec_namespace, spec_name);
    const gop = try SchemaMap.getOrPut(ns.namespace orelse "");
    if (!gop.found_existing)
        gop.value_ptr.* = .init(SchemaMap.allocator);
    try gop.value_ptr.putNoClobber(ns.name, value);
}

pub fn get(spec_namespace: ?[]const u8, spec_name: []const u8) !?Schema {
    const ns = names.NS.resolve(spec_namespace, spec_name);
    if (SchemaMap.get(ns.namespace orelse "")) |ns_defs| return ns_defs.get(ns.name);
    return null;
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

    pub fn decorate(self: *@This(), inherit_namespace: ?[]const u8) !void {
        const ns = self.resolveNamespace(inherit_namespace);
        switch (self.*) {
            .record => |*r| {
                try put(ns.namespace, ns.name, self.*);
                for (r.fields) |*field|
                    try field.type.decorate(ns.namespace);
            },
            .@"enum" => |*e| {
                e.namespace = e.namespace orelse ns.namespace;
                try put(e.namespace, e.name, self.*);
            },
            .@"union" => |union_members| for (union_members) |*u|
                try u.decorate(ns.namespace),
            .array => |*a| try a.items.decorate(ns.namespace),
            .map => |*m| try m.values.decorate(ns.namespace),
            .literal => |*l| l.namespace = l.namespace orelse ns.namespace,
            .fixed => {},
        }
    }

    test decorate {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        SchemaMap = .init(allocator);

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
            var count: usize = 0;
            var ns_it = SchemaMap.valueIterator();
            while (ns_it.next()) |c_ns|
                count += c_ns.count();
            try std.testing.expectEqual(num, count);

            SchemaMap.clearRetainingCapacity();
            try w.writer.flush();
            w.clearRetainingCapacity();
        }
    }

    fn resolveNamespace(self: @This(), inherit_namespace: ?[]const u8) names.NS {
        return switch (self) {
            .record => |r| names.NS.resolve(r.namespace orelse inherit_namespace, r.name),
            .@"enum" => |e| names.NS.resolve(e.namespace orelse inherit_namespace, e.name),
            .array => |a| a.items.resolveNamespace(inherit_namespace),
            .map => |m| m.values.resolveNamespace(inherit_namespace),
            .literal => |l| names.NS.resolve(l.namespace orelse inherit_namespace, ""),
            .@"union" => |_| names.NS.resolve(inherit_namespace, ""),
            else => @panic("Unimplemented namespace()"),
        };
    }

    pub fn source(
        self: @This(),
        allocator: std.mem.Allocator,
        comptime opts: SourceOptions,
    ) anyerror![:0]const u8 {
        return try switch (self) {
            .record => |r| r.typeRef(allocator, opts),
            .@"enum" => |e| e.typeRef(allocator, opts),
            .array => |a| a.source(allocator, opts),
            .map => |m| m.source(allocator, opts),
            .literal => |l| {
                const schema = try get(l.namespace, l.value);
                return try if (schema) |s|
                    s.source(allocator, opts)
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
                                    un[1].literal.namespace,
                                    un[1].literal.value,
                                ) orelse un[1];

                                return try std.fmt.allocPrintSentinel(allocator, "?{s}", .{
                                    try schema.source(allocator, opts.allowTypeRef()),
                                }, 0);
                            }
                            return try std.fmt.allocPrintSentinel(allocator, "?{s}", .{
                                try un[1].source(allocator, opts.allowTypeRef()),
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
                        .{try u.source(allocator, opts.allowTypeRef())},
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
        comptime serdeType: SerdeType,
    ) !void {
        // This generator is only for schemas with a top level record
        if (self.* != .record) return error.UnsupportedSchema;
        // Default namespace is not used inside the generated file
        self.record.namespace = null;

        try writer.writeAll("//! This is a generated file - DO NOT EDIT!\n\n");
        try writer.print("const std = @import(\"std\");\n", .{});
        try writer.print("const avro = @import(\"zig-avro\");\n\n", .{});

        var a = try Ast.parse(allocator, serdeType.invocation(), .zig);
        try a.render(allocator, writer, .{});
        try writer.print("\n", .{});

        SchemaMap.clearRetainingCapacity();
        try self.decorate(null);

        const baseOpts: SourceOptions = .{
            .top_level = true,
            .can_be_typeref = false,
            .serde_type = serdeType,
        };
        const src = try self.source(allocator, baseOpts);
        a = try Ast.parse(allocator, src, .zig);
        try a.render(allocator, writer, .{});

        var ns_it = SchemaMap.iterator();
        while (ns_it.next()) |ns_entry| {
            var ns_aw: Writer.Allocating = .init(allocator);
            defer ns_aw.deinit();
            var ns_writer = &ns_aw.writer;

            const namespaced = ns_entry.key_ptr.len > 0;
            if (namespaced) try ns_writer.print("const @\"{s}\" = struct {{\n", .{ns_entry.key_ptr.*});
            var n_it = ns_entry.value_ptr.iterator();
            while (n_it.next()) |n_entry| {
                try ns_writer.print("const {f} = ", .{std.zig.fmtId(n_entry.key_ptr.*)});
                const r_src = try n_entry.value_ptr.source(allocator, baseOpts.clearTopLevel());
                try ns_writer.writeAll(r_src);
                try ns_writer.print(";\n", .{});
            }
            if (namespaced) try ns_writer.print("}};\n\n", .{});

            const ns_src = try ns_aw.toOwnedSliceSentinel(0);
            defer allocator.free(ns_src);
            a = try Ast.parse(allocator, ns_src, .zig);
            try a.render(allocator, writer, .{});
        }
        try writer.flush();
    }

    test Schema {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        SchemaMap = .init(allocator);

        var w: Writer.Allocating = .init(allocator);
        defer w.deinit();

        const schema_files = comptime &[_][]const u8{
            @embedFile("./test-files/EventLarge.avsc"),
        };

        const result_files = comptime &[_][]const u8{
            @embedFile("./test-files/EventLargeTest.zig"),
        };

        for (schema_files, result_files) |file, expected| {
            var schema = try json.parseFromSliceLeaky(Schema, allocator, file, parse_opts);
            try schema.render(allocator, &w.writer, .deserialize);
            try std.testing.expectEqualStrings(expected, w.written());
            try w.writer.flush();
            w.clearRetainingCapacity();
        }
    }
};

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
