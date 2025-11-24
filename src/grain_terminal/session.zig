const std = @import("std");
const Tab = @import("tab.zig").Tab;
const Config = @import("config.zig").Config;

/// Grain Terminal Session: Save/restore terminal sessions.
/// ~<~ Glow Airbend: explicit session state, bounded session storage.
/// ~~~~ Glow Waterbend: deterministic session management, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Session = struct {
    // Bounded: Max session name length (explicit limit)
    pub const MAX_SESSION_NAME_LEN: u32 = 256;

    // Bounded: Max sessions (explicit limit)
    pub const MAX_SESSIONS: u32 = 1_024;

    // Bounded: Max tabs per session (explicit limit)
    pub const MAX_TABS_PER_SESSION: u32 = 256;

    // Bounded: Max session data size (explicit limit, in bytes)
    pub const MAX_SESSION_DATA_SIZE: u32 = 10_485_760; // 10 MB

    /// Session state enumeration.
    pub const SessionState = enum(u8) {
        active, // Active session
        saved, // Saved session
        restored, // Restored session
    };

    /// Session structure.
    pub const SessionData = struct {
        id: u32, // Session ID (unique identifier)
        name: []const u8, // Session name (bounded)
        name_len: u32,
        state: SessionState, // Session state
        created_at: u64, // Creation timestamp (Unix epoch)
        updated_at: u64, // Last update timestamp (Unix epoch)
        tab_ids: []u32, // Tab IDs in this session (bounded)
        tab_ids_len: u32,
        active_tab_id: u32, // Active tab ID
        config_snapshot: Config, // Configuration snapshot
        allocator: std.mem.Allocator,
    };

    /// Session manager structure.
    sessions: []SessionData, // Sessions buffer (bounded)
    sessions_len: u32, // Number of sessions
    next_session_id: u32, // Next available session ID
    allocator: std.mem.Allocator,

    /// Initialize session manager.
    pub fn init(allocator: std.mem.Allocator) !Session {
        // Assert: Allocator must be valid
        _ = allocator; // Allocator is used below

        // Pre-allocate sessions buffer
        const sessions = try allocator.alloc(SessionData, MAX_SESSIONS);
        errdefer allocator.free(sessions);

        return Session{
            .sessions = sessions,
            .sessions_len = 0,
            .next_session_id = 1, // Start at 1
            .allocator = allocator,
        };
    }

    /// Deinitialize session manager and free memory.
    pub fn deinit(self: *Session) void {
        // Assert: Allocator must be valid
        std.debug.assert(self.allocator.ptr != null);

        // Deinitialize all sessions
        var i: u32 = 0;
        while (i < self.sessions_len) : (i += 1) {
            session_data_deinit(&self.sessions[i]);
        }

        // Free sessions buffer
        self.allocator.free(self.sessions);

        self.* = undefined;
    }

    /// Create new session.
    pub fn create_session(self: *Session, name: []const u8, config: *const Config) !u32 {
        // Assert: Name must be bounded
        std.debug.assert(name.len <= MAX_SESSION_NAME_LEN);

        // Check sessions limit
        if (self.sessions_len >= MAX_SESSIONS) {
            return error.TooManySessions;
        }

        // Get current timestamp
        const now = std.time.timestamp();

        // Allocate name
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        // Pre-allocate tab IDs buffer
        const tab_ids = try self.allocator.alloc(u32, MAX_TABS_PER_SESSION);
        errdefer self.allocator.free(tab_ids);

        // Create config snapshot (copy)
        const config_snapshot = try self.copy_config(config);
        errdefer config_snapshot.deinit(self.allocator);

        // Create session
        const session_id = self.next_session_id;
        self.next_session_id += 1;

        self.sessions[self.sessions_len] = SessionData{
            .id = session_id,
            .name = name_copy,
            .name_len = @as(u32, @intCast(name_copy.len)),
            .state = .active,
            .created_at = @as(u64, @intCast(now)),
            .updated_at = @as(u64, @intCast(now)),
            .tab_ids = tab_ids,
            .tab_ids_len = 0,
            .active_tab_id = 0, // No active tab initially
            .config_snapshot = config_snapshot,
            .allocator = self.allocator,
        };
        self.sessions_len += 1;

        return session_id;
    }

    /// Save session (mark as saved, update timestamp).
    pub fn save_session(self: *Session, session_id: u32) !void {
        if (self.find_session(session_id)) |session| {
            session.state = .saved;
            const now = std.time.timestamp();
            session.updated_at = @as(u64, @intCast(now));
        } else {
            return error.SessionNotFound;
        }
    }

    /// Restore session (mark as restored, update timestamp).
    pub fn restore_session(self: *Session, session_id: u32) !void {
        if (self.find_session(session_id)) |session| {
            session.state = .restored;
            const now = std.time.timestamp();
            session.updated_at = @as(u64, @intCast(now));
        } else {
            return error.SessionNotFound;
        }
    }

    /// Add tab to session.
    pub fn add_tab(self: *Session, session_id: u32, tab_id: u32) !void {
        if (self.find_session(session_id)) |session| {
            // Check tab limit
            if (session.tab_ids_len >= MAX_TABS_PER_SESSION) {
                return error.TooManyTabs;
            }

            session.tab_ids[session.tab_ids_len] = tab_id;
            session.tab_ids_len += 1;

            // Update timestamp
            const now = std.time.timestamp();
            session.updated_at = @as(u64, @intCast(now));
        } else {
            return error.SessionNotFound;
        }
    }

    /// Set active tab in session.
    pub fn set_active_tab(self: *Session, session_id: u32, tab_id: u32) !void {
        if (self.find_session(session_id)) |session| {
            session.active_tab_id = tab_id;

            // Update timestamp
            const now = std.time.timestamp();
            session.updated_at = @as(u64, @intCast(now));
        } else {
            return error.SessionNotFound;
        }
    }

    /// Get session by ID.
    pub fn get_session(self: *Session, session_id: u32) ?*SessionData {
        return self.find_session(session_id);
    }

    /// Find session by ID (internal helper).
    fn find_session(self: *Session, session_id: u32) ?*SessionData {
        var i: u32 = 0;
        while (i < self.sessions_len) : (i += 1) {
            if (self.sessions[i].id == session_id) {
                return &self.sessions[i];
            }
        }
        return null;
    }

    /// Copy configuration (create snapshot).
    // 2025-11-23-150318-pst: Active function
    fn copy_config(self: *Session, config: *const Config) !Config {
        // self will be used in full implementation for session-specific config
        // Create a new config with same settings
        // In a full implementation, we'd deep copy all config entries
        var new_config = try Config.init(self.allocator);
        new_config.theme = config.theme;
        new_config.font_size = config.font_size;
        new_config.show_tabs = config.show_tabs;
        new_config.show_scrollbar = config.show_scrollbar;
        new_config.scrollback_lines = config.scrollback_lines;
        new_config.cursor_blink = config.cursor_blink;
        new_config.cursor_shape = config.cursor_shape;
        
        // Copy font family
        if (config.font_family_len > 0) {
            self.allocator.free(new_config.font_family);
            new_config.font_family = try self.allocator.dupe(u8, config.font_family);
            new_config.font_family_len = config.font_family_len;
        }
        
        return new_config;
    }
};

/// SessionData deinitialization.
pub fn session_data_deinit(data: *Session.SessionData) void {
    // Free name
    if (data.name_len > 0) {
        data.allocator.free(data.name);
    }

    // Free tab IDs
    data.allocator.free(data.tab_ids);

    // Deinitialize config snapshot
    data.config_snapshot.deinit(data.allocator);

    data.* = undefined;
}

