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
//! 2025-12-21-204511-pst: ZON Format Integration Preparation (structure prepared, awaiting Court Agent completion)
//! 2025-12-28-173500-pst: ZON Format Integration Implementation (using Court Agent bounded allocation API)
//! 2025-12-28-174500-pst: ZON Format Integration Tests Added (comprehensive test coverage)

const std = @import("std");
const workflow_metrics = @import("workflow_metrics.zig");
const agent_coordination_metrics = @import("agent_coordination_metrics.zig");
const failure_pattern_metrics = @import("failure_pattern_metrics.zig");
const performance_metrics = @import("performance_metrics.zig");
const grain_court = @import("grain_court");

// Bounded: Max aggregated metrics JSON size (10MB).
pub const MAX_AGGREGATED_JSON_SIZE: u32 = 10_485_760;

// Bounded: Max aggregated metrics ZON size (10MB).
pub const MAX_AGGREGATED_ZON_SIZE: u32 = 10_485_760;

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

    /// Export all metrics to ZON format (full export with nested structure).
    /// Uses Court Agent's bounded allocation API for ZON encoding.
    pub fn export_all_metrics_zon(
        self: *const WorkflowObservatory,
        output: []u8,
    ) u32 {
        std.debug.assert(output.len > 0);
        var output_pos: u32 = 0;

        // Helper to create ZonValue from u64 (no from_u64 function available).
        const create_u64_value = struct {
            fn create(value: u64) grain_court.ZonFormat.ZonValue {
                var zv = grain_court.ZonFormat.ZonValue{
                    .value_type = .u64_value,
                    .bool_val = false,
                    .u32_val = 0,
                    .u64_val = value,
                    .i32_val = 0,
                    .i64_val = 0,
                    .f32_val = 0.0,
                    .f64_val = 0.0,
                    .string_val = undefined,
                    .string_val_len = 0,
                };
                var i: u32 = 0;
                while (i < grain_court.ZonFormat.MAX_STRING_VALUE_LEN) : (i += 1) {
                    zv.string_val[i] = 0;
                }
                std.debug.assert(zv.value_type == .u64_value);
                return zv;
            }
        }.create;

        // Build key-value pairs for scalar metrics.
        var pairs: [32]struct { key: []const u8, value: grain_court.ZonFormat.ZonValue } = undefined;
        var pairs_len: u32 = 0;

        // Workflow metrics scalars.
        if (self.workflow_collector) |collector| {
            pairs[pairs_len] = .{ .key = "workflow:total_executions", .value = grain_court.ZonFormat.ZonValue.from_u32(@intCast(collector.total_executions)) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "workflow:success_rate_percent", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_success_rate_percent()) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "workflow:failure_rate_percent", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_failure_rate_percent()) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "workflow:avg_execution_time_ms", .value = create_u64_value(collector.get_average_execution_time_ms()) };
            pairs_len += 1;

            // Encode workflow scalar pairs first.
            if (!grain_court.ZonFormat.encode_zon_bounded(pairs[0..pairs_len], output, &output_pos)) {
                return 0;
            }
            pairs_len = 0;

            // Encode executions array as tabular format (if executions exist).
            if (collector.executions_len > 0) {
                const field_names = [_][]const u8{ "workflow_id", "name", "execution_time_ms", "status" };
                var rows: [workflow_metrics.MAX_WORKFLOW_EXECUTIONS][]const grain_court.ZonFormat.ZonValue = undefined;
                var row_values: [workflow_metrics.MAX_WORKFLOW_EXECUTIONS][4]grain_court.ZonFormat.ZonValue = undefined;
                var rows_len: u32 = 0;
                var i: u32 = 0;
                while (i < collector.executions_len and rows_len < workflow_metrics.MAX_WORKFLOW_EXECUTIONS) : (i += 1) {
                    const exec = collector.executions[i];
                    row_values[rows_len][0] = grain_court.ZonFormat.ZonValue.from_u32(exec.workflow_id);
                    row_values[rows_len][1] = grain_court.ZonFormat.ZonValue.from_string(exec.workflow_name[0..exec.workflow_name_len]);
                    row_values[rows_len][2] = grain_court.ZonFormat.ZonValue.from_u32(@intCast(exec.execution_time_ms)); // Convert u64 to u32 for tabular format
                    const status_str = if (exec.status == .success) "success" else "failure";
                    row_values[rows_len][3] = grain_court.ZonFormat.ZonValue.from_string(status_str);
                    rows[rows_len] = row_values[rows_len][0..4];
                    rows_len += 1;
                }
                if (!grain_court.ZonFormat.encode_tabular_array_zon_bounded("workflow:executions", &field_names, rows[0..rows_len], output, &output_pos)) {
                    return 0; // Buffer full or encoding error
                }
            }
        }

        // Coordination metrics scalars.
        if (self.coordination_collector) |collector| {
            pairs[pairs_len] = .{ .key = "coordination:total_coordinations", .value = grain_court.ZonFormat.ZonValue.from_u32(@intCast(collector.total_coordinations)) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "coordination:success_rate", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_coordination_success_rate_percent()) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "coordination:avg_latency_ms", .value = create_u64_value(collector.get_average_coordination_latency_ms()) };
            pairs_len += 1;
            if (!grain_court.ZonFormat.encode_zon_bounded(pairs[0..pairs_len], output, &output_pos)) {
                return 0;
            }
            pairs_len = 0;
        }

        // Failure metrics scalars.
        if (self.failure_collector) |collector| {
            pairs[pairs_len] = .{ .key = "failures:total_failures", .value = grain_court.ZonFormat.ZonValue.from_u32(@intCast(collector.total_failures)) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "failures:recovery_rate", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_recovery_success_rate_percent()) };
            pairs_len += 1;
            if (!grain_court.ZonFormat.encode_zon_bounded(pairs[0..pairs_len], output, &output_pos)) {
                return 0;
            }
            pairs_len = 0;
        }

        // Performance metrics scalars.
        if (self.performance_collector) |collector| {
            pairs[pairs_len] = .{ .key = "performance:avg_queue_depth", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_average_queue_depth()) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "performance:avg_wait_time_ms", .value = create_u64_value(collector.get_average_wait_time_ms()) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "performance:avg_cpu_percent", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_average_cpu_percent()) };
            pairs_len += 1;
            if (!grain_court.ZonFormat.encode_zon_bounded(pairs[0..pairs_len], output, &output_pos)) {
                return 0;
            }
            pairs_len = 0;
        }

        std.debug.assert(output_pos <= output.len);
        return output_pos;
    }

    /// Get aggregated metrics summary in ZON format.
    /// Uses Court Agent's bounded allocation API for ZON encoding.
    pub fn get_aggregated_summary_zon(
        self: *const WorkflowObservatory,
        output: []u8,
    ) u32 {
        std.debug.assert(output.len > 0);
        var output_pos: u32 = 0;

        // Helper to create ZonValue from u64 (no from_u64 function available).
        const create_u64_value = struct {
            fn create(value: u64) grain_court.ZonFormat.ZonValue {
                var zv = grain_court.ZonFormat.ZonValue{
                    .value_type = .u64_value,
                    .bool_val = false,
                    .u32_val = 0,
                    .u64_val = value,
                    .i32_val = 0,
                    .i64_val = 0,
                    .f32_val = 0.0,
                    .f64_val = 0.0,
                    .string_val = undefined,
                    .string_val_len = 0,
                };
                var i: u32 = 0;
                while (i < grain_court.ZonFormat.MAX_STRING_VALUE_LEN) : (i += 1) {
                    zv.string_val[i] = 0;
                }
                std.debug.assert(zv.value_type == .u64_value);
                return zv;
            }
        }.create;

        // Build key-value pairs for all metrics.
        var pairs: [64]struct { key: []const u8, value: grain_court.ZonFormat.ZonValue } = undefined;
        var pairs_len: u32 = 0;

        // Workflow metrics summary.
        if (self.workflow_collector) |collector| {
            pairs[pairs_len] = .{ .key = "workflow:total_executions", .value = grain_court.ZonFormat.ZonValue.from_u32(@intCast(collector.total_executions)) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "workflow:success_rate_percent", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_success_rate_percent()) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "workflow:avg_execution_time_ms", .value = create_u64_value(collector.get_average_execution_time_ms()) };
            pairs_len += 1;
        }

        // Coordination metrics summary.
        if (self.coordination_collector) |collector| {
            pairs[pairs_len] = .{ .key = "coordination:total_coordinations", .value = grain_court.ZonFormat.ZonValue.from_u32(@intCast(collector.total_coordinations)) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "coordination:success_rate", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_coordination_success_rate_percent()) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "coordination:avg_latency_ms", .value = create_u64_value(collector.get_average_coordination_latency_ms()) };
            pairs_len += 1;
        }

        // Failure metrics summary.
        if (self.failure_collector) |collector| {
            pairs[pairs_len] = .{ .key = "failures:total_failures", .value = grain_court.ZonFormat.ZonValue.from_u32(@intCast(collector.total_failures)) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "failures:recovery_rate", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_recovery_success_rate_percent()) };
            pairs_len += 1;
        }

        // Performance metrics summary.
        if (self.performance_collector) |collector| {
            pairs[pairs_len] = .{ .key = "performance:avg_queue_depth", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_average_queue_depth()) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "performance:avg_wait_time_ms", .value = create_u64_value(collector.get_average_wait_time_ms()) };
            pairs_len += 1;
            pairs[pairs_len] = .{ .key = "performance:avg_cpu_percent", .value = grain_court.ZonFormat.ZonValue.from_u32(collector.get_average_cpu_percent()) };
            pairs_len += 1;
        }

        // Encode pairs to ZON format.
        if (pairs_len > 0) {
            if (!grain_court.ZonFormat.encode_zon_bounded(pairs[0..pairs_len], output, &output_pos)) {
                return 0; // Buffer full or encoding error
            }
        }

        std.debug.assert(output_pos <= output.len);
        return output_pos;
    }
};
