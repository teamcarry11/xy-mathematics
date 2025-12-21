//! Grain Flow Failure Pattern Metrics: Metric collection for failure analysis.
//!
//! Why: Provides metric collection for failure patterns, enabling observability,
//! testing, and measurement of failure recovery and workflow complexity impact.
//!
//! Architecture: Event-based metric collection, bounded storage, JSON export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-204954-pst: Phase 2 Instrumentation - Phase 3 Failure Pattern Metrics

const std = @import("std");

// Bounded: Max failures tracked.
pub const MAX_FAILURES: u32 = 10000;
// Bounded: Max failure types.
pub const MAX_FAILURE_TYPES: u32 = 16;
// Bounded: Max complexity levels.
pub const MAX_COMPLEXITY_LEVELS: u32 = 100;

// Failure type classification.
pub const FailureType = enum(u8) {
    transient = 0,
    permanent = 1,
    timeout = 2,
    invalid_input = 3,
    agent_unavailable = 4,
    workflow_cycle = 5,
    resource_exhausted = 6,
    unknown = 7,
};

// Failure record.
pub const FailureRecord = struct {
    workflow_id: u32,
    node_id: u32,
    agent_id: u32,
    failure_type: FailureType,
    failed_at: u64,
    recovered: bool,
    recovered_at: u64,
    recovery_attempts: u32,
    workflow_complexity: WorkflowComplexity,

    pub fn init(
        workflow_id: u32,
        node_id: u32,
        agent_id: u32,
        failure_type: FailureType,
        failed_at: u64,
        complexity: WorkflowComplexity,
    ) FailureRecord {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(failed_at > 0);
        return FailureRecord{
            .workflow_id = workflow_id,
            .node_id = node_id,
            .agent_id = agent_id,
            .failure_type = failure_type,
            .failed_at = failed_at,
            .recovered = false,
            .recovered_at = 0,
            .recovery_attempts = 0,
            .workflow_complexity = complexity,
        };
    }

    pub fn mark_recovered(self: *FailureRecord, recovered_at: u64) void {
        std.debug.assert(recovered_at >= self.failed_at);
        self.recovered = true;
        self.recovered_at = recovered_at;
    }

    pub fn increment_recovery_attempts(self: *FailureRecord) void {
        self.recovery_attempts += 1;
    }
};

// Workflow complexity metrics.
pub const WorkflowComplexity = struct {
    node_count: u32,
    edge_count: u32,
    agent_count: u32,

    pub fn init(node_count: u32, edge_count: u32, agent_count: u32) WorkflowComplexity {
        std.debug.assert(node_count > 0);
        return WorkflowComplexity{
            .node_count = node_count,
            .edge_count = edge_count,
            .agent_count = agent_count,
        };
    }

    pub fn get_complexity_level(self: *const WorkflowComplexity) u32 {
        std.debug.assert(self.node_count > 0);
        // Simple complexity: nodes + edges + agents / 10
        const level = (self.node_count + self.edge_count + self.agent_count) / 10;
        return @min(level, MAX_COMPLEXITY_LEVELS - 1);
    }
};

// Failure pattern metrics collector.
pub const FailurePatternMetricsCollector = struct {
    failures: [MAX_FAILURES]FailureRecord,
    failures_len: u32,
    total_failures: u64,
    recovered_failures: u64,
    failure_type_counts: [MAX_FAILURE_TYPES]u64,
    complexity_failure_counts: [MAX_COMPLEXITY_LEVELS]u64,
    complexity_total_counts: [MAX_COMPLEXITY_LEVELS]u64,

    pub fn init() FailurePatternMetricsCollector {
        var collector = FailurePatternMetricsCollector{
            .failures = undefined,
            .failures_len = 0,
            .total_failures = 0,
            .recovered_failures = 0,
            .failure_type_counts = undefined,
            .complexity_failure_counts = undefined,
            .complexity_total_counts = undefined,
        };
        var i: u32 = 0;
        while (i < MAX_FAILURES) : (i += 1) {
            collector.failures[i] = FailureRecord.init(0, 0, 0, .unknown, 0, WorkflowComplexity.init(1, 0, 1));
        }
        i = 0;
        while (i < MAX_FAILURE_TYPES) : (i += 1) {
            collector.failure_type_counts[i] = 0;
        }
        i = 0;
        while (i < MAX_COMPLEXITY_LEVELS) : (i += 1) {
            collector.complexity_failure_counts[i] = 0;
            collector.complexity_total_counts[i] = 0;
        }
        return collector;
    }

    // Record failure.
    pub fn record_failure(
        self: *FailurePatternMetricsCollector,
        workflow_id: u32,
        node_id: u32,
        agent_id: u32,
        failure_type: FailureType,
        failed_at: u64,
        complexity: WorkflowComplexity,
    ) bool {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(failed_at > 0);
        if (self.failures_len >= MAX_FAILURES) {
            return false;
        }
        self.failures[self.failures_len] = FailureRecord.init(
            workflow_id,
            node_id,
            agent_id,
            failure_type,
            failed_at,
            complexity,
        );
        self.failures_len += 1;
        self.total_failures += 1;
        const type_idx = @intFromEnum(failure_type);
        if (type_idx < MAX_FAILURE_TYPES) {
            self.failure_type_counts[type_idx] += 1;
        }
        const complexity_level = complexity.get_complexity_level();
        if (complexity_level < MAX_COMPLEXITY_LEVELS) {
            self.complexity_failure_counts[complexity_level] += 1;
        }
        return true;
    }

    // Record failure recovery.
    pub fn record_failure_recovery(
        self: *FailurePatternMetricsCollector,
        workflow_id: u32,
        recovered_at: u64,
    ) bool {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(recovered_at > 0);
        var i: u32 = 0;
        while (i < self.failures_len) : (i += 1) {
            if (self.failures[i].workflow_id == workflow_id and !self.failures[i].recovered) {
                self.failures[i].mark_recovered(recovered_at);
                self.recovered_failures += 1;
                return true;
            }
        }
        return false;
    }

    // Get failure count by type.
    pub fn get_failure_count_by_type(
        self: *const FailurePatternMetricsCollector,
        failure_type: FailureType,
    ) u64 {
        std.debug.assert(@intFromEnum(failure_type) < MAX_FAILURE_TYPES);
        const type_idx = @intFromEnum(failure_type);
        return if (type_idx < MAX_FAILURE_TYPES) self.failure_type_counts[type_idx] else 0;
    }

    // Get failure recovery success rate (percentage, 0-100).
    pub fn get_recovery_success_rate_percent(
        self: *const FailurePatternMetricsCollector,
    ) u32 {
        std.debug.assert(self.total_failures > 0);
        if (self.total_failures == 0) {
            return 0;
        }
        const rate = (self.recovered_failures * 100) / self.total_failures;
        return @intCast(rate);
    }

    // Get failure rate by complexity level (percentage, 0-100).
    pub fn get_failure_rate_by_complexity_percent(
        self: *const FailurePatternMetricsCollector,
        complexity_level: u32,
    ) u32 {
        std.debug.assert(complexity_level < MAX_COMPLEXITY_LEVELS);
        if (complexity_level >= MAX_COMPLEXITY_LEVELS) {
            return 0;
        }
        if (self.complexity_total_counts[complexity_level] == 0) {
            return 0;
        }
        const rate = (self.complexity_failure_counts[complexity_level] * 100) /
            self.complexity_total_counts[complexity_level];
        return @intCast(rate);
    }

    // Record workflow execution (for complexity tracking).
    pub fn record_workflow_execution(
        self: *FailurePatternMetricsCollector,
        complexity: WorkflowComplexity,
    ) void {
        std.debug.assert(complexity.node_count > 0);
        const complexity_level = complexity.get_complexity_level();
        if (complexity_level < MAX_COMPLEXITY_LEVELS) {
            self.complexity_total_counts[complexity_level] += 1;
        }
    }

    // Export metrics to JSON format.
    pub fn export_json(self: *const FailurePatternMetricsCollector, output: []u8) u32 {
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;
        // Write JSON header.
        const header = "{\"total_failures\":";
        if (offset + header.len < output.len) {
            @memcpy(output[offset..offset + header.len], header);
            offset += @intCast(header.len);
        }
        const total_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{self.total_failures},
        ) catch return offset;
        offset += @intCast(total_str.len);
        // Write recovery success rate.
        const recovery_label = ",\"recovery_success_rate_percent\":";
        if (offset + recovery_label.len < output.len) {
            @memcpy(output[offset..offset + recovery_label.len], recovery_label);
            offset += @intCast(recovery_label.len);
        }
        const recovery_rate = self.get_recovery_success_rate_percent();
        const recovery_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{recovery_rate},
        ) catch return offset;
        offset += @intCast(recovery_str.len);
        // Write failure type distribution.
        const types_label = ",\"failure_type_distribution\":{";
        if (offset + types_label.len < output.len) {
            @memcpy(output[offset..offset + types_label.len], types_label);
            offset += @intCast(types_label.len);
        }
        var first_type: bool = true;
        var i: u32 = 0;
        while (i < MAX_FAILURE_TYPES) : (i += 1) {
            if (self.failure_type_counts[i] > 0) {
                if (!first_type) {
                    if (offset < output.len) {
                        output[offset] = ',';
                        offset += 1;
                    }
                }
                const type_name = switch (i) {
                    0 => "transient",
                    1 => "permanent",
                    2 => "timeout",
                    3 => "invalid_input",
                    4 => "agent_unavailable",
                    5 => "workflow_cycle",
                    6 => "resource_exhausted",
                    7 => "unknown",
                    else => "unknown",
                };
                const type_entry = std.fmt.bufPrint(
                    output[offset..],
                    "\"{s}\":{}",
                    .{ type_name, self.failure_type_counts[i] },
                ) catch return offset;
                offset += @intCast(type_entry.len);
                first_type = false;
            }
        }
        const types_end = "}";
        if (offset + types_end.len < output.len) {
            @memcpy(output[offset..offset + types_end.len], types_end);
            offset += @intCast(types_end.len);
        }
        // Write JSON footer.
        const footer = "}";
        if (offset + footer.len < output.len) {
            @memcpy(output[offset..offset + footer.len], footer);
            offset += @intCast(footer.len);
        }
        return offset;
    }
};
