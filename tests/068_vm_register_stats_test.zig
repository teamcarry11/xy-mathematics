//! Tests for VM Register Usage Statistics Tracking System
//!
//! Objective: Verify register read/write tracking works correctly.
//! Why: Ensure register statistics accurately track register usage patterns.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM register stats initialization" {
    const stats = kernel_vm.register_stats.VMRegisterStats.init();
    try testing.expect(stats.total_reads == 0);
    try testing.expect(stats.total_writes == 0);
    var i: u32 = 0;
    while (i < kernel_vm.register_stats.NUM_REGISTERS) : (i += 1) {
        try testing.expect(stats.entries[i].read_count == 0);
        try testing.expect(stats.entries[i].write_count == 0);
        try testing.expect(stats.entries[i].register_num == i);
    }
}

test "VM register stats record read" {
    var stats = kernel_vm.register_stats.VMRegisterStats.init();
    stats.record_read(5);
    try testing.expect(stats.total_reads == 1);
    try testing.expect(stats.entries[5].read_count == 1);
    try testing.expect(stats.entries[5].write_count == 0);
    stats.record_read(5);
    try testing.expect(stats.total_reads == 2);
    try testing.expect(stats.entries[5].read_count == 2);
}

test "VM register stats record write" {
    var stats = kernel_vm.register_stats.VMRegisterStats.init();
    stats.record_write(10);
    try testing.expect(stats.total_writes == 1);
    try testing.expect(stats.entries[10].read_count == 0);
    try testing.expect(stats.entries[10].write_count == 1);
    stats.record_write(10);
    try testing.expect(stats.total_writes == 2);
    try testing.expect(stats.entries[10].write_count == 2);
}

test "VM register stats multiple registers" {
    var stats = kernel_vm.register_stats.VMRegisterStats.init();
    stats.record_read(1);
    stats.record_read(2);
    stats.record_write(1);
    stats.record_write(3);
    try testing.expect(stats.total_reads == 2);
    try testing.expect(stats.total_writes == 2);
    try testing.expect(stats.entries[1].read_count == 1);
    try testing.expect(stats.entries[1].write_count == 1);
    try testing.expect(stats.entries[2].read_count == 1);
    try testing.expect(stats.entries[2].write_count == 0);
    try testing.expect(stats.entries[3].read_count == 0);
    try testing.expect(stats.entries[3].write_count == 1);
}

test "VM register stats reset" {
    var stats = kernel_vm.register_stats.VMRegisterStats.init();
    stats.record_read(5);
    stats.record_write(10);
    try testing.expect(stats.total_reads == 1);
    try testing.expect(stats.total_writes == 1);
    stats.reset();
    try testing.expect(stats.total_reads == 0);
    try testing.expect(stats.total_writes == 0);
    try testing.expect(stats.entries[5].read_count == 0);
    try testing.expect(stats.entries[10].write_count == 0);
}

test "VM register stats integration" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    try testing.expect(vm.register_stats.total_reads == 0);
    try testing.expect(vm.register_stats.total_writes == 0);
    vm.register_stats.record_read(1);
    vm.register_stats.record_write(2);
    try testing.expect(vm.register_stats.total_reads == 1);
    try testing.expect(vm.register_stats.total_writes == 1);
}

