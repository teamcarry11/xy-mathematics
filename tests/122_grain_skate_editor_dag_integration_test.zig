//! Test: Grain Skate Editor DAG Integration
//!
//! Tests the DAG integration for editor operations (event ordering, undo/redo foundation).

const std = @import("std");
const EditorDagIntegration = @import("grain_skate").EditorDagIntegration;

test "editor dag integration initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try EditorDagIntegration.init(allocator);
    defer integration.deinit();

    try std.testing.expect(integration.dag.nodes_len == 0);
    try std.testing.expect(integration.dag.edges_len == 0);
    try std.testing.expect(integration.buffer_node_id == null);
    try std.testing.expect(integration.last_event_id == 0);
}

test "editor dag create buffer node" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try EditorDagIntegration.init(allocator);
    defer integration.deinit();

    const content = "line1\nline2\nline3";
    const node_id = try integration.create_buffer_node(content);

    try std.testing.expect(node_id < 10_000); // MAX_NODES
    try std.testing.expect(integration.buffer_node_id == node_id);
    try std.testing.expect(integration.dag.nodes_len == 1);
}

test "editor dag map operation to event" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try EditorDagIntegration.init(allocator);
    defer integration.deinit();

    const content = "line1\nline2\nline3";
    _ = try integration.create_buffer_node(content);

    const event_id = try integration.map_operation_to_event(
        .insert,
        1,
        5,
        "",
        "new",
    );

    try std.testing.expect(event_id > 0);
    try std.testing.expect(integration.dag.pending_events_len == 1);
    try std.testing.expect(integration.last_event_id == event_id);
}

test "editor dag event parent references" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try EditorDagIntegration.init(allocator);
    defer integration.deinit();

    const content = "line1\nline2\nline3";
    _ = try integration.create_buffer_node(content);

    const event1_id = try integration.map_operation_to_event(
        .insert,
        1,
        5,
        "",
        "new1",
    );

    const event2_id = try integration.map_operation_to_event(
        .insert,
        1,
        9,
        "",
        "new2",
    );

    try std.testing.expect(event1_id > 0);
    try std.testing.expect(event2_id > event1_id);
    try std.testing.expect(integration.dag.pending_events_len == 2);
    try std.testing.expect(integration.last_event_id == event2_id);
}

test "editor dag process events" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try EditorDagIntegration.init(allocator);
    defer integration.deinit();

    const content = "line1\nline2\nline3";
    _ = try integration.create_buffer_node(content);

    _ = try integration.map_operation_to_event(.insert, 1, 5, "", "new1");
    _ = try integration.map_operation_to_event(.insert, 1, 9, "", "new2");

    try integration.process_events();

    try std.testing.expect(integration.dag.pending_events_len == 0);
}

