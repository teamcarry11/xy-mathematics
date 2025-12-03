//! Tests for enhanced system information syscall.
//! Why: Verify kernel provides enhanced system information for Grain OS integration.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");

test "enhanced sysinfo structure layout" {
    // Verify SysInfo structure size and layout.
    const info = basin_kernel.SysInfo.init();
    
    // Structure should be: total_memory(8) + available_memory(8) + used_memory(8) +
    //                      cpu_cores(4) + padding(4) + uptime_ns(8) + load_avg_1min(4) +
    //                      total_processes(4) + running_processes(4) + exited_processes(4) = 56 bytes
    try testing.expect(@sizeOf(basin_kernel.SysInfo) == 56);
    try testing.expect(info.total_memory == 0);
    try testing.expect(info.available_memory == 0);
    try testing.expect(info.used_memory == 0);
    try testing.expect(info.cpu_cores == 0);
    try testing.expect(info.uptime_ns == 0);
    try testing.expect(info.load_avg_1min == 0);
    try testing.expect(info.total_processes == 0);
    try testing.expect(info.running_processes == 0);
    try testing.expect(info.exited_processes == 0);
}

test "enhanced sysinfo initialization" {
    // Test SysInfo initialization with new fields.
    const info = basin_kernel.SysInfo.init();
    
    // Verify all fields are initialized to zero.
    try testing.expect(info.total_memory == 0);
    try testing.expect(info.available_memory == 0);
    try testing.expect(info.used_memory == 0);
    try testing.expect(info.cpu_cores == 0);
    try testing.expect(info.uptime_ns == 0);
    try testing.expect(info.load_avg_1min == 0);
    try testing.expect(info.total_processes == 0);
    try testing.expect(info.running_processes == 0);
    try testing.expect(info.exited_processes == 0);
}

