//! Grain Terminal Plus: Advanced terminal multiplexer.
//!
//! Why: Provide enhanced terminal with session management and split panes.
//! Architecture: Session management, split panes, tab management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-165209-pst: Active implementation
//! 2025-12-06-232601-pst: Phase 10.2 WebSocket integration for live output streaming

const std = @import("std");
const grain_terminal = @import("grain_terminal");
const grain_core = @import("grain_core");

// Bounded: Max sessions (explicit limit)
// 2025-12-03-165209-pst: Active constant
pub const MAX_SESSIONS: u32 = 64;

// Bounded: Max tabs per session (explicit limit)
// 2025-12-03-165209-pst: Active constant
pub const MAX_TABS_PER_SESSION: u32 = 32;

// Bounded: Max panes per tab (explicit limit)
// 2025-12-03-165209-pst: Active constant
pub const MAX_PANES_PER_TAB: u32 = 16;

// Bounded: Max session name length (explicit limit, in bytes)
// 2025-12-03-165209-pst: Active constant
pub const MAX_SESSION_NAME_LEN: u32 = 256;

// Bounded: Max WebSocket clients per pane (explicit limit)
// 2025-12-06-232601-pst: Phase 10.2 WebSocket integration
pub const MAX_WEBSOCKET_CLIENTS_PER_PANE: u32 = 16;

// Split direction enumeration.
// 2025-12-03-165209-pst: Active enum
pub const SplitDirection = enum(u8) {
    horizontal, // Horizontal split (panes side by side)
    vertical, // Vertical split (panes stacked)
};

// Pane structure for split panes.
// 2025-12-03-165209-pst: Active struct
// 2025-12-06-232601-pst: Phase 10.2 WebSocket integration
pub const TerminalPane = struct {
    pane_id: u32,
    terminal: grain_terminal.Terminal,
    width: u32,
    height: u32,
    x: u32, // X position in parent
    y: u32, // Y position in parent
    active: bool,
    websocket_clients: [MAX_WEBSOCKET_CLIENTS_PER_PANE]u32,
    websocket_clients_len: u32,
};

// Tab structure for tab management.
// 2025-12-03-165209-pst: Active struct
pub const TerminalTab = struct {
    tab_id: u32,
    name: [MAX_SESSION_NAME_LEN]u8,
    name_len: u32,
    panes: [MAX_PANES_PER_TAB]?TerminalPane,
    panes_len: u32,
    active_pane_id: u32,
    allocator: std.mem.Allocator,

    /// Initialize terminal tab.
    // 2025-12-03-165209-pst: Active function
    pub fn init(
        allocator: std.mem.Allocator,
        tab_id: u32,
        name: []const u8,
        width: u32,
        height: u32,
    ) !TerminalTab {
        // Precondition: Name and dimensions must be valid
        std.debug.assert(name.len <= MAX_SESSION_NAME_LEN);
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(allocator.ptr != null);

        var tab = TerminalTab{
            .tab_id = tab_id,
            .name = undefined,
            .name_len = @as(u32, @intCast(name.len)),
            .panes = undefined,
            .panes_len = 0,
            .active_pane_id = 0,
            .allocator = allocator,
        };

        // Initialize name
        @memset(&tab.name, 0);
        if (name.len > 0) {
            @memcpy(tab.name[0..name.len], name);
        }

        // Initialize panes array
        var i: u32 = 0;
        while (i < MAX_PANES_PER_TAB) : (i += 1) {
            tab.panes[i] = null;
        }

        // Create initial pane
        var initial_pane = TerminalPane{
            .pane_id = 0,
            .terminal = grain_terminal.Terminal.init(width, height),
            .width = width,
            .height = height,
            .x = 0,
            .y = 0,
            .active = true,
            .websocket_clients = undefined,
            .websocket_clients_len = 0,
        };
        // Initialize WebSocket clients array
        var j: u32 = 0;
        while (j < MAX_WEBSOCKET_CLIENTS_PER_PANE) : (j += 1) {
            initial_pane.websocket_clients[j] = 0;
        }
        tab.panes[0] = initial_pane;
        tab.panes_len = 1;
        tab.active_pane_id = 0;

        // Postcondition: Tab must be valid
        std.debug.assert(tab.panes_len > 0);
        std.debug.assert(tab.active_pane_id < tab.panes_len);

        return tab;
    }

    /// Split pane (create new pane).
    // 2025-12-03-165209-pst: Active function
    pub fn split_pane(
        self: *TerminalTab,
        pane_id: u32,
        direction: SplitDirection,
    ) !u32 {
        // Precondition: Must have space for new pane
        std.debug.assert(self.panes_len < MAX_PANES_PER_TAB);
        std.debug.assert(pane_id < self.panes_len);

        if (self.panes[pane_id] == null) {
            return error.PaneNotFound;
        }
        var source_pane = &self.panes[pane_id].?;

        // Calculate new pane dimensions
        const new_pane_id = self.panes_len;
        var new_width: u32 = source_pane.width;
        var new_height: u32 = source_pane.height;
        var new_x: u32 = source_pane.x;
        var new_y: u32 = source_pane.y;

        if (direction == .horizontal) {
            new_width = source_pane.width / 2;
            new_x = source_pane.x + new_width;
            source_pane.width = new_width;
        } else {
            new_height = source_pane.height / 2;
            new_y = source_pane.y + new_height;
            source_pane.height = new_height;
        }

        // Create new pane
        var new_pane = TerminalPane{
            .pane_id = new_pane_id,
            .terminal = grain_terminal.Terminal.init(new_width, new_height),
            .width = new_width,
            .height = new_height,
            .x = new_x,
            .y = new_y,
            .active = false,
            .websocket_clients = undefined,
            .websocket_clients_len = 0,
        };
        // Initialize WebSocket clients array
        var j: u32 = 0;
        while (j < MAX_WEBSOCKET_CLIENTS_PER_PANE) : (j += 1) {
            new_pane.websocket_clients[j] = 0;
        }

        self.panes[new_pane_id] = new_pane;
        self.panes_len += 1;
        self.active_pane_id = new_pane_id;

        // Postcondition: Pane count increased
        std.debug.assert(self.panes_len > 0);
        std.debug.assert(self.panes_len <= MAX_PANES_PER_TAB);

        return new_pane_id;
    }
};

// Session structure for session management.
// 2025-12-03-165209-pst: Active struct
pub const TerminalSession = struct {
    session_id: u32,
    name: [MAX_SESSION_NAME_LEN]u8,
    name_len: u32,
    tabs: [MAX_TABS_PER_SESSION]?TerminalTab,
    tabs_len: u32,
    active_tab_id: u32,
    created_at: u64,
    updated_at: u64,
    allocator: std.mem.Allocator,

    /// Initialize terminal session.
    // 2025-12-03-165209-pst: Active function
    pub fn init(
        allocator: std.mem.Allocator,
        session_id: u32,
        name: []const u8,
    ) !TerminalSession {
        // Precondition: Name must be valid
        std.debug.assert(name.len <= MAX_SESSION_NAME_LEN);
        std.debug.assert(session_id > 0);
        std.debug.assert(allocator.ptr != null);

        const now = @as(u64, @intCast(std.time.timestamp()));

        var session = TerminalSession{
            .session_id = session_id,
            .name = undefined,
            .name_len = @as(u32, @intCast(name.len)),
            .tabs = undefined,
            .tabs_len = 0,
            .active_tab_id = 0,
            .created_at = now,
            .updated_at = now,
            .allocator = allocator,
        };

        // Initialize name
        @memset(&session.name, 0);
        if (name.len > 0) {
            @memcpy(session.name[0..name.len], name);
        }

        // Initialize tabs array
        var i: u32 = 0;
        while (i < MAX_TABS_PER_SESSION) : (i += 1) {
            session.tabs[i] = null;
        }

        // Postcondition: Session must be valid
        std.debug.assert(session.tabs_len == 0);

        return session;
    }

    /// Add tab to session.
    // 2025-12-03-165209-pst: Active function
    pub fn add_tab(
        self: *TerminalSession,
        name: []const u8,
        width: u32,
        height: u32,
    ) !u32 {
        // Precondition: Must have space for tab
        std.debug.assert(self.tabs_len < MAX_TABS_PER_SESSION);
        std.debug.assert(name.len <= MAX_SESSION_NAME_LEN);
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        const tab_id = self.tabs_len;
        const tab = try TerminalTab.init(
            self.allocator,
            tab_id,
            name,
            width,
            height,
        );
        self.tabs[self.tabs_len] = tab;
        self.tabs_len += 1;
        self.active_tab_id = tab_id;
        self.updated_at = @as(u64, @intCast(std.time.timestamp()));

        // Postcondition: Tab count increased
        std.debug.assert(self.tabs_len > 0);
        std.debug.assert(self.tabs_len <= MAX_TABS_PER_SESSION);

        return tab_id;
    }

    /// Get active tab.
    // 2025-12-03-165209-pst: Active function
    pub fn get_active_tab(self: *const TerminalSession) ?*TerminalTab {
        // Precondition: Must have tabs
        std.debug.assert(self.tabs_len > 0);

        if (self.active_tab_id < self.tabs_len) {
            if (self.tabs[self.active_tab_id]) |*tab| {
                return tab;
            }
        }

        return null;
    }
};

// Terminal Plus application state.
// 2025-12-03-165209-pst: Active struct
// 2025-12-06-232601-pst: Phase 10.2 WebSocket integration
pub const TerminalPlusApp = struct {
    sessions: [MAX_SESSIONS]?TerminalSession,
    sessions_len: u32,
    next_session_id: u32,
    websocket_manager: *grain_core.websocket.WebSocketManager,
    allocator: std.mem.Allocator,

    /// Initialize terminal plus application.
    // 2025-12-03-165209-pst: Active function
    // 2025-12-06-232601-pst: Phase 10.2 WebSocket integration
    pub fn init(
        allocator: std.mem.Allocator,
        ws_manager: *grain_core.websocket.WebSocketManager,
    ) TerminalPlusApp {
        // Precondition: Allocator and WebSocket manager must be valid
        std.debug.assert(allocator.ptr != null);
        std.debug.assert(@intFromPtr(ws_manager) != 0);

        var app = TerminalPlusApp{
            .sessions = undefined,
            .sessions_len = 0,
            .next_session_id = 1,
            .websocket_manager = ws_manager,
            .allocator = allocator,
        };

        // Initialize sessions array
        var i: u32 = 0;
        while (i < MAX_SESSIONS) : (i += 1) {
            app.sessions[i] = null;
        }

        // Postcondition: App must be valid
        std.debug.assert(app.sessions_len == 0);
        std.debug.assert(app.next_session_id > 0);

        return app;
    }

    /// Create new session.
    // 2025-12-03-165209-pst: Active function
    pub fn create_session(
        self: *TerminalPlusApp,
        name: []const u8,
    ) !u32 {
        // Precondition: Must have space for session
        std.debug.assert(self.sessions_len < MAX_SESSIONS);
        std.debug.assert(name.len <= MAX_SESSION_NAME_LEN);

        const session_id = self.next_session_id;
        self.next_session_id += 1;

        const session = try TerminalSession.init(
            self.allocator,
            session_id,
            name,
        );
        self.sessions[self.sessions_len] = session;
        self.sessions_len += 1;

        // Postcondition: Session count increased
        std.debug.assert(self.sessions_len > 0);
        std.debug.assert(self.sessions_len <= MAX_SESSIONS);

        return session_id;
    }

    /// Get session by ID.
    // 2025-12-03-165209-pst: Active function
    pub fn get_session(
        self: *const TerminalPlusApp,
        session_id: u32,
    ) ?*TerminalSession {
        // Precondition: Session ID must be valid
        std.debug.assert(session_id > 0);

        var i: u32 = 0;
        while (i < self.sessions_len) : (i += 1) {
            if (self.sessions[i]) |*session| {
                if (session.session_id == session_id) {
                    return session;
                }
            }
        }

        return null;
    }

    /// Delete session by ID.
    // 2025-12-03-165209-pst: Active function
    pub fn delete_session(self: *TerminalPlusApp, session_id: u32) void {
        // Precondition: Session ID must be valid
        std.debug.assert(session_id > 0);

        var i: u32 = 0;
        while (i < self.sessions_len) : (i += 1) {
            if (self.sessions[i]) |*session| {
                if (session.session_id == session_id) {
                    // Shift remaining sessions left
                    var j: u32 = i;
                    while (j + 1 < self.sessions_len) : (j += 1) {
                        self.sessions[j] = self.sessions[j + 1];
                    }
                    self.sessions_len -= 1;
                    return;
                }
            }
        }
    }

    /// Add WebSocket client to pane for live output streaming.
    // 2025-12-06-232601-pst: Phase 10.2 WebSocket integration
    pub fn add_pane_websocket_client(
        self: *TerminalPlusApp,
        session_id: u32,
        tab_id: u32,
        pane_id: u32,
        connection_id: u32,
    ) bool {
        // Precondition: IDs must be valid
        std.debug.assert(session_id > 0);
        std.debug.assert(connection_id > 0);

        const session = self.get_session(session_id);
        if (session == null) {
            return false;
        }

        if (tab_id >= session.?.tabs_len) {
            return false;
        }

        const tab_opt = session.?.tabs[tab_id];
        if (tab_opt == null) {
            return false;
        }
        var tab = &tab_opt.?;

        if (pane_id >= tab.panes_len) {
            return false;
        }

        const pane_opt = tab.panes[pane_id];
        if (pane_opt == null) {
            return false;
        }
        var pane = &tab.panes[pane_id].?;

        if (pane.websocket_clients_len >= MAX_WEBSOCKET_CLIENTS_PER_PANE) {
            return false;
        }

        pane.websocket_clients[pane.websocket_clients_len] = connection_id;
        pane.websocket_clients_len += 1;

        // Postcondition: Client count increased
        std.debug.assert(pane.websocket_clients_len > 0);
        std.debug.assert(pane.websocket_clients_len <= MAX_WEBSOCKET_CLIENTS_PER_PANE);

        return true;
    }

    /// Remove WebSocket client from pane.
    // 2025-12-06-232601-pst: Phase 10.2 WebSocket integration
    pub fn remove_pane_websocket_client(
        self: *TerminalPlusApp,
        session_id: u32,
        tab_id: u32,
        pane_id: u32,
        connection_id: u32,
    ) bool {
        // Precondition: IDs must be valid
        std.debug.assert(session_id > 0);
        std.debug.assert(connection_id > 0);

        const session = self.get_session(session_id);
        if (session == null) {
            return false;
        }

        if (tab_id >= session.?.tabs_len) {
            return false;
        }

        const tab_opt = session.?.tabs[tab_id];
        if (tab_opt == null) {
            return false;
        }
        var tab = &tab_opt.?;

        if (pane_id >= tab.panes_len) {
            return false;
        }

        const pane_opt = tab.panes[pane_id];
        if (pane_opt == null) {
            return false;
        }
        var pane = &tab.panes[pane_id].?;

        var i: u32 = 0;
        while (i < pane.websocket_clients_len) : (i += 1) {
            if (pane.websocket_clients[i] == connection_id) {
                var j: u32 = i;
                while (j < pane.websocket_clients_len - 1) : (j += 1) {
                    pane.websocket_clients[j] = pane.websocket_clients[j + 1];
                }
                pane.websocket_clients_len -= 1;
                return true;
            }
        }

        return false;
    }

    /// Broadcast terminal output to WebSocket clients (internal).
    // 2025-12-06-232601-pst: Phase 10.2 WebSocket integration
    pub fn broadcast_pane_output(
        self: *TerminalPlusApp,
        session_id: u32,
        tab_id: u32,
        pane_id: u32,
        output: []const u8,
    ) void {
        // Precondition: Output must be valid
        std.debug.assert(output.len > 0);

        const session = self.get_session(session_id);
        if (session == null) {
            return;
        }

        if (tab_id >= session.?.tabs_len) {
            return;
        }

        const tab_opt = session.?.tabs[tab_id];
        if (tab_opt == null) {
            return;
        }
        var tab = &tab_opt.?;

        if (pane_id >= tab.panes_len) {
            return;
        }

        const pane_opt = tab.panes[pane_id];
        if (pane_opt == null) {
            return;
        }
        var pane = &tab.panes[pane_id].?;

        if (pane.websocket_clients_len == 0) {
            return;
        }

        // Create WebSocket frame
        var frame = grain_core.websocket.WebSocketFrame.init();
        frame.flags.opcode = grain_core.websocket.FrameOpcode.text;
        frame.flags.fin = true;
        frame.flags.masked = false;
        const output_len = @min(output.len, grain_core.websocket.MAX_FRAME_SIZE);
        frame.payload_len = @intCast(output_len);

        var i: u32 = 0;
        while (i < output_len) : (i += 1) {
            frame.payload[i] = output[i];
        }

        // Broadcast to all clients
        i = 0;
        while (i < pane.websocket_clients_len) : (i += 1) {
            const conn_id = pane.websocket_clients[i];
            const conn = self.websocket_manager.find_connection(conn_id);
            if (conn != null and conn.?.state == grain_core.websocket.ConnectionState.open) {
                // Frame would be sent here (actual send via socket not implemented)
                _ = frame;
            }
        }
    }
};

