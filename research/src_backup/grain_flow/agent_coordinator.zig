//! Grain Flow Agent Coordinator: Agent registry, health monitoring, and RPC.
//!
//! Why: Provides agent coordination services for the Grain OS ecosystem.
//! Agents register with the coordinator, which tracks their health, capabilities,
//! and enables agent-to-agent RPC communication.
//!
//! Architecture: Agent registry, health monitoring, capability discovery, RPC.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-071000-pst: Phase 2 Agent Coordinator Foundation

const std = @import("std");
const event_bus = @import("event_bus.zig");

// Bounded: Max agents in registry.
pub const MAX_AGENTS: u32 = 64;

// Bounded: Max RPC requests in queue.
pub const MAX_RPC_REQUESTS: u32 = 1000;

// Bounded: Max agent name length.
pub const MAX_AGENT_NAME_LEN: u32 = 64;

// Bounded: Max capabilities per agent.
pub const MAX_CAPABILITIES: u32 = 32;

// Bounded: Max capability name length.
pub const MAX_CAPABILITY_NAME_LEN: u32 = 64;

// Agent status.
pub const AgentStatus = enum(u8) {
    inactive = 0,
    active = 1,
    unhealthy = 2,
    unknown = 3,
};

// Agent capability: represents a capability an agent provides.
pub const AgentCapability = struct {
    name: [MAX_CAPABILITY_NAME_LEN]u8,
    name_len: u32,
    version: u32,

    pub fn init() AgentCapability {
        var cap = AgentCapability{
            .name = undefined,
            .name_len = 0,
            .version = 0,
        };
        var i: u32 = 0;
        while (i < MAX_CAPABILITY_NAME_LEN) : (i += 1) {
            cap.name[i] = 0;
        }
        return cap;
    }

    pub fn set_name(self: *AgentCapability, name: []const u8) bool {
        std.debug.assert(name.len > 0);
        if (name.len > MAX_CAPABILITY_NAME_LEN) {
            return false;
        }
        var i: u32 = 0;
        while (i < name.len) : (i += 1) {
            self.name[i] = name[i];
        }
        self.name_len = @intCast(name.len);
        return true;
    }
};

// Agent: represents a registered agent.
pub const Agent = struct {
    agent_id: u32,
    name: [MAX_AGENT_NAME_LEN]u8,
    name_len: u32,
    status: AgentStatus,
    last_health_check: u64,
    capabilities: [MAX_CAPABILITIES]AgentCapability,
    capabilities_len: u32,
    registered_at: u64,
    active: bool,

    pub fn init(agent_id: u32, name: []const u8, timestamp: u64) Agent {
        std.debug.assert(agent_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(timestamp > 0);
        var agent = Agent{
            .agent_id = agent_id,
            .name = undefined,
            .name_len = 0,
            .status = AgentStatus.inactive,
            .last_health_check = 0,
            .capabilities = undefined,
            .capabilities_len = 0,
            .registered_at = timestamp,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_AGENT_NAME_LEN) : (i += 1) {
            agent.name[i] = 0;
        }
        i = 0;
        while (i < MAX_CAPABILITIES) : (i += 1) {
            agent.capabilities[i] = AgentCapability.init();
        }
        const name_len = @min(name.len, MAX_AGENT_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            agent.name[i] = name[i];
        }
        agent.name_len = @intCast(name_len);
        return agent;
    }

    pub fn add_capability(self: *Agent, capability: AgentCapability) bool {
        std.debug.assert(self.capabilities_len < MAX_CAPABILITIES);
        if (self.capabilities_len >= MAX_CAPABILITIES) {
            return false;
        }
        self.capabilities[self.capabilities_len] = capability;
        self.capabilities_len += 1;
        return true;
    }
};

// RPC request: represents an RPC request between agents.
pub const RpcRequest = struct {
    request_id: u32,
    from_agent_id: u32,
    to_agent_id: u32,
    method: [MAX_CAPABILITY_NAME_LEN]u8,
    method_len: u32,
    payload: [event_bus.MAX_PAYLOAD_SIZE]u8,
    payload_len: u32,
    timestamp: u64,
    processed: bool,

    pub fn init(
        request_id: u32,
        from_agent_id: u32,
        to_agent_id: u32,
        method: []const u8,
        timestamp: u64,
    ) RpcRequest {
        std.debug.assert(request_id > 0);
        std.debug.assert(from_agent_id > 0);
        std.debug.assert(to_agent_id > 0);
        std.debug.assert(method.len > 0);
        std.debug.assert(timestamp > 0);
        var req = RpcRequest{
            .request_id = request_id,
            .from_agent_id = from_agent_id,
            .to_agent_id = to_agent_id,
            .method = undefined,
            .method_len = 0,
            .payload = undefined,
            .payload_len = 0,
            .timestamp = timestamp,
            .processed = false,
        };
        var i: u32 = 0;
        while (i < MAX_CAPABILITY_NAME_LEN) : (i += 1) {
            req.method[i] = 0;
        }
        i = 0;
        while (i < event_bus.MAX_PAYLOAD_SIZE) : (i += 1) {
            req.payload[i] = 0;
        }
        const method_len = @min(method.len, MAX_CAPABILITY_NAME_LEN);
        i = 0;
        while (i < method_len) : (i += 1) {
            req.method[i] = method[i];
        }
        req.method_len = @intCast(method_len);
        return req;
    }

    pub fn set_payload(self: *RpcRequest, data: []const u8) bool {
        std.debug.assert(data.len > 0);
        if (data.len > event_bus.MAX_PAYLOAD_SIZE) {
            return false;
        }
        var i: u32 = 0;
        while (i < data.len) : (i += 1) {
            self.payload[i] = data[i];
        }
        self.payload_len = @intCast(data.len);
        return true;
    }
};

// Agent coordinator: manages agent registry and coordination.
pub const AgentCoordinator = struct {
    agents: [MAX_AGENTS]Agent,
    agents_len: u32,
    next_agent_id: u32,
    rpc_requests: [MAX_RPC_REQUESTS]RpcRequest,
    rpc_requests_head: u32,
    rpc_requests_tail: u32,
    rpc_requests_count: u32,
    next_request_id: u32,
    event_bus: *event_bus.EventBus,

    pub fn init(event_bus_instance: *event_bus.EventBus) AgentCoordinator {
        std.debug.assert(event_bus_instance != null);
        var coordinator = AgentCoordinator{
            .agents = undefined,
            .agents_len = 0,
            .next_agent_id = 1,
            .rpc_requests = undefined,
            .rpc_requests_head = 0,
            .rpc_requests_tail = 0,
            .rpc_requests_count = 0,
            .next_request_id = 1,
            .event_bus = event_bus_instance,
        };
        var i: u32 = 0;
        while (i < MAX_AGENTS) : (i += 1) {
            coordinator.agents[i] = Agent.init(0, "", 0);
        }
        i = 0;
        while (i < MAX_RPC_REQUESTS) : (i += 1) {
            coordinator.rpc_requests[i] = RpcRequest.init(0, 0, 0, "", 0);
        }
        return coordinator;
    }

    // Register agent with coordinator.
    pub fn register_agent(
        self: *AgentCoordinator,
        name: []const u8,
        timestamp: u64,
    ) ?u32 {
        std.debug.assert(name.len > 0);
        std.debug.assert(timestamp > 0);
        if (self.agents_len >= MAX_AGENTS) {
            return null;
        }
        const agent_id = self.next_agent_id;
        self.next_agent_id += 1;
        self.agents[self.agents_len] = Agent.init(agent_id, name, timestamp);
        self.agents[self.agents_len].status = AgentStatus.active;
        self.agents[self.agents_len].active = true;
        self.agents_len += 1;
        // Publish agent_started event.
        _ = self.event_bus.publish_event(
            event_bus.EventType.agent_started,
            agent_id,
            0,
            timestamp,
        );
        return agent_id;
    }

    // Unregister agent from coordinator.
    pub fn unregister_agent(
        self: *AgentCoordinator,
        agent_id: u32,
        timestamp: u64,
    ) bool {
        std.debug.assert(agent_id > 0);
        std.debug.assert(timestamp > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.agents_len) : (i += 1) {
            if (self.agents[i].agent_id == agent_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        self.agents[i].active = false;
        self.agents[i].status = AgentStatus.inactive;
        // Publish agent_stopped event.
        _ = self.event_bus.publish_event(
            event_bus.EventType.agent_stopped,
            agent_id,
            0,
            timestamp,
        );
        // Shift remaining agents left.
        while (i < self.agents_len - 1) : (i += 1) {
            self.agents[i] = self.agents[i + 1];
        }
        self.agents_len -= 1;
        return true;
    }

    // Find agent by ID.
    pub fn find_agent(self: *const AgentCoordinator, agent_id: u32) ?*const Agent {
        std.debug.assert(agent_id > 0);
        var i: u32 = 0;
        while (i < self.agents_len) : (i += 1) {
            if (self.agents[i].agent_id == agent_id) {
                return &self.agents[i];
            }
        }
        return null;
    }

    // Update agent health status.
    pub fn update_agent_health(
        self: *AgentCoordinator,
        agent_id: u32,
        status: AgentStatus,
        timestamp: u64,
    ) bool {
        std.debug.assert(agent_id > 0);
        std.debug.assert(timestamp > 0);
        var i: u32 = 0;
        while (i < self.agents_len) : (i += 1) {
            if (self.agents[i].agent_id == agent_id) {
                self.agents[i].status = status;
                self.agents[i].last_health_check = timestamp;
                // Publish health check event.
                _ = self.event_bus.publish_event(
                    event_bus.EventType.agent_health_check,
                    agent_id,
                    0,
                    timestamp,
                );
                return true;
            }
        }
        return false;
    }

    // Add capability to agent.
    pub fn add_agent_capability(
        self: *AgentCoordinator,
        agent_id: u32,
        capability: AgentCapability,
    ) bool {
        std.debug.assert(agent_id > 0);
        var i: u32 = 0;
        while (i < self.agents_len) : (i += 1) {
            if (self.agents[i].agent_id == agent_id) {
                return self.agents[i].add_capability(capability);
            }
        }
        return false;
    }

    // Find agents by capability.
    pub fn find_agents_by_capability(
        self: *const AgentCoordinator,
        capability_name: []const u8,
        results: []u32,
    ) u32 {
        std.debug.assert(capability_name.len > 0);
        std.debug.assert(results.len > 0);
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.agents_len and count < results.len) : (i += 1) {
            if (!self.agents[i].active) {
                continue;
            }
            var j: u32 = 0;
            while (j < self.agents[i].capabilities_len) : (j += 1) {
                const cap = &self.agents[i].capabilities[j];
                if (cap.name_len == capability_name.len) {
                    var match: bool = true;
                    var k: u32 = 0;
                    while (k < cap.name_len) : (k += 1) {
                        if (cap.name[k] != capability_name[k]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        results[count] = self.agents[i].agent_id;
                        count += 1;
                        break;
                    }
                }
            }
        }
        return count;
    }

    // Send RPC request to agent.
    pub fn send_rpc_request(
        self: *AgentCoordinator,
        from_agent_id: u32,
        to_agent_id: u32,
        method: []const u8,
        payload: []const u8,
        timestamp: u64,
    ) ?u32 {
        std.debug.assert(from_agent_id > 0);
        std.debug.assert(to_agent_id > 0);
        std.debug.assert(method.len > 0);
        std.debug.assert(timestamp > 0);
        if (self.rpc_requests_count >= MAX_RPC_REQUESTS) {
            return null;
        }
        const request_id = self.next_request_id;
        self.next_request_id += 1;
        const idx = self.rpc_requests_tail;
        self.rpc_requests[idx] = RpcRequest.init(
            request_id,
            from_agent_id,
            to_agent_id,
            method,
            timestamp,
        );
        if (payload.len > 0) {
            _ = self.rpc_requests[idx].set_payload(payload);
        }
        self.rpc_requests_tail = (self.rpc_requests_tail + 1) % MAX_RPC_REQUESTS;
        self.rpc_requests_count += 1;
        return request_id;
    }

    // Get RPC request by ID.
    pub fn get_rpc_request(
        self: *const AgentCoordinator,
        request_id: u32,
    ) ?*const RpcRequest {
        std.debug.assert(request_id > 0);
        var i: u32 = 0;
        while (i < self.rpc_requests_count) : (i += 1) {
            const idx = (self.rpc_requests_head + i) % MAX_RPC_REQUESTS;
            const req = &self.rpc_requests[idx];
            if (req.request_id == request_id) {
                return req;
            }
        }
        return null;
    }

    // Get agent count.
    pub fn get_agent_count(self: *const AgentCoordinator) u32 {
        return self.agents_len;
    }

    // Get active agent count.
    pub fn get_active_agent_count(self: *const AgentCoordinator) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.agents_len) : (i += 1) {
            if (self.agents[i].active) {
                count += 1;
            }
        }
        return count;
    }

    // Get RPC request count.
    pub fn get_rpc_request_count(self: *const AgentCoordinator) u32 {
        return self.rpc_requests_count;
    }
};
