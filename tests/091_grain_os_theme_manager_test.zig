//! Tests for Grain OS theme management system.
//!
//! Why: Verify theme management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ThemeManager = grain_os.theme_manager.ThemeManager;

test "theme manager initialization" {
    const manager = ThemeManager.init();
    std.debug.assert(manager.themes_len == 0);
    std.debug.assert(manager.next_theme_id == 1);
    std.debug.assert(manager.current_theme_id == 0);
}

test "add theme" {
    var manager = ThemeManager.init();
    const theme_id_opt = manager.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff");
    std.debug.assert(theme_id_opt != null);
    if (theme_id_opt) |theme_id| {
        std.debug.assert(theme_id == 1);
        std.debug.assert(manager.get_theme_count() == 1);
        std.debug.assert(manager.current_theme_id == theme_id);
    }
}

test "find theme by ID" {
    var manager = ThemeManager.init();
    if (manager.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff")) |theme_id| {
        const theme_opt = manager.find_theme(theme_id);
        std.debug.assert(theme_opt != null);
        if (theme_opt) |theme| {
            std.debug.assert(theme.theme_id == theme_id);
            const name_slice = theme.name[0..theme.name_len];
            std.debug.assert(std.mem.eql(u8, name_slice, "Dark"));
        }
    }
}

test "set current theme" {
    var manager = ThemeManager.init();
    if (manager.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff")) |theme_id_1| {
        if (manager.add_theme("Light", "#ffffff", "#000000", "#cccccc", "#0066ff")) |theme_id_2| {
            const result = manager.set_current_theme(theme_id_2);
            std.debug.assert(result);
            std.debug.assert(manager.current_theme_id == theme_id_2);
        }
    }
}

test "get current theme" {
    var manager = ThemeManager.init();
    std.debug.assert(manager.get_current_theme() == null);
    if (manager.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff")) |theme_id| {
        const current_opt = manager.get_current_theme();
        std.debug.assert(current_opt != null);
        if (current_opt) |current| {
            std.debug.assert(current.theme_id == theme_id);
        }
    }
}

test "remove theme" {
    var manager = ThemeManager.init();
    if (manager.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff")) |theme_id| {
        const result = manager.remove_theme(theme_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_theme_count() == 0);
    }
}

test "remove current theme" {
    var manager = ThemeManager.init();
    if (manager.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff")) |theme_id_1| {
        if (manager.add_theme("Light", "#ffffff", "#000000", "#cccccc", "#0066ff")) |theme_id_2| {
            _ = theme_id_1;
            const result = manager.remove_theme(theme_id_2);
            std.debug.assert(result);
            std.debug.assert(manager.current_theme_id == theme_id_1);
        }
    }
}

test "compositor add theme" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const theme_id_opt = comp.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff");
    std.debug.assert(theme_id_opt != null);
}

test "compositor set current theme" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff")) |theme_id_1| {
        if (comp.add_theme("Light", "#ffffff", "#000000", "#cccccc", "#0066ff")) |theme_id_2| {
            const result = comp.set_current_theme(theme_id_2);
            std.debug.assert(result);
        }
    }
}

test "compositor get current theme" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_current_theme() == null);
    if (comp.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff")) |theme_id| {
        const current_opt = comp.get_current_theme();
        std.debug.assert(current_opt != null);
        if (current_opt) |current| {
            std.debug.assert(current.theme_id == theme_id);
        }
    }
}

test "compositor get theme count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_theme_count() == 0);
    _ = comp.add_theme("Dark", "#000000", "#ffffff", "#333333", "#0066ff");
    std.debug.assert(comp.get_theme_count() == 1);
}

test "theme constants" {
    std.debug.assert(grain_os.theme_manager.MAX_THEMES == 16);
    std.debug.assert(grain_os.theme_manager.MAX_THEME_NAME_LEN == 64);
    std.debug.assert(grain_os.theme_manager.MAX_COLOR_LEN == 8);
}

