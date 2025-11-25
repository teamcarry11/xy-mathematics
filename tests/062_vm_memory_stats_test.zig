//! Tests for VM memory statistics tracking.
//! Why: Verify memory statistics tracking works correctly.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const vm_mod = kernel_vm;
const memory_stats_mod = kernel_vm.memory_stats;

test "VM memory stats initialization" {
    const stats = memory_stats_mod.VMMemoryStats.init(8 * 1024 * 1024);
    try testing.expect(stats.total_memory_bytes == 8 * 1024 * 1024);
    try testing.expect(stats.used_memory_bytes == 0);
    try testing.expect(stats.total_reads == 0);
    try testing.expect(stats.total_writes == 0);
    try testing.expect(stats.regions_len == 0);
}

test "VM memory stats record read" {
    var stats = memory_stats_mod.VMMemoryStats.init(8 * 1024 * 1024);
    stats.record_read(0x80000000, 8);
    try testing.expect(stats.total_reads == 1);
    try testing.expect(stats.total_bytes_read == 8);
}

test "VM memory stats record write" {
    var stats = memory_stats_mod.VMMemoryStats.init(8 * 1024 * 1024);
    stats.record_write(0x80000000, 8);
    try testing.expect(stats.total_writes == 1);
    try testing.expect(stats.total_bytes_written == 8);
}

test "VM memory stats add region" {
    var stats = memory_stats_mod.VMMemoryStats.init(8 * 1024 * 1024);
    stats.add_region(0x80000000, 0x80001000);
    try testing.expect(stats.regions_len == 1);
    try testing.expect(stats.regions[0].start_addr == 0x80000000);
    try testing.expect(stats.regions[0].end_addr == 0x80001000);
}

test "VM memory stats region tracking" {
    var stats = memory_stats_mod.VMMemoryStats.init(8 * 1024 * 1024);
    stats.add_region(0x80000000, 0x80001000);
    stats.record_read(0x80000004, 8);
    stats.record_write(0x80000008, 8);
    try testing.expect(stats.regions[0].read_count == 1);
    try testing.expect(stats.regions[0].write_count == 1);
    try testing.expect(stats.regions[0].total_bytes_read == 8);
    try testing.expect(stats.regions[0].total_bytes_written == 8);
}

test "VM memory stats integration" {
    // Simple program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM.
    var vm: vm_mod.VM = undefined;
    vm.init(&program, 0x80000000);
    
    // Verify memory stats are initialized.
    try testing.expect(vm.memory_stats.total_memory_bytes > 0);
    try testing.expect(vm.memory_stats.regions_len > 0);
    
    // Execute a step to trigger memory access.
    vm.state = .running;
    try vm.step();
    
    // Verify memory stats are tracked.
    try testing.expect(vm.memory_stats.total_reads > 0 or vm.memory_stats.total_writes > 0);
}

test "VM memory stats print" {
    var stats = memory_stats_mod.VMMemoryStats.init(8 * 1024 * 1024);
    stats.add_region(0x80000000, 0x80001000);
    stats.record_read(0x80000004, 8);
    stats.record_write(0x80000008, 8);
    stats.update_used_memory(1024 * 1024);
    
    // Verify stats can be printed.
    stats.print_stats();
}

test "VM memory stats reset" {
    var stats = memory_stats_mod.VMMemoryStats.init(8 * 1024 * 1024);
    stats.add_region(0x80000000, 0x80001000);
    stats.record_read(0x80000004, 8);
    stats.record_write(0x80000008, 8);
    stats.update_used_memory(1024 * 1024);
    
    stats.reset();
    
    try testing.expect(stats.total_reads == 0);
    try testing.expect(stats.total_writes == 0);
    try testing.expect(stats.total_bytes_read == 0);
    try testing.expect(stats.total_bytes_written == 0);
    try testing.expect(stats.regions[0].read_count == 0);
    try testing.expect(stats.regions[0].write_count == 0);
}

