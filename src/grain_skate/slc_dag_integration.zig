//! Grain Skate SLC DAG Integration: DAG core integration for SLC products.
//!
//! Why: Provide DAG integration helpers for Nostr Profile Builder and DAG Website Builder.
//! Architecture: DAG node/edge mapping for profiles and websites.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-161207-pst: Active implementation

const std = @import("std");
const DagCore = @import("../dag_core.zig").DagCore;

// Re-export DagCore types for convenience
pub const DagCoreAttributes = DagCore.Attributes;

/// SLC DAG Integration: DAG helpers for Nostr profiles and DAG websites.
pub const SlcDagIntegration = struct {
    allocator: std.mem.Allocator,
    dag: DagCore,
    
    // Bounded: Max 10,000 profile relationships
    pub const MAX_PROFILE_RELATIONSHIPS: u32 = 10_000;
    
    // Bounded: Max 1,000 website pages
    pub const MAX_WEBSITE_PAGES: u32 = 1_000;
    
    /// Profile relationship type.
    pub const ProfileRelationship = enum(u8) {
        follows, // Profile follows another profile
        followed_by, // Profile is followed by another profile
        mentions, // Profile mentions another profile
        reposts, // Profile reposts content from another profile
    };
    
    /// Website page structure.
    pub const WebsitePage = struct {
        page_id: u32, // Page ID (DAG node ID)
        title: []const u8, // Page title
        title_len: u32,
        content: []const u8, // Page content
        content_len: u32,
        url_path: []const u8, // URL path (e.g., "/about", "/contact")
        url_path_len: u32,
    };
    
    /// Initialize SLC DAG integration.
    pub fn init(allocator: std.mem.Allocator) !SlcDagIntegration {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        const dag = try DagCore.init(allocator);
        errdefer dag.deinit();
        
        return SlcDagIntegration{
            .allocator = allocator,
            .dag = dag,
        };
    }
    
    /// Deinitialize SLC DAG integration.
    pub fn deinit(self: *SlcDagIntegration) void {
        self.dag.deinit();
        self.* = undefined;
    }
    
    /// Create DAG node for Nostr profile.
    /// Returns DAG node ID for the profile.
    pub fn create_profile_node(
        self: *SlcDagIntegration,
        npub: []const u8,
        name: []const u8,
    ) !u32 {
        // Assert: NPUB and name must be bounded
        std.debug.assert(npub.len <= 128);
        std.debug.assert(name.len <= 256);
        
        // Create profile data (JSON-like structure for now)
        var profile_data = std.ArrayList(u8).init(self.allocator);
        defer profile_data.deinit();
        
        try std.fmt.format(profile_data.writer(), "{{\"npub\":\"{s}\",\"name\":\"{s}\"}}", .{ npub, name });
        
        const profile_data_slice = try self.allocator.dupe(u8, profile_data.items);
        errdefer self.allocator.free(profile_data_slice);
        
        // Create DAG node with data_source type
        const node_id = try self.dag.addNode(
            .data_source,
            profile_data_slice,
            DagCore.Attributes{},
        );
        
        // Assert: Node ID is valid
        std.debug.assert(node_id > 0);
        
        return node_id;
    }
    
    /// Create profile relationship edge (follows, mentions, etc.).
    pub fn create_profile_relationship(
        self: *SlcDagIntegration,
        from_profile_id: u32,
        to_profile_id: u32,
        relationship: ProfileRelationship,
    ) !void {
        // Assert: Profile IDs must be valid
        std.debug.assert(from_profile_id > 0);
        std.debug.assert(to_profile_id > 0);
        std.debug.assert(from_profile_id != to_profile_id);
        
        // Create edge with semantic type for relationships
        try self.dag.addEdge(
            from_profile_id,
            to_profile_id,
            .semantic,
        );
        
        // Assert: Edge count is within bounds
        std.debug.assert(self.dag.edges_len <= MAX_PROFILE_RELATIONSHIPS);
    }
    
    /// Create DAG node for website page.
    /// Returns DAG node ID for the page.
    pub fn create_website_page_node(
        self: *SlcDagIntegration,
        title: []const u8,
        content: []const u8,
        url_path: []const u8,
    ) !u32 {
        // Assert: Title, content, and URL path must be bounded
        std.debug.assert(title.len <= 256);
        std.debug.assert(content.len <= 100_000); // Max 100KB per page
        std.debug.assert(url_path.len <= 512);
        
        // Create page data (JSON-like structure for now)
        var page_data = std.ArrayList(u8).init(self.allocator);
        defer page_data.deinit();
        
        try std.fmt.format(
            page_data.writer(),
            "{{\"title\":\"{s}\",\"content\":\"{s}\",\"url_path\":\"{s}\"}}",
            .{ title, content, url_path },
        );
        
        const page_data_slice = try self.allocator.dupe(u8, page_data.items);
        errdefer self.allocator.free(page_data_slice);
        
        // Create DAG node with data_source type
        const node_id = try self.dag.addNode(
            .data_source,
            page_data_slice,
            DagCore.Attributes{},
        );
        
        // Assert: Node ID is valid
        std.debug.assert(node_id > 0);
        std.debug.assert(self.dag.nodes_len <= MAX_WEBSITE_PAGES);
        
        return node_id;
    }
    
    /// Create link between website pages (DAG edge).
    pub fn create_website_link(
        self: *SlcDagIntegration,
        from_page_id: u32,
        to_page_id: u32,
    ) !void {
        // Assert: Page IDs must be valid
        std.debug.assert(from_page_id > 0);
        std.debug.assert(to_page_id > 0);
        std.debug.assert(from_page_id != to_page_id);
        
        // Create edge with semantic type for links
        try self.dag.addEdge(
            from_page_id,
            to_page_id,
            .semantic,
        );
        
        // Assert: Edge count is within bounds
        std.debug.assert(self.dag.edges_len <= MAX_WEBSITE_PAGES * 10); // Max 10 links per page
    }
    
    /// Get all profiles that a profile follows.
    /// Returns array of profile node IDs.
    pub fn get_following_profiles(
        self: *const SlcDagIntegration,
        profile_id: u32,
        following_ids: []u32,
    ) u32 {
        // Assert: Profile ID must be valid
        std.debug.assert(profile_id > 0);
        std.debug.assert(following_ids.len > 0);
        
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.dag.edges_len and count < following_ids.len) : (i += 1) {
            const edge = self.dag.edges[i];
            if (edge.from_node == profile_id and edge.edge_type == .semantic) {
                following_ids[count] = edge.to_node;
                count += 1;
            }
        }
        
        // Assert: Count is within bounds
        std.debug.assert(count <= following_ids.len);
        
        return count;
    }
    
    /// Get all pages linked from a page.
    /// Returns array of page node IDs.
    pub fn get_linked_pages(
        self: *const SlcDagIntegration,
        page_id: u32,
        linked_page_ids: []u32,
    ) u32 {
        // Assert: Page ID must be valid
        std.debug.assert(page_id > 0);
        std.debug.assert(linked_page_ids.len > 0);
        
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.dag.edges_len and count < linked_page_ids.len) : (i += 1) {
            const edge = self.dag.edges[i];
            if (edge.from_node == page_id and edge.edge_type == .semantic) {
                linked_page_ids[count] = edge.to_node;
                count += 1;
            }
        }
        
        // Assert: Count is within bounds
        std.debug.assert(count <= linked_page_ids.len);
        
        return count;
    }
    
    /// Get all profiles that follow a profile (reverse lookup).
    /// Returns array of profile node IDs.
    pub fn get_follower_profiles(
        self: *const SlcDagIntegration,
        profile_id: u32,
        follower_ids: []u32,
    ) u32 {
        // Assert: Profile ID must be valid
        std.debug.assert(profile_id > 0);
        std.debug.assert(follower_ids.len > 0);
        
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.dag.edges_len and count < follower_ids.len) : (i += 1) {
            const edge = self.dag.edges[i];
            if (edge.to_node == profile_id and edge.edge_type == .semantic) {
                follower_ids[count] = edge.from_node;
                count += 1;
            }
        }
        
        // Assert: Count is within bounds
        std.debug.assert(count <= follower_ids.len);
        
        return count;
    }
    
    /// Get all pages that link to a page (backlinks/reverse lookup).
    /// Returns array of page node IDs.
    pub fn get_backlink_pages(
        self: *const SlcDagIntegration,
        page_id: u32,
        backlink_page_ids: []u32,
    ) u32 {
        // Assert: Page ID must be valid
        std.debug.assert(page_id > 0);
        std.debug.assert(backlink_page_ids.len > 0);
        
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.dag.edges_len and count < backlink_page_ids.len) : (i += 1) {
            const edge = self.dag.edges[i];
            if (edge.to_node == page_id and edge.edge_type == .semantic) {
                backlink_page_ids[count] = edge.from_node;
                count += 1;
            }
        }
        
        // Assert: Count is within bounds
        std.debug.assert(count <= backlink_page_ids.len);
        
        return count;
    }
    
    /// Get total number of relationships for a profile (following + followers).
    /// Returns count of total relationships.
    pub fn get_profile_relationship_count(
        self: *const SlcDagIntegration,
        profile_id: u32,
    ) u32 {
        // Assert: Profile ID must be valid
        std.debug.assert(profile_id > 0);
        
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.dag.edges_len) : (i += 1) {
            const edge = self.dag.edges[i];
            if (edge.edge_type == .semantic) {
                if (edge.from_node == profile_id or edge.to_node == profile_id) {
                    count += 1;
                }
            }
        }
        
        return count;
    }
    
    /// Get total number of links for a page (outgoing + incoming).
    /// Returns count of total links.
    pub fn get_page_link_count(
        self: *const SlcDagIntegration,
        page_id: u32,
    ) u32 {
        // Assert: Page ID must be valid
        std.debug.assert(page_id > 0);
        
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.dag.edges_len) : (i += 1) {
            const edge = self.dag.edges[i];
            if (edge.edge_type == .semantic) {
                if (edge.from_node == page_id or edge.to_node == page_id) {
                    count += 1;
                }
            }
        }
        
        return count;
    }
    
    /// Get profile node data (raw JSON string).
    /// Returns node data if profile exists, null otherwise.
    pub fn get_profile_data(
        self: *const SlcDagIntegration,
        profile_id: u32,
    ) ?[]const u8 {
        // Assert: Profile ID must be valid
        std.debug.assert(profile_id > 0);
        
        const node = self.dag.getNode(profile_id) orelse return null;
        
        // Return node data (JSON string)
        return node.data[0..node.data_len];
    }
    
    /// Get website page node data (raw JSON string).
    /// Returns node data if page exists, null otherwise.
    pub fn get_page_data(
        self: *const SlcDagIntegration,
        page_id: u32,
    ) ?[]const u8 {
        // Assert: Page ID must be valid
        std.debug.assert(page_id > 0);
        
        const node = self.dag.getNode(page_id) orelse return null;
        
        // Return node data (JSON string)
        return node.data[0..node.data_len];
    }
    
    /// Check if profile relationship exists.
    /// Returns true if relationship exists, false otherwise.
    pub fn has_profile_relationship(
        self: *const SlcDagIntegration,
        from_profile_id: u32,
        to_profile_id: u32,
    ) bool {
        // Assert: Profile IDs must be valid
        std.debug.assert(from_profile_id > 0);
        std.debug.assert(to_profile_id > 0);
        
        var i: u32 = 0;
        while (i < self.dag.edges_len) : (i += 1) {
            const edge = self.dag.edges[i];
            if (edge.from_node == from_profile_id and
                edge.to_node == to_profile_id and
                edge.edge_type == .semantic) {
                return true;
            }
        }
        
        return false;
    }
    
    /// Check if website link exists.
    /// Returns true if link exists, false otherwise.
    pub fn has_website_link(
        self: *const SlcDagIntegration,
        from_page_id: u32,
        to_page_id: u32,
    ) bool {
        // Assert: Page IDs must be valid
        std.debug.assert(from_page_id > 0);
        std.debug.assert(to_page_id > 0);
        
        var i: u32 = 0;
        while (i < self.dag.edges_len) : (i += 1) {
            const edge = self.dag.edges[i];
            if (edge.from_node == from_page_id and
                edge.to_node == to_page_id and
                edge.edge_type == .semantic) {
                return true;
            }
        }
        
        return false;
    }
};

test "slc dag integration initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try SlcDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    // Assert: Integration initialized
    try std.testing.expect(integration.dag.nodes_len == 0);
    try std.testing.expect(integration.dag.edges_len == 0);
}

test "slc dag integration profile node creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try SlcDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const npub = "npub1example";
    const name = "Test Profile";
    
    const profile_id = try integration.create_profile_node(npub, name);
    
    // Assert: Profile node created
    try std.testing.expect(profile_id > 0);
    try std.testing.expect(integration.dag.nodes_len == 1);
}

test "slc dag integration profile relationship" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try SlcDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const profile1_id = try integration.create_profile_node("npub1", "Profile 1");
    const profile2_id = try integration.create_profile_node("npub2", "Profile 2");
    
    try integration.create_profile_relationship(profile1_id, profile2_id, .follows);
    
    // Assert: Relationship created
    try std.testing.expect(integration.dag.edges_len == 1);
    try std.testing.expect(integration.dag.edges[0].from_node == profile1_id);
    try std.testing.expect(integration.dag.edges[0].to_node == profile2_id);
}

test "slc dag integration website page creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try SlcDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const title = "About Page";
    const content = "This is the about page content.";
    const url_path = "/about";
    
    const page_id = try integration.create_website_page_node(title, content, url_path);
    
    // Assert: Page node created
    try std.testing.expect(page_id > 0);
    try std.testing.expect(integration.dag.nodes_len == 1);
}

test "slc dag integration website link" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try SlcDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const page1_id = try integration.create_website_page_node("Home", "Content", "/");
    const page2_id = try integration.create_website_page_node("About", "Content", "/about");
    
    try integration.create_website_link(page1_id, page2_id);
    
    // Assert: Link created
    try std.testing.expect(integration.dag.edges_len == 1);
    try std.testing.expect(integration.dag.edges[0].from_node == page1_id);
    try std.testing.expect(integration.dag.edges[0].to_node == page2_id);
}

test "slc dag integration get following profiles" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try SlcDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const profile1_id = try integration.create_profile_node("npub1", "Profile 1");
    const profile2_id = try integration.create_profile_node("npub2", "Profile 2");
    const profile3_id = try integration.create_profile_node("npub3", "Profile 3");
    
    try integration.create_profile_relationship(profile1_id, profile2_id, .follows);
    try integration.create_profile_relationship(profile1_id, profile3_id, .follows);
    
    var following: [10]u32 = undefined;
    const count = integration.get_following_profiles(profile1_id, &following);
    
    // Assert: Following profiles retrieved
    try std.testing.expect(count == 2);
    try std.testing.expect((following[0] == profile2_id and following[1] == profile3_id) or
                           (following[0] == profile3_id and following[1] == profile2_id));
}

test "slc dag integration get linked pages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try SlcDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const page1_id = try integration.create_website_page_node("Home", "Content", "/");
    const page2_id = try integration.create_website_page_node("About", "Content", "/about");
    const page3_id = try integration.create_website_page_node("Contact", "Content", "/contact");
    
    try integration.create_website_link(page1_id, page2_id);
    try integration.create_website_link(page1_id, page3_id);
    
    var linked: [10]u32 = undefined;
    const count = integration.get_linked_pages(page1_id, &linked);
    
    // Assert: Linked pages retrieved
    try std.testing.expect(count == 2);
    try std.testing.expect((linked[0] == page2_id and linked[1] == page3_id) or
                           (linked[0] == page3_id and linked[1] == page2_id));
}
