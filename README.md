# zig-avro

## Examples

### Read into struct

```zig
const std = @import("std");
const avro = @import("zig-avro");

const Record = struct { b: bool = false };

const buf = &[_]u8{1}; // Buffer containing boolean `true`

var r: Record = undefined;

_ = try avro.read(Record, &r, buf);

try std.testing.expect(r.b);
```

### Write struct into bytes

```zig
const std = @import("std");
const avro = @import("zig-avro");

const Record = struct { b: bool = false };

var buf: [10]u8 = undefined;

var r = Record{ .b = true };

_ = try write(Record, &r, &buf);

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

