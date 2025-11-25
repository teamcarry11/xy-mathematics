//! Grain OS Window Session: Save and restore named window layouts.
//!
//! Why: Allow users to save and restore entire window layouts as sessions.
//! Architecture: Session management with named layouts.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");
const window_state = @import("window_state.zig");

// Bounded: Max sessions.
pub const MAX_SESSIONS: u32 = 32;

// Bounded: Max session name length.
pub const MAX_SESSION_NAME_LEN: u32 = 64;

// Window session: named collection of window states.
pub const WindowSession = struct {
    session_id: u32,
    name: [MAX_SESSION_NAME_LEN]u8,
    name_len: u32,
    state_manager: window_state.WindowStateManager,
    timestamp: u64,
    active: bool,

    pub fn init(session_id: u32, name: []const u8) WindowSession {
        std.debug.assert(session_id > 0);
        std.debug.assert(name.len <= MAX_SESSION_NAME_LEN);
        var session = WindowSession{
            .session_id = session_id,
            .name = undefined,
            .name_len = 0,
            .state_manager = window_state.WindowStateManager.init(),
            .timestamp = 0,
            .active = true,
        };
        var i: u32 = 0;
        while (i < MAX_SESSION_NAME_LEN) : (i += 1) {
            session.name[i] = 0;
        }
        const copy_len = @min(name.len, MAX_SESSION_NAME_LEN);
        i = 0;
        while (i < copy_len) : (i += 1) {
            session.name[i] = name[i];
        }
        session.name_len = @intCast(copy_len);
        return session;
    }
};

// Session manager: manages window sessions.
pub const SessionManager = struct {
    sessions: [MAX_SESSIONS]WindowSession,
    sessions_len: u32,
    next_session_id: u32,

    pub fn init() SessionManager {
        var manager = SessionManager{
            .sessions = undefined,
            .sessions_len = 0,
            .next_session_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_SESSIONS) : (i += 1) {
            manager.sessions[i] = WindowSession.init(0, "");
        }
        return manager;
    }

    // Create new session.
    pub fn create_session(
        self: *SessionManager,
        name: []const u8,
    ) ?u32 {
        if (self.sessions_len >= MAX_SESSIONS) {
            return null;
        }
        if (name.len > MAX_SESSION_NAME_LEN) {
            return null;
        }
        const session_id = self.next_session_id;
        self.next_session_id += 1;
        self.sessions[self.sessions_len] = WindowSession.init(session_id, name);
        self.sessions_len += 1;
        return session_id;
    }

    // Find session by ID.
    pub fn find_session(
        self: *SessionManager,
        session_id: u32,
    ) ?*WindowSession {
        std.debug.assert(session_id > 0);
        var i: u32 = 0;
        while (i < self.sessions_len) : (i += 1) {
            if (self.sessions[i].session_id == session_id and self.sessions[i].active) {
                return &self.sessions[i];
            }
        }
        return null;
    }

    // Find session by name.
    pub fn find_session_by_name(
        self: *SessionManager,
        name: []const u8,
    ) ?*WindowSession {
        var i: u32 = 0;
        while (i < self.sessions_len) : (i += 1) {
            const session = &self.sessions[i];
            if (!session.active) {
                continue;
            }
            if (session.name_len == name.len) {
                var match: bool = true;
                var j: u32 = 0;
                while (j < session.name_len) : (j += 1) {
                    if (session.name[j] != name[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    return session;
                }
            }
        }
        return null;
    }

    // Delete session.
    pub fn delete_session(self: *SessionManager, session_id: u32) bool {
        std.debug.assert(session_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.sessions_len) : (i += 1) {
            if (self.sessions[i].session_id == session_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining sessions left.
        while (i < self.sessions_len - 1) : (i += 1) {
            self.sessions[i] = self.sessions[i + 1];
        }
        self.sessions_len -= 1;
        return true;
    }

    // Get session count.
    pub fn get_session_count(self: *const SessionManager) u32 {
        return self.sessions_len;
    }

    // Clear all sessions.
    pub fn clear_all(self: *SessionManager) void {
        self.sessions_len = 0;
    }
};

