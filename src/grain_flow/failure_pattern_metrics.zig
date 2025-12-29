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
// Bounded: Max error message length (1024 chars).
pub const MAX_ERROR_MESSAGE_LEN: u32 = 1024;
// Bounded: Max context data length (10KB).
pub const MAX_CONTEXT_DATA_LEN: u32 = 10240;

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
    failure_id: u32,
    workflow_id: u32,
    node_id: u32,
    agent_id: u32,
    failure_type: FailureType,
    failed_at: u64,
    recovered: bool,
    recovered_at: u64,
    recovery_attempts: u32,
    workflow_complexity: WorkflowComplexity,
    error_message: [MAX_ERROR_MESSAGE_LEN]u8,
    error_message_len: u32,
    context_data: [MAX_CONTEXT_DATA_LEN]u8,
    context_data_len: u32,

    pub fn init(
        failure_id: u32,
        workflow_id: u32,
        node_id: u32,
        agent_id: u32,
        failure_type: FailureType,
        failed_at: u64,
        complexity: WorkflowComplexity,
    ) FailureRecord {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(failed_at > 0);
        var record = FailureRecord{
            .failure_id = failure_id,
            .workflow_id = workflow_id,
            .node_id = node_id,
            .agent_id = agent_id,
            .failure_type = failure_type,
            .failed_at = failed_at,
            .recovered = false,
            .recovered_at = 0,
            .recovery_attempts = 0,
            .workflow_complexity = complexity,
            .error_message = undefined,
            .error_message_len = 0,
            .context_data = undefined,
            .context_data_len = 0,
        };
        // Initialize error_message and context_data to zero.
        var i: u32 = 0;
        while (i < MAX_ERROR_MESSAGE_LEN) : (i += 1) {
            record.error_message[i] = 0;
        }
        i = 0;
        while (i < MAX_CONTEXT_DATA_LEN) : (i += 1) {
            record.context_data[i] = 0;
        }
        return record;
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
            .next_failure_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_FAILURES) : (i += 1) {
            collector.failures[i] = FailureRecord.init(0, 0, 0, 0, .unknown, 0, WorkflowComplexity.init(1, 0, 1));
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
        error_message: ?[]const u8,
        context_data: ?[]const u8,
    ) bool {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(failed_at > 0);
        if (self.failures_len >= MAX_FAILURES) {
            return false;
        }
        const failure_id = self.next_failure_id;
        self.next_failure_id += 1;
        var record = FailureRecord.init(
            failure_id,
            workflow_id,
            node_id,
            agent_id,
            failure_type,
            failed_at,
            complexity,
        );
        // Store error_message if provided.
        if (error_message) |msg| {
            const msg_len = @min(msg.len, MAX_ERROR_MESSAGE_LEN);
            if (msg_len > 0) {
                var i: u32 = 0;
                while (i < msg_len) : (i += 1) {
                    record.error_message[i] = msg[i];
                }
                record.error_message_len = msg_len;
            }
        }
        // Store context_data if provided.
        if (context_data) |ctx| {
            const ctx_len = @min(ctx.len, MAX_CONTEXT_DATA_LEN);
            if (ctx_len > 0) {
                var i: u32 = 0;
                while (i < ctx_len) : (i += 1) {
                    record.context_data[i] = ctx[i];
                }
                record.context_data_len = ctx_len;
            }
        }
        self.failures[self.failures_len] = record;
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
        // Write failures array.
        const failures_label = ",\"failures\":[";
        if (offset + failures_label.len < output.len) {
            @memcpy(output[offset..offset + failures_label.len], failures_label);
            offset += @intCast(failures_label.len);
        }
        var first_failure: bool = true;
        var failure_idx: u32 = 0;
        while (failure_idx < self.failures_len) : (failure_idx += 1) {
            if (!first_failure) {
                if (offset < output.len) {
                    output[offset] = ',';
                    offset += 1;
                } else {
                    return offset;
                }
            }
            const written = self.write_failure_json(&self.failures[failure_idx], output[offset..]);
            if (written == 0) {
                return offset;
            }
            offset += written;
            if (offset >= output.len) {
                return offset;
            }
            first_failure = false;
        }
        const failures_end = "]";
        if (offset + failures_end.len < output.len) {
            @memcpy(output[offset..offset + failures_end.len], failures_end);
            offset += @intCast(failures_end.len);
        }
        // Write JSON footer.
        const footer = "}";
        if (offset + footer.len < output.len) {
            @memcpy(output[offset..offset + footer.len], footer);
            offset += @intCast(footer.len);
        }
        return offset;
    }

    // Write single failure record as JSON object.
    fn write_failure_json(
        self: *const FailurePatternMetricsCollector,
        record: *const FailureRecord,
        output: []u8,
    ) u32 {
        _ = self;
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;
        // Write opening brace.
        if (offset >= output.len) return 0;
        output[offset] = '{';
        offset += 1;
        // Write all fields.
        offset = write_json_field_u32(output, offset, "failure_id", record.failure_id, false);
        if (offset == 0) return 0;
        offset = write_json_field_u32(output, offset, "workflow_id", record.workflow_id, true);
        if (offset == 0) return 0;
        offset = write_json_field_u32(output, offset, "agent_id", record.agent_id, true);
        if (offset == 0) return 0;
        offset = write_json_field_failure_type(output, offset, record.failure_type);
        if (offset == 0) return 0;
        offset = write_json_field_u64(output, offset, "timestamp", record.failed_at, true);
        if (offset == 0) return 0;
        const status_str = if (record.recovered or record.recovered_at > 0) "succeeded" else "not_attempted";
        offset = write_json_field_string_literal(output, offset, "recovery_status", status_str);
        if (offset == 0) return 0;
        const recovery_time_ms = if (record.recovered and record.recovered_at > record.failed_at)
            (record.recovered_at - record.failed_at) / 1_000_000
        else
            @as(u64, 0);
        offset = write_json_field_u64(output, offset, "recovery_time_ms", recovery_time_ms, true);
        if (offset == 0) return 0;
        const msg_slice = if (record.error_message_len > 0)
            record.error_message[0..record.error_message_len]
        else
            "";
        offset = write_json_field_string_escaped(output, offset, "error_message", msg_slice);
        if (offset == 0) return 0;
        const ctx_slice = if (record.context_data_len > 0)
            record.context_data[0..record.context_data_len]
        else
            "";
        offset = write_json_field_string_escaped(output, offset, "context_data", ctx_slice);
        if (offset == 0) return 0;
        // Write closing brace.
        if (offset >= output.len) return offset;
        output[offset] = '}';
        offset += 1;
        return offset;
    }
};

// Write JSON field: u32 value.
fn write_json_field_u32(
    output: []u8,
    offset: u32,
    field_name: []const u8,
    value: u32,
    comma: bool,
) u32 {
        std.debug.assert(output.len > 0);
        std.debug.assert(offset < output.len);
        var pos = offset;
        // Write comma if needed.
        if (comma) {
            if (pos >= output.len) return 0;
            output[pos] = ',';
            pos += 1;
        }
        // Write field name.
        const label_prefix = "\"";
        if (pos + label_prefix.len >= output.len) return 0;
        @memcpy(output[pos..pos + label_prefix.len], label_prefix);
        pos += @intCast(label_prefix.len);
        if (pos + field_name.len >= output.len) return 0;
        @memcpy(output[pos..pos + field_name.len], field_name);
        pos += @intCast(field_name.len);
        const label_suffix = "\":";
        if (pos + label_suffix.len >= output.len) return 0;
        @memcpy(output[pos..pos + label_suffix.len], label_suffix);
        pos += @intCast(label_suffix.len);
        // Write value.
        const val_str = std.fmt.bufPrint(
            output[pos..],
            "{}",
            .{value},
        ) catch return 0;
        pos += @intCast(val_str.len);
        return pos;
    }

    // Write JSON field: u64 value.
    fn write_json_field_u64(
        output: []u8,
        offset: u32,
        field_name: []const u8,
        value: u64,
        comma: bool,
    ) u32 {
        std.debug.assert(output.len > 0);
        std.debug.assert(offset < output.len);
        var pos = offset;
        // Write comma if needed.
        if (comma) {
            if (pos >= output.len) return 0;
            output[pos] = ',';
            pos += 1;
        }
        // Write field name.
        const label_prefix = "\"";
        if (pos + label_prefix.len >= output.len) return 0;
        @memcpy(output[pos..pos + label_prefix.len], label_prefix);
        pos += @intCast(label_prefix.len);
        if (pos + field_name.len >= output.len) return 0;
        @memcpy(output[pos..pos + field_name.len], field_name);
        pos += @intCast(field_name.len);
        const label_suffix = "\":";
        if (pos + label_suffix.len >= output.len) return 0;
        @memcpy(output[pos..pos + label_suffix.len], label_suffix);
        pos += @intCast(label_suffix.len);
        // Write value.
        const val_str = std.fmt.bufPrint(
            output[pos..],
            "{}",
            .{value},
        ) catch return 0;
        pos += @intCast(val_str.len);
        return pos;
    }

    // Write JSON field: failure_type enum as string.
    fn write_json_field_failure_type(
        output: []u8,
        offset: u32,
        failure_type: FailureType,
    ) u32 {
        std.debug.assert(output.len > 0);
        std.debug.assert(offset < output.len);
        var pos = offset;
        // Write comma and field name.
        if (pos >= output.len) return 0;
        output[pos] = ',';
        pos += 1;
        const label = "\"failure_type\":\"";
        if (pos + label.len >= output.len) return 0;
        @memcpy(output[pos..pos + label.len], label);
        pos += @intCast(label.len);
        // Write type name.
        const type_name = switch (failure_type) {
            .transient => "transient",
            .permanent => "permanent",
            .timeout => "timeout",
            .invalid_input => "invalid_input",
            .agent_unavailable => "agent_unavailable",
            .workflow_cycle => "workflow_cycle",
            .resource_exhausted => "resource_exhausted",
            .unknown => "unknown",
        };
        if (pos + type_name.len >= output.len) return 0;
        @memcpy(output[pos..pos + type_name.len], type_name);
        pos += @intCast(type_name.len);
        // Write closing quote.
        if (pos >= output.len) return 0;
        output[pos] = '"';
        pos += 1;
        return pos;
    }

    // Write JSON field: string literal (no escaping needed).
    fn write_json_field_string_literal(
        output: []u8,
        offset: u32,
        field_name: []const u8,
        value: []const u8,
    ) u32 {
        std.debug.assert(output.len > 0);
        std.debug.assert(offset < output.len);
        var pos = offset;
        // Write comma and field name.
        if (pos >= output.len) return 0;
        output[pos] = ',';
        pos += 1;
        const label_prefix = "\"";
        if (pos + label_prefix.len >= output.len) return 0;
        @memcpy(output[pos..pos + label_prefix.len], label_prefix);
        pos += @intCast(label_prefix.len);
        if (pos + field_name.len >= output.len) return 0;
        @memcpy(output[pos..pos + field_name.len], field_name);
        pos += @intCast(field_name.len);
        const label_suffix = "\":\"";
        if (pos + label_suffix.len >= output.len) return 0;
        @memcpy(output[pos..pos + label_suffix.len], label_suffix);
        pos += @intCast(label_suffix.len);
        // Write value.
        if (pos + value.len >= output.len) return 0;
        @memcpy(output[pos..pos + value.len], value);
        pos += @intCast(value.len);
        // Write closing quote.
        if (pos >= output.len) return 0;
        output[pos] = '"';
        pos += 1;
        return pos;
    }

    // Write JSON field: string with JSON escaping.
    fn write_json_field_string_escaped(
        output: []u8,
        offset: u32,
        field_name: []const u8,
        value: []const u8,
    ) u32 {
        std.debug.assert(output.len > 0);
        std.debug.assert(offset < output.len);
        var pos = offset;
        // Write comma and field name.
        if (pos >= output.len) return 0;
        output[pos] = ',';
        pos += 1;
        const label_prefix = "\"";
        if (pos + label_prefix.len >= output.len) return 0;
        @memcpy(output[pos..pos + label_prefix.len], label_prefix);
        pos += @intCast(label_prefix.len);
        if (pos + field_name.len >= output.len) return 0;
        @memcpy(output[pos..pos + field_name.len], field_name);
        pos += @intCast(field_name.len);
        const label_suffix = "\":\"";
        if (pos + label_suffix.len >= output.len) return 0;
        @memcpy(output[pos..pos + label_suffix.len], label_suffix);
        pos += @intCast(label_suffix.len);
        // Write escaped value.
        pos = write_json_escape_string(output, pos, value);
        if (pos == 0) return 0;
        // Write closing quote.
        if (pos >= output.len) return 0;
        output[pos] = '"';
        pos += 1;
        return pos;
    }

    // Escape string for JSON output.
    fn write_json_escape_string(
        output: []u8,
        offset: u32,
        value: []const u8,
    ) u32 {
        std.debug.assert(output.len > 0);
        std.debug.assert(offset < output.len);
        var pos = offset;
        var i: u32 = 0;
        while (i < value.len) : (i += 1) {
            if (pos >= output.len) return 0;
            const ch = value[i];
            if (ch == '"' or ch == '\\' or ch == '\n' or ch == '\r' or ch == '\t') {
                // Write escape character.
                if (pos >= output.len) return 0;
                output[pos] = '\\';
                pos += 1;
                // Write escaped character.
                if (pos >= output.len) return 0;
                const esc_char = switch (ch) {
                    '"' => '"',
                    '\\' => '\\',
                    '\n' => 'n',
                    '\r' => 'r',
                    '\t' => 't',
                    else => ch,
                };
                output[pos] = esc_char;
                pos += 1;
            } else {
                // Write character as-is.
                if (pos >= output.len) return 0;
                output[pos] = ch;
                pos += 1;
            }
        }
        return pos;
    }
