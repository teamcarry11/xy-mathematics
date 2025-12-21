//! Grain Flow Workflow Templates: Pre-built workflow templates and integration examples.
//!
//! Why: Provides pre-built workflow templates for common use cases and demonstrates
//! integration patterns with other agents. Makes Flow Agent more usable by providing
//! ready-to-use workflow patterns.
//!
//! Architecture: Workflow template builders, common patterns, integration examples.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-144320-pst: Phase 5 Workflow Templates & Integration Examples

const std = @import("std");
const workflow_engine = @import("workflow_engine.zig");
const event_bus = @import("event_bus.zig");
const agent_coordinator = @import("agent_coordinator.zig");

// Bounded: Max template name length.
pub const MAX_TEMPLATE_NAME_LEN: u32 = 128;

// Bounded: Max template description length.
pub const MAX_TEMPLATE_DESC_LEN: u32 = 512;

// Workflow template: pre-built workflow definition.
pub const WorkflowTemplate = struct {
    name: [MAX_TEMPLATE_NAME_LEN]u8,
    name_len: u32,
    description: [MAX_TEMPLATE_DESC_LEN]u8,
    description_len: u32,
    node_count: u32,
    edge_count: u32,

    pub fn init(name: []const u8, description: []const u8) WorkflowTemplate {
        std.debug.assert(name.len > 0);
        std.debug.assert(description.len > 0);
        var template = WorkflowTemplate{
            .name = undefined,
            .name_len = 0,
            .description = undefined,
            .description_len = 0,
            .node_count = 0,
            .edge_count = 0,
        };
        var i: u32 = 0;
        while (i < MAX_TEMPLATE_NAME_LEN) : (i += 1) {
            template.name[i] = 0;
        }
        i = 0;
        while (i < MAX_TEMPLATE_DESC_LEN) : (i += 1) {
            template.description[i] = 0;
        }
        const name_len = @min(name.len, MAX_TEMPLATE_NAME_LEN - 1);
        i = 0;
        while (i < name_len) : (i += 1) {
            template.name[i] = name[i];
        }
        template.name_len = @intCast(name_len);
        const desc_len = @min(description.len, MAX_TEMPLATE_DESC_LEN - 1);
        i = 0;
        while (i < desc_len) : (i += 1) {
            template.description[i] = description[i];
        }
        template.description_len = @intCast(desc_len);
        return template;
    }
};

// Workflow template builder: builds workflows from templates.
pub const WorkflowTemplateBuilder = struct {
    bus: *event_bus.EventBus,
    coordinator: *agent_coordinator.AgentCoordinator,
    engine: *workflow_engine.WorkflowEngine,

    pub fn init(
        bus: *event_bus.EventBus,
        coordinator: *agent_coordinator.AgentCoordinator,
        engine: *workflow_engine.WorkflowEngine,
    ) WorkflowTemplateBuilder {
        _ = bus;
        _ = coordinator;
        _ = engine;
        return WorkflowTemplateBuilder{
            .bus = bus,
            .coordinator = coordinator,
            .engine = engine,
        };
    }

    // Create database backup workflow template.
    pub fn create_database_backup_workflow(
        self: *WorkflowTemplateBuilder,
        workflow_name: []const u8,
        silo_agent_id: u32,
        core_agent_id: u32,
        timeout_ms: u64,
    ) ?u32 {
        std.debug.assert(workflow_name.len > 0);
        std.debug.assert(silo_agent_id > 0);
        std.debug.assert(core_agent_id > 0);
        std.debug.assert(timeout_ms > 0);
        const workflow_id = self.engine.create_workflow(workflow_name, timeout_ms);
        if (workflow_id == null) {
            return null;
        }
        const workflow = self.engine.find_workflow(workflow_id.?);
        if (workflow == null) {
            return null;
        }
        const node1 = workflow_engine.WorkflowNode.init(
            1,
            "create_backup_snapshot",
            silo_agent_id,
        );
        const node2 = workflow_engine.WorkflowNode.init(
            2,
            "store_backup_file",
            core_agent_id,
        );
        const node3 = workflow_engine.WorkflowNode.init(
            3,
            "verify_backup_integrity",
            silo_agent_id,
        );
        const node4 = workflow_engine.WorkflowNode.init(
            4,
            "update_backup_metadata",
            core_agent_id,
        );
        _ = workflow.?.add_node(node1);
        _ = workflow.?.add_node(node2);
        _ = workflow.?.add_node(node3);
        _ = workflow.?.add_node(node4);
        const edge1 = workflow_engine.WorkflowEdge.init(1, 2, workflow_engine.EdgeType.dependency);
        const edge2 = workflow_engine.WorkflowEdge.init(2, 3, workflow_engine.EdgeType.dependency);
        const edge3 = workflow_engine.WorkflowEdge.init(3, 4, workflow_engine.EdgeType.dependency);
        _ = workflow.?.add_edge(edge1);
        _ = workflow.?.add_edge(edge2);
        _ = workflow.?.add_edge(edge3);
        return workflow_id;
    }

    // Create data sync workflow template (mobile to database).
    pub fn create_data_sync_workflow(
        self: *WorkflowTemplateBuilder,
        workflow_name: []const u8,
        carry_agent_id: u32,
        silo_agent_id: u32,
        timeout_ms: u64,
    ) ?u32 {
        std.debug.assert(workflow_name.len > 0);
        std.debug.assert(carry_agent_id > 0);
        std.debug.assert(silo_agent_id > 0);
        std.debug.assert(timeout_ms > 0);
        const workflow_id = self.engine.create_workflow(workflow_name, timeout_ms);
        if (workflow_id == null) {
            return null;
        }
        const workflow = self.engine.find_workflow(workflow_id.?);
        if (workflow == null) {
            return null;
        }
        const node1 = workflow_engine.WorkflowNode.init(1, "fetch_mobile_data", carry_agent_id);
        const node2 = workflow_engine.WorkflowNode.init(2, "validate_data", silo_agent_id);
        const node3 = workflow_engine.WorkflowNode.init(3, "store_in_database", silo_agent_id);
        const node4 = workflow_engine.WorkflowNode.init(4, "confirm_sync", carry_agent_id);
        _ = workflow.?.add_node(node1);
        _ = workflow.?.add_node(node2);
        _ = workflow.?.add_node(node3);
        _ = workflow.?.add_node(node4);
        const edge1 = workflow_engine.WorkflowEdge.init(1, 2, workflow_engine.EdgeType.data_flow);
        const edge2 = workflow_engine.WorkflowEdge.init(2, 3, workflow_engine.EdgeType.dependency);
        const edge3 = workflow_engine.WorkflowEdge.init(3, 4, workflow_engine.EdgeType.data_flow);
        _ = workflow.?.add_edge(edge1);
        _ = workflow.?.add_edge(edge2);
        _ = workflow.?.add_edge(edge3);
        return workflow_id;
    }

    // Create parallel processing workflow template.
    pub fn create_parallel_processing_workflow(
        self: *WorkflowTemplateBuilder,
        workflow_name: []const u8,
        agent_ids: []const u32,
        timeout_ms: u64,
    ) ?u32 {
        std.debug.assert(workflow_name.len > 0);
        std.debug.assert(agent_ids.len > 0);
        std.debug.assert(timeout_ms > 0);
        const workflow_id = self.engine.create_workflow(workflow_name, timeout_ms);
        if (workflow_id == null) {
            return null;
        }
        const workflow = self.engine.find_workflow(workflow_id.?);
        if (workflow == null) {
            return null;
        }
        var i: u32 = 0;
        while (i < agent_ids.len) : (i += 1) {
            std.debug.assert(agent_ids[i] > 0);
            var node_name_buf: [32]u8 = undefined;
            const node_name = std.fmt.bufPrint(
                &node_name_buf,
                "parallel_task_{d}",
                .{i + 1},
            ) catch return null;
            const node = workflow_engine.WorkflowNode.init(i + 1, node_name, agent_ids[i]);
            _ = workflow.?.add_node(node);
        }
        return workflow_id;
    }

    // Create sequential workflow template.
    pub fn create_sequential_workflow(
        self: *WorkflowTemplateBuilder,
        workflow_name: []const u8,
        agent_ids: []const u32,
        node_names: []const []const u8,
        timeout_ms: u64,
    ) ?u32 {
        std.debug.assert(workflow_name.len > 0);
        std.debug.assert(agent_ids.len > 0);
        std.debug.assert(node_names.len == agent_ids.len);
        std.debug.assert(timeout_ms > 0);
        const workflow_id = self.engine.create_workflow(workflow_name, timeout_ms);
        if (workflow_id == null) {
            return null;
        }
        const workflow = self.engine.find_workflow(workflow_id.?);
        if (workflow == null) {
            return null;
        }
        var i: u32 = 0;
        while (i < agent_ids.len) : (i += 1) {
            std.debug.assert(agent_ids[i] > 0);
            std.debug.assert(node_names[i].len > 0);
            const node = workflow_engine.WorkflowNode.init(i + 1, node_names[i], agent_ids[i]);
            _ = workflow.?.add_node(node);
            if (i > 0) {
                const edge = workflow_engine.WorkflowEdge.init(
                    i,
                    i + 1,
                    workflow_engine.EdgeType.dependency,
                );
                _ = workflow.?.add_edge(edge);
            }
        }
        return workflow_id;
    }

    // Create Nostr profile publishing workflow template.
    pub fn create_nostr_profile_publish_workflow(
        self: *WorkflowTemplateBuilder,
        workflow_name: []const u8,
        workspace_agent_id: u32,
        silo_agent_id: u32,
        aurora_agent_id: u32,
        skate_agent_id: u32,
        timeout_ms: u64,
    ) ?u32 {
        std.debug.assert(workflow_name.len > 0);
        std.debug.assert(workspace_agent_id > 0);
        std.debug.assert(silo_agent_id > 0);
        std.debug.assert(aurora_agent_id > 0);
        std.debug.assert(skate_agent_id > 0);
        std.debug.assert(timeout_ms > 0);
        const workflow_id = self.engine.create_workflow(workflow_name, timeout_ms);
        if (workflow_id == null) {
            return null;
        }
        const workflow = self.engine.find_workflow(workflow_id.?);
        if (workflow == null) {
            return null;
        }
        const node1 = workflow_engine.WorkflowNode.init(
            1,
            "create_profile_data",
            workspace_agent_id,
        );
        const node2 = workflow_engine.WorkflowNode.init(
            2,
            "store_profile_in_db",
            silo_agent_id,
        );
        const node3 = workflow_engine.WorkflowNode.init(
            3,
            "publish_to_nostr",
            aurora_agent_id,
        );
        const node4 = workflow_engine.WorkflowNode.init(
            4,
            "update_dag_relationships",
            skate_agent_id,
        );
        _ = workflow.?.add_node(node1);
        _ = workflow.?.add_node(node2);
        _ = workflow.?.add_node(node3);
        _ = workflow.?.add_node(node4);
        const edge1 = workflow_engine.WorkflowEdge.init(1, 2, workflow_engine.EdgeType.data_flow);
        const edge2 = workflow_engine.WorkflowEdge.init(2, 3, workflow_engine.EdgeType.dependency);
        const edge3 = workflow_engine.WorkflowEdge.init(3, 4, workflow_engine.EdgeType.data_flow);
        _ = workflow.?.add_edge(edge1);
        _ = workflow.?.add_edge(edge2);
        _ = workflow.?.add_edge(edge3);
        return workflow_id;
    }

    // Create DAG website publishing workflow template.
    pub fn create_dag_website_publish_workflow(
        self: *WorkflowTemplateBuilder,
        workflow_name: []const u8,
        workspace_agent_id: u32,
        skate_agent_id: u32,
        silo_agent_id: u32,
        aurora_agent_id: u32,
        timeout_ms: u64,
    ) ?u32 {
        std.debug.assert(workflow_name.len > 0);
        std.debug.assert(workspace_agent_id > 0);
        std.debug.assert(skate_agent_id > 0);
        std.debug.assert(silo_agent_id > 0);
        std.debug.assert(aurora_agent_id > 0);
        std.debug.assert(timeout_ms > 0);
        const workflow_id = self.engine.create_workflow(workflow_name, timeout_ms);
        if (workflow_id == null) {
            return null;
        }
        const workflow = self.engine.find_workflow(workflow_id.?);
        if (workflow == null) {
            return null;
        }
        const node1 = workflow_engine.WorkflowNode.init(
            1,
            "create_website_content",
            workspace_agent_id,
        );
        const node2 = workflow_engine.WorkflowNode.init(
            2,
            "build_dag_structure",
            skate_agent_id,
        );
        const node3 = workflow_engine.WorkflowNode.init(
            3,
            "store_website_data",
            silo_agent_id,
        );
        const node4 = workflow_engine.WorkflowNode.init(
            4,
            "publish_to_nostr",
            aurora_agent_id,
        );
        _ = workflow.?.add_node(node1);
        _ = workflow.?.add_node(node2);
        _ = workflow.?.add_node(node3);
        _ = workflow.?.add_node(node4);
        const edge1 = workflow_engine.WorkflowEdge.init(1, 2, workflow_engine.EdgeType.data_flow);
        const edge2 = workflow_engine.WorkflowEdge.init(2, 3, workflow_engine.EdgeType.dependency);
        const edge3 = workflow_engine.WorkflowEdge.init(3, 4, workflow_engine.EdgeType.data_flow);
        _ = workflow.?.add_edge(edge1);
        _ = workflow.?.add_edge(edge2);
        _ = workflow.?.add_edge(edge3);
        return workflow_id;
    }
};

// Get template information.
pub fn get_template_info() WorkflowTemplate {
    return WorkflowTemplate.init(
        "Database Backup",
        "Multi-agent workflow for database backup: Silo creates snapshot, Core stores file, Silo verifies, Core updates metadata",
    );
}
