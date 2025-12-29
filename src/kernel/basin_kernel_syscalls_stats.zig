//! Basin Kernel Stats Syscalls
//! Why: Statistics and resource management syscalls (kernel_get_stats, health_check, get_resource_usage, set_resource_limit).
//! Grain Style: Explicit types, static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

// Import types
const types = @import("basin_kernel_types.zig");
const BasinError = types.BasinError;
const SyscallResult = types.SyscallResult;
const ResourceUsage = types.ResourceUsage;
const MAX_PROCESSES = types.MAX_PROCESSES;
const Process = types.Process;

// Import core
const core = @import("basin_kernel_core.zig");
const BasinKernel = core.BasinKernel;

/// Stats syscall handlers for BasinKernel.
/// Why: Extract stats syscalls to separate module for organization.
pub const StatsSyscalls = struct {
    /// Get unified kernel statistics snapshot.
    /// Why: Provide comprehensive system statistics for monitoring and debugging.
    /// Contract: stats_ptr must be valid pointer (checked by integration layer).
    /// Note: Integration layer will write KernelStatsSnapshot structure to stats_ptr.
    pub fn syscall_kernel_get_stats(
        self: *BasinKernel,
        stats_ptr: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Stats pointer must be valid (non-zero, within VM memory).
        if (stats_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (stats_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats pointer exceeds VM memory
        }
        
        // Assert: KernelStatsSnapshot structure must fit within VM memory.
        // KernelStatsSnapshot size: 7 pointers (8 bytes each) + 2 u64 + 1 f64 = 7*8 + 2*8 + 8 = 80 bytes
        const KERNEL_STATS_SIZE: u64 = 80;
        if (stats_ptr + KERNEL_STATS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats structure exceeds VM memory
        }
        
        // Note: This syscall is handled by integration layer (needs VM access to write snapshot).
        // This stub validates the pointer but integration layer will write the KernelStatsSnapshot structure.
        // Contract: stats_ptr must be valid (checked above).
        
        // Get snapshot for validation (integration layer will use this).
        _ = self.get_kernel_stats_snapshot();
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Health check syscall.
    /// Why: Provide overall system health status for monitoring.
    /// Returns: Health status (0 = healthy, 1 = degraded, 2 = unhealthy).
    pub fn syscall_health_check(
        self: *BasinKernel,
        _arg1: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg1;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Get kernel statistics snapshot.
        const snapshot = self.get_kernel_stats_snapshot();
        
        // Calculate health status based on health score.
        // Health score: 0.0 to 100.0 (higher is better).
        // Status: 0 = healthy (>= 80.0), 1 = degraded (50.0-79.9), 2 = unhealthy (< 50.0)
        var health_status: u64 = 0;
        if (snapshot.health_score < 50.0) {
            health_status = 2; // Unhealthy
        } else if (snapshot.health_score < 80.0) {
            health_status = 1; // Degraded
        } else {
            health_status = 0; // Healthy
        }
        
        // Assert: Health status must be valid (0, 1, or 2).
        Debug.kassert(health_status <= 2, "Health status out of range", .{});
        
        const result = SyscallResult.ok(health_status);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get resource usage syscall.
    /// Why: Expose per-process resource usage (CPU, memory, network, file descriptors).
    /// Returns: Resource usage information for the specified process.
    /// Arguments:
    ///   - arg1: Process ID (pid)
    ///   - arg2: Resource usage pointer (ResourceUsage struct in VM memory)
    ///   - arg3: Unused
    ///   - arg4: Unused
    pub fn syscall_get_resource_usage(
        self: *BasinKernel,
        pid: u64,
        usage_ptr: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Process ID must be valid (non-zero).
        if (pid == 0) {
            return BasinError.invalid_argument; // Invalid process ID
        }
        
        // Assert: Usage pointer must be valid (non-zero, within VM memory).
        if (usage_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024;
        if (usage_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Pointer out of bounds
        }
        
        // Calculate ResourceUsage struct size (8 + 8 + 8 + 8 + 8 + 4 + 4 = 48 bytes).
        const RESOURCE_USAGE_SIZE: u64 = 48;
        if (usage_ptr + RESOURCE_USAGE_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Buffer extends beyond VM memory
        }
        
        // Find process in process table.
        var found: ?u32 = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == pid) {
                found = @intCast(i);
                break;
            }
        }
        
        // Assert: Process must exist.
        if (found == null) {
            return BasinError.process_not_found; // Process not found
        }
        
        const process_idx = found.?;
        const process = &self.processes[process_idx];
        
        // Count open file descriptors for this process.
        var file_descriptor_count: u32 = 0;
        for (self.handles) |handle| {
            if (handle.allocated and handle.owner_process_id == @intCast(pid)) {
                file_descriptor_count += 1;
            }
        }
        
        // Count open network connections for this process.
        // Note: This is a simplified count - in a full implementation, we would
        // track which sockets belong to which process.
        var connection_count: u32 = 0;
        // Stub: Connection counting would iterate through TCP/UDP socket managers
        // and count sockets owned by this process. For now, we use the process's
        // open_connections field which should be updated by socket operations.
        connection_count = process.open_connections;
        
        // Create ResourceUsage struct.
        const usage = ResourceUsage{
            .pid = @intCast(pid),
            .cpu_time_ns = process.cpu_time_ns,
            .memory_used = process.memory_used,
            .network_bytes_sent = process.network_bytes_sent,
            .network_bytes_received = process.network_bytes_received,
            .open_file_descriptors = file_descriptor_count,
            .open_connections = connection_count,
        };
        
        // Stub: In a real VM, this would write the ResourceUsage struct to VM memory at usage_ptr.
        _ = usage;
        
        // Assert: Usage must be valid.
        Debug.kassert(usage.pid == @intCast(pid), "Usage PID mismatch", .{});
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set resource limit for a process.
    /// Why: Configure per-process resource limits to prevent resource exhaustion.
    /// Contract: pid must be valid, limit_type must be valid, limit_value must be reasonable.
    ///   - arg1: Process ID (pid)
    ///   - arg2: Limit type (0 = CPU time, 1 = memory, 2 = file descriptors, 3 = connections)
    ///   - arg3: Limit value (CPU time in nanoseconds, memory in bytes, counts for others)
    ///   - arg4: Unused
    pub fn syscall_set_resource_limit(
        self: *BasinKernel,
        pid: u64,
        limit_type: u64,
        limit_value: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: Process ID must be valid (non-zero).
        if (pid == 0) {
            return BasinError.invalid_argument; // Invalid process ID
        }
        
        // Assert: Limit type must be valid (0-3).
        if (limit_type > 3) {
            return BasinError.invalid_argument; // Invalid limit type
        }
        
        // Find process in process table.
        var found: ?u32 = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == pid) {
                found = @intCast(i);
                break;
            }
        }
        
        // Assert: Process must exist.
        if (found == null) {
            return BasinError.process_not_found; // Process not found
        }
        
        const process_idx = found.?;
        const process = &self.processes[process_idx];
        
        // Check permission: Only root or the process itself can set limits.
        const current_pid = self.scheduler.get_current();
        if (current_pid != pid and !self.current_user.is_root()) {
            return BasinError.permission_denied; // Permission denied
        }
        
        // Set limit based on type.
        switch (limit_type) {
            0 => {
                // CPU time limit (nanoseconds).
                process.max_cpu_time_ns = limit_value;
            },
            1 => {
                // Memory limit (bytes).
                process.max_memory_bytes = limit_value;
            },
            2 => {
                // File descriptor limit (count).
                if (limit_value > 0xFFFFFFFF) {
                    return BasinError.invalid_argument; // Limit value too large
                }
                process.max_file_descriptors = @as(u32, @truncate(limit_value));
            },
            3 => {
                // Network connection limit (count).
                if (limit_value > 0xFFFFFFFF) {
                    return BasinError.invalid_argument; // Limit value too large
                }
                process.max_connections = @as(u32, @truncate(limit_value));
            },
            else => {
                return BasinError.invalid_argument; // Invalid limit type
            },
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
};
