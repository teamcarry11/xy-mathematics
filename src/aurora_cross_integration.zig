const std = @import("std");
const Editor = @import("aurora_editor.zig").Editor;
const DreamBrowserViewport = @import("dream_browser_viewport.zig").DreamBrowserViewport;

/// Cross Integration: Enhanced communication between editor and browser.
/// ~<~ Glow Airbend: explicit cross-component state, bounded operations.
/// ~~~~ Glow Waterbend: editor and browser share unified state through DAG.
///
/// This implements:
/// - Shared clipboard/selection between editor and browser
/// - URL/file navigation (click URL in editor to open in browser, click file path in browser to open in editor)
/// - Search across both editor and browser tabs
/// - Cross-component state synchronization
pub const CrossIntegration = struct {
    // Bounded: Max 1MB clipboard size
    pub const MAX_CLIPBOARD_SIZE: u32 = 1024 * 1024;
    
    // Bounded: Max 256 characters for URL/file path
    pub const MAX_URL_LENGTH: u32 = 4096;
    pub const MAX_FILE_PATH_LENGTH: u32 = 4096;
    
    // Bounded: Max 100 search results
    pub const MAX_SEARCH_RESULTS: u32 = 100;
    
    /// Shared clipboard (for cross-component copy/paste).
    pub const Clipboard = struct {
        text: []const u8, // Clipboard text
        source: ClipboardSource, // Source component (editor or browser)
        timestamp: u64, // Timestamp of copy operation
    };
    
    /// Clipboard source.
    pub const ClipboardSource = enum {
        editor,
        browser,
    };
    
    /// Search result (across editor and browser).
    pub const SearchResult = struct {
        component_type: ComponentType, // Editor or browser
        tab_id: u32, // Tab ID
        match_text: []const u8, // Matched text
        match_start: u32, // Start position in source
        match_end: u32, // End position in source
        context_before: []const u8, // Context before match
        context_after: []const u8, // Context after match
    };
    
    /// Component type.
    pub const ComponentType = enum {
        editor,
        browser,
    };
    
    /// Navigation target (URL or file path).
    pub const NavigationTarget = struct {
        target_type: NavigationType, // URL or file path
        value: []const u8, // URL or file path
    };
    
    /// Navigation type.
    pub const NavigationType = enum {
        url,
        file_path,
    };
    
    allocator: std.mem.Allocator,
    clipboard: ?Clipboard = null,
    
    /// Initialize cross integration.
    pub fn init(allocator: std.mem.Allocator) CrossIntegration {
        // Assert: Allocator must be valid
        std.debug.assert(@intFromPtr(allocator.ptr) != 0);
        
        return CrossIntegration{
            .allocator = allocator,
            .clipboard = null,
        };
    }
    
    /// Deinitialize cross integration.
    pub fn deinit(self: *CrossIntegration) void {
        // Free clipboard if exists
        if (self.clipboard) |*clipboard| {
            self.allocator.free(clipboard.text);
        }
    }
    
    /// Copy text to shared clipboard from editor.
    pub fn copy_from_editor(self: *CrossIntegration, text: []const u8) !void {
        // Assert: Text must be valid
        std.debug.assert(text.len > 0);
        std.debug.assert(text.len <= MAX_CLIPBOARD_SIZE);
        
        // Free old clipboard if exists
        if (self.clipboard) |*clipboard| {
            self.allocator.free(clipboard.text);
        }
        
        // Copy text
        const text_copy = try self.allocator.dupe(u8, text);
        errdefer self.allocator.free(text_copy);
        
        self.clipboard = Clipboard{
            .text = text_copy,
            .source = .editor,
            .timestamp = get_current_timestamp(),
        };
    }
    
    /// Copy text to shared clipboard from browser.
    pub fn copy_from_browser(self: *CrossIntegration, text: []const u8) !void {
        // Assert: Text must be valid
        std.debug.assert(text.len > 0);
        std.debug.assert(text.len <= MAX_CLIPBOARD_SIZE);
        
        // Free old clipboard if exists
        if (self.clipboard) |*clipboard| {
            self.allocator.free(clipboard.text);
        }
        
        // Copy text
        const text_copy = try self.allocator.dupe(u8, text);
        errdefer self.allocator.free(text_copy);
        
        self.clipboard = Clipboard{
            .text = text_copy,
            .source = .browser,
            .timestamp = get_current_timestamp(),
        };
    }
    
    /// Get clipboard text.
    pub fn get_clipboard(self: *const CrossIntegration) ?[]const u8 {
        if (self.clipboard) |clipboard| {
            return clipboard.text;
        }
        return null;
    }
    
    /// Get clipboard source.
    pub fn get_clipboard_source(self: *const CrossIntegration) ?ClipboardSource {
        if (self.clipboard) |clipboard| {
            return clipboard.source;
        }
        return null;
    }
    
    /// Extract URL from text (for navigation).
    pub fn extract_url(self: *CrossIntegration, text: []const u8) ?NavigationTarget {
        _ = self;
        
        // Assert: Text must be valid
        std.debug.assert(text.len > 0);
        std.debug.assert(text.len <= MAX_CLIPBOARD_SIZE);
        
        // Check for HTTP/HTTPS URLs
        if (std.mem.indexOf(u8, text, "http://") != null or
            std.mem.indexOf(u8, text, "https://") != null)
        {
            // Find URL boundaries (space, newline, etc.)
            var start: ?u32 = null;
            var end: ?u32 = null;
            
            var i: u32 = 0;
            while (i < text.len) : (i += 1) {
                if (start == null) {
                    if (i + 7 <= text.len and std.mem.eql(u8, text[i..i+7], "http://")) {
                        start = i;
                    } else if (i + 8 <= text.len and std.mem.eql(u8, text[i..i+8], "https://")) {
                        start = i;
                    }
                } else {
                    const ch = text[i];
                    if (ch == ' ' or ch == '\n' or ch == '\r' or ch == '\t') {
                        end = i;
                        break;
                    }
                }
            }
            
            if (start) |s| {
                const e = end orelse text.len;
                if (e > s and e - s <= MAX_URL_LENGTH) {
                    // URL found (caller must copy if needed)
                    return NavigationTarget{
                        .target_type = .url,
                        .value = text[s..e],
                    };
                }
            }
        }
        
        // Check for Nostr URLs
        if (std.mem.indexOf(u8, text, "nostr:") != null) {
            var start: ?u32 = null;
            var end: ?u32 = null;
            
            var i: u32 = 0;
            while (i < text.len) : (i += 1) {
                if (start == null) {
                    if (i + 6 <= text.len and std.mem.eql(u8, text[i..i+6], "nostr:")) {
                        start = i;
                    }
                } else {
                    const ch = text[i];
                    if (ch == ' ' or ch == '\n' or ch == '\r' or ch == '\t') {
                        end = i;
                        break;
                    }
                }
            }
            
            if (start) |s| {
                const e = end orelse text.len;
                if (e > s and e - s <= MAX_URL_LENGTH) {
                    return NavigationTarget{
                        .target_type = .url,
                        .value = text[s..e],
                    };
                }
            }
        }
        
        return null;
    }
    
    /// Extract file path from text (for navigation).
    pub fn extract_file_path(self: *CrossIntegration, text: []const u8) ?NavigationTarget {
        _ = self;
        
        // Assert: Text must be valid
        std.debug.assert(text.len > 0);
        std.debug.assert(text.len <= MAX_CLIPBOARD_SIZE);
        
        // Check for file:// URLs
        if (std.mem.indexOf(u8, text, "file://") != null) {
            var start: ?u32 = null;
            var end: ?u32 = null;
            
            var i: u32 = 0;
            while (i < text.len) : (i += 1) {
                if (start == null) {
                    if (i + 7 <= text.len and std.mem.eql(u8, text[i..i+7], "file://")) {
                        start = i;
                    }
                } else {
                    const ch = text[i];
                    if (ch == ' ' or ch == '\n' or ch == '\r' or ch == '\t') {
                        end = i;
                        break;
                    }
                }
            }
            
            if (start) |s| {
                const e = end orelse text.len;
                if (e > s and e - s <= MAX_FILE_PATH_LENGTH) {
                    return NavigationTarget{
                        .target_type = .file_path,
                        .value = text[s..e],
                    };
                }
            }
        }
        
        // Check for absolute paths (Unix/Mac: /path/to/file, Windows: C:\path\to\file)
        if (text.len > 0 and (text[0] == '/' or (text.len > 1 and text[1] == ':'))) {
            // Find path boundaries
            var end: ?u32 = null;
            var i: u32 = 0;
            while (i < text.len) : (i += 1) {
                const ch = text[i];
                if (ch == ' ' or ch == '\n' or ch == '\r' or ch == '\t') {
                    end = i;
                    break;
                }
            }
            
            const e = end orelse text.len;
            if (e <= MAX_FILE_PATH_LENGTH) {
                return NavigationTarget{
                    .target_type = .file_path,
                    .value = text[0..e],
                };
            }
        }
        
        return null;
    }
    
    /// Search across editor and browser tabs.
    /// Note: Returns slice pointing to allocated array (caller must free).
    pub fn search_cross_component(
        self: *CrossIntegration,
        query: []const u8,
        editor_tabs: []const EditorTab,
        browser_tabs: []const BrowserTab,
    ) ![]const SearchResult {
        // Assert: Query must be valid
        std.debug.assert(query.len > 0);
        std.debug.assert(query.len <= 1024); // Bounded query length
        
        // Count matches
        var match_count: u32 = 0;
        
        // Search editor tabs
        for (editor_tabs) |tab| {
            const text = tab.editor.buffer.textSlice();
            var pos: u32 = 0;
            while (pos < text.len) {
                if (std.mem.indexOfPos(u8, text, pos, query)) |match_pos| {
                    match_count += 1;
                    pos = match_pos + query.len;
                    if (match_count >= MAX_SEARCH_RESULTS) break;
                } else {
                    break;
                }
            }
            if (match_count >= MAX_SEARCH_RESULTS) break;
        }
        
        // Search browser tabs
        if (match_count < MAX_SEARCH_RESULTS) {
            for (browser_tabs) |tab| {
                // Search in URL
                if (std.mem.indexOf(u8, tab.url, query) != null) {
                    match_count += 1;
                    if (match_count >= MAX_SEARCH_RESULTS) break;
                }
                
                // Search in title
                if (std.mem.indexOf(u8, tab.title, query) != null) {
                    match_count += 1;
                    if (match_count >= MAX_SEARCH_RESULTS) break;
                }
            }
        }
        
        if (match_count == 0) {
            return &.{};
        }
        
        // Allocate result array
        const results = try self.allocator.alloc(SearchResult, match_count);
        errdefer self.allocator.free(results);
        
        // Collect matches
        var result_idx: u32 = 0;
        
        // Search editor tabs
        for (editor_tabs, 0..) |tab, tab_idx| {
            const text = tab.editor.buffer.textSlice();
            var pos: u32 = 0;
            while (pos < text.len and result_idx < match_count) {
                if (std.mem.indexOfPos(u8, text, pos, query)) |match_pos| {
                    const match_end = match_pos + query.len;
                    const context_start = if (match_pos > 20) match_pos - 20 else 0;
                    const context_end = @min(match_end + 20, text.len);
                    
                    const context_before = try self.allocator.dupe(u8, text[context_start..match_pos]);
                    errdefer self.allocator.free(context_before);
                    
                    const context_after = try self.allocator.dupe(u8, text[match_end..context_end]);
                    errdefer self.allocator.free(context_after);
                    
                    const match_text = try self.allocator.dupe(u8, text[match_pos..match_end]);
                    errdefer self.allocator.free(match_text);
                    
                    results[result_idx] = SearchResult{
                        .component_type = .editor,
                        .tab_id = @intCast(tab_idx),
                        .match_text = match_text,
                        .match_start = match_pos,
                        .match_end = match_end,
                        .context_before = context_before,
                        .context_after = context_after,
                    };
                    result_idx += 1;
                    pos = match_end;
                } else {
                    break;
                }
            }
            if (result_idx >= match_count) break;
        }
        
        // Search browser tabs
        if (result_idx < match_count) {
            for (browser_tabs, 0..) |tab, tab_idx| {
                // Search in URL
                if (std.mem.indexOf(u8, tab.url, query)) |match_pos| {
                    const match_end = match_pos + query.len;
                    const match_text = try self.allocator.dupe(u8, tab.url[match_pos..match_end]);
                    errdefer self.allocator.free(match_text);
                    
                    results[result_idx] = SearchResult{
                        .component_type = .browser,
                        .tab_id = @intCast(tab_idx),
                        .match_text = match_text,
                        .match_start = match_pos,
                        .match_end = match_end,
                        .context_before = "",
                        .context_after = "",
                    };
                    result_idx += 1;
                    if (result_idx >= match_count) break;
                }
                
                // Search in title
                if (std.mem.indexOf(u8, tab.title, query)) |match_pos| {
                    const match_end = match_pos + query.len;
                    const match_text = try self.allocator.dupe(u8, tab.title[match_pos..match_end]);
                    errdefer self.allocator.free(match_text);
                    
                    results[result_idx] = SearchResult{
                        .component_type = .browser,
                        .tab_id = @intCast(tab_idx),
                        .match_text = match_text,
                        .match_start = match_pos,
                        .match_end = match_end,
                        .context_before = "",
                        .context_after = "",
                    };
                    result_idx += 1;
                    if (result_idx >= match_count) break;
                }
            }
        }
        
        return results[0..result_idx];
    }
    
    /// Get current timestamp (simplified).
    fn get_current_timestamp() u64 {
        const timestamp = std.time.timestamp();
        const non_negative = if (timestamp < 0) 0 else @as(u64, @intCast(timestamp));
        return non_negative;
    }
    
    /// Editor tab reference (for search).
    pub const EditorTab = struct {
        editor: Editor,
    };
    
    /// Browser tab reference (for search).
    pub const BrowserTab = struct {
        url: []const u8,
        title: []const u8,
    };
};

test "cross integration initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    // Assert: Integration initialized
    try std.testing.expect(integration.clipboard == null);
}

test "cross integration clipboard" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    try integration.copy_from_editor("test text");
    
    // Assert: Clipboard set
    const clipboard = integration.get_clipboard();
    try std.testing.expect(clipboard != null);
    try std.testing.expect(std.mem.eql(u8, clipboard.?, "test text"));
    
    const source = integration.get_clipboard_source();
    try std.testing.expect(source == .editor);
}

test "cross integration url extraction" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = CrossIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const target = integration.extract_url("Visit https://example.com for more info");
    
    // Assert: URL extracted
    try std.testing.expect(target != null);
    try std.testing.expect(target.?.target_type == .url);
    try std.testing.expect(std.mem.startsWith(u8, target.?.value, "https://"));
}

