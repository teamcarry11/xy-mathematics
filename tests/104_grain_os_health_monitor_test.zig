//! Tests for Grain OS health monitoring system.
//!
//! Why: Verify health monitoring functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const HealthMonitor = grain_os.health_monitor.HealthMonitor;
const HealthStatus = grain_os.health_monitor.HealthStatus;

test "health monitor initialization" {
    const monitor = HealthMonitor.init();
    std.debug.assert(monitor.checks_len == 0);
    std.debug.assert(monitor.next_check_id == 1);
    std.debug.assert(monitor.overall_status == HealthStatus.unknown);
}

test "add health check" {
    var monitor = HealthMonitor.init();
    const check_id_opt = monitor.add_health_check("cpu_usage");
    std.debug.assert(check_id_opt != null);
    if (check_id_opt) |check_id| {
        std.debug.assert(check_id == 1);
        std.debug.assert(monitor.get_health_check_count() == 1);
    }
}

test "update health check" {
    var monitor = HealthMonitor.init();
    if (monitor.add_health_check("cpu_usage")) |check_id| {
        const result = monitor.update_health_check(
            check_id,
            HealthStatus.healthy,
            "CPU usage is normal",
            1000,
        );
        std.debug.assert(result);
        if (monitor.find_health_check(check_id)) |check| {
            std.debug.assert(check.status == HealthStatus.healthy);
            std.debug.assert(check.last_check_time == 1000);
        }
    }
}

test "overall status healthy" {
    var monitor = HealthMonitor.init();
    if (monitor.add_health_check("check1")) |check_id_1| {
        if (monitor.add_health_check("check2")) |check_id_2| {
            _ = monitor.update_health_check(check_id_1, HealthStatus.healthy, "OK", 1000);
            _ = monitor.update_health_check(check_id_2, HealthStatus.healthy, "OK", 1000);
            std.debug.assert(monitor.get_overall_status() == HealthStatus.healthy);
        }
    }
}

test "overall status warning" {
    var monitor = HealthMonitor.init();
    if (monitor.add_health_check("check1")) |check_id_1| {
        if (monitor.add_health_check("check2")) |check_id_2| {
            _ = monitor.update_health_check(check_id_1, HealthStatus.healthy, "OK", 1000);
            _ = monitor.update_health_check(check_id_2, HealthStatus.warning, "High usage", 1000);
            std.debug.assert(monitor.get_overall_status() == HealthStatus.warning);
        }
    }
}

test "overall status critical" {
    var monitor = HealthMonitor.init();
    if (monitor.add_health_check("check1")) |check_id_1| {
        if (monitor.add_health_check("check2")) |check_id_2| {
            _ = monitor.update_health_check(check_id_1, HealthStatus.warning, "Warning", 1000);
            _ = monitor.update_health_check(check_id_2, HealthStatus.critical, "Critical", 1000);
            std.debug.assert(monitor.get_overall_status() == HealthStatus.critical);
        }
    }
}

test "remove health check" {
    var monitor = HealthMonitor.init();
    if (monitor.add_health_check("cpu_usage")) |check_id| {
        const result = monitor.remove_health_check(check_id);
        std.debug.assert(result);
        std.debug.assert(monitor.get_health_check_count() == 0);
    }
}

test "get healthy check count" {
    var monitor = HealthMonitor.init();
    if (monitor.add_health_check("check1")) |check_id_1| {
        if (monitor.add_health_check("check2")) |check_id_2| {
            _ = monitor.update_health_check(check_id_1, HealthStatus.healthy, "OK", 1000);
            _ = monitor.update_health_check(check_id_2, HealthStatus.healthy, "OK", 1000);
            const count = monitor.get_healthy_check_count();
            std.debug.assert(count == 2);
        }
    }
}

test "get warning check count" {
    var monitor = HealthMonitor.init();
    if (monitor.add_health_check("check1")) |check_id_1| {
        if (monitor.add_health_check("check2")) |check_id_2| {
            _ = monitor.update_health_check(check_id_1, HealthStatus.warning, "Warning", 1000);
            _ = monitor.update_health_check(check_id_2, HealthStatus.warning, "Warning", 1000);
            const count = monitor.get_warning_check_count();
            std.debug.assert(count == 2);
        }
    }
}

test "get critical check count" {
    var monitor = HealthMonitor.init();
    if (monitor.add_health_check("check1")) |check_id_1| {
        if (monitor.add_health_check("check2")) |check_id_2| {
            _ = monitor.update_health_check(check_id_1, HealthStatus.critical, "Critical", 1000);
            _ = monitor.update_health_check(check_id_2, HealthStatus.critical, "Critical", 1000);
            const count = monitor.get_critical_check_count();
            std.debug.assert(count == 2);
        }
    }
}

test "compositor add health check" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const check_id_opt = comp.add_health_check("cpu_usage");
    std.debug.assert(check_id_opt != null);
}

test "compositor update health check" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_health_check("cpu_usage")) |check_id| {
        const result = comp.update_health_check(
            check_id,
            HealthStatus.healthy,
            "CPU usage is normal",
            1000,
        );
        std.debug.assert(result);
    }
}

test "compositor get overall status" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_health_check("check1")) |check_id| {
        _ = comp.update_health_check(check_id, HealthStatus.healthy, "OK", 1000);
        const status = comp.get_overall_health_status();
        std.debug.assert(status == HealthStatus.healthy);
    }
}

test "health statuses" {
    std.debug.assert(@intFromEnum(HealthStatus.healthy) == 0);
    std.debug.assert(@intFromEnum(HealthStatus.warning) == 1);
    std.debug.assert(@intFromEnum(HealthStatus.critical) == 2);
    std.debug.assert(@intFromEnum(HealthStatus.unknown) == 3);
}

test "health monitor constants" {
    std.debug.assert(grain_os.health_monitor.MAX_HEALTH_CHECKS == 32);
    std.debug.assert(grain_os.health_monitor.MAX_HEALTH_CHECK_NAME_LEN == 64);
    std.debug.assert(grain_os.health_monitor.MAX_HEALTH_CHECK_MSG_LEN == 256);
}

