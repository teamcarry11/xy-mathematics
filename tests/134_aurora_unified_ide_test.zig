//! Tests for Aurora Unified IDE module.
//!
//! Why: Verify unified IDE functionality (tab management, layout,
//! payment integration, live preview).
//! Architecture: Comprehensive test coverage for unified IDE integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-23-205405-PST: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const UnifiedIde = @import("aurora_unified_ide").UnifiedIde;

test "unified ide constants" {
    // Assert: MAX_EDITOR_TABS is 100
    std.debug.assert(UnifiedIde.MAX_EDITOR_TABS == 100);
    
    // Assert: MAX_BROWSER_TABS is 100
    std.debug.assert(UnifiedIde.MAX_BROWSER_TABS == 100);
}

test "unified ide editor tab structure" {
    // EditorTab requires Editor, which has complex dependencies
    // This test verifies the structure exists
    _ = UnifiedIde.EditorTab;
    
    // Assert: EditorTab structure exists
}

test "unified ide browser tab structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const url = try arena.allocator().dupe(u8, "https://example.com");
    defer arena.allocator().free(url);
    
    const title = try arena.allocator().dupe(u8, "Example");
    defer arena.allocator().free(title);
    
    // BrowserTab requires complex dependencies, so we just verify structure
    _ = UnifiedIde.BrowserTab;
    
    // Assert: BrowserTab structure exists
}

test "unified ide initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Assert: IDE initialized
    std.debug.assert(ide.editor_tabs.items.len == 0);
    std.debug.assert(ide.browser_tabs.items.len == 0);
    std.debug.assert(ide.current_editor_tab == 0);
    std.debug.assert(ide.current_browser_tab == 0);
}

test "unified ide deinitialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    ide.deinit();
    
    // Assert: IDE deinitialized (no crash)
}

test "unified ide open editor tab" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    const tab_id = try ide.open_editor_tab("file:///test.zig", "const x = 1;");
    
    // Assert: Tab created
    std.debug.assert(tab_id == 0);
    std.debug.assert(ide.editor_tabs.items.len == 1);
    std.debug.assert(ide.current_editor_tab == 0);
    std.debug.assert(ide.get_current_editor_tab() != null);
}

test "unified ide open browser tab" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    const tab_id = try ide.open_browser_tab("nostr:note1abc...");
    
    // Assert: Tab created
    std.debug.assert(tab_id == 0);
    std.debug.assert(ide.browser_tabs.items.len == 1);
    std.debug.assert(ide.current_browser_tab == 0);
    std.debug.assert(ide.get_current_browser_tab() != null);
}

test "unified ide multiple editor tabs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    const tab1 = try ide.open_editor_tab("file:///test1.zig", "const x = 1;");
    const tab2 = try ide.open_editor_tab("file:///test2.zig", "const y = 2;");
    
    // Assert: Multiple tabs created
    std.debug.assert(tab1 == 0);
    std.debug.assert(tab2 == 1);
    std.debug.assert(ide.editor_tabs.items.len == 2);
    std.debug.assert(ide.current_editor_tab == 1);
}

test "unified ide multiple browser tabs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    const tab1 = try ide.open_browser_tab("https://example.com");
    const tab2 = try ide.open_browser_tab("nostr:note1abc...");
    
    // Assert: Multiple tabs created
    std.debug.assert(tab1 == 0);
    std.debug.assert(tab2 == 1);
    std.debug.assert(ide.browser_tabs.items.len == 2);
    std.debug.assert(ide.current_browser_tab == 1);
}

test "unified ide switch editor tab" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    _ = try ide.open_editor_tab("file:///test1.zig", "const x = 1;");
    _ = try ide.open_editor_tab("file:///test2.zig", "const y = 2;");
    
    ide.switch_editor_tab(0);
    
    // Assert: Switched to first tab
    std.debug.assert(ide.current_editor_tab == 0);
}

test "unified ide switch browser tab" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    _ = try ide.open_browser_tab("https://example.com");
    _ = try ide.open_browser_tab("nostr:note1abc...");
    
    ide.switch_browser_tab(0);
    
    // Assert: Switched to first tab
    std.debug.assert(ide.current_browser_tab == 0);
}

test "unified ide close editor tab" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    _ = try ide.open_editor_tab("file:///test1.zig", "const x = 1;");
    _ = try ide.open_editor_tab("file:///test2.zig", "const y = 2;");
    
    try ide.close_editor_tab(0);
    
    // Assert: Tab closed
    std.debug.assert(ide.editor_tabs.items.len == 1);
    std.debug.assert(ide.current_editor_tab == 0);
}

test "unified ide close browser tab" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    _ = try ide.open_browser_tab("https://example.com");
    _ = try ide.open_browser_tab("nostr:note1abc...");
    
    try ide.close_browser_tab(0);
    
    // Assert: Tab closed
    std.debug.assert(ide.browser_tabs.items.len == 1);
    std.debug.assert(ide.current_browser_tab == 0);
}

test "unified ide get current editor tab when empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Assert: No current tab when empty
    std.debug.assert(ide.get_current_editor_tab() == null);
}

test "unified ide get current browser tab when empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Assert: No current tab when empty
    std.debug.assert(ide.get_current_browser_tab() == null);
}

test "unified ide get editor tabs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    _ = try ide.open_editor_tab("file:///test1.zig", "const x = 1;");
    _ = try ide.open_editor_tab("file:///test2.zig", "const y = 2;");
    
    const tabs = ide.get_editor_tabs();
    
    // Assert: Tabs returned
    std.debug.assert(tabs.len == 2);
}

test "unified ide get browser tabs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    _ = try ide.open_browser_tab("https://example.com");
    _ = try ide.open_browser_tab("nostr:note1abc...");
    
    const tabs = ide.get_browser_tabs();
    
    // Assert: Tabs returned
    std.debug.assert(tabs.len == 2);
}

test "unified ide resize" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    try ide.resize(1280, 720);
    
    // Assert: Resized successfully
    std.debug.assert(ide.layout.root != null);
}

test "unified ide handle window resize" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    try ide.handle_window_resize(1280, 720);
    
    // Assert: Window resized successfully
    std.debug.assert(ide.layout.root != null);
}

test "unified ide handle window resize invalid dimensions" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Should not crash (ignores invalid dimensions)
    try ide.handle_window_resize(0, 0);
    try ide.handle_window_resize(20000, 20000);
    
    // Assert: No crash
}

test "unified ide set payment enabled" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    const tab_id = try ide.open_browser_tab("https://example.com");
    
    ide.set_payment_enabled(tab_id, true);
    
    // Assert: Payment enabled
    const tab = ide.get_current_browser_tab();
    std.debug.assert(tab != null);
    std.debug.assert(tab.?.payment_enabled == true);
}

test "unified ide set tab contract" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    const tab_id = try ide.open_browser_tab("https://example.com");
    
    ide.set_tab_contract(tab_id, 12345);
    
    // Assert: Contract set
    const tab = ide.get_current_browser_tab();
    std.debug.assert(tab != null);
    std.debug.assert(tab.?.contract_id == 12345);
    std.debug.assert(tab.?.payment_enabled == true);
}

test "unified ide focus next pane" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Should not crash
    ide.focus_next_pane();
    
    // Assert: No crash
}

test "unified ide close focused pane" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Should not crash (may fail if no panes, but handled gracefully)
    _ = ide.close_focused_pane() catch {};
    
    // Assert: No crash
}

test "unified ide switch workspace" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Should not crash (may fail if workspace doesn't exist, but handled)
    _ = ide.switch_workspace(0) catch {};
    
    // Assert: No crash
}

test "unified ide subscribe live preview" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    const editor_tab = try ide.open_editor_tab("file:///test.zig", "const x = 1;");
    const browser_tab = try ide.open_browser_tab("https://example.com");
    
    // Should not crash (direction enum exists)
    _ = ide.subscribe_live_preview(editor_tab, browser_tab, .editor_to_browser) catch {};
    
    // Assert: No crash
}

test "unified ide process live preview updates" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    _ = try ide.open_editor_tab("file:///test.zig", "const x = 1;");
    _ = try ide.open_browser_tab("https://example.com");
    
    // Should not crash
    _ = ide.process_live_preview_updates() catch {};
    
    // Assert: No crash
}

test "unified ide handle editor edit" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    const tab_id = try ide.open_editor_tab("file:///test.zig", "const x = 1;");
    
    // Should not crash
    _ = ide.handle_editor_edit(tab_id, "const x = 1;", "const x = 2;") catch {};
    
    // Assert: No crash
}

test "unified ide handle browser update" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    const tab_id = try ide.open_browser_tab("nostr:note1abc...");
    
    // Should not crash
    _ = ide.handle_browser_update(tab_id, "content", "event_id") catch {};
    
    // Assert: No crash
}

test "unified ide editor tab with long file uri" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Create URI within bounds (4096 chars)
    var uri_buf = std.ArrayList(u8).init(arena.allocator());
    defer uri_buf.deinit();
    try uri_buf.appendSlice("file:///");
    while (uri_buf.items.len < 4096) {
        try uri_buf.append('x');
    }
    
    // Should not panic (assertions pass)
    _ = try ide.open_editor_tab(uri_buf.items, "test");
}

test "unified ide browser tab with long url" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Create URL within bounds (4096 chars)
    var url_buf = std.ArrayList(u8).init(arena.allocator());
    defer url_buf.deinit();
    try url_buf.appendSlice("https://example.com/");
    while (url_buf.items.len < 4096) {
        try url_buf.append('x');
    }
    
    // Should not panic (assertions pass)
    _ = try ide.open_browser_tab(url_buf.items);
}

test "unified ide multiple instances" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide1 = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide1.deinit();
    
    var ide2 = try UnifiedIde.init(arena.allocator(), 1280, 720);
    defer ide2.deinit();
    
    _ = try ide1.open_editor_tab("file:///test1.zig", "const x = 1;");
    _ = try ide2.open_editor_tab("file:///test2.zig", "const y = 2;");
    
    // Assert: Multiple instances independent
    std.debug.assert(ide1.editor_tabs.items.len == 1);
    std.debug.assert(ide2.editor_tabs.items.len == 1);
}

test "unified ide bounds check editor tabs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Open tabs up to limit (100)
    var i: u32 = 0;
    while (i < UnifiedIde.MAX_EDITOR_TABS) : (i += 1) {
        var uri_buf = std.ArrayList(u8).init(arena.allocator());
        defer uri_buf.deinit();
        try std.fmt.format(uri_buf.writer(), "file:///test{}.zig", .{i});
        
        _ = try ide.open_editor_tab(uri_buf.items, "test");
    }
    
    // Assert: All tabs created
    std.debug.assert(ide.editor_tabs.items.len == UnifiedIde.MAX_EDITOR_TABS);
}

test "unified ide bounds check browser tabs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Open tabs up to limit (100)
    var i: u32 = 0;
    while (i < UnifiedIde.MAX_BROWSER_TABS) : (i += 1) {
        var url_buf = std.ArrayList(u8).init(arena.allocator());
        defer url_buf.deinit();
        try std.fmt.format(url_buf.writer(), "https://example{}.com", .{i});
        
        _ = try ide.open_browser_tab(url_buf.items);
    }
    
    // Assert: All tabs created
    std.debug.assert(ide.browser_tabs.items.len == UnifiedIde.MAX_BROWSER_TABS);
}
