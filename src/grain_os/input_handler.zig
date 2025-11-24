//! Grain OS Input Handler: Handle keyboard, mouse, and touch input events.
//!
//! Why: Process input events from kernel for compositor window management.
//! Architecture: Syscall-based input reading, event routing to windows.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const basin_kernel = @import("basin_kernel");

// Bounded: Max input event buffer size (32 bytes per event).
pub const MAX_EVENT_SIZE: u32 = 32;

// Syscall number (matching kernel/basin_kernel.zig).
const SYSCALL_READ_INPUT_EVENT: u32 = 60;

// Syscall function type.
const SyscallFn = *const fn (u32, u64, u64, u64, u64) i64;

// Input event types (matching kernel_vm/vm.zig).
pub const EventType = enum(u8) {
    mouse = 0,
    keyboard = 1,
};

// Mouse event kinds (matching kernel_vm/vm.zig).
// 0=down, 1=up, 2=move, 3=drag
pub const MouseEventKind = enum(u8) {
    down = 0,
    up = 1,
    move = 2,
    drag = 3,
};

// Keyboard event kinds (matching kernel_vm/vm.zig).
// 0=down, 1=up
pub const KeyboardEventKind = enum(u8) {
    down = 0,
    up = 1,
};

// Input event: parsed event from kernel.
pub const InputEvent = struct {
    event_type: EventType,
    mouse: struct {
        kind: MouseEventKind,
        button: u8,
        x: u32,
        y: u32,
        modifiers: u8,
    },
    keyboard: struct {
        kind: KeyboardEventKind,
        key_code: u32,
        character: u32,
        modifiers: u8,
    },

    pub fn parse_from_buffer(buf: []const u8) !InputEvent {
        std.debug.assert(buf.len >= MAX_EVENT_SIZE);
        const event_type_val = buf[0];
        const event_type = if (event_type_val == 0)
            EventType.mouse
        else if (event_type_val == 1)
            EventType.keyboard
        else
            return error.InvalidEventType;
        var event = InputEvent{
            .event_type = event_type,
            .mouse = undefined,
            .keyboard = undefined,
        };
        if (event_type == .mouse) {
            event.mouse.kind = @enumFromInt(buf[4]);
            event.mouse.button = buf[5];
            event.mouse.x = std.mem.readInt(u32, buf[6..10], .little);
            event.mouse.y = std.mem.readInt(u32, buf[10..14], .little);
            event.mouse.modifiers = buf[14];
        } else {
            event.keyboard.kind = @enumFromInt(buf[4]);
            event.keyboard.key_code = std.mem.readInt(u32, buf[8..12], .little);
            event.keyboard.character = std.mem.readInt(u32, buf[12..16], .little);
            event.keyboard.modifiers = buf[16];
        }
        return event;
    }
};

// Input handler: reads and processes input events.
pub const InputHandler = struct {
    // Syscall function pointer (set by kernel integration).
    syscall_fn: ?SyscallFn = null,
    // Event buffer for reading events.
    event_buf: [MAX_EVENT_SIZE]u8,

    pub fn init() InputHandler {
        var handler = InputHandler{
            .syscall_fn = null,
            .event_buf = undefined,
        };
        var i: u32 = 0;
        while (i < MAX_EVENT_SIZE) : (i += 1) {
            handler.event_buf[i] = 0;
        }
        return handler;
    }

    pub fn set_syscall_fn(
        self: *InputHandler,
        fn_ptr: SyscallFn,
    ) void {
        std.debug.assert(@intFromPtr(fn_ptr) != 0);
        self.syscall_fn = fn_ptr;
        std.debug.assert(self.syscall_fn != null);
    }

    // Read next input event (non-blocking).
    pub fn read_event(self: *InputHandler) !?InputEvent {
        std.debug.assert(self.syscall_fn != null);
        if (self.syscall_fn) |syscall| {
            const event_ptr = @intFromPtr(&self.event_buf);
            const result = syscall(
                SYSCALL_READ_INPUT_EVENT,
                event_ptr,
                0,
                0,
                0,
            );
            if (result < 0) {
                // Error or would_block.
                if (result == -6) {
                    return null; // would_block (no event available).
                }
                return error.SyscallError;
            }
            if (result == 0) {
                return null; // No event.
            }
            // Parse event from buffer.
            const event = try InputEvent.parse_from_buffer(&self.event_buf);
            return event;
        }
        return error.NoSyscallFn;
    }
};

