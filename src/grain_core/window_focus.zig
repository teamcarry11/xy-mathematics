//! Grain OS Window Focus Management: Focus policies and tracking.
//!
//! Why: Provide flexible focus management with policies and history.
//! Architecture: Focus policy management and focus history tracking.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Max focus history entries.
pub const MAX_FOCUS_HISTORY: u32 = 64;

// Focus policy type.
pub const FocusPolicy = enum(u8) {
    click_to_focus, // Focus on click only.
    focus_follows_mouse, // Focus follows mouse movement.
    sloppy_focus, // Focus on mouse enter, unfocus on mouse leave.
};

// Focus history entry.
pub const FocusHistoryEntry = struct {
    window_id: u32,
    timestamp: u64, // Focus time in milliseconds.
};

// Focus manager: manages focus policies and history.
pub const FocusManager = struct {
    policy: FocusPolicy,
    focus_history: [MAX_FOCUS_HISTORY]FocusHistoryEntry,
    focus_history_len: u32,
    last_focus_time: u64,

    pub fn init() FocusManager {
        var manager = FocusManager{
            .policy = FocusPolicy.click_to_focus,
            .focus_history = undefined,
            .focus_history_len = 0,
            .last_focus_time = 0,
        };
        var i: u32 = 0;
        while (i < MAX_FOCUS_HISTORY) : (i += 1) {
            manager.focus_history[i] = FocusHistoryEntry{
                .window_id = 0,
                .timestamp = 0,
            };
        }
        return manager;
    }

    // Set focus policy.
    pub fn set_policy(self: *FocusManager, policy: FocusPolicy) void {
        self.policy = policy;
    }

    // Get focus policy.
    pub fn get_policy(self: *const FocusManager) FocusPolicy {
        return self.policy;
    }

    // Add focus to history.
    pub fn add_focus_history(
        self: *FocusManager,
        window_id: u32,
        timestamp: u64,
    ) void {
        std.debug.assert(window_id > 0);
        if (self.focus_history_len >= MAX_FOCUS_HISTORY) {
            // Shift history left (remove oldest).
            var i: u32 = 0;
            while (i < MAX_FOCUS_HISTORY - 1) : (i += 1) {
                self.focus_history[i] = self.focus_history[i + 1];
            }
            self.focus_history_len = MAX_FOCUS_HISTORY - 1;
        }
        self.focus_history[self.focus_history_len] = FocusHistoryEntry{
            .window_id = window_id,
            .timestamp = timestamp,
        };
        self.focus_history_len += 1;
        self.last_focus_time = timestamp;
    }

    // Get previous focused window.
    pub fn get_previous_focus(self: *const FocusManager) ?u32 {
        if (self.focus_history_len < 2) {
            return null;
        }
        // Return second-to-last entry (previous focus).
        return self.focus_history[self.focus_history_len - 2].window_id;
    }

    // Get focus history count.
    pub fn get_history_count(self: *const FocusManager) u32 {
        return self.focus_history_len;
    }

    // Clear focus history.
    pub fn clear_history(self: *FocusManager) void {
        self.focus_history_len = 0;
    }

    // Check if should focus on mouse move (focus-follows-mouse).
    pub fn should_focus_on_mouse_move(self: *const FocusManager) bool {
        return (self.policy == FocusPolicy.focus_follows_mouse or
            self.policy == FocusPolicy.sloppy_focus);
    }

    // Check if should unfocus on mouse leave (sloppy-focus).
    pub fn should_unfocus_on_mouse_leave(self: *const FocusManager) bool {
        return self.policy == FocusPolicy.sloppy_focus;
    }
};

