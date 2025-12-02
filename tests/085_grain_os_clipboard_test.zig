//! Tests for Grain OS clipboard management system.
//!
//! Why: Verify clipboard copy/paste functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ClipboardManager = grain_os.clipboard.ClipboardManager;
const ClipboardFormat = grain_os.clipboard.ClipboardFormat;

test "clipboard manager initialization" {
    const manager = ClipboardManager.init();
    std.debug.assert(manager.is_empty());
    std.debug.assert(manager.get_history_count() == 0);
}

test "set clipboard data" {
    var manager = ClipboardManager.init();
    const result = manager.set_data(ClipboardFormat.text, "Hello, World!", "text/plain");
    std.debug.assert(result);
    std.debug.assert(!manager.is_empty());
}

test "get clipboard data" {
    var manager = ClipboardManager.init();
    _ = manager.set_data(ClipboardFormat.text, "Test data", "text/plain");
    const data_opt = manager.get_data();
    std.debug.assert(data_opt != null);
    if (data_opt) |data| {
        std.debug.assert(std.mem.eql(u8, data, "Test data"));
    }
}

test "get clipboard format" {
    var manager = ClipboardManager.init();
    _ = manager.set_data(ClipboardFormat.html, "<p>HTML</p>", "text/html");
    std.debug.assert(manager.get_format() == ClipboardFormat.html);
}

test "get clipboard format name" {
    var manager = ClipboardManager.init();
    _ = manager.set_data(ClipboardFormat.text, "Text", "text/plain");
    const format_name = manager.get_format_name();
    std.debug.assert(std.mem.eql(u8, format_name, "text/plain"));
}

test "clear clipboard" {
    var manager = ClipboardManager.init();
    _ = manager.set_data(ClipboardFormat.text, "Data", "text/plain");
    manager.clear();
    std.debug.assert(manager.is_empty());
}

test "clipboard history" {
    var manager = ClipboardManager.init();
    _ = manager.set_data(ClipboardFormat.text, "First", "text/plain");
    _ = manager.set_data(ClipboardFormat.text, "Second", "text/plain");
    std.debug.assert(manager.get_history_count() == 1);
    if (manager.get_history_entry(0)) |entry| {
        const entry_data = entry.data[0..entry.data_len];
        std.debug.assert(std.mem.eql(u8, entry_data, "First"));
    }
}

test "clear clipboard history" {
    var manager = ClipboardManager.init();
    _ = manager.set_data(ClipboardFormat.text, "First", "text/plain");
    _ = manager.set_data(ClipboardFormat.text, "Second", "text/plain");
    manager.clear_history();
    std.debug.assert(manager.get_history_count() == 0);
}

test "clipboard formats" {
    var manager = ClipboardManager.init();
    _ = manager.set_data(ClipboardFormat.text, "Text", "text/plain");
    std.debug.assert(manager.get_format() == ClipboardFormat.text);
    _ = manager.set_data(ClipboardFormat.html, "<p>HTML</p>", "text/html");
    std.debug.assert(manager.get_format() == ClipboardFormat.html);
    _ = manager.set_data(ClipboardFormat.image, "Image data", "image/png");
    std.debug.assert(manager.get_format() == ClipboardFormat.image);
}

test "compositor set clipboard data" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const result = comp.set_clipboard_data(ClipboardFormat.text, "Test", "text/plain");
    std.debug.assert(result);
}

test "compositor get clipboard data" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.set_clipboard_data(ClipboardFormat.text, "Test data", "text/plain");
    const data_opt = comp.get_clipboard_data();
    std.debug.assert(data_opt != null);
    if (data_opt) |data| {
        std.debug.assert(std.mem.eql(u8, data, "Test data"));
    }
}

test "compositor get clipboard format" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.set_clipboard_data(ClipboardFormat.html, "<p>HTML</p>", "text/html");
    std.debug.assert(comp.get_clipboard_format() == ClipboardFormat.html);
}

test "compositor clear clipboard" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.set_clipboard_data(ClipboardFormat.text, "Data", "text/plain");
    comp.clear_clipboard();
    std.debug.assert(comp.is_clipboard_empty());
}

test "compositor clipboard history" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.set_clipboard_data(ClipboardFormat.text, "First", "text/plain");
    _ = comp.set_clipboard_data(ClipboardFormat.text, "Second", "text/plain");
    std.debug.assert(comp.get_clipboard_history_count() == 1);
}

test "clipboard constants" {
    std.debug.assert(grain_os.clipboard.MAX_CLIPBOARD_SIZE == 4096);
    std.debug.assert(grain_os.clipboard.MAX_HISTORY_ENTRIES == 16);
    std.debug.assert(grain_os.clipboard.MAX_FORMAT_NAME_LEN == 32);
}

