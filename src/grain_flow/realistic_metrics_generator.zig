//! Grain Flow Realistic Metrics Generator: Generate realistic workflow metrics for Step 3 validation.
//!
//! Why: Provides realistic workflow execution scenario to generate real workflow metrics
//! for Research Agent's Step 3 validation (end-to-end integration with real data).
//!
//! Architecture: Workflow execution simulation, metrics collection, JSON export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-105000-pst: Phase 3 Step 3 Validation - Realistic Metrics Generation

const std = @import("std");
const workflow_engine = @import("workflow_engine.zig");
const event_bus = @import("event_bus.zig");
const agent_coordinator = @import("agent_coordinator.zig");
const workflow_metrics = @import("workflow_metrics.zig");
const agent_coordination_metrics = @import("agent_coordination_metrics.zig");
const failure_pattern_metrics = @import("failure_pattern_metrics.zig");
const performance_metrics = @import("performance_metrics.zig");
const workflow_observatory = @import("workflow_observatory.zig");

// Bounded: Max workflows to execute in scenario.
pub const MAX_SCENARIO_WORKFLOWS: u32 = 50;

// Realistic metrics generator: generates realistic workflow execution data.
pub const RealisticMetricsGenerator = struct {
    event_bus: event_bus.EventBus,
    coordinator: agent_coordinator.AgentCoordinator,
    engine: workflow_engine.WorkflowEngine,
    workflow_collector: workflow_metrics.WorkflowMetricsCollector,
    coordination_collector: agent_coordination_metrics.AgentCoordinationMetricsCollector,
    failure_collector: failure_pattern_metrics.FailurePatternMetricsCollector,
    performance_collector: performance_metrics.PerformanceMetricsCollector,
    observatory: workflow_observatory.WorkflowObservatory,

    pub fn init() RealisticMetricsGenerator {
        var bus = event_bus.EventBus.init();
        var coord = agent_coordinator.AgentCoordinator.init(&bus);
        var eng = workflow_engine.WorkflowEngine.init(&bus, &coord);
        var wf_collector = workflow_metrics.WorkflowMetricsCollector.init();
        var coord_collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
        var fail_collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
        var perf_collector = performance_metrics.PerformanceMetricsCollector.init();
        var obs = workflow_observatory.WorkflowObservatory.init();

        // Set collectors on engine.
        eng.set_metrics_collector(&wf_collector);
        eng.set_failure_pattern_collector(&fail_collector);
        eng.set_performance_collector(&perf_collector);

        // Set collectors on observatory.
        obs.set_workflow_collector(&wf_collector);
        obs.set_coordination_collector(&coord_collector);
        obs.set_failure_collector(&fail_collector);
        obs.set_performance_collector(&perf_collector);

        return RealisticMetricsGenerator{
            .event_bus = bus,
            .coordinator = coord,
            .engine = eng,
            .workflow_collector = wf_collector,
            .coordination_collector = coord_collector,
            .failure_collector = fail_collector,
            .performance_collector = perf_collector,
            .observatory = obs,
        };
    }

    /// Generate realistic workflow execution scenario.
    pub fn generate_realistic_scenario(
        self: *RealisticMetricsGenerator,
        execution_count: u32,
    ) u32 {
        std.debug.assert(execution_count > 0);
        std.debug.assert(execution_count <= MAX_SCENARIO_WORKFLOWS);
        var executed: u32 = 0;
        var base_timestamp: u64 = 1000000;
        var i: u32 = 0;

        // Register test agents for coordination.
        const silo_agent_id_opt = self.coordinator.register_agent("silo", base_timestamp);
        const carry_agent_id_opt = self.coordinator.register_agent("carry", base_timestamp);
        const workspace_agent_id_opt = self.coordinator.register_agent("workspace", base_timestamp);
        if (silo_agent_id_opt == null or carry_agent_id_opt == null or workspace_agent_id_opt == null) {
            return executed;
        }
        const silo_agent_id = silo_agent_id_opt.?;
        const carry_agent_id = carry_agent_id_opt.?;
        _ = workspace_agent_id_opt.?;

        while (i < execution_count) : (i += 1) {
            const workflow_id = self.engine.create_workflow(
                "realistic_workflow",
                base_timestamp + i * 1000,
            );
            if (workflow_id) |wf_id| {
                // Add nodes to workflow.
                const node1 = workflow_engine.WorkflowNode.init(1, "task1", silo_agent_id);
                const node2 = workflow_engine.WorkflowNode.init(2, "task2", carry_agent_id);
                const workflow = self.engine.find_workflow(wf_id);
                if (workflow) |wf| {
                    _ = wf.add_node(node1);
                    _ = wf.add_node(node2);
                    const edge = workflow_engine.WorkflowEdge.init(1, 2, .dependency);
                    _ = wf.add_edge(edge);

                    // Execute workflow.
                    const start_time = base_timestamp + i * 1000;
                    const exec_time: u64 = 800 + (i % 10) * 100; // 800-1700ms
                    const end_time = start_time + exec_time;
                    const success = (i % 10) != 3; // 90% success rate

                    // Record coordination (simulate agent-to-agent RPC).
                    const request_id: u32 = @as(u32, @intCast(i + 1));
                    _ = self.coordination_collector.record_coordination_start(
                        silo_agent_id,
                        carry_agent_id,
                        wf_id,
                        request_id,
                        start_time,
                    );
                    const coord_latency: u64 = 30 + (i % 5) * 10; // 30-70ms
                    const coord_end = start_time + coord_latency;
                    const coord_status: agent_coordination_metrics.AgentCoordinationStatus = if (i % 12 != 0) .success else .failure;
                    _ = self.coordination_collector.record_coordination_completion(
                        silo_agent_id,
                        carry_agent_id,
                        wf_id,
                        request_id,
                        start_time,
                        coord_end,
                        coord_status,
                    );

                    // Execute workflow (engine processes all ready nodes automatically).
                    _ = self.engine.execute_workflow(wf_id, start_time);
                    
                    // For failures, manually record since engine auto-completes simple workflows.
                    if (!success) {
                        const fail_time = start_time + exec_time / 2;
                        // Manually record failure execution.
                        _ = self.workflow_collector.record_execution(
                            wf_id,
                            "realistic_workflow",
                            start_time,
                            fail_time,
                            workflow_metrics.WorkflowExecutionStatus.failure,
                        );
                        // Record failure pattern.
                        const complexity = failure_pattern_metrics.WorkflowComplexity.init(2, 1, 0);
                        _ = self.failure_collector.record_failure(
                            wf_id,
                            0,
                            0,
                            failure_pattern_metrics.FailureType.transient,
                            fail_time,
                            complexity,
                        );
                    }

                    // Record performance metrics.
                    _ = self.performance_collector.record_queue_depth(start_time, @as(u32, @intCast(i % 10)));
                    const created_at = base_timestamp + i * 1000;
                    _ = self.performance_collector.record_wait_time(wf_id, created_at, start_time);
                    const cpu_percent: u32 = 20 + (i % 10);
                    const memory_bytes: u64 = 512 * 1024 + (i % 100) * 1024;
                    const network_bytes: u64 = 1024 * (i % 50);
                    _ = self.performance_collector.record_resource_usage(wf_id, start_time, cpu_percent, memory_bytes, network_bytes);

                    executed += 1;
                }
            }
        }
        return executed;
    }

    /// Export realistic metrics to JSON.
    pub fn export_realistic_metrics_json(
        self: *const RealisticMetricsGenerator,
        output: []u8,
    ) u32 {
        return self.observatory.export_all_metrics_json(output);
    }
};
