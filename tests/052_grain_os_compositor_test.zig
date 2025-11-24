//! Tests for Grain OS Wayland compositor.
//!
//! Why: Verify compositor functionality and window management.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const wayland = grain_os.wayland;

test "compositor initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const compositor = Compositor.init(allocator);
    std.debug.assert(compositor.windows_len == 0);
    std.debug.assert(compositor.next_window_id > 0);
    std.debug.assert(compositor.registry.object.id > 0);
    std.debug.assert(compositor.output.object.id > 0);
    std.debug.assert(compositor.seat.object.id > 0);
}

test "create window" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    std.debug.assert(window_id > 0);
    std.debug.assert(compositor.windows_len == 1);

    const window = compositor.get_window(window_id);
    std.debug.assert(window != null);
    if (window) |w| {
        std.debug.assert(w.id == window_id);
        std.debug.assert(w.width == 800);
        std.debug.assert(w.height == 600);
        std.debug.assert(w.surface_id > 0);
    }
}

test "window title" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(640, 480);
    const window = compositor.get_window(window_id);
    std.debug.assert(window != null);
    if (window) |w| {
        w.set_title("Test Window");
        std.debug.assert(w.title_len == 11);
        const title_slice = w.title[0..w.title_len];
        std.debug.assert(std.mem.eql(u8, title_slice, "Test Window"));
    }
}

test "multiple windows" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window1_id = try compositor.create_window(800, 600);
    const window2_id = try compositor.create_window(1024, 768);
    std.debug.assert(window1_id != window2_id);
    std.debug.assert(compositor.windows_len == 2);

    const window1 = compositor.get_window(window1_id);
    const window2 = compositor.get_window(window2_id);
    std.debug.assert(window1 != null);
    std.debug.assert(window2 != null);
    if (window1) |w1| {
        std.debug.assert(w1.width == 800);
        std.debug.assert(w1.height == 600);
    }
    if (window2) |w2| {
        std.debug.assert(w2.width == 1024);
        std.debug.assert(w2.height == 768);
    }
}

test "wayland interface name" {
    const interface = wayland.InterfaceName.init("wl_surface");
    const slice = interface.as_slice();
    std.debug.assert(std.mem.eql(u8, slice, "wl_surface"));
    std.debug.assert(interface.len == 10);
}

test "wayland registry bind" {
    var registry = wayland.Registry.init(1);
    std.debug.assert(registry.objects_len == 0);

    const surface_id = try registry.bind(
        1,
        wayland.InterfaceName.init("wl_surface"),
        4,
    );
    std.debug.assert(surface_id > 0);
    std.debug.assert(registry.objects_len == 1);
}

