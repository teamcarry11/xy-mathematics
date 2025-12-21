//! Grain Flow Workflow Engine: DAG-based workflow execution.
//!
//! Why: Provides DAG-based workflow execution for coordinating multiple agents.
//! Workflows define nodes (tasks/agents) and edges (dependencies), and the engine
//! executes them iteratively in topological order.
//!
//! Architecture: Workflow DAG, iterative execution, state management, error handling.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-072000-pst: Phase 3 Workflow Engine Foundation

const std = @import("std");
const event_bus = @import("event_bus.zig");
const agent_coordinator = @import("agent_coordinator.zig");
const workflow_metrics = @import("workflow_metrics.zig");

// Bounded: Max workflow depth (max path length).
pub const MAX_WORKFLOW_DEPTH: u32 = 1000;

// Bounded: Max workflow nodes.
pub const MAX_WORKFLOW_NODES: u32 = 10000;

// Bounded: Max workflow edges.
pub const MAX_WORKFLOW_EDGES: u32 = 100000;

// Bounded: Max node name length.
pub const MAX_NODE_NAME_LEN: u32 = 128;

// Bounded: Max state data size.
pub const MAX_STATE_DATA_SIZE: u32 = 65536;

// Workflow node status.
pub const NodeStatus = enum(u8) {
    pending = 0,
    running = 1,
    completed = 2,
    failed = 3,
    skipped = 4,
};

// Workflow status.
pub const WorkflowStatus = enum(u8) {
    pending = 0,
    running = 1,
    completed = 2,
    failed = 3,
    cancelled = 4,
};

// Workflow node: represents a task/agent in the workflow.
pub const WorkflowNode = struct {
    node_id: u32,
    name: [MAX_NODE_NAME_LEN]u8,
    name_len: u32,
    agent_id: u32,
    status: NodeStatus,
    started_at: u64,
    completed_at: u64,
    error_message: [256]u8,
    error_message_len: u32,
    state_data: [MAX_STATE_DATA_SIZE]u8,
    state_data_len: u32,

    pub fn init(node_id: u32, name: []const u8, agent_id: u32) WorkflowNode {
        std.debug.assert(node_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(agent_id > 0);
        var node = WorkflowNode{
            .node_id = node_id,
            .name = undefined,
            .name_len = 0,
            .agent_id = agent_id,
            .status = NodeStatus.pending,
            .started_at = 0,
            .completed_at = 0,
            .error_message = undefined,
            .error_message_len = 0,
            .state_data = undefined,
            .state_data_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_NODE_NAME_LEN) : (i += 1) {
            node.name[i] = 0;
        }
        i = 0;
        while (i < 256) : (i += 1) {
            node.error_message[i] = 0;
        }
        i = 0;
        while (i < MAX_STATE_DATA_SIZE) : (i += 1) {
            node.state_data[i] = 0;
        }
        const name_len = @min(name.len, MAX_NODE_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            node.name[i] = name[i];
        }
        node.name_len = @intCast(name_len);
        return node;
    }

    pub fn set_error(self: *WorkflowNode, message: []const u8) bool {
        std.debug.assert(message.len > 0);
        if (message.len > 256) {
            return false;
        }
        var i: u32 = 0;
        while (i < message.len) : (i += 1) {
            self.error_message[i] = message[i];
        }
        self.error_message_len = @intCast(message.len);
        return true;
    }

    pub fn set_state_data(self: *WorkflowNode, data: []const u8) bool {
        std.debug.assert(data.len > 0);
        if (data.len > MAX_STATE_DATA_SIZE) {
            return false;
        }
        var i: u32 = 0;
        while (i < data.len) : (i += 1) {
            self.state_data[i] = data[i];
        }
        self.state_data_len = @intCast(data.len);
        return true;
    }
};

// Workflow edge: represents a dependency between nodes.
pub const WorkflowEdge = struct {
    from_node_id: u32,
    to_node_id: u32,
    edge_type: EdgeType,

    pub fn init(from_node_id: u32, to_node_id: u32, edge_type: EdgeType) WorkflowEdge {
        std.debug.assert(from_node_id > 0);
        std.debug.assert(to_node_id > 0);
        std.debug.assert(from_node_id != to_node_id);
        return WorkflowEdge{
            .from_node_id = from_node_id,
            .to_node_id = to_node_id,
            .edge_type = edge_type,
        };
    }
};

// Edge type: type of dependency.
pub const EdgeType = enum(u8) {
    dependency = 0,
    data_flow = 1,
    conditional = 2,
};

// Workflow: represents a complete workflow DAG.
pub const Workflow = struct {
    workflow_id: u32,
    name: [MAX_NODE_NAME_LEN]u8,
    name_len: u32,
    nodes: [MAX_WORKFLOW_NODES]WorkflowNode,
    nodes_len: u32,
    edges: [MAX_WORKFLOW_EDGES]WorkflowEdge,
    edges_len: u32,
    status: WorkflowStatus,
    created_at: u64,
    started_at: u64,
    completed_at: u64,

    pub fn init(workflow_id: u32, name: []const u8, timestamp: u64) Workflow {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(timestamp > 0);
        var workflow = Workflow{
            .workflow_id = workflow_id,
            .name = undefined,
            .name_len = 0,
            .nodes = undefined,
            .nodes_len = 0,
            .edges = undefined,
            .edges_len = 0,
            .status = WorkflowStatus.pending,
            .created_at = timestamp,
            .started_at = 0,
            .completed_at = 0,
        };
        var i: u32 = 0;
        while (i < MAX_NODE_NAME_LEN) : (i += 1) {
            workflow.name[i] = 0;
        }
        i = 0;
        while (i < MAX_WORKFLOW_NODES) : (i += 1) {
            workflow.nodes[i] = WorkflowNode.init(0, "", 0);
        }
        i = 0;
        while (i < MAX_WORKFLOW_EDGES) : (i += 1) {
            workflow.edges[i] = WorkflowEdge.init(0, 0, EdgeType.dependency);
        }
        const name_len = @min(name.len, MAX_NODE_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            workflow.name[i] = name[i];
        }
        workflow.name_len = @intCast(name_len);
        return workflow;
    }

    pub fn add_node(self: *Workflow, node: WorkflowNode) bool {
        std.debug.assert(node.node_id > 0);
        if (self.nodes_len >= MAX_WORKFLOW_NODES) {
            return false;
        }
        self.nodes[self.nodes_len] = node;
        self.nodes_len += 1;
        return true;
    }

    pub fn add_edge(self: *Workflow, edge: WorkflowEdge) bool {
        std.debug.assert(edge.from_node_id > 0);
        std.debug.assert(edge.to_node_id > 0);
        if (self.edges_len >= MAX_WORKFLOW_EDGES) {
            return false;
        }
        self.edges[self.edges_len] = edge;
        self.edges_len += 1;
        return true;
    }

    pub fn find_node(self: *const Workflow, node_id: u32) ?*const WorkflowNode {
        std.debug.assert(node_id > 0);
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            if (self.nodes[i].node_id == node_id) {
                return &self.nodes[i];
            }
        }
        return null;
    }
};

// Workflow engine: executes workflows.
pub const WorkflowEngine = struct {
    workflows: [64]Workflow,
    workflows_len: u32,
    next_workflow_id: u32,
    event_bus: *event_bus.EventBus,
    agent_coordinator: *agent_coordinator.AgentCoordinator,
    metrics_collector: ?*workflow_metrics.WorkflowMetricsCollector,

    pub fn init(
        event_bus_instance: *event_bus.EventBus,
        coordinator_instance: *agent_coordinator.AgentCoordinator,
    ) WorkflowEngine {
        std.debug.assert(event_bus_instance != null);
        std.debug.assert(coordinator_instance != null);
        var engine = WorkflowEngine{
            .workflows = undefined,
            .workflows_len = 0,
            .next_workflow_id = 1,
            .event_bus = event_bus_instance,
            .agent_coordinator = coordinator_instance,
            .metrics_collector = null,
        };
        var i: u32 = 0;
        while (i < 64) : (i += 1) {
            engine.workflows[i] = Workflow.init(0, "", 0);
        }
        return engine;
    }

    // Create workflow.
    pub fn create_workflow(
        self: *WorkflowEngine,
        name: []const u8,
        timestamp: u64,
    ) ?u32 {
        std.debug.assert(name.len > 0);
        std.debug.assert(timestamp > 0);
        if (self.workflows_len >= 64) {
            return null;
        }
        const workflow_id = self.next_workflow_id;
        self.next_workflow_id += 1;
        self.workflows[self.workflows_len] = Workflow.init(workflow_id, name, timestamp);
        self.workflows_len += 1;
        return workflow_id;
    }

    // Find workflow by ID.
    pub fn find_workflow(self: *WorkflowEngine, workflow_id: u32) ?*Workflow {
        std.debug.assert(workflow_id > 0);
        var i: u32 = 0;
        while (i < self.workflows_len) : (i += 1) {
            if (self.workflows[i].workflow_id == workflow_id) {
                return &self.workflows[i];
            }
        }
        return null;
    }

    // Execute workflow (iterative topological sort).
    pub fn execute_workflow(
        self: *WorkflowEngine,
        workflow_id: u32,
        timestamp: u64,
    ) bool {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(timestamp > 0);
        const workflow = self.find_workflow(workflow_id);
        if (workflow == null) {
            return false;
        }
        if (workflow.?.status != WorkflowStatus.pending) {
            return false;
        }
        workflow.?.status = WorkflowStatus.running;
        workflow.?.started_at = timestamp;
        _ = self.event_bus.publish_event(
            event_bus.EventType.workflow_started,
            workflow_id,
            0,
            timestamp,
        );
        // Topological sort (iterative, no recursion).
        var ready_nodes: [MAX_WORKFLOW_NODES]u32 = undefined;
        var ready_count: u32 = 0;
        var in_degree: [MAX_WORKFLOW_NODES]u32 = undefined;
        var i: u32 = 0;
        while (i < workflow.?.nodes_len) : (i += 1) {
            in_degree[i] = 0;
        }
        i = 0;
        while (i < workflow.?.edges_len) : (i += 1) {
            const edge = &workflow.?.edges[i];
            var j: u32 = 0;
            var to_idx: u32 = 0;
            var found: bool = false;
            while (j < workflow.?.nodes_len) : (j += 1) {
                if (workflow.?.nodes[j].node_id == edge.to_node_id) {
                    to_idx = j;
                    found = true;
                    break;
                }
            }
            if (found) {
                in_degree[to_idx] += 1;
            }
        }
        i = 0;
        while (i < workflow.?.nodes_len) : (i += 1) {
            if (in_degree[i] == 0) {
                ready_nodes[ready_count] = i;
                ready_count += 1;
            }
        }
        var processed: u32 = 0;
        while (processed < ready_count) {
            const node_idx = ready_nodes[processed];
            const node = &workflow.?.nodes[node_idx];
            node.status = NodeStatus.running;
            node.started_at = timestamp;
            // Execute node (placeholder - actual execution via agent coordinator).
            node.status = NodeStatus.completed;
            node.completed_at = timestamp;
            _ = self.event_bus.publish_event(
                event_bus.EventType.task_completed,
                node.agent_id,
                workflow_id,
                timestamp,
            );
            processed += 1;
            i = 0;
            while (i < workflow.?.edges_len) : (i += 1) {
                const edge = &workflow.?.edges[i];
                if (edge.from_node_id == node.node_id) {
                    var j: u32 = 0;
                    var to_idx: u32 = 0;
                    var found: bool = false;
                    while (j < workflow.?.nodes_len) : (j += 1) {
                        if (workflow.?.nodes[j].node_id == edge.to_node_id) {
                            to_idx = j;
                            found = true;
                            break;
                        }
                    }
                    if (found) {
                        in_degree[to_idx] -= 1;
                        if (in_degree[to_idx] == 0) {
                            ready_nodes[ready_count] = to_idx;
                            ready_count += 1;
                        }
                    }
                }
            }
        }
        if (processed == workflow.?.nodes_len) {
            workflow.?.status = WorkflowStatus.completed;
            workflow.?.completed_at = timestamp;
            _ = self.event_bus.publish_event(
                event_bus.EventType.workflow_completed,
                workflow_id,
                0,
                timestamp,
            );
            // Record successful execution metric.
            if (self.metrics_collector) |collector| {
                var name_buf: [MAX_NODE_NAME_LEN]u8 = undefined;
                var name_len: u32 = 0;
                var i: u32 = 0;
                while (i < workflow.?.name_len) : (i += 1) {
                    name_buf[i] = workflow.?.name[i];
                }
                name_len = workflow.?.name_len;
                _ = collector.record_execution(
                    workflow_id,
                    name_buf[0..name_len],
                    workflow.?.started_at,
                    timestamp,
                    workflow_metrics.WorkflowExecutionStatus.success,
                );
            }
        } else {
            workflow.?.status = WorkflowStatus.failed;
            workflow.?.completed_at = timestamp;
            _ = self.event_bus.publish_event(
                event_bus.EventType.workflow_failed,
                workflow_id,
                0,
                timestamp,
            );
            // Record failed execution metric.
            if (self.metrics_collector) |collector| {
                var name_buf: [MAX_NODE_NAME_LEN]u8 = undefined;
                var name_len: u32 = 0;
                var i: u32 = 0;
                while (i < workflow.?.name_len) : (i += 1) {
                    name_buf[i] = workflow.?.name[i];
                }
                name_len = workflow.?.name_len;
                _ = collector.record_execution(
                    workflow_id,
                    name_buf[0..name_len],
                    workflow.?.started_at,
                    timestamp,
                    workflow_metrics.WorkflowExecutionStatus.failure,
                );
            }
        }
        return true;
    }

    // Set metrics collector (optional, for observability).
    pub fn set_metrics_collector(
        self: *WorkflowEngine,
        collector: *workflow_metrics.WorkflowMetricsCollector,
    ) void {
        std.debug.assert(@intFromPtr(collector) != 0);
        self.metrics_collector = collector;
    }

    // Get workflow count.
    pub fn get_workflow_count(self: *const WorkflowEngine) u32 {
        return self.workflows_len;
    }
};
