//! Grain Flow Workflow Engine Tests: Comprehensive tests for workflow execution.
//!
//! Why: Verify workflow DAG creation, execution, and state management.
//! Architecture: Tests workflow creation, node/edge management, execution.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-072000-pst: Phase 3 Workflow Engine Foundation

const std = @import("std");
const grain_flow = @import("grain_flow");
const event_bus = grain_flow.event_bus;
const agent_coordinator = grain_flow.agent_coordinator;
const workflow_engine = grain_flow.workflow_engine;

test "workflow engine initialization" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    try std.testing.expect(engine.get_workflow_count() == 0);
}

test "create workflow" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    try std.testing.expect(workflow_id.? > 0);
    try std.testing.expect(engine.get_workflow_count() == 1);
}

test "find workflow by ID" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    try std.testing.expect(workflow.?.workflow_id == workflow_id.?);
}

test "add node to workflow" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node = workflow_engine.WorkflowNode.init(1, "node1", 1);
    const result = workflow.?.add_node(node);
    try std.testing.expect(result == true);
    try std.testing.expect(workflow.?.nodes_len == 1);
}

test "add edge to workflow" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node1 = workflow_engine.WorkflowNode.init(1, "node1", 1);
    const node2 = workflow_engine.WorkflowNode.init(2, "node2", 2);
    _ = workflow.?.add_node(node1);
    _ = workflow.?.add_node(node2);
    const edge = workflow_engine.WorkflowEdge.init(1, 2, workflow_engine.EdgeType.dependency);
    const result = workflow.?.add_edge(edge);
    try std.testing.expect(result == true);
    try std.testing.expect(workflow.?.edges_len == 1);
}

test "execute simple workflow" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node = workflow_engine.WorkflowNode.init(1, "node1", 1);
    _ = workflow.?.add_node(node);
    const result = engine.execute_workflow(workflow_id.?, 2000);
    try std.testing.expect(result == true);
    try std.testing.expect(workflow.?.status == workflow_engine.WorkflowStatus.completed);
}

test "execute workflow with dependencies" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node1 = workflow_engine.WorkflowNode.init(1, "node1", 1);
    const node2 = workflow_engine.WorkflowNode.init(2, "node2", 2);
    _ = workflow.?.add_node(node1);
    _ = workflow.?.add_node(node2);
    const edge = workflow_engine.WorkflowEdge.init(1, 2, workflow_engine.EdgeType.dependency);
    _ = workflow.?.add_edge(edge);
    const result = engine.execute_workflow(workflow_id.?, 2000);
    try std.testing.expect(result == true);
    try std.testing.expect(workflow.?.status == workflow_engine.WorkflowStatus.completed);
    const found_node1 = workflow.?.find_node(1);
    const found_node2 = workflow.?.find_node(2);
    try std.testing.expect(found_node1 != null);
    try std.testing.expect(found_node2 != null);
    try std.testing.expect(found_node1.?.status == workflow_engine.NodeStatus.completed);
    try std.testing.expect(found_node2.?.status == workflow_engine.NodeStatus.completed);
}

test "workflow node error handling" {
    var node = workflow_engine.WorkflowNode.init(1, "node1", 1);
    const result = node.set_error("test error");
    try std.testing.expect(result == true);
    try std.testing.expect(node.error_message_len > 0);
}

test "workflow node state data" {
    var node = workflow_engine.WorkflowNode.init(1, "node1", 1);
    const result = node.set_state_data("test data");
    try std.testing.expect(result == true);
    try std.testing.expect(node.state_data_len > 0);
}

test "bounded workflow nodes" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    var i: u32 = 0;
    while (i < workflow_engine.MAX_WORKFLOW_NODES + 10) : (i += 1) {
        var name_buf: [32]u8 = undefined;
        _ = std.fmt.bufPrint(&name_buf, "node_{}", .{i}) catch "";
        const node = workflow_engine.WorkflowNode.init(i + 1, &name_buf, 1);
        _ = workflow.?.add_node(node);
    }
    try std.testing.expect(workflow.?.nodes_len == workflow_engine.MAX_WORKFLOW_NODES);
}

test "bounded workflow edges" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node1 = workflow_engine.WorkflowNode.init(1, "node1", 1);
    const node2 = workflow_engine.WorkflowNode.init(2, "node2", 2);
    _ = workflow.?.add_node(node1);
    _ = workflow.?.add_node(node2);
    var i: u32 = 0;
    while (i < workflow_engine.MAX_WORKFLOW_EDGES + 10) : (i += 1) {
        const edge = workflow_engine.WorkflowEdge.init(1, 2, workflow_engine.EdgeType.dependency);
        _ = workflow.?.add_edge(edge);
    }
    try std.testing.expect(workflow.?.edges_len == workflow_engine.MAX_WORKFLOW_EDGES);
}

test "find node in workflow" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node = workflow_engine.WorkflowNode.init(1, "node1", 1);
    _ = workflow.?.add_node(node);
    const found = workflow.?.find_node(1);
    try std.testing.expect(found != null);
    try std.testing.expect(found.?.node_id == 1);
}
