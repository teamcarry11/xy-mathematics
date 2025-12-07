//! Grain Flow Agent Coordinator Tests: Comprehensive tests for agent coordination.
//!
//! Why: Verify agent registry, health monitoring, capability discovery, and RPC.
//! Architecture: Tests agent registration, health updates, capabilities, RPC requests.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-071000-pst: Phase 2 Agent Coordinator Foundation

const std = @import("std");
const grain_flow = @import("grain_flow");
const event_bus = grain_flow.event_bus;
const agent_coordinator = grain_flow.agent_coordinator;

test "agent coordinator initialization" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    try std.testing.expect(coordinator.get_agent_count() == 0);
    try std.testing.expect(coordinator.get_active_agent_count() == 0);
    try std.testing.expect(coordinator.get_rpc_request_count() == 0);
}

test "register agent" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    const agent_id = coordinator.register_agent("test_agent", 1000);
    try std.testing.expect(agent_id != null);
    try std.testing.expect(agent_id.? > 0);
    try std.testing.expect(coordinator.get_agent_count() == 1);
    try std.testing.expect(coordinator.get_active_agent_count() == 1);
}

test "unregister agent" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    const agent_id = coordinator.register_agent("test_agent", 1000);
    try std.testing.expect(agent_id != null);
    const result = coordinator.unregister_agent(agent_id.?, 2000);
    try std.testing.expect(result == true);
    try std.testing.expect(coordinator.get_agent_count() == 0);
    try std.testing.expect(coordinator.get_active_agent_count() == 0);
}

test "find agent by ID" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    const agent_id = coordinator.register_agent("test_agent", 1000);
    try std.testing.expect(agent_id != null);
    const agent = coordinator.find_agent(agent_id.?);
    try std.testing.expect(agent != null);
    try std.testing.expect(agent.?.agent_id == agent_id.?);
}

test "update agent health" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    const agent_id = coordinator.register_agent("test_agent", 1000);
    try std.testing.expect(agent_id != null);
    const result = coordinator.update_agent_health(
        agent_id.?,
        agent_coordinator.AgentStatus.unhealthy,
        2000,
    );
    try std.testing.expect(result == true);
    const agent = coordinator.find_agent(agent_id.?);
    try std.testing.expect(agent != null);
    try std.testing.expect(agent.?.status == agent_coordinator.AgentStatus.unhealthy);
}

test "add agent capability" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    const agent_id = coordinator.register_agent("test_agent", 1000);
    try std.testing.expect(agent_id != null);
    var capability = agent_coordinator.AgentCapability.init();
    _ = capability.set_name("test_capability");
    capability.version = 1;
    const result = coordinator.add_agent_capability(agent_id.?, capability);
    try std.testing.expect(result == true);
    const agent = coordinator.find_agent(agent_id.?);
    try std.testing.expect(agent != null);
    try std.testing.expect(agent.?.capabilities_len == 1);
}

test "find agents by capability" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    const agent_id1 = coordinator.register_agent("agent1", 1000);
    const agent_id2 = coordinator.register_agent("agent2", 1000);
    try std.testing.expect(agent_id1 != null);
    try std.testing.expect(agent_id2 != null);
    var capability = agent_coordinator.AgentCapability.init();
    _ = capability.set_name("shared_capability");
    capability.version = 1;
    _ = coordinator.add_agent_capability(agent_id1.?, capability);
    _ = coordinator.add_agent_capability(agent_id2.?, capability);
    var results: [10]u32 = undefined;
    const count = coordinator.find_agents_by_capability("shared_capability", &results);
    try std.testing.expect(count == 2);
}

test "send RPC request" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    const agent_id1 = coordinator.register_agent("agent1", 1000);
    const agent_id2 = coordinator.register_agent("agent2", 1000);
    try std.testing.expect(agent_id1 != null);
    try std.testing.expect(agent_id2 != null);
    const request_id = coordinator.send_rpc_request(
        agent_id1.?,
        agent_id2.?,
        "test_method",
        "",
        2000,
    );
    try std.testing.expect(request_id != null);
    try std.testing.expect(coordinator.get_rpc_request_count() == 1);
}

test "get RPC request by ID" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    const agent_id1 = coordinator.register_agent("agent1", 1000);
    const agent_id2 = coordinator.register_agent("agent2", 1000);
    try std.testing.expect(agent_id1 != null);
    try std.testing.expect(agent_id2 != null);
    const request_id = coordinator.send_rpc_request(
        agent_id1.?,
        agent_id2.?,
        "test_method",
        "test_payload",
        2000,
    );
    try std.testing.expect(request_id != null);
    const req = coordinator.get_rpc_request(request_id.?);
    try std.testing.expect(req != null);
    try std.testing.expect(req.?.request_id == request_id.?);
    try std.testing.expect(req.?.from_agent_id == agent_id1.?);
    try std.testing.expect(req.?.to_agent_id == agent_id2.?);
}

test "bounded agent registry" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var i: u32 = 0;
    while (i < agent_coordinator.MAX_AGENTS + 10) : (i += 1) {
        var name_buf: [32]u8 = undefined;
        _ = std.fmt.bufPrint(&name_buf, "agent_{}", .{i}) catch "";
        _ = coordinator.register_agent(&name_buf, 1000 + i);
    }
    try std.testing.expect(coordinator.get_agent_count() == agent_coordinator.MAX_AGENTS);
}

test "bounded RPC queue" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    const agent_id1 = coordinator.register_agent("agent1", 1000);
    const agent_id2 = coordinator.register_agent("agent2", 1000);
    try std.testing.expect(agent_id1 != null);
    try std.testing.expect(agent_id2 != null);
    var i: u32 = 0;
    while (i < agent_coordinator.MAX_RPC_REQUESTS + 10) : (i += 1) {
        _ = coordinator.send_rpc_request(
            agent_id1.?,
            agent_id2.?,
            "test_method",
            "",
            2000 + i,
        );
    }
    try std.testing.expect(
        coordinator.get_rpc_request_count() == agent_coordinator.MAX_RPC_REQUESTS,
    );
}

test "agent capability name setting" {
    var capability = agent_coordinator.AgentCapability.init();
    const result = capability.set_name("test_capability");
    try std.testing.expect(result == true);
    try std.testing.expect(capability.name_len > 0);
}
