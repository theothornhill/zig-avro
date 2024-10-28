const std = @import("std");

const R = @import("reader.zig");
const W = @import("writer.zig");

pub const Reader = R;
pub const Writer = W;

test {
    @import("std").testing.refAllDecls(@This());
}
