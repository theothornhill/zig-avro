const std = @import("std");
const files = std.fs.File;
const json = std.json;

pub const Default = union(enum) {
    none,
    val: json.Value,

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        const v = std.json.innerParse(json.Value, allocator, source, options) catch |err| switch (err) {
            error.MissingField => return .none,
            else => return err,
        };

        return try jsonParseFromValue(allocator, v, options);
    }

    pub fn jsonParseFromValue(_: std.mem.Allocator, source: json.Value, _: std.json.ParseOptions) !@This() {
        return .{ .val = source };
    }
};

pub const Field = struct {
    name: []const u8,
    doc: ?[]const u8 = null,
    type: *Schema,
    order: ?[]const u8 = "ascending",
    aliases: ?[][]const u8 = null,
    default: Default = .none,

    test "parse obj with null" {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        const allocator = arena.allocator();
        defer arena.deinit();

        const js =
            \\{
            \\  "name": "id",
            \\  "type": "string"
            \\}
        ;

        const p = try json.parseFromSlice(Field, allocator, js, parse_opts);

        try std.testing.expectEqualStrings(p.value.name, "id");
        try std.testing.expect(p.value.default == .none);

        const js2 =
            \\{
            \\  "name": "id",
            \\  "type": "string",
            \\  "default": null
            \\}
        ;

        const p2 = try json.parseFromSlice(Field, allocator, js2, parse_opts);

        try std.testing.expectEqualStrings(p2.value.name, "id");
        try std.testing.expect(p2.value.default.val == .null);
    }
};

pub const Record = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: ?[]const u8 = null,
    aliases: ?[][]const u8 = null,
    fields: []Field,
    default: Default = .none,
};

pub const Enum = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    aliases: ?[][]const u8 = null,
    doc: ?[]const u8 = null,
    symbols: ?[][]const u8 = null,
    default: Default = .none,
};

pub const Array = struct {
    items: *Schema,
    default: Default = .none,
};

pub const Map = struct {
    values: *Schema,
    default: Default = .none,
};

pub const Fixed = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    aliases: ?[][]const u8 = null,
    size: i32,
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
    literal: []const u8,
    fixed: Fixed,

    // Case for field unions for example, like in
    // ```
    // {
    //   "name": "next",
    //   "type": ["null", "LongList"],
    //   "default": "null"
    // }
    // ```
    @"union": []Schema,

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Schema {
        return jsonParseFromValue(allocator, switch (try source.peekNextTokenType()) {
            .string => return .{ .literal = try std.json.innerParse([]const u8, allocator, source, options) },
            .object_begin => try std.json.innerParse(json.Value, allocator, source, options),
            else => return error.UnexpectedToken,
        }, options);
    }

    pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: json.Value, options: std.json.ParseOptions) !@This() {
        if (source == .object) {
            const kind = source.object.get("type") orelse return error.MissingField;
            if (kind != .string) return error.UnexpectedToken;
            const tag = std.meta.stringToEnum(SchemaType, kind.string) orelse .literal;
            return switch (tag) {
                .record => .{ .record = try std.json.parseFromValueLeaky(Record, allocator, source, options) },
                .@"enum" => .{ .@"enum" = try std.json.parseFromValueLeaky(Enum, allocator, source, options) },
                .array => .{ .array = try std.json.parseFromValueLeaky(Array, allocator, source, options) },
                .map => .{ .map = try std.json.parseFromValueLeaky(Map, allocator, source, options) },
                else => .{ .literal = kind.string },
            };
        }

        if (source == .string) {
            return .{ .literal = source.string };
        }

        if (source == .array) {
            return .{ .@"union" = try std.json.parseFromValueLeaky([]Schema, allocator, source, options) };
        }

        return error.UnexpectedToken;
    }
};

pub const parse_opts: json.ParseOptions = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
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

// --------------------------------------------------------------------------------

pub fn IndentedValue(comptime T: type) type {
    return struct {
        t: T,
        indent_level: usize,
    };
}

pub const IndentOptions = struct {
    add_newline_before: bool = true,
    add_newline_after: bool = true,
    indent_level: usize,
};

fn indent(writer: anytype, options: IndentOptions) !void {
    if (options.add_newline_before) try writer.writeByte('\n');
    const char: u8 = ' ';
    const n_chars = 4 * options.indent_level;
    try writer.writeByteNTimes(char, n_chars);
    if (options.add_newline_after) try writer.writeByte('\n');
}

fn formatDefault(
    data: struct { val: Default, ctx: Field },
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    if (data.val == .none) return;

    if (data.ctx.default == .none) return;

    var enum_prefix = switch (data.ctx.default.val) {
        .null => "null",
        .string => |s| if (std.mem.eql(u8, s, "null"))
            "null"
        else if (data.ctx.type.* == .@"enum")
            try std.fmt.allocPrint(std.heap.page_allocator, ".{s}", .{s})
        else
            try std.fmt.allocPrint(std.heap.page_allocator, ".{s}", .{s}),
        else => null,
    };

    switch (data.ctx.type.*) {
        .@"union" => |u| {
            if (u.len > 2) {
                if (std.mem.eql(u8, "null", u[0].literal)) {
                    enum_prefix = try std.fmt.allocPrint(std.heap.page_allocator, ".{s}", .{u[0].literal});
                }
            }
        },
        else => {},
    }

    if (enum_prefix) |ep| {
        const val = data.val;

        if (val == .none) return;

        try writer.print(" = {s}", .{
            switch (val.val) {
                .null => ep,
                .string => ep,
                .array => ".{}", // TODO(Theo): Deal with array with contents
                .object => ".{}", // TODO(Theo): Deal with map with contents
                .bool => "false",
                .integer => "0",
                .float => "0.0",
                else => "null",
            },
        });
    }
}

fn fmtDefault(ty: Default, ctx: Field) std.fmt.Formatter(formatDefault) {
    return .{ .data = .{ .val = ty, .ctx = ctx } };
}

fn formatField(
    data: IndentedValue(Field),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    _ = fmt;
    _ = options;
    try indent(writer, .{
        .indent_level = data.indent_level,
        .add_newline_after = false,
        .add_newline_before = true,
    });

    try writer.print("{s}: {}{},", .{
        data.t.name,
        fmtSchema(data.t.type.*, data.indent_level),
        fmtDefault(data.t.default, data.t),
    });
}

fn fmtField(ty: Field, indent_level: usize) std.fmt.Formatter(formatField) {
    return .{ .data = .{ .t = ty, .indent_level = indent_level } };
}

fn formatFields(
    data: IndentedValue([]Field),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    _ = fmt;
    _ = options;
    for (data.t) |f| {
        try writer.print("{}", .{fmtField(f, data.indent_level)});
    }
}

fn fmtFields(ty: []Field, indent_level: usize) std.fmt.Formatter(formatFields) {
    return .{ .data = .{ .t = ty, .indent_level = indent_level } };
}

fn formatSymbol(
    data: IndentedValue([]const u8),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    _ = fmt;
    _ = options;
    try indent(writer, .{
        .indent_level = data.indent_level,
        .add_newline_after = false,
        .add_newline_before = true,
    });
    try writer.print("{s},", .{
        data.t,
    });
}

fn fmtSymbol(ty: []const u8, indent_level: usize) std.fmt.Formatter(formatSymbol) {
    return .{ .data = .{ .t = ty, .indent_level = indent_level } };
}

fn formatSymbols(
    data: IndentedValue(?[][]const u8),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    _ = fmt;
    _ = options;
    if (data.t) |t| {
        for (t) |f| {
            try writer.print("{}", .{fmtSymbol(f, data.indent_level)});
        }
    }
}

fn fmtSymbols(ty: ?[][]const u8, indent_level: usize) std.fmt.Formatter(formatSymbols) {
    return .{ .data = .{ .t = ty, .indent_level = indent_level } };
}

fn formatDocs(
    data: IndentedValue(?[]const u8),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    _ = options;
    if (data.t) |text| {
        try indent(writer, .{
            .indent_level = data.indent_level,
            .add_newline_after = false,
            .add_newline_before = false,
        });
        if (fmt.len != 1) std.fmt.invalidFmtError(fmt, text);
        const prefix = switch (fmt[0]) {
            'n' => "// ",
            'd' => "/// ",
            '!' => "//! ",
            else => std.fmt.invalidFmtError(fmt, text),
        };
        var iterator = std.mem.splitScalar(u8, text, '\n');
        while (iterator.next()) |line| try writer.print("{s}{s}\n", .{ prefix, line });
    }
}

fn fmtDocs(data: ?[]const u8, indent_level: usize) std.fmt.Formatter(formatDocs) {
    return .{ .data = .{ .t = data, .indent_level = indent_level } };
}

test formatDocs {
    const allocator = std.testing.allocator;
    var arr = std.ArrayList(u8).init(allocator);
    var writer = arr.writer();

    defer arr.deinit();

    try writer.print("{n}", .{fmtDocs("hello", 0)});
    try std.testing.expectEqualStrings("// hello\n", arr.items);
    arr.clearAndFree();

    try writer.print("{d}", .{fmtDocs("hello", 0)});
    try std.testing.expectEqualStrings("/// hello\n", arr.items);
    arr.clearAndFree();

    try writer.print("{d}", .{fmtDocs("This is a long\ndocstring", 0)});
    try std.testing.expectEqualStrings("/// This is a long\n/// docstring\n", arr.items);
    arr.clearAndFree();
}

fn formatSchema(
    data: IndentedValue(Schema),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    _ = options;
    _ = fmt;
    switch (data.t) {
        .record => |r| {
            if (data.indent_level > 0) {
                // Let's just reference the type when nested
                return try writer.print("{p}", .{std.zig.fmtId(r.name)});
            }
            if (r.doc) |docs| try writer.print("{d}", .{fmtDocs(docs, data.indent_level)});
            const format = "pub const {p} = struct {{{}\n}};\n\n";
            try writer.print(format, .{
                std.zig.fmtId(r.name),
                fmtFields(r.fields, data.indent_level + 1),
            });
        },
        .@"enum" => |r| {
            if (data.indent_level > 0) {
                // Let's just reference the type when nested
                return try writer.print("{p}", .{std.zig.fmtId(r.name)});
            }
            if (r.doc) |docs| try writer.print("{d}", .{fmtDocs(docs, data.indent_level)});
            try writer.print("pub const {p} = enum {{{}\n}};\n\n", .{
                std.zig.fmtId(r.name),
                fmtSymbols(r.symbols, data.indent_level + 1),
            });
        },
        .array => |a| {
            if (data.indent_level > 0) {
                return try writer.print("avro.Array({p})", .{fmtSchema(a.items.*, data.indent_level)});
            }
        },
        .map => |m| {
            if (data.indent_level > 0) {
                return try writer.print("avro.Map({p})", .{fmtSchema(m.values.*, data.indent_level)});
            }
        },
        .literal => |l| {
            const v =
                if (std.mem.eql(u8, l, "long"))
                    "i64"
                else if (std.mem.eql(u8, l, "int"))
                    "i32"
                else if (std.mem.eql(u8, l, "null"))
                    "null"
                else if (std.mem.eql(u8, l, "string"))
                    "[]const u8"
                else if (std.mem.eql(u8, l, "bytes"))
                    "[]u8"
                else if (std.mem.eql(u8, l, "double"))
                    "f64"
                else if (std.mem.eql(u8, l, "float"))
                    "f32"
                else if (std.mem.eql(u8, l, "boolean"))
                    "bool"
                else
                    l;

            try writer.writeAll(v);
        },
        .@"union" => |un| {
            if (un.len == 2) {
                // An union of null|Something is considered a nullable, so we
                // use that to our advantage;
                const first = un[0];
                if (first == .literal) {
                    if (std.mem.eql(u8, first.literal, "null")) {
                        return try writer.print("?{}", .{fmtSchema(un[1], data.indent_level)});
                    }
                }
            }
            try writer.writeAll("union(enum) { ");
            for (un) |u| {
                const name = switch (u) {
                    .record => |r| r.name,
                    .literal => |l| l,
                    .@"enum" => |e| e.name,
                    else => @panic("Unsupported name for union!"),
                };

                // Special case for the null value
                if (std.mem.eql(u8, "null", name)) {
                    try writer.writeAll("null, ");
                    continue;
                }
                try writer.print("{s}: {}, ", .{ name, fmtSchema(u, data.indent_level) });
            }
            try writer.writeAll("}");
        },
        else => |e| {
            std.debug.print("Unexpected typeA {}\n", .{e});
            @panic("Unexpected Type");
        },
    }
}

fn fmtSchema(data: Schema, indent_level: usize) std.fmt.Formatter(formatSchema) {
    return .{ .data = .{ .t = data, .indent_level = indent_level } };
}

test "format union in schema" {
    const allocator = std.testing.allocator;
    const p = try json.parseFromSlice(
        Schema,
        allocator,
        @embedFile("./test-files/Simple.avsc"),
        parse_opts,
    );
    defer p.deinit();

    var arr = std.ArrayList(u8).init(allocator);
    var writer = arr.writer();

    defer arr.deinit();

    const expected =
        \\/// A linked list of longs
        \\pub const LongList = struct {
        \\    value: i64,
        \\    next: ?LongList = null,
        \\};
        \\
        \\
    ;

    try writer.print("{n}", .{fmtSchema(p.value, 0)});
    try std.testing.expectEqualStrings(expected, arr.items);
}

test "format more complex union in schema" {
    const allocator = std.testing.allocator;
    const p = try json.parseFromSlice(
        Schema,
        allocator,
        @embedFile("./test-files/RecordWithUnion.avsc"),
        parse_opts,
    );
    defer p.deinit();

    var arr = std.ArrayList(u8).init(allocator);
    var writer = arr.writer();

    defer arr.deinit();

    const expected =
        \\/// A linked list of longs
        \\pub const LongList = struct {
        \\    next: union(enum) { null, LongList1: LongList1, LongList2: LongList2, } = .null,
        \\};
        \\
        \\
    ;

    try writer.print("{n}", .{fmtSchema(p.value, 0)});
    try std.testing.expectEqualStrings(expected, arr.items);
}

fn writeSchema(schema: Schema, map: *std.StringHashMap(Schema), writer: anytype) !void {
    if (schema != .record) return error.NotARecord;

    try writer.print("{!!}\n", .{
        fmtDocs("This is a generated file - DO NOT EDIT!", 0),
    });

    try writer.print("const std = @import(\"std\");\n", .{});
    try writer.print("const avro = @import(\"zig-avro\");\n\n", .{});

    var it = map.iterator();
    while (it.next()) |entry| {
        try writer.print("{}", .{fmtSchema(entry.value_ptr.*, 0)});
    }
}

test writeSchema {
    const allocator = std.testing.allocator;

    const p = try json.parseFromSlice(
        Schema,
        allocator,
        @embedFile("./test-files/Incident.avsc"),
        parse_opts,
    );
    defer p.deinit();

    var arr = std.ArrayList(u8).init(allocator);
    var writer = arr.writer();

    defer arr.deinit();

    const expected = try std.fs.cwd().readFileAlloc(
        allocator,
        "./src/generator/test-files/IncidentTest.zig",
        1_000_000,
    );
    defer allocator.free(expected);

    var map = std.StringHashMap(Schema).init(allocator);
    defer map.deinit();

    try accumulateSchemas(&map, p.value);
    try put(&map, p.value);

    writeSchema(p.value, &map, &writer) catch |err| {
        std.debug.print("\n\nERRRR {}\n\n", .{err});
    };

    try std.testing.expectEqualStrings(expected, arr.items);
}

fn put(map: *std.StringHashMap(Schema), schema: Schema) !void {
    switch (schema) {
        .record => |r| {
            try map.put(r.name, schema);
        },
        .@"enum" => |e| {
            try map.put(e.name, schema);
        },
        .@"union" => |un| {
            for (un) |u| {
                try put(map, u);
            }
        },
        .array => |a| {
            try put(map, a.items.*);
        },
        .map => |m| {
            try put(map, m.values.*);
        },
        .literal => {},
        else => @panic("Unreachable put branch. Unimplemented?"),
    }
}

fn accumulateSchemas(map: *std.StringHashMap(Schema), schema: Schema) !void {
    switch (schema) {
        .record => |r| {
            for (r.fields) |*f| {
                switch (f.type.*) {
                    .array => {
                        try put(map, f.type.*);
                        if (f.type.*.array.items.* != .literal) {
                            try put(map, f.type.*.array.items.*);
                        }

                        try accumulateSchemas(map, f.type.*.array.items.*);
                    },
                    .map => {
                        try put(map, f.type.*);
                        if (f.type.*.map.values.* != .literal) {
                            try put(map, f.type.*.map.values.*);
                        }

                        try accumulateSchemas(map, f.type.*.map.values.*);
                    },
                    .@"enum" => {
                        try put(map, f.type.*);
                        try accumulateSchemas(map, f.type.*);
                    },
                    .record => {
                        try put(map, f.type.*);
                        try accumulateSchemas(map, f.type.*);
                    },
                    .@"union" => |vals| {
                        for (vals) |v| {
                            try put(map, v);
                            try accumulateSchemas(map, v);
                        }
                    },
                    else => continue,
                }
            }
        },
        .literal => {},
        .@"union" => |un| {
            for (un) |u| {
                try put(map, u);
                try accumulateSchemas(map, u);
            }
        },
        else => {
            try put(map, schema);
        },
    }
}

pub const NamespaceSchemas = struct {
    namespace: []const u8,
    main_schema: Schema,
    schemas: std.StringHashMap(Schema),
    out_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, namespace: []const u8, main_schema: Schema, out_path: []const u8) NamespaceSchemas {
        return .{
            .namespace = namespace,
            .main_schema = main_schema,
            .schemas = std.StringHashMap(Schema).init(allocator),
            .out_path = out_path,
        };
    }

    pub fn deinit(self: *NamespaceSchemas) void {
        self.schemas.deinit();
    }
};

pub fn main() !void {
    // Schemas are grouped by namespace into separate files, but we have not
    // yet coded support for generating @import statements to allow schemas
    // to reference enums or records in other namespaces.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    const cwd = std.fs.cwd();

    cwd.makeDir("src/avro") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            std.debug.print("Failed: {}", .{err});
            return err;
        },
    };

    var dir = try cwd.openDir("avro", .{ .iterate = true });
    var it = dir.iterate();

    var namespace_schemas = std.StringHashMap(NamespaceSchemas).init(allocator);
    defer namespace_schemas.deinit();

    while (it.next() catch null) |f| {
        const path = try std.fmt.allocPrint(allocator, "avro/{s}", .{f.name});

        const p = try json.parseFromSlice(
            Schema,
            allocator,
            try cwd.readFileAlloc(allocator, path, 1_000_000),
            parse_opts,
        );

        // Only allow Record as top level for now
        if (p.value != .record) return error.InvalidSchema;

        const namespace = p.value.record.namespace orelse "default"; // Default to "default" if no namespace is given

        const ns_res = try namespace_schemas.getOrPut(namespace);
        if (!ns_res.found_existing) {
            const filename = try std.fmt.allocPrint(allocator, "src/avro/{s}.zig", .{namespace});
            ns_res.value_ptr.* = NamespaceSchemas.init(allocator, namespace, p.value, filename);
        }

        try accumulateSchemas(&ns_res.value_ptr.schemas, p.value);
        try put(&ns_res.value_ptr.schemas, p.value);
    }

    // Write the schemas to each namespace file
    var ns_it = namespace_schemas.iterator();
    while (ns_it.next()) |entry| {
        const ns = entry.value_ptr;

        std.debug.print("Writing namespace: {s} to {s}\n", .{ ns.namespace, ns.out_path });

        var file = try cwd.createFile(ns.out_path, .{});
        defer file.close();

        try writeSchema(ns.main_schema, &ns.schemas, file.writer());
    }
}
