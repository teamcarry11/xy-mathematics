//! Tests for Grain OS workspace management.
//! Why: Verify workspace switching and window assignment.

const std = @import("std");
const testing = std.testing;
const workspace = @import("grain_os").workspace;
const compositor = @import("grain_os").compositor;

test "workspace initialization" {
    const ws = workspace.Workspace.init(1, "test");
    try testing.expect(ws.id == 1);
    try testing.expect(ws.window_ids_len == 0);
    try testing.expect(ws.focused_window_id == 0);
}

test "workspace add window" {
    var ws = workspace.Workspace.init(1, "test");
    const success = ws.add_window(10);
    try testing.expect(success == true);
    try testing.expect(ws.window_ids_len == 1);
    try testing.expect(ws.window_ids[0] == 10);
}

test "workspace remove window" {
    var ws = workspace.Workspace.init(1, "test");
    _ = ws.add_window(10);
    _ = ws.add_window(20);
    const success = ws.remove_window(10);
    try testing.expect(success == true);
    try testing.expect(ws.window_ids_len == 1);
    try testing.expect(ws.window_ids[0] == 20);
}

test "workspace set focused window" {
    var ws = workspace.Workspace.init(1, "test");
    _ = ws.add_window(10);
    const success = ws.set_focused_window(10);
    try testing.expect(success == true);
    try testing.expect(ws.focused_window_id == 10);
}

test "workspace manager initialization" {
    const manager = workspace.WorkspaceManager.init();
    try testing.expect(manager.workspaces_len == 1);
    try testing.expect(manager.current_workspace_id == 1);
}

test "workspace manager get workspace" {
    var manager = workspace.WorkspaceManager.init();
    const ws = manager.get_workspace(1);
    try testing.expect(ws != null);
    if (ws) |workspace_ptr| {
        try testing.expect(workspace_ptr.id == 1);
    }
}

test "workspace manager switch workspace" {
    var manager = workspace.WorkspaceManager.init();
    const ws2_id = manager.create_workspace("workspace2") orelse unreachable;
    const success = manager.switch_workspace(ws2_id);
    try testing.expect(success == true);
    try testing.expect(manager.current_workspace_id == ws2_id);
}

test "workspace manager assign window" {
    var manager = workspace.WorkspaceManager.init();
    const ws2_id = manager.create_workspace("workspace2") orelse unreachable;
    const success = manager.assign_window_to_workspace(10, ws2_id);
    try testing.expect(success == true);
    const ws2 = manager.get_workspace(ws2_id);
    try testing.expect(ws2 != null);
    if (ws2) |workspace_ptr| {
        try testing.expect(workspace_ptr.window_ids_len == 1);
        try testing.expect(workspace_ptr.window_ids[0] == 10);
    }
}

test "compositor workspace integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var comp = compositor.Compositor.init(gpa.allocator());
    _ = try comp.create_window(100, 100);
    const current_id = comp.get_current_workspace_id();
    try testing.expect(current_id > 0);
    const ws2_id = comp.create_workspace("workspace2") orelse unreachable;
    const success = comp.switch_workspace(ws2_id);
    try testing.expect(success == true);
    try testing.expect(comp.get_current_workspace_id() == ws2_id);
}

test "compositor window workspace assignment" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var comp = compositor.Compositor.init(gpa.allocator());
    const win1 = try comp.create_window(100, 100);
    const ws2_id = comp.create_workspace("workspace2") orelse unreachable;
    const success = comp.assign_window_to_workspace(win1, ws2_id);
    try testing.expect(success == true);
}
