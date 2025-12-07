//! Tests for Grain Terminal Plus application.
//!
//! Why: Verify terminal multiplexer with session management and split panes.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-165209-pst: Active implementation
//! 2025-12-06-232601-pst: Phase 10.2 WebSocket integration tests

const std = @import("std");
const testing = std.testing;
const grain_workspace = @import("grain_workspace");
const TerminalPlusApp = grain_workspace.terminal_plus.TerminalPlusApp;
const TerminalSession = grain_workspace.terminal_plus.TerminalSession;
const TerminalTab = grain_workspace.terminal_plus.TerminalTab;
const SplitDirection = grain_workspace.terminal_plus.SplitDirection;
const grain_core = @import("grain_core");

test "terminal plus app initialization" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    try testing.expect(app.sessions_len == 0);
    try testing.expect(app.next_session_id == 1);
}

test "create session" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id = try app.create_session("Test Session");
    try testing.expect(session_id == 1);
    try testing.expect(app.sessions_len == 1);

    const session = app.get_session(session_id);
    try testing.expect(session != null);
    try testing.expect(session.?.session_id == session_id);
    try testing.expect(std.mem.eql(u8, session.?.name[0..session.?.name_len], "Test Session"));
}

test "get session by id" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id1 = try app.create_session("Session 1");
    const session_id2 = try app.create_session("Session 2");

    const session1 = app.get_session(session_id1);
    try testing.expect(session1 != null);
    try testing.expect(session1.?.session_id == session_id1);

    const session2 = app.get_session(session_id2);
    try testing.expect(session2 != null);
    try testing.expect(session2.?.session_id == session_id2);

    const session3 = app.get_session(999);
    try testing.expect(session3 == null);
}

test "delete session" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id = try app.create_session("Test Session");
    try testing.expect(app.sessions_len == 1);

    app.delete_session(session_id);
    try testing.expect(app.sessions_len == 0);

    const session = app.get_session(session_id);
    try testing.expect(session == null);
}

test "session add tab" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id = try app.create_session("Test Session");
    const session = app.get_session(session_id);
    try testing.expect(session != null);

    const tab_id = try session.?.add_tab("Tab 1", 80, 24);
    try testing.expect(tab_id == 0);
    try testing.expect(session.?.tabs_len == 1);
    try testing.expect(session.?.active_tab_id == 0);
}

test "session get active tab" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id = try app.create_session("Test Session");
    const session = app.get_session(session_id);
    try testing.expect(session != null);

    _ = try session.?.add_tab("Tab 1", 80, 24);
    const active_tab = session.?.get_active_tab();
    try testing.expect(active_tab != null);
    try testing.expect(active_tab.?.tab_id == 0);
    try testing.expect(std.mem.eql(u8, active_tab.?.name[0..active_tab.?.name_len], "Tab 1"));
}

test "tab split pane horizontal" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id = try app.create_session("Test Session");
    const session = app.get_session(session_id);
    try testing.expect(session != null);

    const tab_id = try session.?.add_tab("Tab 1", 80, 24);
    const tab = session.?.get_active_tab();
    try testing.expect(tab != null);

    const new_pane_id = try tab.?.split_pane(0, .horizontal);
    try testing.expect(new_pane_id == 1);
    try testing.expect(tab.?.panes_len == 2);
    try testing.expect(tab.?.active_pane_id == 1);

    // Check pane dimensions
    const pane0 = tab.?.panes[0];
    const pane1 = tab.?.panes[1];
    try testing.expect(pane0 != null);
    try testing.expect(pane1 != null);
    try testing.expect(pane0.?.width == 40); // Half of 80
    try testing.expect(pane1.?.width == 40);
    try testing.expect(pane1.?.x == 40); // Positioned to the right
}

test "tab split pane vertical" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id = try app.create_session("Test Session");
    const session = app.get_session(session_id);
    try testing.expect(session != null);

    const tab_id = try session.?.add_tab("Tab 1", 80, 24);
    const tab = session.?.get_active_tab();
    try testing.expect(tab != null);

    const new_pane_id = try tab.?.split_pane(0, .vertical);
    try testing.expect(new_pane_id == 1);
    try testing.expect(tab.?.panes_len == 2);

    // Check pane dimensions
    const pane0 = tab.?.panes[0];
    const pane1 = tab.?.panes[1];
    try testing.expect(pane0 != null);
    try testing.expect(pane1 != null);
    try testing.expect(pane0.?.height == 12); // Half of 24
    try testing.expect(pane1.?.height == 12);
    try testing.expect(pane1.?.y == 12); // Positioned below
}

test "multiple tabs per session" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id = try app.create_session("Test Session");
    const session = app.get_session(session_id);
    try testing.expect(session != null);

    const tab_id1 = try session.?.add_tab("Tab 1", 80, 24);
    const tab_id2 = try session.?.add_tab("Tab 2", 80, 24);
    const tab_id3 = try session.?.add_tab("Tab 3", 80, 24);

    try testing.expect(session.?.tabs_len == 3);
    try testing.expect(session.?.active_tab_id == tab_id3); // Last added is active
}

test "multiple sessions" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id1 = try app.create_session("Session 1");
    const session_id2 = try app.create_session("Session 2");
    const session_id3 = try app.create_session("Session 3");

    try testing.expect(app.sessions_len == 3);
    try testing.expect(session_id1 == 1);
    try testing.expect(session_id2 == 2);
    try testing.expect(session_id3 == 3);
}

test "tab initialization" {
    const allocator = testing.allocator;

    const tab = try TerminalTab.init(allocator, 0, "Test Tab", 80, 24);
    try testing.expect(tab.tab_id == 0);
    try testing.expect(tab.panes_len == 1);
    try testing.expect(tab.active_pane_id == 0);
    try testing.expect(tab.panes[0] != null);
    try testing.expect(tab.panes[0].?.width == 80);
    try testing.expect(tab.panes[0].?.height == 24);
}

test "session initialization" {
    const allocator = testing.allocator;

    const session = try TerminalSession.init(allocator, 1, "Test Session");
    try testing.expect(session.session_id == 1);
    try testing.expect(session.tabs_len == 0);
    try testing.expect(std.mem.eql(u8, session.name[0..session.name_len], "Test Session"));
    try testing.expect(session.created_at > 0);
}

test "websocket client management" {
    const allocator = testing.allocator;
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var app = TerminalPlusApp.init(allocator, &ws_manager);

    const session_id = try app.create_session("Test Session");
    const session = app.get_session(session_id);
    try testing.expect(session != null);

    const tab_id = try session.?.add_tab("Tab 1", 80, 24);
    const tab = session.?.get_active_tab();
    try testing.expect(tab != null);

    // Add WebSocket client
    const conn1 = ws_manager.add_connection(1);
    try testing.expect(conn1 != null);
    if (conn1) |conn| {
        conn.state = grain_core.websocket.ConnectionState.open;
        const added = app.add_pane_websocket_client(session_id, tab_id, 0, conn.connection_id);
        try testing.expect(added == true);
        
        const pane = tab.?.panes[0];
        try testing.expect(pane != null);
        try testing.expect(pane.?.websocket_clients_len == 1);
    }

    // Remove WebSocket client
    if (conn1) |conn| {
        const removed = app.remove_pane_websocket_client(session_id, tab_id, 0, conn.connection_id);
        try testing.expect(removed == true);
        
        const pane = tab.?.panes[0];
        try testing.expect(pane != null);
        try testing.expect(pane.?.websocket_clients_len == 0);
    }
}

