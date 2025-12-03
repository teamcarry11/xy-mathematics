//! Tests for Grain OS kernel integration.
//!
//! Why: Verify kernel syscall integration for resource monitoring and process management.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ResourceMonitor = grain_os.resource_monitor.ResourceMonitor;
const ProcessManager = grain_os.process_manager.ProcessManager;

// Mock syscall function for testing.
fn mock_syscall(syscall_num: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64) i64 {
    _ = arg2;
    _ = arg3;
    _ = arg4;
    // Mock sysinfo syscall (syscall #50).
    if (syscall_num == 50) {
        // Write mock SysInfo structure to buffer.
        const info_ptr = @as(*[40]u8, @ptrFromInt(@as(usize, @intCast(arg1))));
        // total_memory: u64 (offset 0) = 16MB
        @as(*u64, @ptrCast(&info_ptr[0])).* = 16 * 1024 * 1024;
        // available_memory: u64 (offset 8) = 8MB
        @as(*u64, @ptrCast(&info_ptr[8])).* = 8 * 1024 * 1024;
        // cpu_cores: u32 (offset 16) = 1
        @as(*u32, @ptrCast(&info_ptr[16])).* = 1;
        // uptime_ns: u64 (offset 24) = 1000000000 (1 second)
        @as(*u64, @ptrCast(&info_ptr[24])).* = 1000000000;
        // load_avg_1min: u32 (offset 32) = 500 (50% load, scaled by 1000)
        @as(*u32, @ptrCast(&info_ptr[32])).* = 500;
        return 0;
    }
    // Mock spawn syscall (syscall #1).
    if (syscall_num == 1) {
        return 42; // Return mock PID.
    }
    // Mock kill syscall (syscall #80).
    if (syscall_num == 80) {
        return 0; // Success.
    }
    return -1; // Error.
}

test "resource monitor set syscall function" {
    var monitor = ResourceMonitor.init();
    monitor.set_syscall_fn(mock_syscall);
    std.debug.assert(monitor.syscall_fn != null);
}

test "resource monitor update from kernel" {
    var monitor = ResourceMonitor.init();
    monitor.set_syscall_fn(mock_syscall);
    const result = monitor.update_from_kernel(1000);
    std.debug.assert(result);
    std.debug.assert(monitor.get_total_memory() == 16 * 1024 * 1024);
    std.debug.assert(monitor.get_memory_usage() == 8 * 1024 * 1024);
    const cpu_usage = monitor.get_cpu_usage();
    std.debug.assert(cpu_usage >= 49.0);
    std.debug.assert(cpu_usage <= 51.0);
}

test "process manager set syscall function" {
    var manager = ProcessManager.init();
    manager.set_syscall_fn(mock_syscall);
    std.debug.assert(manager.syscall_fn != null);
}

test "process manager spawn process" {
    var manager = ProcessManager.init();
    manager.set_syscall_fn(mock_syscall);
    const pid_opt = manager.spawn_process(0, "test_process", "/bin/test", 1000);
    std.debug.assert(pid_opt != null);
    if (pid_opt) |pid| {
        std.debug.assert(pid == 42);
        std.debug.assert(manager.get_process_count() == 1);
    }
}

test "process manager kill process" {
    var manager = ProcessManager.init();
    manager.set_syscall_fn(mock_syscall);
    if (manager.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const result = manager.kill_process(process_id);
        std.debug.assert(result);
        if (manager.find_process(process_id)) |proc| {
            std.debug.assert(proc.state == .dead);
        }
    }
}

test "compositor set syscall function propagates" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_syscall_fn(mock_syscall);
    std.debug.assert(comp.resource_monitor.syscall_fn != null);
    std.debug.assert(comp.process_manager.syscall_fn != null);
}

test "compositor update resource usage from kernel" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_syscall_fn(mock_syscall);
    const result = comp.update_resource_usage_from_kernel(1000);
    std.debug.assert(result);
    std.debug.assert(comp.get_total_memory() == 16 * 1024 * 1024);
}

test "compositor spawn process" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_syscall_fn(mock_syscall);
    const pid_opt = comp.spawn_process(0, "test_process", "/bin/test", 1000);
    std.debug.assert(pid_opt != null);
    if (pid_opt) |pid| {
        std.debug.assert(pid == 42);
    }
}

test "compositor kill process" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_syscall_fn(mock_syscall);
    if (comp.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const result = comp.kill_process(process_id);
        std.debug.assert(result);
    }
}

