//! Framebuffer Demo Program
//!
//! Objective: Demonstrate framebuffer syscalls (fb_clear, fb_draw_pixel, fb_draw_text)
//! from userspace. This program runs in Grain Vantage VM and renders to the framebuffer.
//!
//! Methodology:
//! - Clear framebuffer to dark background
//! - Draw colored pixels in a pattern
//! - Draw text messages
//! - Exit cleanly
//!
//! GrainStyle: Explicit types, assertions, bounded execution, static allocation where possible.
//! Why: Test the full stack: VM -> Kernel -> Syscalls -> Framebuffer -> Display

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const Syscall = basin_kernel.Syscall;

// Framebuffer syscall numbers (must match kernel/basin_kernel.zig).
const FB_CLEAR: u32 = 70;
const FB_DRAW_PIXEL: u32 = 71;
const FB_DRAW_TEXT: u32 = 72;

// Color constants (32-bit RGBA format: R in MSB, A in LSB).
const COLOR_DARK_BG: u32 = 0x1E1E2EFF; // Dark background
const COLOR_WHITE: u32 = 0xFFFFFFFF;   // White
const COLOR_RED: u32 = 0xFF0000FF;     // Red
const COLOR_GREEN: u32 = 0x00FF00FF;   // Green
const COLOR_BLUE: u32 = 0x0000FFFF;    // Blue

// Framebuffer dimensions (must match kernel/framebuffer.zig).
const FB_WIDTH: u32 = 1024;
const FB_HEIGHT: u32 = 768;

/// Perform syscall via inline assembly.
/// Why: Direct syscall invocation from userspace program.
/// Contract: syscall_num must be valid kernel syscall.
/// Returns: u64 result (negative = error, non-negative = success).
fn syscall(
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
) u64 {
    // Assert: syscall_num must be valid (>= 1).
    std.debug.assert(syscall_num >= 1);
    
    // RISC-V syscall convention: a7 = syscall number, a0-a3 = arguments, a0 = return value.
    var result: u64 = undefined;
    asm volatile (
        \\ ecall
        : [result] "={x10}" (result)
        : [syscall_num] "{x17}" (syscall_num),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3),
          [arg4] "{x13}" (arg4)
        : "memory"
    );
    
    // Assert: Result must be valid u64 (always true, but documents expectation).
    _ = result;
    
    return result;
}

/// Clear framebuffer to specified color.
/// Why: Test fb_clear syscall.
/// Contract: color must be valid 32-bit RGBA value.
fn fb_clear(color: u32) void {
    const result = syscall(FB_CLEAR, color, 0, 0, 0);
    
    // Assert: Syscall must succeed (result == 0).
    std.debug.assert(result == 0);
}

/// Draw a single pixel at specified coordinates.
/// Why: Test fb_draw_pixel syscall.
/// Contract: x and y must be within framebuffer bounds.
fn fb_draw_pixel(x: u32, y: u32, color: u32) void {
    // Assert: Coordinates must be within bounds.
    std.debug.assert(x < FB_WIDTH);
    std.debug.assert(y < FB_HEIGHT);
    
    const result = syscall(FB_DRAW_PIXEL, x, y, color, 0);
    
    // Assert: Syscall must succeed (result == 0).
    std.debug.assert(result == 0);
}

/// Draw text string at specified coordinates.
/// Why: Test fb_draw_text syscall.
/// Contract: text_ptr must point to null-terminated string in kernel memory, x and y within bounds.
fn fb_draw_text(text_ptr: [*]const u8, x: u32, y: u32, fg_color: u32) void {
    // Assert: Text pointer must be valid (non-null).
    std.debug.assert(@intFromPtr(text_ptr) != 0);
    
    // Assert: Coordinates must be within bounds.
    std.debug.assert(x < FB_WIDTH);
    std.debug.assert(y < FB_HEIGHT);
    
    const result = syscall(FB_DRAW_TEXT, @intFromPtr(text_ptr), x, y, fg_color);
    
    // Assert: Syscall must succeed (result >= 0, character count).
    std.debug.assert(result >= 0);
}

/// Main entry point.
/// Why: Program entry point, orchestrates framebuffer demo.
/// Contract: Program runs in VM, has access to kernel syscalls.
pub fn main() void {
    // Clear framebuffer to dark background.
    fb_clear(COLOR_DARK_BG);
    
    // Draw colored pixels in a pattern (10x10 grid).
    const grid_size: u32 = 10;
    const spacing: u32 = 50;
    var y: u32 = 0;
    while (y < grid_size) : (y += 1) {
        var x: u32 = 0;
        while (x < grid_size) : (x += 1) {
            const px: u32 = 100 + x * spacing;
            const py: u32 = 100 + y * spacing;
            
            // Alternate colors based on position.
            const color: u32 = if ((x + y) % 3 == 0) COLOR_RED else if ((x + y) % 3 == 1) COLOR_GREEN else COLOR_BLUE;
            
            fb_draw_pixel(px, py, color);
        }
    }
    
    // Draw text messages (must be in kernel memory, so we use static strings).
    // Note: In real implementation, text would be copied to kernel memory first.
    // For demo, we assume static strings are accessible.
    const text1 = "Grain OS Framebuffer Demo";
    const text2 = "Userspace Program Running";
    const text3 = "fb_clear, fb_draw_pixel, fb_draw_text";
    
    // Draw text at different y positions.
    // Note: In real implementation, we'd need to copy strings to kernel memory.
    // For now, we'll use the address of static strings (they're in program memory).
    fb_draw_text(text1.ptr, 50, 50, COLOR_WHITE);
    fb_draw_text(text2.ptr, 50, 70, COLOR_WHITE);
    fb_draw_text(text3.ptr, 50, 90, COLOR_WHITE);
    
    // Exit program (syscall exit = 2).
    syscall(@intFromEnum(Syscall.exit), 0, 0, 0, 0);
    
    // Assert: Should never reach here (exit syscall should terminate).
    unreachable;
}

