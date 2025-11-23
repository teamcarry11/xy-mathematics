const std = @import("std");
const DreamBrowserRenderer = @import("dream_browser_renderer.zig").DreamBrowserRenderer;

/// Dream Browser Viewport: Scrolling, navigation, and viewport management.
/// ~<~ Glow Airbend: explicit viewport state, bounded scrolling.
/// ~~~~ Glow Waterbend: viewport flows deterministically through DAG.
///
/// This implements:
/// - Viewport state (scroll position, dimensions)
/// - Scrolling (vertical, horizontal, smooth)
/// - Navigation (back, forward, history)
/// - Bounds checking (prevent out-of-bounds scrolling)
pub const DreamBrowserViewport = struct {
    // Bounded: Max 1,000,000 pixels scroll position
    pub const MAX_SCROLL_POSITION: u32 = 1_000_000;
    
    // Bounded: Max 10,000 pixels viewport dimensions
    pub const MAX_VIEWPORT_DIMENSION: u32 = 10_000;
    
    // Bounded: Max 100 history entries
    pub const MAX_HISTORY_ENTRIES: u32 = 100;
    
    /// Viewport state (scroll position and dimensions).
    pub const ViewportState = struct {
        scroll_x: u32, // Horizontal scroll position
        scroll_y: u32, // Vertical scroll position
        viewport_width: u32, // Viewport width
        viewport_height: u32, // Viewport height
        content_width: u32, // Total content width
        content_height: u32, // Total content height
    };
    
    /// History entry (for back/forward navigation).
    pub const HistoryEntry = struct {
        url: []const u8, // URL or Nostr event ID
        scroll_x: u32, // Scroll position when navigating away
        scroll_y: u32, // Scroll position when navigating away
        timestamp: u64, // Timestamp of navigation
    };
    
    /// Navigation history (back/forward stack).
    pub const NavigationHistory = struct {
        entries: []HistoryEntry, // History entries
        entries_len: u32, // Current number of entries
        current_index: u32, // Current position in history
    };
    
    allocator: std.mem.Allocator,
    viewport_state: ViewportState,
    history: NavigationHistory,
    
    /// Initialize viewport.
    pub fn init(allocator: std.mem.Allocator) DreamBrowserViewport {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        // Initialize viewport state
        const initial_state = ViewportState{
            .scroll_x = 0,
            .scroll_y = 0,
            .viewport_width = 800, // Default viewport width
            .viewport_height = 600, // Default viewport height
            .content_width = 0, // Will be set when content is loaded
            .content_height = 0, // Will be set when content is loaded
        };
        
        // Initialize history
        const history_entries = allocator.alloc(HistoryEntry, MAX_HISTORY_ENTRIES) catch {
            // Fallback: empty history if allocation fails
            return DreamBrowserViewport{
                .allocator = allocator,
                .viewport_state = initial_state,
                .history = NavigationHistory{
                    .entries = &.{},
                    .entries_len = 0,
                    .current_index = 0,
                },
            };
        };
        
        return DreamBrowserViewport{
            .allocator = allocator,
            .viewport_state = initial_state,
            .history = NavigationHistory{
                .entries = history_entries,
                .entries_len = 0,
                .current_index = 0,
            },
        };
    }
    
    /// Deinitialize viewport.
    pub fn deinit(self: *DreamBrowserViewport) void {
        // Free history entries
        if (self.history.entries.len > 0) {
            // Free URL strings in history entries
            for (self.history.entries[0..self.history.entries_len]) |entry| {
                self.allocator.free(entry.url);
            }
            self.allocator.free(self.history.entries);
        }
    }
    
    /// Set viewport dimensions.
    pub fn set_viewport_size(
        self: *DreamBrowserViewport,
        width: u32,
        height: u32,
    ) void {
        // Assert: Dimensions must be within bounds
        std.debug.assert(width <= MAX_VIEWPORT_DIMENSION);
        std.debug.assert(height <= MAX_VIEWPORT_DIMENSION);
        
        // Assert: Dimensions must be non-zero
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        
        self.viewport_state.viewport_width = width;
        self.viewport_state.viewport_height = height;
        
        // Clamp scroll position to new viewport bounds
        self.clamp_scroll_position();
    }
    
    /// Set content dimensions (total scrollable area).
    pub fn set_content_size(
        self: *DreamBrowserViewport,
        width: u32,
        height: u32,
    ) void {
        // Assert: Dimensions must be within bounds
        std.debug.assert(width <= MAX_VIEWPORT_DIMENSION);
        std.debug.assert(height <= MAX_VIEWPORT_DIMENSION);
        
        self.viewport_state.content_width = width;
        self.viewport_state.content_height = height;
        
        // Clamp scroll position to new content bounds
        self.clamp_scroll_position();
    }
    
    /// Clamp scroll position to valid bounds.
    fn clamp_scroll_position(self: *DreamBrowserViewport) void {
        // Calculate maximum scroll positions
        const max_scroll_x = if (self.viewport_state.content_width > self.viewport_state.viewport_width)
            self.viewport_state.content_width - self.viewport_state.viewport_width
        else
            0;
        
        const max_scroll_y = if (self.viewport_state.content_height > self.viewport_state.viewport_height)
            self.viewport_state.content_height - self.viewport_state.viewport_height
        else
            0;
        
        // Clamp scroll positions
        if (self.viewport_state.scroll_x > max_scroll_x) {
            self.viewport_state.scroll_x = max_scroll_x;
        }
        if (self.viewport_state.scroll_y > max_scroll_y) {
            self.viewport_state.scroll_y = max_scroll_y;
        }
        
        // Assert: Scroll positions must be within bounds
        std.debug.assert(self.viewport_state.scroll_x <= MAX_SCROLL_POSITION);
        std.debug.assert(self.viewport_state.scroll_y <= MAX_SCROLL_POSITION);
    }
    
    /// Scroll viewport by delta (relative scrolling).
    pub fn scroll_by(
        self: *DreamBrowserViewport,
        delta_x: i32,
        delta_y: i32,
    ) void {
        // Calculate new scroll positions
        const new_scroll_x = if (delta_x < 0)
            if (@as(u32, @intCast(-delta_x)) > self.viewport_state.scroll_x)
                0
            else
                self.viewport_state.scroll_x - @as(u32, @intCast(-delta_x))
        else
            self.viewport_state.scroll_x + @as(u32, @intCast(delta_x));
        
        const new_scroll_y = if (delta_y < 0)
            if (@as(u32, @intCast(-delta_y)) > self.viewport_state.scroll_y)
                0
            else
                self.viewport_state.scroll_y - @as(u32, @intCast(-delta_y))
        else
            self.viewport_state.scroll_y + @as(u32, @intCast(delta_y));
        
        // Set new scroll positions
        self.viewport_state.scroll_x = new_scroll_x;
        self.viewport_state.scroll_y = new_scroll_y;
        
        // Clamp to valid bounds
        self.clamp_scroll_position();
    }
    
    /// Scroll viewport to absolute position.
    pub fn scroll_to(
        self: *DreamBrowserViewport,
        x: u32,
        y: u32,
    ) void {
        // Assert: Scroll positions must be within bounds
        std.debug.assert(x <= MAX_SCROLL_POSITION);
        std.debug.assert(y <= MAX_SCROLL_POSITION);
        
        self.viewport_state.scroll_x = x;
        self.viewport_state.scroll_y = y;
        
        // Clamp to valid bounds
        self.clamp_scroll_position();
    }
    
    /// Get current viewport state.
    pub fn get_viewport_state(self: *const DreamBrowserViewport) ViewportState {
        return self.viewport_state;
    }
    
    /// Check if scrolling is possible in a direction.
    pub fn can_scroll_up(self: *const DreamBrowserViewport) bool {
        return self.viewport_state.scroll_y > 0;
    }
    
    pub fn can_scroll_down(self: *const DreamBrowserViewport) bool {
        const max_scroll_y = if (self.viewport_state.content_height > self.viewport_state.viewport_height)
            self.viewport_state.content_height - self.viewport_state.viewport_height
        else
            0;
        return self.viewport_state.scroll_y < max_scroll_y;
    }
    
    pub fn can_scroll_left(self: *const DreamBrowserViewport) bool {
        return self.viewport_state.scroll_x > 0;
    }
    
    pub fn can_scroll_right(self: *const DreamBrowserViewport) bool {
        const max_scroll_x = if (self.viewport_state.content_width > self.viewport_state.viewport_width)
            self.viewport_state.content_width - self.viewport_state.viewport_width
        else
            0;
        return self.viewport_state.scroll_x < max_scroll_x;
    }
    
    /// Add entry to navigation history.
    pub fn add_history_entry(
        self: *DreamBrowserViewport,
        url: []const u8,
    ) !void {
        // Assert: URL must be non-empty
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= 4096); // Bounded URL length
        
        // Assert: History must not exceed bounds
        std.debug.assert(self.history.entries_len < MAX_HISTORY_ENTRIES);
        
        // Save current scroll position before navigating
        const current_scroll_x = self.viewport_state.scroll_x;
        const current_scroll_y = self.viewport_state.scroll_y;
        
        // Get current timestamp (non-negative)
        const timestamp_raw = std.time.timestamp();
        const timestamp = @as(u64, @intCast(@max(timestamp_raw, 0)));
        
        // If we're not at the end of history, truncate future entries
        if (self.history.current_index < self.history.entries_len) {
            // Free URLs of truncated entries
            for (self.history.entries[self.history.current_index..self.history.entries_len]) |entry| {
                self.allocator.free(entry.url);
            }
            self.history.entries_len = self.history.current_index;
        }
        
        // Add new entry
        if (self.history.entries_len < MAX_HISTORY_ENTRIES) {
            const url_copy = try self.allocator.dupe(u8, url);
            self.history.entries[self.history.entries_len] = HistoryEntry{
                .url = url_copy,
                .scroll_x = current_scroll_x,
                .scroll_y = current_scroll_y,
                .timestamp = timestamp,
            };
            self.history.entries_len += 1;
            self.history.current_index = self.history.entries_len;
        }
        
        // Assert: History state must be valid
        std.debug.assert(self.history.entries_len <= MAX_HISTORY_ENTRIES);
        std.debug.assert(self.history.current_index <= self.history.entries_len);
    }
    
    /// Navigate back in history.
    pub fn navigate_back(self: *DreamBrowserViewport) !?[]const u8 {
        // Assert: Must have history to navigate back
        if (self.history.current_index == 0) {
            return null; // No history to navigate back
        }
        
        // Decrement current index
        self.history.current_index -= 1;
        
        // Get history entry
        const entry = &self.history.entries[self.history.current_index];
        
        // Restore scroll position
        self.viewport_state.scroll_x = entry.scroll_x;
        self.viewport_state.scroll_y = entry.scroll_y;
        
        // Clamp scroll position
        self.clamp_scroll_position();
        
        return entry.url;
    }
    
    /// Navigate forward in history.
    pub fn navigate_forward(self: *DreamBrowserViewport) !?[]const u8 {
        // Assert: Must have future history to navigate forward
        if (self.history.current_index >= self.history.entries_len - 1) {
            return null; // No future history to navigate forward
        }
        
        // Increment current index
        self.history.current_index += 1;
        
        // Get history entry
        const entry = &self.history.entries[self.history.current_index];
        
        // Restore scroll position
        self.viewport_state.scroll_x = entry.scroll_x;
        self.viewport_state.scroll_y = entry.scroll_y;
        
        // Clamp scroll position
        self.clamp_scroll_position();
        
        return entry.url;
    }
    
    /// Check if back navigation is possible.
    pub fn can_navigate_back(self: *const DreamBrowserViewport) bool {
        return self.history.current_index > 0;
    }
    
    /// Check if forward navigation is possible.
    pub fn can_navigate_forward(self: *const DreamBrowserViewport) bool {
        return self.history.current_index < self.history.entries_len - 1;
    }
    
    /// Get current URL from history.
    pub fn get_current_url(self: *const DreamBrowserViewport) ?[]const u8 {
        if (self.history.entries_len == 0) {
            return null;
        }
        if (self.history.current_index >= self.history.entries_len) {
            return null;
        }
        return self.history.entries[self.history.current_index].url;
    }
};

test "viewport initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var viewport = DreamBrowserViewport.init(arena.allocator());
    defer viewport.deinit();
    
    // Assert: Viewport initialized
    try std.testing.expect(viewport.viewport_state.viewport_width > 0);
    try std.testing.expect(viewport.viewport_state.viewport_height > 0);
}

test "viewport set size" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var viewport = DreamBrowserViewport.init(arena.allocator());
    defer viewport.deinit();
    
    viewport.set_viewport_size(1024, 768);
    
    // Assert: Viewport size set correctly
    try std.testing.expect(viewport.viewport_state.viewport_width == 1024);
    try std.testing.expect(viewport.viewport_state.viewport_height == 768);
}

test "viewport scroll by" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var viewport = DreamBrowserViewport.init(arena.allocator());
    defer viewport.deinit();
    
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(1600, 1200);
    
    viewport.scroll_by(100, 200);
    
    // Assert: Scroll position updated
    try std.testing.expect(viewport.viewport_state.scroll_x == 100);
    try std.testing.expect(viewport.viewport_state.scroll_y == 200);
}

test "viewport scroll bounds" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var viewport = DreamBrowserViewport.init(arena.allocator());
    defer viewport.deinit();
    
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(1600, 1200);
    
    // Scroll beyond bounds
    viewport.scroll_by(2000, 2000);
    
    // Assert: Scroll position clamped to bounds
    try std.testing.expect(viewport.viewport_state.scroll_x == 800); // max: 1600 - 800
    try std.testing.expect(viewport.viewport_state.scroll_y == 600); // max: 1200 - 600
}

test "viewport navigation history" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var viewport = DreamBrowserViewport.init(arena.allocator());
    defer viewport.deinit();
    
    // Add history entries
    try viewport.add_history_entry("nostr:note1abc");
    try viewport.add_history_entry("nostr:note2def");
    
    // Assert: History entries added
    try std.testing.expect(viewport.history.entries_len == 2);
    try std.testing.expect(viewport.history.current_index == 2);
    
    // Navigate back
    const back_url = try viewport.navigate_back();
    
    // Assert: Navigated back
    try std.testing.expect(back_url != null);
    try std.testing.expect(std.mem.eql(u8, back_url.?, "nostr:note1abc"));
    try std.testing.expect(viewport.history.current_index == 1);
}

test "viewport can scroll" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var viewport = DreamBrowserViewport.init(arena.allocator());
    defer viewport.deinit();
    
    viewport.set_viewport_size(800, 600);
    viewport.set_content_size(1600, 1200);
    
    // Assert: Can scroll down and right initially
    try std.testing.expect(!viewport.can_scroll_up());
    try std.testing.expect(viewport.can_scroll_down());
    try std.testing.expect(!viewport.can_scroll_left());
    try std.testing.expect(viewport.can_scroll_right());
    
    // Scroll to bottom-right
    viewport.scroll_to(800, 600);
    
    // Assert: Can scroll up and left at bottom-right
    try std.testing.expect(viewport.can_scroll_up());
    try std.testing.expect(!viewport.can_scroll_down());
    try std.testing.expect(viewport.can_scroll_left());
    try std.testing.expect(!viewport.can_scroll_right());
}

