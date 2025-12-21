//! Grain Flow Agent Coordination Metrics: Metric collection for agent coordination.
//!
//! Why: Provides metric collection for agent coordination, enabling observability,
//! testing, and measurement of coordination performance and patterns.
//!
//! Architecture: Event-based metric collection, bounded storage, JSON export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-203857-pst: Phase 2 Instrumentation - Agent Coordination Metrics

const std = @import("std");

// Bounded: Max coordinations tracked.
pub const MAX_COORDINATIONS: u32 = 10000;
// Bounded: Max agent pairs for pattern tracking.
pub const MAX_AGENT_PAIRS: u32 = 1024;

// Agent coordination record.
pub const AgentCoordinationRecord = struct {
    source_agent_id: u32,
    target_agent_id: u32,
    workflow_id: u32,
    request_id: u32,
    started_at: u64,
    completed_at: u64,
    coordination_latency_ms: u64,
    status: AgentCoordinationStatus,

    pub fn init(
        source_agent_id: u32,
        target_agent_id: u32,
        workflow_id: u32,
        request_id: u32,
        started_at: u64,
        completed_at: u64,
        status: AgentCoordinationStatus,
    ) AgentCoordinationRecord {
        std.debug.assert(source_agent_id > 0);
        std.debug.assert(target_agent_id > 0);
        std.debug.assert(completed_at >= started_at);
        const latency = if (completed_at >= started_at) completed_at - started_at else 0;
        return AgentCoordinationRecord{
            .source_agent_id = source_agent_id,
            .target_agent_id = target_agent_id,
            .workflow_id = workflow_id,
            .request_id = request_id,
            .started_at = started_at,
            .completed_at = completed_at,
            .coordination_latency_ms = latency,
            .status = status,
        };
    }
};

// Agent coordination status.
pub const AgentCoordinationStatus = enum(u8) {
    success = 0,
    failure = 1,
    timeout = 2,
};

// Agent pair pattern (for tracking coordination frequency).
pub const AgentPairPattern = struct {
    source_agent_id: u32,
    target_agent_id: u32,
    count: u32,
};

// Agent coordination metrics collector.
pub const AgentCoordinationMetricsCollector = struct {
    coordinations: [MAX_COORDINATIONS]AgentCoordinationRecord,
    coordinations_len: u32,
    total_coordinations: u64,
    successful_coordinations: u64,
    failed_coordinations: u64,
    timeout_coordinations: u64,
    pending_coordinations: [MAX_COORDINATIONS]u32,
    pending_coordinations_len: u32,

    pub fn init() AgentCoordinationMetricsCollector {
        var collector = AgentCoordinationMetricsCollector{
            .coordinations = undefined,
            .coordinations_len = 0,
            .total_coordinations = 0,
            .successful_coordinations = 0,
            .failed_coordinations = 0,
            .timeout_coordinations = 0,
            .pending_coordinations = undefined,
            .pending_coordinations_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_COORDINATIONS) : (i += 1) {
            collector.coordinations[i] = AgentCoordinationRecord.init(0, 0, 0, 0, 0, 0, .success);
        }
        i = 0;
        while (i < MAX_COORDINATIONS) : (i += 1) {
            collector.pending_coordinations[i] = 0;
        }
        return collector;
    }

    // Record coordination start (when RPC request is sent).
    pub fn record_coordination_start(
        self: *AgentCoordinationMetricsCollector,
        source_agent_id: u32,
        target_agent_id: u32,
        workflow_id: u32,
        request_id: u32,
        timestamp: u64,
    ) bool {
        std.debug.assert(source_agent_id > 0);
        std.debug.assert(target_agent_id > 0);
        std.debug.assert(request_id > 0);
        if (self.pending_coordinations_len >= MAX_COORDINATIONS) {
            return false;
        }
        self.pending_coordinations[self.pending_coordinations_len] = request_id;
        self.pending_coordinations_len += 1;
        return true;
    }

    // Record coordination completion.
    pub fn record_coordination_completion(
        self: *AgentCoordinationMetricsCollector,
        source_agent_id: u32,
        target_agent_id: u32,
        workflow_id: u32,
        request_id: u32,
        started_at: u64,
        completed_at: u64,
        status: AgentCoordinationStatus,
    ) bool {
        std.debug.assert(source_agent_id > 0);
        std.debug.assert(target_agent_id > 0);
        std.debug.assert(completed_at >= started_at);
        if (self.coordinations_len >= MAX_COORDINATIONS) {
            return false;
        }
        self.coordinations[self.coordinations_len] = AgentCoordinationRecord.init(
            source_agent_id,
            target_agent_id,
            workflow_id,
            request_id,
            started_at,
            completed_at,
            status,
        );
        self.coordinations_len += 1;
        self.total_coordinations += 1;
        if (status == .success) {
            self.successful_coordinations += 1;
        } else if (status == .failure) {
            self.failed_coordinations += 1;
        } else {
            self.timeout_coordinations += 1;
        }
        // Remove from pending coordinations.
        var i: u32 = 0;
        while (i < self.pending_coordinations_len) : (i += 1) {
            if (self.pending_coordinations[i] == request_id) {
                var j: u32 = i;
                while (j < self.pending_coordinations_len - 1) : (j += 1) {
                    self.pending_coordinations[j] = self.pending_coordinations[j + 1];
                }
                self.pending_coordinations_len -= 1;
                break;
            }
        }
        return true;
    }

    // Get average coordination latency (milliseconds).
    pub fn get_average_coordination_latency_ms(
        self: *const AgentCoordinationMetricsCollector,
    ) u64 {
        std.debug.assert(self.coordinations_len > 0);
        if (self.coordinations_len == 0) {
            return 0;
        }
        var total_ms: u64 = 0;
        var i: u32 = 0;
        while (i < self.coordinations_len) : (i += 1) {
            total_ms += self.coordinations[i].coordination_latency_ms;
        }
        return total_ms / @as(u64, self.coordinations_len);
    }

    // Get coordination success rate (percentage, 0-100).
    pub fn get_coordination_success_rate_percent(
        self: *const AgentCoordinationMetricsCollector,
    ) u32 {
        std.debug.assert(self.total_coordinations > 0);
        if (self.total_coordinations == 0) {
            return 0;
        }
        const rate = (self.successful_coordinations * 100) / self.total_coordinations;
        return @intCast(rate);
    }

    // Get coordination patterns (agent pair frequencies).
    pub fn get_coordination_patterns(
        self: *const AgentCoordinationMetricsCollector,
        patterns: []AgentPairPattern,
    ) u32 {
        std.debug.assert(patterns.len > 0);
        var pattern_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.coordinations_len and pattern_count < patterns.len) : (i += 1) {
            const coord = &self.coordinations[i];
            var found: bool = false;
            var j: u32 = 0;
            while (j < pattern_count) : (j += 1) {
                if (patterns[j].source_agent_id == coord.source_agent_id and
                    patterns[j].target_agent_id == coord.target_agent_id)
                {
                    patterns[j].count += 1;
                    found = true;
                    break;
                }
            }
            if (!found) {
                patterns[pattern_count] = AgentPairPattern{
                    .source_agent_id = coord.source_agent_id,
                    .target_agent_id = coord.target_agent_id,
                    .count = 1,
                };
                pattern_count += 1;
            }
        }
        return pattern_count;
    }

    // Export metrics to JSON format.
    pub fn export_json(self: *const AgentCoordinationMetricsCollector, output: []u8) u32 {
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;
        // Write JSON header.
        const header = "{\"total_coordinations\":";
        if (offset + header.len < output.len) {
            @memcpy(output[offset..offset + header.len], header);
            offset += @intCast(header.len);
        }
        const total_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{self.total_coordinations},
        ) catch return offset;
        offset += @intCast(total_str.len);
        // Write success rate.
        const success_label = ",\"success_rate_percent\":";
        if (offset + success_label.len < output.len) {
            @memcpy(output[offset..offset + success_label.len], success_label);
            offset += @intCast(success_label.len);
        }
        const success_rate = self.get_coordination_success_rate_percent();
        const success_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{success_rate},
        ) catch return offset;
        offset += @intCast(success_str.len);
        // Write average latency.
        const latency_label = ",\"avg_coordination_latency_ms\":";
        if (offset + latency_label.len < output.len) {
            @memcpy(output[offset..offset + latency_label.len], latency_label);
            offset += @intCast(latency_label.len);
        }
        const avg_latency = if (self.coordinations_len > 0)
            self.get_average_coordination_latency_ms()
        else
            @as(u64, 0);
        const latency_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{avg_latency},
        ) catch return offset;
        offset += @intCast(latency_str.len);
        // Write coordination patterns.
        const patterns_label = ",\"coordination_patterns\":[";
        if (offset + patterns_label.len < output.len) {
            @memcpy(output[offset..offset + patterns_label.len], patterns_label);
            offset += @intCast(patterns_label.len);
        }
        var pattern_buf: [MAX_AGENT_PAIRS]AgentPairPattern = undefined;
        const pattern_count = self.get_coordination_patterns(&pattern_buf);
        var p: u32 = 0;
        while (p < pattern_count) : (p += 1) {
            if (p > 0) {
                if (offset < output.len) {
                    output[offset] = ',';
                    offset += 1;
                }
            }
            offset += self.write_pattern_json(&pattern_buf[p], output[offset..]);
        }
        // Write JSON footer.
        const footer = "]}";
        if (offset + footer.len < output.len) {
            @memcpy(output[offset..offset + footer.len], footer);
            offset += @intCast(footer.len);
        }
        return offset;
    }

    // Write single pattern to JSON.
    fn write_pattern_json(
        self: *const AgentCoordinationMetricsCollector,
        pattern: *const AgentPairPattern,
        output: []u8,
    ) u32 {
        _ = self;
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;
        const start = "{\"source_agent_id\":";
        if (offset + start.len < output.len) {
            @memcpy(output[offset..offset + start.len], start);
            offset += @intCast(start.len);
        }
        const source_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{pattern.source_agent_id},
        ) catch return offset;
        offset += @intCast(source_str.len);
        const target_label = ",\"target_agent_id\":";
        if (offset + target_label.len < output.len) {
            @memcpy(output[offset..offset + target_label.len], target_label);
            offset += @intCast(target_label.len);
        }
        const target_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{pattern.target_agent_id},
        ) catch return offset;
        offset += @intCast(target_str.len);
        const count_label = ",\"count\":";
        if (offset + count_label.len < output.len) {
            @memcpy(output[offset..offset + count_label.len], count_label);
            offset += @intCast(count_label.len);
        }
        const count_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{pattern.count},
        ) catch return offset;
        offset += @intCast(count_str.len);
        const end = "}";
        if (offset + end.len < output.len) {
            @memcpy(output[offset..offset + end.len], end);
            offset += @intCast(end.len);
        }
        return offset;
    }
};
