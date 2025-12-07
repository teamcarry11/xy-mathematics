//! Tests for Dream Browser Viewport.
//!
//! Why: Verify viewport functionality (scrolling, navigation, history).
//! Architecture: Comprehensive test coverage for viewport operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-020403-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const DreamBrowserViewport = @import("dream_browser_viewport").DreamBrowserViewport;

test "viewport initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Assert: Viewport initialized correctly
    std.debug.assert(viewport.viewport_state.scroll_x == 0);
    std.debug.assert(viewport.viewport_state.scroll_y == 0);
    std.debug.assert(viewport.viewport_state.viewport_width == 800);
    std.debug.assert(viewport.viewport_state.viewport_height == 600);
    std.debug.assert(viewport.history.entries_len == 0);
    std.debug.assert(viewport.history.current_index == 0);
}

test "viewport set size" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set viewport size
    viewport.set_viewport_size(1024, 768);

    // Assert: Size set correctly
    std.debug.assert(viewport.viewport_state.viewport_width == 1024);
    std.debug.assert(viewport.viewport_state.viewport_height == 768);
}

test "viewport set content size" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set content size
    viewport.set_content_size(2000, 3000);

    // Assert: Content size set correctly
    std.debug.assert(viewport.viewport_state.content_width == 2000);
    std.debug.assert(viewport.viewport_state.content_height == 3000);
}

test "viewport scroll by down" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set content size larger than viewport
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(800, 2000);

    // Scroll down
    viewport.scroll_by(0, 100);

    // Assert: Scroll position updated
    std.debug.assert(viewport.viewport_state.scroll_y == 100);
    std.debug.assert(viewport.viewport_state.scroll_x == 0);
}

test "viewport scroll by up" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set content size and scroll down first
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(800, 2000);
    viewport.scroll_by(0, 200);

    // Scroll up
    viewport.scroll_by(0, -100);

    // Assert: Scroll position updated
    std.debug.assert(viewport.viewport_state.scroll_y == 100);
}

test "viewport scroll by right" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set content size larger than viewport
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(2000, 600);

    // Scroll right
    viewport.scroll_by(100, 0);

    // Assert: Scroll position updated
    std.debug.assert(viewport.viewport_state.scroll_x == 100);
    std.debug.assert(viewport.viewport_state.scroll_y == 0);
}

test "viewport scroll by left" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set content size and scroll right first
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(2000, 600);
    viewport.scroll_by(200, 0);

    // Scroll left
    viewport.scroll_by(-100, 0);

    // Assert: Scroll position updated
    std.debug.assert(viewport.viewport_state.scroll_x == 100);
}

test "viewport scroll bounds checking" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set content size
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(800, 1000);

    // Try to scroll beyond content
    viewport.scroll_by(0, 10000);

    // Assert: Scroll position clamped to content bounds
    const max_scroll = viewport.viewport_state.content_height - 
                       viewport.viewport_state.viewport_height;
    std.debug.assert(viewport.viewport_state.scroll_y <= max_scroll);
}

test "viewport can scroll down" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set content size larger than viewport
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(800, 2000);

    // Assert: Can scroll down
    std.debug.assert(viewport.can_scroll_down() == true);

    // Scroll to bottom
    viewport.scroll_by(0, 10000);

    // Assert: Cannot scroll down further
    std.debug.assert(viewport.can_scroll_down() == false);
}

test "viewport can scroll up" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set content size
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(800, 2000);

    // Assert: Cannot scroll up initially
    std.debug.assert(viewport.can_scroll_up() == false);

    // Scroll down
    viewport.scroll_by(0, 100);

    // Assert: Can scroll up
    std.debug.assert(viewport.can_scroll_up() == true);
}

test "viewport add history entry" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Add history entry
    const url = try allocator.dupe(u8, "https://example.com");
    defer allocator.free(url);
    try viewport.add_history_entry(url);

    // Assert: History entry added
    std.debug.assert(viewport.history.entries_len == 1);
    std.debug.assert(viewport.history.current_index == 0);
}

test "viewport navigate back" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Add multiple history entries
    const url1 = try allocator.dupe(u8, "https://example.com/page1");
    defer allocator.free(url1);
    try viewport.add_history_entry(url1);

    const url2 = try allocator.dupe(u8, "https://example.com/page2");
    defer allocator.free(url2);
    try viewport.add_history_entry(url2);

    // Navigate back
    const back_url = try viewport.navigate_back();

    // Assert: Navigated back to previous URL
    try testing.expect(back_url != null);
    try testing.expectEqualStrings("https://example.com/page1", back_url.?);
    std.debug.assert(viewport.history.current_index == 0);
}

test "viewport navigate forward" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Add multiple history entries
    const url1 = try allocator.dupe(u8, "https://example.com/page1");
    defer allocator.free(url1);
    try viewport.add_history_entry(url1);

    const url2 = try allocator.dupe(u8, "https://example.com/page2");
    defer allocator.free(url2);
    try viewport.add_history_entry(url2);

    // Navigate back first
    _ = try viewport.navigate_back();

    // Navigate forward
    const forward_url = try viewport.navigate_forward();

    // Assert: Navigated forward to next URL
    try testing.expect(forward_url != null);
    try testing.expectEqualStrings("https://example.com/page2", forward_url.?);
    std.debug.assert(viewport.history.current_index == 1);
}

test "viewport can navigate back" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Assert: Cannot navigate back initially
    std.debug.assert(viewport.can_navigate_back() == false);

    // Add history entry
    const url1 = try allocator.dupe(u8, "https://example.com/page1");
    defer allocator.free(url1);
    try viewport.add_history_entry(url1);

    const url2 = try allocator.dupe(u8, "https://example.com/page2");
    defer allocator.free(url2);
    try viewport.add_history_entry(url2);

    // Assert: Can navigate back
    std.debug.assert(viewport.can_navigate_back() == true);
}

test "viewport can navigate forward" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Add history entries
    const url1 = try allocator.dupe(u8, "https://example.com/page1");
    defer allocator.free(url1);
    try viewport.add_history_entry(url1);

    const url2 = try allocator.dupe(u8, "https://example.com/page2");
    defer allocator.free(url2);
    try viewport.add_history_entry(url2);

    // Assert: Cannot navigate forward initially
    std.debug.assert(viewport.can_navigate_forward() == false);

    // Navigate back
    _ = try viewport.navigate_back();

    // Assert: Can navigate forward
    std.debug.assert(viewport.can_navigate_forward() == true);
}

test "viewport get current url" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Add history entry
    const url = try allocator.dupe(u8, "https://example.com");
    defer allocator.free(url);
    try viewport.add_history_entry(url);

    // Get current URL
    const current_url = viewport.get_current_url();

    // Assert: Current URL returned
    try testing.expect(current_url != null);
    try testing.expectEqualStrings("https://example.com", current_url.?);
}

test "viewport get viewport state" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Set viewport and content size
    viewport.set_viewport_size(1024, 768);
    viewport.set_content_size(2000, 3000);
    viewport.scroll_by(50, 100);

    // Get viewport state
    const state = viewport.get_viewport_state();

    // Assert: State returned correctly
    std.debug.assert(state.scroll_x == 50);
    std.debug.assert(state.scroll_y == 100);
    std.debug.assert(state.viewport_width == 1024);
    std.debug.assert(state.viewport_height == 768);
    std.debug.assert(state.content_width == 2000);
    std.debug.assert(state.content_height == 3000);
}

test "viewport history bounds" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var viewport = DreamBrowserViewport.init(allocator);
    defer viewport.deinit();

    // Add maximum history entries
    var i: u32 = 0;
    while (i < DreamBrowserViewport.MAX_HISTORY_ENTRIES) : (i += 1) {
        var url_buf: [64]u8 = undefined;
        const url = try std.fmt.bufPrint(
            &url_buf,
            "https://example.com/page{d}",
            .{i},
        );
        const url_copy = try allocator.dupe(u8, url);
        try viewport.add_history_entry(url_copy);
    }

    // Assert: History entries at maximum
    std.debug.assert(viewport.history.entries_len == 
                     DreamBrowserViewport.MAX_HISTORY_ENTRIES);
}

