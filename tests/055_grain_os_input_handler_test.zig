//! Tests for Grain OS input handler.
//!
//! Why: Verify input event parsing and handling.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const InputHandler = grain_os.input_handler.InputHandler;
const InputEvent = grain_os.input_handler.InputEvent;

// Mock syscall function for testing.
fn mock_syscall_no_event(
    syscall_num: u32,
    _arg1: u64,
    _arg2: u64,
    _arg3: u64,
    _arg4: u64,
) i64 {
    _ = _arg1;
    _ = _arg2;
    _ = _arg3;
    _ = _arg4;
    if (syscall_num == 60) {
        // read_input_event - would_block
        return -6;
    }
    return -1;
}

// Mock syscall function that returns a mouse event.
fn mock_syscall_mouse_event(
    syscall_num: u32,
    arg1: u64,
    _arg2: u64,
    _arg3: u64,
    _arg4: u64,
) i64 {
    _ = _arg2;
    _ = _arg3;
    _ = _arg4;
    if (syscall_num == 60) {
        // read_input_event - write mouse event to buffer.
        const buf = @as([*]u8, @ptrFromInt(@as(usize, @intCast(arg1))));
        buf[0] = 0; // event_type = mouse
        buf[1] = 0;
        buf[2] = 0;
        buf[3] = 0;
        buf[4] = 2; // kind = move
        buf[5] = 0; // button
        // x = 100 (little-endian)
        buf[6] = 100;
        buf[7] = 0;
        buf[8] = 0;
        buf[9] = 0;
        // y = 200 (little-endian)
        buf[10] = 200;
        buf[11] = 0;
        buf[12] = 0;
        buf[13] = 0;
        buf[14] = 0; // modifiers
        return 32; // event size
    }
    return -1;
}

test "input handler initialization" {
    var handler = InputHandler.init();
    std.debug.assert(handler.syscall_fn == null);
    handler.set_syscall_fn(mock_syscall_no_event);
    std.debug.assert(handler.syscall_fn != null);
}

test "input handler read event no event" {
    var handler = InputHandler.init();
    handler.set_syscall_fn(mock_syscall_no_event);
    const event = try handler.read_event();
    std.debug.assert(event == null);
}

test "input handler read mouse event" {
    var handler = InputHandler.init();
    handler.set_syscall_fn(mock_syscall_mouse_event);
    const event_opt = try handler.read_event();
    std.debug.assert(event_opt != null);
    if (event_opt) |event| {
        std.debug.assert(event.event_type == .mouse);
        std.debug.assert(event.mouse.kind == .move);
        std.debug.assert(event.mouse.x == 100);
        std.debug.assert(event.mouse.y == 200);
    }
}

test "input event parse mouse" {
    var buf: [32]u8 = undefined;
    buf[0] = 0; // event_type = mouse
    buf[4] = 1; // kind = up
    buf[5] = 0; // button = left
    // x = 150
    buf[6] = 150;
    buf[7] = 0;
    buf[8] = 0;
    buf[9] = 0;
    // y = 250
    buf[10] = 250;
    buf[11] = 0;
    buf[12] = 0;
    buf[13] = 0;
    buf[14] = 0; // modifiers
    const event = try InputEvent.parse_from_buffer(&buf);
    std.debug.assert(event.event_type == .mouse);
    std.debug.assert(event.mouse.kind == .up);
    std.debug.assert(event.mouse.x == 150);
    std.debug.assert(event.mouse.y == 250);
}

