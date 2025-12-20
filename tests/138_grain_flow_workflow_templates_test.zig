//! Tests for Grain Flow Workflow Templates.
//!
//! Tests workflow template builders and common workflow patterns.

const std = @import("std");
const grain_flow = @import("grain_flow");
const event_bus = grain_flow.event_bus;
const agent_coordinator = grain_flow.agent_coordinator;
const workflow_engine = grain_flow.workflow_engine;
const workflow_templates = grain_flow.workflow_templates;

test "template builder initialization" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const builder = workflow_templates.WorkflowTemplateBuilder.init(&bus, &coordinator, &engine);
    try std.testing.expect(builder.bus != null);
    try std.testing.expect(builder.coordinator != null);
    try std.testing.expect(builder.engine != null);
}

test "create database backup workflow template" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    var builder = workflow_templates.WorkflowTemplateBuilder.init(&bus, &coordinator, &engine);
    const silo_id = coordinator.register_agent("silo_agent", 1000);
    try std.testing.expect(silo_id != null);
    const core_id = coordinator.register_agent("core_agent", 1000);
    try std.testing.expect(core_id != null);
    const workflow_id = builder.create_database_backup_workflow(
        "database_backup",
        silo_id.?,
        core_id.?,
        2000,
    );
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    try std.testing.expect(workflow.?.get_node_count() == 4);
    try std.testing.expect(workflow.?.get_edge_count() == 3);
}

test "create data sync workflow template" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    var builder = workflow_templates.WorkflowTemplateBuilder.init(&bus, &coordinator, &engine);
    const carry_id = coordinator.register_agent("carry_agent", 1000);
    try std.testing.expect(carry_id != null);
    const silo_id = coordinator.register_agent("silo_agent", 1000);
    try std.testing.expect(silo_id != null);
    const workflow_id = builder.create_data_sync_workflow(
        "data_sync",
        carry_id.?,
        silo_id.?,
        2000,
    );
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    try std.testing.expect(workflow.?.get_node_count() == 4);
    try std.testing.expect(workflow.?.get_edge_count() == 3);
}

test "create parallel processing workflow template" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    var builder = workflow_templates.WorkflowTemplateBuilder.init(&bus, &coordinator, &engine);
    const agent1_id = coordinator.register_agent("agent1", 1000);
    try std.testing.expect(agent1_id != null);
    const agent2_id = coordinator.register_agent("agent2", 1000);
    try std.testing.expect(agent2_id != null);
    const agent3_id = coordinator.register_agent("agent3", 1000);
    try std.testing.expect(agent3_id != null);
    const agent_ids = [_]u32{ agent1_id.?, agent2_id.?, agent3_id.? };
    const workflow_id = builder.create_parallel_processing_workflow(
        "parallel_workflow",
        &agent_ids,
        2000,
    );
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    try std.testing.expect(workflow.?.get_node_count() == 3);
}

test "create sequential workflow template" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    var builder = workflow_templates.WorkflowTemplateBuilder.init(&bus, &coordinator, &engine);
    const agent1_id = coordinator.register_agent("agent1", 1000);
    try std.testing.expect(agent1_id != null);
    const agent2_id = coordinator.register_agent("agent2", 1000);
    try std.testing.expect(agent2_id != null);
    const agent_ids = [_]u32{ agent1_id.?, agent2_id.? };
    const node_names = [_][]const u8{ "task1", "task2" };
    const workflow_id = builder.create_sequential_workflow(
        "sequential_workflow",
        &agent_ids,
        &node_names,
        2000,
    );
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    try std.testing.expect(workflow.?.get_node_count() == 2);
    try std.testing.expect(workflow.?.get_edge_count() == 1);
}

test "get template info" {
    const template = workflow_templates.get_template_info();
    try std.testing.expect(template.name_len > 0);
    try std.testing.expect(template.description_len > 0);
}
