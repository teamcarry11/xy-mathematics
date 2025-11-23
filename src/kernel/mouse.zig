//! Grain Basin Mouse Driver
//! Why: Kernel-side mouse state tracking (position, buttons).
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Maximum mouse X coordinate.
/// Why: Bounded mouse position for safety.
pub const MAX_MOUSE_X: u32 = 65535;

/// Maximum mouse Y coordinate.
/// Why: Bounded mouse position for safety.
pub const MAX_MOUSE_Y: u32 = 65535;

/// Mouse button type.
/// Why: Explicit mouse button enumeration.
pub const MouseButton = enum(u8) {
    left = 0,
    right = 1,
    middle = 2,
    button4 = 3,
    button5 = 4,
};

/// Mouse button state (pressed or released).
/// Why: Explicit button state enumeration.
pub const ButtonState = enum(u8) {
    released = 0,
    pressed = 1,
};

/// Maximum number of mouse buttons.
/// Why: Bounded button state table for safety.
pub const MAX_BUTTONS: u32 = 5;

/// Mouse driver state.
/// Why: Track mouse state for kernel input handling.
/// Grain Style: Static allocation, bounded button state table.
pub const Mouse = struct {
    /// Current X coordinate (0 to MAX_MOUSE_X).
    x: u32,
    
    /// Current Y coordinate (0 to MAX_MOUSE_Y).
    y: u32,
    
    /// Button states (pressed/released for each button).
    /// Why: Track which buttons are currently pressed.
    /// Grain Style: Static allocation, max 5 buttons.
    button_states: [MAX_BUTTONS]ButtonState,
    
    /// Last button pressed (null if none).
    /// Why: Track most recent button press for polling.
    last_button: ?MouseButton,
    
    /// Last button state change (pressed or released).
    /// Why: Track most recent button state change.
    last_button_state: ButtonState,
    
    /// Initialize mouse driver.
    /// Why: Set up mouse state.
    pub fn init() Mouse {
        return Mouse{
            .x = 0,
            .y = 0,
            .button_states = [_]ButtonState{.released} ** MAX_BUTTONS,
            .last_button = null,
            .last_button_state = .released,
        };
    }
    
    /// Set mouse position.
    /// Why: Update mouse coordinates.
    /// Contract: x must be <= MAX_MOUSE_X, y must be <= MAX_MOUSE_Y.
    pub fn set_position(self: *Mouse, x: u32, y: u32) void {
        // Assert: X coordinate must be <= MAX_MOUSE_X.
        Debug.kassert(x <= MAX_MOUSE_X, "X > MAX_MOUSE_X", .{});
        
        // Assert: Y coordinate must be <= MAX_MOUSE_Y.
        Debug.kassert(y <= MAX_MOUSE_Y, "Y > MAX_MOUSE_Y", .{});
        
        // Update position.
        self.x = x;
        self.y = y;
        
        // Assert: Position must be updated.
        Debug.kassert(self.x == x, "X not updated", .{});
        Debug.kassert(self.y == y, "Y not updated", .{});
    }
    
    /// Get mouse X coordinate.
    /// Why: Query mouse X position.
    /// Returns: X coordinate (0 to MAX_MOUSE_X).
    pub fn get_x(self: *const Mouse) u32 {
        // Assert: X coordinate must be <= MAX_MOUSE_X.
        Debug.kassert(self.x <= MAX_MOUSE_X, "X > MAX_MOUSE_X", .{});
        
        return self.x;
    }
    
    /// Get mouse Y coordinate.
    /// Why: Query mouse Y position.
    /// Returns: Y coordinate (0 to MAX_MOUSE_Y).
    pub fn get_y(self: *const Mouse) u32 {
        // Assert: Y coordinate must be <= MAX_MOUSE_Y.
        Debug.kassert(self.y <= MAX_MOUSE_Y, "Y > MAX_MOUSE_Y", .{});
        
        return self.y;
    }
    
    /// Handle button press event.
    /// Why: Update mouse state when button is pressed.
    /// Contract: button must be valid MouseButton.
    pub fn handle_button_press(self: *Mouse, button: MouseButton) void {
        // Assert: Button must be valid.
        Debug.kassert(@intFromEnum(button) < MAX_BUTTONS, "Button >= MAX_BUTTONS", .{});
        
        const button_idx = @as(u32, @intFromEnum(button));
        
        // Update button state.
        self.button_states[button_idx] = .pressed;
        self.last_button = button;
        self.last_button_state = .pressed;
        
        // Assert: Button state must be updated.
        Debug.kassert(self.button_states[button_idx] == .pressed, "Button state not pressed", .{});
        Debug.kassert(self.last_button == button, "Last button mismatch", .{});
    }
    
    /// Handle button release event.
    /// Why: Update mouse state when button is released.
    /// Contract: button must be valid MouseButton.
    pub fn handle_button_release(self: *Mouse, button: MouseButton) void {
        // Assert: Button must be valid.
        Debug.kassert(@intFromEnum(button) < MAX_BUTTONS, "Button >= MAX_BUTTONS", .{});
        
        const button_idx = @as(u32, @intFromEnum(button));
        
        // Update button state.
        self.button_states[button_idx] = .released;
        self.last_button = button;
        self.last_button_state = .released;
        
        // Assert: Button state must be updated.
        Debug.kassert(self.button_states[button_idx] == .released, "Button state not released", .{});
        Debug.kassert(self.last_button == button, "Last button mismatch", .{});
    }
    
    /// Check if button is pressed.
    /// Why: Query button state for polling.
    /// Contract: button must be valid MouseButton.
    /// Returns: true if button is pressed, false otherwise.
    pub fn is_button_pressed(self: *const Mouse, button: MouseButton) bool {
        // Assert: Button must be valid.
        Debug.kassert(@intFromEnum(button) < MAX_BUTTONS, "Button >= MAX_BUTTONS", .{});
        
        const button_idx = @as(u32, @intFromEnum(button));
        const pressed = self.button_states[button_idx] == .pressed;
        
        // Assert: Result must be consistent with button state.
        Debug.kassert(pressed == (self.button_states[button_idx] == .pressed), "Button state inconsistent", .{});
        
        return pressed;
    }
    
    /// Get last button pressed.
    /// Why: Query most recent button press for polling.
    /// Returns: Last button (null if none).
    pub fn get_last_button(self: *const Mouse) ?MouseButton {
        // Assert: Last button must be valid or null.
        if (self.last_button) |button| {
            Debug.kassert(@intFromEnum(button) < MAX_BUTTONS, "Last button invalid", .{});
        }
        
        return self.last_button;
    }
    
    /// Get last button state.
    /// Why: Query most recent button state change for polling.
    /// Returns: Last button state (pressed or released).
    pub fn get_last_button_state(self: *const Mouse) ButtonState {
        // Assert: Last button state must be valid.
        Debug.kassert(self.last_button_state == .pressed or self.last_button_state == .released, "Last button state invalid", .{});
        
        return self.last_button_state;
    }
    
    /// Clear all button states.
    /// Why: Reset mouse state (e.g., on driver reset).
    pub fn clear_all_buttons(self: *Mouse) void {
        // Clear all button states.
        for (0..MAX_BUTTONS) |i| {
            self.button_states[i] = .released;
        }
        self.last_button = null;
        self.last_button_state = .released;
        
        // Assert: All buttons must be released.
        for (0..MAX_BUTTONS) |i| {
            Debug.kassert(self.button_states[i] == .released, "Button not released", .{});
        }
        Debug.kassert(self.last_button == null, "Last button not null", .{});
    }
};

// Test mouse initialization.
test "mouse init" {
    const mouse = Mouse.init();
    
    // Assert: Mouse must be initialized.
    try std.testing.expect(mouse.x == 0);
    try std.testing.expect(mouse.y == 0);
    try std.testing.expect(mouse.last_button == null);
    try std.testing.expect(mouse.last_button_state == .released);
    
    // Assert: All buttons must be released.
    for (0..MAX_BUTTONS) |i| {
        try std.testing.expect(mouse.button_states[i] == .released);
    }
}

// Test mouse position.
test "mouse position" {
    var mouse = Mouse.init();
    
    mouse.set_position(100, 200);
    
    // Assert: Position must be updated.
    try std.testing.expect(mouse.get_x() == 100);
    try std.testing.expect(mouse.get_y() == 200);
}

// Test button press.
test "mouse button press" {
    var mouse = Mouse.init();
    
    mouse.handle_button_press(.left);
    
    // Assert: Button must be pressed.
    try std.testing.expect(mouse.is_button_pressed(.left));
    try std.testing.expect(mouse.get_last_button() == .left);
    try std.testing.expect(mouse.get_last_button_state() == .pressed);
}

// Test button release.
test "mouse button release" {
    var mouse = Mouse.init();
    
    mouse.handle_button_press(.left);
    mouse.handle_button_release(.left);
    
    // Assert: Button must be released.
    try std.testing.expect(!mouse.is_button_pressed(.left));
    try std.testing.expect(mouse.get_last_button() == .left);
    try std.testing.expect(mouse.get_last_button_state() == .released);
}

// Test multiple buttons.
test "mouse multiple buttons" {
    var mouse = Mouse.init();
    
    mouse.handle_button_press(.left);
    mouse.handle_button_press(.right);
    
    // Assert: Both buttons must be pressed.
    try std.testing.expect(mouse.is_button_pressed(.left));
    try std.testing.expect(mouse.is_button_pressed(.right));
    try std.testing.expect(mouse.get_last_button() == .right);
    
    mouse.handle_button_release(.left);
    
    // Assert: Left released, right still pressed.
    try std.testing.expect(!mouse.is_button_pressed(.left));
    try std.testing.expect(mouse.is_button_pressed(.right));
}

// Test clear all buttons.
test "mouse clear all buttons" {
    var mouse = Mouse.init();
    
    mouse.handle_button_press(.left);
    mouse.handle_button_press(.right);
    mouse.clear_all_buttons();
    
    // Assert: All buttons must be released.
    try std.testing.expect(!mouse.is_button_pressed(.left));
    try std.testing.expect(!mouse.is_button_pressed(.right));
    try std.testing.expect(mouse.get_last_button() == null);
}

