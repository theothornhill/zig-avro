# zig-avro

## Examples

### Decode

```zig
pub const ReadLol = struct {
    foo: bool,
    bar: bool,
};

test "foo" {
    var buf: [2]u8 = .{0x1, 0x0};
    var r: ReadLol = undefined;
    _ = try avro.Deserializer.read(ReadLol &r, &buf);

    try std.testing.expectEqual(true, r.foo);
    try std.testing.expectEqual(false, r.bar);
}
```

### Encode

The library takes a writer, so as long as you can supply a proper writer,
`zig-avro` should be able to output its payload.

```zig
const std = @import("std");
const avro = @import("zig-avro");

const Record = struct { b: bool = false };

var buf: [10]u8 = undefined;
var writer: Serializer = .fixed(&buf);

var r = Record{ .b = true };

const written = try avro.Serialize.write(Record, &writer, &r);

try std.testing.expectEqual(1, buf[0]);
```

For Arrays or Maps, you need to provide a type that defines `⚙️iterator()`.
If your source data is available as a slice `[]const T`, you can use the
provided `SliceArray`:
```zig
const std = @import("std");
const avro = @import("zig-avro");

const FootballTeam = struct {
    name: []const u8,
    player_ids: avro.Serialize.SliceArray(i32),
};

var buf: [50]u8 = undefined;
var writer: std.Io.Writer = .fixed(&buf);

var t = FootballTeam{
    .name = "Zig Avro Oldboys",
    .player_ids = .from(&.{ 11, 23, 99, 45, 22, 84, 92, 88, 24, 1, 8 }),
};

const written = try avro.Serialize.write(FootballTeam, &writer, &t);

try std.testing.expectEqualStrings("Avro", buf[5..9]);
try std.testing.expectEqual(34, written);
```

If your source data is available in a `std.StringHashMapUnmanaged(T)` (or something
that quacks the same, like `std.StringArrayHashMap(T)`), you can use the
provided `StringMap`:
```zig
const std = @import("std");
const avro = @import("zig-avro");

const Properties = std.StringHashMap([]const u8);
const T = struct {
    properties: avro.Serialize.StringMap(Properties),
};

var propsMap: Properties = .init(std.testing.allocator);
defer propsMap.deinit();
try propsMap.put("hello", "world");
var t: T = .{ .properties = .from(&propsMap) };

var buf: [100]u8 = undefined;
var writer: std.Io.Writer = .fixed(&buf);

const written = try avro.Serialize.write(T, &writer, &t);

try std.testing.expectEqualStrings("hello", buf[2..7]);
try std.testing.expectEqualStrings("world", buf[8..13]);
try std.testing.expectEqual(14, written);
```

## How to generate structs

We assume you have `.avsc` files in a directory called `avro` in the current working directory.

In `build.zig`:
```zig
    const @"zig-avro" = b.dependency("zig-avro", .{
        .target = target,
        .optimize = optimize,
    });


    var avrogen = b.addRunArtifact(@"zig-avro".artifact("generator"));
    avrogen.addArg("--schemaDir=avro");
    avrogen.addArg("--outputDir=src/avro");

    b.getInstallStep().dependOn(&avrogen.step);
```

or from cli (after building the binary included from building this lib):

```sh
./zig-out/bin/avro_generator
```

Then the files will be located in `src/avro`. This path is hard coded for the time being.

## Avro spec
- [1.12.0](https://avro.apache.org/docs/1.12.0/)

## Related docs
- [On zig-zag encoding](https://protobuf.dev/programming-guides/encoding/)

