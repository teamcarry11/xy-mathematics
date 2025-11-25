//! Tests for Grain OS window preview functionality.
//!
//! Why: Verify window preview generation and caching.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const PreviewManager = grain_os.window_preview.PreviewManager;
const WindowPreview = grain_os.window_preview.WindowPreview;

test "preview manager initialization" {
    const manager = PreviewManager.init();
    std.debug.assert(manager.previews_len == 0);
}

test "get or create preview" {
    var manager = PreviewManager.init();
    const preview_opt = manager.get_preview(1);
    std.debug.assert(preview_opt != null);
    if (preview_opt) |preview| {
        std.debug.assert(preview.window_id == 1);
        std.debug.assert(preview.valid == false);
        std.debug.assert(manager.previews_len == 1);
    }
}

test "remove preview" {
    var manager = PreviewManager.init();
    _ = manager.get_preview(1);
    const result = manager.remove_preview(1);
    std.debug.assert(result);
    std.debug.assert(manager.previews_len == 0);
}

test "clear all previews" {
    var manager = PreviewManager.init();
    _ = manager.get_preview(1);
    _ = manager.get_preview(2);
    manager.clear_all();
    std.debug.assert(manager.previews_len == 0);
}

test "generate preview" {
    var manager = PreviewManager.init();
    const result = manager.generate_preview(
        1, // window_id
        100, // win_x
        200, // win_y
        800, // win_width
        600, // win_height
        1920, // screen_width
        1080, // screen_height
    );
    std.debug.assert(result);
    if (manager.get_preview(1)) |preview| {
        std.debug.assert(preview.valid == true);
        std.debug.assert(preview.width == 160);
        std.debug.assert(preview.height == 90);
    }
}

test "compositor generate window preview" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    const result = comp.generate_window_preview(window_id);
    std.debug.assert(result);
    std.debug.assert(comp.preview_manager.previews_len == 1);
}

test "compositor get window preview" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    _ = comp.generate_window_preview(window_id);
    const preview_opt = comp.get_window_preview(window_id);
    std.debug.assert(preview_opt != null);
    if (preview_opt) |preview| {
        std.debug.assert(preview.window_id == window_id);
        std.debug.assert(preview.valid == true);
    }
}

test "compositor generate all previews" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = try comp.create_window(800, 600);
    _ = try comp.create_window(900, 700);
    _ = try comp.create_window(1000, 800);

    comp.generate_all_previews();
    std.debug.assert(comp.preview_manager.previews_len == 3);
}

test "compositor preview removed on window deletion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const win1 = try comp.create_window(800, 600);
    const win2 = try comp.create_window(900, 700);
    _ = comp.generate_window_preview(win1);
    _ = comp.generate_window_preview(win2);

    _ = comp.remove_window(win1);
    std.debug.assert(comp.preview_manager.previews_len == 1);
    std.debug.assert(comp.preview_manager.previews[0].window_id == win2);
}

test "preview window init" {
    const preview = WindowPreview.init(1);
    std.debug.assert(preview.window_id == 1);
    std.debug.assert(preview.width == 160);
    std.debug.assert(preview.height == 90);
    std.debug.assert(preview.valid == false);
}

test "preview window clear" {
    var preview = WindowPreview.init(1);
    preview.valid = true;
    preview.clear();
    std.debug.assert(preview.valid == false);
}

