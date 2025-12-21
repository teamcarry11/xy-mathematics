//! Grain Bubble Agent Flow Tests
//!
//! Tests for agent flow design functionality.
//!
//! 2025-12-20-152034-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const grain_bubble = @import("grain_bubble");
const canvas = grain_bubble.canvas;
const agent_flow = grain_bubble.agent_flow;

test "flow node init" {
    const node = agent_flow.FlowNode.init(
        1,
        .agent,
        "TestAgent",
        100.0,
        200.0,
    );
    try testing.expect(node.id == 1);
    try testing.expect(node.node_type == .agent);
    try testing.expect(node.name_len > 0);
    try testing.expect(node.x == 100.0);
    try testing.expect(node.y == 200.0);
    try testing.expect(node.width == 120.0);
    try testing.expect(node.height == 60.0);
}

test "flow node set_config" {
    var node = agent_flow.FlowNode.init(
        1,
        .agent,
        "TestAgent",
        100.0,
        200.0,
    );
    const config = "agent_id=5";
    node.set_config(config);
    try testing.expect(node.config_len == config.len);
}

test "flow node set_agent_id" {
    var node = agent_flow.FlowNode.init(
        1,
        .agent,
        "TestAgent",
        100.0,
        200.0,
    );
    node.set_agent_id(5);
    try testing.expect(node.agent_id == 5);
}

test "flow node set_task_name" {
    var node = agent_flow.FlowNode.init(
        1,
        .task,
        "TestTask",
        100.0,
        200.0,
    );
    const task_name = "process_data";
    node.set_task_name(task_name);
    try testing.expect(node.task_name_len == task_name.len);
}

test "flow connection init" {
    const conn = agent_flow.FlowConnection.init(1, 2, 3);
    try testing.expect(conn.id == 1);
    try testing.expect(conn.from_node_id == 2);
    try testing.expect(conn.to_node_id == 3);
    try testing.expect(conn.label_len == 0);
    try testing.expect(conn.condition_len == 0);
}

test "flow connection set_label" {
    var conn = agent_flow.FlowConnection.init(1, 2, 3);
    const label = "Next";
    conn.set_label(label);
    try testing.expect(conn.label_len == label.len);
}

test "flow connection set_condition" {
    var conn = agent_flow.FlowConnection.init(1, 2, 3);
    const condition = "status == success";
    conn.set_condition(condition);
    try testing.expect(conn.condition_len == condition.len);
}

test "agent flow init" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    try testing.expect(flow.nodes_len == 0);
    try testing.expect(flow.connections_len == 0);
    try testing.expect(flow.next_node_id == 1);
    try testing.expect(flow.next_connection_id == 1);
}

test "agent flow add_node" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    const node = flow.add_node(.start, "Start", 100.0, 200.0);
    try testing.expect(node != null);
    try testing.expect(flow.nodes_len == 1);
    try testing.expect(node.?.id == 1);
    try testing.expect(node.?.node_type == .start);
    try testing.expect(flow.next_node_id == 2);
}

test "agent flow get_node" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.agent, "Agent1", 100.0, 200.0);
    const node = flow.get_node(1);
    try testing.expect(node != null);
    try testing.expect(node.?.id == 1);
    try testing.expect(node.?.node_type == .agent);
}

test "agent flow add_connection" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.start, "Start", 100.0, 200.0);
    _ = flow.add_node(.end, "End", 300.0, 200.0);
    const conn = flow.add_connection(1, 2);
    try testing.expect(conn != null);
    try testing.expect(flow.connections_len == 1);
    try testing.expect(conn.?.from_node_id == 1);
    try testing.expect(conn.?.to_node_id == 2);
    try testing.expect(flow.next_connection_id == 2);
}

test "agent flow get_connection" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.start, "Start", 100.0, 200.0);
    _ = flow.add_node(.end, "End", 300.0, 200.0);
    _ = flow.add_connection(1, 2);
    const conn = flow.get_connection(1);
    try testing.expect(conn != null);
    try testing.expect(conn.?.id == 1);
}

test "agent flow remove_node" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.start, "Start", 100.0, 200.0);
    _ = flow.add_node(.end, "End", 300.0, 200.0);
    _ = flow.add_connection(1, 2);
    const removed = flow.remove_node(1);
    try testing.expect(removed == true);
    try testing.expect(flow.nodes_len == 1);
    try testing.expect(flow.connections_len == 0);
}

test "agent flow remove_connection" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.start, "Start", 100.0, 200.0);
    _ = flow.add_node(.end, "End", 300.0, 200.0);
    _ = flow.add_connection(1, 2);
    const removed = flow.remove_connection(1);
    try testing.expect(removed == true);
    try testing.expect(flow.connections_len == 0);
}

test "agent flow get_node_count" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.start, "Start", 100.0, 200.0);
    _ = flow.add_node(.agent, "Agent1", 200.0, 200.0);
    try testing.expect(flow.get_node_count() == 2);
}

test "agent flow get_connection_count" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.start, "Start", 100.0, 200.0);
    _ = flow.add_node(.agent, "Agent1", 200.0, 200.0);
    _ = flow.add_node(.end, "End", 300.0, 200.0);
    _ = flow.add_connection(1, 2);
    _ = flow.add_connection(2, 3);
    try testing.expect(flow.get_connection_count() == 2);
}

test "agent flow get_node_at_position" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.agent, "Agent1", 100.0, 200.0);
    const node = flow.get_node_at_position(150.0, 230.0);
    try testing.expect(node != null);
    try testing.expect(node.?.id == 1);
}

test "agent flow get_node_at_position not found" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.agent, "Agent1", 100.0, 200.0);
    const node = flow.get_node_at_position(500.0, 500.0);
    try testing.expect(node == null);
}

test "agent flow render_nodes" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    const layer_id = canvas_state.create_layer("Flow Layer").?;
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.start, "Start", 100.0, 200.0);
    _ = flow.add_node(.agent, "Agent1", 200.0, 200.0);
    flow.render_nodes(layer_id);
    try testing.expect(canvas_state.layers[layer_id].shapes_len == 2);
}

test "agent flow export_to_workflow_format" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.start, "Start", 100.0, 200.0);
    const agent_node = flow.add_node(.agent, "Agent1", 200.0, 200.0);
    agent_node.?.set_agent_id(5);
    _ = flow.add_node(.end, "End", 300.0, 200.0);
    _ = flow.add_connection(1, 2);
    _ = flow.add_connection(2, 3);
    var output: [4096]u8 = undefined;
    const len = flow.export_to_workflow_format("TestWorkflow", &output);
    try testing.expect(len > 0);
    const output_str = output[0..len];
    try testing.expect(std.mem.indexOf(u8, output_str, "TestWorkflow") != null);
    try testing.expect(std.mem.indexOf(u8, output_str, "Start") != null);
    try testing.expect(std.mem.indexOf(u8, output_str, "Agent1") != null);
    try testing.expect(std.mem.indexOf(u8, output_str, "End") != null);
    try testing.expect(std.mem.indexOf(u8, output_str, "agent_id") != null);
}

test "agent flow export_to_workflow_format with task node" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    const task_node = flow.add_node(.task, "ProcessData", 100.0, 200.0);
    task_node.?.set_task_name("process_data");
    var output: [4096]u8 = undefined;
    const len = flow.export_to_workflow_format("TaskWorkflow", &output);
    try testing.expect(len > 0);
    const output_str = output[0..len];
    try testing.expect(std.mem.indexOf(u8, output_str, "TaskWorkflow") != null);
    try testing.expect(std.mem.indexOf(u8, output_str, "ProcessData") != null);
    try testing.expect(std.mem.indexOf(u8, output_str, "task_name") != null);
    try testing.expect(std.mem.indexOf(u8, output_str, "process_data") != null);
}

test "agent flow export_to_workflow_format with connection labels" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.start, "Start", 100.0, 200.0);
    _ = flow.add_node(.end, "End", 200.0, 200.0);
    const conn = flow.add_connection(1, 2);
    conn.?.set_label("Next");
    var output: [4096]u8 = undefined;
    const len = flow.export_to_workflow_format("LabelWorkflow", &output);
    try testing.expect(len > 0);
    const output_str = output[0..len];
    try testing.expect(std.mem.indexOf(u8, output_str, "label") != null);
    try testing.expect(std.mem.indexOf(u8, output_str, "Next") != null);
}

test "agent flow export_to_workflow_format with decision condition" {
    var canvas_state = canvas.Canvas.init(1024, 768);
    var flow = agent_flow.AgentFlow.init(&canvas_state);
    _ = flow.add_node(.decision, "CheckStatus", 100.0, 200.0);
    _ = flow.add_node(.end, "End", 200.0, 200.0);
    const conn = flow.add_connection(1, 2);
    conn.?.set_condition("status == success");
    var output: [4096]u8 = undefined;
    const len = flow.export_to_workflow_format("DecisionWorkflow", &output);
    try testing.expect(len > 0);
    const output_str = output[0..len];
    try testing.expect(std.mem.indexOf(u8, output_str, "condition") != null);
    try testing.expect(std.mem.indexOf(u8, output_str, "status == success") != null);
}
