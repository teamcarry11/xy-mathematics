//! Grain OS Window Grouping: Group windows together for unified management.
//!
//! Why: Allow windows to be grouped and managed as a unit.
//! Architecture: Window group management and operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Max groups.
pub const MAX_GROUPS: u32 = 64;

// Bounded: Max windows per group.
pub const MAX_GROUP_WINDOWS: u32 = 16;

// Window group: collection of windows managed together.
pub const WindowGroup = struct {
    group_id: u32,
    window_ids: [MAX_GROUP_WINDOWS]u32,
    window_ids_len: u32,
    name: [compositor.MAX_TITLE_LEN]u8,
    name_len: u32,

    pub fn init(group_id: u32) WindowGroup {
        var group = WindowGroup{
            .group_id = group_id,
            .window_ids = undefined,
            .window_ids_len = 0,
            .name = undefined,
            .name_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_GROUP_WINDOWS) : (i += 1) {
            group.window_ids[i] = 0;
        }
        var j: u32 = 0;
        while (j < compositor.MAX_TITLE_LEN) : (j += 1) {
            group.name[j] = 0;
        }
        return group;
    }

    // Add window to group.
    pub fn add_window(self: *WindowGroup, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.window_ids_len >= MAX_GROUP_WINDOWS) {
            return false;
        }
        // Check if window already in group.
        var i: u32 = 0;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                return true; // Already in group.
            }
        }
        self.window_ids[self.window_ids_len] = window_id;
        self.window_ids_len += 1;
        return true;
    }

    // Remove window from group.
    pub fn remove_window(self: *WindowGroup, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining windows left.
        while (i < self.window_ids_len - 1) : (i += 1) {
            self.window_ids[i] = self.window_ids[i + 1];
        }
        self.window_ids_len -= 1;
        return true;
    }

    // Check if window is in group.
    pub fn has_window(self: *const WindowGroup, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                return true;
            }
        }
        return false;
    }

    // Get window count in group.
    pub fn get_window_count(self: *const WindowGroup) u32 {
        return self.window_ids_len;
    }

    // Set group name.
    pub fn set_name(self: *WindowGroup, name: []const u8) void {
        std.debug.assert(name.len <= compositor.MAX_TITLE_LEN);
        const copy_len = @min(name.len, compositor.MAX_TITLE_LEN);
        var i: u32 = 0;
        while (i < compositor.MAX_TITLE_LEN) : (i += 1) {
            self.name[i] = 0;
        }
        i = 0;
        while (i < copy_len) : (i += 1) {
            self.name[i] = name[i];
        }
        self.name_len = @intCast(copy_len);
    }
};

// Window group manager: manages window groups.
pub const WindowGroupManager = struct {
    groups: [MAX_GROUPS]WindowGroup,
    groups_len: u32,
    next_group_id: u32,

    pub fn init() WindowGroupManager {
        var manager = WindowGroupManager{
            .groups = undefined,
            .groups_len = 0,
            .next_group_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_GROUPS) : (i += 1) {
            manager.groups[i] = WindowGroup.init(0);
        }
        return manager;
    }

    // Create new group.
    pub fn create_group(self: *WindowGroupManager) ?u32 {
        if (self.groups_len >= MAX_GROUPS) {
            return null;
        }
        const group_id = self.next_group_id;
        self.next_group_id += 1;
        self.groups[self.groups_len] = WindowGroup.init(group_id);
        self.groups_len += 1;
        return group_id;
    }

    // Get group by ID.
    pub fn get_group(self: *WindowGroupManager, group_id: u32) ?*WindowGroup {
        std.debug.assert(group_id > 0);
        var i: u32 = 0;
        while (i < self.groups_len) : (i += 1) {
            if (self.groups[i].group_id == group_id) {
                return &self.groups[i];
            }
        }
        return null;
    }

    // Find group containing window.
    pub fn find_group_for_window(
        self: *WindowGroupManager,
        window_id: u32,
    ) ?u32 {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.groups_len) : (i += 1) {
            if (self.groups[i].has_window(window_id)) {
                return self.groups[i].group_id;
            }
        }
        return null;
    }

    // Add window to group.
    pub fn add_window_to_group(
        self: *WindowGroupManager,
        window_id: u32,
        group_id: u32,
    ) bool {
        std.debug.assert(window_id > 0);
        std.debug.assert(group_id > 0);
        if (self.get_group(group_id)) |group| {
            return group.add_window(window_id);
        }
        return false;
    }

    // Remove window from group.
    pub fn remove_window_from_group(
        self: *WindowGroupManager,
        window_id: u32,
        group_id: u32,
    ) bool {
        std.debug.assert(window_id > 0);
        std.debug.assert(group_id > 0);
        if (self.get_group(group_id)) |group| {
            return group.remove_window(window_id);
        }
        return false;
    }

    // Remove window from all groups.
    pub fn remove_window_from_all_groups(
        self: *WindowGroupManager,
        window_id: u32,
    ) void {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.groups_len) : (i += 1) {
            _ = self.groups[i].remove_window(window_id);
        }
    }

    // Delete group.
    pub fn delete_group(self: *WindowGroupManager, group_id: u32) bool {
        std.debug.assert(group_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.groups_len) : (i += 1) {
            if (self.groups[i].group_id == group_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining groups left.
        while (i < self.groups_len - 1) : (i += 1) {
            self.groups[i] = self.groups[i + 1];
        }
        self.groups_len -= 1;
        return true;
    }

    // Get group count.
    pub fn get_group_count(self: *const WindowGroupManager) u32 {
        return self.groups_len;
    }
};

