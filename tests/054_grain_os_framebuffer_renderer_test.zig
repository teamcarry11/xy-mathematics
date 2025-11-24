//! Tests for Grain OS framebuffer renderer.
//!
//! Why: Verify framebuffer rendering functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const FramebufferRenderer = grain_os.framebuffer_renderer.FramebufferRenderer;

// Mock syscall function for testing.
fn mock_syscall(
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    _arg4: u64,
) i64 {
    _ = _arg4;
    // Track syscalls for verification.
    if (syscall_num == 70) {
        // fb_clear
        std.debug.assert(arg1 <= 0xFFFFFFFF);
        return 0;
    }
    if (syscall_num == 71) {
        // fb_draw_pixel
        std.debug.assert(arg1 < 1024);
        std.debug.assert(arg2 < 768);
        std.debug.assert(arg3 <= 0xFFFFFFFF);
        return 0;
    }
    return -1;
}

test "framebuffer renderer initialization" {
    var renderer = FramebufferRenderer.init();
    std.debug.assert(renderer.syscall_fn == null);
    renderer.set_syscall_fn(mock_syscall);
    std.debug.assert(renderer.syscall_fn != null);
}

test "framebuffer renderer clear" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    renderer.clear(grain_os.framebuffer_renderer.COLOR_DARK_BG);
    std.debug.assert(renderer.syscall_fn != null);
}

test "framebuffer renderer draw pixel" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    renderer.draw_pixel(100, 200, grain_os.framebuffer_renderer.COLOR_WHITE);
    std.debug.assert(renderer.syscall_fn != null);
}

test "framebuffer renderer draw rect" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    renderer.draw_rect(10, 20, 100, 50, grain_os.framebuffer_renderer.COLOR_BLUE);
    std.debug.assert(renderer.syscall_fn != null);
}

test "framebuffer renderer draw rect bounds" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    // Test rectangle that extends beyond framebuffer (should be clipped).
    renderer.draw_rect(1000, 700, 100, 100, grain_os.framebuffer_renderer.COLOR_RED);
    std.debug.assert(renderer.syscall_fn != null);
}

test "framebuffer renderer draw rect negative coords" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    // Test rectangle with negative coordinates (should be clipped).
    renderer.draw_rect(-10, -20, 100, 50, grain_os.framebuffer_renderer.COLOR_GREEN);
    std.debug.assert(renderer.syscall_fn != null);
}

