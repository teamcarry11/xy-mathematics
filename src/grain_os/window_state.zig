//! Grain OS Window State: Save and restore window configurations.
//!
//! Why: Persist window positions, sizes, and states across sessions.
//! Architecture: Window state serialization and restoration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Max windows in state.
pub const MAX_STATE_WINDOWS: u32 = 256;

// Bounded: Max state name length.
pub const MAX_STATE_NAME_LEN: u32 = 64;

// Window state entry: saved window configuration.
pub const WindowStateEntry = struct {
    window_id: u32,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    minimized: bool,
    maximized: bool,
    workspace_id: u32,
    title: [compositor.MAX_TITLE_LEN]u8,
    title_len: u32,
};

// Window state manager: manages saved window states.
pub const WindowStateManager = struct {
    entries: [MAX_STATE_WINDOWS]WindowStateEntry,
    entries_len: u32,

    pub fn init() WindowStateManager {
        var manager = WindowStateManager{
            .entries = undefined,
            .entries_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_STATE_WINDOWS) : (i += 1) {
            manager.entries[i] = WindowStateEntry{
                .window_id = 0,
                .x = 0,
                .y = 0,
                .width = 0,
                .height = 0,
                .minimized = false,
                .maximized = false,
                .workspace_id = 0,
                .title = undefined,
                .title_len = 0,
            };
            var j: u32 = 0;
            while (j < compositor.MAX_TITLE_LEN) : (j += 1) {
                manager.entries[i].title[j] = 0;
            }
        }
        return manager;
    }

    // Save window state.
    pub fn save_window(
        self: *WindowStateManager,
        window_id: u32,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        minimized: bool,
        maximized: bool,
        workspace_id: u32,
        title: []const u8,
    ) bool {
        std.debug.assert(window_id > 0);
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        if (self.entries_len >= MAX_STATE_WINDOWS) {
            return false;
        }
        // Check if window already exists, update it.
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].window_id == window_id) {
                self.entries[i].x = x;
                self.entries[i].y = y;
                self.entries[i].width = width;
                self.entries[i].height = height;
                self.entries[i].minimized = minimized;
                self.entries[i].maximized = maximized;
                self.entries[i].workspace_id = workspace_id;
                const copy_len = @min(title.len, compositor.MAX_TITLE_LEN);
                var j: u32 = 0;
                while (j < compositor.MAX_TITLE_LEN) : (j += 1) {
                    self.entries[i].title[j] = 0;
                }
                j = 0;
                while (j < copy_len) : (j += 1) {
                    self.entries[i].title[j] = title[j];
                }
                self.entries[i].title_len = @intCast(copy_len);
                return true;
            }
        }
        // Add new entry.
        self.entries[self.entries_len] = WindowStateEntry{
            .window_id = window_id,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .minimized = minimized,
            .maximized = maximized,
            .workspace_id = workspace_id,
            .title = undefined,
            .title_len = 0,
        };
        const copy_len = @min(title.len, compositor.MAX_TITLE_LEN);
        var j: u32 = 0;
        while (j < compositor.MAX_TITLE_LEN) : (j += 1) {
            self.entries[self.entries_len].title[j] = 0;
        }
        j = 0;
        while (j < copy_len) : (j += 1) {
            self.entries[self.entries_len].title[j] = title[j];
        }
        self.entries[self.entries_len].title_len = @intCast(copy_len);
        self.entries_len += 1;
        return true;
    }

    // Get saved window state.
    pub fn get_window_state(
        self: *const WindowStateManager,
        window_id: u32,
    ) ?WindowStateEntry {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].window_id == window_id) {
                return self.entries[i];
            }
        }
        return null;
    }

    // Remove window state.
    pub fn remove_window(self: *WindowStateManager, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].window_id == window_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining entries left.
        while (i < self.entries_len - 1) : (i += 1) {
            self.entries[i] = self.entries[i + 1];
        }
        self.entries_len -= 1;
        return true;
    }

    // Clear all saved states.
    pub fn clear(self: *WindowStateManager) void {
        self.entries_len = 0;
    }

    // Get number of saved states.
    pub fn get_count(self: *const WindowStateManager) u32 {
        return self.entries_len;
    }
};

