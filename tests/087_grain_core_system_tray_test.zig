//! Tests for Grain OS system tray management system.
//!
//! Why: Verify system tray icon management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_core = @import("grain_core");
const Compositor = grain_core.compositor.Compositor;
const SystemTrayManager = grain_core.system_tray.SystemTrayManager;

test "system tray manager initialization" {
    const manager = SystemTrayManager.init();
    std.debug.assert(manager.icons_len == 0);
    std.debug.assert(manager.is_visible());
    std.debug.assert(manager.next_icon_id == 1);
}

test "add tray icon" {
    var manager = SystemTrayManager.init();
    const icon_id_opt = manager.add_icon(1, "/path/to/icon", "Tooltip");
    std.debug.assert(icon_id_opt != null);
    if (icon_id_opt) |icon_id| {
        std.debug.assert(icon_id == 1);
        std.debug.assert(manager.get_icon_count() == 1);
    }
}

test "find icon by ID" {
    var manager = SystemTrayManager.init();
    if (manager.add_icon(1, "/path/to/icon", "Tooltip")) |icon_id| {
        const icon_opt = manager.find_icon(icon_id);
        std.debug.assert(icon_opt != null);
        if (icon_opt) |icon| {
            std.debug.assert(icon.icon_id == icon_id);
        }
    }
}

test "find icon by app ID" {
    var manager = SystemTrayManager.init();
    _ = manager.add_icon(1, "/path/to/icon", "Tooltip");
    const icon_opt = manager.find_icon_by_app_id(1);
    std.debug.assert(icon_opt != null);
    if (icon_opt) |icon| {
        std.debug.assert(icon.app_id == 1);
    }
}

test "remove tray icon" {
    var manager = SystemTrayManager.init();
    if (manager.add_icon(1, "/path/to/icon", "Tooltip")) |icon_id| {
        const result = manager.remove_icon(icon_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_icon_count() == 0);
    }
}

test "update tooltip" {
    var manager = SystemTrayManager.init();
    if (manager.add_icon(1, "/path/to/icon", "Old Tooltip")) |icon_id| {
        const result = manager.update_tooltip(icon_id, "New Tooltip");
        std.debug.assert(result);
        if (manager.find_icon(icon_id)) |icon| {
            const tooltip = icon.tooltip[0..icon.tooltip_len];
            std.debug.assert(std.mem.eql(u8, tooltip, "New Tooltip"));
        }
    }
}

test "show and hide icon" {
    var manager = SystemTrayManager.init();
    if (manager.add_icon(1, "/path/to/icon", "Tooltip")) |icon_id| {
        _ = manager.hide_icon(icon_id);
        std.debug.assert(manager.get_visible_icon_count() == 0);
        _ = manager.show_icon(icon_id);
        std.debug.assert(manager.get_visible_icon_count() == 1);
    }
}

test "show and hide system tray" {
    var manager = SystemTrayManager.init();
    std.debug.assert(manager.is_visible());
    manager.hide();
    std.debug.assert(!manager.is_visible());
    manager.show();
    std.debug.assert(manager.is_visible());
}

test "get visible icon count" {
    var manager = SystemTrayManager.init();
    if (manager.add_icon(1, "/path/to/icon", "Tooltip")) |icon_id| {
        std.debug.assert(manager.get_visible_icon_count() == 1);
        _ = manager.hide_icon(icon_id);
        std.debug.assert(manager.get_visible_icon_count() == 0);
    }
}

test "compositor add tray icon" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const icon_id_opt = comp.add_tray_icon(1, "/path/to/icon", "Tooltip");
    std.debug.assert(icon_id_opt != null);
}

test "compositor remove tray icon" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_tray_icon(1, "/path/to/icon", "Tooltip")) |icon_id| {
        const result = comp.remove_tray_icon(icon_id);
        std.debug.assert(result);
    }
}

test "compositor update tooltip" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_tray_icon(1, "/path/to/icon", "Old Tooltip")) |icon_id| {
        const result = comp.update_tray_icon_tooltip(icon_id, "New Tooltip");
        std.debug.assert(result);
    }
}

test "compositor show system tray" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.is_system_tray_visible());
    comp.hide_system_tray();
    std.debug.assert(!comp.is_system_tray_visible());
    comp.show_system_tray();
    std.debug.assert(comp.is_system_tray_visible());
}

test "compositor get tray icon count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_tray_icon_count() == 0);
    _ = comp.add_tray_icon(1, "/path/to/icon", "Tooltip");
    std.debug.assert(comp.get_tray_icon_count() == 1);
}

test "system tray constants" {
    std.debug.assert(grain_core.system_tray.MAX_TRAY_ICONS == 32);
    std.debug.assert(grain_core.system_tray.MAX_TOOLTIP_LEN == 128);
    std.debug.assert(grain_core.system_tray.MAX_ICON_PATH_LEN == 256);
}

