const std = @import("std");
const DagCore = @import("dag_core.zig").DagCore;
const DreamProtocol = @import("dream_protocol.zig").DreamProtocol;

/// Browser-DAG Integration: Maps DOM nodes to DAG nodes, web requests to DAG events.
/// ~<~ Glow Airbend: explicit DOM-to-DAG mapping, bounded conversions.
/// ~~~~ Glow Waterbend: web requests stream through DAG deterministically.
///
/// This implements unified editor/browser state:
/// - DOM nodes become DAG nodes (unified with AST nodes)
/// - Web requests become DAG events (HashDAG-style ordering)
/// - Streaming updates (Hyperfiddle-style propagation)
/// - Real-time sync (editor ↔ browser)
pub const BrowserDagIntegration = struct {
    allocator: std.mem.Allocator,
    dag: DagCore,
    
    // Bounded: Max 5,000 DOM nodes per page
    pub const MAX_DOM_NODES_PER_PAGE: u32 = 5_000;
    
    // Bounded: Max 50 web requests per second
    pub const MAX_REQUESTS_PER_SECOND: u32 = 50;
    
    /// Simple DOM node structure (foundation for future HTML parser).
    pub const DomNode = struct {
        tag_name: []const u8, // "div", "span", "p", etc.
        attributes: []const Attribute,
        children: []const DomNode,
        text_content: []const u8, // Text content (for text nodes)
        parent_id: ?u32 = null, // Parent DAG node ID
    };
    
    /// DOM node attribute.
    pub const Attribute = struct {
        name: []const u8,
        value: []const u8,
    };
    
    /// Web request structure.
    pub const WebRequest = struct {
        url: []const u8,
        method: []const u8, // "GET", "POST", etc.
        headers: []const Header,
        body: ?[]const u8 = null,
    };
    
    /// HTTP header.
    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };
    
    /// Initialize browser-DAG integration.
    pub fn init(allocator: std.mem.Allocator, dag: *DagCore) BrowserDagIntegration {
        // Assert: Allocator and DAG must be valid
        std.debug.assert(allocator.ptr != null);
        _ = dag; // DAG is owned by caller
        
        return BrowserDagIntegration{
            .allocator = allocator,
            .dag = dag.*,
        };
    }
    
    /// Deinitialize browser-DAG integration.
    pub fn deinit(self: *BrowserDagIntegration) void {
        // DAG is owned by caller, don't deinit here
        _ = self;
    }
    
    /// Map DOM node to DAG node.
    /// Returns DAG node ID for the DOM node.
    pub fn mapDomNodeToDag(
        self: *BrowserDagIntegration,
        dom_node: *const DomNode,
        url: []const u8,
        parent_dag_id: ?u32,
    ) !u32 {
        // Assert: DOM node count must be within bounds
        std.debug.assert(self.dag.nodes_len < DagCore.MAX_NODES);
        
        // Assert: URL must be non-empty
        std.debug.assert(url.len > 0);
        
        // Create node data (DOM tag + URL + attributes)
        var node_data = std.ArrayList(u8).init(self.allocator);
        defer node_data.deinit();
        
        const writer = node_data.writer();
        try writer.print("{s}:{s}:", .{ url, dom_node.tag_name });
        
        // Add attributes to node data
        for (dom_node.attributes) |attr| {
            try writer.print("{s}={s},", .{ attr.name, attr.value });
        }
        
        // Add text content if present
        if (dom_node.text_content.len > 0) {
            try writer.print("text:{d}", .{dom_node.text_content.len});
        }
        
        // Determine readonly spans (metadata like event ID, timestamp)
        var is_readonly = false;
        var readonly_start: u32 = 0;
        var readonly_end: u32 = 0;
        
        // Check if node has readonly attributes (Nostr event metadata)
        for (dom_node.attributes) |attr| {
            if (std.mem.eql(u8, attr.name, "data-event-id") or
                std.mem.eql(u8, attr.name, "data-timestamp") or
                std.mem.eql(u8, attr.name, "data-author"))
            {
                is_readonly = true;
                readonly_start = 0; // Will be set by renderer
                readonly_end = 0; // Will be set by renderer
                break;
            }
        }
        
        // Create metadata (URL + tag + attributes)
        var metadata = std.ArrayList(u8).init(self.allocator);
        defer metadata.deinit();
        
        const meta_writer = metadata.writer();
        try meta_writer.print("url:{s},tag:{s}", .{ url, dom_node.tag_name });
        
        // Create DAG node (DOM node type)
        const dag_node_id = try self.dag.addNode(
            .dom_node,
            try node_data.toOwnedSlice(),
            .{
                .is_readonly = is_readonly,
                .readonly_start = readonly_start,
                .readonly_end = readonly_end,
                .metadata = try metadata.toOwnedSlice(),
                .metadata_len = @as(u32, @intCast(metadata.items.len)),
            },
        );
        
        // Create edge to parent if present
        if (parent_dag_id) |parent_id| {
            try self.dag.addEdge(parent_id, dag_node_id, .dependency);
        }
        
        // Recursively map children
        for (dom_node.children) |child| {
            _ = try self.mapDomNodeToDag(&child, url, dag_node_id);
        }
        
        // Assert: Node was created
        std.debug.assert(self.dag.getNode(dag_node_id) != null);
        
        return dag_node_id;
    }
    
    /// Map web request to DAG event (HashDAG-style).
    /// Returns event ID for the request.
    pub fn mapRequestToEvent(
        self: *BrowserDagIntegration,
        request: WebRequest,
        parent_events: []const u64,
    ) !u64 {
        // Assert: Request rate must be within bounds
        // TODO: Implement rate limiting
        
        // Assert: URL must be non-empty
        std.debug.assert(request.url.len > 0);
        
        // Create event data (request method + URL + headers + body)
        var event_data = std.ArrayList(u8).init(self.allocator);
        defer event_data.deinit();
        
        const writer = event_data.writer();
        try writer.print("{s}:{s}:", .{ request.method, request.url });
        
        // Add headers
        for (request.headers) |header| {
            try writer.print("{s}:{s},", .{ header.name, header.value });
        }
        
        // Add body if present
        if (request.body) |body| {
            try writer.print("body:{d}:", .{body.len});
            try writer.writeAll(body);
        }
        
        // Determine target node (find or create DOM node for URL)
        // For now, use a placeholder node ID (will be created when DOM is parsed)
        const target_node_id: u32 = 0; // TODO: Find or create DOM node for URL
        
        // Add event to DAG (HashDAG-style with parent references)
        const event_id = try self.dag.addEvent(
            .web_request,
            target_node_id,
            try event_data.toOwnedSlice(),
            parent_events,
        );
        
        // Assert: Event was added
        std.debug.assert(event_id > 0);
        
        return event_id;
    }
    
    /// Map Nostr event to DAG event (for real-time content updates).
    pub fn mapNostrEventToDag(
        self: *BrowserDagIntegration,
        nostr_event: DreamProtocol.Event,
        parent_events: []const u64,
    ) !u64 {
        // Assert: Nostr event must be valid
        std.debug.assert(nostr_event.id.len > 0);
        std.debug.assert(nostr_event.pubkey.len > 0);
        
        // Create event data (Nostr event JSON)
        var event_data = std.ArrayList(u8).init(self.allocator);
        defer event_data.deinit();
        
        const writer = event_data.writer();
        try writer.print("nostr:id:{s},pubkey:{s},kind:{d},content:{d}", .{
            nostr_event.id,
            nostr_event.pubkey,
            nostr_event.kind,
            nostr_event.content.len,
        });
        
        // Determine target node (find or create DOM node for Nostr content)
        // For now, use a placeholder node ID
        const target_node_id: u32 = 0; // TODO: Find or create DOM node for Nostr content
        
        // Add event to DAG (HashDAG-style)
        const event_id = try self.dag.addEvent(
            .web_request, // Use web_request type for Nostr events
            target_node_id,
            try event_data.toOwnedSlice(),
            parent_events,
        );
        
        // Assert: Event was added
        std.debug.assert(event_id > 0);
        
        return event_id;
    }
    
    /// Process pending events (streaming updates, Hyperfiddle-style).
    pub fn processEvents(self: *BrowserDagIntegration) !void {
        // Process events in DAG (TigerBeetle-style state machine)
        try self.dag.processEvents();
        
        // Assert: Events were processed
        std.debug.assert(self.dag.pending_events_len == 0);
    }
    
    /// Find DAG node by URL and DOM tag (for navigation, updates).
    pub fn findNodeByUrlAndTag(
        self: *const BrowserDagIntegration,
        url: []const u8,
        tag_name: []const u8,
    ) ?u32 {
        // Assert: URL and tag must be non-empty
        std.debug.assert(url.len > 0);
        std.debug.assert(tag_name.len > 0);
        
        // Search DAG nodes for matching URL and tag
        const nodes = self.dag.nodes[0..self.dag.nodes_len];
        
        for (nodes, 0..) |node, i| {
            if (node.node_type == .dom_node) {
                // Check if node matches URL and tag
                // TODO: Parse node data to extract URL and tag
                // For now, check metadata
                if (std.mem.indexOf(u8, node.attributes.metadata, url) != null) {
                    if (std.mem.indexOf(u8, node.attributes.metadata, tag_name) != null) {
                        return @as(u32, @intCast(i));
                    }
                }
            }
        }
        
        return null;
    }
    
    /// Get unified state (editor + browser DAG nodes).
    pub fn getUnifiedState(self: *const BrowserDagIntegration) UnifiedState {
        // Count nodes by type
        const nodes = self.dag.nodes[0..self.dag.nodes_len];
        
        var ast_count: u32 = 0;
        var dom_count: u32 = 0;
        var ui_count: u32 = 0;
        var data_count: u32 = 0;
        var comp_count: u32 = 0;
        
        for (nodes) |node| {
            switch (node.node_type) {
                .ast_node => ast_count += 1,
                .dom_node => dom_count += 1,
                .ui_component => ui_count += 1,
                .data_source => data_count += 1,
                .computation => comp_count += 1,
            }
        }
        
        return UnifiedState{
            .total_nodes = self.dag.nodes_len,
            .ast_nodes = ast_count,
            .dom_nodes = dom_count,
            .ui_components = ui_count,
            .data_sources = data_count,
            .computations = comp_count,
            .total_edges = self.dag.edges_len,
            .pending_events = self.dag.pending_events_len,
        };
    }
    
    /// Unified state statistics (editor + browser).
    pub const UnifiedState = struct {
        total_nodes: u32,
        ast_nodes: u32,
        dom_nodes: u32,
        ui_components: u32,
        data_sources: u32,
        computations: u32,
        total_edges: u32,
        pending_events: u32,
    };
};

test "browser dag integration initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var integration = BrowserDagIntegration.init(arena.allocator(), &dag);
    defer integration.deinit();
    
    // Assert: Integration initialized
    try std.testing.expect(integration.dag.nodes_len == 0);
    try std.testing.expect(integration.dag.edges_len == 0);
}

test "browser dag map dom node" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var integration = BrowserDagIntegration.init(arena.allocator(), &dag);
    defer integration.deinit();
    
    const dom_node = BrowserDagIntegration.DomNode{
        .tag_name = "div",
        .attributes = &.{},
        .children = &.{},
        .text_content = "Hello, World!",
    };
    
    const dag_node_id = try integration.mapDomNodeToDag(&dom_node, "https://example.com", null);
    
    // Assert: Node was created
    try std.testing.expect(dag_node_id >= 0);
    try std.testing.expect(integration.dag.nodes_len > 0);
    
    const node = integration.dag.getNode(dag_node_id);
    try std.testing.expect(node != null);
    try std.testing.expect(node.?.node_type == .dom_node);
}

test "browser dag map request to event" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var integration = BrowserDagIntegration.init(arena.allocator(), &dag);
    defer integration.deinit();
    
    const request = BrowserDagIntegration.WebRequest{
        .url = "https://example.com",
        .method = "GET",
        .headers = &.{},
        .body = null,
    };
    
    const event_id = try integration.mapRequestToEvent(request, &.{});
    
    // Assert: Event was created
    try std.testing.expect(event_id > 0);
    try std.testing.expect(integration.dag.pending_events_len == 1);
}

test "browser dag unified state" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var integration = BrowserDagIntegration.init(arena.allocator(), &dag);
    defer integration.deinit();
    
    // Add some DOM nodes
    const dom_node = BrowserDagIntegration.DomNode{
        .tag_name = "div",
        .attributes = &.{},
        .children = &.{},
        .text_content = "Test",
    };
    
    _ = try integration.mapDomNodeToDag(&dom_node, "https://example.com", null);
    
    const state = integration.getUnifiedState();
    
    // Assert: State reflects DOM nodes
    try std.testing.expect(state.total_nodes > 0);
    try std.testing.expect(state.dom_nodes > 0);
}

