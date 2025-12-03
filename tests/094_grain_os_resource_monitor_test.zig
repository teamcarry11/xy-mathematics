//! Tests for Grain OS resource monitoring system.
//!
//! Why: Verify resource monitoring functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ResourceMonitor = grain_os.resource_monitor.ResourceMonitor;

test "resource monitor initialization" {
    const monitor = ResourceMonitor.init();
    std.debug.assert(monitor.get_cpu_usage() == 0.0);
    std.debug.assert(monitor.get_memory_usage() == 0);
    std.debug.assert(monitor.get_total_memory() == 0);
    std.debug.assert(monitor.get_history_count() == 0);
}

test "update resource usage" {
    var monitor = ResourceMonitor.init();
    monitor.update_usage(25.5, 4096, 16384, 1024, 8192, 1000);
    std.debug.assert(monitor.get_cpu_usage() == 25.5);
    std.debug.assert(monitor.get_memory_usage() == 4096);
    std.debug.assert(monitor.get_total_memory() == 16384);
}

test "get memory usage percentage" {
    var monitor = ResourceMonitor.init();
    monitor.update_usage(0.0, 4096, 16384, 0, 0, 1000);
    const mem_percent = monitor.get_memory_usage_percent();
    std.debug.assert(mem_percent == 25.0);
}

test "get disk usage percentage" {
    var monitor = ResourceMonitor.init();
    monitor.update_usage(0.0, 0, 0, 2048, 8192, 1000);
    const disk_percent = monitor.get_disk_usage_percent();
    std.debug.assert(disk_percent == 25.0);
}

test "get current usage" {
    var monitor = ResourceMonitor.init();
    monitor.update_usage(50.0, 8192, 16384, 4096, 8192, 1000);
    const usage = monitor.get_current_usage();
    std.debug.assert(usage.cpu_percent == 50.0);
    std.debug.assert(usage.memory_used == 8192);
}

test "get history entry" {
    var monitor = ResourceMonitor.init();
    monitor.update_usage(10.0, 1024, 16384, 512, 8192, 1000);
    monitor.update_usage(20.0, 2048, 16384, 1024, 8192, 2000);
    const entry_opt = monitor.get_history_entry(0);
    std.debug.assert(entry_opt != null);
    if (entry_opt) |entry| {
        std.debug.assert(entry.cpu_percent == 10.0);
    }
}

test "get history count" {
    var monitor = ResourceMonitor.init();
    std.debug.assert(monitor.get_history_count() == 0);
    monitor.update_usage(10.0, 1024, 16384, 512, 8192, 1000);
    std.debug.assert(monitor.get_history_count() == 1);
    monitor.update_usage(20.0, 2048, 16384, 1024, 8192, 2000);
    std.debug.assert(monitor.get_history_count() == 2);
}

test "clear history" {
    var monitor = ResourceMonitor.init();
    monitor.update_usage(10.0, 1024, 16384, 512, 8192, 1000);
    std.debug.assert(monitor.get_history_count() == 1);
    monitor.clear_history();
    std.debug.assert(monitor.get_history_count() == 0);
}

test "compositor update resource usage" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.update_resource_usage(30.0, 8192, 32768, 4096, 16384, 1000);
    std.debug.assert(comp.get_cpu_usage() == 30.0);
    std.debug.assert(comp.get_memory_usage() == 8192);
}

test "compositor get memory usage percentage" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.update_resource_usage(0.0, 4096, 16384, 0, 0, 1000);
    const mem_percent = comp.get_memory_usage_percent();
    std.debug.assert(mem_percent == 25.0);
}

test "compositor get disk usage percentage" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.update_resource_usage(0.0, 0, 0, 2048, 8192, 1000);
    const disk_percent = comp.get_disk_usage_percent();
    std.debug.assert(disk_percent == 25.0);
}

test "compositor get current resource usage" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.update_resource_usage(40.0, 16384, 32768, 8192, 16384, 1000);
    const usage = comp.get_current_resource_usage();
    std.debug.assert(usage.cpu_percent == 40.0);
    std.debug.assert(usage.memory_used == 16384);
}

test "compositor get resource history count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_resource_history_count() == 0);
    comp.update_resource_usage(10.0, 1024, 16384, 512, 8192, 1000);
    std.debug.assert(comp.get_resource_history_count() == 1);
}

test "resource monitor constants" {
    std.debug.assert(grain_os.resource_monitor.MAX_HISTORY_ENTRIES == 64);
}

test "update from kernel" {
    var monitor = ResourceMonitor.init();
    const basin_kernel = @import("basin_kernel");
    // Mock syscall function that returns success.
    const mock_syscall: ResourceMonitor.SyscallFn = struct {
        fn mock_fn(syscall_num: u32, arg1: u64, _arg2: u64, _arg3: u64, _arg4: u64) i64 {
            _ = _arg2;
            _ = _arg3;
            _ = _arg4;
            if (syscall_num == @intFromEnum(basin_kernel.Syscall.sysinfo)) {
                // Write mock SysInfo to buffer (56 bytes for enhanced sysinfo).
                const buf_ptr = @as(*[56]u8, @ptrFromInt(@intCast(arg1)));
                const info = @as(*basin_kernel.SysInfo, @ptrCast(buf_ptr));
                info.total_memory = 1024 * 1024 * 1024; // 1GB
                info.available_memory = 512 * 1024 * 1024; // 512MB
                info.used_memory = 512 * 1024 * 1024; // 512MB (enhanced field)
                info.cpu_cores = 4;
                info.uptime_ns = 1000000000; // 1 second
                info.load_avg_1min = 500; // 50% load
                info.total_processes = 10; // Enhanced field
                info.running_processes = 7; // Enhanced field
                info.exited_processes = 3; // Enhanced field
                return 0;
            }
            return -1;
        }
    }.mock_fn;
    monitor.set_syscall_fn(mock_syscall);
    const result = monitor.update_from_kernel(1000);
    std.debug.assert(result);
    std.debug.assert(monitor.get_cpu_usage() == 50.0);
    std.debug.assert(monitor.get_memory_usage() == 512 * 1024 * 1024);
    std.debug.assert(monitor.get_total_memory() == 1024 * 1024 * 1024);
    std.debug.assert(monitor.get_total_processes() == 10);
    std.debug.assert(monitor.get_running_processes() == 7);
    std.debug.assert(monitor.get_exited_processes() == 3);
}

test "update usage with process counts" {
    var monitor = ResourceMonitor.init();
    monitor.update_usage_with_processes(25.0, 256 * 1024 * 1024, 1024 * 1024 * 1024, 0, 0, 5, 3, 2, 1000);
    std.debug.assert(monitor.get_cpu_usage() == 25.0);
    std.debug.assert(monitor.get_memory_usage() == 256 * 1024 * 1024);
    std.debug.assert(monitor.get_total_processes() == 5);
    std.debug.assert(monitor.get_running_processes() == 3);
    std.debug.assert(monitor.get_exited_processes() == 2);
}

test "get process counts" {
    var monitor = ResourceMonitor.init();
    monitor.update_usage_with_processes(0.0, 0, 0, 0, 0, 10, 7, 3, 1000);
    std.debug.assert(monitor.get_total_processes() == 10);
    std.debug.assert(monitor.get_running_processes() == 7);
    std.debug.assert(monitor.get_exited_processes() == 3);
}

test "compositor get process counts from monitor" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    // Process counts will be 0 if syscall not set, but methods should work.
    _ = comp.get_total_process_count();
    _ = comp.get_running_process_count_from_monitor();
    _ = comp.get_exited_process_count();
}

