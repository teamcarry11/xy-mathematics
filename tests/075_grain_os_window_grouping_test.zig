//! Tests for Grain OS window grouping system.
//!
//! Why: Verify window grouping functionality and management.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const WindowGroup = grain_os.window_grouping.WindowGroup;
const WindowGroupManager = grain_os.window_grouping.WindowGroupManager;

test "window group initialization" {
    const group = WindowGroup.init(1);
    std.debug.assert(group.group_id == 1);
    std.debug.assert(group.window_ids_len == 0);
}

test "window group add window" {
    var group = WindowGroup.init(1);
    const result = group.add_window(100);
    std.debug.assert(result);
    std.debug.assert(group.window_ids_len == 1);
    std.debug.assert(group.window_ids[0] == 100);
}

test "window group remove window" {
    var group = WindowGroup.init(1);
    _ = group.add_window(100);
    const result = group.remove_window(100);
    std.debug.assert(result);
    std.debug.assert(group.window_ids_len == 0);
}

test "window group has window" {
    var group = WindowGroup.init(1);
    _ = group.add_window(100);
    std.debug.assert(group.has_window(100) == true);
    std.debug.assert(group.has_window(200) == false);
}

test "window group get window count" {
    var group = WindowGroup.init(1);
    _ = group.add_window(100);
    _ = group.add_window(200);
    std.debug.assert(group.get_window_count() == 2);
}

test "window group set name" {
    var group = WindowGroup.init(1);
    group.set_name("Test Group");
    std.debug.assert(group.name_len > 0);
}

test "group manager initialization" {
    const manager = WindowGroupManager.init();
    std.debug.assert(manager.groups_len == 0);
    std.debug.assert(manager.next_group_id == 1);
}

test "group manager create group" {
    var manager = WindowGroupManager.init();
    const group_id_opt = manager.create_group();
    std.debug.assert(group_id_opt != null);
    if (group_id_opt) |group_id| {
        std.debug.assert(group_id == 1);
        std.debug.assert(manager.groups_len == 1);
    }
}

test "group manager get group" {
    var manager = WindowGroupManager.init();
    if (manager.create_group()) |group_id| {
        const group_opt = manager.get_group(group_id);
        std.debug.assert(group_opt != null);
        if (group_opt) |group| {
            std.debug.assert(group.group_id == group_id);
        }
    }
}

test "group manager add window to group" {
    var manager = WindowGroupManager.init();
    if (manager.create_group()) |group_id| {
        const result = manager.add_window_to_group(100, group_id);
        std.debug.assert(result);
        if (manager.get_group(group_id)) |group| {
            std.debug.assert(group.has_window(100));
        }
    }
}

test "group manager find group for window" {
    var manager = WindowGroupManager.init();
    if (manager.create_group()) |group_id| {
        _ = manager.add_window_to_group(100, group_id);
        const found_group_id = manager.find_group_for_window(100);
        std.debug.assert(found_group_id != null);
        if (found_group_id) |found_id| {
            std.debug.assert(found_id == group_id);
        }
    }
}

test "group manager delete group" {
    var manager = WindowGroupManager.init();
    if (manager.create_group()) |group_id| {
        const result = manager.delete_group(group_id);
        std.debug.assert(result);
        std.debug.assert(manager.groups_len == 0);
    }
}

test "compositor create window group" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const group_id_opt = comp.create_window_group();
    std.debug.assert(group_id_opt != null);
}

test "compositor add window to group" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    if (comp.create_window_group()) |group_id| {
        const result = comp.add_window_to_group(window_id, group_id);
        std.debug.assert(result);
    }
}

test "compositor find window group" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    if (comp.create_window_group()) |group_id| {
        _ = comp.add_window_to_group(window_id, group_id);
        const found_group_id = comp.find_window_group(window_id);
        std.debug.assert(found_group_id != null);
        if (found_group_id) |found_id| {
            std.debug.assert(found_id == group_id);
        }
    }
}

test "compositor remove window from all groups" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    if (comp.create_window_group()) |group_id| {
        _ = comp.add_window_to_group(window_id, group_id);
        _ = comp.remove_window(window_id);
        // Window should be removed from all groups automatically.
        const found_group_id = comp.find_window_group(window_id);
        std.debug.assert(found_group_id == null);
    }
}

