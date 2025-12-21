//! Grain Database SLC Product Integration: Helpers for SLC products.
//!
//! Why: Simplify database usage for Nostr profiles, DAG websites, and Workspace files.
//! Architecture: Helper functions for common SLC product storage patterns.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-20-161207-pst: Grain Silo Agent

const std = @import("std");
const storage_engine = @import("storage_engine.zig");
const graph = @import("graph.zig");
const relational = @import("relational.zig");

// Bounded: Max profile key length.
pub const MAX_PROFILE_KEY_LEN: u32 = 256;

// Bounded: Max website key length.
pub const MAX_WEBSITE_KEY_LEN: u32 = 256;

// Bounded: Max file key length.
pub const MAX_FILE_KEY_LEN: u32 = 512;

// Nostr profile storage helper.
pub const NostrProfileStorage = struct {
    storage_engine: *storage_engine.StorageEngine,
    graph: *graph.Graph,

    // Initialize Nostr profile storage.
    pub fn init(
        storage: *storage_engine.StorageEngine,
        g: *graph.Graph,
    ) NostrProfileStorage {
        std.debug.assert(storage != null);
        std.debug.assert(g != null);
        return NostrProfileStorage{
            .storage_engine = storage,
            .graph = g,
        };
    }

    // Store Nostr profile data.
    pub fn store_profile(
        self: *NostrProfileStorage,
        npub: []const u8,
        profile_data: []const u8,
    ) !u64 {
        std.debug.assert(npub.len > 0);
        std.debug.assert(npub.len <= MAX_PROFILE_KEY_LEN);
        std.debug.assert(profile_data.len > 0);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "nostr:profile:{s}",
            .{npub},
        );
        defer self.storage_engine.allocator.free(key);
        const record_id = try self.storage_engine.create_record(key, profile_data);
        std.debug.assert(record_id > 0);
        return record_id;
    }

    // Retrieve Nostr profile data.
    pub fn get_profile(
        self: *NostrProfileStorage,
        npub: []const u8,
    ) ?*const storage_engine.Record {
        std.debug.assert(npub.len > 0);
        std.debug.assert(npub.len <= MAX_PROFILE_KEY_LEN);
        const key = std.fmt.allocPrint(
            self.storage_engine.allocator,
            "nostr:profile:{s}",
            .{npub},
        ) catch return null;
        defer self.storage_engine.allocator.free(key);
        return self.storage_engine.get_record_by_key(key);
    }
};

// DAG website storage helper.
pub const DagWebsiteStorage = struct {
    storage_engine: *storage_engine.StorageEngine,
    graph: *graph.Graph,

    // Initialize DAG website storage.
    pub fn init(
        storage: *storage_engine.StorageEngine,
        g: *graph.Graph,
    ) DagWebsiteStorage {
        std.debug.assert(storage != null);
        std.debug.assert(g != null);
        return DagWebsiteStorage{
            .storage_engine = storage,
            .graph = g,
        };
    }

    // Store DAG website node.
    pub fn store_node(
        self: *DagWebsiteStorage,
        node_id: []const u8,
        content: []const u8,
    ) !u64 {
        std.debug.assert(node_id.len > 0);
        std.debug.assert(node_id.len <= MAX_WEBSITE_KEY_LEN);
        std.debug.assert(content.len > 0);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "dag:website:{s}",
            .{node_id},
        );
        defer self.storage_engine.allocator.free(key);
        const record_id = try self.storage_engine.create_record(key, content);
        std.debug.assert(record_id > 0);
        const node = try self.graph.add_node(node_id, content);
        std.debug.assert(node != null);
        return record_id;
    }

    // Store DAG website edge.
    pub fn store_edge(
        self: *DagWebsiteStorage,
        from_node_id: []const u8,
        to_node_id: []const u8,
        edge_data: []const u8,
    ) !void {
        std.debug.assert(from_node_id.len > 0);
        std.debug.assert(to_node_id.len > 0);
        const edge = try self.graph.add_edge(from_node_id, to_node_id, edge_data);
        std.debug.assert(edge != null);
    }

    // Retrieve DAG website node.
    pub fn get_node(
        self: *DagWebsiteStorage,
        node_id: []const u8,
    ) ?*const storage_engine.Record {
        std.debug.assert(node_id.len > 0);
        std.debug.assert(node_id.len <= MAX_WEBSITE_KEY_LEN);
        const key = std.fmt.allocPrint(
            self.storage_engine.allocator,
            "dag:website:{s}",
            .{node_id},
        ) catch return null;
        defer self.storage_engine.allocator.free(key);
        return self.storage_engine.get_record_by_key(key);
    }
};

// Workspace file storage helper.
pub const WorkspaceFileStorage = struct {
    storage_engine: *storage_engine.StorageEngine,

    // Initialize workspace file storage.
    pub fn init(
        storage: *storage_engine.StorageEngine,
    ) WorkspaceFileStorage {
        std.debug.assert(storage != null);
        return WorkspaceFileStorage{
            .storage_engine = storage,
        };
    }

    // Store workspace file metadata.
    pub fn store_file_metadata(
        self: *WorkspaceFileStorage,
        file_path: []const u8,
        metadata: []const u8,
    ) !u64 {
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_KEY_LEN);
        std.debug.assert(metadata.len > 0);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "workspace:file:{s}",
            .{file_path},
        );
        defer self.storage_engine.allocator.free(key);
        const record_id = try self.storage_engine.create_record(key, metadata);
        std.debug.assert(record_id > 0);
        return record_id;
    }

    // Retrieve workspace file metadata.
    pub fn get_file_metadata(
        self: *WorkspaceFileStorage,
        file_path: []const u8,
    ) ?*const storage_engine.Record {
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_KEY_LEN);
        const key = std.fmt.allocPrint(
            self.storage_engine.allocator,
            "workspace:file:{s}",
            .{file_path},
        ) catch return null;
        defer self.storage_engine.allocator.free(key);
        return self.storage_engine.get_record_by_key(key);
    }
};
