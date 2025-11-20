const std = @import("std");
const browser_mod = @import("browser.zig");

// Grainscape - Main Entry Point
// The native browser for Grain OS

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Print banner
    std.debug.print(
        \\
        \\  +========================================================================+
        \\  |                          GRAINSCAPE v0.1.0                           |
        \\  |                    The Grain OS Native Browser                       |
        \\  +========================================================================+
        \\
        \\
    , .{});
    
    // Initialize browser
    const config = browser_mod.BrowserConfig{
        .viewport_width = 75,
        .viewport_height = 20,
    };
    
    var browser = try browser_mod.Browser.init(allocator, config);
    defer browser.deinit();
    
    // Navigate to welcome page
    std.debug.print("Navigating to grain://welcome...\n\n", .{});
    try browser.navigate("grain://welcome");
    
    // Render viewport (to a buffer then print)
    var buf: std.ArrayList(u8) = .{
        .items = &.{},
        .capacity = 0,
    };
    defer buf.deinit(allocator);
    
    try browser.render_viewport(buf.writer(allocator));
    std.debug.print("{s}\n", .{buf.items});
    
    std.debug.print("\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  (In future: interactive mode with navigation)\n", .{});
    std.debug.print("  For now: demonstrating text rendering\n", .{});
}
