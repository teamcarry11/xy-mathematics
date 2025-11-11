const std = @import("std");
const RawIO = @import("raw_io.zig");

pub fn write(msg: []const u8) void {
    RawIO.write(msg);
}
