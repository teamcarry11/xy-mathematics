const std = @import("std");
const Editor = @import("aurora_editor.zig").Editor;
const EditorDagIntegration = @import("aurora_dag_integration.zig").EditorDagIntegration;
const BrowserDagIntegration = @import("dream_browser_dag_integration.zig").BrowserDagIntegration;
const DagCore = @import("dag_core.zig").DagCore;
const DreamBrowserParser = @import("dream_browser_parser.zig").DreamBrowserParser;
const DreamBrowserRenderer = @import("dream_browser_renderer.zig").DreamBrowserRenderer;
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;
const GrainAurora = @import("grain_aurora.zig").GrainAurora;

/// Live Preview: Real-time bidirectional sync between editor and browser.
/// ~<~ Glow Airbend: explicit sync state, bounded updates.
/// ~~~~ Glow Waterbend: edits flow through DAG deterministically.
pub const LivePreview = struct {
    // Bounded: Max 100 sync subscriptions
    pub const MAX_SYNC_SUBSCRIPTIONS: u32 = 100;
    
    // Bounded: Max 1,000 pending updates per second
    pub const MAX_UPDATES_PER_SECOND: u32 = 1_000;
    
    pub const SyncSubscription = struct {
        editor_tab_id: u32,
        browser_tab_id: u32,
        sync_direction: SyncDirection,
        enabled: bool = true,
    };
    
    pub const SyncDirection = enum {
        editor_to_browser, // Editor edits → Browser preview
        browser_to_editor, // Browser updates → Editor sync
        bidirectional, // Both directions
    };
    
    pub const Update = struct {
        source: UpdateSource,
        source_id: u32, // Editor tab ID or browser tab ID
        target_id: u32, // Target tab ID
        data: []const u8,
        timestamp: u64,
    };
    
    pub const UpdateSource = enum {
        editor_edit, // Code edit in editor
        nostr_event, // Nostr event in browser
        browser_content, // Browser content update
    };
    
    allocator: std.mem.Allocator,
    dag: DagCore,
    editor_dag: EditorDagIntegration,
    browser_dag: BrowserDagIntegration,
    sync_subscriptions: std.ArrayList(SyncSubscription) = undefined,
    pending_updates: std.ArrayList(Update) = undefined,
    
    pub fn init(allocator: std.mem.Allocator) !LivePreview {
        const dag = try DagCore.init(allocator);
        errdefer dag.deinit();
        
        const editor_dag = try EditorDagIntegration.init(allocator);
        errdefer editor_dag.deinit();
        
        const browser_dag = BrowserDagIntegration.init(allocator, &dag);
        
        return LivePreview{
            .allocator = allocator,
            .dag = dag,
            .editor_dag = editor_dag,
            .browser_dag = browser_dag,
            .sync_subscriptions = std.ArrayList(SyncSubscription).init(allocator),
            .pending_updates = std.ArrayList(Update).init(allocator),
        };
    }
    
    pub fn deinit(self: *LivePreview) void {
        // Free pending updates
        for (self.pending_updates.items) |*update| {
            self.allocator.free(update.data);
        }
        self.pending_updates.deinit();
        
        self.sync_subscriptions.deinit();
        self.browser_dag.deinit();
        self.editor_dag.deinit();
        self.dag.deinit();
        self.* = undefined;
    }
    
    /// Subscribe editor tab to browser tab for live preview.
    pub fn subscribe(
        self: *LivePreview,
        editor_tab_id: u32,
        browser_tab_id: u32,
        direction: SyncDirection,
    ) !void {
        // Assert: Tab IDs must be valid
        std.debug.assert(editor_tab_id < 100); // Bounded editor tabs
        std.debug.assert(browser_tab_id < 100); // Bounded browser tabs
        
        // Assert: Bounded subscriptions
        std.debug.assert(self.sync_subscriptions.items.len < MAX_SYNC_SUBSCRIPTIONS);
        
        try self.sync_subscriptions.append(SyncSubscription{
            .editor_tab_id = editor_tab_id,
            .browser_tab_id = browser_tab_id,
            .sync_direction = direction,
            .enabled = true,
        });
        
        // Assert: Subscription added successfully
        std.debug.assert(self.sync_subscriptions.items.len <= MAX_SYNC_SUBSCRIPTIONS);
    }
    
    /// Handle editor edit and propagate to browser preview.
    pub fn handle_editor_edit(
        self: *LivePreview,
        editor_tab_id: u32,
        file_uri: []const u8,
        old_text: []const u8,
        new_text: []const u8,
        edit_type: EditorDagIntegration.EditType,
    ) !void {
        // Assert: Editor tab ID and text must be valid
        std.debug.assert(editor_tab_id < 100); // Bounded editor tabs
        std.debug.assert(file_uri.len > 0);
        std.debug.assert(file_uri.len <= 4096); // Bounded URI length
        std.debug.assert(old_text.len <= 100 * 1024 * 1024); // Bounded text size
        std.debug.assert(new_text.len <= 100 * 1024 * 1024); // Bounded text size
        
        // Find subscriptions for this editor tab
        for (self.sync_subscriptions.items) |*sub| {
            if (sub.editor_tab_id == editor_tab_id and sub.enabled) {
                // Check sync direction
                if (sub.sync_direction == .editor_to_browser or 
                    sub.sync_direction == .bidirectional)
                {
                    // Map code edit to DAG event
                    const node_id = try self.find_or_create_editor_node(file_uri);
                    const parent_events = try self.get_latest_parent_events();
                    
                    const event_id = try self.editor_dag.mapCodeEditToDag(
                        node_id,
                        edit_type,
                        old_text,
                        new_text,
                        parent_events,
                    );
                    
                    // Queue update for browser preview
                    try self.queue_browser_update(
                        sub.browser_tab_id,
                        new_text,
                        event_id,
                    );
                }
            }
        }
    }
    
    /// Handle Nostr event update and propagate to editor sync.
    pub fn handle_nostr_event(
        self: *LivePreview,
        browser_tab_id: u32,
        event_content: []const u8,
        event_id: []const u8,
    ) !void {
        // Assert: Browser tab ID and content must be valid
        std.debug.assert(browser_tab_id < 100); // Bounded browser tabs
        std.debug.assert(event_content.len > 0);
        std.debug.assert(event_content.len <= 10 * 1024 * 1024); // Bounded content size (10MB)
        std.debug.assert(event_id.len > 0);
        std.debug.assert(event_id.len <= 64); // Bounded event ID length
        
        // Find subscriptions for this browser tab
        for (self.sync_subscriptions.items) |*sub| {
            if (sub.browser_tab_id == browser_tab_id and sub.enabled) {
                // Check sync direction
                if (sub.sync_direction == .browser_to_editor or 
                    sub.sync_direction == .bidirectional)
                {
                    // Map Nostr event to DAG event
                    const node_id = try self.find_or_create_browser_node(event_id);
                    const parent_events = try self.get_latest_parent_events();
                    
                    const web_event_id = try self.browser_dag.mapWebRequestToDag(
                        node_id,
                        "nostr",
                        "GET",
                        &.{},
                        event_content,
                        parent_events,
                    );
                    
                    // Queue update for editor sync
                    try self.queue_editor_update(
                        sub.editor_tab_id,
                        event_content,
                        web_event_id,
                    );
                }
            }
        }
    }
    
    /// Process pending updates (streaming, Hyperfiddle-style).
    /// Takes optional editor and browser renderer instances for actual updates.
    pub fn process_updates(
        self: *LivePreview,
        editor_instances: ?[]const EditorInstance,
        browser_renderers: ?[]const BrowserRendererInstance,
    ) !void {
        // Assert: Updates must be within bounds
        std.debug.assert(self.pending_updates.items.len <= MAX_UPDATES_PER_SECOND);
        
        // Process updates in order (deterministic)
        for (self.pending_updates.items) |*update| {
            // Apply update based on source
            switch (update.source) {
                .editor_edit => {
                    // Editor edit → Browser preview
                    // Find browser renderer for target tab
                    if (browser_renderers) |renderers| {
                        for (renderers) |renderer_instance| {
                            if (renderer_instance.tab_id == update.target_id) {
                                // Parse new content as HTML
                                var parser = DreamBrowserParser.init(self.allocator);
                                defer parser.deinit();
                                
                                const html_node = parser.parseHtml(update.data) catch {
                                    // If parsing fails, skip this update
                                    continue;
                                };
                                
                                // Re-render browser with new content
                                renderer_instance.renderer.renderPage(
                                    &html_node,
                                    &.{}, // Empty CSS rules for now
                                    renderer_instance.buffer,
                                ) catch {
                                    // If rendering fails, skip this update
                                    continue;
                                };
                                break;
                            }
                        }
                    }
                },
                .nostr_event, .browser_content => {
                    // Browser update → Editor sync
                    // Find editor for target tab
                    if (editor_instances) |editors| {
                        for (editors) |editor_instance| {
                            if (editor_instance.tab_id == update.target_id) {
                                // Update editor buffer with new content
                                // Replace entire buffer content with new content
                                const current_text = editor_instance.editor.buffer.textSlice();
                                
                                // Clear existing buffer and create new one with updated content
                                editor_instance.editor.buffer.deinit();
                                
                                // Create new buffer with updated content
                                editor_instance.editor.buffer = GrainBuffer.fromSlice(
                                    editor_instance.editor.allocator,
                                    update.data,
                                ) catch {
                                    // If buffer creation fails, skip this update
                                    continue;
                                };
                                
                                // Update Aurora rendering
                                editor_instance.editor.aurora.deinit();
                                editor_instance.editor.aurora = GrainAurora.init(
                                    editor_instance.editor.allocator,
                                    update.data,
                                ) catch {
                                    // If Aurora init fails, skip this update
                                    continue;
                                };
                                break;
                            }
                        }
                    }
                },
            }
        }
        
        // Clear pending updates after processing
        for (self.pending_updates.items) |*update| {
            self.allocator.free(update.data);
        }
        self.pending_updates.clearRetainingCapacity();
        
        // Process DAG events (TigerBeetle-style state machine)
        try self.editor_dag.processEvents();
        try self.browser_dag.processEvents();
        
        // Assert: Updates processed successfully
        std.debug.assert(self.pending_updates.items.len == 0);
    }
    
    /// Editor instance (for update processing).
    pub const EditorInstance = struct {
        tab_id: u32,
        editor: *Editor,
    };
    
    /// Browser renderer instance (for update processing).
    pub const BrowserRendererInstance = struct {
        tab_id: u32,
        renderer: *DreamBrowserRenderer,
        buffer: *GrainBuffer,
    };
    
    /// Find or create editor node in DAG for file URI.
    fn find_or_create_editor_node(self: *LivePreview, file_uri: []const u8) !u32 {
        // Assert: File URI must be valid
        std.debug.assert(file_uri.len > 0);
        std.debug.assert(file_uri.len <= 4096); // Bounded URI length
        
        // Search for existing node with this file URI
        for (0..self.dag.nodes_len) |i| {
            const node = &self.dag.nodes[i];
            if (node.node_type == .ast_node) {
                // Check if node data contains file URI
                if (std.mem.indexOf(u8, node.data[0..node.data_len], file_uri)) |_| {
                    return @intCast(i);
                }
            }
        }
        
        // Create new node for file
        const node_data = try std.fmt.allocPrint(
            self.allocator,
            "file:{s}",
            .{file_uri},
        );
        defer self.allocator.free(node_data);
        
        const node_id = try self.dag.addNode(
            .ast_node,
            node_data,
            .{},
        );
        
        // Assert: Node created successfully
        std.debug.assert(node_id < DagCore.MAX_NODES);
        
        return node_id;
    }
    
    /// Find or create browser node in DAG for event ID.
    fn find_or_create_browser_node(self: *LivePreview, event_id: []const u8) !u32 {
        // Assert: Event ID must be valid
        std.debug.assert(event_id.len > 0);
        std.debug.assert(event_id.len <= 64); // Bounded event ID length
        
        // Search for existing node with this event ID
        for (0..self.dag.nodes_len) |i| {
            const node = &self.dag.nodes[i];
            if (node.node_type == .dom_node) {
                // Check if node data contains event ID
                if (std.mem.indexOf(u8, node.data[0..node.data_len], event_id)) |_| {
                    return @intCast(i);
                }
            }
        }
        
        // Create new node for event
        const node_data = try std.fmt.allocPrint(
            self.allocator,
            "nostr:{s}",
            .{event_id},
        );
        defer self.allocator.free(node_data);
        
        const node_id = try self.dag.addNode(
            .dom_node,
            node_data,
            .{},
        );
        
        // Assert: Node created successfully
        std.debug.assert(node_id < DagCore.MAX_NODES);
        
        return node_id;
    }
    
    /// Get latest parent events for HashDAG-style ordering.
    fn get_latest_parent_events(self: *LivePreview) ![]const u64 {
        // Get latest events from DAG (for parent references)
        // Bounded: Max 10 parent events
        const max_parents: u32 = 10;
        var parents = std.ArrayList(u64).init(self.allocator);
        errdefer parents.deinit();
        
        // Get latest events (simplified: get from pending events)
        const count = @min(self.dag.pending_events_len, max_parents);
        for (0..count) |i| {
            const event = self.dag.pending_events[i];
            try parents.append(event.id);
        }
        
        return try parents.toOwnedSlice();
    }
    
    /// Queue browser update for processing.
    fn queue_browser_update(
        self: *LivePreview,
        browser_tab_id: u32,
        content: []const u8,
        event_id: u64,
    ) !void {
        // Assert: Browser tab ID and content must be valid
        std.debug.assert(browser_tab_id < 100); // Bounded browser tabs
        std.debug.assert(content.len > 0);
        std.debug.assert(content.len <= 10 * 1024 * 1024); // Bounded content size
        
        // Assert: Bounded pending updates
        std.debug.assert(self.pending_updates.items.len < MAX_UPDATES_PER_SECOND);
        
        const content_copy = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(content_copy);
        
        const timestamp = std.time.timestamp();
        // Assert: Timestamp must be non-negative (cast to u64)
        std.debug.assert(timestamp >= 0);
        const timestamp_u64 = @intCast(timestamp);
        
        try self.pending_updates.append(Update{
            .source = .editor_edit,
            .source_id = browser_tab_id, // Source is editor, target is browser
            .target_id = browser_tab_id,
            .data = content_copy,
            .timestamp = timestamp_u64,
        });
        
        // Assert: Update queued successfully
        std.debug.assert(self.pending_updates.items.len <= MAX_UPDATES_PER_SECOND);
    }
    
    /// Queue editor update for processing.
    fn queue_editor_update(
        self: *LivePreview,
        editor_tab_id: u32,
        content: []const u8,
        event_id: u64,
    ) !void {
        // Assert: Editor tab ID and content must be valid
        std.debug.assert(editor_tab_id < 100); // Bounded editor tabs
        std.debug.assert(content.len > 0);
        std.debug.assert(content.len <= 10 * 1024 * 1024); // Bounded content size
        
        // Assert: Bounded pending updates
        std.debug.assert(self.pending_updates.items.len < MAX_UPDATES_PER_SECOND);
        
        const content_copy = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(content_copy);
        
        const timestamp = std.time.timestamp();
        // Handle negative timestamps (shouldn't happen, but handle gracefully)
        const timestamp_u64 = if (timestamp < 0)
            @as(u64, 0)
        else
            @as(u64, @intCast(timestamp));
        
        try self.pending_updates.append(Update{
            .source = .nostr_event,
            .source_id = editor_tab_id, // Source is browser, target is editor
            .target_id = editor_tab_id,
            .data = content_copy,
            .timestamp = timestamp_u64,
        });
        
        // Assert: Update queued successfully
        std.debug.assert(self.pending_updates.items.len <= MAX_UPDATES_PER_SECOND);
    }
    
    /// Enable or disable sync subscription.
    pub fn set_sync_enabled(self: *LivePreview, subscription_idx: u32, enabled: bool) void {
        // Assert: Subscription index must be valid
        std.debug.assert(subscription_idx < self.sync_subscriptions.items.len);
        
        self.sync_subscriptions.items[subscription_idx].enabled = enabled;
    }
    
    /// Get sync subscription by editor and browser tab IDs.
    pub fn get_subscription(
        self: *LivePreview,
        editor_tab_id: u32,
        browser_tab_id: u32,
    ) ?*SyncSubscription {
        // Assert: Tab IDs must be valid
        std.debug.assert(editor_tab_id < 100); // Bounded editor tabs
        std.debug.assert(browser_tab_id < 100); // Bounded browser tabs
        
        for (self.sync_subscriptions.items) |*sub| {
            if (sub.editor_tab_id == editor_tab_id and 
                sub.browser_tab_id == browser_tab_id)
            {
                return sub;
            }
        }
        
        return null;
    }
};

test "live preview lifecycle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var preview = try LivePreview.init(arena.allocator());
    defer preview.deinit();
    
    // Assert: Preview initialized
    std.debug.assert(preview.sync_subscriptions.items.len == 0);
    std.debug.assert(preview.pending_updates.items.len == 0);
}

test "live preview subscribe" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var preview = try LivePreview.init(arena.allocator());
    defer preview.deinit();
    
    try preview.subscribe(0, 0, .bidirectional);
    
    // Assert: Subscription created
    std.debug.assert(preview.sync_subscriptions.items.len == 1);
    std.debug.assert(preview.sync_subscriptions.items[0].enabled == true);
}

