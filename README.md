# zig-avro

## Examples

### Deserialize

```zig
pub const ReadLol = struct {
    foo: bool,
    bar: bool,

    const Self = @This();

    pub const ReadError = avro.Reader.ReadError || error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    fn read(self: *Self, buf: []u8) !usize {
        return try avro.Reader.read(Self, self, buf);
    }
};

test "foo" {
    var buf: [2]u8 = .{0x1, 0x0};
    const r: ReadLol = undefined;
    _ = try r.reader().read(&buf);

    try std.testing.expectEqual(true, r.foo);
    try std.testing.expectEqual(false, r.bar);
}
```

### Serialize

The library takes a writer, so as long as you can supply a proper writer,
`zig-avro` should be able to output its payload.

```zig
const std = @import("std");
const avro = @import("zig-avro");

const Record = struct { b: bool = false };

var buf: [10]u8 = undefined;
var fbs = std.io.fixedBufferStream(&buf);
var writer = fbs.writer();

var r = Record{ .b = true };

const written = try r.write(&writer);

try std.testing.expectEqual(1, buf[0]);
```



## How to generate structs

We assume you have `.avsc` files in a directory called `avro` in root.

In `build.zig`:
```zig

    const @"zig-avro" = b.dependency("zig-avro", .{
        .target = target,
        .optimize = optimize,
    });


    var avrogen = b.addRunArtifact(@"zig-avro".artifact("generator"));

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

