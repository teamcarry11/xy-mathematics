//! Grain Research Workflow Metrics Analyzer: Analyze workflow metrics from Flow Agent.
//!
//! Why: Provides metrics analysis capabilities for Workflow Observatory Phase 3
//! collaboration. Analyzes JSON metrics exported by Flow Agent to generate insights.
//! Architecture: JSON parsing, bounded analysis buffers, iterative algorithms.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-21-094200-pst: Grain Research Agent Phase 3 (Flow Agent Collaboration)

const std = @import("std");

// Bounded: Max JSON input length.
pub const MAX_JSON_INPUT_LEN: u32 = 10_000_000; // 10 MB

// Bounded: Max metric entries to analyze.
pub const MAX_METRIC_ENTRIES: u32 = 100_000;

// Bounded: Max workflow executions to track.
pub const MAX_WORKFLOW_EXECUTIONS: u32 = 10_000;

// Bounded: Max agent pairs to track.
pub const MAX_AGENT_PAIRS: u32 = 1_000;

// Workflow execution metric.
pub const WorkflowExecutionMetric = struct {
    workflow_id: u32,
    execution_time_ms: u64,
    status: WorkflowStatus,
    timestamp: u64,
};

// Workflow status.
pub const WorkflowStatus = enum(u8) {
    success = 0,
    failure = 1,
    timeout = 2,
};

// Agent coordination metric.
pub const AgentCoordinationMetric = struct {
    source_agent_id: u32,
    target_agent_id: u32,
    coordination_latency_ms: u64,
    status: CoordinationStatus,
    timestamp: u64,
};

// Coordination status.
pub const CoordinationStatus = enum(u8) {
    success = 0,
    failure = 1,
    timeout = 2,
};

// Failure pattern metric.
pub const FailurePatternMetric = struct {
    failure_type: FailureType,
    workflow_id: u32,
    recovered: bool,
    timestamp: u64,
};

// Failure type.
pub const FailureType = enum(u8) {
    transient = 0,
    permanent = 1,
    timeout = 2,
    unknown = 3,
};

// Performance metric.
pub const PerformanceMetric = struct {
    queue_depth: u32,
    wait_time_ms: u64,
    cpu_percent: u32,
    memory_bytes: u64,
    timestamp: u64,
};

// Workflow metrics analyzer.
pub const WorkflowMetricsAnalyzer = struct {
    allocator: std.mem.Allocator,
    workflow_executions: std.ArrayListUnmanaged(WorkflowExecutionMetric),
    coordination_metrics: std.ArrayListUnmanaged(AgentCoordinationMetric),
    failure_metrics: std.ArrayListUnmanaged(FailurePatternMetric),
    performance_metrics: std.ArrayListUnmanaged(PerformanceMetric),
    coordination_success_rate_percent: u32,

    // Initialize workflow metrics analyzer.
    pub fn init(allocator: std.mem.Allocator) WorkflowMetricsAnalyzer {
        std.debug.assert(allocator.ptr != null);

        return WorkflowMetricsAnalyzer{
            .allocator = allocator,
            .workflow_executions = .{},
            .coordination_metrics = .{},
            .failure_metrics = .{},
            .performance_metrics = .{},
            .coordination_success_rate_percent = 0,
        };
    }

    // Deinitialize and free memory.
    pub fn deinit(self: *WorkflowMetricsAnalyzer) void {
        self.workflow_executions.deinit(self.allocator);
        self.coordination_metrics.deinit(self.allocator);
        self.failure_metrics.deinit(self.allocator);
        self.performance_metrics.deinit(self.allocator);
        self.* = undefined;
    }

    // Parse JSON metrics from Flow Agent.
    pub fn parse_json_metrics(
        self: *WorkflowMetricsAnalyzer,
        json_data: []const u8,
    ) !void {
        std.debug.assert(json_data.len > 0);
        std.debug.assert(json_data.len <= MAX_JSON_INPUT_LEN);

        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            json_data,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) {
            return error.InvalidJson;
        }

        const obj = root.object;

        // Parse workflow metrics.
        if (obj.get("workflow")) |workflow_val| {
            try self.parse_workflow_metrics(workflow_val);
        }

        // Parse coordination metrics.
        if (obj.get("coordination")) |coord_val| {
            try self.parse_coordination_metrics(coord_val);
        }

        // Parse failure metrics.
        if (obj.get("failure")) |failure_val| {
            try self.parse_failure_metrics(failure_val);
        }

        // Parse performance metrics.
        if (obj.get("performance")) |perf_val| {
            try self.parse_performance_metrics(perf_val);
        }
    }

    // Parse workflow metrics from JSON value.
    fn parse_workflow_metrics(
        self: *WorkflowMetricsAnalyzer,
        workflow_val: std.json.Value,
    ) !void {
        std.debug.assert(workflow_val == .object);

        const workflow_obj = workflow_val.object;

        // Parse executions array.
        if (workflow_obj.get("executions")) |executions_val| {
            if (executions_val == .array) {
                const executions = executions_val.array;
                var i: u32 = 0;
                while (i < executions.items.len and
                    i < MAX_WORKFLOW_EXECUTIONS) : (i += 1)
                {
                    const exec_val = executions.items[i];
                    if (exec_val == .object) {
                        const exec_obj = exec_val.object;
                        var metric = WorkflowExecutionMetric{
                            .workflow_id = 0,
                            .execution_time_ms = 0,
                            .status = .success,
                            .timestamp = 0,
                        };

                        if (exec_obj.get("workflow_id")) |id_val| {
                            if (id_val == .integer) {
                                metric.workflow_id = @intCast(id_val.integer);
                            }
                        }

                        if (exec_obj.get("execution_time_ms")) |time_val| {
                            if (time_val == .integer) {
                                metric.execution_time_ms = @intCast(time_val.integer);
                            }
                        }

                        if (exec_obj.get("status")) |status_val| {
                            if (status_val == .integer) {
                                const status_int = @intCast(status_val.integer);
                                metric.status = @enumFromInt(status_int);
                            }
                        }

                        if (exec_obj.get("timestamp")) |ts_val| {
                            if (ts_val == .integer) {
                                metric.timestamp = @intCast(ts_val.integer);
                            }
                        }

                        try self.workflow_executions.append(
                            self.allocator,
                            metric,
                        );
                    }
                }
            }
        }
    }

    // Parse coordination metrics from JSON value.
    fn parse_coordination_metrics(
        self: *WorkflowMetricsAnalyzer,
        coord_val: std.json.Value,
    ) !void {
        std.debug.assert(coord_val == .object);

        const coord_obj = coord_val.object;

        // Parse top-level success rate.
        if (coord_obj.get("success_rate_percent")) |success_rate_val| {
            if (success_rate_val == .integer) {
                self.coordination_success_rate_percent = @intCast(success_rate_val.integer);
            }
        }

        // Parse coordination patterns array.
        if (coord_obj.get("coordination_patterns")) |patterns_val| {
            if (patterns_val == .array) {
                const patterns = patterns_val.array;
                var i: u32 = 0;
                while (i < patterns.items.len and
                    i < MAX_AGENT_PAIRS) : (i += 1)
                {
                    const pattern_val = patterns.items[i];
                    if (pattern_val == .object) {
                        const pattern_obj = pattern_val.object;
                        var metric = AgentCoordinationMetric{
                            .source_agent_id = 0,
                            .target_agent_id = 0,
                            .coordination_latency_ms = 0,
                            .status = .success,
                            .timestamp = 0,
                        };

                        if (pattern_obj.get("source_agent_id")) |source_val| {
                            if (source_val == .integer) {
                                metric.source_agent_id = @intCast(source_val.integer);
                            }
                        }

                        if (pattern_obj.get("target_agent_id")) |target_val| {
                            if (target_val == .integer) {
                                metric.target_agent_id = @intCast(target_val.integer);
                            }
                        }

                        // Patterns don't include latency_ms (it's at top level).
                        // Use average latency if available, otherwise 0.
                        if (coord_obj.get("avg_coordination_latency_ms")) |avg_lat_val| {
                            if (avg_lat_val == .integer) {
                                metric.coordination_latency_ms = @intCast(avg_lat_val.integer);
                            }
                        }

                        try self.coordination_metrics.append(
                            self.allocator,
                            metric,
                        );
                    }
                }
            }
        }
    }

    // Parse failure metrics from JSON value.
    fn parse_failure_metrics(
        self: *WorkflowMetricsAnalyzer,
        failure_val: std.json.Value,
    ) !void {
        std.debug.assert(failure_val == .object);

        const failure_obj = failure_val.object;

        // Parse failure type distribution.
        if (failure_obj.get("failure_type_distribution")) |types_val| {
            if (types_val == .object) {
                const types_obj = types_val.object;
                var iter = types_obj.iterator();
                var count: u32 = 0;
                while (iter.next()) |entry| : (count += 1) {
                    if (count >= MAX_METRIC_ENTRIES) break;

                    const type_name = entry.key_ptr.*;
                    const type_count = entry.value_ptr.*;

                    if (type_count == .integer) {
                        const count_val = @intCast(type_count.integer);
                        const failure_type = parse_failure_type(type_name);

                        var i: u32 = 0;
                        while (i < count_val and
                            i < MAX_METRIC_ENTRIES) : (i += 1)
                        {
                            var metric = FailurePatternMetric{
                                .failure_type = failure_type,
                                .workflow_id = 0,
                                .recovered = false,
                                .timestamp = 0,
                            };

                            try self.failure_metrics.append(
                                self.allocator,
                                metric,
                            );
                        }
                    }
                }
            }
        }
    }

    // Parse performance metrics from JSON value.
    fn parse_performance_metrics(
        self: *WorkflowMetricsAnalyzer,
        perf_val: std.json.Value,
    ) !void {
        std.debug.assert(perf_val == .object);

        const perf_obj = perf_val.object;

        var metric = PerformanceMetric{
            .queue_depth = 0,
            .wait_time_ms = 0,
            .cpu_percent = 0,
            .memory_bytes = 0,
            .timestamp = 0,
        };

        if (perf_obj.get("avg_queue_depth")) |queue_val| {
            if (queue_val == .integer) {
                metric.queue_depth = @intCast(queue_val.integer);
            }
        }

        if (perf_obj.get("avg_wait_time_ms")) |wait_val| {
            if (wait_val == .integer) {
                metric.wait_time_ms = @intCast(wait_val.integer);
            }
        }

        if (perf_obj.get("avg_cpu_percent")) |cpu_val| {
            if (cpu_val == .integer) {
                metric.cpu_percent = @intCast(cpu_val.integer);
            }
        }

        try self.performance_metrics.append(self.allocator, metric);
    }

    // Parse failure type from string.
    fn parse_failure_type(type_name: []const u8) FailureType {
        std.debug.assert(type_name.len > 0);

        if (std.mem.eql(u8, type_name, "transient")) {
            return .transient;
        } else if (std.mem.eql(u8, type_name, "permanent")) {
            return .permanent;
        } else if (std.mem.eql(u8, type_name, "timeout")) {
            return .timeout;
        } else {
            return .unknown;
        }
    }

    // Calculate average execution time.
    pub fn get_average_execution_time_ms(
        self: *const WorkflowMetricsAnalyzer,
    ) u64 {
        std.debug.assert(self.workflow_executions.items.len <= MAX_WORKFLOW_EXECUTIONS);

        if (self.workflow_executions.items.len == 0) {
            return 0;
        }

        var total: u64 = 0;
        var i: u32 = 0;
        while (i < self.workflow_executions.items.len) : (i += 1) {
            total += self.workflow_executions.items[i].execution_time_ms;
        }

        return total / @as(u64, self.workflow_executions.items.len);
    }

    // Calculate success rate percentage.
    pub fn get_success_rate_percent(
        self: *const WorkflowMetricsAnalyzer,
    ) u32 {
        std.debug.assert(self.workflow_executions.items.len <= MAX_WORKFLOW_EXECUTIONS);

        if (self.workflow_executions.items.len == 0) {
            return 0;
        }

        var success_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.workflow_executions.items.len) : (i += 1) {
            if (self.workflow_executions.items[i].status == .success) {
                success_count += 1;
            }
        }

        const success_rate = (success_count * 100) / self.workflow_executions.items.len;
        std.debug.assert(success_rate <= 100);

        return success_rate;
    }

    // Calculate average coordination latency.
    pub fn get_average_coordination_latency_ms(
        self: *const WorkflowMetricsAnalyzer,
    ) u64 {
        std.debug.assert(self.coordination_metrics.items.len <= MAX_AGENT_PAIRS);

        if (self.coordination_metrics.items.len == 0) {
            return 0;
        }

        var total: u64 = 0;
        var i: u32 = 0;
        while (i < self.coordination_metrics.items.len) : (i += 1) {
            total += self.coordination_metrics.items[i].coordination_latency_ms;
        }

        return total / @as(u64, self.coordination_metrics.items.len);
    }

    // Calculate coordination success rate percentage.
    pub fn get_coordination_success_rate_percent(
        self: *const WorkflowMetricsAnalyzer,
    ) u32 {
        std.debug.assert(self.coordination_success_rate_percent <= 100);

        // Use top-level success rate from JSON (more accurate than counting patterns).
        return self.coordination_success_rate_percent;
    }

    // Calculate failure recovery success rate percentage.
    pub fn get_failure_recovery_success_rate_percent(
        self: *const WorkflowMetricsAnalyzer,
    ) u32 {
        std.debug.assert(self.failure_metrics.items.len <= MAX_METRIC_ENTRIES);

        if (self.failure_metrics.items.len == 0) {
            return 0;
        }

        var recovered_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.failure_metrics.items.len) : (i += 1) {
            if (self.failure_metrics.items[i].recovered) {
                recovered_count += 1;
            }
        }

        const recovery_rate = (recovered_count * 100) / self.failure_metrics.items.len;
        std.debug.assert(recovery_rate <= 100);

        return recovery_rate;
    }

    // Get workflow execution count.
    pub fn get_workflow_execution_count(
        self: *const WorkflowMetricsAnalyzer,
    ) u32 {
        std.debug.assert(self.workflow_executions.items.len <= MAX_WORKFLOW_EXECUTIONS);

        return @intCast(self.workflow_executions.items.len);
    }

    // Get coordination metric count.
    pub fn get_coordination_metric_count(
        self: *const WorkflowMetricsAnalyzer,
    ) u32 {
        std.debug.assert(self.coordination_metrics.items.len <= MAX_AGENT_PAIRS);

        return @intCast(self.coordination_metrics.items.len);
    }

    // Get failure metric count.
    pub fn get_failure_metric_count(
        self: *const WorkflowMetricsAnalyzer,
    ) u32 {
        std.debug.assert(self.failure_metrics.items.len <= MAX_METRIC_ENTRIES);

        return @intCast(self.failure_metrics.items.len);
    }

    // Get performance metric count.
    pub fn get_performance_metric_count(
        self: *const WorkflowMetricsAnalyzer,
    ) u32 {
        std.debug.assert(self.performance_metrics.items.len <= MAX_METRIC_ENTRIES);

        return @intCast(self.performance_metrics.items.len);
    }

    // Failure pattern analysis result.
    pub const FailurePatternAnalysis = struct {
        transient_failure_rate_percent: u32,
        permanent_failure_rate_percent: u32,
        timeout_failure_rate_percent: u32,
        unknown_failure_rate_percent: u32,
        total_failures: u32,
    };

    // Analyze failure patterns and calculate failure rates by type.
    pub fn analyze_failure_patterns(
        self: *const WorkflowMetricsAnalyzer,
    ) FailurePatternAnalysis {
        std.debug.assert(self.failure_metrics.items.len <= MAX_METRIC_ENTRIES);

        var result = FailurePatternAnalysis{
            .transient_failure_rate_percent = 0,
            .permanent_failure_rate_percent = 0,
            .timeout_failure_rate_percent = 0,
            .unknown_failure_rate_percent = 0,
            .total_failures = @intCast(self.failure_metrics.items.len),
        };

        if (result.total_failures == 0) {
            return result;
        }

        var transient_count: u32 = 0;
        var permanent_count: u32 = 0;
        var timeout_count: u32 = 0;
        var unknown_count: u32 = 0;

        var i: u32 = 0;
        while (i < self.failure_metrics.items.len) : (i += 1) {
            const metric = self.failure_metrics.items[i];
            switch (metric.failure_type) {
                .transient => transient_count += 1,
                .permanent => permanent_count += 1,
                .timeout => timeout_count += 1,
                .unknown => unknown_count += 1,
            }
        }

        result.transient_failure_rate_percent =
            (transient_count * 100) / result.total_failures;
        result.permanent_failure_rate_percent =
            (permanent_count * 100) / result.total_failures;
        result.timeout_failure_rate_percent =
            (timeout_count * 100) / result.total_failures;
        result.unknown_failure_rate_percent =
            (unknown_count * 100) / result.total_failures;

        std.debug.assert(result.transient_failure_rate_percent <= 100);
        std.debug.assert(result.permanent_failure_rate_percent <= 100);
        std.debug.assert(result.timeout_failure_rate_percent <= 100);
        std.debug.assert(result.unknown_failure_rate_percent <= 100);

        return result;
    }

    // Get failure count by type.
    pub fn get_failure_count_by_type(
        self: *const WorkflowMetricsAnalyzer,
        failure_type: FailureType,
    ) u32 {
        std.debug.assert(self.failure_metrics.items.len <= MAX_METRIC_ENTRIES);

        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.failure_metrics.items.len) : (i += 1) {
            if (self.failure_metrics.items[i].failure_type == failure_type) {
                count += 1;
            }
        }

        return count;
    }

    // Get recovered failure count.
    pub fn get_recovered_failure_count(
        self: *const WorkflowMetricsAnalyzer,
    ) u32 {
        std.debug.assert(self.failure_metrics.items.len <= MAX_METRIC_ENTRIES);

        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.failure_metrics.items.len) : (i += 1) {
            if (self.failure_metrics.items[i].recovered) {
                count += 1;
            }
        }

        return count;
    }

    // Get unrecovered failure count.
    pub fn get_unrecovered_failure_count(
        self: *const WorkflowMetricsAnalyzer,
    ) u32 {
        std.debug.assert(self.failure_metrics.items.len <= MAX_METRIC_ENTRIES);

        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.failure_metrics.items.len) : (i += 1) {
            if (!self.failure_metrics.items[i].recovered) {
                count += 1;
            }
        }

        return count;
    }

    // Get failure count by workflow ID.
    pub fn get_failure_count_by_workflow(
        self: *const WorkflowMetricsAnalyzer,
        workflow_id: u32,
    ) u32 {
        std.debug.assert(self.failure_metrics.items.len <= MAX_METRIC_ENTRIES);

        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.failure_metrics.items.len) : (i += 1) {
            if (self.failure_metrics.items[i].workflow_id == workflow_id) {
                count += 1;
            }
        }

        return count;
    }
};
