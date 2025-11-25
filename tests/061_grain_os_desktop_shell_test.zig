//! Tests for Grain OS desktop shell.
//!
//! Why: Verify desktop shell rendering and launcher functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const DesktopShell = grain_os.desktop_shell.DesktopShell;
const FramebufferRenderer = grain_os.framebuffer_renderer.FramebufferRenderer;

// Mock syscall function for renderer.
fn mock_syscall(_: u32, _: u64, _: u64, _: u64, _: u64) i64 {
    return 0;
}

test "desktop shell initialization" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    const shell = DesktopShell.init(&renderer, 1024, 768);
    std.debug.assert(shell.output_width == 1024);
    std.debug.assert(shell.output_height == 768);
    std.debug.assert(shell.launcher_items_len > 0);
    std.debug.assert(shell.launcher_visible == false);
}

test "desktop shell add launcher item" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    var shell = DesktopShell.init(&renderer, 1024, 768);
    const initial_len = shell.launcher_items_len;
    const added = shell.add_launcher_item("Test App", "test-app");
    std.debug.assert(added);
    std.debug.assert(shell.launcher_items_len == initial_len + 1);
}

test "desktop shell toggle launcher" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    var shell = DesktopShell.init(&renderer, 1024, 768);
    std.debug.assert(shell.launcher_visible == false);
    shell.toggle_launcher();
    std.debug.assert(shell.launcher_visible == true);
    shell.toggle_launcher();
    std.debug.assert(shell.launcher_visible == false);
}

test "desktop shell set current workspace" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    var shell = DesktopShell.init(&renderer, 1024, 768);
    shell.set_current_workspace(2);
    std.debug.assert(shell.current_workspace_id == 2);
}

test "desktop shell render" {
    var renderer = FramebufferRenderer.init();
    renderer.set_syscall_fn(mock_syscall);
    const shell = DesktopShell.init(&renderer, 1024, 768);
    // Render should not crash.
    shell.render();
}

test "compositor desktop shell integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = grain_os.compositor.Compositor.init(allocator);
    // Toggle launcher should work.
    compositor.toggle_launcher();
    std.debug.assert(compositor.shell.launcher_visible == true);
    compositor.toggle_launcher();
    std.debug.assert(compositor.shell.launcher_visible == false);
}

