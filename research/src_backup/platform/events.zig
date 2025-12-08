const std = @import("std");

/// Platform-agnostic event types for Aurora GUI.
/// ~<~ Glow Airbend: events flow from platform to Aurora core deterministically.

/// Mouse button types.
pub const MouseButton = enum {
    left,
    right,
    middle,
    other,
};

/// Mouse event: click, movement, drag.
pub const MouseEvent = struct {
    /// Event type: down, up, move, drag.
    kind: MouseEventKind,
    /// Button that triggered the event (for down/up).
    button: MouseButton,
    /// X coordinate in window space (0 = left edge).
    x: f64,
    /// Y coordinate in window space (0 = top edge, macOS convention).
    y: f64,
    /// Modifier keys pressed during event.
    modifiers: ModifierKeys,
    
    pub const MouseEventKind = enum {
        down,
        up,
        move,
        drag,
    };
};

/// Keyboard event: key press, release.
pub const KeyboardEvent = struct {
    /// Event type: down, up.
    kind: KeyboardEventKind,
    /// Key code (platform-specific, but we'll use ASCII/Unicode where possible).
    key_code: u32,
    /// Character (if printable), null otherwise.
    character: ?u21,
    /// Modifier keys pressed during event.
    modifiers: ModifierKeys,
    
    pub const KeyboardEventKind = enum {
        down,
        up,
    };
};

/// Modifier keys state.
pub const ModifierKeys = struct {
    command: bool = false,
    option: bool = false,
    shift: bool = false,
    control: bool = false,
    
    /// Convert Cocoa modifier flags to ModifierKeys struct.
    /// Grain Style: validate input, ensure deterministic conversion.
    pub fn fromCocoaFlags(flags: u32) ModifierKeys {
        // Assert: flags must be reasonable (not suspiciously large).
        // NSEventModifierFlagCommand = 1 << 20
        // NSEventModifierFlagOption = 1 << 19
        // NSEventModifierFlagShift = 1 << 17
        // NSEventModifierFlagControl = 1 << 18
        // Maximum valid flag value is around 0xFFFFFFFF, but we check for reasonable range.
        std.debug.assert(flags <= 0xFFFFFFFF);
        
        return ModifierKeys{
            .command = (flags & (1 << 20)) != 0,
            .option = (flags & (1 << 19)) != 0,
            .shift = (flags & (1 << 17)) != 0,
            .control = (flags & (1 << 18)) != 0,
        };
    }
};

/// Window focus event.
pub const FocusEvent = struct {
    /// Event type: gained, lost.
    kind: FocusEventKind,
    
    pub const FocusEventKind = enum {
        gained,
        lost,
    };
};

/// Event handler callback: processes events from platform.
/// Returns true if event was handled, false otherwise.
pub const EventHandler = struct {
    /// User data pointer (typically *TahoeSandbox or similar).
    user_data: *anyopaque,
    /// Mouse event handler.
    onMouse: *const fn (user_data: *anyopaque, event: MouseEvent) bool,
    /// Keyboard event handler.
    onKeyboard: *const fn (user_data: *anyopaque, event: KeyboardEvent) bool,
    /// Focus event handler.
    onFocus: *const fn (user_data: *anyopaque, event: FocusEvent) bool,
};

