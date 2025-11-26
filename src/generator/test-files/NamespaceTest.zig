//! This is a generated file - DO NOT EDIT!

const std = @import("std");
const avro = @import("zig-avro");

pub fn @"⚙️deserialize"(self: *@This(), data: []const u8) !void {
    _ = try avro.Deserialize.read(@This(), self, data);
}

toe: @"name.spaced".Toe,
pub const @"name.spaced" = struct {
    pub const Toe = struct {
        size: i64,
    };
};
