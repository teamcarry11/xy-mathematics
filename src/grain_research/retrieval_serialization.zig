//! Grain Research Retrieval Serialization: JSON and ZON serialization for test data.
//!
//! Why: Enables serialization of test datasets (facts, queries) to JSON and ZON
//! formats for LLM retrieval accuracy testing. Supports Phase 2 validation.
//! Architecture: JSON and ZON serialization, bounded operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-144000-pst: ZON Format Token Efficiency Validation Phase 2

const std = @import("std");
const retrieval_accuracy = @import("retrieval_accuracy.zig");
const TestDataset = retrieval_accuracy.TestDataset;
const Fact = retrieval_accuracy.Fact;
const Query = retrieval_accuracy.Query;

// Bounded: Max serialized JSON length.
pub const MAX_JSON_LEN: u32 = 10 * 1024 * 1024; // 10MB

// Bounded: Max serialized ZON length.
pub const MAX_ZON_LEN: u32 = 10 * 1024 * 1024; // 10MB

// Serialization result.
pub const SerializationResult = struct {
    format: SerializationFormat,
    data: []const u8,
    len: u32,

    pub const SerializationFormat = enum(u8) {
        json = 0,
        zon = 1,
    };

    pub fn init(format: SerializationFormat, data: []const u8) SerializationResult {
        std.debug.assert(data.len > 0);
        std.debug.assert(data.len <= MAX_JSON_LEN);

        return SerializationResult{
            .format = format,
            .data = data,
            .len = @as(u32, @intCast(data.len)),
        };
    }
};

// Serializer: Serializes test datasets to JSON and ZON.
pub const Serializer = struct {
    allocator: std.mem.Allocator,
    json_buffer: std.ArrayList(u8),
    zon_buffer: std.ArrayList(u8),

    // Initialize serializer.
    pub fn init(allocator: std.mem.Allocator) Serializer {
        return Serializer{
            .allocator = allocator,
            .json_buffer = std.ArrayList(u8).init(allocator),
            .zon_buffer = std.ArrayList(u8).init(allocator),
        };
    }

    // Deinitialize serializer.
    pub fn deinit(self: *Serializer) void {
        self.json_buffer.deinit();
        self.zon_buffer.deinit();
    }

    // Serialize dataset to JSON.
    pub fn serialize_to_json(self: *Serializer, dataset: *const TestDataset) !SerializationResult {
        self.json_buffer.clearRetainingCapacity();

        // Start JSON object.
        try self.json_buffer.appendSlice("{\"facts\":[");

        // Serialize facts.
        for (dataset.facts.items, 0..) |fact, i| {
            if (i > 0) {
                try self.json_buffer.appendSlice(",");
            }
            try self.serialize_fact_json(fact);
        }

        // Serialize queries.
        try self.json_buffer.appendSlice("],\"queries\":[");
        for (dataset.queries.items, 0..) |query, i| {
            if (i > 0) {
                try self.json_buffer.appendSlice(",");
            }
            try self.serialize_query_json(query);
        }

        // End JSON object.
        try self.json_buffer.appendSlice("]}");

        const data = try self.allocator.dupe(u8, self.json_buffer.items);
        return SerializationResult.init(.json, data);
    }

    // Serialize dataset to ZON.
    pub fn serialize_to_zon(self: *Serializer, dataset: *const TestDataset) !SerializationResult {
        self.zon_buffer.clearRetainingCapacity();

        // ZON format: Header row with column names, then data rows.
        // Facts: id|text|category
        try self.zon_buffer.appendSlice("id|text|category\n");

        // Serialize facts.
        for (dataset.facts.items) |fact| {
            try self.serialize_fact_zon(fact);
            try self.zon_buffer.appendSlice("\n");
        }

        // Queries: id|text|expected_fact_ids|query_type
        try self.zon_buffer.appendSlice("\nid|text|expected_fact_ids|query_type\n");

        // Serialize queries.
        for (dataset.queries.items) |query| {
            try self.serialize_query_zon(query);
            try self.zon_buffer.appendSlice("\n");
        }

        const data = try self.allocator.dupe(u8, self.zon_buffer.items);
        return SerializationResult.init(.zon, data);
    }

    // Serialize fact to JSON.
    fn serialize_fact_json(self: *Serializer, fact: Fact) !void {
        try self.json_buffer.appendSlice("{\"id\":");
        try self.append_u32(fact.id);
        try self.json_buffer.appendSlice(",\"text\":\"");
        try self.escape_json_string(fact.text);
        try self.json_buffer.appendSlice("\",\"category\":\"");
        try self.escape_json_string(fact.category);
        try self.json_buffer.appendSlice("\"}");
    }

    // Serialize fact to ZON.
    fn serialize_fact_zon(self: *Serializer, fact: Fact) !void {
        try self.append_u32_zon(fact.id);
        try self.zon_buffer.appendSlice("|");
        try self.escape_zon_string(fact.text);
        try self.zon_buffer.appendSlice("|");
        try self.escape_zon_string(fact.category);
    }

    // Serialize query to JSON.
    fn serialize_query_json(self: *Serializer, query: Query) !void {
        try self.json_buffer.appendSlice("{\"id\":");
        try self.append_u32(query.id);
        try self.json_buffer.appendSlice(",\"text\":\"");
        try self.escape_json_string(query.text);
        try self.json_buffer.appendSlice("\",\"expected_fact_ids\":[");
        for (query.expected_fact_ids, 0..) |fact_id, i| {
            if (i > 0) {
                try self.json_buffer.appendSlice(",");
            }
            try self.append_u32(fact_id);
        }
        try self.json_buffer.appendSlice("],\"query_type\":");
        try self.append_u32(@intFromEnum(query.query_type));
        try self.json_buffer.appendSlice("}");
    }

    // Serialize query to ZON.
    fn serialize_query_zon(self: *Serializer, query: Query) !void {
        try self.append_u32_zon(query.id);
        try self.zon_buffer.appendSlice("|");
        try self.escape_zon_string(query.text);
        try self.zon_buffer.appendSlice("|");
        // Serialize expected_fact_ids as comma-separated.
        for (query.expected_fact_ids, 0..) |fact_id, i| {
            if (i > 0) {
                try self.zon_buffer.appendSlice(",");
            }
            try self.append_u32_zon(fact_id);
        }
        try self.zon_buffer.appendSlice("|");
        try self.append_u32_zon(@intFromEnum(query.query_type));
    }

    // Append u32 to buffer (for JSON).
    fn append_u32(self: *Serializer, value: u32) !void {
        const buffer = [_]u8{0} ** 16;
        const formatted = try std.fmt.bufPrint(&buffer, "{}", .{value});
        try self.json_buffer.appendSlice(formatted);
    }

    // Append u32 to ZON buffer.
    fn append_u32_zon(self: *Serializer, value: u32) !void {
        const buffer = [_]u8{0} ** 16;
        const formatted = try std.fmt.bufPrint(&buffer, "{}", .{value});
        try self.zon_buffer.appendSlice(formatted);
    }

    // Escape JSON string.
    fn escape_json_string(self: *Serializer, text: []const u8) !void {
        for (text) |char| {
            switch (char) {
                '"' => try self.json_buffer.appendSlice("\\\""),
                '\\' => try self.json_buffer.appendSlice("\\\\"),
                '\n' => try self.json_buffer.appendSlice("\\n"),
                '\r' => try self.json_buffer.appendSlice("\\r"),
                '\t' => try self.json_buffer.appendSlice("\\t"),
                else => try self.json_buffer.append(char),
            }
        }
    }

    // Escape ZON string (replace pipe with escaped pipe).
    fn escape_zon_string(self: *Serializer, text: []const u8) !void {
        for (text) |char| {
            switch (char) {
                '|' => try self.zon_buffer.appendSlice("\\|"),
                '\n' => try self.zon_buffer.appendSlice("\\n"),
                '\r' => try self.zon_buffer.appendSlice("\\r"),
                else => try self.zon_buffer.append(char),
            }
        }
    }
};
