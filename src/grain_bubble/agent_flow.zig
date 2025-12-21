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

// Flow node execution status (matches Flow Agent NodeStatus).
pub const FlowNodeStatus = enum(u8) {
    pending = 0,
    running = 1,
    completed = 2,
    failed = 3,
    skipped = 4,
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
    execution_status: FlowNodeStatus, // Execution status for visualization

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
            .execution_status = .pending,
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

    // Set execution status.
    pub fn set_execution_status(self: *FlowNode, status: FlowNodeStatus) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.execution_status = status;
    }

    // Get execution status.
    pub fn get_execution_status(self: *const FlowNode) FlowNodeStatus {
        std.debug.assert(@intFromPtr(self) != 0);
        return self.execution_status;
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

    // Render flow nodes as shapes on canvas.
    pub fn render_nodes(self: *AgentFlow, layer_id: u32) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(self.canvas_state) != 0);
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            const node = &self.nodes[i];
            const base_color: u32 = switch (node.node_type) {
                .start => 0xFF00FF00, // Green
                .agent => 0xFF0000FF, // Blue
                .task => 0xFFFF00FF, // Magenta
                .decision => 0xFFFFFF00, // Yellow
                .end => 0xFFFF0000, // Red
            };
            // Override color based on execution status.
            const color: u32 = switch (node.execution_status) {
                .pending => base_color,
                .running => 0xFFFFA500, // Orange for running
                .completed => 0xFF00FF00, // Green for completed
                .failed => 0xFFFF0000, // Red for failed
                .skipped => 0xFF808080, // Gray for skipped
            };
            _ = self.canvas_state.add_shape(
                layer_id,
                .rounded_rectangle,
                node.x,
                node.y,
                node.width,
                node.height,
                color,
                8.0, // Corner radius
            );
        }
        std.debug.assert(i == self.nodes_len);
    }

    // Set execution status for a node by ID.
    pub fn set_node_execution_status(
        self: *AgentFlow,
        node_id: u32,
        status: FlowNodeStatus,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        const node = self.get_node(node_id);
        if (node == null) {
            return false;
        }
        node.?.set_execution_status(status);
        return true;
    }

    // Get execution status for a node by ID.
    pub fn get_node_execution_status(
        self: *const AgentFlow,
        node_id: u32,
    ) ?FlowNodeStatus {
        std.debug.assert(@intFromPtr(self) != 0);
        const node = self.get_node(node_id);
        if (node == null) {
            return null;
        }
        return node.?.get_execution_status();
    }

    // Reset all node execution statuses to pending.
    pub fn reset_execution_statuses(self: *AgentFlow) void {
        std.debug.assert(@intFromPtr(self) != 0);
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            self.nodes[i].execution_status = .pending;
        }
        std.debug.assert(i == self.nodes_len);
    }

    // Get node at position (for selection).
    pub fn get_node_at_position(
        self: *const AgentFlow,
        x: f64,
        y: f64,
    ) ?*const FlowNode {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(x >= 0.0);
        std.debug.assert(y >= 0.0);
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            const node = &self.nodes[i];
            if (x >= node.x and x <= node.x + node.width and
                y >= node.y and y <= node.y + node.height)
            {
                return node;
            }
        }
        return null;
    }

    // Write workflow header to output buffer.
    fn write_workflow_header(
        workflow_name: []const u8,
        output: []u8,
        offset: *u32,
    ) void {
        std.debug.assert(workflow_name.len > 0);
        std.debug.assert(output.len > 0);
        std.debug.assert(@intFromPtr(offset) != 0);
        const header = "{\"workflow_name\":\"";
        if (offset.* + header.len < output.len) {
            @memcpy(output[offset.*..offset.* + header.len], header);
            offset.* += @as(u32, @intCast(header.len));
        }
        const name_len = @min(workflow_name.len, output.len - offset.* - 1);
        if (offset.* + name_len < output.len) {
            @memcpy(output[offset.*..offset.* + name_len], workflow_name[0..name_len]);
            offset.* += name_len;
        }
        const header2 = "\",\"nodes\":[";
        if (offset.* + header2.len < output.len) {
            @memcpy(output[offset.*..offset.* + header2.len], header2);
            offset.* += @as(u32, @intCast(header2.len));
        }
        std.debug.assert(offset.* <= output.len);
    }

    // Write a single node as JSON to output buffer.
    fn write_node_json(
        node: *const FlowNode,
        output: []u8,
        offset: *u32,
    ) void {
        std.debug.assert(@intFromPtr(node) != 0);
        std.debug.assert(output.len > 0);
        std.debug.assert(@intFromPtr(offset) != 0);
        const node_start = "{\"id\":";
        if (offset.* + node_start.len < output.len) {
            @memcpy(output[offset.*..offset.* + node_start.len], node_start);
            offset.* += @as(u32, @intCast(node_start.len));
        }
        const node_id_str = std.fmt.bufPrint(
            output[offset.*..@min(offset.* + 32, output.len)],
            "{}",
            .{node.id},
        ) catch return;
        const node_id_len = std.mem.indexOfScalar(u8, node_id_str, 0) orelse node_id_str.len;
        offset.* += @as(u32, @intCast(node_id_len));
        const node_type_str = switch (node.node_type) {
            .start => "start",
            .agent => "agent",
            .task => "task",
            .decision => "decision",
            .end => "end",
        };
        const node_mid = ",\"type\":\"";
        if (offset.* + node_mid.len < output.len) {
            @memcpy(output[offset.*..offset.* + node_mid.len], node_mid);
            offset.* += @as(u32, @intCast(node_mid.len));
        }
        if (offset.* + node_type_str.len < output.len) {
            @memcpy(output[offset.*..offset.* + node_type_str.len], node_type_str);
            offset.* += @as(u32, @intCast(node_type_str.len));
        }
        const node_name = node.name[0..node.name_len];
        const node_name_mid = "\",\"name\":\"";
        if (offset.* + node_name_mid.len < output.len) {
            @memcpy(output[offset.*..offset.* + node_name_mid.len], node_name_mid);
            offset.* += @as(u32, @intCast(node_name_mid.len));
        }
        const name_copy_len = @min(node_name.len, output.len - offset.* - 1);
        if (offset.* + name_copy_len < output.len) {
            @memcpy(output[offset.*..offset.* + name_copy_len], node_name[0..name_copy_len]);
            offset.* += name_copy_len;
        }
        if (node.node_type == .agent and node.agent_id > 0) {
            const agent_mid = "\",\"agent_id\":";
            if (offset.* + agent_mid.len < output.len) {
                @memcpy(output[offset.*..offset.* + agent_mid.len], agent_mid);
                offset.* += @as(u32, @intCast(agent_mid.len));
            }
            const agent_id_str = std.fmt.bufPrint(
                output[offset.*..@min(offset.* + 32, output.len)],
                "{}",
                .{node.agent_id},
            ) catch return;
            const agent_id_len = std.mem.indexOfScalar(u8, agent_id_str, 0) orelse agent_id_str.len;
            offset.* += @as(u32, @intCast(agent_id_len));
        }
        if (node.node_type == .task and node.task_name_len > 0) {
            const task_mid = ",\"task_name\":\"";
            if (offset.* + task_mid.len < output.len) {
                @memcpy(output[offset.*..offset.* + task_mid.len], task_mid);
                offset.* += @as(u32, @intCast(task_mid.len));
            }
            const task_name = node.task_name[0..node.task_name_len];
            const task_copy_len = @min(task_name.len, output.len - offset.* - 1);
            if (offset.* + task_copy_len < output.len) {
                @memcpy(output[offset.*..offset.* + task_copy_len], task_name[0..task_copy_len]);
                offset.* += task_copy_len;
            }
        }
        const node_end = "}";
        if (offset.* + node_end.len < output.len) {
            @memcpy(output[offset.*..offset.* + node_end.len], node_end);
            offset.* += @as(u32, @intCast(node_end.len));
        }
        std.debug.assert(offset.* <= output.len);
    }

    // Write a single connection as JSON to output buffer.
    fn write_connection_json(
        conn: *const FlowConnection,
        output: []u8,
        offset: *u32,
    ) void {
        std.debug.assert(@intFromPtr(conn) != 0);
        std.debug.assert(output.len > 0);
        std.debug.assert(@intFromPtr(offset) != 0);
        const conn_start_str = "{\"from\":";
        if (offset.* + conn_start_str.len < output.len) {
            @memcpy(output[offset.*..offset.* + conn_start_str.len], conn_start_str);
            offset.* += @as(u32, @intCast(conn_start_str.len));
        }
        const from_str = std.fmt.bufPrint(
            output[offset.*..@min(offset.* + 32, output.len)],
            "{}",
            .{conn.from_node_id},
        ) catch return;
        const from_len = std.mem.indexOfScalar(u8, from_str, 0) orelse from_str.len;
        offset.* += @as(u32, @intCast(from_len));
        const conn_mid = ",\"to\":";
        if (offset.* + conn_mid.len < output.len) {
            @memcpy(output[offset.*..offset.* + conn_mid.len], conn_mid);
            offset.* += @as(u32, @intCast(conn_mid.len));
        }
        const to_str = std.fmt.bufPrint(
            output[offset.*..@min(offset.* + 32, output.len)],
            "{}",
            .{conn.to_node_id},
        ) catch return;
        const to_len = std.mem.indexOfScalar(u8, to_str, 0) orelse to_str.len;
        offset.* += @as(u32, @intCast(to_len));
        if (conn.label_len > 0) {
            const label_mid = ",\"label\":\"";
            if (offset.* + label_mid.len < output.len) {
                @memcpy(output[offset.*..offset.* + label_mid.len], label_mid);
                offset.* += @as(u32, @intCast(label_mid.len));
            }
            const label = conn.label[0..conn.label_len];
            const label_copy_len = @min(label.len, output.len - offset.* - 1);
            if (offset.* + label_copy_len < output.len) {
                @memcpy(output[offset.*..offset.* + label_copy_len], label[0..label_copy_len]);
                offset.* += label_copy_len;
            }
        }
        if (conn.condition_len > 0) {
            const cond_mid = ",\"condition\":\"";
            if (offset.* + cond_mid.len < output.len) {
                @memcpy(output[offset.*..offset.* + cond_mid.len], cond_mid);
                offset.* += @as(u32, @intCast(cond_mid.len));
            }
            const condition = conn.condition[0..conn.condition_len];
            const cond_copy_len = @min(condition.len, output.len - offset.* - 1);
            if (offset.* + cond_copy_len < output.len) {
                @memcpy(output[offset.*..offset.* + cond_copy_len], condition[0..cond_copy_len]);
                offset.* += cond_copy_len;
            }
        }
        const conn_end = "}";
        if (offset.* + conn_end.len < output.len) {
            @memcpy(output[offset.*..offset.* + conn_end.len], conn_end);
            offset.* += @as(u32, @intCast(conn_end.len));
        }
        std.debug.assert(offset.* <= output.len);
    }

    // Export flow to Flow Agent workflow format (simplified representation).
    // Returns workflow data as JSON-like string representation.
    pub fn export_to_workflow_format(
        self: *const AgentFlow,
        workflow_name: []const u8,
        output: []u8,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(workflow_name.len > 0);
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;
        self.write_workflow_header(workflow_name, output, &offset);
        // Write nodes.
        var node_i: u32 = 0;
        while (node_i < self.nodes_len) : (node_i += 1) {
            if (node_i > 0) {
                if (offset < output.len) {
                    output[offset] = ',';
                    offset += 1;
                }
            }
            const node = &self.nodes[node_i];
            self.write_node_json(node, output, &offset);
        }
        // Write connections.
        const conn_start = "],\"connections\":[";
        if (offset + conn_start.len < output.len) {
            @memcpy(output[offset..offset + conn_start.len], conn_start);
            offset += @as(u32, @intCast(conn_start.len));
        }
        var conn_i: u32 = 0;
        while (conn_i < self.connections_len) : (conn_i += 1) {
            if (conn_i > 0) {
                if (offset < output.len) {
                    output[offset] = ',';
                    offset += 1;
                }
            }
            const conn = &self.connections[conn_i];
            self.write_connection_json(conn, output, &offset);
        }
        // Write footer.
        const footer = "]}";
        if (offset + footer.len < output.len) {
            @memcpy(output[offset..offset + footer.len], footer);
            offset += @as(u32, @intCast(footer.len));
        }
        std.debug.assert(offset <= output.len);
        return offset;
    }
};
