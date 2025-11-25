//! Tests for Grain OS window snapping.
//!
//! Why: Verify window snapping to edges and corners works correctly.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const window_snapping = grain_os.window_snapping;

test "detect snap zone left" {
    const zone = window_snapping.detect_snap_zone(
        10, // win_x (within threshold)
        50, // win_y
        400, // win_width
        300, // win_height
        1024, // screen_width
        768, // screen_height
        20, // threshold
    );
    std.debug.assert(zone == window_snapping.SnapZone.left);
}

test "detect snap zone right" {
    const zone = window_snapping.detect_snap_zone(
        1014, // win_x (near right edge)
        50, // win_y
        400, // win_width
        300, // win_height
        1024, // screen_width
        768, // screen_height
        20, // threshold
    );
    std.debug.assert(zone == window_snapping.SnapZone.right);
}

test "detect snap zone top left" {
    const zone = window_snapping.detect_snap_zone(
        10, // win_x (within threshold)
        30, // win_y (near top)
        400, // win_width
        300, // win_height
        1024, // screen_width
        768, // screen_height
        20, // threshold
    );
    std.debug.assert(zone == window_snapping.SnapZone.top_left);
}

test "detect snap zone none" {
    const zone = window_snapping.detect_snap_zone(
        200, // win_x (not near edge)
        200, // win_y (not near edge)
        400, // win_width
        300, // win_height
        1024, // screen_width
        768, // screen_height
        20, // threshold
    );
    std.debug.assert(zone == window_snapping.SnapZone.none);
}

test "calculate snap position left" {
    const snapped = window_snapping.calculate_snap_position(
        window_snapping.SnapZone.left,
        400, // win_width
        300, // win_height
        1024, // screen_width
        768, // screen_height
    );
    std.debug.assert(snapped.x == @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH)));
    std.debug.assert(snapped.width == 512); // screen_width / 2
}

test "calculate snap position top left" {
    const snapped = window_snapping.calculate_snap_position(
        window_snapping.SnapZone.top_left,
        400, // win_width
        300, // win_height
        1024, // screen_width
        768, // screen_height
    );
    std.debug.assert(snapped.x == @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH)));
    std.debug.assert(snapped.width == 512); // screen_width / 2
    std.debug.assert(snapped.height == 360); // content_height / 2
}

test "apply snap left" {
    var win_x: i32 = 10;
    var win_y: i32 = 50;
    var win_width: u32 = 400;
    var win_height: u32 = 300;
    const snap_state = window_snapping.apply_snap(
        &win_x,
        &win_y,
        &win_width,
        &win_height,
        1024, // screen_width
        768, // screen_height
        20, // threshold
    );
    std.debug.assert(snap_state.snapped);
    std.debug.assert(snap_state.zone == window_snapping.SnapZone.left);
    std.debug.assert(win_x == @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH)));
    std.debug.assert(win_width == 512); // screen_width / 2
}

test "apply snap none" {
    var win_x: i32 = 200;
    var win_y: i32 = 200;
    var win_width: u32 = 400;
    var win_height: u32 = 300;
    const snap_state = window_snapping.apply_snap(
        &win_x,
        &win_y,
        &win_width,
        &win_height,
        1024, // screen_width
        768, // screen_height
        20, // threshold
    );
    std.debug.assert(!snap_state.snapped);
    std.debug.assert(snap_state.zone == window_snapping.SnapZone.none);
    // Position should remain unchanged.
    std.debug.assert(win_x == 200);
    std.debug.assert(win_y == 200);
}

test "compositor drag with snapping integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(400, 300);
    std.debug.assert(window_id > 0);

    // Start drag near left edge.
    comp.start_drag(window_id, 10, 50);
    if (comp.get_window(window_id)) |win| {
        std.debug.assert(win.drag_state.active);
        // Manually set position near left edge to trigger snapping.
        win.x = 10;
        win.y = 50;
        // Apply snap.
        const snap_state = window_snapping.apply_snap(
            &win.x,
            &win.y,
            &win.width,
            &win.height,
            comp.output.width,
            comp.output.height,
            window_snapping.SNAP_THRESHOLD,
        );
        // Window should snap to left edge.
        std.debug.assert(snap_state.snapped);
        std.debug.assert(snap_state.zone == window_snapping.SnapZone.left);
        std.debug.assert(win.x == @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH)));
        std.debug.assert(win.width == 512); // screen_width / 2
    }
}

test "compositor drag without snapping integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(400, 300);
    std.debug.assert(window_id > 0);

    // Start drag in center.
    comp.start_drag(window_id, 200, 200);
    if (comp.get_window(window_id)) |win| {
        std.debug.assert(win.drag_state.active);
        // Set position in center (not near edge).
        win.x = 200;
        win.y = 200;
        const original_width = win.width;
        const original_height = win.height;
        // Apply snap (should not snap).
        const snap_state = window_snapping.apply_snap(
            &win.x,
            &win.y,
            &win.width,
            &win.height,
            comp.output.width,
            comp.output.height,
            window_snapping.SNAP_THRESHOLD,
        );
        // Window should not snap.
        std.debug.assert(!snap_state.snapped);
        std.debug.assert(snap_state.zone == window_snapping.SnapZone.none);
        // Dimensions should remain unchanged.
        std.debug.assert(win.width == original_width);
        std.debug.assert(win.height == original_height);
    }
}

