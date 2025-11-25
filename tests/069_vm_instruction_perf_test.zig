//! Tests for VM Instruction Performance Profiling System
//!
//! Objective: Verify instruction performance profiling works correctly.
//! Why: Ensure performance profiling accurately tracks execution time per instruction type.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM instruction perf initialization" {
    const perf = kernel_vm.instruction_perf.VMInstructionPerf.init();
    try testing.expect(perf.total_profiling_time_ns == 0);
    try testing.expect(perf.entries_len == 0);
}

test "VM instruction perf record execution" {
    var perf = kernel_vm.instruction_perf.VMInstructionPerf.init();
    perf.record_execution(5, 100);
    try testing.expect(perf.total_profiling_time_ns == 100);
    try testing.expect(perf.entries_len == 1);
    try testing.expect(perf.entries[0].opcode == 5);
    try testing.expect(perf.entries[0].total_time_ns == 100);
    try testing.expect(perf.entries[0].execution_count == 1);
    perf.record_execution(5, 200);
    try testing.expect(perf.total_profiling_time_ns == 300);
    try testing.expect(perf.entries[0].total_time_ns == 300);
    try testing.expect(perf.entries[0].execution_count == 2);
}

test "VM instruction perf multiple opcodes" {
    var perf = kernel_vm.instruction_perf.VMInstructionPerf.init();
    perf.record_execution(1, 50);
    perf.record_execution(2, 100);
    perf.record_execution(1, 75);
    try testing.expect(perf.total_profiling_time_ns == 225);
    try testing.expect(perf.entries_len == 2);
    try testing.expect(perf.entries[0].opcode == 1);
    try testing.expect(perf.entries[0].total_time_ns == 125);
    try testing.expect(perf.entries[0].execution_count == 2);
    try testing.expect(perf.entries[1].opcode == 2);
    try testing.expect(perf.entries[1].total_time_ns == 100);
    try testing.expect(perf.entries[1].execution_count == 1);
}

test "VM instruction perf reset" {
    var perf = kernel_vm.instruction_perf.VMInstructionPerf.init();
    perf.record_execution(5, 100);
    try testing.expect(perf.total_profiling_time_ns == 100);
    perf.reset();
    try testing.expect(perf.total_profiling_time_ns == 0);
    try testing.expect(perf.entries_len == 0);
}

test "VM instruction perf integration" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    try testing.expect(vm.instruction_perf.total_profiling_time_ns == 0);
    vm.instruction_perf.record_execution(10, 50);
    try testing.expect(vm.instruction_perf.total_profiling_time_ns == 50);
}

