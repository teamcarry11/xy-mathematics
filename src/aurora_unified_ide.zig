const std = @import("std");
const Editor = @import("aurora_editor.zig").Editor;
const Layout = @import("aurora_layout.zig").Layout;
const DreamBrowserParser = @import("dream_browser_parser.zig").DreamBrowserParser;
const DreamBrowserRenderer = @import("dream_browser_renderer.zig").DreamBrowserRenderer;
const DreamBrowserViewport = @import("dream_browser_viewport.zig").DreamBrowserViewport;
const GrainAurora = @import("grain_aurora.zig").GrainAurora;
const AuroraGrainBank = @import("aurora_grainbank.zig").AuroraGrainBank;
const DagCore = @import("dag_core.zig").DagCore;
const BrowserDagIntegration = @import("dream_browser_dag_integration.zig").BrowserDagIntegration;
const LivePreview = @import("aurora_live_preview.zig").LivePreview;
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;

/// Unified IDE: integrates Dream Editor and Dream Browser in multi-pane layout.
/// ~<~ Glow Airbend: explicit tab management, bounded tabs.
/// ~~~~ Glow Waterbend: editor and browser share unified state through DAG.
pub const UnifiedIde = struct {
    allocator: std.mem.Allocator,
    layout: Layout,
    shared_aurora: GrainAurora,
    dag: DagCore,
    grainbank: AuroraGrainBank,
    live_preview: LivePreview,
    
    // Bounded: Max 100 editor tabs
    pub const MAX_EDITOR_TABS: u32 = 100;
    editor_tabs: std.ArrayList(EditorTab) = undefined,
    current_editor_tab: u32 = 0,
    
    // Bounded: Max 100 browser tabs
    pub const MAX_BROWSER_TABS: u32 = 100;
    browser_tabs: std.ArrayList(BrowserTab) = undefined,
    current_browser_tab: u32 = 0,
    
    pub const EditorTab = struct {
        id: u32,
        editor: Editor,
        file_uri: []const u8,
        title: []const u8,
    };
    
    pub const BrowserTab = struct {
        id: u32,
        url: []const u8,
        parser: DreamBrowserParser,
        renderer: DreamBrowserRenderer,
        viewport: DreamBrowserViewport, // Viewport for scrolling and navigation
        title: []const u8,
        contract_id: ?u64 = null, // Associated GrainBank contract (if content requires payment)
        payment_enabled: bool = false, // Whether automatic micropayments are enabled
    };
    
    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !UnifiedIde {
        // Assert: Dimensions must be valid
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(width <= 16384); // Bounded width
        std.debug.assert(height <= 16384); // Bounded height
        
        var layout = Layout.init(allocator);
        errdefer layout.deinit();
        
        // Create initial workspace with editor pane
        _ = try layout.create_workspace("main", width, height);
        
        const shared_aurora = try GrainAurora.init(allocator, "");
        errdefer shared_aurora.deinit();
        
        var dag = try DagCore.init(allocator);
        errdefer dag.deinit();
        
        var grainbank = try AuroraGrainBank.init(allocator, &dag);
        errdefer grainbank.deinit();
        
        var live_preview = try LivePreview.init(allocator);
        errdefer live_preview.deinit();
        
        return UnifiedIde{
            .allocator = allocator,
            .layout = layout,
            .shared_aurora = shared_aurora,
            .dag = dag,
            .grainbank = grainbank,
            .live_preview = live_preview,
            .editor_tabs = std.ArrayList(EditorTab).init(allocator),
            .browser_tabs = std.ArrayList(BrowserTab).init(allocator),
        };
    }
    
    pub fn deinit(self: *UnifiedIde) void {
        // Free editor tabs
        for (self.editor_tabs.items) |*tab| {
            tab.editor.deinit();
            self.allocator.free(tab.file_uri);
            self.allocator.free(tab.title);
        }
        self.editor_tabs.deinit();
        
        // Free browser tabs
        for (self.browser_tabs.items) |*tab| {
            tab.parser.deinit();
            tab.renderer.deinit();
            tab.viewport.deinit();
            self.allocator.free(tab.url);
            self.allocator.free(tab.title);
        }
        self.browser_tabs.deinit(self.allocator);
        
        self.live_preview.deinit();
        self.grainbank.deinit();
        self.dag.deinit();
        self.shared_aurora.deinit();
        self.layout.deinit();
        self.* = undefined;
    }
    
    /// Open editor tab with file.
    pub fn open_editor_tab(self: *UnifiedIde, file_uri: []const u8, initial_text: []const u8) !u32 {
        // Assert: File URI and text must be valid
        std.debug.assert(file_uri.len > 0);
        std.debug.assert(file_uri.len <= 4096); // Bounded URI length
        std.debug.assert(initial_text.len <= 100 * 1024 * 1024); // Bounded text size (100MB)
        
        // Assert: Bounded editor tabs
        std.debug.assert(self.editor_tabs.items.len < MAX_EDITOR_TABS);
        
        // Create editor
        var editor = try Editor.init(self.allocator, file_uri, initial_text);
        errdefer editor.deinit();
        
        // Extract title from file URI
        const title = try self.extract_title_from_uri(file_uri);
        errdefer self.allocator.free(title);
        
        const file_uri_copy = try self.allocator.dupe(u8, file_uri);
        errdefer self.allocator.free(file_uri_copy);
        
        const tab_id = @intCast(self.editor_tabs.items.len);
        try self.editor_tabs.append(EditorTab{
            .id = tab_id,
            .editor = editor,
            .file_uri = file_uri_copy,
            .title = title,
        });
        
        // Set as current tab
        self.current_editor_tab = tab_id;
        
        // Assert: Tab created successfully
        std.debug.assert(self.editor_tabs.items.len <= MAX_EDITOR_TABS);
        
        return tab_id;
    }
    
    /// Open browser tab with URL.
    pub fn open_browser_tab(self: *UnifiedIde, url: []const u8) !u32 {
        // Assert: URL must be valid
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= 4096); // Bounded URL length
        
        // Assert: Bounded browser tabs
        std.debug.assert(self.browser_tabs.items.len < MAX_BROWSER_TABS);
        
        // Create parser, renderer, and viewport
        var parser = DreamBrowserParser.init(self.allocator);
        errdefer parser.deinit();
        
        var renderer = DreamBrowserRenderer.init(self.allocator);
        errdefer renderer.deinit();
        
        var viewport = DreamBrowserViewport.init(self.allocator);
        errdefer viewport.deinit();
        
        // Extract title from URL
        const title = try self.extract_title_from_url(url);
        errdefer self.allocator.free(title);
        
        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);
        
        // Check if URL requires payment (Nostr content may include GrainBank contracts)
        const contract_id = try self.detect_payment_contract(url);
        
        // Add to history
        try viewport.add_history_entry(url_copy);
        
        const tab_id = @intCast(self.browser_tabs.items.len);
        try self.browser_tabs.append(self.allocator, BrowserTab{
            .id = tab_id,
            .url = url_copy,
            .parser = parser,
            .renderer = renderer,
            .viewport = viewport,
            .title = title,
            .contract_id = contract_id,
            .payment_enabled = contract_id != null,
        });
        
        // Set as current tab
        self.current_browser_tab = tab_id;
        
        // Assert: Tab created successfully
        std.debug.assert(self.browser_tabs.items.len <= MAX_BROWSER_TABS);
        
        return tab_id;
    }
    
    /// Detect if URL/content requires GrainBank payment contract.
    fn detect_payment_contract(self: *UnifiedIde, url: []const u8) !?u64 {
        _ = self;
        
        // Assert: URL must be valid
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= 4096); // Bounded URL length
        
        // For now, return null (no payment required)
        // In future, this would:
        // 1. Parse Nostr event from URL
        // 2. Check if event includes GrainBank contract metadata
        // 3. Create or find contract in GrainBank
        // 4. Return contract ID
        
        return null;
    }
    
    /// Trigger automatic micropayment for content viewing.
    pub fn trigger_content_payment(
        self: *UnifiedIde,
        browser_tab_id: u32,
        amount: u128,
        from_npub: [32]u8,
        to_npub: [32]u8,
    ) !?u64 {
        // Assert: Browser tab ID and amount must be valid
        std.debug.assert(browser_tab_id < self.browser_tabs.items.len);
        std.debug.assert(amount > 0);
        
        const tab = &self.browser_tabs.items[browser_tab_id];
        
        // Assert: Payment must be enabled for this tab
        std.debug.assert(tab.payment_enabled);
        std.debug.assert(tab.contract_id != null);
        
        const contract_id = tab.contract_id.?;
        
        // Create payment via GrainBank
        const payment_id = try self.grainbank.create_payment(
            contract_id,
            amount,
            from_npub,
            to_npub,
        );
        
        // Process pending payments (deterministic state machine)
        try self.grainbank.process_pending_payments();
        
        // Assert: Payment created successfully
        std.debug.assert(payment_id > 0);
        
        return payment_id;
    }
    
    /// Enable or disable automatic micropayments for browser tab.
    pub fn set_payment_enabled(self: *UnifiedIde, browser_tab_id: u32, enabled: bool) void {
        // Assert: Browser tab ID must be valid
        std.debug.assert(browser_tab_id < self.browser_tabs.items.len);
        
        const tab = &self.browser_tabs.items[browser_tab_id];
        tab.payment_enabled = enabled;
    }
    
    /// Associate GrainBank contract with browser tab.
    pub fn set_tab_contract(self: *UnifiedIde, browser_tab_id: u32, contract_id: u64) void {
        // Assert: Browser tab ID and contract ID must be valid
        std.debug.assert(browser_tab_id < self.browser_tabs.items.len);
        std.debug.assert(contract_id > 0);
        
        const tab = &self.browser_tabs.items[browser_tab_id];
        tab.contract_id = contract_id;
        tab.payment_enabled = true;
    }
    
    /// Close editor tab.
    pub fn close_editor_tab(self: *UnifiedIde, tab_id: u32) !void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.editor_tabs.items.len);
        
        const tab = &self.editor_tabs.items[tab_id];
        tab.editor.deinit();
        self.allocator.free(tab.file_uri);
        self.allocator.free(tab.title);
        
        // Remove from list (swap with last and pop)
        if (self.editor_tabs.items.len > 1) {
            const last_idx = self.editor_tabs.items.len - 1;
            if (tab_id != last_idx) {
                self.editor_tabs.items[tab_id] = self.editor_tabs.items[last_idx];
                self.editor_tabs.items[tab_id].id = tab_id;
            }
        }
        _ = self.editor_tabs.pop();
        
        // Update current tab if needed
        if (self.current_editor_tab >= self.editor_tabs.items.len) {
            if (self.editor_tabs.items.len > 0) {
                self.current_editor_tab = @intCast(self.editor_tabs.items.len - 1);
            } else {
                self.current_editor_tab = 0;
            }
        }
        
        // Assert: Tab count valid
        std.debug.assert(self.editor_tabs.items.len < MAX_EDITOR_TABS);
    }
    
    /// Close browser tab.
    pub fn close_browser_tab(self: *UnifiedIde, tab_id: u32) !void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.browser_tabs.items.len);
        
        const tab = &self.browser_tabs.items[tab_id];
        tab.parser.deinit();
        tab.renderer.deinit();
        self.allocator.free(tab.url);
        self.allocator.free(tab.title);
        
        // Remove from list (swap with last and pop)
        if (self.browser_tabs.items.len > 1) {
            const last_idx = self.browser_tabs.items.len - 1;
            if (tab_id != last_idx) {
                self.browser_tabs.items[tab_id] = self.browser_tabs.items[last_idx];
                self.browser_tabs.items[tab_id].id = tab_id;
            }
        }
        _ = self.browser_tabs.pop();
        
        // Update current tab if needed
        if (self.current_browser_tab >= self.browser_tabs.items.len) {
            if (self.browser_tabs.items.len > 0) {
                self.current_browser_tab = @intCast(self.browser_tabs.items.len - 1);
            } else {
                self.current_browser_tab = 0;
            }
        }
        
        // Assert: Tab count valid
        std.debug.assert(self.browser_tabs.items.len < MAX_BROWSER_TABS);
    }
    
    /// Switch to editor tab.
    pub fn switch_editor_tab(self: *UnifiedIde, tab_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.editor_tabs.items.len);
        
        self.current_editor_tab = tab_id;
    }
    
    /// Switch to browser tab.
    pub fn switch_browser_tab(self: *UnifiedIde, tab_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < self.browser_tabs.items.len);
        
        self.current_browser_tab = tab_id;
    }
    
    /// Get current editor tab.
    pub fn get_current_editor_tab(self: *UnifiedIde) ?*EditorTab {
        if (self.editor_tabs.items.len == 0) return null;
        
        // Assert: Current tab index must be valid
        std.debug.assert(self.current_editor_tab < self.editor_tabs.items.len);
        
        return &self.editor_tabs.items[self.current_editor_tab];
    }
    
    /// Get current browser tab.
    pub fn get_current_browser_tab(self: *UnifiedIde) ?*BrowserTab {
        if (self.browser_tabs.items.len == 0) return null;
        
        // Assert: Current tab index must be valid
        std.debug.assert(self.current_browser_tab < self.browser_tabs.items.len);
        
        return &self.browser_tabs.items[self.current_browser_tab];
    }
    
    /// Split pane and open editor tab in new pane.
    pub fn split_and_open_editor(self: *UnifiedIde, direction: Layout.SplitDirection, file_uri: []const u8, initial_text: []const u8) !void {
        // Assert: File URI and text must be valid
        std.debug.assert(file_uri.len > 0);
        std.debug.assert(file_uri.len <= 4096); // Bounded URI length
        std.debug.assert(initial_text.len <= 100 * 1024 * 1024); // Bounded text size
        
        // Split focused pane
        try self.layout.split_pane(direction, .editor);
        
        // Open editor tab
        _ = try self.open_editor_tab(file_uri, initial_text);
    }
    
    /// Split pane and open browser tab in new pane.
    pub fn split_and_open_browser(self: *UnifiedIde, direction: Layout.SplitDirection, url: []const u8) !void {
        // Assert: URL must be valid
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= 4096); // Bounded URL length
        
        // Split focused pane
        try self.layout.split_pane(direction, .browser);
        
        // Open browser tab
        _ = try self.open_browser_tab(url);
    }
    
    /// Resize unified IDE layout.
    pub fn resize(self: *UnifiedIde, width: u32, height: u32) !void {
        // Assert: Dimensions must be valid
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(width <= 16384); // Bounded width
        std.debug.assert(height <= 16384); // Bounded height
        
        try self.layout.resize(width, height);
    }
    
    /// Extract title from file URI (e.g., "file:///path/to/file.zig" -> "file.zig").
    fn extract_title_from_uri(self: *UnifiedIde, uri: []const u8) ![]const u8 {
        _ = self;
        
        // Assert: URI must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        
        // Find last '/' or '\'
        var last_slash: ?u32 = null;
        for (uri, 0..) |ch, i| {
            if (ch == '/' or ch == '\\') {
                last_slash = @intCast(i);
            }
        }
        
        const start = if (last_slash) |pos| pos + 1 else 0;
        const filename = uri[start..];
        
        // If empty, use "untitled"
        if (filename.len == 0) {
            return try self.allocator.dupe(u8, "untitled");
        }
        
        return try self.allocator.dupe(u8, filename);
    }
    
    /// Extract title from URL (e.g., "nostr:note1abc..." -> "Nostr Note").
    fn extract_title_from_url(self: *UnifiedIde, url: []const u8) ![]const u8 {
        _ = self;
        
        // Assert: URL must be valid
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= 4096); // Bounded URL length
        
        // Check for Nostr URLs
        if (std.mem.startsWith(u8, url, "nostr:")) {
            if (std.mem.startsWith(u8, url, "nostr:note")) {
                return try self.allocator.dupe(u8, "Nostr Note");
            } else if (std.mem.startsWith(u8, url, "nostr:npub")) {
                return try self.allocator.dupe(u8, "Nostr Profile");
            } else {
                return try self.allocator.dupe(u8, "Nostr");
            }
        }
        
        // Extract domain from HTTP/HTTPS URLs
        if (std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://")) {
            const prefix_len = if (std.mem.startsWith(u8, url, "https://")) 8 else 7;
            const after_prefix = url[prefix_len..];
            
            if (std.mem.indexOfScalar(u8, after_prefix, '/')) |slash_pos| {
                const domain = after_prefix[0..slash_pos];
                return try self.allocator.dupe(u8, domain);
            } else {
                return try self.allocator.dupe(u8, after_prefix);
            }
        }
        
        // Default: use URL as title (truncated)
        const max_title_len = 64;
        if (url.len > max_title_len) {
            var title = try self.allocator.alloc(u8, max_title_len + 3);
            @memcpy(title[0..max_title_len], url[0..max_title_len]);
            @memcpy(title[max_title_len..], "...");
            return title;
        }
        
        return try self.allocator.dupe(u8, url);
    }
    
    /// Get all editor tabs (for tab bar rendering).
    pub fn get_editor_tabs(self: *UnifiedIde) []const EditorTab {
        return self.editor_tabs.items;
    }
    
    /// Get all browser tabs (for tab bar rendering).
    pub fn get_browser_tabs(self: *UnifiedIde) []const BrowserTab {
        return self.browser_tabs.items;
    }
    
    /// Focus next pane (River-style navigation).
    pub fn focus_next_pane(self: *UnifiedIde) void {
        self.layout.focus_next();
    }
    
    /// Close focused pane.
    pub fn close_focused_pane(self: *UnifiedIde) !void {
        try self.layout.close_pane();
    }
    
    /// Switch workspace (River-style workspace switching).
    pub fn switch_workspace(self: *UnifiedIde, workspace_id: u32) !void {
        try self.layout.switch_workspace(workspace_id);
    }
    
    /// Subscribe editor tab to browser tab for live preview.
    pub fn subscribe_live_preview(
        self: *UnifiedIde,
        editor_tab_id: u32,
        browser_tab_id: u32,
        direction: LivePreview.SyncDirection,
    ) !void {
        // Assert: Tab IDs must be valid
        std.debug.assert(editor_tab_id < self.editor_tabs.items.len);
        std.debug.assert(browser_tab_id < self.browser_tabs.items.len);
        
        try self.live_preview.subscribe(editor_tab_id, browser_tab_id, direction);
    }
    
    /// Process live preview updates (call periodically to sync editor and browser).
    pub fn process_live_preview_updates(self: *UnifiedIde) !void {
        // Build editor instances array
        var editor_instances = std.ArrayList(LivePreview.EditorInstance).init(self.allocator);
        defer editor_instances.deinit();
        
        for (self.editor_tabs.items) |*tab| {
            try editor_instances.append(LivePreview.EditorInstance{
                .tab_id = tab.id,
                .editor = &tab.editor,
            });
        }
        
        // Build browser renderer instances array
        var browser_renderers = std.ArrayList(LivePreview.BrowserRendererInstance).init(self.allocator);
        defer browser_renderers.deinit();
        
        for (self.browser_tabs.items) |*tab| {
            // Create buffer for renderer (temporary, would be managed by renderer in full implementation)
            var buffer = try GrainBuffer.fromSlice(self.allocator, "");
            errdefer buffer.deinit();
            
            try browser_renderers.append(LivePreview.BrowserRendererInstance{
                .tab_id = tab.id,
                .renderer = &tab.renderer,
                .buffer = &buffer,
            });
        }
        
        // Process updates with editor and browser instances
        try self.live_preview.process_updates(
            editor_instances.items,
            browser_renderers.items,
        );
    }
    
    /// Handle editor edit and propagate to live preview.
    pub fn handle_editor_edit(
        self: *UnifiedIde,
        editor_tab_id: u32,
        old_text: []const u8,
        new_text: []const u8,
    ) !void {
        // Assert: Editor tab ID must be valid
        std.debug.assert(editor_tab_id < self.editor_tabs.items.len);
        std.debug.assert(old_text.len <= 100 * 1024 * 1024); // Bounded text size
        std.debug.assert(new_text.len <= 100 * 1024 * 1024); // Bounded text size
        
        const tab = &self.editor_tabs.items[editor_tab_id];
        
        // Determine edit type (simplified: always insertion for now)
        const edit_type: @import("aurora_dag_integration.zig").EditorDagIntegration.EditType = .insert;
        
        // Propagate to live preview
        try self.live_preview.handle_editor_edit(
            editor_tab_id,
            tab.file_uri,
            old_text,
            new_text,
            edit_type,
        );
    }
    
    /// Handle browser content update and propagate to live preview.
    pub fn handle_browser_update(
        self: *UnifiedIde,
        browser_tab_id: u32,
        event_content: []const u8,
        event_id: []const u8,
    ) !void {
        // Assert: Browser tab ID must be valid
        std.debug.assert(browser_tab_id < self.browser_tabs.items.len);
        std.debug.assert(event_content.len > 0);
        std.debug.assert(event_content.len <= 10 * 1024 * 1024); // Bounded content size
        std.debug.assert(event_id.len > 0);
        std.debug.assert(event_id.len <= 64); // Bounded event ID length
        
        // Propagate to live preview
        try self.live_preview.handle_nostr_event(
            browser_tab_id,
            event_content,
            event_id,
        );
    }
};

test "unified ide lifecycle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var ide = try UnifiedIde.init(arena.allocator(), 1920, 1080);
    defer ide.deinit();
    
    // Assert: IDE initialized
    std.debug.assert(ide.editor_tabs.items.len == 0);
    std.debug.assert(ide.browser_tabs.items.len == 0);
    std.debug.assert(ide.layout.root != null);
}

test "unified ide open editor tab" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
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
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
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

