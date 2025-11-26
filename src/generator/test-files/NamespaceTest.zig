//! This is a generated file - DO NOT EDIT!

const std = @import("std");
const avro = @import("zig-avro");

pub fn @"⚙️deserialize"(self: *@This(), data: []const u8) !void {
    _ = try avro.Deserialize.read(@This(), self, data);
}

toe: @"name.spaced".Toe,
const Bone = struct {
    toe: @"namespaced.Toe",
};
const @"name.spaced" = struct {
    const Toe = struct {
        size: i64,
    };
};
