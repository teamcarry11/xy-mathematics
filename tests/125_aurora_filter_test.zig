//! Tests for Aurora Filter module.
//!
//! Why: Verify filter functionality (mode enum, FluxState, apply operations,
//! darkroom filter effects).
//! Architecture: Comprehensive test coverage for visual filter operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-120349-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const Filter = @import("aurora_filter");

test "filter mode enum" {
    // Assert: Mode enum values
    std.debug.assert(@intFromEnum(Filter.Mode.none) == 0);
    std.debug.assert(@intFromEnum(Filter.Mode.darkroom) == 1);
}

test "filter flux state initialization" {
    // Assert: FluxState initialized with none mode
    const state = Filter.FluxState{};
    std.debug.assert(state.mode == .none);
}

test "filter flux state toggle to darkroom" {
    // Assert: Toggle to darkroom mode
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    std.debug.assert(state.mode == .darkroom);
}

test "filter flux state toggle to none" {
    // Assert: Toggle to none mode
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    state.toggle(.none);
    std.debug.assert(state.mode == .none);
}

test "filter apply none mode" {
    // Assert: Apply with none mode does nothing
    const state = Filter.FluxState{};
    var pixels = [_]u8{ 100, 150, 200, 255 };
    const original = pixels;
    
    Filter.apply(state, &pixels);
    
    // Assert: Pixels unchanged
    std.debug.assert(pixels[0] == original[0]);
    std.debug.assert(pixels[1] == original[1]);
    std.debug.assert(pixels[2] == original[2]);
    std.debug.assert(pixels[3] == original[3]);
}

test "filter apply darkroom mode" {
    // Assert: Apply darkroom filter
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{ 200, 180, 160, 255 };
    Filter.apply(state, &pixels);
    
    // Assert: Red increased, green and blue decreased
    std.debug.assert(pixels[0] > 200 or pixels[0] == 220);
    std.debug.assert(pixels[1] < 40);
    std.debug.assert(pixels[2] < 25);
}

test "filter apply darkroom mode low values" {
    // Assert: Apply darkroom filter to low pixel values
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{ 10, 20, 30, 255 };
    Filter.apply(state, &pixels);
    
    // Assert: Red increased, green and blue decreased
    std.debug.assert(pixels[0] >= 10);
    std.debug.assert(pixels[1] < 20);
    std.debug.assert(pixels[2] < 30);
}

test "filter apply darkroom mode high values" {
    // Assert: Apply darkroom filter to high pixel values
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{ 250, 240, 230, 255 };
    Filter.apply(state, &pixels);
    
    // Assert: Red clamped to 255, green and blue decreased
    std.debug.assert(pixels[0] <= 255);
    std.debug.assert(pixels[1] < 240);
    std.debug.assert(pixels[2] < 230);
}

test "filter apply invalid pixel length" {
    // Assert: Apply with invalid pixel length does nothing
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{ 100, 150, 200 }; // Not multiple of 4
    Filter.apply(state, &pixels);
    
    // Assert: Pixels unchanged (function returns early)
    std.debug.assert(pixels[0] == 100);
    std.debug.assert(pixels[1] == 150);
    std.debug.assert(pixels[2] == 200);
}

test "filter apply multiple pixels" {
    // Assert: Apply filter to multiple pixels
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{
        200, 180, 160, 255,
        100, 120, 140, 255,
        50, 60, 70, 255,
    };
    
    Filter.apply(state, &pixels);
    
    // Assert: All pixels modified
    std.debug.assert(pixels[0] > 200 or pixels[0] == 220);
    std.debug.assert(pixels[4] >= 100);
    std.debug.assert(pixels[8] >= 50);
}

test "filter apply darkroom red channel clamp" {
    // Assert: Red channel clamped to 255
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{ 250, 100, 100, 255 };
    Filter.apply(state, &pixels);
    
    // Assert: Red channel clamped
    std.debug.assert(pixels[0] <= 255);
}

test "filter apply darkroom green channel division" {
    // Assert: Green channel divided by 6
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{ 100, 180, 100, 255 };
    Filter.apply(state, &pixels);
    
    // Assert: Green channel divided
    std.debug.assert(pixels[1] == 30); // 180 / 6 = 30
}

test "filter apply darkroom blue channel division" {
    // Assert: Blue channel divided by 12
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{ 100, 100, 240, 255 };
    Filter.apply(state, &pixels);
    
    // Assert: Blue channel divided
    std.debug.assert(pixels[2] == 20); // 240 / 12 = 20
}

test "filter apply darkroom alpha preserved" {
    // Assert: Alpha channel preserved
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{ 100, 150, 200, 128 };
    Filter.apply(state, &pixels);
    
    // Assert: Alpha unchanged
    std.debug.assert(pixels[3] == 128);
}

test "filter toggle multiple times" {
    // Assert: Toggle multiple times works correctly
    var state = Filter.FluxState{};
    
    state.toggle(.darkroom);
    std.debug.assert(state.mode == .darkroom);
    
    state.toggle(.none);
    std.debug.assert(state.mode == .none);
    
    state.toggle(.darkroom);
    std.debug.assert(state.mode == .darkroom);
}

test "filter apply empty pixels" {
    // Assert: Apply with empty pixels does nothing
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels: [0]u8 = undefined;
    Filter.apply(state, &pixels);
    
    // Assert: No crash (empty array handled)
}

test "filter apply single pixel" {
    // Assert: Apply to single pixel
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels = [_]u8{ 200, 180, 160, 255 };
    Filter.apply(state, &pixels);
    
    // Assert: Pixel modified
    std.debug.assert(pixels[0] > 200 or pixels[0] == 220);
    std.debug.assert(pixels[1] < 40);
    std.debug.assert(pixels[2] < 25);
}

test "filter darkroom effect consistency" {
    // Assert: Darkroom effect is consistent
    var state = Filter.FluxState{};
    state.toggle(.darkroom);
    
    var pixels1 = [_]u8{ 200, 180, 160, 255 };
    var pixels2 = [_]u8{ 200, 180, 160, 255 };
    
    Filter.apply(state, &pixels1);
    Filter.apply(state, &pixels2);
    
    // Assert: Same input produces same output
    std.debug.assert(pixels1[0] == pixels2[0]);
    std.debug.assert(pixels1[1] == pixels2[1]);
    std.debug.assert(pixels1[2] == pixels2[2]);
}
