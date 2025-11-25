//! Tests for VM execution flow tracking.
//! Why: Verify execution flow tracking works correctly.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const vm_mod = kernel_vm;
const execution_flow_mod = kernel_vm.execution_flow;

test "VM execution flow initialization" {
    const flow = execution_flow_mod.VMExecutionFlow.init();
    try testing.expect(flow.total_instructions == 0);
    try testing.expect(flow.unique_pcs_len == 0);
    try testing.expect(flow.pc_history_len == 0);
}

test "VM execution flow record PC" {
    var flow = execution_flow_mod.VMExecutionFlow.init();
    flow.record_pc(0x80000000);
    try testing.expect(flow.total_instructions == 1);
    try testing.expect(flow.unique_pcs_len == 1);
    try testing.expect(flow.pc_history_len == 1);
    try testing.expect(flow.unique_pcs[0].pc == 0x80000000);
    try testing.expect(flow.unique_pcs[0].execution_count == 1);
}

test "VM execution flow multiple PCs" {
    var flow = execution_flow_mod.VMExecutionFlow.init();
    flow.record_pc(0x80000000);
    flow.record_pc(0x80000000); // Same PC again
    flow.record_pc(0x80000004); // Different PC
    try testing.expect(flow.total_instructions == 3);
    try testing.expect(flow.unique_pcs_len == 2);
    try testing.expect(flow.unique_pcs[0].execution_count == 2);
    try testing.expect(flow.unique_pcs[1].execution_count == 1);
}

test "VM execution flow integration" {
    // Simple program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM.
    var vm: vm_mod.VM = undefined;
    vm.init(&program, 0x80000000);
    
    // Verify execution flow is initialized.
    try testing.expect(vm.execution_flow.total_instructions == 0);
    
    // Execute a step to trigger flow tracking.
    vm.state = .running;
    try vm.step();
    
    // Verify execution flow is tracked.
    try testing.expect(vm.execution_flow.total_instructions > 0);
}

test "VM execution flow print" {
    var flow = execution_flow_mod.VMExecutionFlow.init();
    flow.record_pc(0x80000000);
    flow.record_pc(0x80000004);
    
    // Verify stats can be printed.
    flow.print_stats();
}

test "VM execution flow reset" {
    var flow = execution_flow_mod.VMExecutionFlow.init();
    flow.record_pc(0x80000000);
    flow.record_pc(0x80000004);
    
    flow.reset();
    
    try testing.expect(flow.total_instructions == 0);
    try testing.expect(flow.unique_pcs_len == 0);
    try testing.expect(flow.pc_history_len == 0);
}

