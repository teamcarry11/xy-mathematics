//! Tests for Grain Monitor application.
//!
//! Why: Verify system monitoring and resource tracking functionality.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-164418-pst: Active implementation

const std = @import("std");
const testing = std.testing;
const MonitorApp = @import("../src/grain_workspace/monitor/app.zig").MonitorApp;
const grain_core = @import("grain_core");

test "monitor app initialization" {
    const allocator = testing.allocator;
    var process_mgr = grain_core.process_manager.ProcessManager.init();
    var resource_mon = grain_core.resource_monitor.ResourceMonitor.init();

    var app = MonitorApp.init(allocator, &process_mgr, &resource_mon);

    try testing.expect(app.metrics_history_len == 0);
    try testing.expect(app.alert_thresholds_len == 0);
}

test "update metrics" {
    const allocator = testing.allocator;
    var process_mgr = grain_core.process_manager.ProcessManager.init();
    var resource_mon = grain_core.resource_monitor.ResourceMonitor.init();

    resource_mon.update_usage(50.0, 1024 * 1024, 4 * 1024 * 1024, 0, 0, 1234567890);
    resource_mon.update_usage_with_processes(50.0, 1024 * 1024, 4 * 1024 * 1024, 0, 0, 10, 8, 2, 1234567890);

    var app = MonitorApp.init(allocator, &process_mgr, &resource_mon);
    app.update_metrics(3600);

    try testing.expect(app.metrics_history_len == 1);

    const metrics = app.get_current_metrics();
    try testing.expect(metrics.cpu_percent == 50.0);
    try testing.expect(metrics.uptime == 3600);
    try testing.expect(metrics.total_processes == 10);
    try testing.expect(metrics.running_processes == 8);
}

test "get current metrics" {
    const allocator = testing.allocator;
    var process_mgr = grain_core.process_manager.ProcessManager.init();
    var resource_mon = grain_core.resource_monitor.ResourceMonitor.init();

    resource_mon.update_usage(75.0, 2048 * 1024, 8 * 1024 * 1024, 0, 0, 1234567890);
    resource_mon.update_usage_with_processes(75.0, 2048 * 1024, 8 * 1024 * 1024, 0, 0, 20, 15, 5, 1234567890);

    var app = MonitorApp.init(allocator, &process_mgr, &resource_mon);
    app.update_metrics(7200);

    const metrics = app.get_current_metrics();
    try testing.expect(metrics.cpu_percent == 75.0);
    try testing.expect(metrics.memory_percent == 25.0); // 2MB / 8MB = 25%
    try testing.expect(metrics.uptime == 7200);
}

test "get all processes" {
    const allocator = testing.allocator;
    var process_mgr = grain_core.process_manager.ProcessManager.init();
    var resource_mon = grain_core.resource_monitor.ResourceMonitor.init();

    // Add a test process
    var proc = grain_core.process_manager.Process.init();
    proc.process_id = 1;
    proc.name_len = 4;
    @memcpy(proc.name[0..4], "test");
    proc.active = true;
    process_mgr.processes[0] = proc;
    process_mgr.processes_len = 1;

    var app = MonitorApp.init(allocator, &process_mgr, &resource_mon);

    var processes: [10]MonitorApp.ProcessInfo = undefined;
    var processes_len: u32 = 0;
    app.get_all_processes(&processes, &processes_len);

    try testing.expect(processes_len == 1);
    try testing.expect(processes[0].process_id == 1);
    try testing.expect(processes[0].name_len == 4);
}

test "add alert threshold" {
    const allocator = testing.allocator;
    var process_mgr = grain_core.process_manager.ProcessManager.init();
    var resource_mon = grain_core.resource_monitor.ResourceMonitor.init();

    var app = MonitorApp.init(allocator, &process_mgr, &resource_mon);

    try app.add_alert_threshold(.cpu, 80.0);
    try testing.expect(app.alert_thresholds_len == 1);
    try testing.expect(app.alert_thresholds[0].resource_type == .cpu);
    try testing.expect(app.alert_thresholds[0].threshold_value == 80.0);
    try testing.expect(app.alert_thresholds[0].enabled == true);

    try app.add_alert_threshold(.memory, 90.0);
    try testing.expect(app.alert_thresholds_len == 2);
    try testing.expect(app.alert_thresholds[1].resource_type == .memory);
    try testing.expect(app.alert_thresholds[1].threshold_value == 90.0);
}

test "metrics history" {
    const allocator = testing.allocator;
    var process_mgr = grain_core.process_manager.ProcessManager.init();
    var resource_mon = grain_core.resource_monitor.ResourceMonitor.init();

    var app = MonitorApp.init(allocator, &process_mgr, &resource_mon);

    // Update metrics multiple times
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        resource_mon.update_usage(@as(f64, @floatFromInt(i * 10)), 0, 0, 0, 0, 1234567890 + i);
        resource_mon.update_usage_with_processes(@as(f64, @floatFromInt(i * 10)), 0, 0, 0, 0, 0, 0, 0, 1234567890 + i);
        app.update_metrics(3600 + i);
    }

    try testing.expect(app.metrics_history_len == 10);
}

test "alert threshold checking" {
    const allocator = testing.allocator;
    var process_mgr = grain_core.process_manager.ProcessManager.init();
    var resource_mon = grain_core.resource_monitor.ResourceMonitor.init();

    var app = MonitorApp.init(allocator, &process_mgr, &resource_mon);

    try app.add_alert_threshold(.cpu, 50.0);
    try app.add_alert_threshold(.memory, 60.0);

    // Set CPU to 75% (above threshold)
    resource_mon.update_usage(75.0, 1024 * 1024, 2 * 1024 * 1024, 0, 0, 1234567890);
    resource_mon.update_usage_with_processes(75.0, 1024 * 1024, 2 * 1024 * 1024, 0, 0, 0, 0, 0, 1234567890);
    app.update_metrics(3600);

    // Metrics should be updated and thresholds checked
    const metrics = app.get_current_metrics();
    try testing.expect(metrics.cpu_percent == 75.0);
    try testing.expect(metrics.memory_percent == 50.0); // 1MB / 2MB = 50%
}

