const std = @import("std");

// Test what's available in std.io for Zig 0.15.2
pub fn main() !void {
    // Check if std.io exists
    const io = std.io;
    _ = io;
    
    std.debug.print("std.io exists\n", .{});
    
    // Check for common types
    std.debug.print("Checking types...\n", .{});
}
