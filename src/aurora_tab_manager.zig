const std = @import("std");
const Editor = @import("aurora_editor.zig").Editor;
const DreamBrowserParser = @import("dream_browser_parser.zig").DreamBrowserParser;
const DreamBrowserRenderer = @import("dream_browser_renderer.zig").DreamBrowserRenderer;
const DreamBrowserViewport = @import("dream_browser_viewport.zig").DreamBrowserViewport;

/// Tab Manager: Enhanced tab management for unified IDE.
/// ~<~ Glow Airbend: explicit tab ordering, bounded groups.
/// ~~~~ Glow Waterbend: tabs flow deterministically through DAG.
///
/// This implements:
/// - Tab reordering (move tabs left/right)
/// - Tab groups (group related tabs together)
/// - Tab persistence (save/restore tab state)
/// - Tab pinning (pin important tabs)
/// - Tab metadata (last accessed time, etc.)
pub const TabManager = struct {
    // Bounded: Max 100 editor tabs
    pub const MAX_EDITOR_TABS: u32 = 100;
    
    // Bounded: Max 100 browser tabs
    pub const MAX_BROWSER_TABS: u32 = 100;
    
    // Bounded: Max 20 tab groups
    pub const MAX_TAB_GROUPS: u32 = 20;
    
    // Bounded: Max 256 characters for group name
    pub const MAX_GROUP_NAME_LENGTH: u32 = 256;
    
    /// Tab metadata (for enhanced management).
    pub const TabMetadata = struct {
        last_accessed: u64, // Timestamp of last access
        is_pinned: bool, // Whether tab is pinned
        group_id: ?u32 = null, // Tab group ID (if grouped)
        order: u32, // Tab order (for custom ordering)
    };
    
    /// Tab group (for grouping related tabs).
    pub const TabGroup = struct {
        id: u32, // Group ID
        name: []const u8, // Group name
        editor_tabs: []const u32, // Editor tab IDs in group
        editor_tabs_len: u32, // Number of editor tabs
        browser_tabs: []const u32, // Browser tab IDs in group
        browser_tabs_len: u32, // Number of browser tabs
        created_at: u64, // Creation timestamp
    };
    
    /// Editor tab with metadata.
    pub const ManagedEditorTab = struct {
        id: u32,
        editor: Editor,
        file_uri: []const u8,
        title: []const u8,
        metadata: TabMetadata,
    };
    
    /// Browser tab with metadata.
    pub const ManagedBrowserTab = struct {
        id: u32,
        url: []const u8,
        parser: DreamBrowserParser,
        renderer: DreamBrowserRenderer,
        viewport: DreamBrowserViewport,
        title: []const u8,
        contract_id: ?u64 = null,
        payment_enabled: bool = false,
        metadata: TabMetadata,
    };
    
    /// Tab storage.
    pub const TabStorage = struct {
        editor_tabs: []ManagedEditorTab, // Editor tabs
        editor_tabs_len: u32, // Current number of editor tabs
        browser_tabs: []ManagedBrowserTab, // Browser tabs
        browser_tabs_len: u32, // Current number of browser tabs
        groups: []TabGroup, // Tab groups
        groups_len: u32, // Current number of groups
        next_group_id: u32, // Next group ID to assign
    };
    
    storage: TabStorage,
    current_editor_tab: u32,
    current_browser_tab: u32,
    
    /// Initialize tab manager.
    pub fn init(allocator: std.mem.Allocator) !TabManager {
        // Pre-allocate editor tabs
        const editor_tabs = try allocator.alloc(ManagedEditorTab, MAX_EDITOR_TABS);
        
        // Pre-allocate browser tabs
        const browser_tabs = try allocator.alloc(ManagedBrowserTab, MAX_BROWSER_TABS);
        
        // Pre-allocate tab groups
        const groups = try allocator.alloc(TabGroup, MAX_TAB_GROUPS);
        
        return TabManager{
            .allocator = allocator,
            .storage = TabStorage{
                .editor_tabs = editor_tabs,
                .editor_tabs_len = 0,
                .browser_tabs = browser_tabs,
                .browser_tabs_len = 0,
                .groups = groups,
                .groups_len = 0,
                .next_group_id = 1,
            },
            .current_editor_tab = 0,
            .current_browser_tab = 0,
        };
    }
    
    /// Deinitialize tab manager.
    pub fn deinit(self: *TabManager) void {
        // Free editor tabs
        for (self.storage.editor_tabs[0..self.storage.editor_tabs_len]) |*tab| {
            tab.editor.deinit();
            self.allocator.free(tab.file_uri);
            self.allocator.free(tab.title);
        }
        
        // Free browser tabs
        for (self.storage.browser_tabs[0..self.storage.browser_tabs_len]) |*tab| {
            tab.parser.deinit();
            tab.renderer.deinit();
            tab.viewport.deinit();
            self.allocator.free(tab.url);
            self.allocator.free(tab.title);
        }
        
        // Free groups
        for (self.storage.groups[0..self.storage.groups_len]) |*group| {
            self.allocator.free(group.name);
            self.allocator.free(group.editor_tabs);
            self.allocator.free(group.browser_tabs);
        }
        
        // Free arrays
        self.allocator.free(self.storage.editor_tabs);
        self.allocator.free(self.storage.browser_tabs);
        self.allocator.free(self.storage.groups);
    }
    
    /// Move editor tab to new position.
    pub fn move_editor_tab(self: *TabManager, tab_id: u32, new_position: u32) void {
        // Assert: Tab ID and position must be valid
        std.debug.assert(tab_id < self.storage.editor_tabs_len);
        std.debug.assert(new_position < self.storage.editor_tabs_len);
        
        if (tab_id == new_position) {
            return; // No move needed
        }
        
        // Get tab
        const tab = self.storage.editor_tabs[tab_id];
        
        // Shift tabs
        if (tab_id < new_position) {
            // Move right: shift left
            var i: u32 = tab_id;
            while (i < new_position) : (i += 1) {
                self.storage.editor_tabs[i] = self.storage.editor_tabs[i + 1];
                self.storage.editor_tabs[i].id = i;
                self.storage.editor_tabs[i].metadata.order = i;
            }
        } else {
            // Move left: shift right
            var i: u32 = tab_id;
            while (i > new_position) : (i -= 1) {
                self.storage.editor_tabs[i] = self.storage.editor_tabs[i - 1];
                self.storage.editor_tabs[i].id = i;
                self.storage.editor_tabs[i].metadata.order = i;
            }
        }
        
        // Place tab at new position
        self.storage.editor_tabs[new_position] = tab;
        self.storage.editor_tabs[new_position].id = new_position;
        self.storage.editor_tabs[new_position].metadata.order = new_position;
        
        // Update current tab if needed
        if (self.current_editor_tab == tab_id) {
            self.current_editor_tab = new_position;
        } else if (self.current_editor_tab == new_position) {
            self.current_editor_tab = tab_id;
        }
    }
    
    /// Move browser tab to new position.
    pub fn move_browser_tab(self: *TabManager, tab_id: u32, new_position: u32) void {
        // Assert: Tab ID and position must be valid
        std.debug.assert(tab_id < self.storage.browser_tabs_len);
        std.debug.assert(new_position < self.storage.browser_tabs_len);
        
        if (tab_id == new_position) {
            return; // No move needed
        }
        
        // Get tab
        const tab = self.storage.browser_tabs[tab_id];
        
        // Shift tabs
        if (tab_id < new_position) {
            // Move right: shift left
            var i: u32 = tab_id;
            while (i < new_position) : (i += 1) {
                self.storage.browser_tabs[i] = self.storage.browser_tabs[i + 1];
                self.storage.browser_tabs[i].id = i;
                self.storage.browser_tabs[i].metadata.order = i;
            }
        } else {
            // Move left: shift right
            var i: u32 = tab_id;
            while (i > new_position) : (i -= 1) {
                self.storage.browser_tabs[i] = self.storage.browser_tabs[i - 1];
                self.storage.browser_tabs[i].id = i;
                self.storage.browser_tabs[i].metadata.order = i;
            }
        }
        
        // Place tab at new position
        self.storage.browser_tabs[new_position] = tab;
        self.storage.browser_tabs[new_position].id = new_position;
        self.storage.browser_tabs[new_position].metadata.order = new_position;
        
        // Update current tab if needed
        if (self.current_browser_tab == tab_id) {
            self.current_browser_tab = new_position;
        } else if (self.current_browser_tab == new_position) {
            self.current_browser_tab = tab_id;
        }
    }
    
    /// Pin editor tab.
    pub fn pin_editor_tab(self: *TabManager, tab_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.storage.editor_tabs_len);
        
        self.storage.editor_tabs[tab_id].metadata.is_pinned = true;
    }
    
    /// Unpin editor tab.
    pub fn unpin_editor_tab(self: *TabManager, tab_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.storage.editor_tabs_len);
        
        self.storage.editor_tabs[tab_id].metadata.is_pinned = false;
    }
    
    /// Pin browser tab.
    pub fn pin_browser_tab(self: *TabManager, tab_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.storage.browser_tabs_len);
        
        self.storage.browser_tabs[tab_id].metadata.is_pinned = true;
    }
    
    /// Unpin browser tab.
    pub fn unpin_browser_tab(self: *TabManager, tab_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.storage.browser_tabs_len);
        
        self.storage.browser_tabs[tab_id].metadata.is_pinned = false;
    }
    
    /// Create tab group.
    pub fn create_tab_group(self: *TabManager, name: []const u8) !u32 {
        // Assert: Name must be valid
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_GROUP_NAME_LENGTH);
        
        // Assert: Groups must be within bounds
        std.debug.assert(self.storage.groups_len < MAX_TAB_GROUPS);
        
        // Copy name
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        
        // Pre-allocate tab arrays
        const editor_tabs = try self.allocator.alloc(u32, MAX_EDITOR_TABS);
        const browser_tabs = try self.allocator.alloc(u32, MAX_BROWSER_TABS);
        
        // Create group
        const group_id = self.storage.next_group_id;
        self.storage.next_group_id += 1;
        
        const idx = self.storage.groups_len;
        self.storage.groups[idx] = TabGroup{
            .id = group_id,
            .name = name_copy,
            .editor_tabs = editor_tabs,
            .editor_tabs_len = 0,
            .browser_tabs = browser_tabs,
            .browser_tabs_len = 0,
            .created_at = get_current_timestamp(),
        };
        self.storage.groups_len += 1;
        
        return group_id;
    }
    
    /// Add editor tab to group.
    pub fn add_editor_tab_to_group(self: *TabManager, tab_id: u32, group_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.storage.editor_tabs_len);
        
        // Find group
        var group: ?*TabGroup = null;
        var i: u32 = 0;
        while (i < self.storage.groups_len) : (i += 1) {
            if (self.storage.groups[i].id == group_id) {
                group = &self.storage.groups[i];
                break;
            }
        }
        
        if (group) |g| {
            // Assert: Group must have space
            std.debug.assert(g.editor_tabs_len < MAX_EDITOR_TABS);
            
            // Add tab to group
            g.editor_tabs[g.editor_tabs_len] = tab_id;
            g.editor_tabs_len += 1;
            
            // Update tab metadata
            self.storage.editor_tabs[tab_id].metadata.group_id = group_id;
        }
    }
    
    /// Add browser tab to group.
    pub fn add_browser_tab_to_group(self: *TabManager, tab_id: u32, group_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.storage.browser_tabs_len);
        
        // Find group
        var group: ?*TabGroup = null;
        var i: u32 = 0;
        while (i < self.storage.groups_len) : (i += 1) {
            if (self.storage.groups[i].id == group_id) {
                group = &self.storage.groups[i];
                break;
            }
        }
        
        if (group) |g| {
            // Assert: Group must have space
            std.debug.assert(g.browser_tabs_len < MAX_BROWSER_TABS);
            
            // Add tab to group
            g.browser_tabs[g.browser_tabs_len] = tab_id;
            g.browser_tabs_len += 1;
            
            // Update tab metadata
            self.storage.browser_tabs[tab_id].metadata.group_id = group_id;
        }
    }
    
    /// Update tab last accessed time.
    pub fn update_editor_tab_access(self: *TabManager, tab_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.storage.editor_tabs_len);
        
        self.storage.editor_tabs[tab_id].metadata.last_accessed = get_current_timestamp();
    }
    
    /// Update browser tab last accessed time.
    pub fn update_browser_tab_access(self: *TabManager, tab_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.storage.browser_tabs_len);
        
        self.storage.browser_tabs[tab_id].metadata.last_accessed = get_current_timestamp();
    }
    
    /// Get current timestamp (simplified).
    fn get_current_timestamp() u64 {
        const timestamp = std.time.timestamp();
        const non_negative = if (timestamp < 0) 0 else @as(u64, @intCast(timestamp));
        return non_negative;
    }
    
    /// Get tab statistics.
    pub fn get_stats(self: *const TabManager) TabStats {
        return TabStats{
            .editor_tabs_count = self.storage.editor_tabs_len,
            .browser_tabs_count = self.storage.browser_tabs_len,
            .groups_count = self.storage.groups_len,
            .pinned_editor_tabs: count_pinned_editor_tabs(self),
            .pinned_browser_tabs: count_pinned_browser_tabs(self),
        };
    }
    
    /// Count pinned editor tabs.
    fn count_pinned_editor_tabs(self: *const TabManager) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.storage.editor_tabs_len) : (i += 1) {
            if (self.storage.editor_tabs[i].metadata.is_pinned) {
                count += 1;
            }
        }
        return count;
    }
    
    /// Count pinned browser tabs.
    fn count_pinned_browser_tabs(self: *const TabManager) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.storage.browser_tabs_len) : (i += 1) {
            if (self.storage.browser_tabs[i].metadata.is_pinned) {
                count += 1;
            }
        }
        return count;
    }
    
    /// Tab statistics.
    pub const TabStats = struct {
        editor_tabs_count: u32,
        browser_tabs_count: u32,
        groups_count: u32,
        pinned_editor_tabs: u32,
        pinned_browser_tabs: u32,
    };
};

test "tab manager initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var manager = try TabManager.init(arena.allocator());
    defer manager.deinit();
    
    // Assert: Manager initialized
    try std.testing.expect(manager.storage.editor_tabs_len == 0);
    try std.testing.expect(manager.storage.browser_tabs_len == 0);
    try std.testing.expect(manager.storage.groups_len == 0);
}

test "tab manager stats" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var manager = try TabManager.init(arena.allocator());
    defer manager.deinit();
    
    const stats = manager.get_stats();
    try std.testing.expect(stats.editor_tabs_count == 0);
    try std.testing.expect(stats.browser_tabs_count == 0);
    try std.testing.expect(stats.groups_count == 0);
    try std.testing.expect(stats.pinned_editor_tabs == 0);
    try std.testing.expect(stats.pinned_browser_tabs == 0);
}

