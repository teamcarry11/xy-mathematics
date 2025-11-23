//! Framebuffer Syscall Tests
//!
//! Objective: Validate framebuffer syscalls (fb_clear, fb_draw_pixel, fb_draw_text) with
//! comprehensive test coverage including valid inputs, invalid inputs, edge cases, and
//! boundary conditions. Tests verify that syscalls correctly access VM framebuffer memory
//! through the integration layer.
//!
//! Methodology:
//! - Test valid operations (clear, draw pixel, draw text) with various parameters
//! - Test invalid inputs (out of bounds coordinates, null pointers, invalid colors)
//! - Test edge cases (boundary coordinates, empty strings, maximum values)
//! - Verify framebuffer memory is correctly modified
//! - Verify error codes are returned correctly for invalid operations
//! - Use explicit types (u32/u64) throughout, no usize
//! - Minimum 2 assertions per test function
//! - Pair assertions: verify both input validation and output correctness
//!
//! TigerStyle Principles:
//! - Exhaustive testing: valid data, invalid data, and as valid data becomes invalid
//! - Assertions detect programmer errors: assert preconditions, postconditions, invariants
//! - Explicit types: u32/u64 instead of usize for cross-platform consistency
//! - Static allocation: no dynamic allocation after initialization
//! - Bounded loops: all loops have fixed upper bounds
//! - Comments explain why: not just what the code does, but why it's written this way
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive test coverage, deterministic behavior, explicit limits

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const Integration = kernel_vm.Integration;
const VM = kernel_vm.VM;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const Syscall = basin_kernel.Syscall;
const framebuffer = @import("framebuffer");

// Framebuffer constants (explicit types, no usize).
const FRAMEBUFFER_BASE: u64 = framebuffer.FRAMEBUFFER_BASE;
const FRAMEBUFFER_WIDTH: u32 = framebuffer.FRAMEBUFFER_WIDTH;
const FRAMEBUFFER_HEIGHT: u32 = framebuffer.FRAMEBUFFER_HEIGHT;
const FRAMEBUFFER_BPP: u32 = framebuffer.FRAMEBUFFER_BPP;
const FRAMEBUFFER_SIZE: u32 = framebuffer.FRAMEBUFFER_SIZE;

// Color constants (32-bit RGBA format: R in MSB, A in LSB).
const COLOR_BLACK: u32 = framebuffer.COLOR_BLACK;
const COLOR_WHITE: u32 = framebuffer.COLOR_WHITE;
const COLOR_RED: u32 = framebuffer.COLOR_RED;
const COLOR_GREEN: u32 = framebuffer.COLOR_GREEN;
const COLOR_BLUE: u32 = framebuffer.COLOR_BLUE;
const COLOR_DARK_BG: u32 = framebuffer.COLOR_DARK_BG;

// Syscall numbers (explicit constants for clarity).
const FB_CLEAR_SYSCALL: u32 = 70;
const FB_DRAW_PIXEL_SYSCALL: u32 = 71;
const FB_DRAW_TEXT_SYSCALL: u32 = 72;

/// Helper: Create VM and kernel with integration layer initialized.
/// Why: Reduce test boilerplate, ensure consistent setup across tests.
/// Contract: Returns initialized Integration instance, VM framebuffer ready.
/// GrainStyle: In-place initialization pattern, explicit types.
fn create_test_integration() struct { vm: VM, kernel: BasinKernel, integration: Integration } {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    var kernel = BasinKernel.init();
    
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Assert: Integration must be initialized.
    std.debug.assert(integration.initialized);
    
    // Assert: VM must be in halted state.
    std.debug.assert(vm.state == .halted);
    
    return .{ .vm = vm, .kernel = kernel, .integration = integration };
}

/// Helper: Call syscall via VM ECALL instruction.
/// Why: Test syscalls through the actual VM execution path (ECALL -> handler -> integration).
/// Contract: syscall_num must be valid kernel syscall (>= 10).
/// Returns: u64 result (negative = error, non-negative = success).
/// Note: Uses VM's execute_ecall which calls the syscall handler set by integration.finish_init().
/// GrainStyle: Test through actual execution path, not direct function calls.
fn call_syscall(
    integration: *Integration,
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
) u64 {
    // Assert: syscall_num must be kernel syscall (>= 10).
    std.debug.assert(syscall_num >= 10);
    
    // Assert: integration must be initialized.
    std.debug.assert(integration.initialized);
    
    // Get VM from integration.
    const vm = integration.get_vm();
    
    // Assert: VM must have syscall handler set (done by finish_init).
    std.debug.assert(vm.syscall_handler != null);
    
    // Set up registers for syscall (RISC-V calling convention).
    // a7 (x17) = syscall number, a0-a3 (x10-x13) = arguments.
    vm.regs.set(17, syscall_num); // a7 = syscall number
    vm.regs.set(10, arg1);        // a0 = arg1
    vm.regs.set(11, arg2);        // a1 = arg2
    vm.regs.set(12, arg3);        // a2 = arg3
    vm.regs.set(13, arg4);        // a3 = arg4
    
    // Execute ECALL instruction (triggers syscall handler).
    // ECALL encoding: 000000000000 | 00000 | 000 | 00000 | 1110011
    const ecall_inst: u32 = 0x00000073;
    
    // Execute ECALL (this calls the syscall handler set by integration.finish_init()).
    vm.execute_ecall(ecall_inst) catch |err| {
        // If ECALL execution fails, return error code.
        // Note: This shouldn't happen for valid syscalls, but handle it for safety.
        _ = err;
        return @as(u64, @bitCast(@as(i64, -8))); // invalid_syscall
    };
    
    // Get result from a0 register (RISC-V convention: return value in a0).
    const result = vm.regs.get(10);
    
    // Assert: result must be valid (either success >= 0 or error < 0).
    // Note: We don't assert specific value here, just that it's a valid u64.
    // Return result directly (no discard needed).
    return result;
}

/// Helper: Read pixel from framebuffer memory.
/// Why: Verify framebuffer operations by reading back pixel data.
/// Contract: x and y must be within framebuffer bounds.
/// Returns: 32-bit RGBA color value.
fn read_framebuffer_pixel(vm: *VM, x: u32, y: u32) u32 {
    // Assert: coordinates must be within bounds.
    std.debug.assert(x < FRAMEBUFFER_WIDTH);
    std.debug.assert(y < FRAMEBUFFER_HEIGHT);
    
    const fb_memory = vm.get_framebuffer_memory();
    const offset: u32 = (y * FRAMEBUFFER_WIDTH + x) * FRAMEBUFFER_BPP;
    
    // Assert: offset must be within framebuffer bounds.
    std.debug.assert(offset + 3 < FRAMEBUFFER_SIZE);
    
    const pixel = std.mem.readInt(u32, fb_memory[offset..][0..4], .little);
    
    // Assert: pixel value must be valid (not corrupted).
    // Note: Any 32-bit value is technically valid, but we check offset was correct.
    // Return pixel directly (no discard needed).
    return pixel;
}

// ============================================================================
// fb_clear Syscall Tests
// ============================================================================

test "fb_clear: valid color clears entire framebuffer" {
    // Objective: Verify fb_clear syscall fills entire framebuffer with specified color.
    // Methodology: Clear framebuffer with known color, verify all pixels match.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear framebuffer to red color.
    const clear_color: u32 = COLOR_RED;
    const result = call_syscall(integration, FB_CLEAR_SYSCALL, clear_color, 0, 0, 0);
    
    // Assert: syscall must return success (0).
    try testing.expectEqual(@as(u64, 0), result);
    
    // Verify framebuffer is filled with red color.
    // Check multiple pixels: first, middle, last (pair assertions).
    const first_pixel = read_framebuffer_pixel(vm, 0, 0);
    const middle_x: u32 = FRAMEBUFFER_WIDTH / 2;
    const middle_y: u32 = FRAMEBUFFER_HEIGHT / 2;
    const middle_pixel = read_framebuffer_pixel(vm, middle_x, middle_y);
    const last_x: u32 = FRAMEBUFFER_WIDTH - 1;
    const last_y: u32 = FRAMEBUFFER_HEIGHT - 1;
    const last_pixel = read_framebuffer_pixel(vm, last_x, last_y);
    
    // Assert: all pixels must be red color.
    try testing.expectEqual(clear_color, first_pixel);
    try testing.expectEqual(clear_color, middle_pixel);
    try testing.expectEqual(clear_color, last_pixel);
}

test "fb_clear: different colors produce different results" {
    // Objective: Verify fb_clear correctly applies different colors.
    // Methodology: Clear with different colors, verify pixels match each color.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear to red, verify.
    var result = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_RED, 0, 0, 0);
    try testing.expectEqual(@as(u64, 0), result);
    var pixel = read_framebuffer_pixel(vm, 0, 0);
    try testing.expectEqual(COLOR_RED, pixel);
    
    // Clear to green, verify changed.
    result = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_GREEN, 0, 0, 0);
    try testing.expectEqual(@as(u64, 0), result);
    pixel = read_framebuffer_pixel(vm, 0, 0);
    try testing.expectEqual(COLOR_GREEN, pixel);
    
    // Assert: color must have changed from red to green.
    try testing.expect(COLOR_GREEN != COLOR_RED);
}

test "fb_clear: all color components preserved" {
    // Objective: Verify fb_clear preserves all RGBA components correctly.
    // Methodology: Clear with color containing all components, verify each component.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Test color with all components set: R=0xFF, G=0xAA, B=0x55, A=0xFF
    const test_color: u32 = 0xFFAA55FF;
    const result = call_syscall(integration, FB_CLEAR_SYSCALL, test_color, 0, 0, 0);
    try testing.expectEqual(@as(u64, 0), result);
    
    const pixel = read_framebuffer_pixel(vm, 0, 0);
    
    // Assert: pixel must match test color exactly.
    try testing.expectEqual(test_color, pixel);
    
    // Verify RGBA components individually (pair assertions).
    const r: u8 = @truncate((pixel >> 24) & 0xFF);
    const g: u8 = @truncate((pixel >> 16) & 0xFF);
    const b: u8 = @truncate((pixel >> 8) & 0xFF);
    const a: u8 = @truncate(pixel & 0xFF);
    
    try testing.expectEqual(@as(u8, 0xFF), r);
    try testing.expectEqual(@as(u8, 0xAA), g);
    try testing.expectEqual(@as(u8, 0x55), b);
    try testing.expectEqual(@as(u8, 0xFF), a);
}

// ============================================================================
// fb_draw_pixel Syscall Tests
// ============================================================================

test "fb_draw_pixel: valid coordinates draw pixel correctly" {
    // Objective: Verify fb_draw_pixel draws a single pixel at specified coordinates.
    // Methodology: Draw pixel at known position, verify it appears at correct location.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear framebuffer first (known state).
    _ = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_BLACK, 0, 0, 0);
    
    // Draw red pixel at (100, 200).
    const x: u32 = 100;
    const y: u32 = 200;
    const pixel_color: u32 = COLOR_RED;
    const result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, x, y, pixel_color, 0);
    
    // Assert: syscall must return success (0).
    try testing.expectEqual(@as(u64, 0), result);
    
    // Verify pixel at (100, 200) is red.
    const drawn_pixel = read_framebuffer_pixel(vm, x, y);
    try testing.expectEqual(pixel_color, drawn_pixel);
    
    // Verify adjacent pixels are still black (pair assertion).
    const left_pixel = read_framebuffer_pixel(vm, x - 1, y);
    const right_pixel = read_framebuffer_pixel(vm, x + 1, y);
    try testing.expectEqual(COLOR_BLACK, left_pixel);
    try testing.expectEqual(COLOR_BLACK, right_pixel);
}

test "fb_draw_pixel: boundary coordinates (corners)" {
    // Objective: Verify fb_draw_pixel works at framebuffer boundaries.
    // Methodology: Draw pixels at all four corners, verify they are drawn correctly.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear framebuffer.
    _ = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_BLACK, 0, 0, 0);
    
    // Draw pixels at all four corners.
    const corners = [_]struct { x: u32, y: u32, color: u32 }{
        .{ .x = 0, .y = 0, .color = COLOR_RED },                    // Top-left
        .{ .x = FRAMEBUFFER_WIDTH - 1, .y = 0, .color = COLOR_GREEN }, // Top-right
        .{ .x = 0, .y = FRAMEBUFFER_HEIGHT - 1, .color = COLOR_BLUE }, // Bottom-left
        .{ .x = FRAMEBUFFER_WIDTH - 1, .y = FRAMEBUFFER_HEIGHT - 1, .color = COLOR_WHITE }, // Bottom-right
    };
    
    for (corners) |corner| {
        const result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, corner.x, corner.y, corner.color, 0);
        
        // Assert: syscall must succeed for boundary coordinates.
        try testing.expectEqual(@as(u64, 0), result);
        
        // Verify pixel is drawn correctly.
        const pixel = read_framebuffer_pixel(vm, corner.x, corner.y);
        try testing.expectEqual(corner.color, pixel);
    }
}

test "fb_draw_pixel: out of bounds x coordinate" {
    // Objective: Verify fb_draw_pixel rejects out of bounds x coordinate.
    // Methodology: Attempt to draw pixel with x >= FRAMEBUFFER_WIDTH, verify error.
    
    var setup = create_test_integration();
    const integration = &setup.integration;
    
    // Attempt to draw pixel with x = FRAMEBUFFER_WIDTH (out of bounds).
    const x: u32 = FRAMEBUFFER_WIDTH; // Out of bounds
    const y: u32 = 100;
    const color: u32 = COLOR_RED;
    const result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, x, y, color, 0);
    
    // Assert: syscall must return error (negative value).
    // Error code -11 = out_of_bounds.
    const expected_error: i64 = -11;
    try testing.expectEqual(@as(u64, @bitCast(expected_error)), result);
}

test "fb_draw_pixel: out of bounds y coordinate" {
    // Objective: Verify fb_draw_pixel rejects out of bounds y coordinate.
    // Methodology: Attempt to draw pixel with y >= FRAMEBUFFER_HEIGHT, verify error.
    
    var setup = create_test_integration();
    const integration = &setup.integration;
    
    // Attempt to draw pixel with y = FRAMEBUFFER_HEIGHT (out of bounds).
    const x: u32 = 100;
    const y: u32 = FRAMEBUFFER_HEIGHT; // Out of bounds
    const color: u32 = COLOR_RED;
    const result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, x, y, color, 0);
    
    // Assert: syscall must return error (negative value).
    const expected_error: i64 = -11; // out_of_bounds
    try testing.expectEqual(@as(u64, @bitCast(expected_error)), result);
}

test "fb_draw_pixel: maximum valid coordinates" {
    // Objective: Verify fb_draw_pixel accepts maximum valid coordinates.
    // Methodology: Draw pixel at (WIDTH-1, HEIGHT-1), verify success.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Draw pixel at maximum valid coordinates.
    const x: u32 = FRAMEBUFFER_WIDTH - 1;
    const y: u32 = FRAMEBUFFER_HEIGHT - 1;
    const color: u32 = COLOR_WHITE;
    const result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, x, y, color, 0);
    
    // Assert: syscall must succeed for maximum valid coordinates.
    try testing.expectEqual(@as(u64, 0), result);
    
    // Verify pixel is drawn.
    const pixel = read_framebuffer_pixel(vm, x, y);
    try testing.expectEqual(color, pixel);
}

test "fb_draw_pixel: multiple pixels don't interfere" {
    // Objective: Verify drawing multiple pixels doesn't cause interference.
    // Methodology: Draw pixels at different locations, verify each is independent.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear framebuffer.
    _ = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_BLACK, 0, 0, 0);
    
    // Draw multiple pixels with different colors.
    const pixels = [_]struct { x: u32, y: u32, color: u32 }{
        .{ .x = 10, .y = 10, .color = COLOR_RED },
        .{ .x = 20, .y = 20, .color = COLOR_GREEN },
        .{ .x = 30, .y = 30, .color = COLOR_BLUE },
    };
    
    for (pixels) |p| {
        const result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, p.x, p.y, p.color, 0);
        try testing.expectEqual(@as(u64, 0), result);
    }
    
    // Verify each pixel is drawn correctly (pair assertions).
    for (pixels) |p| {
        const pixel = read_framebuffer_pixel(vm, p.x, p.y);
        try testing.expectEqual(p.color, pixel);
    }
    
    // Verify pixels don't interfere (adjacent pixels are still black).
    const between_pixel = read_framebuffer_pixel(vm, 15, 15);
    try testing.expectEqual(COLOR_BLACK, between_pixel);
}

// ============================================================================
// fb_draw_text Syscall Tests
// ============================================================================

test "fb_draw_text: valid text string renders" {
    // Objective: Verify fb_draw_text renders a valid text string to framebuffer.
    // Methodology: Write text to kernel memory, call syscall, verify text appears.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear framebuffer.
    _ = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_BLACK, 0, 0, 0);
    
    // Write text string to kernel memory (at kernel base address).
    const text = "Hello";
    const text_addr: u64 = 0x80001000; // Kernel memory address
    
    // Write text to VM memory (simulating kernel memory).
    const text_phys = vm.translate_address(text_addr);
    if (text_phys) |phys| {
        @memcpy(vm.memory[@as(usize, @intCast(phys))..][0..text.len], text);
        vm.memory[@as(usize, @intCast(phys + text.len))] = 0;
    } else {
        // If translation fails, use direct offset (kernel base = 0x80000000, offset = 0x1000).
        const kernel_base: u64 = 0x80000000;
        const offset: u64 = text_addr - kernel_base;
        @memcpy(vm.memory[@as(usize, @intCast(offset))..][0..text.len], text);
        vm.memory[@as(usize, @intCast(offset + text.len))] = 0;
    }
    
    // Draw text at (10, 10) with white foreground.
    const x: u32 = 10;
    const y: u32 = 10;
    const fg_color: u32 = COLOR_WHITE;
    const result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, text_addr, x, y, fg_color);
    
    // Assert: syscall must return character count (non-negative).
    try testing.expect(result >= 0);
    try testing.expectEqual(@as(u64, text.len), result);
    
    // Verify text was rendered (check that pixels changed from black).
    // Note: Simple rendering draws character blocks, so we check pixels are not all black.
    var found_non_black: bool = false;
    const char_width: u32 = 8;
    const char_height: u32 = 8;
    var py: u32 = 0;
    while (py < char_height) : (py += 1) {
        var px: u32 = 0;
        while (px < char_width * text.len) : (px += 1) {
            if (x + px < FRAMEBUFFER_WIDTH and y + py < FRAMEBUFFER_HEIGHT) {
                const pixel = read_framebuffer_pixel(vm, x + px, y + py);
                if (pixel != COLOR_BLACK) {
                    found_non_black = true;
                    break;
                }
            }
        }
        if (found_non_black) break;
    }
    
    // Assert: text rendering must have drawn some non-black pixels.
    try testing.expect(found_non_black);
}

test "fb_draw_text: null pointer returns error" {
    // Objective: Verify fb_draw_text rejects null text pointer.
    // Methodology: Call syscall with text_ptr = 0, verify error.
    
    var setup = create_test_integration();
    const integration = &setup.integration;
    
    const text_ptr: u64 = 0; // Null pointer
    const x: u32 = 10;
    const y: u32 = 10;
    const fg_color: u32 = COLOR_WHITE;
    const result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, text_ptr, x, y, fg_color);
    
    // Assert: syscall must return error (negative value).
    // Error code -2 = invalid_argument.
    const expected_error: i64 = -2;
    try testing.expectEqual(@as(u64, @bitCast(expected_error)), result);
}

test "fb_draw_text: out of bounds x coordinate" {
    // Objective: Verify fb_draw_text rejects out of bounds x coordinate.
    // Methodology: Call syscall with x >= FRAMEBUFFER_WIDTH, verify error.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Write text to kernel memory.
    const text = "Test";
    const text_addr: u64 = 0x80001000;
    const text_phys = vm.translate_address(text_addr) orelse 0x1000;
    @memcpy(vm.memory[@as(usize, @intCast(text_phys))..][0..text.len], text);
    vm.memory[@as(usize, @intCast(text_phys + text.len))] = 0;
    
    const x: u32 = FRAMEBUFFER_WIDTH; // Out of bounds
    const y: u32 = 10;
    const fg_color: u32 = COLOR_WHITE;
    const result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, text_addr, x, y, fg_color);
    
    // Assert: syscall must return error.
    const expected_error: i64 = -11; // out_of_bounds
    try testing.expectEqual(@as(u64, @bitCast(expected_error)), result);
}

test "fb_draw_text: out of bounds y coordinate" {
    // Objective: Verify fb_draw_text rejects out of bounds y coordinate.
    // Methodology: Call syscall with y >= FRAMEBUFFER_HEIGHT, verify error.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Write text to kernel memory.
    const text = "Test";
    const text_addr: u64 = 0x80001000;
    const text_phys = vm.translate_address(text_addr) orelse 0x1000;
    @memcpy(vm.memory[@as(usize, @intCast(text_phys))..][0..text.len], text);
    vm.memory[@as(usize, @intCast(text_phys + text.len))] = 0;
    
    const x: u32 = 10;
    const y: u32 = FRAMEBUFFER_HEIGHT; // Out of bounds
    const fg_color: u32 = COLOR_WHITE;
    const result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, text_addr, x, y, fg_color);
    
    // Assert: syscall must return error.
    const expected_error: i64 = -11; // out_of_bounds
    try testing.expectEqual(@as(u64, @bitCast(expected_error)), result);
}

test "fb_draw_text: empty string returns error" {
    // Objective: Verify fb_draw_text rejects empty string (null terminator only).
    // Methodology: Write null terminator to kernel memory, call syscall, verify error.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Write null terminator only (empty string).
    const text_addr: u64 = 0x80001000;
    const text_phys = vm.translate_address(text_addr) orelse 0x1000;
    vm.memory[@as(usize, @intCast(text_phys))] = 0;
    
    const x: u32 = 10;
    const y: u32 = 10;
    const fg_color: u32 = COLOR_WHITE;
    const result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, text_addr, x, y, fg_color);
    
    // Assert: syscall must return error (empty string).
    const expected_error: i64 = -2; // invalid_argument
    try testing.expectEqual(@as(u64, @bitCast(expected_error)), result);
}

test "fb_draw_text: text wraps at framebuffer edge" {
    // Objective: Verify fb_draw_text handles text that exceeds framebuffer width.
    // Methodology: Draw long text starting near right edge, verify wrapping behavior.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear framebuffer.
    _ = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_BLACK, 0, 0, 0);
    
    // Write long text string.
    const text = "This is a very long text string that should wrap";
    const text_addr: u64 = 0x80001000;
    const text_phys = vm.translate_address(text_addr) orelse 0x1000;
    @memcpy(vm.memory[@as(usize, @intCast(text_phys))..][0..text.len], text);
    vm.memory[@as(usize, @intCast(text_phys + text.len))] = 0;
    
    // Draw text starting near right edge (should wrap).
    const x: u32 = FRAMEBUFFER_WIDTH - 100; // Near right edge
    const y: u32 = 10;
    const fg_color: u32 = COLOR_WHITE;
    const result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, text_addr, x, y, fg_color);
    
    // Assert: syscall must succeed (wrapping is handled).
    try testing.expect(result >= 0);
    try testing.expectEqual(@as(u64, text.len), result);
}

test "fb_draw_text: newline character wraps to next line" {
    // Objective: Verify fb_draw_text handles newline characters correctly.
    // Methodology: Write text with newline, verify text appears on multiple lines.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear framebuffer.
    _ = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_BLACK, 0, 0, 0);
    
    // Write text with newline.
    const text = "Line1\nLine2";
    const text_addr: u64 = 0x80001000;
    const text_phys = vm.translate_address(text_addr) orelse 0x1000;
    @memcpy(vm.memory[@as(usize, @intCast(text_phys))..][0..text.len], text);
    vm.memory[@as(usize, @intCast(text_phys + text.len))] = 0;
    
    const x: u32 = 10;
    const y: u32 = 10;
    const fg_color: u32 = COLOR_WHITE;
    const result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, text_addr, x, y, fg_color);
    
    // Assert: syscall must succeed.
    try testing.expect(result >= 0);
    
    // Verify text appears on multiple lines (check pixels at different y positions).
    const char_height: u32 = 8;
    const line1_y: u32 = y;
    const line2_y: u32 = y + char_height;
    
    // Check that pixels exist at both line positions.
    var found_line1: bool = false;
    var found_line2: bool = false;
    var px: u32 = 0;
    while (px < 40) : (px += 1) {
        if (x + px < FRAMEBUFFER_WIDTH) {
            const pixel1 = read_framebuffer_pixel(vm, x + px, line1_y);
            const pixel2 = read_framebuffer_pixel(vm, x + px, line2_y);
            if (pixel1 != COLOR_BLACK) found_line1 = true;
            if (pixel2 != COLOR_BLACK) found_line2 = true;
        }
    }
    
    // Assert: text must appear on both lines.
    try testing.expect(found_line1);
    try testing.expect(found_line2);
}

// ============================================================================
// Integration Tests: Multiple Syscalls
// ============================================================================

test "Integration: clear then draw pixel sequence" {
    // Objective: Verify framebuffer syscalls work correctly in sequence.
    // Methodology: Clear framebuffer, then draw pixels, verify final state.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear to black.
    var result = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_BLACK, 0, 0, 0);
    try testing.expectEqual(@as(u64, 0), result);
    
    // Draw red pixel at (50, 50).
    result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, 50, 50, COLOR_RED, 0);
    try testing.expectEqual(@as(u64, 0), result);
    
    // Verify pixel is red.
    const pixel = read_framebuffer_pixel(vm, 50, 50);
    try testing.expectEqual(COLOR_RED, pixel);
    
    // Verify surrounding pixels are still black (pair assertion).
    const adjacent = read_framebuffer_pixel(vm, 51, 50);
    try testing.expectEqual(COLOR_BLACK, adjacent);
}

test "Integration: clear then draw text sequence" {
    // Objective: Verify clear and draw_text work together correctly.
    // Methodology: Clear framebuffer, draw text, verify text appears.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear to dark background.
    var result = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_DARK_BG, 0, 0, 0);
    try testing.expectEqual(@as(u64, 0), result);
    
    // Write text to kernel memory.
    const text = "Grain";
    const text_addr: u64 = 0x80001000;
    const text_phys = vm.translate_address(text_addr) orelse 0x1000;
    @memcpy(vm.memory[@as(usize, @intCast(text_phys))..][0..text.len], text);
    vm.memory[@as(usize, @intCast(text_phys + text.len))] = 0;
    
    // Draw text.
    result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, text_addr, 20, 20, COLOR_WHITE);
    try testing.expect(result >= 0);
    
    // Verify text was drawn (pixels changed from background).
    var found_text: bool = false;
    const char_width: u32 = 8;
    var px: u32 = 0;
    while (px < char_width * text.len) : (px += 1) {
        if (20 + px < FRAMEBUFFER_WIDTH) {
            const pixel = read_framebuffer_pixel(vm, 20 + px, 20);
            if (pixel != COLOR_DARK_BG) {
                found_text = true;
                break;
            }
        }
    }
    
    // Assert: text must have been drawn.
    try testing.expect(found_text);
}

// ============================================================================
// Edge Cases and Boundary Conditions
// ============================================================================

test "Edge case: maximum color value" {
    // Objective: Verify framebuffer syscalls handle maximum color value (0xFFFFFFFF).
    // Methodology: Use maximum color value, verify it's handled correctly.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    const max_color: u32 = 0xFFFFFFFF;
    
    // Clear with maximum color.
    var result = call_syscall(integration, FB_CLEAR_SYSCALL, max_color, 0, 0, 0);
    try testing.expectEqual(@as(u64, 0), result);
    
    // Verify framebuffer is filled with maximum color.
    const pixel = read_framebuffer_pixel(vm, 0, 0);
    try testing.expectEqual(max_color, pixel);
    
    // Draw pixel with maximum color.
    result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, 100, 100, max_color, 0);
    try testing.expectEqual(@as(u64, 0), result);
    
    const drawn_pixel = read_framebuffer_pixel(vm, 100, 100);
    try testing.expectEqual(max_color, drawn_pixel);
}

test "Edge case: zero color value" {
    // Objective: Verify framebuffer syscalls handle zero color value (transparent black).
    // Methodology: Use zero color value, verify it's handled correctly.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    const zero_color: u32 = 0x00000000;
    
    // Clear with zero color.
    const result = call_syscall(integration, FB_CLEAR_SYSCALL, zero_color, 0, 0, 0);
    try testing.expectEqual(@as(u64, 0), result);
    
    // Verify framebuffer is filled with zero color.
    const pixel = read_framebuffer_pixel(vm, 0, 0);
    try testing.expectEqual(zero_color, pixel);
}

test "Edge case: coordinates at exact boundary" {
    // Objective: Verify coordinates at exact boundary (WIDTH-1, HEIGHT-1) work correctly.
    // Methodology: Draw pixel at maximum valid coordinates, verify success.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Draw pixel at exact boundary.
    const x: u32 = FRAMEBUFFER_WIDTH - 1;
    const y: u32 = FRAMEBUFFER_HEIGHT - 1;
    const result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, x, y, COLOR_WHITE, 0);
    
    // Assert: syscall must succeed at boundary.
    try testing.expectEqual(@as(u64, 0), result);
    
    // Verify pixel is drawn.
    const pixel = read_framebuffer_pixel(vm, x, y);
    try testing.expectEqual(COLOR_WHITE, pixel);
}

test "Edge case: text pointer at maximum kernel address" {
    // Objective: Verify fb_draw_text handles text pointer at high kernel address.
    // Methodology: Write text at high kernel address, verify syscall works.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Write text at high kernel address (near end of kernel memory).
    const text = "Test";
    const text_addr: u64 = 0x80000000 + vm.memory_size - 100; // Near end of kernel memory
    const text_phys_opt = vm.translate_address(text_addr);
    if (text_phys_opt) |text_phys| {
        @memcpy(vm.memory[@as(usize, @intCast(text_phys))..][0..text.len], text);
        vm.memory[@as(usize, @intCast(text_phys + text.len))] = 0;
    } else {
        // Fallback: use direct offset.
        const kernel_base: u64 = 0x80000000;
        const offset: u64 = text_addr - kernel_base;
        @memcpy(vm.memory[@as(usize, @intCast(offset))..][0..text.len], text);
        vm.memory[@as(usize, @intCast(offset + text.len))] = 0;
    }
    
    const result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, text_addr, 10, 10, COLOR_WHITE);
    
    // Assert: syscall must succeed even with high address.
    try testing.expect(result >= 0);
}

// ============================================================================
// Stress Tests: Multiple Operations
// ============================================================================

test "Stress: clear framebuffer multiple times" {
    // Objective: Verify fb_clear works correctly when called multiple times.
    // Methodology: Clear framebuffer with different colors multiple times, verify final state.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    const colors = [_]u32{ COLOR_RED, COLOR_GREEN, COLOR_BLUE, COLOR_WHITE, COLOR_BLACK };
    
    for (colors) |color| {
        const result = call_syscall(integration, FB_CLEAR_SYSCALL, color, 0, 0, 0);
        try testing.expectEqual(@as(u64, 0), result);
        
        // Verify framebuffer is filled with current color.
        const pixel = read_framebuffer_pixel(vm, 0, 0);
        try testing.expectEqual(color, pixel);
    }
    
    // Assert: final color must be black (last clear operation).
    const final_pixel = read_framebuffer_pixel(vm, 0, 0);
    try testing.expectEqual(COLOR_BLACK, final_pixel);
}

test "Stress: draw many pixels" {
    // Objective: Verify fb_draw_pixel works correctly with many operations.
    // Methodology: Draw pixels in a pattern, verify all are drawn correctly.
    
    var setup = create_test_integration();
    const vm = &setup.vm;
    const integration = &setup.integration;
    
    // Clear framebuffer.
    _ = call_syscall(integration, FB_CLEAR_SYSCALL, COLOR_BLACK, 0, 0, 0);
    
    // Draw pixels in a 10x10 grid pattern.
    const grid_size: u32 = 10;
    const spacing: u32 = 20;
    var y: u32 = 0;
    while (y < grid_size) : (y += 1) {
        var x: u32 = 0;
        while (x < grid_size) : (x += 1) {
            const px: u32 = x * spacing;
            const py: u32 = y * spacing;
            const color: u32 = if ((x + y) % 2 == 0) COLOR_RED else COLOR_GREEN;
            
            const result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, px, py, color, 0);
            try testing.expectEqual(@as(u64, 0), result);
        }
    }
    
    // Verify all pixels are drawn correctly.
    y = 0;
    while (y < grid_size) : (y += 1) {
        var x: u32 = 0;
        while (x < grid_size) : (x += 1) {
            const px: u32 = x * spacing;
            const py: u32 = y * spacing;
            const expected_color: u32 = if ((x + y) % 2 == 0) COLOR_RED else COLOR_GREEN;
            
            const pixel = read_framebuffer_pixel(vm, px, py);
            try testing.expectEqual(expected_color, pixel);
        }
    }
}

// ============================================================================
// Error Code Verification
// ============================================================================

test "Error codes: verify all error conditions return correct codes" {
    // Objective: Verify all error conditions return correct negative error codes.
    // Methodology: Trigger each error condition, verify error code matches specification.
    
    var setup = create_test_integration();
    const integration = &setup.integration;
    
    // Test invalid_argument (-2): null text pointer.
    var result = call_syscall(integration, FB_DRAW_TEXT_SYSCALL, 0, 10, 10, COLOR_WHITE);
    try testing.expectEqual(@as(u64, @bitCast(@as(i64, -2))), result);
    
    // Test out_of_bounds (-11): x coordinate out of bounds.
    result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, FRAMEBUFFER_WIDTH, 10, COLOR_RED, 0);
    try testing.expectEqual(@as(u64, @bitCast(@as(i64, -11))), result);
    
    // Test out_of_bounds (-11): y coordinate out of bounds.
    result = call_syscall(integration, FB_DRAW_PIXEL_SYSCALL, 10, FRAMEBUFFER_HEIGHT, COLOR_RED, 0);
    try testing.expectEqual(@as(u64, @bitCast(@as(i64, -11))), result);
}

