const std = @import("std");
const files = std.fs.File;
const json = std.json;
const Writer = std.Io.Writer;
const Ast = std.zig.Ast;

const Field = @import("Field.zig");
const Record = @import("Record.zig");
const Default = @import("Default.zig").Default;
const Schema = @import("Schema.zig").Schema;

const parse_opts: std.json.ParseOptions = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
};

const CliArgs = struct {
    schemaDir: []const u8 = "avro",
    outputDir: []const u8 = "src/avro",
    pub fn init() CliArgs {
        var args = CliArgs{};
        var it = std.process.args();
        _ = it.next();
        while (it.next()) |arg| {
            var split = std.mem.splitScalar(u8, arg, '=');
            if (split.next()) |key| {
                if (split.next()) |val| {
                    if (std.mem.eql(u8, key, "--schemaDir"))
                        args.schemaDir = val;
                    if (std.mem.eql(u8, key, "--outputDir"))
                        args.outputDir = val;
                }
            }
        }
        return args;
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    const args = CliArgs.init();

    const cwd = std.fs.cwd();

    cwd.makeDir(args.outputDir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            std.debug.print("Failed: {}", .{err});
            return err;
        },
    };

    var dir = try cwd.openDir(args.schemaDir, .{ .iterate = true });
    var it = dir.iterate();

    while (it.next() catch null) |f| {
        const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ args.schemaDir, f.name });

        const input = try cwd.readFileAlloc(allocator, path, 1_000_000);

        var hashbuf: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(input, &hashbuf, .{});
        var p: json.Parsed(Schema) = try json.parseFromSlice(
            Schema,
            allocator,
            input,
            parse_opts,
        );

        if (p.value != .record) return error.InvalidSchema;

        const subpath = try std.fmt.allocPrint(
            allocator,
            "{s}/{x}",
            .{
                args.outputDir,
                hashbuf[0..4],
            },
        );

        try cwd.makePath(subpath);

        const filename = try if (p.value.record.namespace) |ns|
            std.fmt.allocPrint(
                allocator,
                "{s}/{x}/{s}.{s}.zig",
                .{ args.outputDir, hashbuf[0..4], ns, p.value.record.name },
            )
        else
            std.fmt.allocPrint(
                allocator,
                "{s}/{x}/{s}.zig",
                .{ args.outputDir, hashbuf[0..4], p.value.record.name },
            );

        std.debug.print("Writing schema to: {s}\n", .{filename});

        var file = try cwd.createFile(filename, .{});
        defer file.close();

        var file_buffer: [1024]u8 = undefined;
        var w = file.writer(&file_buffer);

        try p.value.render(allocator, &w.interface);
        try w.interface.flush();
    }
}
