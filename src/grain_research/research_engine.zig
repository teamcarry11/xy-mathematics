//! Grain Research Engine: Core research capabilities for data collection and storage.
//!
//! Why: Provides research data collection, storage, and query capabilities for the
//! Grain OS ecosystem. Research Engine is the foundation for all research features.
//! Architecture: Bounded research entries, iterative query algorithms.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-07-070000-pst: Grain Research Agent Phase 1

const std = @import("std");

// Bounded: Max research entries in storage.
pub const MAX_RESEARCH_ENTRIES: u32 = 100_000;

// Bounded: Max query results returned.
pub const MAX_QUERY_RESULTS: u32 = 10_000;

// Bounded: Max entry title length.
pub const MAX_ENTRY_TITLE: u32 = 512;

// Bounded: Max entry content length.
pub const MAX_ENTRY_CONTENT: u32 = 1_048_576; // 1 MB

// Bounded: Max entry tags.
pub const MAX_ENTRY_TAGS: u32 = 64;

// Bounded: Max tag length.
pub const MAX_TAG_LEN: u32 = 128;

// Research entry: Represents a single research data point.
pub const ResearchEntry = struct {
    entry_id: u64,
    title: []const u8,
    title_len: u32,
    content: []const u8,
    content_len: u32,
    tags: []const []const u8,
    tags_len: u32,
    created_at: u64,
    updated_at: u64,
    allocator: std.mem.Allocator,

    // Initialize research entry.
    pub fn init(
        allocator: std.mem.Allocator,
        entry_id: u64,
        title: []const u8,
        content: []const u8,
        tags: []const []const u8,
    ) !ResearchEntry {
        std.debug.assert(entry_id > 0);
        std.debug.assert(title.len <= MAX_ENTRY_TITLE);
        std.debug.assert(content.len <= MAX_ENTRY_CONTENT);
        std.debug.assert(tags.len <= MAX_ENTRY_TAGS);

        const title_copy = try allocator.dupe(u8, title);
        errdefer allocator.free(title_copy);

        const content_copy = try allocator.dupe(u8, content);
        errdefer allocator.free(content_copy);

        const tags_copy = try allocator.alloc([]const u8, tags.len);
        errdefer allocator.free(tags_copy);

        var i: u32 = 0;
        while (i < tags.len) : (i += 1) {
            std.debug.assert(tags[i].len <= MAX_TAG_LEN);
            const tag_copy = try allocator.dupe(u8, tags[i]);
            errdefer {
                var j: u32 = 0;
                while (j < i) : (j += 1) {
                    allocator.free(tags_copy[j]);
                }
                allocator.free(tags_copy);
            }
            tags_copy[i] = tag_copy;
        }

        const now = std.time.timestamp();

        return ResearchEntry{
            .entry_id = entry_id,
            .title = title_copy,
            .title_len = @as(u32, @intCast(title_copy.len)),
            .content = content_copy,
            .content_len = @as(u32, @intCast(content_copy.len)),
            .tags = tags_copy,
            .tags_len = @as(u32, @intCast(tags.len)),
            .created_at = @as(u64, @intCast(now)),
            .updated_at = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }

    // Deinitialize research entry and free memory.
    pub fn deinit(self: *ResearchEntry) void {
        var i: u32 = 0;
        while (i < self.tags_len) : (i += 1) {
            self.allocator.free(self.tags[i]);
        }
        if (self.tags_len > 0) {
            self.allocator.free(self.tags);
        }
        if (self.content_len > 0) {
            self.allocator.free(self.content);
        }
        if (self.title_len > 0) {
            self.allocator.free(self.title);
        }
        self.* = undefined;
    }
};

// Query filter: Defines search criteria.
pub const QueryFilter = struct {
    tag: ?[]const u8 = null,
    title_contains: ?[]const u8 = null,
    content_contains: ?[]const u8 = null,
    created_after: ?u64 = null,
    created_before: ?u64 = null,
};

// Query result: Contains matching entries.
pub const QueryResult = struct {
    entries: []const ResearchEntry,
    entries_len: u32,
    total_matched: u32,
    allocator: std.mem.Allocator,

    // Initialize query result.
    pub fn init(
        allocator: std.mem.Allocator,
        entries: []const ResearchEntry,
        total_matched: u32,
    ) !QueryResult {
        std.debug.assert(entries.len <= MAX_QUERY_RESULTS);
        std.debug.assert(total_matched >= entries.len);

        const entries_copy = try allocator.alloc(ResearchEntry, entries.len);
        errdefer allocator.free(entries_copy);

        var i: u32 = 0;
        while (i < entries.len) : (i += 1) {
            entries_copy[i] = entries[i];
        }

        return QueryResult{
            .entries = entries_copy,
            .entries_len = @as(u32, @intCast(entries.len)),
            .total_matched = total_matched,
            .allocator = allocator,
        };
    }

    // Deinitialize query result and free memory.
    pub fn deinit(self: *QueryResult) void {
        if (self.entries_len > 0) {
            self.allocator.free(self.entries);
        }
        self.* = undefined;
    }
};

// Research engine: Core research data collection and storage.
pub const ResearchEngine = struct {
    entries: std.ArrayListUnmanaged(ResearchEntry),
    next_entry_id: u64,
    allocator: std.mem.Allocator,

    // Initialize research engine.
    pub fn init(allocator: std.mem.Allocator) ResearchEngine {
        _ = allocator;

        return ResearchEngine{
            .entries = .{},
            .next_entry_id = 1,
            .allocator = allocator,
        };
    }

    // Deinitialize research engine and free memory.
    pub fn deinit(self: *ResearchEngine) void {
        var i: u32 = 0;
        while (i < self.entries.items.len) : (i += 1) {
            self.entries.items[i].deinit();
        }
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    // Collect research data (add entry).
    pub fn collect(
        self: *ResearchEngine,
        title: []const u8,
        content: []const u8,
        tags: []const []const u8,
    ) !u64 {
        std.debug.assert(title.len > 0);
        std.debug.assert(title.len <= MAX_ENTRY_TITLE);
        std.debug.assert(content.len <= MAX_ENTRY_CONTENT);
        std.debug.assert(tags.len <= MAX_ENTRY_TAGS);
        std.debug.assert(self.entries.items.len < MAX_RESEARCH_ENTRIES);

        const entry_id = self.next_entry_id;
        self.next_entry_id += 1;

        const entry = try ResearchEntry.init(
            self.allocator,
            entry_id,
            title,
            content,
            tags,
        );
        errdefer entry.deinit();

        try self.entries.append(self.allocator, entry);

        return entry_id;
    }

    // Query research entries with filter.
    pub fn query(
        self: *ResearchEngine,
        filter: QueryFilter,
    ) !QueryResult {
        std.debug.assert(self.entries.items.len <= MAX_RESEARCH_ENTRIES);

        var matches = std.ArrayListUnmanaged(ResearchEntry){};
        defer matches.deinit(self.allocator);

        var i: u32 = 0;
        while (i < self.entries.items.len) : (i += 1) {
            const entry = self.entries.items[i];
            var matches_filter = true;

            if (filter.tag) |tag| {
                var found_tag = false;
                var j: u32 = 0;
                while (j < entry.tags_len) : (j += 1) {
                    if (std.mem.eql(u8, entry.tags[j], tag)) {
                        found_tag = true;
                        break;
                    }
                }
                if (!found_tag) {
                    matches_filter = false;
                }
            }

            if (matches_filter) {
                if (filter.title_contains) |substr| {
                    if (std.mem.indexOf(u8, entry.title, substr) == null) {
                        matches_filter = false;
                    }
                }
            }

            if (matches_filter) {
                if (filter.content_contains) |substr| {
                    if (std.mem.indexOf(u8, entry.content, substr) == null) {
                        matches_filter = false;
                    }
                }
            }

            if (matches_filter) {
                if (filter.created_after) |after| {
                    if (entry.created_at < after) {
                        matches_filter = false;
                    }
                }
            }

            if (matches_filter) {
                if (filter.created_before) |before| {
                    if (entry.created_at > before) {
                        matches_filter = false;
                    }
                }
            }

            if (matches_filter) {
                try matches.append(self.allocator, entry);
                if (matches.items.len >= MAX_QUERY_RESULTS) {
                    break;
                }
            }
        }

        const total_matched = @as(u32, @intCast(matches.items.len));
        const result = try QueryResult.init(
            self.allocator,
            matches.items,
            total_matched,
        );

        return result;
    }

    // Get entry by ID.
    pub fn get_entry_by_id(
        self: *ResearchEngine,
        entry_id: u64,
    ) ?*ResearchEntry {
        std.debug.assert(entry_id > 0);

        var i: u32 = 0;
        while (i < self.entries.items.len) : (i += 1) {
            if (self.entries.items[i].entry_id == entry_id) {
                return &self.entries.items[i];
            }
        }

        return null;
    }

    // Get entry by ID (const version).
    pub fn get_entry_by_id_const(
        self: *const ResearchEngine,
        entry_id: u64,
    ) ?*const ResearchEntry {
        std.debug.assert(entry_id > 0);

        var i: u32 = 0;
        while (i < self.entries.items.len) : (i += 1) {
            if (self.entries.items[i].entry_id == entry_id) {
                return &self.entries.items[i];
            }
        }

        return null;
    }

    // Get total entry count.
    pub fn get_entry_count(self: *const ResearchEngine) u32 {
        std.debug.assert(self.entries.items.len <= MAX_RESEARCH_ENTRIES);

        return @as(u32, @intCast(self.entries.items.len));
    }
};
