//! Grain OS Window Drag and Drop: Drag windows between workspaces and drop zones.
//!
//! Why: Allow windows to be dragged and dropped for workspace switching and operations.
//! Architecture: Drag and drop state management and drop zone detection.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Max drop zones.
pub const MAX_DROP_ZONES: u32 = 16;

// Drop zone type.
pub const DropZoneType = enum(u8) {
    none,
    workspace,
    group,
    snap_zone,
};

// Drop zone: target for window drag and drop.
pub const DropZone = struct {
    zone_id: u32,
    zone_type: DropZoneType,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    target_id: u32, // Workspace ID, group ID, etc.
    active: bool,
};

// Drag and drop state.
pub const DragDropState = struct {
    dragging_window_id: u32,
    drag_start_x: i32,
    drag_start_y: i32,
    current_x: i32,
    current_y: i32,
    active: bool,
};

// Drop zone manager: manages drop zones.
pub const DropZoneManager = struct {
    zones: [MAX_DROP_ZONES]DropZone,
    zones_len: u32,
    next_zone_id: u32,

    pub fn init() DropZoneManager {
        var manager = DropZoneManager{
            .zones = undefined,
            .zones_len = 0,
            .next_zone_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_DROP_ZONES) : (i += 1) {
            manager.zones[i] = DropZone{
                .zone_id = 0,
                .zone_type = DropZoneType.none,
                .x = 0,
                .y = 0,
                .width = 0,
                .height = 0,
                .target_id = 0,
                .active = false,
            };
        }
        return manager;
    }

    // Add drop zone.
    pub fn add_drop_zone(
        self: *DropZoneManager,
        zone_type: DropZoneType,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        target_id: u32,
    ) ?u32 {
        if (self.zones_len >= MAX_DROP_ZONES) {
            return null;
        }
        const zone_id = self.next_zone_id;
        self.next_zone_id += 1;
        self.zones[self.zones_len] = DropZone{
            .zone_id = zone_id,
            .zone_type = zone_type,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .target_id = target_id,
            .active = true,
        };
        self.zones_len += 1;
        return zone_id;
    }

    // Find drop zone at point.
    pub fn find_drop_zone_at(
        self: *const DropZoneManager,
        x: u32,
        y: u32,
    ) ?*const DropZone {
        const x_i32 = @as(i32, @intCast(x));
        const y_i32 = @as(i32, @intCast(y));
        var i: u32 = 0;
        while (i < self.zones_len) : (i += 1) {
            const zone = &self.zones[i];
            if (zone.active) {
                if (x_i32 >= zone.x and x_i32 < zone.x + @as(i32, @intCast(zone.width)) and
                    y_i32 >= zone.y and y_i32 < zone.y + @as(i32, @intCast(zone.height)))
                {
                    return zone;
                }
            }
        }
        return null;
    }

    // Remove drop zone.
    pub fn remove_drop_zone(self: *DropZoneManager, zone_id: u32) bool {
        std.debug.assert(zone_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.zones_len) : (i += 1) {
            if (self.zones[i].zone_id == zone_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining zones left.
        while (i < self.zones_len - 1) : (i += 1) {
            self.zones[i] = self.zones[i + 1];
        }
        self.zones_len -= 1;
        return true;
    }

    // Clear all drop zones.
    pub fn clear_all(self: *DropZoneManager) void {
        self.zones_len = 0;
    }

    // Get drop zone count.
    pub fn get_zone_count(self: *const DropZoneManager) u32 {
        return self.zones_len;
    }
};

// Check if window can be dragged.
pub fn can_drag_window(window_id: u32, maximized: bool) bool {
    std.debug.assert(window_id > 0);
    return !maximized;
}

// Check if window can be dropped on target.
pub fn can_drop_window(
    _window_id: u32,
    drop_zone: *const DropZone,
) bool {
    std.debug.assert(_window_id > 0);
    return drop_zone.active;
}

