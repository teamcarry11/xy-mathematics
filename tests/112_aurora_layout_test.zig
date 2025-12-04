const std = @import("std");
const Layout = @import("../src/aurora_layout.zig").Layout;

test "layout init and deinit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Assert: Layout initialized correctly
    std.debug.assert(layout.root == null);
    std.debug.assert(layout.pane_count == 0);
    std.debug.assert(layout.current_workspace == 0);
}

test "layout create workspace with root pane" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create workspace (creates root pane)
    const workspace_id = try layout.create_workspace("main", 800, 600);
    
    // Assert: Workspace and root pane created
    std.debug.assert(workspace_id == 0);
    std.debug.assert(layout.root != null);
    std.debug.assert(layout.pane_count == 1);
    
    const root = layout.root.?;
    std.debug.assert(root.id == 0);
    std.debug.assert(root.pane_type == .editor);
    std.debug.assert(root.rect.x == 0);
    std.debug.assert(root.rect.y == 0);
    std.debug.assert(root.rect.width == 800);
    std.debug.assert(root.rect.height == 600);
    std.debug.assert(root.focused == true);
}

test "layout split pane horizontal" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create root pane
    try layout.create_root_pane(.editor, 0, 0, 800, 600);
    
    // Split horizontally
    try layout.split_pane(.horizontal, .terminal);
    
    // Assert: Split successful
    std.debug.assert(layout.pane_count == 2);
    
    const root = layout.root.?;
    std.debug.assert(root.left != null);
    std.debug.assert(root.focused == false);
    
    const new_pane = root.left.?;
    std.debug.assert(new_pane.focused == true);
    std.debug.assert(new_pane.pane_type == .terminal);
    std.debug.assert(new_pane.rect.width == 400);
    std.debug.assert(new_pane.rect.height == 600);
    std.debug.assert(new_pane.rect.x == 400);
    std.debug.assert(new_pane.rect.y == 0);
    
    // Assert: Original pane resized
    std.debug.assert(root.rect.width == 400);
    std.debug.assert(root.rect.height == 600);
}

test "layout split pane vertical" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create root pane
    try layout.create_root_pane(.editor, 0, 0, 800, 600);
    
    // Split vertically
    try layout.split_pane(.vertical, .browser);
    
    // Assert: Split successful
    std.debug.assert(layout.pane_count == 2);
    
    const root = layout.root.?;
    std.debug.assert(root.right != null);
    std.debug.assert(root.focused == false);
    
    const new_pane = root.right.?;
    std.debug.assert(new_pane.focused == true);
    std.debug.assert(new_pane.pane_type == .browser);
    std.debug.assert(new_pane.rect.width == 800);
    std.debug.assert(new_pane.rect.height == 300);
    std.debug.assert(new_pane.rect.x == 0);
    std.debug.assert(new_pane.rect.y == 300);
    
    // Assert: Original pane resized
    std.debug.assert(root.rect.width == 800);
    std.debug.assert(root.rect.height == 300);
}

test "layout focus next pane" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create root pane
    try layout.create_root_pane(.editor, 0, 0, 800, 600);
    
    // Split horizontally
    try layout.split_pane(.horizontal, .terminal);
    
    // Assert: New pane is focused
    const root = layout.root.?;
    const new_pane = root.left.?;
    std.debug.assert(new_pane.focused == true);
    std.debug.assert(root.focused == false);
    
    // Focus next
    layout.focus_next();
    
    // Assert: Focus moved to root
    std.debug.assert(root.focused == true);
    std.debug.assert(new_pane.focused == false);
}

test "layout resize panes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create root pane
    try layout.create_root_pane(.editor, 0, 0, 800, 600);
    
    // Split horizontally
    try layout.split_pane(.horizontal, .terminal);
    
    // Resize layout
    try layout.resize(1000, 800);
    
    // Assert: Panes resized
    const root = layout.root.?;
    const new_pane = root.left.?;
    std.debug.assert(root.rect.width == 500);
    std.debug.assert(root.rect.height == 800);
    std.debug.assert(new_pane.rect.width == 500);
    std.debug.assert(new_pane.rect.height == 800);
}

test "layout create workspace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create workspace
    const workspace_id = try layout.create_workspace("test");
    
    // Assert: Workspace created
    std.debug.assert(workspace_id == 0);
    std.debug.assert(layout.workspaces.items.len == 1);
    
    const ws = layout.workspaces.items[0];
    std.debug.assert(ws.id == 0);
    std.debug.assert(std.mem.eql(u8, ws.name, "test"));
}

test "layout switch workspace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create workspaces
    _ = try layout.create_workspace("ws1");
    _ = try layout.create_workspace("ws2");
    
    // Switch to workspace 1
    try layout.switch_workspace(1);
    
    // Assert: Workspace switched
    std.debug.assert(layout.current_workspace == 1);
}

test "layout bounded panes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create root pane
    try layout.create_root_pane(.editor, 0, 0, 800, 600);
    
    // Split until we hit the limit
    var i: u32 = 1;
    while (i < Layout.MAX_PANES) : (i += 1) {
        try layout.split_pane(.horizontal, .editor);
    }
    
    // Assert: At limit
    std.debug.assert(layout.pane_count == Layout.MAX_PANES);
    
    // Next split should fail
    const result = layout.split_pane(.horizontal, .editor);
    std.debug.assert(result == error.TooManyPanes);
}

test "layout bounded workspaces" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create workspaces until we hit the limit
    var i: u32 = 0;
    while (i < Layout.MAX_WORKSPACES) : (i += 1) {
        var name_buf: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buf, "ws{}", .{i});
        _ = try layout.create_workspace(name);
    }
    
    // Assert: At limit
    std.debug.assert(layout.workspaces.items.len == Layout.MAX_WORKSPACES);
    
    // Next workspace should fail
    const result = layout.create_workspace("extra");
    std.debug.assert(result == error.TooManyWorkspaces);
}

test "layout find focused pane" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create root pane
    try layout.create_root_pane(.editor, 0, 0, 800, 600);
    
    // Assert: Root is focused
    const focused = layout.find_focused_pane();
    std.debug.assert(focused != null);
    std.debug.assert(focused.? == layout.root.?);
    
    // Split and focus new pane
    try layout.split_pane(.horizontal, .terminal);
    
    // Assert: New pane is focused
    const new_focused = layout.find_focused_pane();
    std.debug.assert(new_focused != null);
    std.debug.assert(new_focused.? != layout.root.?);
}

test "layout pane tree structure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var layout = Layout.init(allocator);
    defer layout.deinit();
    
    // Create root pane
    try layout.create_root_pane(.editor, 0, 0, 800, 600);
    
    // Split horizontally
    try layout.split_pane(.horizontal, .terminal);
    
    // Split left pane vertically
    layout.focus_next(); // Focus root
    try layout.split_pane(.vertical, .browser);
    
    // Assert: Tree structure correct
    const root = layout.root.?;
    std.debug.assert(root.left != null);
    std.debug.assert(root.right != null);
    
    const left = root.left.?;
    std.debug.assert(left.right != null);
    
    // Assert: Pane count correct
    std.debug.assert(layout.pane_count == 3);
}

