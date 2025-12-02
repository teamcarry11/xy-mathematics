//! Tests for Grain OS application launcher system.
//!
//! Why: Verify application launcher and search functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ApplicationLauncher = grain_os.app_launcher.ApplicationLauncher;

test "application launcher initialization" {
    const launcher = ApplicationLauncher.init();
    std.debug.assert(launcher.entries_len == 0);
    std.debug.assert(!launcher.is_visible());
    std.debug.assert(launcher.get_favorites_count() == 0);
    std.debug.assert(launcher.get_recent_apps_count() == 0);
}

test "add app to launcher" {
    var launcher = ApplicationLauncher.init();
    const result = launcher.add_app(1, "Test App", "/path/to/icon");
    std.debug.assert(result);
    std.debug.assert(launcher.get_app_count() == 1);
}

test "find app by ID" {
    var launcher = ApplicationLauncher.init();
    _ = launcher.add_app(1, "Test App", "/path/to/icon");
    const entry_opt = launcher.find_app(1);
    std.debug.assert(entry_opt != null);
    if (entry_opt) |entry| {
        std.debug.assert(entry.app_id == 1);
    }
}

test "search apps" {
    var launcher = ApplicationLauncher.init();
    _ = launcher.add_app(1, "Text Editor", "/path/to/icon");
    _ = launcher.add_app(2, "Terminal", "/path/to/icon");
    _ = launcher.add_app(3, "Browser", "/path/to/icon");
    var results: [32]u32 = undefined;
    const count = launcher.search_apps("Text", results[0..]);
    std.debug.assert(count == 1);
    std.debug.assert(results[0] == 1);
}

test "add to favorites" {
    var launcher = ApplicationLauncher.init();
    _ = launcher.add_app(1, "Test App", "/path/to/icon");
    const result = launcher.add_favorite(1);
    std.debug.assert(result);
    std.debug.assert(launcher.get_favorites_count() == 1);
}

test "remove from favorites" {
    var launcher = ApplicationLauncher.init();
    _ = launcher.add_app(1, "Test App", "/path/to/icon");
    _ = launcher.add_favorite(1);
    const result = launcher.remove_favorite(1);
    std.debug.assert(result);
    std.debug.assert(launcher.get_favorites_count() == 0);
}

test "record app usage" {
    var launcher = ApplicationLauncher.init();
    _ = launcher.add_app(1, "Test App", "/path/to/icon");
    launcher.record_app_usage(1);
    std.debug.assert(launcher.get_recent_apps_count() == 1);
}

test "show and hide launcher" {
    var launcher = ApplicationLauncher.init();
    std.debug.assert(!launcher.is_visible());
    launcher.show();
    std.debug.assert(launcher.is_visible());
    launcher.hide();
    std.debug.assert(!launcher.is_visible());
}

test "compositor add app to launcher" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const result = comp.add_app_to_launcher(1, "Test App", "/path/to/icon");
    std.debug.assert(result);
}

test "compositor search apps" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.add_app_to_launcher(1, "Text Editor", "/path/to/icon");
    var results: [32]u32 = undefined;
    const count = comp.search_apps_in_launcher("Text", results[0..]);
    std.debug.assert(count == 1);
}

test "compositor add to favorites" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.add_app_to_launcher(1, "Test App", "/path/to/icon");
    const result = comp.add_app_to_favorites(1);
    std.debug.assert(result);
}

test "compositor show launcher" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(!comp.is_app_launcher_visible());
    comp.show_app_launcher();
    std.debug.assert(comp.is_app_launcher_visible());
    comp.hide_app_launcher();
    std.debug.assert(!comp.is_app_launcher_visible());
}

test "app launcher constants" {
    std.debug.assert(grain_os.app_launcher.MAX_APPS == 256);
    std.debug.assert(grain_os.app_launcher.MAX_SEARCH_RESULTS == 32);
    std.debug.assert(grain_os.app_launcher.MAX_FAVORITES == 16);
    std.debug.assert(grain_os.app_launcher.MAX_RECENT_APPS == 16);
    std.debug.assert(grain_os.app_launcher.MAX_QUERY_LEN == 128);
}

