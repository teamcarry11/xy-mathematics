const std = @import("std");

// Graincard Generator
// Main entry point for 75x100 graincard generation

pub const types = @import("graincard/types.zig");
pub const layout = @import("graincard/layout.zig");
pub const ecology = @import("graincard/ecology.zig");
pub const cli = @import("graincard/cli.zig");
pub const png_generator = @import("graincard/png_generator.zig");
pub const font8x8 = @import("graincard/font8x8.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try cli.run(allocator);
}
