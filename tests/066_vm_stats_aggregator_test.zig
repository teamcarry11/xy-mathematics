//! Tests for VM statistics aggregator.
//! Why: Verify statistics aggregation works correctly.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const vm_mod = kernel_vm;
const stats_aggregator_mod = kernel_vm.stats_aggregator;

test "VM stats aggregator initialization" {
    // Simple program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM.
    var vm: vm_mod.VM = undefined;
    vm.init(&program, 0x80000000);
    
    // Create aggregator.
    const aggregator = stats_aggregator_mod.VMStatsAggregator.init(&vm);
    try testing.expect(aggregator.vm == &vm);
}

test "VM stats aggregator print all stats" {
    // Simple program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM.
    var vm: vm_mod.VM = undefined;
    vm.init(&program, 0x80000000);
    
    // Execute a step to generate statistics.
    vm.state = .running;
    try vm.step();
    
    // Create aggregator and print stats.
    var aggregator = stats_aggregator_mod.VMStatsAggregator.init(&vm);
    aggregator.print_all_stats();
}

test "VM stats aggregator reset all stats" {
    // Simple program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM.
    var vm: vm_mod.VM = undefined;
    vm.init(&program, 0x80000000);
    
    // Execute a step to generate statistics.
    vm.state = .running;
    try vm.step();
    
    // Verify statistics exist.
    try testing.expect(vm.performance.instructions_executed > 0);
    
    // Create aggregator and reset stats.
    var aggregator = stats_aggregator_mod.VMStatsAggregator.init(&vm);
    aggregator.reset_all_stats();
    
    // Verify statistics are reset.
    try testing.expect(vm.performance.instructions_executed == 0);
    try testing.expect(vm.instruction_stats.total_instructions == 0);
    try testing.expect(vm.execution_flow.total_instructions == 0);
}

