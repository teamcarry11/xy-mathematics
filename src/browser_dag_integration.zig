//! Browser-DAG Integration: Maps DOM nodes to DAG nodes, web requests to DAG events.
//! ~<~ Glow Airbend: explicit DOM-to-DAG mapping, bounded conversions.
//! ~~~~ Glow Waterbend: web requests stream through DAG deterministically.
//!
//! This implements unified editor+browser state:
//! - DOM nodes become DAG nodes (unified semantic graph)
//! - Web requests become DAG events (HashDAG-style ordering)
//! - Streaming updates (real-time propagation)
//! - Unified state (editor + browser share same DAG)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded structures: fixed-size buffers (no dynamic allocation after init)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive DOM-to-DAG mapping, deterministic behavior, explicit limits

const std = @import("std");
const DagCore = @import("dag_core.zig").DagCore;

/// Browser-DAG Integration: Maps DOM nodes to DAG nodes, web requests to DAG events.
/// Why: Enable unified state between editor and browser via shared DAG.
/// GrainStyle: Explicit types, bounded conversions, deterministic mapping.
pub const BrowserDagIntegration = struct {
    allocator: std.mem.Allocator,
    dag: *DagCore,
    
    /// Bounded: Max 1,000 DOM nodes per page.
    /// Why: Prevent unbounded growth, ensure deterministic behavior.
    pub const MAX_DOM_NODES_PER_PAGE: u32 = 1_000;
    
    /// Bounded: Max 100 web requests per second.
    /// Why: Rate limiting prevents DAG overflow, ensures real-time performance.
    pub const MAX_REQUESTS_PER_SECOND: u32 = 100;
    
    /// DOM node representation (simplified for DAG mapping).
    /// Why: Capture DOM structure for DAG integration.
    /// GrainStyle: Explicit types, bounded size, deterministic encoding.
    pub const DOMNode = struct {
        /// Node ID (unique within page).
        id: u32,
        /// Node type (element, text, comment, etc.).
        node_type: DOMNodeType,
        /// Tag name (for element nodes).
        tag_name: []const u8,
        /// Text content (for text nodes).
        text_content: []const u8,
        /// Attributes (key-value pairs).
        attributes: []const u8,
        /// Parent node ID (0 = root).
        parent_id: u32,
        /// Child node IDs (bounded array).
        children: []const u32,
    };
    
    /// DOM node type.
    pub const DOMNodeType = enum(u8) {
        element, // HTML element (<div>, <p>, etc.)
        text, // Text node
        comment, // Comment node
        document, // Document root
    };
    
    /// Web request representation (for DAG event mapping).
    /// Why: Capture web requests as DAG events for unified state.
    /// GrainStyle: Explicit types, bounded size, deterministic encoding.
    pub const WebRequest = struct {
        /// Request URL.
        url: []const u8,
        /// Request method (GET, POST, etc.).
        method: []const u8,
        /// Request headers (key-value pairs).
        headers: []const u8,
        /// Request body (for POST/PUT).
        body: []const u8,
        /// Response status code.
        status_code: u32,
        /// Response body.
        response_body: []const u8,
        /// Timestamp (Unix seconds).
        timestamp: u64,
    };
    
    /// Initialize browser-DAG integration.
    /// Why: Set up DOM-to-DAG mapping for unified state.
    /// Contract: allocator must be valid, dag must be initialized.
    pub fn init(allocator: std.mem.Allocator, dag: *DagCore) BrowserDagIntegration {
        // Assert: Allocator must be valid (precondition).
        std.debug.assert(allocator.ptr != null);
        
        // Assert: DAG must be initialized (precondition).
        std.debug.assert(dag.nodes_len <= DagCore.MAX_NODES);
        
        return BrowserDagIntegration{
            .allocator = allocator,
            .dag = dag,
        };
    }
    
    /// Map DOM node to DAG node.
    /// Why: Integrate DOM structure into unified DAG (editor + browser).
    /// Contract: dom_node must be valid, returns DAG node ID.
    pub fn mapDomNodeToDag(
        self: *BrowserDagIntegration,
        dom_node: DOMNode,
    ) !u32 {
        // Assert: DOM node must be valid (precondition).
        std.debug.assert(dom_node.id > 0);
        std.debug.assert(dom_node.id <= MAX_DOM_NODES_PER_PAGE);
        
        // Assert: DAG must have capacity (precondition).
        std.debug.assert(self.dag.nodes_len < DagCore.MAX_NODES);
        
        // Create node data (serialize DOM node info).
        var node_data = std.ArrayList(u8).init(self.allocator);
        defer node_data.deinit();
        
        const writer = node_data.writer();
        try writer.print("dom:{d}:", .{dom_node.id});
        try writer.print("type:{s}:", .{@tagName(dom_node.node_type)});
        try writer.print("tag:{s}:", .{dom_node.tag_name});
        try writer.print("text:{d}:", .{dom_node.text_content.len});
        try writer.writeAll(dom_node.text_content);
        try writer.print("attrs:{d}:", .{dom_node.attributes.len});
        try writer.writeAll(dom_node.attributes);
        
        // Add node to DAG (dom_node type).
        const node_id = try self.dag.addNode(
            .dom_node,
            try node_data.toOwnedSlice(),
        );
        
        // Assert: Node must be added (postcondition).
        std.debug.assert(node_id > 0);
        std.debug.assert(node_id <= DagCore.MAX_NODES);
        
        // Add dependency edge from parent (if not root).
        if (dom_node.parent_id > 0) {
            const parent_dag_id = self.findDagNodeForDomId(dom_node.parent_id);
            if (parent_dag_id) |parent_id| {
                // Add dependency edge (parent -> child).
                try self.dag.addEdge(
                    parent_id,
                    node_id,
                    .dependency,
                );
            }
        }
        
        // Assert: Node must be in DAG (postcondition).
        const dag_node = self.dag.getNode(node_id);
        std.debug.assert(dag_node != null);
        
        return node_id;
    }
    
    /// Map web request to DAG event.
    /// Why: Track web requests as DAG events for unified state.
    /// Contract: request must be valid, parent_events must be valid.
    pub fn mapWebRequestToDag(
        self: *BrowserDagIntegration,
        request: WebRequest,
        parent_events: []const u64,
    ) !u64 {
        // Assert: Request must be valid (precondition).
        std.debug.assert(request.url.len > 0);
        std.debug.assert(request.method.len > 0);
        
        // Assert: Request rate must be within bounds (precondition).
        // TODO: Implement rate limiting (MAX_REQUESTS_PER_SECOND).
        
        // Create event data (serialize web request info).
        var event_data = std.ArrayList(u8).init(self.allocator);
        defer event_data.deinit();
        
        const writer = event_data.writer();
        try writer.print("url:{d}:", .{request.url.len});
        try writer.writeAll(request.url);
        try writer.print("method:{s}:", .{request.method});
        try writer.print("status:{d}:", .{request.status_code});
        try writer.print("response:{d}:", .{request.response_body.len});
        try writer.writeAll(request.response_body);
        
        // Find or create DAG node for URL (data source node).
        const url_node_id = try self.getOrCreateUrlNode(request.url);
        
        // Add event to DAG (web_request type, HashDAG-style with parent references).
        const event_id = try self.dag.addEvent(
            .web_request,
            url_node_id,
            try event_data.toOwnedSlice(),
            parent_events,
        );
        
        // Assert: Event must be added (postcondition).
        std.debug.assert(event_id > 0);
        
        return event_id;
    }
    
    /// Get or create DAG node for URL (data source node).
    /// Why: Represent URLs as DAG nodes for dependency tracking.
    /// Contract: url must be non-empty, returns DAG node ID.
    fn getOrCreateUrlNode(
        self: *BrowserDagIntegration,
        url: []const u8,
    ) !u32 {
        // Assert: URL must be non-empty (precondition).
        std.debug.assert(url.len > 0);
        
        // Search for existing URL node (simple linear search, bounded).
        // Why: URLs are data sources, should be unique per URL.
        var i: u32 = 0;
        while (i < self.dag.nodes_len) : (i += 1) {
            const node = &self.dag.nodes[i];
            if (node.node_type == .data_source) {
                // Check if node data starts with "url:" and matches.
                if (std.mem.startsWith(u8, node.data, "url:")) {
                    const url_start = 4; // Skip "url:"
                    if (url_start < node.data_len) {
                        const node_url = node.data[url_start..];
                        if (std.mem.eql(u8, node_url, url)) {
                            // Found existing URL node.
                            return node.id;
                        }
                    }
                }
            }
        }
        
        // Create new URL node (data source type).
        var node_data = std.ArrayList(u8).init(self.allocator);
        defer node_data.deinit();
        
        const writer = node_data.writer();
        try writer.print("url:");
        try writer.writeAll(url);
        
        const node_id = try self.dag.addNode(
            .data_source,
            try node_data.toOwnedSlice(),
        );
        
        // Assert: Node must be created (postcondition).
        std.debug.assert(node_id > 0);
        
        return node_id;
    }
    
    /// Find DAG node ID for DOM node ID.
    /// Why: Lookup DAG node corresponding to DOM node for edge creation.
    /// Contract: dom_id must be valid, returns DAG node ID or null.
    fn findDagNodeForDomId(self: *BrowserDagIntegration, dom_id: u32) ?u32 {
        // Assert: DOM ID must be valid (precondition).
        std.debug.assert(dom_id > 0);
        std.debug.assert(dom_id <= MAX_DOM_NODES_PER_PAGE);
        
        // Search for DAG node with matching DOM ID (bounded search).
        var i: u32 = 0;
        while (i < self.dag.nodes_len) : (i += 1) {
            const node = &self.dag.nodes[i];
            if (node.node_type == .dom_node) {
                // Check if node data contains matching DOM ID.
                if (std.mem.startsWith(u8, node.data, "dom:")) {
                    const dom_id_start = 4; // Skip "dom:"
                    if (dom_id_start < node.data_len) {
                        // Parse DOM ID from node data.
                        const dom_id_str = node.data[dom_id_start..];
                        const parsed_dom_id = std.fmt.parseInt(u32, dom_id_str, 10) catch continue;
                        if (parsed_dom_id == dom_id) {
                            // Found matching DOM node.
                            return node.id;
                        }
                    }
                }
            }
        }
        
        // Not found.
        return null;
    }
    
    /// Process streaming updates (real-time).
    /// Why: Propagate DOM changes and web requests through DAG in real-time.
    /// Contract: DAG must be initialized.
    pub fn processStreamingUpdates(self: *BrowserDagIntegration) !void {
        // Assert: DAG must be initialized (precondition).
        std.debug.assert(self.dag.nodes_len <= DagCore.MAX_NODES);
        
        // Process pending events in DAG (TigerBeetle-style state machine).
        try self.dag.processEvents();
        
        // Assert: Events must be processed (postcondition).
        std.debug.assert(self.dag.pending_events_len == 0);
    }
    
    /// Get unified state (editor + browser).
    /// Why: Query unified DAG state for both editor and browser nodes.
    /// Returns: Total node count in unified DAG.
    pub fn getUnifiedState(self: *const BrowserDagIntegration) u32 {
        // Assert: DAG must be initialized (precondition).
        std.debug.assert(self.dag.nodes_len <= DagCore.MAX_NODES);
        
        // Return total node count (editor + browser nodes).
        return self.dag.nodes_len;
    }
    
    /// Get browser nodes count (DOM nodes + data sources).
    /// Why: Query browser-specific nodes in unified DAG.
    /// Returns: Count of browser-related nodes.
    pub fn getBrowserNodesCount(self: *const BrowserDagIntegration) u32 {
        // Assert: DAG must be initialized (precondition).
        std.debug.assert(self.dag.nodes_len <= DagCore.MAX_NODES);
        
        // Count browser-related nodes (dom_node + data_source types).
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.dag.nodes_len) : (i += 1) {
            const node = &self.dag.nodes[i];
            if (node.node_type == .dom_node or node.node_type == .data_source) {
                count += 1;
            }
        }
        
        // Assert: Count must be valid (postcondition).
        std.debug.assert(count <= self.dag.nodes_len);
        
        return count;
    }
};

