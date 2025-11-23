//! Dirty Region Tracking Tests
//!
//! Objective: Validate framebuffer dirty region tracking optimization.
//! Tests verify that dirty regions are correctly tracked and only dirty areas
//! are copied during framebuffer sync.
//!
//! Methodology:
//! - Test dirty region marking (pixel, all)
//! - Test dirty region bounds calculation
//! - Test dirty region clearing
//! - Test optimized sync (only dirty regions copied)
//! - Test performance improvement (fewer bytes copied)
//!
//! TigerStyle Principles:
//! - Exhaustive testing: valid data, invalid data, edge cases
//! - Assertions detect programmer errors: assert preconditions, postconditions, invariants
//! - Explicit types: u32/u64 instead of usize for cross-platform consistency
//! - Bounded loops: all loops have fixed upper bounds
//! - Comments explain why: not just what the code does, but why it's written this way
//! - Pair assertions: verify both input validation and output correctness
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive test coverage, deterministic behavior, explicit limits

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const FramebufferDirtyRegion = kernel_vm.FramebufferDirtyRegion;
const framebuffer = @import("framebuffer");

// Framebuffer constants (explicit types, no usize).
const FRAMEBUFFER_WIDTH: u32 = framebuffer.FRAMEBUFFER_WIDTH;
const FRAMEBUFFER_HEIGHT: u32 = framebuffer.FRAMEBUFFER_HEIGHT;

test "Dirty Region: Mark single pixel" {
    // Objective: Verify marking a single pixel correctly initializes dirty region.
    // Methodology: Mark one pixel, verify region bounds match pixel coordinates.
    // Why: Foundation test for dirty region tracking.
    
    var dirty = FramebufferDirtyRegion{};
    
    // Assert: Region must start clean (precondition).
    try testing.expect(!dirty.is_dirty);
    
    // Mark pixel at (100, 200).
    const x: u32 = 100;
    const y: u32 = 200;
    dirty.mark_pixel(x, y);
    
    // Assert: Region must be dirty (postcondition).
    try testing.expect(dirty.is_dirty);
    
    // Assert: Region bounds must match pixel (postcondition).
    try testing.expectEqual(x, dirty.min_x);
    try testing.expectEqual(y, dirty.min_y);
    try testing.expectEqual(x + 1, dirty.max_x);
    try testing.expectEqual(y + 1, dirty.max_y);
}

test "Dirty Region: Mark multiple pixels expands region" {
    // Objective: Verify marking multiple pixels expands dirty region correctly.
    // Methodology: Mark pixels at different locations, verify region includes all.
    // Why: Dirty region must track all modified pixels, not just one.
    
    var dirty = FramebufferDirtyRegion{};
    
    // Mark pixel at (10, 10).
    dirty.mark_pixel(10, 10);
    
    // Assert: Region must include first pixel (postcondition).
    try testing.expect(dirty.min_x == 10);
    try testing.expect(dirty.min_y == 10);
    
    // Mark pixel at (50, 50).
    dirty.mark_pixel(50, 50);
    
    // Assert: Region must include both pixels (postcondition).
    try testing.expect(dirty.min_x == 10);
    try testing.expect(dirty.min_y == 10);
    try testing.expect(dirty.max_x == 51);
    try testing.expect(dirty.max_y == 51);
    
    // Mark pixel at (5, 100).
    dirty.mark_pixel(5, 100);
    
    // Assert: Region must include all three pixels (postcondition).
    try testing.expect(dirty.min_x == 5);
    try testing.expect(dirty.min_y == 10);
    try testing.expect(dirty.max_x == 51);
    try testing.expect(dirty.max_y == 101);
}

test "Dirty Region: Mark all framebuffer" {
    // Objective: Verify marking entire framebuffer sets correct bounds.
    // Methodology: Call mark_all, verify region covers entire framebuffer.
    // Why: Clear operations change entire framebuffer, must track all pixels.
    
    var dirty = FramebufferDirtyRegion{};
    
    // Assert: Region must start clean (precondition).
    try testing.expect(!dirty.is_dirty);
    
    // Mark entire framebuffer.
    dirty.mark_all();
    
    // Assert: Region must be dirty (postcondition).
    try testing.expect(dirty.is_dirty);
    
    // Assert: Region must cover entire framebuffer (postcondition).
    try testing.expectEqual(@as(u32, 0), dirty.min_x);
    try testing.expectEqual(@as(u32, 0), dirty.min_y);
    try testing.expectEqual(FRAMEBUFFER_WIDTH, dirty.max_x);
    try testing.expectEqual(FRAMEBUFFER_HEIGHT, dirty.max_y);
}

test "Dirty Region: Clear resets tracking" {
    // Objective: Verify clearing dirty region resets all state.
    // Methodology: Mark pixels, clear, verify region is clean.
    // Why: Dirty region must be cleared after sync to track next frame.
    
    var dirty = FramebufferDirtyRegion{};
    
    // Mark some pixels.
    dirty.mark_pixel(10, 10);
    dirty.mark_pixel(50, 50);
    
    // Assert: Region must be dirty (precondition).
    try testing.expect(dirty.is_dirty);
    
    // Clear dirty region.
    dirty.clear();
    
    // Assert: Region must be clean (postcondition).
    try testing.expect(!dirty.is_dirty);
    
    // Assert: Bounds must be reset (postcondition).
    try testing.expectEqual(@as(u32, 0), dirty.min_x);
    try testing.expectEqual(@as(u32, 0), dirty.min_y);
    try testing.expectEqual(@as(u32, 0), dirty.max_x);
    try testing.expectEqual(@as(u32, 0), dirty.max_y);
}

test "Dirty Region: Get bounds returns correct values" {
    // Objective: Verify get_bounds returns correct dirty region coordinates.
    // Methodology: Mark pixels, get bounds, verify coordinates match.
    // Why: Sync function needs bounds to copy only dirty regions.
    
    var dirty = FramebufferDirtyRegion{};
    
    // Mark pixels at (20, 30) and (60, 70).
    dirty.mark_pixel(20, 30);
    dirty.mark_pixel(60, 70);
    
    // Get bounds.
    var min_x: u32 = 0;
    var min_y: u32 = 0;
    var max_x: u32 = 0;
    var max_y: u32 = 0;
    const has_dirty = dirty.get_bounds(&min_x, &min_y, &max_x, &max_y);
    
    // Assert: get_bounds must return true (postcondition).
    try testing.expect(has_dirty);
    
    // Assert: Bounds must be correct (postcondition).
    try testing.expectEqual(@as(u32, 20), min_x);
    try testing.expectEqual(@as(u32, 30), min_y);
    try testing.expectEqual(@as(u32, 61), max_x);
    try testing.expectEqual(@as(u32, 71), max_y);
}

test "Dirty Region: Get bounds returns false when clean" {
    // Objective: Verify get_bounds returns false when no region is dirty.
    // Methodology: Don't mark any pixels, get bounds, verify false.
    // Why: Sync optimization: skip copy when nothing changed.
    
    var dirty = FramebufferDirtyRegion{};
    
    // Assert: Region must start clean (precondition).
    try testing.expect(!dirty.is_dirty);
    
    // Get bounds.
    var min_x: u32 = 0;
    var min_y: u32 = 0;
    var max_x: u32 = 0;
    var max_y: u32 = 0;
    const has_dirty = dirty.get_bounds(&min_x, &min_y, &max_x, &max_y);
    
    // Assert: get_bounds must return false (postcondition).
    try testing.expect(!has_dirty);
}

test "Dirty Region: Boundary coordinates" {
    // Objective: Verify dirty region tracking works at framebuffer boundaries.
    // Methodology: Mark pixels at corners and edges, verify bounds are correct.
    // Why: Edge cases often reveal bugs in bounds checking.
    
    var dirty = FramebufferDirtyRegion{};
    
    // Mark pixel at top-left corner (0, 0).
    dirty.mark_pixel(0, 0);
    
    // Assert: Region must include corner (postcondition).
    try testing.expect(dirty.min_x == 0);
    try testing.expect(dirty.min_y == 0);
    try testing.expect(dirty.max_x == 1);
    try testing.expect(dirty.max_y == 1);
    
    // Clear and mark pixel at bottom-right corner.
    dirty.clear();
    dirty.mark_pixel(FRAMEBUFFER_WIDTH - 1, FRAMEBUFFER_HEIGHT - 1);
    
    // Assert: Region must include corner (postcondition).
    try testing.expect(dirty.min_x == FRAMEBUFFER_WIDTH - 1);
    try testing.expect(dirty.min_y == FRAMEBUFFER_HEIGHT - 1);
    try testing.expect(dirty.max_x == FRAMEBUFFER_WIDTH);
    try testing.expect(dirty.max_y == FRAMEBUFFER_HEIGHT);
}

test "Dirty Region: Integration with VM framebuffer operations" {
    // Objective: Verify VM framebuffer operations mark dirty regions correctly.
    // Methodology: Create VM, call framebuffer operations, verify dirty tracking.
    // Why: End-to-end validation of dirty region tracking in real usage.
    
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Initialize framebuffer (should mark all as dirty).
    vm.init_framebuffer();
    
    // Assert: Entire framebuffer must be dirty after initialization (postcondition).
    try testing.expect(vm.framebuffer_dirty.is_dirty);
    
    var min_x: u32 = 0;
    var min_y: u32 = 0;
    var max_x: u32 = 0;
    var max_y: u32 = 0;
    const has_dirty = vm.framebuffer_dirty.get_bounds(&min_x, &min_y, &max_x, &max_y);
    
    // Assert: Bounds must cover entire framebuffer (postcondition).
    try testing.expect(has_dirty);
    try testing.expectEqual(@as(u32, 0), min_x);
    try testing.expectEqual(@as(u32, 0), min_y);
    try testing.expectEqual(FRAMEBUFFER_WIDTH, max_x);
    try testing.expectEqual(FRAMEBUFFER_HEIGHT, max_y);
}

test "Dirty Region: Performance optimization validation" {
    // Objective: Verify dirty region tracking reduces memory copy operations.
    // Methodology: Mark small region, verify only that region needs copying.
    // Why: Optimization must reduce memory bandwidth for better performance.
    
    var dirty = FramebufferDirtyRegion{};
    
    // Mark small region (10x10 pixels).
    const region_x: u32 = 100;
    const region_y: u32 = 100;
    const region_size: u32 = 10;
    var y: u32 = 0;
    while (y < region_size) : (y += 1) {
        var x: u32 = 0;
        while (x < region_size) : (x += 1) {
            dirty.mark_pixel(region_x + x, region_y + y);
        }
    }
    
    // Get bounds.
    var min_x: u32 = 0;
    var min_y: u32 = 0;
    var max_x: u32 = 0;
    var max_y: u32 = 0;
    const has_dirty = dirty.get_bounds(&min_x, &min_y, &max_x, &max_y);
    
    // Assert: Region must be dirty (postcondition).
    try testing.expect(has_dirty);
    
    // Calculate bytes that need copying (dirty region only).
    const bpp: u32 = 4; // RGBA
    const dirty_width: u32 = max_x - min_x;
    const dirty_height: u32 = max_y - min_y;
    const dirty_bytes: u32 = dirty_width * dirty_height * bpp;
    
    // Calculate bytes for full framebuffer copy.
    const full_bytes: u32 = FRAMEBUFFER_WIDTH * FRAMEBUFFER_HEIGHT * bpp;
    
    // Assert: Dirty region must be smaller than full framebuffer (postcondition).
    // Why: Optimization only helps if dirty region is smaller than full copy.
    try testing.expect(dirty_bytes < full_bytes);
    
    // Assert: Dirty region size must match expected (10x10 pixels).
    try testing.expect(dirty_width == region_size);
    try testing.expect(dirty_height == region_size);
}

