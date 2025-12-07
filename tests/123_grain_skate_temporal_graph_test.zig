//! Test: Grain Skate Temporal Graph
//!
//! Tests the temporal knowledge graph functionality (time-travel mode).

const std = @import("std");
const TemporalGraph = @import("grain_skate").TemporalGraph;
const EditorDagIntegration = @import("grain_skate").EditorDagIntegration;

test "temporal graph initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var dag_integration = try EditorDagIntegration.init(allocator);
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    var temporal = TemporalGraph.init(allocator, &dag_integration);
    
    try std.testing.expect(temporal.current_timestamp == null);
    try std.testing.expect(!temporal.is_time_travel_mode());
}

test "temporal graph time range" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var dag_integration = try EditorDagIntegration.init(allocator);
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    // Create and process events
    _ = try dag_integration.map_operation_to_event(.insert, 1, 5, "", "new1");
    _ = try dag_integration.map_operation_to_event(.insert, 1, 9, "", "new2");
    try dag_integration.process_events();
    
    var temporal = TemporalGraph.init(allocator, &dag_integration);
    
    const range = temporal.get_time_range();
    
    try std.testing.expect(range.earliest != null);
    try std.testing.expect(range.latest != null);
    try std.testing.expect(range.latest.? >= range.earliest.?);
}

test "temporal graph time travel" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var dag_integration = try EditorDagIntegration.init(allocator);
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    // Create and process events
    _ = try dag_integration.map_operation_to_event(.insert, 1, 5, "", "new1");
    _ = try dag_integration.map_operation_to_event(.insert, 1, 9, "", "new2");
    try dag_integration.process_events();
    
    var temporal = TemporalGraph.init(allocator, &dag_integration);
    
    const latest = dag_integration.get_latest_timestamp();
    try std.testing.expect(latest != null);
    
    // Set timestamp to latest (time-travel)
    temporal.set_timestamp(latest);
    
    try std.testing.expect(temporal.is_time_travel_mode());
    try std.testing.expect(temporal.get_timestamp() == latest);
    
    const events = temporal.query_events_at_current_time();
    try std.testing.expect(events.len > 0);
    
    // Reset to present
    temporal.reset_to_present();
    try std.testing.expect(!temporal.is_time_travel_mode());
}

test "temporal graph date range query" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var dag_integration = try EditorDagIntegration.init(allocator);
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    // Create and process events
    _ = try dag_integration.map_operation_to_event(.insert, 1, 5, "", "new1");
    _ = try dag_integration.map_operation_to_event(.insert, 1, 9, "", "new2");
    try dag_integration.process_events();
    
    var temporal = TemporalGraph.init(allocator, &dag_integration);
    
    const range = temporal.get_time_range();
    try std.testing.expect(range.earliest != null);
    try std.testing.expect(range.latest != null);
    
    // Query events in date range
    const count = temporal.query_events_by_date_range(range.earliest.?, range.latest.?);
    try std.testing.expect(count >= 2);
}

