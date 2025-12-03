//! Grain Skate Main Entry Point: Native macOS knowledge graph application.
//!
//! Why: Main entry point for Grain Skate application.
//! Architecture: Application initialization, event loop, window management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const grain_skate = @import("grain_skate");
const Block = grain_skate.Block;
const SkateWindow = grain_skate.SkateWindow;
const GrainSkateApp = grain_skate.GrainSkateApp;
const events = @import("platform/events.zig");

/// Main entry point for Grain Skate application.
pub fn main() void {
    // Wrap in error handler to catch panics.
    mainImpl() catch |err| {
        const err_msg = switch (err) {
            error.OutOfMemory => "Out of memory",
            else => @errorName(err),
        };
        std.debug.print("Error: {s}\n", .{err_msg});
        std.process.exit(1);
    };
}

fn mainImpl() !void {
    std.debug.print("[grain_skate] Starting Grain Skate application...\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("[grain_skate] Allocator initialized.\n", .{});

    // Initialize block storage.
    std.debug.print("[grain_skate] Initializing block storage...\n", .{});
    var block_storage = Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    // Create initial block for testing.
    _ = try block_storage.create_block("Welcome", "Welcome to Grain Skate!\n\nThis is a knowledge graph application.\n\nPress 'i' to enter insert mode.\nPress 'Esc' to return to normal mode.\n\nClick on graph nodes to open blocks for editing.");

    // Initialize window.
    std.debug.print("[grain_skate] Initializing window...\n", .{});
    var window = try SkateWindow.init(allocator, "Grain Skate", 1200, 800);
    defer window.deinit();

    // Initialize application.
    std.debug.print("[grain_skate] Initializing application...\n", .{});
    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    // Load blocks into graph visualization.
    std.debug.print("[grain_skate] Loading blocks into graph...\n", .{});
    app.load_blocks_to_graph();

    // Show window.
    std.debug.print("[grain_skate] Showing window...\n", .{});
    try window.window.show();

    // Render initial graph view.
    std.debug.print("[grain_skate] Rendering initial graph view...\n", .{});
    window.render_graph();
    try window.window.present();

    std.debug.print("[grain_skate] Window ready. Running event loop...\n", .{});
    std.debug.print("[grain_skate] To quit: Close window, press Cmd+Q, or Ctrl+C in terminal\n", .{});

    // Run event loop: blocks until app terminates.
    // This is normal macOS GUI app behavior - the event loop must run to process
    // window events, keyboard input, etc. It will block until the user quits.
    window.window.runEventLoop();

    std.debug.print("[grain_skate] Event loop exited (application terminated).\n", .{});
}

