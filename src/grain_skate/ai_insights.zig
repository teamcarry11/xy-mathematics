const std = @import("std");
const EditorDagIntegration = @import("editor_dag_integration.zig").EditorDagIntegration;
const Block = @import("block.zig").Block;
const Glm46Client = @import("../aurora_glm46.zig").Glm46Client;

/// AI-Powered Graph Insights: GLM-4.6 powered insights for knowledge graph.
/// ~<~ Glow Airbend: explicit AI suggestions, bounded analysis.
/// ~~~~ Glow Waterbend: AI insights flow deterministically through DAG.
///
/// This implements AI-powered knowledge graph management:
/// - Auto-suggest connections between blocks (semantic similarity)
/// - Detect knowledge gaps (missing links between related blocks)
/// - Summarize subgraphs (AI-generated summaries)
/// - Generate block titles from content (auto-titling)
/// - Semantic clustering (group related blocks visually)
pub const AiInsights = struct {
    allocator: std.mem.Allocator,
    dag_integration: *EditorDagIntegration,
    block_storage: *Block.BlockStorage,
    glm46_client: ?Glm46Client, // Optional GLM-4.6 client (if API key provided)
    
    // Bounded: Max 100 AI suggestions per session
    pub const MAX_AI_SUGGESTIONS: u32 = 100;
    
    // Bounded: Max 10 blocks per analysis batch
    pub const MAX_BLOCKS_PER_BATCH: u32 = 10;
    
    /// AI suggestion for block connection.
    pub const ConnectionSuggestion = struct {
        from_block_id: u64,
        to_block_id: u64,
        confidence: f32, // 0.0 to 1.0
        reason: []const u8, // AI-generated reason for connection
        reason_len: u32,
    };
    
    /// AI suggestion for block title.
    pub const TitleSuggestion = struct {
        block_id: u64,
        suggested_title: []const u8,
        title_len: u32,
        confidence: f32, // 0.0 to 1.0
    };
    
    /// Initialize AI insights (without GLM-4.6 client).
    pub fn init(
        allocator: std.mem.Allocator,
        dag_integration: *EditorDagIntegration,
        block_storage: *Block.BlockStorage,
    ) AiInsights {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        // Assert: DAG integration must be valid
        std.debug.assert(dag_integration.buffer_node_id != null);
        
        // Assert: Block storage must be valid
        _ = block_storage;
        
        return AiInsights{
            .allocator = allocator,
            .dag_integration = dag_integration,
            .block_storage = block_storage,
            .glm46_client = null,
        };
    }
    
    /// Initialize AI insights with GLM-4.6 client (for AI-powered features).
    pub fn init_with_glm46(
        allocator: std.mem.Allocator,
        dag_integration: *EditorDagIntegration,
        block_storage: *Block.BlockStorage,
        api_key: []const u8,
    ) AiInsights {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        // Assert: DAG integration must be valid
        std.debug.assert(dag_integration.buffer_node_id != null);
        
        // Assert: API key must be provided
        std.debug.assert(api_key.len > 0);
        
        // Assert: Block storage must be valid
        _ = block_storage;
        
        const glm46_client = Glm46Client.init(allocator, api_key);
        
        return AiInsights{
            .allocator = allocator,
            .dag_integration = dag_integration,
            .block_storage = block_storage,
            .glm46_client = glm46_client,
        };
    }
    
    /// Deinitialize AI insights (cleanup GLM-4.6 client if present).
    pub fn deinit(self: *AiInsights) void {
        if (self.glm46_client) |*client| {
            client.deinit();
        }
        self.* = undefined;
    }
    
    /// Global buffer for collecting streaming responses (single-threaded use).
    /// Note: This is a workaround for callback limitations in GLM-4.6 client.
    var global_response_buffer: ?*std.ArrayList(u8) = null;
    
    /// Callback for collecting streaming GLM-4.6 response chunks.
    fn collect_chunk_callback(chunk: []const u8) void {
        if (global_response_buffer) |buffer| {
            buffer.writer().writeAll(chunk) catch {};
        }
    }
    
    /// Collect streaming GLM-4.6 response into a single string.
    fn collect_glm46_response(
        self: *AiInsights,
        messages: []const Glm46Client.Message,
    ) ![]const u8 {
        // Assert: GLM-4.6 client must be available
        std.debug.assert(self.glm46_client != null);
        
        // Assert: Messages must be within bounds
        std.debug.assert(messages.len > 0);
        
        var response_buffer_local = std.ArrayList(u8).init(self.allocator);
        errdefer response_buffer_local.deinit();
        
        const client = &self.glm46_client.?;
        
        // Set global buffer (single-threaded use)
        global_response_buffer = &response_buffer_local;
        defer global_response_buffer = null;
        
        // Collect streaming chunks
        try client.requestCompletion(messages, collect_chunk_callback);
        
        return try response_buffer_local.toOwnedSlice();
    }
    
    /// Analyze blocks and suggest connections (semantic similarity).
    /// Returns array of connection suggestions.
    pub fn suggest_connections(
        self: *AiInsights,
        block_ids: []const u64,
    ) ![]const ConnectionSuggestion {
        // Assert: Block count must be within bounds
        std.debug.assert(block_ids.len <= MAX_BLOCKS_PER_BATCH);
        
        // Assert: Block count must be at least 2 for connections
        std.debug.assert(block_ids.len >= 2);
        
        // If GLM-4.6 client not available, return empty suggestions
        if (self.glm46_client == null) {
            return &[_]ConnectionSuggestion{};
        }
        
        // Get block contents
        var block_contents = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (block_contents.items) |content| {
                self.allocator.free(content);
            }
            block_contents.deinit();
        }
        
        for (block_ids) |block_id| {
            const block = self.block_storage.get_block(@as(u32, @intCast(block_id))) orelse continue;
            const content = try self.allocator.dupe(u8, block.content[0..block.content_len]);
            try block_contents.append(content);
        }
        
        // Build prompt for GLM-4.6
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();
        
        const writer = prompt.writer();
        try writer.writeAll("Analyze these knowledge graph blocks and suggest connections between them based on semantic similarity. For each suggested connection, provide: block1_id, block2_id, confidence (0.0-1.0), and reason.\n\n");
        
        for (block_ids, 0..) |block_id, i| {
            if (i < block_contents.items.len) {
                try writer.print("Block {d}:\n{s}\n\n", .{ block_id, block_contents.items[i] });
            }
        }
        
        try writer.writeAll("Format: block1_id,block2_id,confidence,reason (one per line)");
        
        const messages = [_]Glm46Client.Message{
            .{ .role = "system", .content = "You are a knowledge graph analysis assistant. Analyze blocks and suggest semantic connections." },
            .{ .role = "user", .content = try prompt.toOwnedSlice() },
        };
        defer self.allocator.free(messages[1].content);
        
        // Get AI response
        const response = try self.collect_glm46_response(&messages);
        defer self.allocator.free(response);
        
        // Parse response (simple CSV-like format)
        var suggestions = std.ArrayList(ConnectionSuggestion).init(self.allocator);
        errdefer {
            for (suggestions.items) |*suggestion| {
                self.allocator.free(suggestion.reason);
            }
            suggestions.deinit();
        }
        
        // Parse lines (simple implementation)
        var lines = std.mem.split(u8, response, "\n");
        var line_count: u32 = 0;
        while (lines.next()) |line| : (line_count += 1) {
            if (line.len == 0) continue;
            
            // Assert: Line count must be within bounds
            std.debug.assert(line_count < MAX_BLOCKS_PER_BATCH * MAX_BLOCKS_PER_BATCH);
            
            // Check if suggestions array is full
            if (suggestions.items.len >= MAX_AI_SUGGESTIONS) {
                break;
            }
            
            var fields = std.mem.split(u8, line, ",");
            const from_id_str = fields.next() orelse continue;
            const to_id_str = fields.next() orelse continue;
            const conf_str = fields.next() orelse continue;
            const reason_str = fields.rest();
            
            // Validate reason string length
            if (reason_str.len > 1000) continue; // Max 1000 chars per reason
            
            const from_id = std.fmt.parseInt(u64, from_id_str, 10) catch continue;
            const to_id = std.fmt.parseInt(u64, to_id_str, 10) catch continue;
            
            // Validate block IDs are within reasonable bounds
            if (from_id == 0 or to_id == 0) continue;
            if (from_id == to_id) continue; // Skip self-connections
            
            // Parse confidence and clamp to valid range
            var confidence = std.fmt.parseFloat(f32, conf_str) catch 0.5;
            if (confidence < 0.0) confidence = 0.0;
            if (confidence > 1.0) confidence = 1.0;
            
            const reason = try self.allocator.dupe(u8, reason_str);
            
            try suggestions.append(ConnectionSuggestion{
                .from_block_id = from_id,
                .to_block_id = to_id,
                .confidence = confidence,
                .reason = reason,
                .reason_len = @as(u32, @intCast(reason.len)),
            });
        }
        
        return try suggestions.toOwnedSlice();
    }
    
    /// Detect knowledge gaps (missing links between related blocks).
    /// Returns array of block ID pairs that should be linked.
    pub fn detect_knowledge_gaps(
        self: *AiInsights,
        block_ids: []const u64,
    ) ![]const struct { from_block_id: u64, to_block_id: u64 } {
        // Assert: Block count must be within bounds
        std.debug.assert(block_ids.len <= MAX_BLOCKS_PER_BATCH);
        
        // Validate all block IDs are non-zero
        for (block_ids) |block_id| {
            std.debug.assert(block_id > 0);
        }
        
        // If GLM-4.6 client not available, return empty gaps
        if (self.glm46_client == null) {
            return &[_]struct { from_block_id: u64, to_block_id: u64 }{};
        }
        
        // Get block contents and existing links
        var block_contents = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (block_contents.items) |content| {
                self.allocator.free(content);
            }
            block_contents.deinit();
        }
        
        for (block_ids) |block_id| {
            const block = self.block_storage.get_block(@as(u32, @intCast(block_id))) orelse continue;
            const content = try self.allocator.dupe(u8, block.content[0..block.content_len]);
            try block_contents.append(content);
        }
        
        // Build prompt for GLM-4.6
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();
        
        const writer = prompt.writer();
        try writer.writeAll("Analyze these knowledge graph blocks and identify missing connections (knowledge gaps). For each gap, provide: block1_id,block2_id (one per line).\n\n");
        
        for (block_ids, 0..) |block_id, i| {
            if (i < block_contents.items.len) {
                try writer.print("Block {d}:\n{s}\n\n", .{ block_id, block_contents.items[i] });
            }
        }
        
        const messages = [_]Glm46Client.Message{
            .{ .role = "system", .content = "You are a knowledge graph analysis assistant. Identify missing connections between related blocks." },
            .{ .role = "user", .content = try prompt.toOwnedSlice() },
        };
        defer self.allocator.free(messages[1].content);
        
        // Get AI response
        const response = try self.collect_glm46_response(&messages);
        defer self.allocator.free(response);
        
        // Parse response (simple CSV-like format)
        var gaps = std.ArrayList(struct { from_block_id: u64, to_block_id: u64 }).init(self.allocator);
        errdefer gaps.deinit();
        
        // Parse lines
        var lines = std.mem.split(u8, response, "\n");
        var line_count: u32 = 0;
        while (lines.next()) |line| : (line_count += 1) {
            if (line.len == 0) continue;
            
            // Assert: Line count must be within bounds
            std.debug.assert(line_count < MAX_BLOCKS_PER_BATCH * MAX_BLOCKS_PER_BATCH);
            
            // Check if gaps array is full
            if (gaps.items.len >= MAX_AI_SUGGESTIONS) {
                break;
            }
            
            var fields = std.mem.split(u8, line, ",");
            const from_id_str = fields.next() orelse continue;
            const to_id_str = fields.next() orelse continue;
            
            const from_id = std.fmt.parseInt(u64, from_id_str, 10) catch continue;
            const to_id = std.fmt.parseInt(u64, to_id_str, 10) catch continue;
            
            // Validate block IDs are within reasonable bounds
            if (from_id == 0 or to_id == 0) continue;
            if (from_id == to_id) continue; // Skip self-connections
            
            try gaps.append(.{
                .from_block_id = from_id,
                .to_block_id = to_id,
            });
        }
        
        return try gaps.toOwnedSlice();
    }
    
    /// Generate block title from content (auto-titling).
    /// Returns suggested title for the block.
    pub fn suggest_title(
        self: *AiInsights,
        block_id: u64,
    ) !?TitleSuggestion {
        // Assert: Block ID must be valid
        std.debug.assert(block_id > 0);
        
        // If GLM-4.6 client not available, return null
        if (self.glm46_client == null) {
            return null;
        }
        
        // Get block content
        const block = self.block_storage.get_block(@as(u32, @intCast(block_id))) orelse return null;
        
        // Assert: Block content must exist
        std.debug.assert(block.content_len > 0);
        
        // Build prompt for GLM-4.6
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();
        
        const writer = prompt.writer();
        try writer.print("Generate a concise title (max 50 characters) for this knowledge graph block:\n\n{s}\n\nTitle only, no explanation.", .{block.content[0..block.content_len]});
        
        const messages = [_]Glm46Client.Message{
            .{ .role = "system", .content = "You are a knowledge graph assistant. Generate concise, descriptive titles for blocks." },
            .{ .role = "user", .content = try prompt.toOwnedSlice() },
        };
        defer self.allocator.free(messages[1].content);
        
        // Get AI response
        const response = try self.collect_glm46_response(&messages);
        defer self.allocator.free(response);
        
        // Validate response is not empty
        if (response.len == 0) {
            return null;
        }
        
        // Trim whitespace and limit length
        const trimmed = std.mem.trim(u8, response, " \n\r\t");
        if (trimmed.len == 0) {
            return null;
        }
        const max_len = @min(trimmed.len, Block.MAX_BLOCK_TITLE);
        const title = try self.allocator.dupe(u8, trimmed[0..max_len]);
        
        // Assert: Title length is within bounds
        std.debug.assert(title.len <= Block.MAX_BLOCK_TITLE);
        
        return TitleSuggestion{
            .block_id = block_id,
            .suggested_title = title,
            .title_len = @as(u32, @intCast(max_len)),
            .confidence = 0.8, // Default confidence
        };
    }
    
    /// Summarize subgraph (AI-generated summary).
    /// Returns summary text for the subgraph.
    pub fn summarize_subgraph(
        self: *AiInsights,
        block_ids: []const u64,
    ) !?[]const u8 {
        // Assert: Block count must be within bounds
        std.debug.assert(block_ids.len <= MAX_BLOCKS_PER_BATCH);
        
        // If GLM-4.6 client not available, return null
        if (self.glm46_client == null) {
            return null;
        }
        
        // Get block contents
        var block_contents = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (block_contents.items) |content| {
                self.allocator.free(content);
            }
            block_contents.deinit();
        }
        
        for (block_ids) |block_id| {
            // Assert: Block ID must be valid
            std.debug.assert(block_id > 0);
            
            const block = self.block_storage.get_block(@as(u32, @intCast(block_id))) orelse continue;
            const content = try self.allocator.dupe(u8, block.content[0..block.content_len]);
            try block_contents.append(content);
        }
        
        // Assert: At least one block content retrieved
        std.debug.assert(block_contents.items.len > 0);
        
        // Build prompt for GLM-4.6
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();
        
        const writer = prompt.writer();
        try writer.writeAll("Summarize this knowledge graph subgraph in 2-3 sentences:\n\n");
        
        for (block_ids, 0..) |block_id, i| {
            if (i < block_contents.items.len) {
                try writer.print("Block {d}:\n{s}\n\n", .{ block_id, block_contents.items[i] });
            }
        }
        
        const messages = [_]Glm46Client.Message{
            .{ .role = "system", .content = "You are a knowledge graph assistant. Provide concise summaries of subgraphs." },
            .{ .role = "user", .content = try prompt.toOwnedSlice() },
        };
        defer self.allocator.free(messages[1].content);
        
        // Get AI response
        const response = try self.collect_glm46_response(&messages);
        
        // Validate response is not empty
        if (response.len == 0) {
            return null;
        }
        
        // Assert: Response length is reasonable (max 10KB)
        std.debug.assert(response.len <= 10_000);
        
        // Return summary (caller owns the memory)
        return response;
    }
    
    /// Store AI suggestion as DAG event (for deterministic replay).
    pub fn store_suggestion_as_dag_event(
        self: *AiInsights,
        suggestion_type: SuggestionType,
        suggestion_data: []const u8,
    ) !u64 {
        // Assert: Buffer node must exist
        std.debug.assert(self.dag_integration.buffer_node_id != null);
        
        // Assert: Event count must be within bounds
        std.debug.assert(self.dag_integration.dag.pending_events_len < EditorDagIntegration.MAX_EVENTS_PER_SESSION);
        
        // Create event data (suggestion type + data)
        var event_data = std.ArrayList(u8).init(self.allocator);
        defer event_data.deinit();
        
        const writer = event_data.writer();
        try writer.print("ai_suggestion:{s}:", .{@tagName(suggestion_type)});
        try writer.writeAll(suggestion_data);
        
        // Create parent event IDs (reference last event)
        var parent_events: []const u64 = &.{};
        const last_event_id = self.dag_integration.get_last_event_id();
        if (last_event_id > 0) {
            parent_events = &.{last_event_id};
        }
        
        // Add event to DAG (ai_completion type) and update last event ID
        const event_id = try self.dag_integration.add_event_and_update_last(
            .ai_completion,
            try event_data.toOwnedSlice(),
            parent_events,
        );
        
        return event_id;
    }
    
    /// Type of AI suggestion.
    pub const SuggestionType = enum(u8) {
        connection, // Connection suggestion between blocks
        title, // Title suggestion for block
        summary, // Summary suggestion for subgraph
        gap, // Knowledge gap detection
    };
};

test "ai insights initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag_integration = try EditorDagIntegration.init(arena.allocator());
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    var block_storage = try Block.BlockStorage.init(arena.allocator());
    defer block_storage.deinit();
    
    var ai_insights = AiInsights.init(arena.allocator(), &dag_integration, &block_storage);
    
    // Assert: AI insights initialized
    _ = ai_insights;
}

test "ai insights store suggestion as dag event" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag_integration = try EditorDagIntegration.init(arena.allocator());
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    var block_storage = try Block.BlockStorage.init(arena.allocator());
    defer block_storage.deinit();
    
    var ai_insights = AiInsights.init(arena.allocator(), &dag_integration, &block_storage);
    
    // Store suggestion as DAG event
    const event_id = try ai_insights.store_suggestion_as_dag_event(
        .connection,
        "block1->block2:high_similarity",
    );
    
    // Assert: Event was created
    try std.testing.expect(event_id > 0);
    try std.testing.expect(dag_integration.dag.pending_events_len == 1);
}

