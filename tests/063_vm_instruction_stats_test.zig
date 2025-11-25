//! Tests for VM instruction execution statistics tracking.
//! Why: Verify instruction statistics tracking works correctly.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const vm_mod = kernel_vm;
const instruction_stats_mod = kernel_vm.instruction_stats;

test "VM instruction stats initialization" {
    const stats = instruction_stats_mod.VMInstructionStats.init();
    try testing.expect(stats.total_instructions == 0);
    try testing.expect(stats.entries_len == 0);
}

test "VM instruction stats record instruction" {
    var stats = instruction_stats_mod.VMInstructionStats.init();
    stats.record_instruction(0x13); // ADDI opcode
    try testing.expect(stats.total_instructions == 1);
    try testing.expect(stats.entries_len == 1);
    try testing.expect(stats.entries[0].opcode == 0x13);
    try testing.expect(stats.entries[0].execution_count == 1);
}

test "VM instruction stats multiple instructions" {
    var stats = instruction_stats_mod.VMInstructionStats.init();
    stats.record_instruction(0x13); // ADDI
    stats.record_instruction(0x13); // ADDI again
    stats.record_instruction(0x33); // ADD
    try testing.expect(stats.total_instructions == 3);
    try testing.expect(stats.entries_len == 2);
    try testing.expect(stats.entries[0].execution_count == 2);
    try testing.expect(stats.entries[1].execution_count == 1);
}

test "VM instruction stats integration" {
    // Simple program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42 (opcode 0x13)
        0x67, 0x80, 0x00, 0x00, // RET (JALR, opcode 0x67)
    };
    
    // Initialize VM.
    var vm: vm_mod.VM = undefined;
    vm.init(&program, 0x80000000);
    
    // Verify instruction stats are initialized.
    try testing.expect(vm.instruction_stats.total_instructions == 0);
    
    // Execute a step to trigger instruction tracking.
    vm.state = .running;
    try vm.step();
    
    // Verify instruction stats are tracked.
    try testing.expect(vm.instruction_stats.total_instructions > 0);
}

test "VM instruction stats print" {
    var stats = instruction_stats_mod.VMInstructionStats.init();
    stats.record_instruction(0x13); // ADDI
    stats.record_instruction(0x33); // ADD
    
    // Verify stats can be printed.
    stats.print_stats();
}

test "VM instruction stats reset" {
    var stats = instruction_stats_mod.VMInstructionStats.init();
    stats.record_instruction(0x13);
    stats.record_instruction(0x33);
    
    stats.reset();
    
    try testing.expect(stats.total_instructions == 0);
    try testing.expect(stats.entries[0].execution_count == 0);
    try testing.expect(stats.entries[1].execution_count == 0);
}


