//! Tests for Aurora Cocoa module.
//!
//! Why: Verify Cocoa/macOS integration functionality (menu entries,
//! window configuration, app lifecycle).
//! Architecture: Comprehensive test coverage for macOS Cocoa integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-23-165214-PST: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const MenuEntry = @import("aurora_cocoa").MenuEntry;
const WindowConfig = @import("aurora_cocoa").WindowConfig;
const App = @import("aurora_cocoa").App;

test "cocoa menu entry structure" {
    const entry = MenuEntry{
        .title = "File",
        .action = null,
    };
    
    // Assert: Menu entry structure initialized
    std.debug.assert(std.mem.eql(u8, entry.title, "File"));
    std.debug.assert(entry.action == null);
}

test "cocoa menu entry with action" {
    const entry = MenuEntry{
        .title = "New",
        .action = "new_file",
    };
    
    // Assert: Menu entry with action initialized
    std.debug.assert(std.mem.eql(u8, entry.title, "New"));
    std.debug.assert(std.mem.eql(u8, entry.action.?, "new_file"));
}

test "cocoa window config default title" {
    const config = WindowConfig{};
    
    // Assert: Default title is "Aurora"
    std.debug.assert(std.mem.eql(u8, config.title, "Aurora"));
    std.debug.assert(config.menu.len == 0);
}

test "cocoa window config custom title" {
    const config = WindowConfig{
        .title = "My App",
        .menu = &.{},
    };
    
    // Assert: Custom title set
    std.debug.assert(std.mem.eql(u8, config.title, "My App"));
    std.debug.assert(config.menu.len == 0);
}

test "cocoa window config with menu" {
    const menu_entries = [_]MenuEntry{
        .{ .title = "File", .action = null },
        .{ .title = "Edit", .action = null },
    };
    
    const config = WindowConfig{
        .title = "Aurora",
        .menu = &menu_entries,
    };
    
    // Assert: Menu entries set
    std.debug.assert(config.menu.len == 2);
    std.debug.assert(std.mem.eql(u8, config.menu[0].title, "File"));
    std.debug.assert(std.mem.eql(u8, config.menu[1].title, "Edit"));
}

test "cocoa app initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = WindowConfig{
        .title = "Test App",
        .menu = &.{},
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Assert: App initialized correctly
    std.debug.assert(std.mem.eql(u8, app.config.title, "Test App"));
    std.debug.assert(app.config.menu.len == 0);
}

test "cocoa app initialization with menu" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const menu_entries = [_]MenuEntry{
        .{ .title = "File", .action = null },
        .{ .title = "Edit", .action = "edit_action" },
        .{ .title = "View", .action = null },
    };
    
    const config = WindowConfig{
        .title = "Aurora IDE",
        .menu = &menu_entries,
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Assert: App initialized with menu
    std.debug.assert(std.mem.eql(u8, app.config.title, "Aurora IDE"));
    std.debug.assert(app.config.menu.len == 3);
    std.debug.assert(std.mem.eql(u8, app.config.menu[0].title, "File"));
    std.debug.assert(std.mem.eql(u8, app.config.menu[1].title, "Edit"));
    std.debug.assert(std.mem.eql(u8, app.config.menu[2].title, "View"));
    std.debug.assert(app.config.menu[1].action != null);
    std.debug.assert(std.mem.eql(u8, app.config.menu[1].action.?, "edit_action"));
}

test "cocoa app deinitialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = WindowConfig{
        .title = "Test App",
        .menu = &.{},
    };
    
    var app = try App.init(arena.allocator(), config);
    app.deinit();
    
    // Assert: App deinitialized (no crash)
}

test "cocoa app present with empty menu" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = WindowConfig{
        .title = "Empty Menu App",
        .menu = &.{},
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: App presented successfully
}

test "cocoa app present with single menu entry" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const menu_entries = [_]MenuEntry{
        .{ .title = "File", .action = null },
    };
    
    const config = WindowConfig{
        .title = "Single Menu App",
        .menu = &menu_entries,
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: App presented successfully
}

test "cocoa app present with multiple menu entries" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const menu_entries = [_]MenuEntry{
        .{ .title = "Aurora", .action = null },
        .{ .title = "File", .action = "file_action" },
        .{ .title = "Edit", .action = null },
        .{ .title = "View", .action = "view_action" },
        .{ .title = "Window", .action = null },
    };
    
    const config = WindowConfig{
        .title = "Multi Menu App",
        .menu = &menu_entries,
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: App presented successfully
    std.debug.assert(app.config.menu.len == 5);
}

test "cocoa app present with menu entries with actions" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const menu_entries = [_]MenuEntry{
        .{ .title = "New", .action = "new_file" },
        .{ .title = "Open", .action = "open_file" },
        .{ .title = "Save", .action = "save_file" },
    };
    
    const config = WindowConfig{
        .title = "Actions Menu App",
        .menu = &menu_entries,
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: All menu entries have actions
    std.debug.assert(app.config.menu[0].action != null);
    std.debug.assert(app.config.menu[1].action != null);
    std.debug.assert(app.config.menu[2].action != null);
}

test "cocoa app present with menu entries without actions" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const menu_entries = [_]MenuEntry{
        .{ .title = "File", .action = null },
        .{ .title = "Edit", .action = null },
        .{ .title = "View", .action = null },
    };
    
    const config = WindowConfig{
        .title = "No Actions Menu App",
        .menu = &menu_entries,
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: All menu entries have no actions
    std.debug.assert(app.config.menu[0].action == null);
    std.debug.assert(app.config.menu[1].action == null);
    std.debug.assert(app.config.menu[2].action == null);
}

test "cocoa app present with mixed menu entries" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const menu_entries = [_]MenuEntry{
        .{ .title = "File", .action = null },
        .{ .title = "New", .action = "new_file" },
        .{ .title = "Edit", .action = null },
        .{ .title = "Save", .action = "save_file" },
    };
    
    const config = WindowConfig{
        .title = "Mixed Menu App",
        .menu = &menu_entries,
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: Mixed menu entries handled correctly
    std.debug.assert(app.config.menu[0].action == null);
    std.debug.assert(app.config.menu[1].action != null);
    std.debug.assert(app.config.menu[2].action == null);
    std.debug.assert(app.config.menu[3].action != null);
}

test "cocoa app multiple instances" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config_1 = WindowConfig{
        .title = "App 1",
        .menu = &.{},
    };
    
    const config_2 = WindowConfig{
        .title = "App 2",
        .menu = &.{ .{ .title = "File", .action = null } },
    };
    
    var app_1 = try App.init(arena.allocator(), config_1);
    defer app_1.deinit();
    
    var app_2 = try App.init(arena.allocator(), config_2);
    defer app_2.deinit();
    
    // Assert: Multiple instances independent
    std.debug.assert(std.mem.eql(u8, app_1.config.title, "App 1"));
    std.debug.assert(std.mem.eql(u8, app_2.config.title, "App 2"));
    std.debug.assert(app_1.config.menu.len == 0);
    std.debug.assert(app_2.config.menu.len == 1);
}

test "cocoa app long title" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const long_title = "A" ** 100;
    const config = WindowConfig{
        .title = long_title,
        .menu = &.{},
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: Long title handled correctly
    std.debug.assert(app.config.title.len == 100);
}

test "cocoa app empty title" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = WindowConfig{
        .title = "",
        .menu = &.{},
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: Empty title handled correctly
    std.debug.assert(app.config.title.len == 0);
}

test "cocoa app menu entry empty title" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const menu_entries = [_]MenuEntry{
        .{ .title = "", .action = null },
    };
    
    const config = WindowConfig{
        .title = "Empty Menu Title App",
        .menu = &menu_entries,
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: Empty menu title handled correctly
    std.debug.assert(app.config.menu[0].title.len == 0);
}

test "cocoa app menu entry long title" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const long_title = "Menu Entry " ** 20;
    const menu_entries = [_]MenuEntry{
        .{ .title = long_title, .action = null },
    };
    
    const config = WindowConfig{
        .title = "Long Menu Title App",
        .menu = &menu_entries,
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: Long menu title handled correctly
    std.debug.assert(app.config.menu[0].title.len > 0);
}

test "cocoa app menu entry long action" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const long_action = "action_" ** 50;
    const menu_entries = [_]MenuEntry{
        .{ .title = "File", .action = long_action },
    };
    
    const config = WindowConfig{
        .title = "Long Action App",
        .menu = &menu_entries,
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app (writes to stdout)
    try app.present();
    
    // Assert: Long action handled correctly
    std.debug.assert(app.config.menu[0].action != null);
    std.debug.assert(app.config.menu[0].action.?.len > 0);
}

test "cocoa app present multiple times" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = WindowConfig{
        .title = "Multiple Present App",
        .menu = &.{ .{ .title = "File", .action = null } },
    };
    
    var app = try App.init(arena.allocator(), config);
    defer app.deinit();
    
    // Present app multiple times
    try app.present();
    try app.present();
    try app.present();
    
    // Assert: Multiple presents handled correctly
    std.debug.assert(std.mem.eql(u8, app.config.title, "Multiple Present App"));
}
