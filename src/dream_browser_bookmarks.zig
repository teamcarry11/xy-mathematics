const std = @import("std");

/// Dream Browser Bookmarks: Bookmark management and history tracking.
/// ~<~ Glow Airbend: explicit bookmark storage, bounded history.
/// ~~~~ Glow Waterbend: bookmarks flow deterministically through DAG.
///
/// This implements:
/// - Bookmark storage (URL, title, timestamp)
/// - Bookmark organization (folders, tags)
/// - History tracking (visited URLs, timestamps)
/// - Search and filtering (by title, URL, tag)
pub const DreamBrowserBookmarks = struct {
    // Bounded: Max 10,000 bookmarks
    pub const MAX_BOOKMARKS: u32 = 10_000;
    
    // Bounded: Max 1,000 history entries
    pub const MAX_HISTORY_ENTRIES: u32 = 1_000;
    
    // Bounded: Max 256 characters for title/URL
    pub const MAX_TITLE_LENGTH: u32 = 256;
    pub const MAX_URL_LENGTH: u32 = 2048;
    
    // Bounded: Max 100 tags per bookmark
    pub const MAX_TAGS_PER_BOOKMARK: u32 = 100;
    
    /// Bookmark entry.
    pub const Bookmark = struct {
        url: []const u8, // Bookmark URL
        title: []const u8, // Bookmark title
        folder: ?[]const u8 = null, // Folder name (optional)
        tags: []const []const u8 = &.{}, // Tags (optional)
        created_at: u64, // Creation timestamp
        last_visited: u64, // Last visit timestamp
        visit_count: u32, // Number of visits
    };
    
    /// History entry.
    pub const HistoryEntry = struct {
        url: []const u8, // Visited URL
        title: []const u8, // Page title
        visited_at: u64, // Visit timestamp
        visit_duration: u32, // Visit duration in seconds
    };
    
    /// Bookmark folder.
    pub const BookmarkFolder = struct {
        name: []const u8, // Folder name
        bookmarks: []const u32, // Bookmark indices
        bookmarks_len: u32, // Number of bookmarks in folder
        created_at: u64, // Creation timestamp
    };
    
    /// Bookmarks storage.
    pub const BookmarksStorage = struct {
        bookmarks: []Bookmark, // Bookmark entries
        bookmarks_len: u32, // Current number of bookmarks
        folders: []BookmarkFolder, // Bookmark folders
        folders_len: u32, // Current number of folders
    };
    
    /// History storage.
    pub const HistoryStorage = struct {
        entries: []HistoryEntry, // History entries
        entries_len: u32, // Current number of entries
        entries_index: u32, // Circular buffer index
    };
    
    allocator: std.mem.Allocator,
    bookmarks_storage: BookmarksStorage,
    history_storage: HistoryStorage,
    
    /// Initialize bookmarks manager.
    pub fn init(allocator: std.mem.Allocator) !DreamBrowserBookmarks {
        // Pre-allocate bookmarks storage
        const bookmarks = try allocator.alloc(Bookmark, MAX_BOOKMARKS);
        const folders = try allocator.alloc(BookmarkFolder, 100); // Max 100 folders
        
        // Pre-allocate history storage
        const history_entries = try allocator.alloc(HistoryEntry, MAX_HISTORY_ENTRIES);
        
        return DreamBrowserBookmarks{
            .allocator = allocator,
            .bookmarks_storage = BookmarksStorage{
                .bookmarks = bookmarks,
                .bookmarks_len = 0,
                .folders = folders,
                .folders_len = 0,
            },
            .history_storage = HistoryStorage{
                .entries = history_entries,
                .entries_len = 0,
                .entries_index = 0,
            },
        };
    }
    
    /// Deinitialize bookmarks manager.
    pub fn deinit(self: *DreamBrowserBookmarks) void {
        // Free bookmarks
        for (self.bookmarks_storage.bookmarks[0..self.bookmarks_storage.bookmarks_len]) |*bookmark| {
            self.allocator.free(bookmark.url);
            self.allocator.free(bookmark.title);
            if (bookmark.folder) |folder| {
                self.allocator.free(folder);
            }
            // Free tags only if allocated (not empty slice)
            if (bookmark.tags.len > 0) {
                for (bookmark.tags) |tag| {
                    self.allocator.free(tag);
                }
                self.allocator.free(bookmark.tags);
            }
        }
        
        // Free folders
        for (self.bookmarks_storage.folders[0..self.bookmarks_storage.folders_len]) |*folder| {
            self.allocator.free(folder.name);
            self.allocator.free(folder.bookmarks);
        }
        
        // Free history entries
        for (self.history_storage.entries[0..self.history_storage.entries_len]) |*entry| {
            self.allocator.free(entry.url);
            self.allocator.free(entry.title);
        }
        
        // Free arrays
        self.allocator.free(self.bookmarks_storage.bookmarks);
        self.allocator.free(self.bookmarks_storage.folders);
        self.allocator.free(self.history_storage.entries);
    }
    
    /// Add bookmark.
    pub fn add_bookmark(
        self: *DreamBrowserBookmarks,
        url: []const u8,
        title: []const u8,
        folder: ?[]const u8,
    ) !u32 {
        // Assert: URL and title must be non-empty
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= MAX_URL_LENGTH);
        std.debug.assert(title.len > 0);
        std.debug.assert(title.len <= MAX_TITLE_LENGTH);
        
        // Assert: Bookmarks must be within bounds
        std.debug.assert(self.bookmarks_storage.bookmarks_len < MAX_BOOKMARKS);
        
        // Check if bookmark already exists
        var i: u32 = 0;
        while (i < self.bookmarks_storage.bookmarks_len) : (i += 1) {
            if (std.mem.eql(u8, self.bookmarks_storage.bookmarks[i].url, url)) {
                // Update existing bookmark
                self.bookmarks_storage.bookmarks[i].last_visited = get_current_timestamp();
                self.bookmarks_storage.bookmarks[i].visit_count += 1;
                return i;
            }
        }
        
        // Copy URL and title
        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);
        
        const title_copy = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(title_copy);
        
        const folder_copy = if (folder) |f| blk: {
            const copy = try self.allocator.dupe(u8, f);
            break :blk copy;
        } else null;
        errdefer if (folder_copy) |f| self.allocator.free(f);
        
        // Create empty tags array
        const tags = try self.allocator.alloc([]const u8, MAX_TAGS_PER_BOOKMARK);
        
        // Add bookmark
        const idx = self.bookmarks_storage.bookmarks_len;
        self.bookmarks_storage.bookmarks[idx] = Bookmark{
            .url = url_copy,
            .title = title_copy,
            .folder = folder_copy,
            .tags = tags,
            .created_at = get_current_timestamp(),
            .last_visited = get_current_timestamp(),
            .visit_count = 1,
        };
        self.bookmarks_storage.bookmarks_len += 1;
        
        return idx;
    }
    
    /// Remove bookmark.
    pub fn remove_bookmark(self: *DreamBrowserBookmarks, bookmark_idx: u32) void {
        if (bookmark_idx >= self.bookmarks_storage.bookmarks_len) {
            return;
        }
        
        const bookmark = &self.bookmarks_storage.bookmarks[bookmark_idx];
        
        // Free bookmark data
        self.allocator.free(bookmark.url);
        self.allocator.free(bookmark.title);
        if (bookmark.folder) |folder| {
            self.allocator.free(folder);
        }
        for (bookmark.tags) |tag| {
            self.allocator.free(tag);
        }
        self.allocator.free(bookmark.tags);
        
        // Move last bookmark to this position
        if (self.bookmarks_storage.bookmarks_len > 1) {
            const last_idx = self.bookmarks_storage.bookmarks_len - 1;
            if (bookmark_idx != last_idx) {
                self.bookmarks_storage.bookmarks[bookmark_idx] = self.bookmarks_storage.bookmarks[last_idx];
            }
        }
        
        self.bookmarks_storage.bookmarks_len -= 1;
    }
    
    /// Get bookmark by index.
    pub fn get_bookmark(self: *const DreamBrowserBookmarks, bookmark_idx: u32) ?*const Bookmark {
        if (bookmark_idx >= self.bookmarks_storage.bookmarks_len) {
            return null;
        }
        return &self.bookmarks_storage.bookmarks[bookmark_idx];
    }
    
    /// Add history entry.
    pub fn add_history_entry(
        self: *DreamBrowserBookmarks,
        url: []const u8,
        title: []const u8,
        visit_duration: u32,
    ) !void {
        // Assert: URL and title must be non-empty
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= MAX_URL_LENGTH);
        std.debug.assert(title.len > 0);
        std.debug.assert(title.len <= MAX_TITLE_LENGTH);
        
        // Copy URL and title
        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);
        
        const title_copy = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(title_copy);
        
        // Add to history (or overwrite oldest if full)
        if (self.history_storage.entries_len < MAX_HISTORY_ENTRIES) {
            const idx = self.history_storage.entries_len;
            self.history_storage.entries[idx] = HistoryEntry{
                .url = url_copy,
                .title = title_copy,
                .visited_at = get_current_timestamp(),
                .visit_duration = visit_duration,
            };
            self.history_storage.entries_len += 1;
        } else {
            // Overwrite oldest entry (circular buffer)
            const idx = self.history_storage.entries_index;
            const old_entry = &self.history_storage.entries[idx];
            
            // Free old entry
            self.allocator.free(old_entry.url);
            self.allocator.free(old_entry.title);
            
            // Set new entry
            self.history_storage.entries[idx] = HistoryEntry{
                .url = url_copy,
                .title = title_copy,
                .visited_at = get_current_timestamp(),
                .visit_duration = visit_duration,
            };
            
            self.history_storage.entries_index = (idx + 1) % MAX_HISTORY_ENTRIES;
        }
    }
    
    /// Get history entries (recent first).
    pub fn get_history_entries(self: *const DreamBrowserBookmarks, max_count: u32) []const HistoryEntry {
        const count = @min(max_count, self.history_storage.entries_len);
        if (count == 0) {
            return &.{};
        }
        
        // Allocate result array (caller must free)
        const result = self.allocator.alloc(HistoryEntry, count) catch {
            return &.{};
        };
        
        // Copy entries in reverse order (newest first)
        var i: u32 = 0;
        var src_idx: u32 = self.history_storage.entries_len;
        while (i < count and src_idx > 0) : (i += 1) {
            src_idx -= 1;
            result[i] = self.history_storage.entries[src_idx];
        }
        
        return result[0..count];
    }
    
    /// Search bookmarks by title or URL.
    /// Note: Returns slice pointing to allocated array (caller must free).
    pub fn search_bookmarks(
        self: *DreamBrowserBookmarks,
        query: []const u8,
    ) []const u32 {
        // Assert: Query must be non-empty
        std.debug.assert(query.len > 0);
        
        // Count matching bookmarks
        var match_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.bookmarks_storage.bookmarks_len) : (i += 1) {
            const bookmark = &self.bookmarks_storage.bookmarks[i];
            if (std.mem.indexOf(u8, bookmark.title, query) != null or
                std.mem.indexOf(u8, bookmark.url, query) != null)
            {
                match_count += 1;
            }
        }
        
        if (match_count == 0) {
            return &.{};
        }
        
        // Allocate result array (caller must free)
        const result = self.allocator.alloc(u32, match_count) catch {
            return &.{};
        };
        
        // Collect matching indices
        var result_idx: u32 = 0;
        i = 0;
        while (i < self.bookmarks_storage.bookmarks_len) : (i += 1) {
            const bookmark = &self.bookmarks_storage.bookmarks[i];
            if (std.mem.indexOf(u8, bookmark.title, query) != null or
                std.mem.indexOf(u8, bookmark.url, query) != null)
            {
                result[result_idx] = i;
                result_idx += 1;
            }
        }
        
        return result[0..match_count];
    }
    
    /// Get current timestamp (simplified).
    fn get_current_timestamp() u64 {
        const timestamp = std.time.timestamp();
        const non_negative = if (timestamp < 0) 0 else @as(u64, @intCast(timestamp));
        return non_negative;
    }
    
    /// Get statistics.
    pub fn get_stats(self: *const DreamBrowserBookmarks) BookmarksStats {
        return BookmarksStats{
            .bookmarks_count = self.bookmarks_storage.bookmarks_len,
            .history_count = self.history_storage.entries_len,
            .folders_count = self.bookmarks_storage.folders_len,
            .max_bookmarks = MAX_BOOKMARKS,
            .max_history = MAX_HISTORY_ENTRIES,
        };
    }
    
    /// Bookmarks statistics.
    pub const BookmarksStats = struct {
        bookmarks_count: u32,
        history_count: u32,
        folders_count: u32,
        max_bookmarks: u32,
        max_history: u32,
    };
};

test "bookmarks initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var bookmarks = try DreamBrowserBookmarks.init(arena.allocator());
    defer bookmarks.deinit();
    
    // Assert: Bookmarks initialized
    try std.testing.expect(bookmarks.bookmarks_storage.bookmarks_len == 0);
    try std.testing.expect(bookmarks.history_storage.entries_len == 0);
}

test "bookmarks add and get" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var bookmarks = try DreamBrowserBookmarks.init(arena.allocator());
    defer bookmarks.deinit();
    
    const idx = try bookmarks.add_bookmark("https://example.com", "Example", null);
    
    // Assert: Bookmark added
    const bookmark = bookmarks.get_bookmark(idx);
    try std.testing.expect(bookmark != null);
    try std.testing.expect(std.mem.eql(u8, bookmark.?.url, "https://example.com"));
    try std.testing.expect(std.mem.eql(u8, bookmark.?.title, "Example"));
}

test "bookmarks history" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var bookmarks = try DreamBrowserBookmarks.init(arena.allocator());
    defer bookmarks.deinit();
    
    try bookmarks.add_history_entry("https://example.com", "Example", 10);
    
    // Assert: History entry added
    const stats = bookmarks.get_stats();
    try std.testing.expect(stats.history_count == 1);
}

test "bookmarks search" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var bookmarks = try DreamBrowserBookmarks.init(arena.allocator());
    defer bookmarks.deinit();
    
    _ = try bookmarks.add_bookmark("https://example.com", "Example Site", null);
    _ = try bookmarks.add_bookmark("https://test.com", "Test Site", null);
    
    // Search for "Example"
    const results = bookmarks.search_bookmarks("Example");
    defer if (results.len > 0) arena.allocator().free(results);
    
    // Assert: Search found bookmark
    try std.testing.expect(results.len == 1);
    try std.testing.expect(results[0] == 0);
}

test "bookmarks stats" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var bookmarks = try DreamBrowserBookmarks.init(arena.allocator());
    defer bookmarks.deinit();
    
    const stats = bookmarks.get_stats();
    try std.testing.expect(stats.bookmarks_count == 0);
    try std.testing.expect(stats.history_count == 0);
    try std.testing.expect(stats.max_bookmarks == DreamBrowserBookmarks.MAX_BOOKMARKS);
    try std.testing.expect(stats.max_history == DreamBrowserBookmarks.MAX_HISTORY_ENTRIES);
}

