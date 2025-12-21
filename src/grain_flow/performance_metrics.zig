//! Grain Flow Performance Metrics: Metric collection for performance characteristics.
//!
//! Why: Provides metric collection for performance characteristics, enabling observability,
//! testing, and measurement of resource usage, queue depth, and wait times.
//!
//! Architecture: Event-based and sampling-based metric collection, bounded storage, JSON export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-205348-pst: Phase 2 Instrumentation - Phase 4 Performance Characteristics

const std = @import("std");

// Bounded: Max performance samples tracked.
pub const MAX_PERFORMANCE_SAMPLES: u32 = 10000;
// Bounded: Max queue depth samples.
pub const MAX_QUEUE_DEPTH_SAMPLES: u32 = 1000;
// Bounded: Max wait time records.
pub const MAX_WAIT_TIME_RECORDS: u32 = 10000;

// Resource usage record.
pub const ResourceUsageRecord = struct {
    workflow_id: u32,
    timestamp: u64,
    cpu_percent: u32,
    memory_bytes: u64,
    network_bytes: u64,

    pub fn init(
        workflow_id: u32,
        timestamp: u64,
        cpu_percent: u32,
        memory_bytes: u64,
        network_bytes: u64,
    ) ResourceUsageRecord {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(timestamp > 0);
        std.debug.assert(cpu_percent <= 100);
        return ResourceUsageRecord{
            .workflow_id = workflow_id,
            .timestamp = timestamp,
            .cpu_percent = cpu_percent,
            .memory_bytes = memory_bytes,
            .network_bytes = network_bytes,
        };
    }
};

// Queue depth sample.
pub const QueueDepthSample = struct {
    timestamp: u64,
    queue_depth: u32,

    pub fn init(timestamp: u64, queue_depth: u32) QueueDepthSample {
        std.debug.assert(timestamp > 0);
        return QueueDepthSample{
            .timestamp = timestamp,
            .queue_depth = queue_depth,
        };
    }
};

// Wait time record.
pub const WaitTimeRecord = struct {
    workflow_id: u32,
    created_at: u64,
    started_at: u64,
    wait_time_ms: u64,

    pub fn init(workflow_id: u32, created_at: u64, started_at: u64) WaitTimeRecord {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(started_at >= created_at);
        const wait_time = started_at - created_at;
        return WaitTimeRecord{
            .workflow_id = workflow_id,
            .created_at = created_at,
            .started_at = started_at,
            .wait_time_ms = wait_time,
        };
    }
};

// Performance metrics collector.
pub const PerformanceMetricsCollector = struct {
    resource_samples: [MAX_PERFORMANCE_SAMPLES]ResourceUsageRecord,
    resource_samples_len: u32,
    queue_depth_samples: [MAX_QUEUE_DEPTH_SAMPLES]QueueDepthSample,
    queue_depth_samples_len: u32,
    wait_time_records: [MAX_WAIT_TIME_RECORDS]WaitTimeRecord,
    wait_time_records_len: u32,
    total_resource_samples: u64,
    total_queue_depth_samples: u64,
    total_wait_time_records: u64,

    pub fn init() PerformanceMetricsCollector {
        var collector = PerformanceMetricsCollector{
            .resource_samples = undefined,
            .resource_samples_len = 0,
            .queue_depth_samples = undefined,
            .queue_depth_samples_len = 0,
            .wait_time_records = undefined,
            .wait_time_records_len = 0,
            .total_resource_samples = 0,
            .total_queue_depth_samples = 0,
            .total_wait_time_records = 0,
        };
        var i: u32 = 0;
        while (i < MAX_PERFORMANCE_SAMPLES) : (i += 1) {
            collector.resource_samples[i] = ResourceUsageRecord.init(0, 0, 0, 0, 0);
        }
        i = 0;
        while (i < MAX_QUEUE_DEPTH_SAMPLES) : (i += 1) {
            collector.queue_depth_samples[i] = QueueDepthSample.init(0, 0);
        }
        i = 0;
        while (i < MAX_WAIT_TIME_RECORDS) : (i += 1) {
            collector.wait_time_records[i] = WaitTimeRecord.init(0, 0, 0);
        }
        return collector;
    }

    // Record resource usage sample.
    pub fn record_resource_usage(
        self: *PerformanceMetricsCollector,
        workflow_id: u32,
        timestamp: u64,
        cpu_percent: u32,
        memory_bytes: u64,
        network_bytes: u64,
    ) bool {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(timestamp > 0);
        std.debug.assert(cpu_percent <= 100);
        if (self.resource_samples_len >= MAX_PERFORMANCE_SAMPLES) {
            return false;
        }
        self.resource_samples[self.resource_samples_len] = ResourceUsageRecord.init(
            workflow_id,
            timestamp,
            cpu_percent,
            memory_bytes,
            network_bytes,
        );
        self.resource_samples_len += 1;
        self.total_resource_samples += 1;
        return true;
    }

    // Record queue depth sample.
    pub fn record_queue_depth(
        self: *PerformanceMetricsCollector,
        timestamp: u64,
        queue_depth: u32,
    ) bool {
        std.debug.assert(timestamp > 0);
        if (self.queue_depth_samples_len >= MAX_QUEUE_DEPTH_SAMPLES) {
            return false;
        }
        self.queue_depth_samples[self.queue_depth_samples_len] = QueueDepthSample.init(
            timestamp,
            queue_depth,
        );
        self.queue_depth_samples_len += 1;
        self.total_queue_depth_samples += 1;
        return true;
    }

    // Record wait time.
    pub fn record_wait_time(
        self: *PerformanceMetricsCollector,
        workflow_id: u32,
        created_at: u64,
        started_at: u64,
    ) bool {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(started_at >= created_at);
        if (self.wait_time_records_len >= MAX_WAIT_TIME_RECORDS) {
            return false;
        }
        self.wait_time_records[self.wait_time_records_len] = WaitTimeRecord.init(
            workflow_id,
            created_at,
            started_at,
        );
        self.wait_time_records_len += 1;
        self.total_wait_time_records += 1;
        return true;
    }

    // Get average queue depth.
    pub fn get_average_queue_depth(self: *const PerformanceMetricsCollector) u32 {
        std.debug.assert(self.queue_depth_samples_len > 0);
        if (self.queue_depth_samples_len == 0) {
            return 0;
        }
        var total_depth: u64 = 0;
        var i: u32 = 0;
        while (i < self.queue_depth_samples_len) : (i += 1) {
            total_depth += self.queue_depth_samples[i].queue_depth;
        }
        const avg = total_depth / @as(u64, self.queue_depth_samples_len);
        return @intCast(avg);
    }

    // Get average wait time (milliseconds).
    pub fn get_average_wait_time_ms(self: *const PerformanceMetricsCollector) u64 {
        std.debug.assert(self.wait_time_records_len > 0);
        if (self.wait_time_records_len == 0) {
            return 0;
        }
        var total_wait: u64 = 0;
        var i: u32 = 0;
        while (i < self.wait_time_records_len) : (i += 1) {
            total_wait += self.wait_time_records[i].wait_time_ms;
        }
        return total_wait / @as(u64, self.wait_time_records_len);
    }

    // Get average CPU usage (percentage).
    pub fn get_average_cpu_percent(self: *const PerformanceMetricsCollector) u32 {
        std.debug.assert(self.resource_samples_len > 0);
        if (self.resource_samples_len == 0) {
            return 0;
        }
        var total_cpu: u64 = 0;
        var i: u32 = 0;
        while (i < self.resource_samples_len) : (i += 1) {
            total_cpu += self.resource_samples[i].cpu_percent;
        }
        const avg = total_cpu / @as(u64, self.resource_samples_len);
        return @intCast(avg);
    }

    // Get average memory usage (bytes).
    pub fn get_average_memory_bytes(self: *const PerformanceMetricsCollector) u64 {
        std.debug.assert(self.resource_samples_len > 0);
        if (self.resource_samples_len == 0) {
            return 0;
        }
        var total_memory: u64 = 0;
        var i: u32 = 0;
        while (i < self.resource_samples_len) : (i += 1) {
            total_memory += self.resource_samples[i].memory_bytes;
        }
        return total_memory / @as(u64, self.resource_samples_len);
    }

    // Export metrics to JSON format.
    pub fn export_json(self: *const PerformanceMetricsCollector, output: []u8) u32 {
        std.debug.assert(output.len > 0);
        var offset: u32 = 0;
        // Write JSON header.
        const header = "{\"avg_queue_depth\":";
        if (offset + header.len < output.len) {
            @memcpy(output[offset..offset + header.len], header);
            offset += @intCast(header.len);
        }
        const avg_queue = self.get_average_queue_depth();
        const queue_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{avg_queue},
        ) catch return offset;
        offset += @intCast(queue_str.len);
        // Write average wait time.
        const wait_label = ",\"avg_wait_time_ms\":";
        if (offset + wait_label.len < output.len) {
            @memcpy(output[offset..offset + wait_label.len], wait_label);
            offset += @intCast(wait_label.len);
        }
        const avg_wait = if (self.wait_time_records_len > 0)
            self.get_average_wait_time_ms()
        else
            @as(u64, 0);
        const wait_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{avg_wait},
        ) catch return offset;
        offset += @intCast(wait_str.len);
        // Write average CPU usage.
        const cpu_label = ",\"avg_cpu_percent\":";
        if (offset + cpu_label.len < output.len) {
            @memcpy(output[offset..offset + cpu_label.len], cpu_label);
            offset += @intCast(cpu_label.len);
        }
        const avg_cpu = if (self.resource_samples_len > 0)
            self.get_average_cpu_percent()
        else
            @as(u32, 0);
        const cpu_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{avg_cpu},
        ) catch return offset;
        offset += @intCast(cpu_str.len);
        // Write average memory usage.
        const mem_label = ",\"avg_memory_bytes\":";
        if (offset + mem_label.len < output.len) {
            @memcpy(output[offset..offset + mem_label.len], mem_label);
            offset += @intCast(mem_label.len);
        }
        const avg_mem = if (self.resource_samples_len > 0)
            self.get_average_memory_bytes()
        else
            @as(u64, 0);
        const mem_str = std.fmt.bufPrint(
            output[offset..],
            "{}",
            .{avg_mem},
        ) catch return offset;
        offset += @intCast(mem_str.len);
        // Write JSON footer.
        const footer = "}";
        if (offset + footer.len < output.len) {
            @memcpy(output[offset..offset + footer.len], footer);
            offset += @intCast(footer.len);
        }
        return offset;
    }
};
