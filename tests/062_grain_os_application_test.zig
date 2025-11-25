//! Tests for Grain OS application framework.
//!
//! Why: Verify application registration and launching.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const ApplicationRegistry = grain_os.application.ApplicationRegistry;
const ApplicationLauncher = grain_os.application.ApplicationLauncher;
const Compositor = grain_os.compositor.Compositor;

// Mock syscall function for launcher.
fn mock_syscall(_: u32, _: u64, _: u64, _: u64, _: u64) i64 {
    return 0; // Success.
}

test "application registry initialization" {
    const registry = ApplicationRegistry.init();
    std.debug.assert(registry.applications_len == 0);
    std.debug.assert(registry.next_app_id > 0);
}

test "application registry register application" {
    var registry = ApplicationRegistry.init();
    const app_id = registry.register_application(
        "Test App",
        "/apps/test",
        "test-app",
    );
    std.debug.assert(app_id != null);
    std.debug.assert(app_id.? > 0);
    std.debug.assert(registry.applications_len == 1);
}

test "application registry get application" {
    var registry = ApplicationRegistry.init();
    const app_id = registry.register_application(
        "Test App",
        "/apps/test",
        "test-app",
    );
    std.debug.assert(app_id != null);
    if (registry.get_application(app_id.?)) |app| {
        std.debug.assert(app.id == app_id.?);
        std.debug.assert(app.name_len > 0);
    }
}

test "application registry get application by name" {
    var registry = ApplicationRegistry.init();
    _ = registry.register_application(
        "Test App",
        "/apps/test",
        "test-app",
    );
    if (registry.get_application_by_name("Test App")) |app| {
        std.debug.assert(app.name_len > 0);
    }
}

test "application launcher initialization" {
    var registry = ApplicationRegistry.init();
    const launcher = ApplicationLauncher.init(&registry);
    std.debug.assert(@intFromPtr(launcher.registry) != 0);
}

test "application launcher set syscall fn" {
    var registry = ApplicationRegistry.init();
    var launcher = ApplicationLauncher.init(&registry);
    launcher.set_syscall_fn(mock_syscall);
    std.debug.assert(launcher.syscall_fn != null);
}

test "compositor application integration" {
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
}

test "compositor launch application" {
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
    const launched = compositor.launch_application("Test App");
    // Launch should attempt to call syscall (mock returns success).
    std.debug.assert(launched);
}

