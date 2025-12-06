//! Grain Terminal Plus: Advanced terminal multiplexer.
//!
//! Why: Provide enhanced terminal with session management and split panes.
//! Architecture: Session management, split panes, tab management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-165209-pst: Active implementation

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

// Split direction enumeration.
// 2025-12-03-165209-pst: Active enum
pub const SplitDirection = enum(u8) {
    horizontal, // Horizontal split (panes side by side)
    vertical, // Vertical split (panes stacked)
};

// Pane structure for split panes.
// 2025-12-03-165209-pst: Active struct
pub const TerminalPane = struct {
    pane_id: u32,
    terminal: grain_terminal.Terminal,
    width: u32,
    height: u32,
    x: u32, // X position in parent
    y: u32, // Y position in parent
    active: bool,
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
        const initial_pane = TerminalPane{
            .pane_id = 0,
            .terminal = grain_terminal.Terminal.init(width, height),
            .width = width,
            .height = height,
            .x = 0,
            .y = 0,
            .active = true,
        };
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
        const new_pane = TerminalPane{
            .pane_id = new_pane_id,
            .terminal = grain_terminal.Terminal.init(new_width, new_height),
            .width = new_width,
            .height = new_height,
            .x = new_x,
            .y = new_y,
            .active = false,
        };

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
pub const TerminalPlusApp = struct {
    sessions: [MAX_SESSIONS]?TerminalSession,
    sessions_len: u32,
    next_session_id: u32,
    allocator: std.mem.Allocator,

    /// Initialize terminal plus application.
    // 2025-12-03-165209-pst: Active function
    pub fn init(allocator: std.mem.Allocator) TerminalPlusApp {
        // Precondition: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        var app = TerminalPlusApp{
            .sessions = undefined,
            .sessions_len = 0,
            .next_session_id = 1,
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
};

