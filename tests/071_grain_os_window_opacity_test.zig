//! Tests for Grain OS window opacity/transparency.
//!
//! Why: Verify window opacity management and alpha blending.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const window_opacity = grain_os.window_opacity;

test "opacity constants" {
    std.debug.assert(window_opacity.OPACITY_MIN == 0);
    std.debug.assert(window_opacity.OPACITY_MAX == 255);
    std.debug.assert(window_opacity.OPACITY_DEFAULT == 255);
}

test "apply opacity to color" {
    const color: u32 = 0x0000FFFF; // Blue.
    const opacity: u8 = 128; // 50% opacity.
    const result = window_opacity.apply_opacity_to_color(color, opacity);
    std.debug.assert((result >> 24) == opacity);
    std.debug.assert((result & 0x00FFFFFF) == (color & 0x00FFFFFF));
}

test "clamp opacity" {
    std.debug.assert(window_opacity.clamp_opacity(0) == 0);
    std.debug.assert(window_opacity.clamp_opacity(255) == 255);
    std.debug.assert(window_opacity.clamp_opacity(300) == 255);
}

test "is fully opaque" {
    std.debug.assert(window_opacity.is_fully_opaque(255) == true);
    std.debug.assert(window_opacity.is_fully_opaque(254) == false);
    std.debug.assert(window_opacity.is_fully_opaque(0) == false);
}

test "is fully transparent" {
    std.debug.assert(window_opacity.is_fully_transparent(0) == true);
    std.debug.assert(window_opacity.is_fully_transparent(1) == false);
    std.debug.assert(window_opacity.is_fully_transparent(255) == false);
}

test "compositor set window opacity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    const result = comp.set_window_opacity(window_id, 128);
    std.debug.assert(result);
    const opacity = comp.get_window_opacity(window_id);
    std.debug.assert(opacity != null);
    if (opacity) |op| {
        std.debug.assert(op == 128);
    }
}

test "compositor get window opacity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    const opacity = comp.get_window_opacity(window_id);
    std.debug.assert(opacity != null);
    if (opacity) |op| {
        std.debug.assert(op == window_opacity.OPACITY_DEFAULT);
    }
}

test "compositor window default opacity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    if (comp.get_window(window_id)) |win| {
        std.debug.assert(win.opacity == window_opacity.OPACITY_DEFAULT);
    }
}

test "compositor opacity clamping" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    _ = comp.set_window_opacity(window_id, @as(u8, @intCast(300)));
    const opacity = comp.get_window_opacity(window_id);
    std.debug.assert(opacity != null);
    if (opacity) |op| {
        std.debug.assert(op == window_opacity.OPACITY_MAX);
    }
}

test "compositor render with opacity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    _ = comp.set_window_opacity(window_id, 128);
    // Render should not crash (opacity applied).
    comp.render_to_framebuffer();
}

