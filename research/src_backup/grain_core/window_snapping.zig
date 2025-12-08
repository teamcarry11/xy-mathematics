//! Grain OS Window Snapping: Snap windows to edges and corners.
//!
//! Why: Provide automatic window snapping when dragging near edges.
//! Architecture: Snap detection and position calculation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Snap threshold in pixels.
pub const SNAP_THRESHOLD: u32 = 20;

// Snap zone: which edge/corner to snap to.
pub const SnapZone = enum(u8) {
    none,
    left,
    right,
    top,
    bottom,
    top_left,
    top_right,
    bottom_left,
    bottom_right,
    center,
};

// Window snap state: tracks if window is snapped.
pub const SnapState = struct {
    snapped: bool,
    zone: SnapZone,
};

// Check if window should snap to left edge.
fn should_snap_left(win_x: i32, threshold: u32) bool {
    return win_x >= 0 and win_x <= @as(i32, @intCast(threshold));
}

// Check if window should snap to right edge.
fn should_snap_right(win_x: i32, win_width: u32, screen_width: u32, threshold: u32) bool {
    const right_edge = win_x + @as(i32, @intCast(win_width));
    const screen_right = @as(i32, @intCast(screen_width));
    return right_edge >= screen_right - @as(i32, @intCast(threshold)) and
        right_edge <= screen_right;
}

// Check if window should snap to top edge.
fn should_snap_top(win_y: i32, threshold: u32, title_bar_height: u32) bool {
    const top_y = @as(i32, @intCast(compositor.BORDER_WIDTH + title_bar_height));
    return win_y >= top_y - @as(i32, @intCast(threshold)) and
        win_y <= top_y + @as(i32, @intCast(threshold));
}

// Check if window should snap to bottom edge.
fn should_snap_bottom(win_y: i32, win_height: u32, screen_height: u32, threshold: u32, status_bar_height: u32) bool {
    const bottom_edge = win_y + @as(i32, @intCast(win_height));
    const screen_bottom = @as(i32, @intCast(screen_height - status_bar_height));
    return bottom_edge >= screen_bottom - @as(i32, @intCast(threshold)) and
        bottom_edge <= screen_bottom;
}

// Detect snap zone for window position.
pub fn detect_snap_zone(
    win_x: i32,
    win_y: i32,
    win_width: u32,
    win_height: u32,
    screen_width: u32,
    screen_height: u32,
    threshold: u32,
) SnapZone {
    std.debug.assert(win_width > 0);
    std.debug.assert(win_height > 0);
    std.debug.assert(screen_width > 0);
    std.debug.assert(screen_height > 0);
    const title_bar_height = compositor.TITLE_BAR_HEIGHT;
    const status_bar_height = @as(u32, 24); // Desktop shell status bar height.
    const snap_left = should_snap_left(win_x, threshold);
    const snap_right = should_snap_right(win_x, win_width, screen_width, threshold);
    const snap_top = should_snap_top(win_y, threshold, title_bar_height);
    const snap_bottom = should_snap_bottom(win_y, win_height, screen_height, threshold, status_bar_height);
    // Check corners first.
    if (snap_left and snap_top) {
        return SnapZone.top_left;
    }
    if (snap_right and snap_top) {
        return SnapZone.top_right;
    }
    if (snap_left and snap_bottom) {
        return SnapZone.bottom_left;
    }
    if (snap_right and snap_bottom) {
        return SnapZone.bottom_right;
    }
    // Check edges.
    if (snap_left) {
        return SnapZone.left;
    }
    if (snap_right) {
        return SnapZone.right;
    }
    if (snap_top) {
        return SnapZone.top;
    }
    if (snap_bottom) {
        return SnapZone.bottom;
    }
    return SnapZone.none;
}

// Calculate snapped position for left edge.
fn calc_snap_left(screen_width: u32, content_height: u32) struct { x: i32, y: i32, width: u32, height: u32 } {
    const border_width = compositor.BORDER_WIDTH;
    const title_bar_height = compositor.TITLE_BAR_HEIGHT;
    return .{
        .x = @as(i32, @intCast(border_width)),
        .y = @as(i32, @intCast(border_width + title_bar_height)),
        .width = screen_width / 2,
        .height = content_height,
    };
}

// Calculate snapped position for right edge.
fn calc_snap_right(screen_width: u32, content_height: u32) struct { x: i32, y: i32, width: u32, height: u32 } {
    const border_width = compositor.BORDER_WIDTH;
    const title_bar_height = compositor.TITLE_BAR_HEIGHT;
    return .{
        .x = @as(i32, @intCast(screen_width / 2)),
        .y = @as(i32, @intCast(border_width + title_bar_height)),
        .width = screen_width / 2,
        .height = content_height,
    };
}

// Calculate snapped position for top edge.
fn calc_snap_top(screen_width: u32, content_height: u32) struct { x: i32, y: i32, width: u32, height: u32 } {
    const border_width = compositor.BORDER_WIDTH;
    const title_bar_height = compositor.TITLE_BAR_HEIGHT;
    return .{
        .x = @as(i32, @intCast(border_width)),
        .y = @as(i32, @intCast(border_width + title_bar_height)),
        .width = screen_width - (border_width * 2),
        .height = content_height / 2,
    };
}

// Calculate snapped position for bottom edge.
fn calc_snap_bottom(screen_width: u32, content_height: u32) struct { x: i32, y: i32, width: u32, height: u32 } {
    const border_width = compositor.BORDER_WIDTH;
    const title_bar_height = compositor.TITLE_BAR_HEIGHT;
    return .{
        .x = @as(i32, @intCast(border_width)),
        .y = @as(i32, @intCast(border_width + title_bar_height + content_height / 2)),
        .width = screen_width - (border_width * 2),
        .height = content_height / 2,
    };
}

// Calculate snapped position for corner zones.
fn calc_snap_corner(zone: SnapZone, screen_width: u32, content_height: u32) struct { x: i32, y: i32, width: u32, height: u32 } {
    const border_width = compositor.BORDER_WIDTH;
    const title_bar_height = compositor.TITLE_BAR_HEIGHT;
    const half_width = screen_width / 2;
    const half_height = content_height / 2;
    switch (zone) {
        .top_left => {
            return .{
                .x = @as(i32, @intCast(border_width)),
                .y = @as(i32, @intCast(border_width + title_bar_height)),
                .width = half_width,
                .height = half_height,
            };
        },
        .top_right => {
            return .{
                .x = @as(i32, @intCast(half_width)),
                .y = @as(i32, @intCast(border_width + title_bar_height)),
                .width = half_width,
                .height = half_height,
            };
        },
        .bottom_left => {
            return .{
                .x = @as(i32, @intCast(border_width)),
                .y = @as(i32, @intCast(border_width + title_bar_height + half_height)),
                .width = half_width,
                .height = half_height,
            };
        },
        .bottom_right => {
            return .{
                .x = @as(i32, @intCast(half_width)),
                .y = @as(i32, @intCast(border_width + title_bar_height + half_height)),
                .width = half_width,
                .height = half_height,
            };
        },
        else => unreachable,
    }
}

// Calculate snapped position for window.
pub fn calculate_snap_position(
    zone: SnapZone,
    win_width: u32,
    win_height: u32,
    screen_width: u32,
    screen_height: u32,
) struct { x: i32, y: i32, width: u32, height: u32 } {
    std.debug.assert(win_width > 0);
    std.debug.assert(win_height > 0);
    std.debug.assert(screen_width > 0);
    std.debug.assert(screen_height > 0);
    const border_width = compositor.BORDER_WIDTH;
    const title_bar_height = compositor.TITLE_BAR_HEIGHT;
    const status_bar_height: u32 = 24;
    const content_height = screen_height - (border_width * 2) - title_bar_height - status_bar_height;
    switch (zone) {
        .left => return calc_snap_left(screen_width, content_height),
        .right => return calc_snap_right(screen_width, content_height),
        .top => return calc_snap_top(screen_width, content_height),
        .bottom => return calc_snap_bottom(screen_width, content_height),
        .top_left, .top_right, .bottom_left, .bottom_right => {
            return calc_snap_corner(zone, screen_width, content_height);
        },
        .center, .none => {
            return .{
                .x = 0,
                .y = @as(i32, @intCast(border_width + title_bar_height)),
                .width = win_width,
                .height = win_height,
            };
        },
    }
}

// Apply snap to window position if within threshold.
pub fn apply_snap(
    win_x: *i32,
    win_y: *i32,
    win_width: *u32,
    win_height: *u32,
    screen_width: u32,
    screen_height: u32,
    threshold: u32,
) SnapState {
    std.debug.assert(win_width.* > 0);
    std.debug.assert(win_height.* > 0);
    const zone = detect_snap_zone(win_x.*, win_y.*, win_width.*, win_height.*, screen_width, screen_height, threshold);
    if (zone != .none) {
        const snapped = calculate_snap_position(zone, win_width.*, win_height.*, screen_width, screen_height);
        win_x.* = snapped.x;
        win_y.* = snapped.y;
        win_width.* = snapped.width;
        win_height.* = snapped.height;
        return SnapState{ .snapped = true, .zone = zone };
    }
    return SnapState{ .snapped = false, .zone = .none };
}

