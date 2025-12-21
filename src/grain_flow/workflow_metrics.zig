//! Grain Flow Workflow Metrics: Metric collection for workflow observability.
//!
//! Why: Provides metric collection for workflow execution, enabling observability,
//! testing, and measurement of workflow health.
//!
//! Architecture: Event-based metric collection, bounded storage, JSON export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-201357-pst: Phase 2 Instrumentation - Phase 1 Basic Metrics

const std = @import("std");

// Bounded: Max workflow executions tracked.
pub const MAX_WORKFLOW_EXECUTIONS: u32 = 10000;
// Bounded: Max workflow name length for metrics.
pub const MAX_WORKFLOW_NAME_LEN: u32 = 128;
// Bounded: Max JSON export size.
pub const MAX_JSON_EXPORT_SIZE: u32 = 1024 * 1024;

// Workflow execution record.
pub const WorkflowExecutionRecord = struct {
    workflow_id: u32,
    workflow_name: [MAX_WORKFLOW_NAME_LEN]u8,
    workflow_name_len: u32,
    started_at: u64,
    completed_at: u64,
    execution_time_ms: u64,
    status: WorkflowExecutionStatus,

    pub fn init(
        workflow_id: u32,
        name: []const u8,
        started_at: u64,
        completed_at: u64,
        status: WorkflowExecutionStatus,
    ) WorkflowExecutionRecord {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(started_at > 0);
        std.debug.assert(completed_at >= started_at);
        var record = WorkflowExecutionRecord{
            .workflow_id = workflow_id,
            .workflow_name = undefined,
            .workflow_name_len = 0,
            .started_at = started_at,
            .completed_at = completed_at,
            .execution_time_ms = completed_at - started_at,
            .status = status,
        };
        var i: u32 = 0;
        while (i < MAX_WORKFLOW_NAME_LEN) : (i += 1) {
            record.workflow_name[i] = 0;
        }
        const name_len = @min(name.len, MAX_WORKFLOW_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            record.workflow_name[i] = name[i];
        }
        record.workflow_name_len = @intCast(name_len);
        return record;
    }
};

// Workflow execution status.
pub const WorkflowExecutionStatus = enum(u8) {
    success = 0,
    failure = 1,
};

// Workflow metrics collector.
pub const WorkflowMetricsCollector = struct {
    executions: [MAX_WORKFLOW_EXECUTIONS]WorkflowExecutionRecord,
    executions_len: u32,
    total_executions: u64,
    successful_executions: u64,
    failed_executions: u64,

    pub fn init() WorkflowMetricsCollector {
        var collector = WorkflowMetricsCollector{
            .executions = undefined,
            .executions_len = 0,
            .total_executions = 0,
            .successful_executions = 0,
            .failed_executions = 0,
        };
        var i: u32 = 0;
        while (i < MAX_WORKFLOW_EXECUTIONS) : (i += 1) {
            collector.executions[i] = WorkflowExecutionRecord.init(0, "", 0, 0, .success);
        }
        return collector;
    }

    // Record workflow execution.
    pub fn record_execution(
        self: *WorkflowMetricsCollector,
        workflow_id: u32,
        name: []const u8,
        started_at: u64,
        completed_at: u64,
        status: WorkflowExecutionStatus,
    ) bool {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(completed_at >= started_at);
        if (self.executions_len >= MAX_WORKFLOW_EXECUTIONS) {
            return false;
        }
        self.executions[self.executions_len] = WorkflowExecutionRecord.init(
            workflow_id,
            name,
            started_at,
            completed_at,
            status,
        );
        self.executions_len += 1;
        self.total_executions += 1;
        if (status == .success) {
            self.successful_executions += 1;
        } else {
            self.failed_executions += 1;
        }
        return true;
    }

    // Get workflow execution time (average).
    pub fn get_average_execution_time_ms(self: *const WorkflowMetricsCollector) u64 {
        std.debug.assert(self.executions_len > 0);
        if (self.executions_len == 0) {
            return 0;
        }
        var total_ms: u64 = 0;
        var i: u32 = 0;
        while (i < self.executions_len) : (i += 1) {
            total_ms += self.executions[i].execution_time_ms;
        }
        return total_ms / @as(u64, self.executions_len);
    }

    // Get workflow success rate (percentage, 0-100).
    pub fn get_success_rate_percent(self: *const WorkflowMetricsCollector) u32 {
        std.debug.assert(self.total_executions > 0);
        if (self.total_executions == 0) {
            return 0;
        }
        const rate = (self.successful_executions * 100) / self.total_executions;
        return @intCast(rate);
    }

    // Get workflow failure rate (percentage, 0-100).
    pub fn get_failure_rate_percent(self: *const WorkflowMetricsCollector) u32 {
        std.debug.assert(self.total_executions > 0);
        if (self.total_executions == 0) {
            return 0;
        }
        const rate = (self.failed_executions * 100) / self.total_executions;
        return @intCast(rate);
    }

    // Export metrics to JSON format.
    pub fn export_json(self: *const WorkflowMetricsCollector, output: []u8) u32 {
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;
        // Write JSON header.
        const header = "{\"total_executions\":";
        if (offset + header.len < output.len) {
            @memcpy(output[offset..offset + header.len], header);
            offset += @intCast(header.len);
        }
        const total_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{self.total_executions},
        ) catch return offset;
        offset += @intCast(total_str.len);
        // Write success rate.
        const success_label = ",\"success_rate_percent\":";
        if (offset + success_label.len < output.len) {
            @memcpy(output[offset..offset + success_label.len], success_label);
            offset += @intCast(success_label.len);
        }
        const success_rate = self.get_success_rate_percent();
        const success_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{success_rate},
        ) catch return offset;
        offset += @intCast(success_str.len);
        // Write failure rate.
        const failure_label = ",\"failure_rate_percent\":";
        if (offset + failure_label.len < output.len) {
            @memcpy(output[offset..offset + failure_label.len], failure_label);
            offset += @intCast(failure_label.len);
        }
        const failure_rate = self.get_failure_rate_percent();
        const failure_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{failure_rate},
        ) catch return offset;
        offset += @intCast(failure_str.len);
        // Write average execution time.
        const time_label = ",\"avg_execution_time_ms\":";
        if (offset + time_label.len < output.len) {
            @memcpy(output[offset..offset + time_label.len], time_label);
            offset += @intCast(time_label.len);
        }
        const avg_time = if (self.executions_len > 0)
            self.get_average_execution_time_ms()
        else
            @as(u64, 0);
        const time_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{avg_time},
        ) catch return offset;
        offset += @intCast(time_str.len);
        // Write executions array.
        const exec_label = ",\"executions\":[";
        if (offset + exec_label.len < output.len) {
            @memcpy(output[offset..offset + exec_label.len], exec_label);
            offset += @intCast(exec_label.len);
        }
        var i: u32 = 0;
        while (i < self.executions_len) : (i += 1) {
            if (i > 0) {
                if (offset < output.len) {
                    output[offset] = ',';
                    offset += 1;
                }
            }
            offset += self.write_execution_json(&self.executions[i], output[offset..]);
        }
        // Write JSON footer.
        const footer = "]}";
        if (offset + footer.len < output.len) {
            @memcpy(output[offset..offset + footer.len], footer);
            offset += @intCast(footer.len);
        }
        return offset;
    }

    // Write single execution record to JSON.
    fn write_execution_json(
        self: *const WorkflowMetricsCollector,
        record: *const WorkflowExecutionRecord,
        output: []u8,
    ) u32 {
        _ = self;
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;
        const start = "{\"workflow_id\":";
        if (offset + start.len < output.len) {
            @memcpy(output[offset..offset + start.len], start);
            offset += @intCast(start.len);
        }
        const id_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{record.workflow_id},
        ) catch return offset;
        offset += @intCast(id_str.len);
        const name_start = ",\"name\":\"";
        if (offset + name_start.len < output.len) {
            @memcpy(output[offset..offset + name_start.len], name_start);
            offset += @intCast(name_start.len);
        }
        if (offset + record.workflow_name_len < output.len) {
            @memcpy(
                output[offset..offset + record.workflow_name_len],
                record.workflow_name[0..record.workflow_name_len],
            );
            offset += record.workflow_name_len;
        }
        const exec_time = ",\"execution_time_ms\":";
        if (offset + exec_time.len < output.len) {
            @memcpy(output[offset..offset + exec_time.len], exec_time);
            offset += @intCast(exec_time.len);
        }
        const time_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{record.execution_time_ms},
        ) catch return offset;
        offset += @intCast(time_str.len);
        const status_label = ",\"status\":\"";
        if (offset + status_label.len < output.len) {
            @memcpy(output[offset..offset + status_label.len], status_label);
            offset += @intCast(status_label.len);
        }
        const status_str = if (record.status == .success) "success" else "failure";
        if (offset + status_str.len < output.len) {
            @memcpy(output[offset..offset + status_str.len], status_str);
            offset += @intCast(status_str.len);
        }
        const end = "\"}";
        if (offset + end.len < output.len) {
            @memcpy(output[offset..offset + end.len], end);
            offset += @intCast(end.len);
        }
        return offset;
    }
};
