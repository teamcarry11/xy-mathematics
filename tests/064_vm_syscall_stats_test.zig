//! Tests for VM syscall execution statistics tracking.
//! Why: Verify syscall statistics tracking works correctly.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const vm_mod = kernel_vm;
const syscall_stats_mod = kernel_vm.syscall_stats;

test "VM syscall stats initialization" {
    const stats = syscall_stats_mod.VMSyscallStats.init();
    try testing.expect(stats.total_syscalls == 0);
    try testing.expect(stats.entries_len == 0);
}

test "VM syscall stats record syscall" {
    var stats = syscall_stats_mod.VMSyscallStats.init();
    stats.record_syscall(0); // spawn syscall
    try testing.expect(stats.total_syscalls == 1);
    try testing.expect(stats.entries_len == 1);
    try testing.expect(stats.entries[0].syscall_number == 0);
    try testing.expect(stats.entries[0].execution_count == 1);
}

test "VM syscall stats multiple syscalls" {
    var stats = syscall_stats_mod.VMSyscallStats.init();
    stats.record_syscall(0); // spawn
    stats.record_syscall(0); // spawn again
    stats.record_syscall(4); // map
    try testing.expect(stats.total_syscalls == 3);
    try testing.expect(stats.entries_len == 2);
    try testing.expect(stats.entries[0].execution_count == 2);
    try testing.expect(stats.entries[1].execution_count == 1);
}

test "VM syscall stats print" {
    var stats = syscall_stats_mod.VMSyscallStats.init();
    stats.record_syscall(0); // spawn
    stats.record_syscall(4); // map
    
    // Verify stats can be printed.
    stats.print_stats();
}

test "VM syscall stats reset" {
    var stats = syscall_stats_mod.VMSyscallStats.init();
    stats.record_syscall(0);
    stats.record_syscall(4);
    
    stats.reset();
    
    try testing.expect(stats.total_syscalls == 0);
    try testing.expect(stats.entries[0].execution_count == 0);
    try testing.expect(stats.entries[1].execution_count == 0);
}

