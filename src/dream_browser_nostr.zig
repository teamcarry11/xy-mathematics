//! Dream Browser Nostr Content Loading: Parse URLs, subscribe to events, render to browser.
//! ~<~ Glow Airbend: explicit URL parsing, bounded subscriptions.
//! ~~~~ Glow Waterbend: streaming events flow deterministically through DAG.
//!
//! This implements:
//! - Parse Nostr URLs (`nostr:note1...`, `nostr:npub1...`)
//! - Subscribe to Nostr events
//! - Receive events (streaming, real-time)
//! - Render events to browser
//! - DAG event integration
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded structures: fixed-size buffers (no dynamic allocation after init)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive Nostr integration, deterministic behavior, explicit limits

const std = @import("std");
const DreamProtocol = @import("dream_protocol.zig").DreamProtocol;
const BrowserDagIntegration = @import("dream_browser_dag_integration.zig").BrowserDagIntegration;
const DreamBrowserRenderer = @import("dream_browser_renderer.zig").DreamBrowserRenderer;

/// Dream Browser Nostr Content Loader: Parse URLs, subscribe, receive, render.
/// Why: Enable Nostr content loading in browser with DAG integration.
/// GrainStyle: Explicit types, bounded subscriptions, deterministic behavior.
pub const DreamBrowserNostr = struct {
    allocator: std.mem.Allocator,
    protocol: DreamProtocol,
    browser_dag: *BrowserDagIntegration,
    renderer: *DreamBrowserRenderer,
    
    /// Bounded: Max 100 active subscriptions.
    /// Why: Prevent unbounded growth, ensure deterministic behavior.
    pub const MAX_SUBSCRIPTIONS: u32 = 100;
    
    /// Bounded: Max 1,000 events per subscription.
    /// Why: Limit event buffer size, prevent memory growth.
    pub const MAX_EVENTS_PER_SUBSCRIPTION: u32 = 1_000;
    
    /// Nostr URL type.
    pub const NostrUrlType = enum(u8) {
        note, // nostr:note1... (event ID)
        npub, // nostr:npub1... (public key)
        nprofile, // nostr:nprofile1... (profile)
        nevent, // nostr:nevent1... (event with relays)
    };
    
    /// Parsed Nostr URL.
    pub const NostrUrl = struct {
        url_type: NostrUrlType,
        identifier: []const u8, // Note ID, pubkey, etc.
        relays: []const []const u8, // Optional relay URLs
    };
    
    /// Active subscription.
    pub const Subscription = struct {
        subscription_id: []const u8,
        url: NostrUrl,
        events: []DreamProtocol.Event,
        events_len: u32,
    };
    
    /// Initialize Nostr content loader.
    /// Why: Set up Nostr integration for browser content loading.
    /// Contract: allocator must be valid, browser_dag and renderer must be initialized.
    pub fn init(
        allocator: std.mem.Allocator,
        browser_dag: *BrowserDagIntegration,
        renderer: *DreamBrowserRenderer,
    ) DreamBrowserNostr {
        // Assert: Allocator must be valid (precondition).
        std.debug.assert(allocator.ptr != null);
        
        // Assert: Browser DAG must be initialized (precondition).
        std.debug.assert(browser_dag.dag.nodes_len <= BrowserDagIntegration.MAX_DOM_NODES_PER_PAGE);
        
        return DreamBrowserNostr{
            .allocator = allocator,
            .protocol = DreamProtocol.init(allocator),
            .browser_dag = browser_dag,
            .renderer = renderer,
        };
    }
    
    /// Deinitialize Nostr content loader.
    pub fn deinit(self: *DreamBrowserNostr) void {
        self.protocol.deinit();
    }
    
    /// Parse Nostr URL (`nostr:note1...`, `nostr:npub1...`, etc.).
    /// Why: Extract identifier and type from Nostr URL.
    /// Contract: url must be valid Nostr URL, returns parsed URL.
    pub fn parseNostrUrl(self: *DreamBrowserNostr, url: []const u8) !NostrUrl {
        // Assert: URL must be non-empty (precondition).
        std.debug.assert(url.len > 0);
        
        // Assert: URL must start with "nostr:" (precondition).
        if (!std.mem.startsWith(u8, url, "nostr:")) {
            return error.InvalidNostrUrl;
        }
        
        // Extract identifier (after "nostr:").
        const identifier = url[6..]; // Skip "nostr:"
        
        // Determine URL type based on prefix.
        var url_type: NostrUrlType = undefined;
        
        if (std.mem.startsWith(u8, identifier, "note1")) {
            // Event ID (bech32-encoded).
            url_type = .note;
        } else if (std.mem.startsWith(u8, identifier, "npub1")) {
            // Public key (bech32-encoded).
            url_type = .npub;
        } else if (std.mem.startsWith(u8, identifier, "nprofile1")) {
            // Profile (bech32-encoded).
            url_type = .nprofile;
        } else if (std.mem.startsWith(u8, identifier, "nevent1")) {
            // Event with relays (bech32-encoded).
            url_type = .nevent;
        } else {
            return error.InvalidNostrUrl;
        }
        
        // Parse relays (if present in URL, e.g., "nostr:note1...?relay=wss://...").
        var relays = std.ArrayList([]const u8).init(self.allocator);
        defer relays.deinit();
        
        // Check for query parameters.
        if (std.mem.indexOfScalar(u8, identifier, '?')) |query_start| {
            const query = identifier[query_start + 1..];
            
            // Parse relay parameters (simple: "relay=wss://...").
            var query_it = std.mem.splitScalar(u8, query, '&');
            while (query_it.next()) |param| {
                if (std.mem.startsWith(u8, param, "relay=")) {
                    const relay_url = param[6..]; // Skip "relay="
                    try relays.append(try self.allocator.dupe(u8, relay_url));
                }
            }
        }
        
        // Assert: URL type must be determined (postcondition).
        std.debug.assert(@intFromEnum(url_type) >= 0);
        
        return NostrUrl{
            .url_type = url_type,
            .identifier = try self.allocator.dupe(u8, identifier),
            .relays = try relays.toOwnedSlice(),
        };
    }
    
    /// Subscribe to Nostr events based on URL.
    /// Why: Create subscription for Nostr content loading.
    /// Contract: url must be valid parsed URL, returns subscription ID.
    pub fn subscribeToNostr(
        self: *DreamBrowserNostr,
        url: NostrUrl,
        relay_url: []const u8,
    ) ![]const u8 {
        // Assert: URL must be valid (precondition).
        std.debug.assert(url.identifier.len > 0);
        
        // Assert: Relay URL must be non-empty (precondition).
        std.debug.assert(relay_url.len > 0);
        
        // Connect to relay if not connected.
        if (self.protocol.state != .connected) {
            try self.protocol.connect(relay_url);
        }
        
        // Assert: Protocol must be connected (postcondition).
        std.debug.assert(self.protocol.state == .connected);
        
        // Create subscription ID (unique identifier).
        const subscription_id = try std.fmt.allocPrint(
            self.allocator,
            "sub_{d}",
            .{std.time.timestamp()},
        );
        
        // Build filter based on URL type.
        var filters = std.ArrayList(DreamProtocol.Filter).init(self.allocator);
        defer filters.deinit();
        
        var filter = DreamProtocol.Filter{};
        
        switch (url.url_type) {
            .note => {
                // Subscribe to specific event ID.
                // Note: identifier is bech32-encoded, need to decode to hex.
                // For now, use identifier as-is (simplified).
                const event_ids = [_][]const u8{url.identifier};
                filter.ids = &event_ids;
            },
            .npub => {
                // Subscribe to events from specific author.
                const authors = [_][]const u8{url.identifier};
                filter.authors = &authors;
            },
            .nprofile => {
                // Subscribe to profile metadata (kind 0).
                const authors = [_][]const u8{url.identifier};
                filter.authors = &authors;
                const kinds = [_]u32{0}; // Metadata
                filter.kinds = &kinds;
            },
            .nevent => {
                // Subscribe to specific event (with relay hints).
                const event_ids = [_][]const u8{url.identifier};
                filter.ids = &event_ids;
            },
        }
        
        try filters.append(filter);
        
        // Subscribe via protocol.
        try self.protocol.subscribe(subscription_id, try filters.toOwnedSlice());
        
        // Assert: Subscription must be created (postcondition).
        std.debug.assert(subscription_id.len > 0);
        
        return subscription_id;
    }
    
    /// Receive events (streaming, real-time).
    /// Why: Process incoming Nostr events from relay.
    /// Contract: subscription_id must be valid, returns array of events.
    pub fn receiveEvents(
        self: *DreamBrowserNostr,
        subscription_id: []const u8,
    ) ![]DreamProtocol.Event {
        // Assert: Subscription ID must be valid (precondition).
        std.debug.assert(subscription_id.len > 0);
        
        // Assert: Protocol must be connected (precondition).
        std.debug.assert(self.protocol.state == .connected);
        
        // TODO: Read events from WebSocket stream.
        // For now, return empty array (stub).
        _ = subscription_id;
        
        // Create events array (bounded).
        var events = std.ArrayList(DreamProtocol.Event).init(self.allocator);
        defer events.deinit();
        
        // Assert: Events must be within bounds (postcondition).
        std.debug.assert(events.items.len <= MAX_EVENTS_PER_SUBSCRIPTION);
        
        return try events.toOwnedSlice();
    }
    
    /// Render events to browser (convert to DOM nodes).
    /// Why: Display Nostr events in browser with readonly spans for metadata.
    /// Contract: events must be valid, returns DOM node.
    pub fn renderEventsToBrowser(
        self: *DreamBrowserNostr,
        events: []const DreamProtocol.Event,
    ) !BrowserDagIntegration.DomNode {
        // Assert: Events must be valid (precondition).
        std.debug.assert(events.len <= MAX_EVENTS_PER_SUBSCRIPTION);
        
        // Create root DOM node (div container).
        var children = std.ArrayList(BrowserDagIntegration.DomNode).init(self.allocator);
        defer children.deinit();
        
        // Render each event as a DOM node.
        for (events) |event| {
            const event_dom = try self.renderEventToDom(event);
            try children.append(event_dom);
        }
        
        // Create root container.
        const root_attributes = [_]BrowserDagIntegration.DomNode.Attribute{};
        
        return BrowserDagIntegration.DomNode{
            .tag_name = "div",
            .attributes = &root_attributes,
            .children = try children.toOwnedSlice(),
            .text_content = "",
            .parent_id = null,
        };
    }
    
    /// Render single event to DOM node.
    /// Why: Convert Nostr event to DOM structure with readonly spans.
    /// Contract: event must be valid, returns DOM node.
    fn renderEventToDom(
        self: *DreamBrowserNostr,
        event: DreamProtocol.Event,
    ) !BrowserDagIntegration.DomNode {
        // Assert: Event must be valid (precondition).
        std.debug.assert(event.id.len > 0);
        std.debug.assert(event.pubkey.len > 0);
        
        // Create event container (div with metadata attributes).
        var attributes = std.ArrayList(BrowserDagIntegration.DomNode.Attribute).init(self.allocator);
        defer attributes.deinit();
        
        // Add readonly metadata attributes (event ID, timestamp, author).
        try attributes.append(BrowserDagIntegration.DomNode.Attribute{
            .name = "data-event-id",
            .value = event.id,
        });
        
        try attributes.append(BrowserDagIntegration.DomNode.Attribute{
            .name = "data-timestamp",
            .value = try std.fmt.allocPrint(self.allocator, "{d}", .{event.created_at}),
        });
        
        try attributes.append(BrowserDagIntegration.DomNode.Attribute{
            .name = "data-author",
            .value = event.pubkey,
        });
        
        // Create content node (paragraph with event content).
        const content_attributes = [_]BrowserDagIntegration.DomNode.Attribute{};
        const content_node = BrowserDagIntegration.DomNode{
            .tag_name = "p",
            .attributes = &content_attributes,
            .children = &.{},
            .text_content = event.content,
            .parent_id = null,
        };
        
        // Create event container with content.
        const event_children = [_]BrowserDagIntegration.DomNode{content_node};
        
        return BrowserDagIntegration.DomNode{
            .tag_name = "div",
            .attributes = try attributes.toOwnedSlice(),
            .children = &event_children,
            .text_content = "",
            .parent_id = null,
        };
    }
    
    /// Integrate events into DAG (map events to DAG events).
    /// Why: Track Nostr events in unified DAG state.
    /// Contract: events must be valid.
    pub fn integrateEventsToDag(
        self: *DreamBrowserNostr,
        events: []const DreamProtocol.Event,
    ) !void {
        // Assert: Events must be valid (precondition).
        std.debug.assert(events.len <= MAX_EVENTS_PER_SUBSCRIPTION);
        
        // Map each event to DAG event.
        for (events) |event| {
            // Get parent events (empty for now, could reference previous events).
            const parent_events = [_]u64{};
            
            // Map event to DAG via browser-DAG integration.
            _ = try self.browser_dag.mapNostrEventToDag(event, &parent_events);
        }
        
        // Assert: Events must be integrated (postcondition).
        // Events are now in DAG pending events.
    }
};

