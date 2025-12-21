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

test "temporal graph time range duration" {
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
    
    const duration = temporal.get_time_range_duration();
    try std.testing.expect(duration > 0);
    try std.testing.expect(duration == (range.latest.? - range.earliest.?));
}

test "temporal graph timestamp from slider position" {
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
    
    // Test 0.0 position (earliest)
    const ts_0 = temporal.timestamp_from_slider_position(0.0);
    try std.testing.expect(ts_0 != null);
    try std.testing.expect(ts_0.? == range.earliest.?);
    
    // Test 1.0 position (latest)
    const ts_1 = temporal.timestamp_from_slider_position(1.0);
    try std.testing.expect(ts_1 != null);
    try std.testing.expect(ts_1.? == range.latest.?);
    
    // Test 0.5 position (middle)
    const ts_05 = temporal.timestamp_from_slider_position(0.5);
    try std.testing.expect(ts_05 != null);
    try std.testing.expect(ts_05.? >= range.earliest.?);
    try std.testing.expect(ts_05.? <= range.latest.?);
}

test "temporal graph slider position from timestamp" {
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
    
    // Test earliest timestamp (should be 0.0)
    const pos_earliest = temporal.slider_position_from_timestamp(range.earliest.?);
    try std.testing.expect(pos_earliest != null);
    try std.testing.expect(pos_earliest.? == 0.0);
    
    // Test latest timestamp (should be 1.0)
    const pos_latest = temporal.slider_position_from_timestamp(range.latest.?);
    try std.testing.expect(pos_latest != null);
    try std.testing.expect(pos_latest.? == 1.0);
}
