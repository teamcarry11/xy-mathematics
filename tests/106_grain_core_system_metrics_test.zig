//! Tests for Grain OS system metrics aggregation.
//!
//! Why: Verify system metrics aggregation functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_core = @import("grain_core");
const Compositor = grain_core.compositor.Compositor;
const MetricsAggregator = grain_core.system_metrics.MetricsAggregator;
const SystemHealth = grain_core.system_metrics.SystemHealth;

test "metrics aggregator initialization" {
    const aggregator = MetricsAggregator.init();
    const status = aggregator.get_system_status();
    std.debug.assert(status.cpu_usage_percent == 0.0);
    std.debug.assert(status.memory_usage_percent == 0.0);
    std.debug.assert(status.total_processes == 0);
    std.debug.assert(status.overall_health == SystemHealth.unknown);
}

test "update from resource monitor" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_from_resource_monitor(25.5, 50.0, 75.0, 10, 7);
    const status = aggregator.get_system_status();
    std.debug.assert(status.cpu_usage_percent == 25.5);
    std.debug.assert(status.memory_usage_percent == 50.0);
    std.debug.assert(status.disk_usage_percent == 75.0);
    std.debug.assert(status.total_processes == 10);
    std.debug.assert(status.running_processes == 7);
}

test "update from health monitor" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_from_health_monitor(SystemHealth.healthy, 5, 2, 0);
    const status = aggregator.get_system_status();
    std.debug.assert(status.overall_health == SystemHealth.healthy);
    std.debug.assert(status.healthy_checks == 5);
    std.debug.assert(status.warning_checks == 2);
    std.debug.assert(status.critical_checks == 0);
}

test "update from process supervisor" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_from_process_supervisor(8, 6, 1);
    const status = aggregator.get_system_status();
    std.debug.assert(status.supervised_processes == 8);
    std.debug.assert(status.running_supervised == 6);
    std.debug.assert(status.crashed_supervised == 1);
}

test "calculate overall health critical" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_from_health_monitor(SystemHealth.critical, 0, 0, 1);
    const health = aggregator.calculate_overall_health();
    std.debug.assert(health == SystemHealth.critical);
}

test "calculate overall health warning" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_from_health_monitor(SystemHealth.warning, 0, 1, 0);
    aggregator.update_from_resource_monitor(50.0, 50.0, 50.0, 0, 0);
    const health = aggregator.calculate_overall_health();
    std.debug.assert(health == SystemHealth.warning);
}

test "calculate overall health from high cpu" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_from_resource_monitor(95.0, 50.0, 50.0, 0, 0);
    aggregator.update_from_health_monitor(SystemHealth.healthy, 5, 0, 0);
    const health = aggregator.calculate_overall_health();
    std.debug.assert(health == SystemHealth.warning);
}

test "calculate overall health from high memory" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_from_resource_monitor(50.0, 95.0, 50.0, 0, 0);
    aggregator.update_from_health_monitor(SystemHealth.healthy, 5, 0, 0);
    const health = aggregator.calculate_overall_health();
    std.debug.assert(health == SystemHealth.warning);
}

test "calculate overall health from crashed supervised" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_from_process_supervisor(5, 3, 1);
    aggregator.update_from_health_monitor(SystemHealth.healthy, 5, 0, 0);
    const health = aggregator.calculate_overall_health();
    std.debug.assert(health == SystemHealth.critical);
}

test "calculate overall health healthy" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_from_resource_monitor(50.0, 50.0, 50.0, 0, 0);
    aggregator.update_from_health_monitor(SystemHealth.healthy, 5, 0, 0);
    aggregator.update_from_process_supervisor(5, 5, 0);
    const health = aggregator.calculate_overall_health();
    std.debug.assert(health == SystemHealth.healthy);
}

test "update timestamp" {
    var aggregator = MetricsAggregator.init();
    aggregator.update_timestamp(1000);
    const status = aggregator.get_system_status();
    std.debug.assert(status.timestamp == 1000);
}

test "compositor update system metrics" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.update_resource_usage(25.0, 1024, 4096, 512, 2048, 1000);
    comp.update_system_metrics(1000);
    const status = comp.get_system_status();
    std.debug.assert(status.cpu_usage_percent == 25.0);
}

test "compositor get overall system health" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.update_resource_usage(50.0, 1024, 4096, 512, 2048, 1000);
    if (comp.add_health_check("test")) |check_id| {
        _ = comp.update_health_check(check_id, grain_core.health_monitor.HealthStatus.healthy, "OK", 1000);
    }
    comp.update_system_metrics(1000);
    const health = comp.get_overall_system_health();
    std.debug.assert(health == SystemHealth.healthy);
}

test "system health enum" {
    std.debug.assert(@intFromEnum(SystemHealth.healthy) == 0);
    std.debug.assert(@intFromEnum(SystemHealth.warning) == 1);
    std.debug.assert(@intFromEnum(SystemHealth.critical) == 2);
    std.debug.assert(@intFromEnum(SystemHealth.unknown) == 3);
}

