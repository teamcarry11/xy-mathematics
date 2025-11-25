//! Grain OS Window Actions: Rectangle-inspired window management shortcuts.
//!
//! Why: Provide keyboard shortcuts for window positioning and resizing.
//! Architecture: Window action functions for compositor integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Window action: function that modifies window position/size.
pub const WindowAction = *const fn (*compositor.Compositor, u32) bool;

// Move window to left half of screen.
pub fn action_left_half(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        win.x = @as(i32, @intCast(compositor.BORDER_WIDTH));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = comp.output.width / 2;
        win.height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to right half of screen.
pub fn action_right_half(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        win.x = @as(i32, @intCast(comp.output.width / 2));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = comp.output.width / 2;
        win.height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to top half of screen.
pub fn action_top_half(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        win.x = @as(i32, @intCast(compositor.BORDER_WIDTH));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = comp.output.width - (compositor.BORDER_WIDTH * 2);
        win.height = (comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT) / 2;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to bottom half of screen.
pub fn action_bottom_half(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        const half_height = content_height / 2;
        win.x = @as(i32, @intCast(compositor.BORDER_WIDTH));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT + half_height));
        win.width = comp.output.width - (compositor.BORDER_WIDTH * 2);
        win.height = half_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to top-left quarter.
pub fn action_top_left(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        win.x = @as(i32, @intCast(compositor.BORDER_WIDTH));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = comp.output.width / 2;
        win.height = content_height / 2;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to top-right quarter.
pub fn action_top_right(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        win.x = @as(i32, @intCast(comp.output.width / 2));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = comp.output.width / 2;
        win.height = content_height / 2;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to bottom-left quarter.
pub fn action_bottom_left(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        const half_height = content_height / 2;
        win.x = @as(i32, @intCast(compositor.BORDER_WIDTH));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT + half_height));
        win.width = comp.output.width / 2;
        win.height = half_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to bottom-right quarter.
pub fn action_bottom_right(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        const half_height = content_height / 2;
        win.x = @as(i32, @intCast(comp.output.width / 2));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT + half_height));
        win.width = comp.output.width / 2;
        win.height = half_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to first third (left third).
pub fn action_first_third(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        win.x = @as(i32, @intCast(compositor.BORDER_WIDTH));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = comp.output.width / 3;
        win.height = content_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to center third.
pub fn action_center_third(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        const third_width = comp.output.width / 3;
        win.x = @as(i32, @intCast(third_width));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = third_width;
        win.height = content_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to last third (right third).
pub fn action_last_third(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        const two_thirds = (comp.output.width * 2) / 3;
        win.x = @as(i32, @intCast(two_thirds));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = comp.output.width / 3;
        win.height = content_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to first two thirds (left two thirds).
pub fn action_first_two_thirds(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        win.x = @as(i32, @intCast(compositor.BORDER_WIDTH));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = (comp.output.width * 2) / 3;
        win.height = content_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Move window to last two thirds (right two thirds).
pub fn action_last_two_thirds(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        const third_width = comp.output.width / 3;
        win.x = @as(i32, @intCast(third_width));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.width = (comp.output.width * 2) / 3;
        win.height = content_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Center window on screen.
pub fn action_center(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const content_width = comp.output.width - (compositor.BORDER_WIDTH * 2);
        const content_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        const center_x = (content_width - win.width) / 2;
        const center_y = (content_height - win.height) / 2;
        win.x = @as(i32, @intCast(compositor.BORDER_WIDTH + center_x));
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT + center_y));
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Make window larger (increase size by 10%).
pub fn action_larger(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const new_width = win.width + (win.width / 10);
        const new_height = win.height + (win.height / 10);
        const max_width = comp.output.width - (compositor.BORDER_WIDTH * 2);
        const max_height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        win.width = if (new_width > max_width) max_width else new_width;
        win.height = if (new_height > max_height) max_height else new_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Make window smaller (decrease size by 10%).
pub fn action_smaller(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        const min_size: u32 = 100;
        const new_width = if (win.width > win.width / 10) win.width - (win.width / 10) else min_size;
        const new_height = if (win.height > win.height / 10) win.height - (win.height / 10) else min_size;
        win.width = if (new_width < min_size) min_size else new_width;
        win.height = if (new_height < min_size) min_size else new_height;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

// Maximize height only.
pub fn action_maximize_height(comp: *compositor.Compositor, window_id: u32) bool {
    std.debug.assert(window_id > 0);
    if (comp.get_window(window_id)) |win| {
        win.y = @as(i32, @intCast(compositor.BORDER_WIDTH + compositor.TITLE_BAR_HEIGHT));
        win.height = comp.output.height - (compositor.BORDER_WIDTH * 2) - compositor.TITLE_BAR_HEIGHT;
        comp.recalculate_layout();
        return true;
    }
    return false;
}

