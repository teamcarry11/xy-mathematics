//! Grain OS Keyboard Shortcuts: Rectangle-inspired keyboard shortcuts.
//!
//! Why: Provide keyboard shortcuts for window management actions.
//! Architecture: Maps key combinations to window actions.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const input_handler = @import("input_handler.zig");
const window_actions = @import("window_actions.zig");
const compositor = @import("compositor.zig");

// Bounded: Max number of keyboard shortcuts.
pub const MAX_SHORTCUTS: u32 = 64;

// Modifier flags (matching kernel input event format).
pub const MODIFIER_CTRL: u8 = 0x01;
pub const MODIFIER_ALT: u8 = 0x02;
pub const MODIFIER_SHIFT: u8 = 0x04;
pub const MODIFIER_META: u8 = 0x08;

// Key codes (matching kernel input event format).
pub const KEY_LEFT: u32 = 0x25;
pub const KEY_UP: u32 = 0x26;
pub const KEY_RIGHT: u32 = 0x27;
pub const KEY_DOWN: u32 = 0x28;
pub const KEY_RETURN: u32 = 0x0D;
pub const KEY_BACKSPACE: u32 = 0x08;
pub const KEY_EQUALS: u32 = 0x3D;
pub const KEY_MINUS: u32 = 0x2D;
pub const KEY_U: u32 = 0x55;
pub const KEY_I: u32 = 0x49;
pub const KEY_J: u32 = 0x4A;
pub const KEY_K: u32 = 0x4B;
pub const KEY_D: u32 = 0x44;
pub const KEY_F: u32 = 0x46;
pub const KEY_G: u32 = 0x47;
pub const KEY_E: u32 = 0x45;
pub const KEY_T: u32 = 0x54;
pub const KEY_C: u32 = 0x43;
pub const KEY_TAB: u32 = 0x09;

// Keyboard shortcut: key combination and action.
pub const KeyboardShortcut = struct {
    modifiers: u8,
    key_code: u32,
    action: window_actions.WindowAction,
    name: []const u8,
};

// Shortcut registry: maps key combinations to actions.
pub const ShortcutRegistry = struct {
    shortcuts: [MAX_SHORTCUTS]KeyboardShortcut,
    shortcuts_len: u32,

    pub fn init() ShortcutRegistry {
        var registry = ShortcutRegistry{
            .shortcuts = undefined,
            .shortcuts_len = 0,
        };
        // Initialize all shortcuts to zero.
        var i: u32 = 0;
        while (i < MAX_SHORTCUTS) : (i += 1) {
            registry.shortcuts[i] = KeyboardShortcut{
                .modifiers = 0,
                .key_code = 0,
                .action = undefined,
                .name = "",
            };
        }
        // Register Rectangle-inspired shortcuts.
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_LEFT, window_actions.action_left_half, "left-half");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_RIGHT, window_actions.action_right_half, "right-half");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_UP, window_actions.action_top_half, "top-half");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_DOWN, window_actions.action_bottom_half, "bottom-half");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_U, window_actions.action_top_left, "top-left");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_I, window_actions.action_top_right, "top-right");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_J, window_actions.action_bottom_left, "bottom-left");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_K, window_actions.action_bottom_right, "bottom-right");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_D, window_actions.action_first_third, "first-third");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_F, window_actions.action_center_third, "center-third");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_G, window_actions.action_last_third, "last-third");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_E, window_actions.action_first_two_thirds, "first-two-thirds");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_T, window_actions.action_last_two_thirds, "last-two-thirds");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_RETURN, action_maximize, "maximize");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_C, window_actions.action_center, "center");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_EQUALS, window_actions.action_larger, "larger");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT, KEY_MINUS, window_actions.action_smaller, "smaller");
        _ = registry.register_shortcut(MODIFIER_CTRL | MODIFIER_ALT | MODIFIER_SHIFT, KEY_UP, window_actions.action_maximize_height, "maximize-height");
        _ = registry.register_shortcut(MODIFIER_ALT, KEY_TAB, window_actions.action_switch_next, "switch-next");
        _ = registry.register_shortcut(MODIFIER_ALT | MODIFIER_SHIFT, KEY_TAB, window_actions.action_switch_previous, "switch-previous");
        std.debug.assert(registry.shortcuts_len <= MAX_SHORTCUTS);
        return registry;
    }

    pub fn register_shortcut(
        self: *ShortcutRegistry,
        modifiers: u8,
        key_code: u32,
        action: window_actions.WindowAction,
        name: []const u8,
    ) bool {
        std.debug.assert(self.shortcuts_len < MAX_SHORTCUTS);
        if (self.shortcuts_len >= MAX_SHORTCUTS) return false;
        self.shortcuts[self.shortcuts_len] = KeyboardShortcut{
            .modifiers = modifiers,
            .key_code = key_code,
            .action = action,
            .name = name,
        };
        self.shortcuts_len += 1;
        std.debug.assert(self.shortcuts_len <= MAX_SHORTCUTS);
        return true;
    }

    pub fn find_shortcut(
        self: *const ShortcutRegistry,
        modifiers: u8,
        key_code: u32,
    ) ?window_actions.WindowAction {
        std.debug.assert(key_code > 0);
        var i: u32 = 0;
        while (i < self.shortcuts_len) : (i += 1) {
            const shortcut = &self.shortcuts[i];
            if (shortcut.modifiers == modifiers and shortcut.key_code == key_code) {
                return shortcut.action;
            }
        }
        return null;
    }
};

// Wrapper for maximize_window method.
fn action_maximize(comp: *compositor.Compositor, window_id: u32) bool {
    return comp.maximize_window(window_id);
}

