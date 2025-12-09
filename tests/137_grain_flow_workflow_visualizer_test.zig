//! Grain Flow Workflow Visualizer Tests: Comprehensive tests for workflow visualization.
//!
//! Why: Verify workflow DAG rendering, node/edge visualization, and HTML export.
//! Architecture: Tests workflow visualization, SVG/HTML generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-08-140000-pst: Phase 4 Workflow Visualizer Foundation

const std = @import("std");
const grain_flow = @import("grain_flow");
const event_bus = grain_flow.event_bus;
const agent_coordinator = grain_flow.agent_coordinator;
const workflow_engine = grain_flow.workflow_engine;
const workflow_visualizer = grain_flow.workflow_visualizer;

test "workflow visualizer initialization" {
    var visualizer = workflow_visualizer.WorkflowVisualizer.init(800, 600);
    try std.testing.expect(visualizer.width == 800);
    try std.testing.expect(visualizer.height == 600);
    try std.testing.expect(visualizer.node_visuals_len == 0);
    try std.testing.expect(visualizer.edge_visuals_len == 0);
}

test "add node visual" {
    var visualizer = workflow_visualizer.WorkflowVisualizer.init(800, 600);
    const position = workflow_visualizer.NodePosition.init(100, 100);
    const visual = workflow_visualizer.NodeVisual.init(1, position, "node1");
    const result = visualizer.add_node_visual(visual);
    try std.testing.expect(result == true);
    try std.testing.expect(visualizer.node_visuals_len == 1);
}

test "add edge visual" {
    var visualizer = workflow_visualizer.WorkflowVisualizer.init(800, 600);
    const edge_visual = workflow_visualizer.EdgeVisual.init(
        1,
        2,
        workflow_engine.EdgeType.dependency,
    );
    const result = visualizer.add_edge_visual(edge_visual);
    try std.testing.expect(result == true);
    try std.testing.expect(visualizer.edge_visuals_len == 1);
}

test "render workflow to SVG" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node = workflow_engine.WorkflowNode.init(1, "node1", 1);
    _ = workflow.?.add_node(node);
    var visualizer = workflow_visualizer.WorkflowVisualizer.init(800, 600);
    const result = visualizer.render_to_svg(workflow.?);
    try std.testing.expect(result == true);
    try std.testing.expect(visualizer.svg_content_len > 0);
}

test "render workflow to HTML" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node = workflow_engine.WorkflowNode.init(1, "node1", 1);
    _ = workflow.?.add_node(node);
    var visualizer = workflow_visualizer.WorkflowVisualizer.init(800, 600);
    const result = visualizer.render_to_html(workflow.?);
    try std.testing.expect(result == true);
    try std.testing.expect(visualizer.html_content_len > 0);
}

test "node visual status color" {
    const position = workflow_visualizer.NodePosition.init(100, 100);
    var visual = workflow_visualizer.NodeVisual.init(1, position, "node1");
    visual.set_status_color(workflow_engine.NodeStatus.completed);
    try std.testing.expect(visual.status_color == 0xFF00FF00); // Green
}

test "edge visual color by type" {
    const edge1 = workflow_visualizer.EdgeVisual.init(
        1,
        2,
        workflow_engine.EdgeType.dependency,
    );
    try std.testing.expect(edge1.color == 0xFF000000); // Black
    const edge2 = workflow_visualizer.EdgeVisual.init(
        1,
        2,
        workflow_engine.EdgeType.data_flow,
    );
    try std.testing.expect(edge2.color == 0xFF0000FF); // Blue
}

test "get SVG content" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node = workflow_engine.WorkflowNode.init(1, "node1", 1);
    _ = workflow.?.add_node(node);
    var visualizer = workflow_visualizer.WorkflowVisualizer.init(800, 600);
    _ = visualizer.render_to_svg(workflow.?);
    const svg_content = visualizer.get_svg_content();
    try std.testing.expect(svg_content.len > 0);
}

test "get HTML content" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const workflow = engine.find_workflow(workflow_id.?);
    try std.testing.expect(workflow != null);
    const node = workflow_engine.WorkflowNode.init(1, "node1", 1);
    _ = workflow.?.add_node(node);
    var visualizer = workflow_visualizer.WorkflowVisualizer.init(800, 600);
    _ = visualizer.render_to_html(workflow.?);
    const html_content = visualizer.get_html_content();
    try std.testing.expect(html_content.len > 0);
}

test "clear visualizer" {
    var visualizer = workflow_visualizer.WorkflowVisualizer.init(800, 600);
    const position = workflow_visualizer.NodePosition.init(100, 100);
    const visual = workflow_visualizer.NodeVisual.init(1, position, "node1");
    _ = visualizer.add_node_visual(visual);
    try std.testing.expect(visualizer.node_visuals_len == 1);
    visualizer.clear();
    try std.testing.expect(visualizer.node_visuals_len == 0);
    try std.testing.expect(visualizer.svg_content_len == 0);
    try std.testing.expect(visualizer.html_content_len == 0);
}

test "render workflow with edges" {
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
    var visualizer = workflow_visualizer.WorkflowVisualizer.init(800, 600);
    const result = visualizer.render_to_svg(workflow.?);
    try std.testing.expect(result == true);
    try std.testing.expect(visualizer.node_visuals_len == 2);
    try std.testing.expect(visualizer.edge_visuals_len == 1);
}
