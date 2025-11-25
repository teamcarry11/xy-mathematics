//! Grain OS Window Switching: Alt+Tab style window switching.
//!
//! Why: Provide window switching to cycle through open windows.
//! Architecture: Window order management and cycling.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Max windows in switch list.
pub const MAX_SWITCH_WINDOWS: u32 = 256;

// Window switch order: maintains order of windows for switching.
pub const WindowSwitchOrder = struct {
    window_ids: [MAX_SWITCH_WINDOWS]u32,
    window_ids_len: u32,
    current_index: u32,

    pub fn init() WindowSwitchOrder {
        var order = WindowSwitchOrder{
            .window_ids = undefined,
            .window_ids_len = 0,
            .current_index = 0,
        };
        var i: u32 = 0;
        while (i < MAX_SWITCH_WINDOWS) : (i += 1) {
            order.window_ids[i] = 0;
        }
        return order;
    }

    // Add window to switch order.
    pub fn add_window(self: *WindowSwitchOrder, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.window_ids_len >= MAX_SWITCH_WINDOWS) {
            return false;
        }
        // Check if window already exists.
        var i: u32 = 0;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                // Move to front.
                self.move_to_front(window_id);
                return true;
            }
        }
        // Add to front.
        self.window_ids[self.window_ids_len] = window_id;
        self.window_ids_len += 1;
        self.move_to_front(window_id);
        return true;
    }

    // Remove window from switch order.
    pub fn remove_window(self: *WindowSwitchOrder, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining windows left.
        while (i < self.window_ids_len - 1) : (i += 1) {
            self.window_ids[i] = self.window_ids[i + 1];
        }
        self.window_ids_len -= 1;
        // Adjust current index if needed.
        if (self.current_index >= self.window_ids_len and self.window_ids_len > 0) {
            self.current_index = self.window_ids_len - 1;
        }
        if (self.window_ids_len == 0) {
            self.current_index = 0;
        }
        return true;
    }

    // Move window to front of order.
    pub fn move_to_front(self: *WindowSwitchOrder, window_id: u32) void {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return;
        }
        // Shift windows before this one right.
        var j: u32 = i;
        while (j > 0) : (j -= 1) {
            self.window_ids[j] = self.window_ids[j - 1];
        }
        // Put window at front.
        self.window_ids[0] = window_id;
        self.current_index = 0;
    }

    // Get next window in cycle (forward).
    pub fn get_next(self: *WindowSwitchOrder) ?u32 {
        if (self.window_ids_len == 0) {
            return null;
        }
        self.current_index = (self.current_index + 1) % self.window_ids_len;
        return self.window_ids[self.current_index];
    }

    // Get previous window in cycle (backward).
    pub fn get_previous(self: *WindowSwitchOrder) ?u32 {
        if (self.window_ids_len == 0) {
            return null;
        }
        if (self.current_index == 0) {
            self.current_index = self.window_ids_len - 1;
        } else {
            self.current_index -= 1;
        }
        return self.window_ids[self.current_index];
    }

    // Get current window.
    pub fn get_current(self: *const WindowSwitchOrder) ?u32 {
        if (self.window_ids_len == 0) {
            return null;
        }
        return self.window_ids[self.current_index];
    }

    // Reset to first window.
    pub fn reset(self: *WindowSwitchOrder) void {
        self.current_index = 0;
    }
};

