//! Grain OS Resource Monitor: System resource monitoring.
//!
//! Why: Provide system resource monitoring for CPU, memory, and disk usage.
//! Architecture: Resource tracking, usage statistics, performance metrics.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const basin_kernel = @import("basin_kernel");

// Bounded: Max history entries.
pub const MAX_HISTORY_ENTRIES: u32 = 64;

// Resource usage: represents system resource usage.
pub const ResourceUsage = struct {
    cpu_percent: f64, // CPU usage percentage (0.0 to 100.0).
    memory_used: u64, // Memory used in bytes.
    memory_total: u64, // Total memory in bytes.
    disk_used: u64, // Disk used in bytes.
    disk_total: u64, // Total disk in bytes.
    total_processes: u32, // Total number of processes.
    running_processes: u32, // Number of running processes.
    exited_processes: u32, // Number of exited processes.
    timestamp: u64, // Timestamp of measurement.

    pub fn init() ResourceUsage {
        return ResourceUsage{
            .cpu_percent = 0.0,
            .memory_used = 0,
            .memory_total = 0,
            .disk_used = 0,
            .disk_total = 0,
            .total_processes = 0,
            .running_processes = 0,
            .exited_processes = 0,
            .timestamp = 0,
        };
    }
};

// Syscall function type.
const SyscallFn = *const fn (u32, u64, u64, u64, u64) i64;

// Resource monitor: monitors system resources.
pub const ResourceMonitor = struct {
    current_usage: ResourceUsage,
    history: [MAX_HISTORY_ENTRIES]ResourceUsage,
    history_len: u32,
    history_index: u32,
    syscall_fn: ?SyscallFn,

    pub fn init() ResourceMonitor {
        var monitor = ResourceMonitor{
            .current_usage = ResourceUsage.init(),
            .history = undefined,
            .history_len = 0,
            .history_index = 0,
            .syscall_fn = null,
        };
        var i: u32 = 0;
        while (i < MAX_HISTORY_ENTRIES) : (i += 1) {
            monitor.history[i] = ResourceUsage.init();
        }
        return monitor;
    }

    // Update resource usage.
    pub fn update_usage(
        self: *ResourceMonitor,
        cpu_percent: f64,
        memory_used: u64,
        memory_total: u64,
        disk_used: u64,
        disk_total: u64,
        timestamp: u64,
    ) void {
        std.debug.assert(cpu_percent >= 0.0);
        std.debug.assert(cpu_percent <= 100.0);
        self.current_usage.cpu_percent = cpu_percent;
        self.current_usage.memory_used = memory_used;
        self.current_usage.memory_total = memory_total;
        self.current_usage.disk_used = disk_used;
        self.current_usage.disk_total = disk_total;
        self.current_usage.timestamp = timestamp;
        // Add to history.
        self.history[self.history_index] = self.current_usage;
        self.history_index = (self.history_index + 1) % MAX_HISTORY_ENTRIES;
        if (self.history_len < MAX_HISTORY_ENTRIES) {
            self.history_len += 1;
        }
    }

    // Update resource usage with process counts.
    pub fn update_usage_with_processes(
        self: *ResourceMonitor,
        cpu_percent: f64,
        memory_used: u64,
        memory_total: u64,
        disk_used: u64,
        disk_total: u64,
        total_processes: u32,
        running_processes: u32,
        exited_processes: u32,
        timestamp: u64,
    ) void {
        std.debug.assert(cpu_percent >= 0.0);
        std.debug.assert(cpu_percent <= 100.0);
        self.current_usage.cpu_percent = cpu_percent;
        self.current_usage.memory_used = memory_used;
        self.current_usage.memory_total = memory_total;
        self.current_usage.disk_used = disk_used;
        self.current_usage.disk_total = disk_total;
        self.current_usage.total_processes = total_processes;
        self.current_usage.running_processes = running_processes;
        self.current_usage.exited_processes = exited_processes;
        self.current_usage.timestamp = timestamp;
        // Add to history.
        self.history[self.history_index] = self.current_usage;
        self.history_index = (self.history_index + 1) % MAX_HISTORY_ENTRIES;
        if (self.history_len < MAX_HISTORY_ENTRIES) {
            self.history_len += 1;
        }
    }

    // Get current CPU usage.
    pub fn get_cpu_usage(self: *const ResourceMonitor) f64 {
        return self.current_usage.cpu_percent;
    }

    // Get current memory usage.
    pub fn get_memory_usage(self: *const ResourceMonitor) u64 {
        return self.current_usage.memory_used;
    }

    // Get total memory.
    pub fn get_total_memory(self: *const ResourceMonitor) u64 {
        return self.current_usage.memory_total;
    }

    // Get memory usage percentage.
    pub fn get_memory_usage_percent(self: *const ResourceMonitor) f64 {
        if (self.current_usage.memory_total == 0) {
            return 0.0;
        }
        const used: f64 = @floatFromInt(self.current_usage.memory_used);
        const total: f64 = @floatFromInt(self.current_usage.memory_total);
        return (used / total) * 100.0;
    }

    // Get current disk usage.
    pub fn get_disk_usage(self: *const ResourceMonitor) u64 {
        return self.current_usage.disk_used;
    }

    // Get total disk.
    pub fn get_total_disk(self: *const ResourceMonitor) u64 {
        return self.current_usage.disk_total;
    }

    // Get disk usage percentage.
    pub fn get_disk_usage_percent(self: *const ResourceMonitor) f64 {
        if (self.current_usage.disk_total == 0) {
            return 0.0;
        }
        const used: f64 = @floatFromInt(self.current_usage.disk_used);
        const total: f64 = @floatFromInt(self.current_usage.disk_total);
        return (used / total) * 100.0;
    }

    // Get total process count.
    pub fn get_total_processes(self: *const ResourceMonitor) u32 {
        return self.current_usage.total_processes;
    }

    // Get running process count.
    pub fn get_running_processes(self: *const ResourceMonitor) u32 {
        return self.current_usage.running_processes;
    }

    // Get exited process count.
    pub fn get_exited_processes(self: *const ResourceMonitor) u32 {
        return self.current_usage.exited_processes;
    }

    // Get current usage.
    pub fn get_current_usage(self: *const ResourceMonitor) ResourceUsage {
        return self.current_usage;
    }

    // Get history entry.
    pub fn get_history_entry(self: *const ResourceMonitor, index: u32) ?*const ResourceUsage {
        if (index >= self.history_len) {
            return null;
        }
        const actual_index = (self.history_index + MAX_HISTORY_ENTRIES - self.history_len + index) % MAX_HISTORY_ENTRIES;
        return &self.history[actual_index];
    }

    // Get history count.
    pub fn get_history_count(self: *const ResourceMonitor) u32 {
        return self.history_len;
    }

    // Clear history.
    pub fn clear_history(self: *ResourceMonitor) void {
        self.history_len = 0;
        self.history_index = 0;
    }

    // Set syscall function.
    pub fn set_syscall_fn(self: *ResourceMonitor, fn_ptr: SyscallFn) void {
        std.debug.assert(@intFromPtr(fn_ptr) != 0);
        self.syscall_fn = fn_ptr;
    }

    // Update from kernel sysinfo syscall.
    pub fn update_from_kernel(self: *ResourceMonitor, timestamp: u64) bool {
        if (self.syscall_fn == null) {
            return false;
        }
        var sysinfo_buf: [56]u8 = undefined; // Enhanced SysInfo is 56 bytes.
        var i: u32 = 0;
        while (i < 56) : (i += 1) {
            sysinfo_buf[i] = 0;
        }
        const sysinfo_ptr = @intFromPtr(&sysinfo_buf);
        const result = self.syscall_fn.?(@intFromEnum(basin_kernel.Syscall.sysinfo), sysinfo_ptr, 0, 0, 0);
        if (result < 0) {
            return false;
        }
        const info = @as(*basin_kernel.SysInfo, @ptrCast(&sysinfo_buf));
        // Use enhanced sysinfo fields: used_memory, process counts.
        const cpu_percent: f64 = @floatFromInt(info.load_avg_1min) / 10.0;
        const clamped_cpu = @min(cpu_percent, 100.0);
        self.update_usage_with_processes(
            clamped_cpu,
            info.used_memory, // Use kernel-calculated used_memory.
            info.total_memory,
            0, // Disk not from kernel yet.
            0, // Disk not from kernel yet.
            info.total_processes,
            info.running_processes,
            info.exited_processes,
            timestamp,
        );
        return true;
    }
};

