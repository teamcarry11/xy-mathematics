//! Grain OS Window Stacking: Z-order management for window layering.
//!
//! Why: Manage window stacking order for proper visual layering.
//! Architecture: Z-order list management and window raising/lowering.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max windows in stack.
pub const MAX_STACK_WINDOWS: u32 = 256;

// Window stack: maintains z-order of windows (bottom to top).
pub const WindowStack = struct {
    window_ids: [MAX_STACK_WINDOWS]u32,
    window_ids_len: u32,

    pub fn init() WindowStack {
        var stack = WindowStack{
            .window_ids = undefined,
            .window_ids_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_STACK_WINDOWS) : (i += 1) {
            stack.window_ids[i] = 0;
        }
        return stack;
    }

    // Add window to stack (at top).
    pub fn add_window(self: *WindowStack, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.window_ids_len >= MAX_STACK_WINDOWS) {
            return false;
        }
        // Check if window already exists.
        var i: u32 = 0;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                // Already in stack, raise to top.
                _ = self.raise_to_top(window_id);
                return true;
            }
        }
        // Add to top.
        self.window_ids[self.window_ids_len] = window_id;
        self.window_ids_len += 1;
        return true;
    }

    // Remove window from stack.
    pub fn remove_window(self: *WindowStack, window_id: u32) bool {
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
        return true;
    }

    // Raise window to top of stack.
    pub fn raise_to_top(self: *WindowStack, window_id: u32) bool {
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
        // Move to end (top of stack).
        while (i < self.window_ids_len - 1) : (i += 1) {
            self.window_ids[i] = self.window_ids[i + 1];
        }
        self.window_ids[self.window_ids_len - 1] = window_id;
        return true;
    }

    // Lower window to bottom of stack.
    pub fn lower_to_bottom(self: *WindowStack, window_id: u32) bool {
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
        // Move to beginning (bottom of stack).
        while (i > 0) : (i -= 1) {
            self.window_ids[i] = self.window_ids[i - 1];
        }
        self.window_ids[0] = window_id;
        return true;
    }

    // Get window at index (0 = bottom, len-1 = top).
    pub fn get_window_at(self: *const WindowStack, index: u32) ?u32 {
        if (index >= self.window_ids_len) {
            return null;
        }
        return self.window_ids[index];
    }

    // Get top window.
    pub fn get_top_window(self: *const WindowStack) ?u32 {
        if (self.window_ids_len == 0) {
            return null;
        }
        return self.window_ids[self.window_ids_len - 1];
    }

    // Get bottom window.
    pub fn get_bottom_window(self: *const WindowStack) ?u32 {
        if (self.window_ids_len == 0) {
            return null;
        }
        return self.window_ids[0];
    }

    // Get stack count.
    pub fn get_count(self: *const WindowStack) u32 {
        return self.window_ids_len;
    }

    // Clear stack.
    pub fn clear(self: *WindowStack) void {
        self.window_ids_len = 0;
    }
};

