//! Grain Flow Workflow Observatory: Metrics aggregation and dashboard API.
//!
//! Why: Provides aggregated metrics view for Workflow Observatory dashboard.
//! Collects metrics from all collectors (workflow, coordination, failure, performance)
//! and provides API endpoints for dashboard visualization.
//!
//! Architecture: Metrics aggregation, JSON export, API endpoints.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-083202-pst: Phase 3 Workflow Observatory Foundation

const std = @import("std");
const workflow_metrics = @import("workflow_metrics.zig");
const agent_coordination_metrics = @import("agent_coordination_metrics.zig");
const failure_pattern_metrics = @import("failure_pattern_metrics.zig");
const performance_metrics = @import("performance_metrics.zig");

// Bounded: Max aggregated metrics JSON size (10MB).
pub const MAX_AGGREGATED_JSON_SIZE: u32 = 10_485_760;

// Bounded: Max dashboard query parameters.
pub const MAX_QUERY_PARAMS: u32 = 32;

// Bounded: Max time range (days).
pub const MAX_TIME_RANGE_DAYS: u32 = 365;

// Workflow Observatory: Aggregates all metrics collectors.
pub const WorkflowObservatory = struct {
    workflow_collector: ?*workflow_metrics.WorkflowMetricsCollector,
    coordination_collector: ?*agent_coordination_metrics.AgentCoordinationMetricsCollector,
    failure_collector: ?*failure_pattern_metrics.FailurePatternMetricsCollector,
    performance_collector: ?*performance_metrics.PerformanceMetricsCollector,

    pub fn init() WorkflowObservatory {
        return WorkflowObservatory{
            .workflow_collector = null,
            .coordination_collector = null,
            .failure_collector = null,
            .performance_collector = null,
        };
    }

    /// Set workflow metrics collector.
    pub fn set_workflow_collector(
        self: *WorkflowObservatory,
        collector: *workflow_metrics.WorkflowMetricsCollector,
    ) void {
        std.debug.assert(collector != undefined);
        self.workflow_collector = collector;
    }

    /// Set agent coordination metrics collector.
    pub fn set_coordination_collector(
        self: *WorkflowObservatory,
        collector: *agent_coordination_metrics.AgentCoordinationMetricsCollector,
    ) void {
        std.debug.assert(collector != undefined);
        self.coordination_collector = collector;
    }

    /// Set failure pattern metrics collector.
    pub fn set_failure_collector(
        self: *WorkflowObservatory,
        collector: *failure_pattern_metrics.FailurePatternMetricsCollector,
    ) void {
        std.debug.assert(collector != undefined);
        self.failure_collector = collector;
    }

    /// Set performance metrics collector.
    pub fn set_performance_collector(
        self: *WorkflowObservatory,
        collector: *performance_metrics.PerformanceMetricsCollector,
    ) void {
        std.debug.assert(collector != undefined);
        self.performance_collector = collector;
    }

    /// Get aggregated metrics summary (JSON format).
    pub fn get_aggregated_summary(
        self: *const WorkflowObservatory,
        output: []u8,
    ) u32 {
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;

        // Start JSON object.
        if (offset + 1 < output.len) {
            output[offset] = '{';
            offset += 1;
        } else {
            return offset;
        }

        // Workflow metrics summary.
        if (self.workflow_collector) |collector| {
            const written = self.write_workflow_summary(
                collector,
                output[offset..],
            );
            offset += written;
            if (offset >= output.len) return offset;
        }

        // Agent coordination metrics summary.
        if (self.coordination_collector) |collector| {
            if (offset + 1 < output.len) {
                output[offset] = ',';
                offset += 1;
            } else {
                return offset;
            }
            const written = self.write_coordination_summary(
                collector,
                output[offset..],
            );
            offset += written;
            if (offset >= output.len) return offset;
        }

        // Failure pattern metrics summary.
        if (self.failure_collector) |collector| {
            if (offset + 1 < output.len) {
                output[offset] = ',';
                offset += 1;
            } else {
                return offset;
            }
            const written = self.write_failure_summary(
                collector,
                output[offset..],
            );
            offset += written;
            if (offset >= output.len) return offset;
        }

        // Performance metrics summary.
        if (self.performance_collector) |collector| {
            if (offset + 1 < output.len) {
                output[offset] = ',';
                offset += 1;
            } else {
                return offset;
            }
            const written = self.write_performance_summary(
                collector,
                output[offset..],
            );
            offset += written;
            if (offset >= output.len) return offset;
        }

        // End JSON object.
        if (offset + 1 < output.len) {
            output[offset] = '}';
            offset += 1;
        }
        return offset;
    }

    /// Write workflow metrics summary to JSON.
    fn write_workflow_summary(
        self: *const WorkflowObservatory,
        collector: *workflow_metrics.WorkflowMetricsCollector,
        output: []u8,
    ) u32 {
        _ = self;
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;

        // "workflow":{"total":N,"success_rate":N,"avg_time_ms":N}
        const prefix = "\"workflow\":{";
        const prefix_len = @as(u32, @intCast(prefix.len));
        if (offset + prefix_len < output.len) {
            var i: u32 = 0;
            while (i < prefix_len) : (i += 1) {
                output[offset + i] = prefix[i];
            }
            offset += prefix_len;
        } else {
            return offset;
        }

        // Total executions.
        const total = collector.total_executions;
        const total_written = std.fmt.bufPrint(
            output[offset..],
            "\"total\":{d},",
            .{total},
        ) catch return offset;
        offset += @intCast(total_written.len);

        // Success rate.
        const success_rate = collector.get_success_rate_percent();
        const success_written = std.fmt.bufPrint(
            output[offset..],
            "\"success_rate\":{d},",
            .{success_rate},
        ) catch return offset;
        offset += @intCast(success_written.len);

        // Average execution time.
        const avg_time = collector.get_average_execution_time_ms();
        const avg_written = std.fmt.bufPrint(
            output[offset..],
            "\"avg_time_ms\":{d}",
            .{avg_time},
        ) catch return offset;
        offset += @intCast(avg_written.len);

        // Closing brace.
        if (offset + 1 < output.len) {
            output[offset] = '}';
            offset += 1;
        }
        return offset;
    }

    /// Write coordination metrics summary to JSON.
    fn write_coordination_summary(
        self: *const WorkflowObservatory,
        collector: *agent_coordination_metrics.AgentCoordinationMetricsCollector,
        output: []u8,
    ) u32 {
        _ = self;
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;

        // "coordination":{"total":N,"success_rate":N,"avg_latency_ms":N}
        const prefix = "\"coordination\":{";
        const prefix_len = @as(u32, @intCast(prefix.len));
        if (offset + prefix_len < output.len) {
            var i: u32 = 0;
            while (i < prefix_len) : (i += 1) {
                output[offset + i] = prefix[i];
            }
            offset += prefix_len;
        } else {
            return offset;
        }

        // Total coordinations.
        const total = collector.total_coordinations;
        const total_written = std.fmt.bufPrint(
            output[offset..],
            "\"total\":{d},",
            .{total},
        ) catch return offset;
        offset += @intCast(total_written.len);

        // Success rate.
        const success_rate = collector.get_coordination_success_rate_percent();
        const success_written = std.fmt.bufPrint(
            output[offset..],
            "\"success_rate\":{d},",
            .{success_rate},
        ) catch return offset;
        offset += @intCast(success_written.len);

        // Average latency.
        const avg_latency = collector.get_average_coordination_latency_ms();
        const avg_written = std.fmt.bufPrint(
            output[offset..],
            "\"avg_latency_ms\":{d}",
            .{avg_latency},
        ) catch return offset;
        offset += @intCast(avg_written.len);

        // Closing brace.
        if (offset + 1 < output.len) {
            output[offset] = '}';
            offset += 1;
        }
        return offset;
    }

    /// Write failure pattern metrics summary to JSON.
    fn write_failure_summary(
        self: *const WorkflowObservatory,
        collector: *failure_pattern_metrics.FailurePatternMetricsCollector,
        output: []u8,
    ) u32 {
        _ = self;
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;

        // "failures":{"total":N,"recovery_rate":N}
        const prefix = "\"failures\":{";
        const prefix_len = @as(u32, @intCast(prefix.len));
        if (offset + prefix_len < output.len) {
            var i: u32 = 0;
            while (i < prefix_len) : (i += 1) {
                output[offset + i] = prefix[i];
            }
            offset += prefix_len;
        } else {
            return offset;
        }

        // Total failures.
        const total = collector.total_failures;
        const total_written = std.fmt.bufPrint(
            output[offset..],
            "\"total\":{d},",
            .{total},
        ) catch return offset;
        offset += @intCast(total_written.len);

        // Recovery rate.
        const recovery_rate = collector.get_recovery_success_rate_percent();
        const recovery_written = std.fmt.bufPrint(
            output[offset..],
            "\"recovery_rate\":{d}",
            .{recovery_rate},
        ) catch return offset;
        offset += @intCast(recovery_written.len);

        // Closing brace.
        if (offset + 1 < output.len) {
            output[offset] = '}';
            offset += 1;
        }
        return offset;
    }

    /// Write performance metrics summary to JSON.
    fn write_performance_summary(
        self: *const WorkflowObservatory,
        collector: *performance_metrics.PerformanceMetricsCollector,
        output: []u8,
    ) u32 {
        _ = self;
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;

        // "performance":{"avg_queue_depth":N,"avg_wait_time_ms":N,"avg_cpu_percent":N}
        const prefix = "\"performance\":{";
        const prefix_len = @as(u32, @intCast(prefix.len));
        if (offset + prefix_len < output.len) {
            var i: u32 = 0;
            while (i < prefix_len) : (i += 1) {
                output[offset + i] = prefix[i];
            }
            offset += prefix_len;
        } else {
            return offset;
        }

        // Average queue depth.
        const avg_queue = collector.get_average_queue_depth();
        const queue_written = std.fmt.bufPrint(
            output[offset..],
            "\"avg_queue_depth\":{d},",
            .{avg_queue},
        ) catch return offset;
        offset += @intCast(queue_written.len);

        // Average wait time.
        const avg_wait = collector.get_average_wait_time_ms();
        const wait_written = std.fmt.bufPrint(
            output[offset..],
            "\"avg_wait_time_ms\":{d},",
            .{avg_wait},
        ) catch return offset;
        offset += @intCast(wait_written.len);

        // Average CPU percent.
        const avg_cpu = collector.get_average_cpu_percent();
        const cpu_written = std.fmt.bufPrint(
            output[offset..],
            "\"avg_cpu_percent\":{d}",
            .{avg_cpu},
        ) catch return offset;
        offset += @intCast(cpu_written.len);

        // Closing brace.
        if (offset + 1 < output.len) {
            output[offset] = '}';
            offset += 1;
        }
        return offset;
    }

    /// Export all metrics to JSON (full export with nested structure).
    pub fn export_all_metrics_json(
        self: *const WorkflowObservatory,
        output: []u8,
    ) u32 {
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;

        // Start JSON object.
        if (offset + 1 < output.len) {
            output[offset] = '{';
            offset += 1;
        } else {
            return offset;
        }

        // Export workflow metrics (nested under "workflow" key).
        if (self.workflow_collector) |collector| {
            const prefix = "\"workflow\":";
            const prefix_len = @as(u32, @intCast(prefix.len));
            if (offset + prefix_len < output.len) {
                var i: u32 = 0;
                while (i < prefix_len) : (i += 1) {
                    output[offset + i] = prefix[i];
                }
                offset += prefix_len;
            } else {
                return offset;
            }
            const written = collector.export_json(output[offset..]);
            offset += written;
            if (offset >= output.len) return offset;
            if (offset + 1 < output.len) {
                output[offset] = ',';
                offset += 1;
            } else {
                return offset;
            }
        }

        // Export coordination metrics (nested under "coordination" key).
        if (self.coordination_collector) |collector| {
            const prefix = "\"coordination\":";
            const prefix_len = @as(u32, @intCast(prefix.len));
            if (offset + prefix_len < output.len) {
                var i: u32 = 0;
                while (i < prefix_len) : (i += 1) {
                    output[offset + i] = prefix[i];
                }
                offset += prefix_len;
            } else {
                return offset;
            }
            const written = collector.export_json(output[offset..]);
            offset += written;
            if (offset >= output.len) return offset;
            if (offset + 1 < output.len) {
                output[offset] = ',';
                offset += 1;
            } else {
                return offset;
            }
        }

        // Export failure metrics (nested under "failure" key).
        if (self.failure_collector) |collector| {
            const prefix = "\"failure\":";
            const prefix_len = @as(u32, @intCast(prefix.len));
            if (offset + prefix_len < output.len) {
                var i: u32 = 0;
                while (i < prefix_len) : (i += 1) {
                    output[offset + i] = prefix[i];
                }
                offset += prefix_len;
            } else {
                return offset;
            }
            const written = collector.export_json(output[offset..]);
            offset += written;
            if (offset >= output.len) return offset;
            if (offset + 1 < output.len) {
                output[offset] = ',';
                offset += 1;
            } else {
                return offset;
            }
        }

        // Export performance metrics (nested under "performance" key).
        if (self.performance_collector) |collector| {
            const prefix = "\"performance\":";
            const prefix_len = @as(u32, @intCast(prefix.len));
            if (offset + prefix_len < output.len) {
                var i: u32 = 0;
                while (i < prefix_len) : (i += 1) {
                    output[offset + i] = prefix[i];
                }
                offset += prefix_len;
            } else {
                return offset;
            }
            const written = collector.export_json(output[offset..]);
            offset += written;
            if (offset >= output.len) return offset;
        }

        // End JSON object.
        if (offset + 1 < output.len) {
            output[offset] = '}';
            offset += 1;
        }
        return offset;
    }
};
