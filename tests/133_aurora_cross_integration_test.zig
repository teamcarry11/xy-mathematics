//! Tests for Aurora Cross Integration module.
//!
//! Why: Verify cross-component integration functionality (clipboard,
//! navigation, search across editor and browser).
//! Architecture: Comprehensive test coverage for cross-component integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-23-202253-PST: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const CrossIntegration = @import("aurora_cross_integration").CrossIntegration;

test "cross integration constants" {
    // Assert: MAX_CLIPBOARD_SIZE is 1MB
    std.debug.assert(CrossIntegration.MAX_CLIPBOARD_SIZE == 1024 * 1024);
    
    // Assert: MAX_URL_LENGTH is 4096
    std.debug.assert(CrossIntegration.MAX_URL_LENGTH == 4096);
    
    // Assert: MAX_FILE_PATH_LENGTH is 4096
    std.debug.assert(CrossIntegration.MAX_FILE_PATH_LENGTH == 4096);
    
    // Assert: MAX_SEARCH_RESULTS is 100
    std.debug.assert(CrossIntegration.MAX_SEARCH_RESULTS == 100);
}

test "cross integration clipboard source enum" {
    // Assert: ClipboardSource enum values
    std.debug.assert(@intFromEnum(CrossIntegration.ClipboardSource.editor) == 0);
    std.debug.assert(@intFromEnum(CrossIntegration.ClipboardSource.browser) == 1);
}

test "cross integration component type enum" {
    // Assert: ComponentType enum values
    std.debug.assert(@intFromEnum(CrossIntegration.ComponentType.editor) == 0);
    std.debug.assert(@intFromEnum(CrossIntegration.ComponentType.browser) == 1);
}

test "cross integration navigation type enum" {
    // Assert: NavigationType enum values
    std.debug.assert(@intFromEnum(CrossIntegration.NavigationType.url) == 0);
    std.debug.assert(@intFromEnum(CrossIntegration.NavigationType.file_path) == 1);
}

test "cross integration clipboard structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const text = try arena.allocator().dupe(u8, "test clipboard");
    defer arena.allocator().free(text);
    
    const clipboard = CrossIntegration.Clipboard{
        .text = text,
        .source = .editor,
        .timestamp = 1234567890,
    };
    
    // Assert: Clipboard structure initialized
    std.debug.assert(std.mem.eql(u8, clipboard.text, "test clipboard"));
    std.debug.assert(clipboard.source == .editor);
    std.debug.assert(clipboard.timestamp == 1234567890);
}

test "cross integration navigation target structure" {
    const target = CrossIntegration.NavigationTarget{
        .target_type = .url,
        .value = "https://example.com",
    };
    
    // Assert: NavigationTarget structure initialized
    std.debug.assert(target.target_type == .url);
    std.debug.assert(std.mem.eql(u8, target.value, "https://example.com"));
}

test "cross integration search result structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const match_text = try arena.allocator().dupe(u8, "match");
    defer arena.allocator().free(match_text);
    
    const context_before = try arena.allocator().dupe(u8, "before");
    defer arena.allocator().free(context_before);
    
    const context_after = try arena.allocator().dupe(u8, "after");
    defer arena.allocator().free(context_after);
    
    const result = CrossIntegration.SearchResult{
        .component_type = .editor,
        .tab_id = 0,
        .match_text = match_text,
        .match_start = 10,
        .match_end = 15,
        .context_before = context_before,
        .context_after = context_after,
    };
    
    // Assert: SearchResult structure initialized
    std.debug.assert(result.component_type == .editor);
    std.debug.assert(result.tab_id == 0);
    std.debug.assert(std.mem.eql(u8, result.match_text, "match"));
    std.debug.assert(result.match_start == 10);
    std.debug.assert(result.match_end == 15);
}

test "cross integration initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    // Assert: Integration initialized
    std.debug.assert(integration.clipboard == null);
}

test "cross integration deinitialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    integration.deinit();
    
    // Assert: Integration deinitialized (no crash)
}

test "cross integration copy from editor" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    try integration.copy_from_editor("test text");
    
    // Assert: Clipboard set from editor
    const clipboard = integration.get_clipboard();
    std.debug.assert(clipboard != null);
    std.debug.assert(std.mem.eql(u8, clipboard.?, "test text"));
    
    const source = integration.get_clipboard_source();
    std.debug.assert(source.? == .editor);
}

test "cross integration copy from browser" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    try integration.copy_from_browser("browser text");
    
    // Assert: Clipboard set from browser
    const clipboard = integration.get_clipboard();
    std.debug.assert(clipboard != null);
    std.debug.assert(std.mem.eql(u8, clipboard.?, "browser text"));
    
    const source = integration.get_clipboard_source();
    std.debug.assert(source.? == .browser);
}

test "cross integration clipboard replacement" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    try integration.copy_from_editor("first text");
    try integration.copy_from_browser("second text");
    
    // Assert: Clipboard replaced
    const clipboard = integration.get_clipboard();
    std.debug.assert(clipboard != null);
    std.debug.assert(std.mem.eql(u8, clipboard.?, "second text"));
    
    const source = integration.get_clipboard_source();
    std.debug.assert(source.? == .browser);
}

test "cross integration get clipboard when empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    // Assert: Clipboard is null when empty
    const clipboard = integration.get_clipboard();
    std.debug.assert(clipboard == null);
    
    const source = integration.get_clipboard_source();
    std.debug.assert(source == null);
}

test "cross integration extract http url" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_url("Visit http://example.com for more");
    
    // Assert: HTTP URL extracted
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .url);
    std.debug.assert(std.mem.startsWith(u8, target.?.value, "http://"));
}

test "cross integration extract https url" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_url("Visit https://example.com for more");
    
    // Assert: HTTPS URL extracted
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .url);
    std.debug.assert(std.mem.startsWith(u8, target.?.value, "https://"));
}

test "cross integration extract nostr url" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_url("Check nostr:npub1abc123 for details");
    
    // Assert: Nostr URL extracted
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .url);
    std.debug.assert(std.mem.startsWith(u8, target.?.value, "nostr:"));
}

test "cross integration extract url with newline" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_url("Visit https://example.com\nfor more");
    
    // Assert: URL extracted (stops at newline)
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .url);
    std.debug.assert(std.mem.startsWith(u8, target.?.value, "https://"));
    std.debug.assert(!std.mem.containsAtLeast(u8, target.?.value, 1, "\n"));
}

test "cross integration extract url not found" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_url("No URL here");
    
    // Assert: No URL extracted
    std.debug.assert(target == null);
}

test "cross integration extract file path from file url" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_file_path("Open file:///path/to/file.txt");
    
    // Assert: File path extracted
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .file_path);
    std.debug.assert(std.mem.startsWith(u8, target.?.value, "file://"));
}

test "cross integration extract unix file path" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_file_path("/path/to/file.txt");
    
    // Assert: Unix file path extracted
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .file_path);
    std.debug.assert(std.mem.startsWith(u8, target.?.value, "/"));
}

test "cross integration extract windows file path" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_file_path("C:\\path\\to\\file.txt");
    
    // Assert: Windows file path extracted
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .file_path);
    std.debug.assert(target.?.value.len > 0);
}

test "cross integration extract file path with space" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_file_path("/path/to/file.txt and more");
    
    // Assert: File path extracted (stops at space)
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .file_path);
    std.debug.assert(!std.mem.containsAtLeast(u8, target.?.value, 1, " "));
}

test "cross integration extract file path not found" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_file_path("No file path here");
    
    // Assert: No file path extracted
    std.debug.assert(target == null);
}

test "cross integration browser tab structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const url = try arena.allocator().dupe(u8, "https://example.com");
    defer arena.allocator().free(url);
    
    const title = try arena.allocator().dupe(u8, "Example");
    defer arena.allocator().free(title);
    
    const tab = CrossIntegration.BrowserTab{
        .url = url,
        .title = title,
    };
    
    // Assert: BrowserTab structure initialized
    std.debug.assert(std.mem.eql(u8, tab.url, "https://example.com"));
    std.debug.assert(std.mem.eql(u8, tab.title, "Example"));
}

test "cross integration clipboard bounds check" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    // Create text within bounds (1MB)
    const large_text = try arena.allocator().alloc(u8, CrossIntegration.MAX_CLIPBOARD_SIZE);
    defer arena.allocator().free(large_text);
    @memset(large_text, 'x');
    
    // Should not panic (assertions pass)
    try integration.copy_from_editor(large_text);
}

test "cross integration url length bounds check" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    // Create URL within bounds (4096 chars)
    var url_buf = std.ArrayList(u8).init(arena.allocator());
    defer url_buf.deinit();
    try url_buf.appendSlice("https://example.com/");
    while (url_buf.items.len < CrossIntegration.MAX_URL_LENGTH) {
        try url_buf.append('x');
    }
    
    const text = try std.fmt.allocPrint(arena.allocator(), "Visit {s} for more", .{url_buf.items});
    defer arena.allocator().free(text);
    
    // Should not panic (assertions pass)
    _ = integration.extract_url(text);
}

test "cross integration file path length bounds check" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    // Create file path within bounds (4096 chars)
    var path_buf = std.ArrayList(u8).init(arena.allocator());
    defer path_buf.deinit();
    try path_buf.append('/');
    while (path_buf.items.len < CrossIntegration.MAX_FILE_PATH_LENGTH) {
        try path_buf.append('x');
    }
    
    // Should not panic (assertions pass)
    _ = integration.extract_file_path(path_buf.items);
}

test "cross integration multiple clipboard operations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    try integration.copy_from_editor("first");
    try integration.copy_from_browser("second");
    try integration.copy_from_editor("third");
    
    // Assert: Last clipboard value is correct
    const clipboard = integration.get_clipboard();
    std.debug.assert(clipboard != null);
    std.debug.assert(std.mem.eql(u8, clipboard.?, "third"));
    
    const source = integration.get_clipboard_source();
    std.debug.assert(source.? == .editor);
}

test "cross integration empty clipboard after deinit" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    try integration.copy_from_editor("test");
    integration.deinit();
    
    // Create new integration to verify old clipboard is freed
    var integration2 = CrossIntegration.init(arena.allocator());
    defer integration2.deinit();
    
    // Assert: New integration has empty clipboard
    std.debug.assert(integration2.clipboard == null);
}

test "cross integration url at start of text" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_url("https://example.com is the URL");
    
    // Assert: URL at start extracted
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .url);
}

test "cross integration url at end of text" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_url("The URL is https://example.com");
    
    // Assert: URL at end extracted
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .url);
}

test "cross integration file path at start of text" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_file_path("/path/to/file.txt is the file");
    
    // Assert: File path at start extracted
    std.debug.assert(target != null);
    std.debug.assert(target.?.target_type == .file_path);
}

test "cross integration multiple instances" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var integration1 = CrossIntegration.init(arena.allocator());
    defer integration1.deinit();
    
    var integration2 = CrossIntegration.init(arena.allocator());
    defer integration2.deinit();
    
    try integration1.copy_from_editor("text1");
    try integration2.copy_from_browser("text2");
    
    // Assert: Multiple instances independent
    const clipboard1 = integration1.get_clipboard();
    const clipboard2 = integration2.get_clipboard();
    
    std.debug.assert(clipboard1 != null);
    std.debug.assert(clipboard2 != null);
    std.debug.assert(std.mem.eql(u8, clipboard1.?, "text1"));
    std.debug.assert(std.mem.eql(u8, clipboard2.?, "text2"));
}
