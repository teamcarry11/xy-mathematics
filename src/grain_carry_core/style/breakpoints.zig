// Responsive breakpoints for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Defines breakpoints for responsive design
// Based on screen width in dp (Android) / points (iOS)

const std = @import("std");

pub const Breakpoint = enum(u8) {
    phone_small,   // < 360dp/375pt
    phone_medium,  // 360-414dp/375-414pt
    phone_large,   // 414-480dp/414-480pt
    tablet_small,  // 480-600dp/480-600pt
    tablet_large,  // 600-840dp/600-840pt
    desktop,       // > 840dp/840pt
};

pub const BREAKPOINT_PHONE_SMALL_MAX: u32 = 359;
pub const BREAKPOINT_PHONE_MEDIUM_MIN: u32 = 360;
pub const BREAKPOINT_PHONE_MEDIUM_MAX: u32 = 413;
pub const BREAKPOINT_PHONE_LARGE_MIN: u32 = 414;
pub const BREAKPOINT_PHONE_LARGE_MAX: u32 = 479;
pub const BREAKPOINT_TABLET_SMALL_MIN: u32 = 480;
pub const BREAKPOINT_TABLET_SMALL_MAX: u32 = 599;
pub const BREAKPOINT_TABLET_LARGE_MIN: u32 = 600;
pub const BREAKPOINT_TABLET_LARGE_MAX: u32 = 839;
pub const BREAKPOINT_DESKTOP_MIN: u32 = 840;

pub fn get_breakpoint(width_dp: u32, height_dp: u32) Breakpoint {
    std.debug.assert(width_dp > 0);
    std.debug.assert(width_dp <= 10000);
    std.debug.assert(height_dp > 0);
    std.debug.assert(height_dp <= 10000);
    
    // Use width for breakpoint determination (standard practice)
    if (width_dp < BREAKPOINT_PHONE_MEDIUM_MIN) {
        return .phone_small;
    } else if (width_dp <= BREAKPOINT_PHONE_MEDIUM_MAX) {
        return .phone_medium;
    } else if (width_dp <= BREAKPOINT_PHONE_LARGE_MAX) {
        return .phone_large;
    } else if (width_dp <= BREAKPOINT_TABLET_SMALL_MAX) {
        return .tablet_small;
    } else if (width_dp <= BREAKPOINT_TABLET_LARGE_MAX) {
        return .tablet_large;
    } else {
        return .desktop;
    }
}

