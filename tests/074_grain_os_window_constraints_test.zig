//! Tests for Grain OS window constraints (min/max size, aspect ratio).
//!
//! Why: Verify window constraint functionality and validation.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const WindowConstraints = grain_os.window_constraints.WindowConstraints;

test "constraints initialization" {
    const constraints = WindowConstraints.init();
    std.debug.assert(constraints.min_width == grain_os.window_constraints.DEFAULT_MIN_WIDTH);
    std.debug.assert(constraints.min_height == grain_os.window_constraints.DEFAULT_MIN_HEIGHT);
    std.debug.assert(constraints.max_width == grain_os.window_constraints.DEFAULT_MAX_WIDTH);
    std.debug.assert(constraints.max_height == grain_os.window_constraints.DEFAULT_MAX_HEIGHT);
    std.debug.assert(constraints.aspect_ratio == grain_os.window_constraints.DEFAULT_ASPECT_RATIO);
}

test "apply constraints min size" {
    var constraints = WindowConstraints.init();
    constraints.set_min_size(200, 150);
    const result = constraints.apply_constraints(50, 50);
    std.debug.assert(result.width == 200);
    std.debug.assert(result.height == 150);
}

test "apply constraints max size" {
    var constraints = WindowConstraints.init();
    constraints.set_max_size(800, 600);
    const result = constraints.apply_constraints(1000, 1000);
    std.debug.assert(result.width == 800);
    std.debug.assert(result.height == 600);
}

test "apply constraints aspect ratio" {
    var constraints = WindowConstraints.init();
    constraints.set_aspect_ratio(16.0 / 9.0); // 16:9 aspect ratio.
    const result = constraints.apply_constraints(800, 400);
    const expected_ratio = 16.0 / 9.0;
    const actual_ratio = @as(f32, @floatFromInt(result.width)) /
        @as(f32, @floatFromInt(result.height));
    const diff = if (actual_ratio > expected_ratio)
        actual_ratio - expected_ratio
    else
        expected_ratio - actual_ratio;
    std.debug.assert(diff < 0.1); // Allow small floating point errors.
}

test "is valid size" {
    var constraints = WindowConstraints.init();
    constraints.set_min_size(100, 100);
    constraints.set_max_size(800, 600);
    std.debug.assert(constraints.is_valid_size(400, 300) == true);
    std.debug.assert(constraints.is_valid_size(50, 50) == false); // Too small.
    std.debug.assert(constraints.is_valid_size(1000, 1000) == false); // Too large.
}

test "set min size" {
    var constraints = WindowConstraints.init();
    constraints.set_min_size(200, 150);
    std.debug.assert(constraints.min_width == 200);
    std.debug.assert(constraints.min_height == 150);
}

test "set max size" {
    var constraints = WindowConstraints.init();
    constraints.set_max_size(800, 600);
    std.debug.assert(constraints.max_width == 800);
    std.debug.assert(constraints.max_height == 600);
}

test "set aspect ratio" {
    var constraints = WindowConstraints.init();
    constraints.set_aspect_ratio(4.0 / 3.0);
    std.debug.assert(constraints.aspect_ratio == 4.0 / 3.0);
}

test "compositor set window constraints" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    const result = comp.set_window_constraints(window_id, 200, 150, 1000, 800, 0.0);
    std.debug.assert(result);
    const constraints_opt = comp.get_window_constraints(window_id);
    std.debug.assert(constraints_opt != null);
    if (constraints_opt) |constraints| {
        std.debug.assert(constraints.min_width == 200);
        std.debug.assert(constraints.min_height == 150);
    }
}

test "compositor get window constraints" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    const constraints_opt = comp.get_window_constraints(window_id);
    std.debug.assert(constraints_opt != null);
    if (constraints_opt) |constraints| {
        std.debug.assert(constraints.min_width == grain_os.window_constraints.DEFAULT_MIN_WIDTH);
    }
}

test "compositor constraints applied during resize" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    _ = comp.set_window_constraints(window_id, 200, 150, 0, 0, 0.0);
    if (comp.get_window(window_id)) |win| {
        // Simulate resize to very small size.
        win.width = 50;
        win.height = 50;
        const constrained = win.constraints.apply_constraints(win.width, win.height);
        std.debug.assert(constrained.width >= 200);
        std.debug.assert(constrained.height >= 150);
    }
}

