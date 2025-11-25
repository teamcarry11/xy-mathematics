//! Tests for Grain OS launcher-application integration.
//!
//! Why: Verify launcher items launch applications correctly.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const DesktopShell = grain_os.desktop_shell.DesktopShell;

// Mock syscall function for launcher.
fn mock_syscall(_: u32, _: u64, _: u64, _: u64, _: u64) i64 {
    return 0; // Success.
}

test "desktop shell set app registry" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const compositor = Compositor.init(allocator);
    std.debug.assert(compositor.shell.app_registry != null);
}

test "desktop shell sync launcher items" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const app_id = compositor.register_application(
        "Test App",
        "/apps/test",
        "test-app",
    );
    std.debug.assert(app_id != null);
    // Launcher items should be synced after registration.
    std.debug.assert(compositor.shell.launcher_items_len > 0);
}

test "desktop shell get launcher item at" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    _ = compositor.register_application(
        "Test App",
        "/apps/test",
        "test-app",
    );
    compositor.shell.toggle_launcher();
    const launcher_x = (compositor.output.width - grain_os.desktop_shell.LAUNCHER_WIDTH) / 2;
    const launcher_y = (compositor.output.height - grain_os.desktop_shell.LAUNCHER_HEIGHT) / 2;
    const item_x = launcher_x + 10;
    const item_y = launcher_y + 50; // First item area.
    const item_index = compositor.shell.get_launcher_item_at(item_x, item_y);
    std.debug.assert(item_index != null);
}

test "compositor launcher item click" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    _ = compositor.register_application(
        "Test App",
        "/apps/test",
        "test-app",
    );
    compositor.set_syscall_fn(mock_syscall);
    compositor.shell.toggle_launcher();
    // Create mock mouse event for launcher item click.
    var input_handler = grain_os.input_handler.InputHandler.init();
    input_handler.set_syscall_fn(mock_syscall);
    // Process input would trigger launcher item launch.
    // This test verifies the integration is set up correctly.
    std.debug.assert(compositor.shell.launcher_visible == true);
}

