const std = @import("std");
const TahoeSandbox = @import("tahoe_window.zig").TahoeSandbox;
const crash = @import("aurora_crash.zig");

/// macOS native entry point: deterministic main loop, explicit allocator lifecycle.
/// ~<~ Glow Airbend: avoid Cocoa autorelease pools; Zig owns all memory.
pub fn main() void {
    // Wrap in error handler to catch panics and format crash logs.
    mainImpl() catch |err| {
        const err_msg = switch (err) {
            error.OutOfMemory => "Out of memory",
            else => @errorName(err),
        };
        var msg_buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "Error: {s}", .{err_msg}) catch "Unknown error";
        crash.handlePanic(msg, null);
        std.process.exit(1);
    };
}

fn mainImpl() !void {
    std.debug.print("[tahoe] Starting Tahoe application...\n", .{});
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    std.debug.print("[tahoe] Allocator initialized.\n", .{});

    // Assert: Objective-C runtime should be available on macOS.
    // Note: The runtime initializes automatically when Foundation framework is linked,
    // but we verify it's working by checking if we can get NSObject class.
    std.debug.print("[tahoe] Checking Objective-C runtime...\n", .{});
    const c = @cImport({
        @cInclude("objc/runtime.h");
    });
    const NSObjectClass = c.objc_getClass("NSObject");
    if (NSObjectClass == null) {
        std.debug.panic("Objective-C runtime not initialized. NSObject class not found. Ensure Foundation framework is linked.", .{});
    }
    std.debug.assert(NSObjectClass != null);
    std.debug.print("[tahoe] Objective-C runtime OK (NSObject: 0x{x})\n", .{@intFromPtr(NSObjectClass)});

    std.debug.print("[tahoe] Initializing TahoeSandbox...\n", .{});
    var sandbox = try TahoeSandbox.init(gpa.allocator(), "Grain Aurora");
    defer sandbox.deinit();
    std.debug.print("[tahoe] TahoeSandbox initialized.\n", .{});

    std.debug.print("[tahoe] Showing window...\n", .{});
    try sandbox.show();
    std.debug.print("[tahoe] Window shown.\n", .{});
    
    std.debug.print("[tahoe] Running initial tick...\n", .{});
    try sandbox.tick();
    std.debug.print("[tahoe] Initial tick complete.\n", .{});
    
    // Start animation loop: 60fps continuous updates.
    std.debug.print("[tahoe] Starting animation loop (60fps)...\n", .{});
    sandbox.start_animation_loop();
    std.debug.print("[tahoe] Animation loop started.\n", .{});

    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll("[Aurora] Window ready. Running event loop...\n");
    try stdout.writeAll("[Aurora] To quit: Close window, press Cmd+Q, or Ctrl+C in terminal\n");
    std.debug.print("[tahoe] Starting NSApplication event loop (this will block until app quits)...\n", .{});
    std.debug.print("[tahoe] Window should be visible now. Event loop is running.\n", .{});

    // Run event loop: blocks until app terminates.
    // This is normal macOS GUI app behavior - the event loop must run to process
    // window events, keyboard input, etc. It will block until the user quits.
    sandbox.platform.runEventLoop();
    
    std.debug.print("[tahoe] Event loop exited (application terminated).\n", .{});
}

