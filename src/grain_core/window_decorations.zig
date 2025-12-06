//! Grain OS Window Decorations: Title bar buttons and controls.
//!
//! Why: Provide interactive title bar buttons (close, minimize, maximize).
//! Architecture: Button rendering and hit testing for window controls.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Button size.
pub const BUTTON_SIZE: u32 = 20;

// Bounded: Button spacing.
pub const BUTTON_SPACING: u32 = 4;

// Bounded: Button margin from edge.
pub const BUTTON_MARGIN: u32 = 4;

// Button type.
pub const ButtonType = enum(u8) {
    none,
    close,
    minimize,
    maximize,
};

// Button state.
pub const ButtonState = struct {
    hovered: bool,
    pressed: bool,
};

// Get close button bounds.
pub fn get_close_button_bounds(
    win_x: i32,
    win_y: i32,
    win_width: u32,
) struct { x: i32, y: i32, width: u32, height: u32 } {
    const title_bar_x = win_x + @as(i32, @intCast(compositor.BORDER_WIDTH));
    const title_bar_y = win_y + @as(i32, @intCast(compositor.BORDER_WIDTH));
    const button_x = title_bar_x + @as(i32, @intCast(win_width - compositor.BORDER_WIDTH * 2 - BUTTON_MARGIN - BUTTON_SIZE));
    const button_y = title_bar_y;
    return .{
        .x = button_x,
        .y = button_y,
        .width = BUTTON_SIZE,
        .height = compositor.TITLE_BAR_HEIGHT,
    };
}

// Get minimize button bounds.
pub fn get_minimize_button_bounds(
    win_x: i32,
    win_y: i32,
    win_width: u32,
) struct { x: i32, y: i32, width: u32, height: u32 } {
    const close_bounds = get_close_button_bounds(win_x, win_y, win_width);
    const button_x = close_bounds.x - @as(i32, @intCast(BUTTON_SIZE + BUTTON_SPACING));
    const button_y = close_bounds.y;
    return .{
        .x = button_x,
        .y = button_y,
        .width = BUTTON_SIZE,
        .height = compositor.TITLE_BAR_HEIGHT,
    };
}

// Get maximize button bounds.
pub fn get_maximize_button_bounds(
    win_x: i32,
    win_y: i32,
    win_width: u32,
) struct { x: i32, y: i32, width: u32, height: u32 } {
    const minimize_bounds = get_minimize_button_bounds(win_x, win_y, win_width);
    const button_x = minimize_bounds.x - @as(i32, @intCast(BUTTON_SIZE + BUTTON_SPACING));
    const button_y = minimize_bounds.y;
    return .{
        .x = button_x,
        .y = button_y,
        .width = BUTTON_SIZE,
        .height = compositor.TITLE_BAR_HEIGHT,
    };
}

// Check if point is in close button.
pub fn is_in_close_button(
    win_x: i32,
    win_y: i32,
    win_width: u32,
    x: u32,
    y: u32,
) bool {
    const bounds = get_close_button_bounds(win_x, win_y, win_width);
    const x_i32 = @as(i32, @intCast(x));
    const y_i32 = @as(i32, @intCast(y));
    return (x_i32 >= bounds.x and x_i32 < bounds.x + @as(i32, @intCast(bounds.width)) and
        y_i32 >= bounds.y and y_i32 < bounds.y + @as(i32, @intCast(bounds.height)));
}

// Check if point is in minimize button.
pub fn is_in_minimize_button(
    win_x: i32,
    win_y: i32,
    win_width: u32,
    x: u32,
    y: u32,
) bool {
    const bounds = get_minimize_button_bounds(win_x, win_y, win_width);
    const x_i32 = @as(i32, @intCast(x));
    const y_i32 = @as(i32, @intCast(y));
    return (x_i32 >= bounds.x and x_i32 < bounds.x + @as(i32, @intCast(bounds.width)) and
        y_i32 >= bounds.y and y_i32 < bounds.y + @as(i32, @intCast(bounds.height)));
}

// Check if point is in maximize button.
pub fn is_in_maximize_button(
    win_x: i32,
    win_y: i32,
    win_width: u32,
    x: u32,
    y: u32,
) bool {
    const bounds = get_maximize_button_bounds(win_x, win_y, win_width);
    const x_i32 = @as(i32, @intCast(x));
    const y_i32 = @as(i32, @intCast(y));
    return (x_i32 >= bounds.x and x_i32 < bounds.x + @as(i32, @intCast(bounds.width)) and
        y_i32 >= bounds.y and y_i32 < bounds.y + @as(i32, @intCast(bounds.height)));
}

// Get button type at point.
pub fn get_button_at(
    win_x: i32,
    win_y: i32,
    win_width: u32,
    x: u32,
    y: u32,
) ButtonType {
    if (is_in_close_button(win_x, win_y, win_width, x, y)) {
        return ButtonType.close;
    }
    if (is_in_minimize_button(win_x, win_y, win_width, x, y)) {
        return ButtonType.minimize;
    }
    if (is_in_maximize_button(win_x, win_y, win_width, x, y)) {
        return ButtonType.maximize;
    }
    return ButtonType.none;
}

// Get button color for state.
pub fn get_button_color(
    button_type: ButtonType,
    hovered: bool,
    pressed: bool,
    focused: bool,
) u32 {
    _ = focused;
    if (pressed) {
        return 0xFF666666; // Dark gray when pressed.
    }
    if (hovered) {
        if (button_type == ButtonType.close) {
            return 0xFFFF0000; // Red when hovered.
        }
        return 0xFF888888; // Light gray when hovered.
    }
    return 0xFFCCCCCC; // Light gray default.
}

