//! Grain Basin Keyboard Driver
//! Why: Kernel-side keyboard state tracking and key code abstraction.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Maximum number of keys to track.
/// Why: Bounded key state table for safety and static allocation.
pub const MAX_KEYS: u32 = 256;

/// Key code type.
/// Why: Explicit key code type for type safety.
pub const KeyCode = u32;

/// Key state (pressed or released).
/// Why: Explicit key state enumeration.
pub const KeyState = enum(u8) {
    released = 0,
    pressed = 1,
};

/// Keyboard driver state.
/// Why: Track keyboard state for kernel input handling.
/// Grain Style: Static allocation, bounded key state table.
pub const Keyboard = struct {
    /// Key state table (pressed/released for each key).
    /// Why: Track which keys are currently pressed.
    /// Grain Style: Static allocation, max 256 keys.
    key_states: [MAX_KEYS]KeyState,
    
    /// Last key code pressed (0 if none).
    /// Why: Track most recent key press for polling.
    last_key_code: KeyCode,
    
    /// Last key state change (pressed or released).
    /// Why: Track most recent key state change.
    last_key_state: KeyState,
    
    /// Initialize keyboard driver.
    /// Why: Set up keyboard state.
    pub fn init() Keyboard {
        return Keyboard{
            .key_states = [_]KeyState{.released} ** MAX_KEYS,
            .last_key_code = 0,
            .last_key_state = .released,
        };
    }
    
    /// Handle key press event.
    /// Why: Update keyboard state when key is pressed.
    /// Contract: key_code must be < MAX_KEYS.
    pub fn handle_key_press(self: *Keyboard, key_code: KeyCode) void {
        // Assert: Key code must be < MAX_KEYS.
        Debug.kassert(key_code < MAX_KEYS, "Key code >= MAX_KEYS", .{});
        
        // Update key state.
        self.key_states[key_code] = .pressed;
        self.last_key_code = key_code;
        self.last_key_state = .pressed;
        
        // Assert: Key state must be updated.
        Debug.kassert(self.key_states[key_code] == .pressed, "Key state not pressed", .{});
        Debug.kassert(self.last_key_code == key_code, "Last key code mismatch", .{});
    }
    
    /// Handle key release event.
    /// Why: Update keyboard state when key is released.
    /// Contract: key_code must be < MAX_KEYS.
    pub fn handle_key_release(self: *Keyboard, key_code: KeyCode) void {
        // Assert: Key code must be < MAX_KEYS.
        Debug.kassert(key_code < MAX_KEYS, "Key code >= MAX_KEYS", .{});
        
        // Update key state.
        self.key_states[key_code] = .released;
        self.last_key_code = key_code;
        self.last_key_state = .released;
        
        // Assert: Key state must be updated.
        Debug.kassert(self.key_states[key_code] == .released, "Key state not released", .{});
        Debug.kassert(self.last_key_code == key_code, "Last key code mismatch", .{});
    }
    
    /// Check if key is pressed.
    /// Why: Query key state for polling.
    /// Contract: key_code must be < MAX_KEYS.
    /// Returns: true if key is pressed, false otherwise.
    pub fn is_key_pressed(self: *const Keyboard, key_code: KeyCode) bool {
        // Assert: Key code must be < MAX_KEYS.
        Debug.kassert(key_code < MAX_KEYS, "Key code >= MAX_KEYS", .{});
        
        const pressed = self.key_states[key_code] == .pressed;
        
        // Assert: Result must be consistent with key state.
        Debug.kassert(pressed == (self.key_states[key_code] == .pressed), "Key state inconsistent", .{});
        
        return pressed;
    }
    
    /// Get last key code.
    /// Why: Query most recent key press for polling.
    /// Returns: Last key code (0 if none).
    pub fn get_last_key_code(self: *const Keyboard) KeyCode {
        // Assert: Last key code must be < MAX_KEYS or 0.
        Debug.kassert(self.last_key_code < MAX_KEYS or self.last_key_code == 0, "Last key code invalid", .{});
        
        return self.last_key_code;
    }
    
    /// Get last key state.
    /// Why: Query most recent key state change for polling.
    /// Returns: Last key state (pressed or released).
    pub fn get_last_key_state(self: *const Keyboard) KeyState {
        // Assert: Last key state must be valid.
        Debug.kassert(self.last_key_state == .pressed or self.last_key_state == .released, "Last key state invalid", .{});
        
        return self.last_key_state;
    }
    
    /// Clear all key states.
    /// Why: Reset keyboard state (e.g., on driver reset).
    pub fn clear_all(self: *Keyboard) void {
        // Clear all key states.
        for (0..MAX_KEYS) |i| {
            self.key_states[i] = .released;
        }
        self.last_key_code = 0;
        self.last_key_state = .released;
        
        // Assert: All keys must be released.
        for (0..MAX_KEYS) |i| {
            Debug.kassert(self.key_states[i] == .released, "Key not released", .{});
        }
        Debug.kassert(self.last_key_code == 0, "Last key code not 0", .{});
    }
};

// Test keyboard initialization.
test "keyboard init" {
    const keyboard = Keyboard.init();
    
    // Assert: Keyboard must be initialized.
    try std.testing.expect(keyboard.last_key_code == 0);
    try std.testing.expect(keyboard.last_key_state == .released);
    
    // Assert: All keys must be released.
    for (0..MAX_KEYS) |i| {
        try std.testing.expect(keyboard.key_states[i] == .released);
    }
}

// Test key press.
test "keyboard key press" {
    var keyboard = Keyboard.init();
    
    const key_code: KeyCode = 65; // 'A' key
    keyboard.handle_key_press(key_code);
    
    // Assert: Key must be pressed.
    try std.testing.expect(keyboard.is_key_pressed(key_code));
    try std.testing.expect(keyboard.get_last_key_code() == key_code);
    try std.testing.expect(keyboard.get_last_key_state() == .pressed);
}

// Test key release.
test "keyboard key release" {
    var keyboard = Keyboard.init();
    
    const key_code: KeyCode = 65; // 'A' key
    keyboard.handle_key_press(key_code);
    keyboard.handle_key_release(key_code);
    
    // Assert: Key must be released.
    try std.testing.expect(!keyboard.is_key_pressed(key_code));
    try std.testing.expect(keyboard.get_last_key_code() == key_code);
    try std.testing.expect(keyboard.get_last_key_state() == .released);
}

// Test multiple keys.
test "keyboard multiple keys" {
    var keyboard = Keyboard.init();
    
    const key1: KeyCode = 65; // 'A'
    const key2: KeyCode = 66; // 'B'
    
    keyboard.handle_key_press(key1);
    keyboard.handle_key_press(key2);
    
    // Assert: Both keys must be pressed.
    try std.testing.expect(keyboard.is_key_pressed(key1));
    try std.testing.expect(keyboard.is_key_pressed(key2));
    try std.testing.expect(keyboard.get_last_key_code() == key2);
    
    keyboard.handle_key_release(key1);
    
    // Assert: Key1 released, key2 still pressed.
    try std.testing.expect(!keyboard.is_key_pressed(key1));
    try std.testing.expect(keyboard.is_key_pressed(key2));
}

// Test clear all.
test "keyboard clear all" {
    var keyboard = Keyboard.init();
    
    keyboard.handle_key_press(65);
    keyboard.handle_key_press(66);
    keyboard.clear_all();
    
    // Assert: All keys must be released.
    try std.testing.expect(!keyboard.is_key_pressed(65));
    try std.testing.expect(!keyboard.is_key_pressed(66));
    try std.testing.expect(keyboard.get_last_key_code() == 0);
}

