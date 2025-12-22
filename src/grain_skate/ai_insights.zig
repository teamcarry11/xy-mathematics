const std = @import("std");
const EditorDagIntegration = @import("editor_dag_integration.zig").EditorDagIntegration;
const Block = @import("block.zig").Block;
const grain_court = @import("grain_court");
const grain_core = @import("grain_core");
const LlmProvider = grain_court.LlmProvider;
const ProviderPool = LlmProvider.ProviderPool;
const OpenAIProvider = grain_court.OpenAIProvider;

/// AI-Powered Graph Insights: Multi-provider LLM powered insights for knowledge graph.
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
    provider_pool: ?ProviderPool, // Optional provider pool (if API key provided)
    http_client: ?*grain_core.http_client.HttpClient, // HTTP client for providers
    // Note: Provider instances are heap-allocated and stored in provider_pool
    // For simplicity, we use arena allocator pattern or rely on allocator cleanup
    
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
    
    /// Initialize AI insights (without LLM provider).
    pub fn init(
        allocator: std.mem.Allocator,
        dag_integration: *EditorDagIntegration,
        block_storage: *Block.BlockStorage,
    ) AiInsights {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        // Assert: DAG integration must be valid
        std.debug.assert(dag_integration.buffer_node_id != null);
        
        return AiInsights{
            .allocator = allocator,
            .dag_integration = dag_integration,
            .block_storage = block_storage,
            .provider_pool = null,
            .http_client = null,
            .provider_instance = null,
        };
    }
    
    /// Initialize AI insights with LLM provider (for AI-powered features).
    /// Uses Court Agent's multi-provider LLM abstraction.
    pub fn init_with_llm_provider(
        allocator: std.mem.Allocator,
        dag_integration: *EditorDagIntegration,
        block_storage: *Block.BlockStorage,
        api_key: []const u8,
        http_client_ptr: ?*grain_core.http_client.HttpClient,
        provider_type: LlmProvider.ProviderType,
    ) !AiInsights {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        // Assert: DAG integration must be valid
        std.debug.assert(dag_integration.buffer_node_id != null);
        
        // Assert: API key must be provided
        std.debug.assert(api_key.len > 0);
        
        // Initialize provider pool
        var provider_pool = ProviderPool.init(allocator);
        
        // Create provider based on type (heap-allocated for pool storage)
        var provider: *LlmProvider.ProviderTrait = undefined;
        var provider_instance: ?*anyopaque = null;
        
        switch (provider_type) {
            .openai => {
                var openai_provider = try allocator.create(OpenAIProvider);
                openai_provider.* = try OpenAIProvider.init(allocator, api_key, http_client_ptr);
                provider = &openai_provider.trait;
                provider_instance = @ptrCast(openai_provider);
            },
            .anthropic => {
                const AnthropicProvider = grain_court.AnthropicProvider;
                var anthropic_provider = try allocator.create(AnthropicProvider);
                anthropic_provider.* = try AnthropicProvider.init(allocator, api_key, http_client_ptr);
                provider = &anthropic_provider.trait;
                provider_instance = @ptrCast(anthropic_provider);
            },
            .mistral => {
                const MistralProvider = grain_court.MistralProvider;
                var mistral_provider = try allocator.create(MistralProvider);
                mistral_provider.* = try MistralProvider.init(allocator, api_key, http_client_ptr);
                provider = &mistral_provider.trait;
                provider_instance = @ptrCast(mistral_provider);
            },
            else => return error.UnsupportedProvider,
        }
        
        // Add provider to pool
        try provider_pool.add_provider(provider);
        
        return AiInsights{
            .allocator = allocator,
            .dag_integration = dag_integration,
            .block_storage = block_storage,
            .provider_pool = provider_pool,
            .http_client = http_client_ptr,
            .provider_instance = provider_instance,
        };
    }
    
    /// Deinitialize AI insights (cleanup provider pool if present).
    pub fn deinit(self: *AiInsights) void {
        // Cleanup heap-allocated provider instance
        if (self.provider_instance) |instance| {
            // Free provider instance (allocated in init_with_llm_provider)
            // Note: Provider cleanup handled by allocator (e.g., arena allocator)
            // For explicit cleanup, we'd need to know the concrete type
            _ = instance;
        }
        self.* = undefined;
    }
    
    /// Send LLM request using Court's provider pool.
    /// Converts system/user messages to a single prompt and sends via provider pool.
    fn send_llm_request(
        self: *AiInsights,
        system_prompt: []const u8,
        user_prompt: []const u8,
        model: []const u8,
        max_tokens: u32,
        temperature: f32,
    ) ![]const u8 {
        // Assert: Provider pool must be available
        std.debug.assert(self.provider_pool != null);
        
        // Assert: Prompts must be within bounds
        std.debug.assert(system_prompt.len > 0);
        std.debug.assert(user_prompt.len > 0);
        std.debug.assert(system_prompt.len + user_prompt.len <= LlmProvider.MAX_REQUEST_SIZE);
        
        const pool = &self.provider_pool.?;
        
        // Build combined prompt (system + user)
        var combined_prompt = std.ArrayList(u8).init(self.allocator);
        defer combined_prompt.deinit();
        
        try combined_prompt.writer().print("{s}\n\n{s}", .{ system_prompt, user_prompt });
        
        // Assert: Combined prompt within bounds
        std.debug.assert(combined_prompt.items.len <= LlmProvider.MAX_REQUEST_SIZE);
        
        // Create LLM request
        var request = LlmProvider.LlmRequest{
            .request_id = 0, // Will be set by provider
            .provider_type = .openai, // Default, can be overridden
            .model = undefined,
            .model_len = 0,
            .prompt = undefined,
            .prompt_len = 0,
            .max_tokens = max_tokens,
            .temperature = temperature,
            .created_at = @as(u64, @intCast(std.time.timestamp())),
        };
        
        // Copy model name
        const model_len = @min(model.len, 128);
        var i: u32 = 0;
        while (i < 128) : (i += 1) {
            request.model[i] = 0;
        }
        i = 0;
        while (i < model_len) : (i += 1) {
            request.model[i] = model[i];
        }
        request.model_len = model_len;
        
        // Copy prompt
        const prompt_len = @min(combined_prompt.items.len, @as(usize, @intCast(LlmProvider.MAX_REQUEST_SIZE)));
        i = 0;
        while (i < LlmProvider.MAX_REQUEST_SIZE) : (i += 1) {
            request.prompt[i] = 0;
        }
        i = 0;
        while (i < prompt_len) : (i += 1) {
            request.prompt[i] = combined_prompt.items[i];
        }
        request.prompt_len = @intCast(prompt_len);
        
        // Send request via provider pool
        const response = try pool.send_request_with_fallback(&request, self.allocator);
        
        // Extract response content
        const content = response.content[0..response.content_len];
        const content_copy = try self.allocator.dupe(u8, content);
        
        return content_copy;
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
        
        // If provider pool not available, return empty suggestions
        if (self.provider_pool == null) {
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
            
            // Skip blocks with empty content
            if (block.content_len == 0) continue;
            
            const content = try self.allocator.dupe(u8, block.content[0..block.content_len]);
            try block_contents.append(content);
        }
        
        // Assert: At least 2 blocks with content required for connections
        std.debug.assert(block_contents.items.len >= 2);
        
        // Build prompt for LLM
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
        
        const prompt_str = try prompt.toOwnedSlice();
        defer self.allocator.free(prompt_str);
        
        // Get AI response via Court provider
        const response = try self.send_llm_request(
            "You are a knowledge graph analysis assistant. Analyze blocks and suggest semantic connections.",
            prompt_str,
            "gpt-4o", // Default model, can be configurable
            2000, // Max tokens
            0.7, // Temperature
        );
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
            
            // Validate blocks exist
            const from_block = self.block_storage.get_block(@as(u32, @intCast(from_id))) orelse continue;
            _ = self.block_storage.get_block(@as(u32, @intCast(to_id))) orelse continue;
            
            // Skip if link already exists
            var link_exists = false;
            var i: u32 = 0;
            while (i < from_block.links_len) : (i += 1) {
                if (from_block.links[i] == @as(u32, @intCast(to_id))) {
                    link_exists = true;
                    break;
                }
            }
            if (link_exists) continue;
            
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
        
        // If provider pool not available, return empty gaps
        if (self.provider_pool == null) {
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
            
            // Skip blocks with empty content
            if (block.content_len == 0) continue;
            
            const content = try self.allocator.dupe(u8, block.content[0..block.content_len]);
            try block_contents.append(content);
        }
        
        // Assert: At least 2 blocks with content required for gap detection
        std.debug.assert(block_contents.items.len >= 2);
        
        // Build prompt for LLM
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();
        
        const writer = prompt.writer();
        try writer.writeAll("Analyze these knowledge graph blocks and identify missing connections (knowledge gaps). For each gap, provide: block1_id,block2_id (one per line).\n\n");
        
        for (block_ids, 0..) |block_id, i| {
            if (i < block_contents.items.len) {
                try writer.print("Block {d}:\n{s}\n\n", .{ block_id, block_contents.items[i] });
            }
        }
        
        const prompt_str = try prompt.toOwnedSlice();
        defer self.allocator.free(prompt_str);
        
        // Get AI response via Court provider
        const response = try self.send_llm_request(
            "You are a knowledge graph analysis assistant. Identify missing connections between related blocks.",
            prompt_str,
            "gpt-4o", // Default model
            2000, // Max tokens
            0.7, // Temperature
        );
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
            
            // Validate blocks exist
            const from_block = self.block_storage.get_block(@as(u32, @intCast(from_id))) orelse continue;
            _ = self.block_storage.get_block(@as(u32, @intCast(to_id))) orelse continue;
            
            // Skip if link already exists (not a knowledge gap)
            var link_exists = false;
            var i: u32 = 0;
            while (i < from_block.links_len) : (i += 1) {
                if (from_block.links[i] == @as(u32, @intCast(to_id))) {
                    link_exists = true;
                    break;
                }
            }
            if (link_exists) continue;
            
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
        
        // If provider pool not available, return null
        if (self.provider_pool == null) {
            return null;
        }
        
        // Get block content
        const block = self.block_storage.get_block(@as(u32, @intCast(block_id))) orelse return null;
        
        // Assert: Block content must exist
        std.debug.assert(block.content_len > 0);
        
        // Build prompt for LLM
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();
        
        const writer = prompt.writer();
        try writer.print("Generate a concise title (max 50 characters) for this knowledge graph block:\n\n{s}\n\nTitle only, no explanation.", .{block.content[0..block.content_len]});
        
        const prompt_str = try prompt.toOwnedSlice();
        defer self.allocator.free(prompt_str);
        
        // Get AI response via Court provider
        const response = try self.send_llm_request(
            "You are a knowledge graph assistant. Generate concise, descriptive titles for blocks.",
            prompt_str,
            "gpt-4o", // Default model
            100, // Max tokens (titles are short)
            0.7, // Temperature
        );
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
        
        // If provider pool not available, return null
        if (self.provider_pool == null) {
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
        
        // Build prompt for LLM
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();
        
        const writer = prompt.writer();
        try writer.writeAll("Summarize this knowledge graph subgraph in 2-3 sentences:\n\n");
        
        for (block_ids, 0..) |block_id, i| {
            if (i < block_contents.items.len) {
                try writer.print("Block {d}:\n{s}\n\n", .{ block_id, block_contents.items[i] });
            }
        }
        
        const prompt_str = try prompt.toOwnedSlice();
        defer self.allocator.free(prompt_str);
        
        // Get AI response via Court provider
        const response = try self.send_llm_request(
            "You are a knowledge graph assistant. Provide concise summaries of subgraphs.",
            prompt_str,
            "gpt-4o", // Default model
            500, // Max tokens (summaries are short)
            0.7, // Temperature
        );
        
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
    
    const ai_insights = AiInsights.init(arena.allocator(), &dag_integration, &block_storage);
    
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
    defer ai_insights.deinit();
    
    // Store suggestion as DAG event
    const event_id = try ai_insights.store_suggestion_as_dag_event(
        .connection,
        "block1->block2:high_similarity",
    );
    
    // Assert: Event was created
    try std.testing.expect(event_id > 0);
    try std.testing.expect(dag_integration.dag.pending_events_len == 1);
}

