//! Grain OS System Metrics: Unified system metrics aggregation.
//!
//! Why: Provide unified system metrics by aggregating data from multiple sources.
//! Architecture: Metrics aggregation, system status summary, unified reporting.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// System status summary.
pub const SystemStatus = struct {
    overall_health: SystemHealth,
    cpu_usage_percent: f64,
    memory_usage_percent: f64,
    disk_usage_percent: f64,
    total_processes: u32,
    running_processes: u32,
    supervised_processes: u32,
    running_supervised: u32,
    crashed_supervised: u32,
    healthy_checks: u32,
    warning_checks: u32,
    critical_checks: u32,
    timestamp: u64,

    pub fn init() SystemStatus {
        return SystemStatus{
            .overall_health = SystemHealth.unknown,
            .cpu_usage_percent = 0.0,
            .memory_usage_percent = 0.0,
            .disk_usage_percent = 0.0,
            .total_processes = 0,
            .running_processes = 0,
            .supervised_processes = 0,
            .running_supervised = 0,
            .crashed_supervised = 0,
            .healthy_checks = 0,
            .warning_checks = 0,
            .critical_checks = 0,
            .timestamp = 0,
        };
    }
};

// System health (aggregated).
pub const SystemHealth = enum(u8) {
    healthy,
    warning,
    critical,
    unknown,
};

// Metrics aggregator: aggregates system metrics.
pub const MetricsAggregator = struct {
    current_status: SystemStatus,

    pub fn init() MetricsAggregator {
        return MetricsAggregator{
            .current_status = SystemStatus.init(),
        };
    }

    // Update system status from resource monitor.
    pub fn update_from_resource_monitor(
        self: *MetricsAggregator,
        cpu_percent: f64,
        memory_percent: f64,
        disk_percent: f64,
        total_processes: u32,
        running_processes: u32,
    ) void {
        std.debug.assert(cpu_percent >= 0.0);
        std.debug.assert(cpu_percent <= 100.0);
        std.debug.assert(memory_percent >= 0.0);
        std.debug.assert(memory_percent <= 100.0);
        std.debug.assert(disk_percent >= 0.0);
        std.debug.assert(disk_percent <= 100.0);
        self.current_status.cpu_usage_percent = cpu_percent;
        self.current_status.memory_usage_percent = memory_percent;
        self.current_status.disk_usage_percent = disk_percent;
        self.current_status.total_processes = total_processes;
        self.current_status.running_processes = running_processes;
    }

    // Update system status from health monitor.
    pub fn update_from_health_monitor(
        self: *MetricsAggregator,
        overall_health: SystemHealth,
        healthy_checks: u32,
        warning_checks: u32,
        critical_checks: u32,
    ) void {
        self.current_status.overall_health = overall_health;
        self.current_status.healthy_checks = healthy_checks;
        self.current_status.warning_checks = warning_checks;
        self.current_status.critical_checks = critical_checks;
    }

    // Update system status from process supervisor.
    pub fn update_from_process_supervisor(
        self: *MetricsAggregator,
        supervised_processes: u32,
        running_supervised: u32,
        crashed_supervised: u32,
    ) void {
        self.current_status.supervised_processes = supervised_processes;
        self.current_status.running_supervised = running_supervised;
        self.current_status.crashed_supervised = crashed_supervised;
    }

    // Update timestamp.
    pub fn update_timestamp(self: *MetricsAggregator, timestamp: u64) void {
        self.current_status.timestamp = timestamp;
    }

    // Calculate overall system health.
    pub fn calculate_overall_health(self: *MetricsAggregator) SystemHealth {
        if (self.current_status.critical_checks > 0) {
            return SystemHealth.critical;
        }
        if (self.current_status.crashed_supervised > 0) {
            return SystemHealth.critical;
        }
        if (self.current_status.warning_checks > 0) {
            return SystemHealth.warning;
        }
        if (self.current_status.cpu_usage_percent > 90.0) {
            return SystemHealth.warning;
        }
        if (self.current_status.memory_usage_percent > 90.0) {
            return SystemHealth.warning;
        }
        if (self.current_status.disk_usage_percent > 90.0) {
            return SystemHealth.warning;
        }
        if (self.current_status.healthy_checks > 0) {
            return SystemHealth.healthy;
        }
        return SystemHealth.unknown;
    }

    // Get current system status.
    pub fn get_system_status(self: *MetricsAggregator) SystemStatus {
        self.current_status.overall_health = self.calculate_overall_health();
        return self.current_status;
    }

    // Get overall health.
    pub fn get_overall_health(self: *MetricsAggregator) SystemHealth {
        return self.calculate_overall_health();
    }
};

