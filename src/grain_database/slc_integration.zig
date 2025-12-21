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

// Validate Nostr npub format (basic check: starts with "npub1" and has valid length).
pub fn validate_npub(npub: []const u8) bool {
    std.debug.assert(npub.len > 0);
    if (npub.len < 5) {
        return false;
    }
    if (!std.mem.eql(u8, npub[0..5], "npub1")) {
        return false;
    }
    if (npub.len > MAX_PROFILE_KEY_LEN) {
        return false;
    }
    return true;
}

// Validate file path format (basic check: non-empty, starts with "/").
pub fn validate_file_path(file_path: []const u8) bool {
    std.debug.assert(file_path.len > 0);
    if (file_path.len == 0) {
        return false;
    }
    if (file_path[0] != '/') {
        return false;
    }
    if (file_path.len > MAX_FILE_KEY_LEN) {
        return false;
    }
    return true;
}

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
        if (!validate_npub(npub)) {
            return error.InvalidNpub;
        }
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
    ) ?*storage_engine.Record {
        std.debug.assert(npub.len > 0);
        std.debug.assert(npub.len <= MAX_PROFILE_KEY_LEN);
        const key = std.fmt.allocPrint(
            self.storage_engine.allocator,
            "nostr:profile:{s}",
            .{npub},
        ) catch return null;
        defer self.storage_engine.allocator.free(key);
        return self.storage_engine.read_record_by_key(key);
    }

    // Update Nostr profile data.
    pub fn update_profile(
        self: *NostrProfileStorage,
        npub: []const u8,
        profile_data: []const u8,
    ) !void {
        std.debug.assert(npub.len > 0);
        std.debug.assert(npub.len <= MAX_PROFILE_KEY_LEN);
        std.debug.assert(profile_data.len > 0);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "nostr:profile:{s}",
            .{npub},
        );
        defer self.storage_engine.allocator.free(key);
        try self.storage_engine.update_record(key, profile_data);
    }

    // Delete Nostr profile data.
    pub fn delete_profile(
        self: *NostrProfileStorage,
        npub: []const u8,
    ) !void {
        std.debug.assert(npub.len > 0);
        std.debug.assert(npub.len <= MAX_PROFILE_KEY_LEN);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "nostr:profile:{s}",
            .{npub},
        );
        defer self.storage_engine.allocator.free(key);
        try self.storage_engine.delete_record(key);
    }

    // List all Nostr profiles (returns count of matching records).
    pub fn list_profiles(
        self: *NostrProfileStorage,
        output: []u64,
    ) u32 {
        std.debug.assert(output.len > 0);
        var count: u32 = 0;
        var i: u32 = 0;
        const prefix = "nostr:profile:";
        while (i < self.storage_engine.records_len) : (i += 1) {
            const record = &self.storage_engine.records[i];
            if (record.key_len >= prefix.len) {
                if (std.mem.eql(u8, record.key[0..prefix.len], prefix)) {
                    if (count < output.len) {
                        output[count] = record.record_id;
                        count += 1;
                    }
                }
            }
        }
        return count;
    }

    // Count all Nostr profiles.
    pub fn count_profiles(self: *NostrProfileStorage) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        const prefix = "nostr:profile:";
        while (i < self.storage_engine.records_len) : (i += 1) {
            const record = &self.storage_engine.records[i];
            if (record.key_len >= prefix.len) {
                if (std.mem.eql(u8, record.key[0..prefix.len], prefix)) {
                    count += 1;
                }
            }
        }
        return count;
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
        const graph_node_id = try self.graph.add_node("dag_website", content);
        std.debug.assert(graph_node_id > 0);
        return record_id;
    }

    // Store DAG website edge.
    pub fn store_edge(
        self: *DagWebsiteStorage,
        from_node_id: u64,
        to_node_id: u64,
        edge_data: []const u8,
    ) !u64 {
        std.debug.assert(from_node_id > 0);
        std.debug.assert(to_node_id > 0);
        std.debug.assert(edge_data.len > 0);
        const edge_id = try self.graph.add_edge(
            from_node_id,
            to_node_id,
            "dag_link",
            edge_data,
        );
        std.debug.assert(edge_id > 0);
        return edge_id;
    }

    // Retrieve DAG website node.
    pub fn get_node(
        self: *DagWebsiteStorage,
        node_id: []const u8,
    ) ?*storage_engine.Record {
        std.debug.assert(node_id.len > 0);
        std.debug.assert(node_id.len <= MAX_WEBSITE_KEY_LEN);
        const key = std.fmt.allocPrint(
            self.storage_engine.allocator,
            "dag:website:{s}",
            .{node_id},
        ) catch return null;
        defer self.storage_engine.allocator.free(key);
        return self.storage_engine.read_record_by_key(key);
    }

    // Update DAG website node.
    pub fn update_node(
        self: *DagWebsiteStorage,
        node_id: []const u8,
        content: []const u8,
    ) !void {
        std.debug.assert(node_id.len > 0);
        std.debug.assert(node_id.len <= MAX_WEBSITE_KEY_LEN);
        std.debug.assert(content.len > 0);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "dag:website:{s}",
            .{node_id},
        );
        defer self.storage_engine.allocator.free(key);
        try self.storage_engine.update_record(key, content);
    }

    // Delete DAG website node.
    pub fn delete_node(
        self: *DagWebsiteStorage,
        node_id: []const u8,
    ) !void {
        std.debug.assert(node_id.len > 0);
        std.debug.assert(node_id.len <= MAX_WEBSITE_KEY_LEN);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "dag:website:{s}",
            .{node_id},
        );
        defer self.storage_engine.allocator.free(key);
        try self.storage_engine.delete_record(key);
    }

    // List all DAG website nodes (returns count of matching records).
    pub fn list_nodes(
        self: *DagWebsiteStorage,
        output: []u64,
    ) u32 {
        std.debug.assert(output.len > 0);
        var count: u32 = 0;
        var i: u32 = 0;
        const prefix = "dag:website:";
        while (i < self.storage_engine.records_len) : (i += 1) {
            const record = &self.storage_engine.records[i];
            if (record.key_len >= prefix.len) {
                if (std.mem.eql(u8, record.key[0..prefix.len], prefix)) {
                    if (count < output.len) {
                        output[count] = record.record_id;
                        count += 1;
                    }
                }
            }
        }
        return count;
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
        if (!validate_file_path(file_path)) {
            return error.InvalidFilePath;
        }
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
    ) ?*storage_engine.Record {
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_KEY_LEN);
        const key = std.fmt.allocPrint(
            self.storage_engine.allocator,
            "workspace:file:{s}",
            .{file_path},
        ) catch return null;
        defer self.storage_engine.allocator.free(key);
        return self.storage_engine.read_record_by_key(key);
    }

    // Update workspace file metadata.
    pub fn update_file_metadata(
        self: *WorkspaceFileStorage,
        file_path: []const u8,
        metadata: []const u8,
    ) !void {
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_KEY_LEN);
        std.debug.assert(metadata.len > 0);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "workspace:file:{s}",
            .{file_path},
        );
        defer self.storage_engine.allocator.free(key);
        try self.storage_engine.update_record(key, metadata);
    }

    // Delete workspace file metadata.
    pub fn delete_file_metadata(
        self: *WorkspaceFileStorage,
        file_path: []const u8,
    ) !void {
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_KEY_LEN);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "workspace:file:{s}",
            .{file_path},
        );
        defer self.storage_engine.allocator.free(key);
        try self.storage_engine.delete_record(key);
    }

    // List all workspace file metadata (returns count of matching records).
    pub fn list_file_metadata(
        self: *WorkspaceFileStorage,
        output: []u64,
    ) u32 {
        std.debug.assert(output.len > 0);
        var count: u32 = 0;
        var i: u32 = 0;
        const prefix = "workspace:file:";
        while (i < self.storage_engine.records_len) : (i += 1) {
            const record = &self.storage_engine.records[i];
            if (record.key_len >= prefix.len) {
                if (std.mem.eql(u8, record.key[0..prefix.len], prefix)) {
                    if (count < output.len) {
                        output[count] = record.record_id;
                        count += 1;
                    }
                }
            }
        }
        return count;
    }
};
