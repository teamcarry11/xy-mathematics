//! Test: Grain Skate AI Insights
//!
//! Tests the AI-powered graph insights functionality.

const std = @import("std");
const AiInsights = @import("grain_skate").AiInsights;
const EditorDagIntegration = @import("grain_skate").EditorDagIntegration;
const Block = @import("grain_skate").Block;

test "ai insights initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var dag_integration = try EditorDagIntegration.init(allocator);
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();
    
    var ai_insights = AiInsights.init(allocator, &dag_integration, &block_storage);
    
    // Assert: AI insights initialized
    _ = ai_insights;
}

test "ai insights store suggestion as dag event" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var dag_integration = try EditorDagIntegration.init(allocator);
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();
    
    var ai_insights = AiInsights.init(allocator, &dag_integration, &block_storage);
    
    // Store suggestion as DAG event
    const event_id = try ai_insights.store_suggestion_as_dag_event(
        .connection,
        "block1->block2:high_similarity",
    );
    
    // Assert: Event was created
    try std.testing.expect(event_id > 0);
    try std.testing.expect(dag_integration.dag.pending_events_len == 1);
    try std.testing.expect(dag_integration.get_last_event_id() == event_id);
}

test "ai insights suggest connections placeholder" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var dag_integration = try EditorDagIntegration.init(allocator);
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();
    
    var ai_insights = AiInsights.init(allocator, &dag_integration, &block_storage);
    
    // Test suggest connections (placeholder)
    const block_ids = [_]u64{ 1, 2 };
    const suggestions = try ai_insights.suggest_connections(&block_ids);
    
    // Assert: Placeholder returns empty array
    try std.testing.expect(suggestions.len == 0);
}

test "ai insights detect knowledge gaps placeholder" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var dag_integration = try EditorDagIntegration.init(allocator);
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();
    
    var ai_insights = AiInsights.init(allocator, &dag_integration, &block_storage);
    
    // Test detect knowledge gaps (placeholder)
    const block_ids = [_]u64{ 1, 2, 3 };
    const gaps = try ai_insights.detect_knowledge_gaps(&block_ids);
    
    // Assert: Placeholder returns empty array
    try std.testing.expect(gaps.len == 0);
}

