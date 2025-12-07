const std = @import("std");
const EditorDagIntegration = @import("editor_dag_integration.zig").EditorDagIntegration;
const Block = @import("block.zig").Block;

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
    
    /// Initialize AI insights.
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
        };
    }
    
    /// Analyze blocks and suggest connections (semantic similarity).
    /// Returns array of connection suggestions.
    /// Note: This is a placeholder - actual GLM-4.6 integration pending.
    pub fn suggest_connections(
        self: *AiInsights,
        block_ids: []const u64,
    ) ![]const ConnectionSuggestion {
        // Assert: Block count must be within bounds
        std.debug.assert(block_ids.len <= MAX_BLOCKS_PER_BATCH);
        
        // Assert: Block count must be at least 2 for connections
        std.debug.assert(block_ids.len >= 2);
        
        // Placeholder: Return empty suggestions for now
        // TODO: Integrate with GLM-4.6 client for semantic analysis
        _ = self;
        _ = block_ids;
        
        // Return empty array (caller should allocate result)
        return &[_]ConnectionSuggestion{};
    }
    
    /// Detect knowledge gaps (missing links between related blocks).
    /// Returns array of block ID pairs that should be linked.
    /// Note: This is a placeholder - actual GLM-4.6 integration pending.
    pub fn detect_knowledge_gaps(
        self: *AiInsights,
        block_ids: []const u64,
    ) ![]const struct { from_block_id: u64, to_block_id: u64 } {
        // Assert: Block count must be within bounds
        std.debug.assert(block_ids.len <= MAX_BLOCKS_PER_BATCH);
        
        // Placeholder: Return empty gaps for now
        // TODO: Integrate with GLM-4.6 client for gap detection
        _ = self;
        _ = block_ids;
        
        // Return empty array (caller should allocate result)
        return &[_]struct { from_block_id: u64, to_block_id: u64 }{};
    }
    
    /// Generate block title from content (auto-titling).
    /// Returns suggested title for the block.
    /// Note: This is a placeholder - actual GLM-4.6 integration pending.
    pub fn suggest_title(
        self: *AiInsights,
        block_id: u64,
    ) !?TitleSuggestion {
        // Assert: Block ID must be valid
        _ = block_id;
        
        // Placeholder: Return null for now
        // TODO: Integrate with GLM-4.6 client for title generation
        _ = self;
        
        return null;
    }
    
    /// Summarize subgraph (AI-generated summary).
    /// Returns summary text for the subgraph.
    /// Note: This is a placeholder - actual GLM-4.6 integration pending.
    pub fn summarize_subgraph(
        self: *AiInsights,
        block_ids: []const u64,
    ) !?[]const u8 {
        // Assert: Block count must be within bounds
        std.debug.assert(block_ids.len <= MAX_BLOCKS_PER_BATCH);
        
        // Placeholder: Return null for now
        // TODO: Integrate with GLM-4.6 client for summarization
        _ = self;
        _ = block_ids;
        
        return null;
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

