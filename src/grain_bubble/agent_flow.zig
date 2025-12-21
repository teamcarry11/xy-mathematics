//! Grain Bubble Agent Flow: Visual agent workflow design.
//!
//! Why: Visual design tool for creating agent workflows.
//! Architecture: Flow nodes, connections, and canvas integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-152034-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");

// Bounded: Max flow nodes.
pub const MAX_FLOW_NODES: u32 = 1000;

// Bounded: Max flow connections.
pub const MAX_FLOW_CONNECTIONS: u32 = 2000;

// Bounded: Max node name length.
pub const MAX_NODE_NAME_LEN: u32 = 64;

// Bounded: Max node config length.
pub const MAX_NODE_CONFIG_LEN: u32 = 1024;

// Flow node type.
pub const FlowNodeType = enum(u8) {
    start = 0,
    agent = 1,
    task = 2,
    decision = 3,
    end = 4,
};

// Flow node: represents an agent, task, or decision point.
pub const FlowNode = struct {
    id: u32,
    node_type: FlowNodeType,
    name: [MAX_NODE_NAME_LEN]u8,
    name_len: u32,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    config: [MAX_NODE_CONFIG_LEN]u8,
    config_len: u32,
    agent_id: u32, // For agent nodes: which agent to use
    task_name: [MAX_NODE_NAME_LEN]u8, // For task nodes: task name
    task_name_len: u32,

    pub fn init(
        id: u32,
        node_type: FlowNodeType,
        name: []const u8,
        x: f64,
        y: f64,
    ) FlowNode {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_NODE_NAME_LEN);
        std.debug.assert(x >= 0.0);
        std.debug.assert(y >= 0.0);
        var node = FlowNode{
            .id = id,
            .node_type = node_type,
            .name = undefined,
            .name_len = 0,
            .x = x,
            .y = y,
            .width = 120.0,
            .height = 60.0,
            .config = undefined,
            .config_len = 0,
            .agent_id = 0,
            .task_name = undefined,
            .task_name_len = 0,
        };
        @memset(node.name[0..], 0);
        @memset(node.config[0..], 0);
        @memset(node.task_name[0..], 0);
        const name_len = @min(name.len, MAX_NODE_NAME_LEN);
        @memcpy(node.name[0..name_len], name[0..name_len]);
        node.name_len = @as(u32, @intCast(name_len));
        std.debug.assert(node.name_len > 0);
        std.debug.assert(node.x >= 0.0);
        std.debug.assert(node.y >= 0.0);
        return node;
    }

    // Set node configuration.
    pub fn set_config(self: *FlowNode, config: []const u8) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(config.len <= MAX_NODE_CONFIG_LEN);
        const copy_len = @min(config.len, MAX_NODE_CONFIG_LEN);
        @memcpy(self.config[0..copy_len], config[0..copy_len]);
        self.config_len = @as(u32, @intCast(copy_len));
        std.debug.assert(self.config_len <= MAX_NODE_CONFIG_LEN);
    }

    // Set agent ID for agent nodes.
    pub fn set_agent_id(self: *FlowNode, agent_id: u32) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(self.node_type == .agent);
        self.agent_id = agent_id;
    }

    // Set task name for task nodes.
    pub fn set_task_name(self: *FlowNode, task_name: []const u8) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(self.node_type == .task);
        std.debug.assert(task_name.len > 0);
        std.debug.assert(task_name.len <= MAX_NODE_NAME_LEN);
        const copy_len = @min(task_name.len, MAX_NODE_NAME_LEN);
        @memcpy(self.task_name[0..copy_len], task_name[0..copy_len]);
        self.task_name_len = @as(u32, @intCast(copy_len));
        std.debug.assert(self.task_name_len > 0);
    }
};

// Flow connection: connection between two nodes.
pub const FlowConnection = struct {
    id: u32,
    from_node_id: u32,
    to_node_id: u32,
    label: [MAX_NODE_NAME_LEN]u8,
    label_len: u32,
    condition: [MAX_NODE_CONFIG_LEN]u8, // For decision nodes
    condition_len: u32,

    pub fn init(
        id: u32,
        from_node_id: u32,
        to_node_id: u32,
    ) FlowConnection {
        std.debug.assert(from_node_id != to_node_id);
        var conn = FlowConnection{
            .id = id,
            .from_node_id = from_node_id,
            .to_node_id = to_node_id,
            .label = undefined,
            .label_len = 0,
            .condition = undefined,
            .condition_len = 0,
        };
        @memset(conn.label[0..], 0);
        @memset(conn.condition[0..], 0);
        std.debug.assert(conn.from_node_id != conn.to_node_id);
        return conn;
    }

    // Set connection label.
    pub fn set_label(self: *FlowConnection, label: []const u8) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(label.len <= MAX_NODE_NAME_LEN);
        const copy_len = @min(label.len, MAX_NODE_NAME_LEN);
        @memcpy(self.label[0..copy_len], label[0..copy_len]);
        self.label_len = @as(u32, @intCast(copy_len));
    }

    // Set condition for decision connections.
    pub fn set_condition(self: *FlowConnection, condition: []const u8) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(condition.len <= MAX_NODE_CONFIG_LEN);
        const copy_len = @min(condition.len, MAX_NODE_CONFIG_LEN);
        @memcpy(self.condition[0..copy_len], condition[0..copy_len]);
        self.condition_len = @as(u32, @intCast(copy_len));
    }
};

// Agent flow: complete flow design with nodes and connections.
pub const AgentFlow = struct {
    nodes: [MAX_FLOW_NODES]FlowNode,
    nodes_len: u32,
    connections: [MAX_FLOW_CONNECTIONS]FlowConnection,
    connections_len: u32,
    next_node_id: u32,
    next_connection_id: u32,
    canvas_state: *canvas.Canvas,

    pub fn init(canvas_state: *canvas.Canvas) AgentFlow {
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        var flow = AgentFlow{
            .nodes = undefined,
            .nodes_len = 0,
            .connections = undefined,
            .connections_len = 0,
            .next_node_id = 1,
            .next_connection_id = 1,
            .canvas_state = canvas_state,
        };
        std.debug.assert(flow.nodes_len == 0);
        std.debug.assert(flow.connections_len == 0);
        std.debug.assert(flow.next_node_id == 1);
        return flow;
    }

    // Add a flow node.
    pub fn add_node(
        self: *AgentFlow,
        node_type: FlowNodeType,
        name: []const u8,
        x: f64,
        y: f64,
    ) ?*FlowNode {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(self.nodes_len < MAX_FLOW_NODES);
        std.debug.assert(name.len > 0);
        std.debug.assert(x >= 0.0);
        std.debug.assert(y >= 0.0);
        if (self.nodes_len >= MAX_FLOW_NODES) {
            return null;
        }
        const node_id = self.next_node_id;
        self.next_node_id += 1;
        const node = FlowNode.init(node_id, node_type, name, x, y);
        self.nodes[self.nodes_len] = node;
        self.nodes_len += 1;
        std.debug.assert(self.nodes_len <= MAX_FLOW_NODES);
        return &self.nodes[self.nodes_len - 1];
    }

    // Get a flow node by ID.
    pub fn get_node(self: *AgentFlow, node_id: u32) ?*FlowNode {
        std.debug.assert(@intFromPtr(self) != 0);
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            if (self.nodes[i].id == node_id) {
                return &self.nodes[i];
            }
        }
        return null;
    }

    // Add a flow connection.
    pub fn add_connection(
        self: *AgentFlow,
        from_node_id: u32,
        to_node_id: u32,
    ) ?*FlowConnection {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(self.connections_len < MAX_FLOW_CONNECTIONS);
        std.debug.assert(from_node_id != to_node_id);
        if (self.connections_len >= MAX_FLOW_CONNECTIONS) {
            return null;
        }
        const from_node = self.get_node(from_node_id);
        const to_node = self.get_node(to_node_id);
        if (from_node == null or to_node == null) {
            return null;
        }
        const conn_id = self.next_connection_id;
        self.next_connection_id += 1;
        const conn = FlowConnection.init(conn_id, from_node_id, to_node_id);
        self.connections[self.connections_len] = conn;
        self.connections_len += 1;
        std.debug.assert(self.connections_len <= MAX_FLOW_CONNECTIONS);
        return &self.connections[self.connections_len - 1];
    }

    // Get a flow connection by ID.
    pub fn get_connection(self: *AgentFlow, connection_id: u32) ?*FlowConnection {
        std.debug.assert(@intFromPtr(self) != 0);
        var i: u32 = 0;
        while (i < self.connections_len) : (i += 1) {
            if (self.connections[i].id == connection_id) {
                return &self.connections[i];
            }
        }
        return null;
    }

    // Remove a flow node and its connections.
    pub fn remove_node(self: *AgentFlow, node_id: u32) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        var node_idx: ?u32 = null;
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            if (self.nodes[i].id == node_id) {
                node_idx = i;
                break;
            }
        }
        if (node_idx == null) {
            return false;
        }
        const idx = node_idx.?;
        // Remove connections to/from this node.
        var conn_i: u32 = 0;
        while (conn_i < self.connections_len) {
            const conn = &self.connections[conn_i];
            if (conn.from_node_id == node_id or conn.to_node_id == node_id) {
                // Remove connection by shifting.
                var j: u32 = conn_i;
                while (j < self.connections_len - 1) : (j += 1) {
                    self.connections[j] = self.connections[j + 1];
                }
                self.connections_len -= 1;
            } else {
                conn_i += 1;
            }
        }
        // Remove node by shifting.
        i = idx;
        while (i < self.nodes_len - 1) : (i += 1) {
            self.nodes[i] = self.nodes[i + 1];
        }
        self.nodes_len -= 1;
        std.debug.assert(self.nodes_len < MAX_FLOW_NODES);
        return true;
    }

    // Remove a flow connection.
    pub fn remove_connection(self: *AgentFlow, connection_id: u32) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        var conn_idx: ?u32 = null;
        var i: u32 = 0;
        while (i < self.connections_len) : (i += 1) {
            if (self.connections[i].id == connection_id) {
                conn_idx = i;
                break;
            }
        }
        if (conn_idx == null) {
            return false;
        }
        const idx = conn_idx.?;
        // Remove connection by shifting.
        i = idx;
        while (i < self.connections_len - 1) : (i += 1) {
            self.connections[i] = self.connections[i + 1];
        }
        self.connections_len -= 1;
        std.debug.assert(self.connections_len < MAX_FLOW_CONNECTIONS);
        return true;
    }

    // Get node count.
    pub fn get_node_count(self: *const AgentFlow) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        return self.nodes_len;
    }

    // Get connection count.
    pub fn get_connection_count(self: *const AgentFlow) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        return self.connections_len;
    }
};
