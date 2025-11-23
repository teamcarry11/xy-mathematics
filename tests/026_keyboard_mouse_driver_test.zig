//! Keyboard and Mouse Driver Tests
//! Why: Comprehensive TigerStyle tests for keyboard and mouse driver functionality.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const Keyboard = basin_kernel.basin_kernel.Keyboard;
const Mouse = basin_kernel.basin_kernel.Mouse;
const KeyCode = basin_kernel.basin_kernel.KeyCode;
const RawIO = basin_kernel.RawIO;

// Test keyboard driver integration.
test "keyboard driver integration" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    const kernel_instance = BasinKernel.init();
    
    // Assert: Keyboard must be initialized.
    try std.testing.expect(kernel_instance.keyboard.last_key_code == 0);
    try std.testing.expect(kernel_instance.keyboard.last_key_state == .released);
}

// Test mouse driver integration.
test "mouse driver integration" {
    const kernel_instance = BasinKernel.init();
    
    // Assert: Mouse must be initialized.
    try std.testing.expect(kernel_instance.mouse.x == 0);
    try std.testing.expect(kernel_instance.mouse.y == 0);
    try std.testing.expect(kernel_instance.mouse.last_button == null);
}

// Test keyboard key sequence.
test "keyboard key sequence" {
    var keyboard_instance = Keyboard.init();
    
    // Press 'A', then 'B', then release 'A'.
    keyboard_instance.handle_key_press(65); // 'A'
    keyboard_instance.handle_key_press(66); // 'B'
    
    // Assert: Both keys must be pressed.
    try std.testing.expect(keyboard_instance.is_key_pressed(65));
    try std.testing.expect(keyboard_instance.is_key_pressed(66));
    try std.testing.expect(keyboard_instance.get_last_key_code() == 66);
    
    keyboard_instance.handle_key_release(65);
    
    // Assert: 'A' released, 'B' still pressed.
    try std.testing.expect(!keyboard_instance.is_key_pressed(65));
    try std.testing.expect(keyboard_instance.is_key_pressed(66));
    try std.testing.expect(keyboard_instance.get_last_key_state() == .released);
}

// Test mouse position tracking.
test "mouse position tracking" {
    var mouse_instance = Mouse.init();
    
    // Move mouse to different positions.
    mouse_instance.set_position(100, 200);
    try std.testing.expect(mouse_instance.get_x() == 100);
    try std.testing.expect(mouse_instance.get_y() == 200);
    
    mouse_instance.set_position(300, 400);
    try std.testing.expect(mouse_instance.get_x() == 300);
    try std.testing.expect(mouse_instance.get_y() == 400);
}

// Test mouse button sequence.
test "mouse button sequence" {
    var mouse_instance2 = Mouse.init();
    
    // Press left, then right, then release left.
    mouse_instance2.handle_button_press(.left);
    mouse_instance2.handle_button_press(.right);
    
    // Assert: Both buttons must be pressed.
    try std.testing.expect(mouse_instance2.is_button_pressed(.left));
    try std.testing.expect(mouse_instance2.is_button_pressed(.right));
    try std.testing.expect(mouse_instance2.get_last_button() == .right);
    
    mouse_instance2.handle_button_release(.left);
    
    // Assert: Left released, right still pressed.
    try std.testing.expect(!mouse_instance2.is_button_pressed(.left));
    try std.testing.expect(mouse_instance2.is_button_pressed(.right));
    try std.testing.expect(mouse_instance2.get_last_button_state() == .released);
}

// Test keyboard clear all.
test "keyboard clear all keys" {
    var keyboard_instance = Keyboard.init();
    
    keyboard_instance.handle_key_press(65);
    keyboard_instance.handle_key_press(66);
    keyboard_instance.handle_key_press(67);
    keyboard_instance.clear_all();
    
    // Assert: All keys must be released.
    try std.testing.expect(!keyboard_instance.is_key_pressed(65));
    try std.testing.expect(!keyboard_instance.is_key_pressed(66));
    try std.testing.expect(!keyboard_instance.is_key_pressed(67));
    try std.testing.expect(keyboard_instance.get_last_key_code() == 0);
    try std.testing.expect(keyboard_instance.get_last_key_state() == .released);
}

// Test mouse clear all buttons.
test "mouse clear all buttons" {
    var mouse_instance3 = Mouse.init();
    
    mouse_instance3.handle_button_press(.left);
    mouse_instance3.handle_button_press(.right);
    mouse_instance3.handle_button_press(.middle);
    mouse_instance3.clear_all_buttons();
    
    // Assert: All buttons must be released.
    try std.testing.expect(!mouse_instance3.is_button_pressed(.left));
    try std.testing.expect(!mouse_instance3.is_button_pressed(.right));
    try std.testing.expect(!mouse_instance3.is_button_pressed(.middle));
    try std.testing.expect(mouse_instance3.get_last_button() == null);
    try std.testing.expect(mouse_instance3.get_last_button_state() == .released);
}

// Test keyboard and mouse together.
test "keyboard and mouse together" {
    var keyboard_instance4 = Keyboard.init();
    var mouse_instance4 = Mouse.init();
    
    // Simulate typing and clicking.
    keyboard_instance4.handle_key_press(65); // 'A'
    mouse_instance4.set_position(100, 200);
    mouse_instance4.handle_button_press(.left);
    
    // Assert: Both devices must track state correctly.
    try std.testing.expect(keyboard_instance4.is_key_pressed(65));
    try std.testing.expect(mouse_instance4.get_x() == 100);
    try std.testing.expect(mouse_instance4.get_y() == 200);
    try std.testing.expect(mouse_instance4.is_button_pressed(.left));
    
    keyboard_instance4.handle_key_release(65);
    mouse_instance4.handle_button_release(.left);
    
    // Assert: Both devices must track release correctly.
    try std.testing.expect(!keyboard_instance4.is_key_pressed(65));
    try std.testing.expect(!mouse_instance4.is_button_pressed(.left));
}

// Test keyboard last key tracking.
test "keyboard last key tracking" {
    var keyboard_instance5 = Keyboard.init();
    
    // Press multiple keys, verify last key is tracked.
    keyboard_instance5.handle_key_press(65); // 'A'
    try std.testing.expect(keyboard_instance5.get_last_key_code() == 65);
    
    keyboard_instance5.handle_key_press(66); // 'B'
    try std.testing.expect(keyboard_instance5.get_last_key_code() == 66);
    
    keyboard_instance5.handle_key_release(66);
    try std.testing.expect(keyboard_instance5.get_last_key_code() == 66);
    try std.testing.expect(keyboard_instance5.get_last_key_state() == .released);
}

// Test mouse last button tracking.
test "mouse last button tracking" {
    var mouse_instance5 = Mouse.init();
    
    // Press multiple buttons, verify last button is tracked.
    mouse_instance5.handle_button_press(.left);
    try std.testing.expect(mouse_instance5.get_last_button() == .left);
    
    mouse_instance5.handle_button_press(.right);
    try std.testing.expect(mouse_instance5.get_last_button() == .right);
    
    mouse_instance5.handle_button_release(.right);
    try std.testing.expect(mouse_instance5.get_last_button() == .right);
    try std.testing.expect(mouse_instance5.get_last_button_state() == .released);
}

