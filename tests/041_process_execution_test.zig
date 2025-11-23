//! Process Execution Tests (Phase 3.14)
//! Why: Test process context switching and execution in VM.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const basin_kernel = @import("basin_kernel");
const ProcessContext = basin_kernel.basin_kernel.ProcessContext;
const pe = basin_kernel.basin_kernel.process_execution;

// Test: switch to process context sets VM registers.
test "switch to process context sets VM registers" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    const context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    process_execution.switch_to_process_context(&vm, &context);
    
    // Assert: VM PC must be set to context PC.
    try testing.expect(vm.regs.pc == 0x10000);
    
    // Assert: VM SP register (x2) must be set to context SP.
    try testing.expect(vm.regs.get(2) == 0x400000);
}

// Test: save process context preserves VM state.
test "save process context preserves VM state" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    vm.regs.pc = 0x10010;
    vm.regs.set(2, 0x400010); // SP register
    
    var context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    process_execution.save_process_context(&vm, &context);
    
    // Assert: Context PC must be saved from VM PC.
    try testing.expect(context.pc == 0x10010);
    
    // Assert: Context SP must be saved from VM SP register.
    try testing.expect(context.sp == 0x400010);
}

// Test: execute process runs VM steps.
test "execute process runs VM until halted or max steps" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    var context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    // Execute process with max 100 steps.
    // Note: This will halt quickly since VM memory is empty (invalid instructions).
    const should_continue = pe.execute_process(&vm, &context, 100);
    
    // Assert: Process execution should complete (halted or errored).
    // Note: VM will halt due to invalid instruction, so should_continue should be false.
    try testing.expect(!should_continue or vm.state != .running);
}

// Test: context switching round-trip.
test "context switching round-trip preserves state" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    var context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    // Switch to process context.
    pe.switch_to_process_context(&vm, &context);
    
    // Modify VM state (simulate execution).
    vm.regs.pc = 0x10010;
    vm.regs.set(2, 0x400010);
    
    // Save context back.
    pe.save_process_context(&vm, &context);
    
    // Assert: Context must be updated.
    try testing.expect(context.pc == 0x10010);
    try testing.expect(context.sp == 0x400010);
    
    // Switch to context again.
    pe.switch_to_process_context(&vm, &context);
    
    // Assert: VM must be restored to context state.
    try testing.expect(vm.regs.pc == 0x10010);
    try testing.expect(vm.regs.get(2) == 0x400010);
}

// Test: multiple context switches.
test "multiple context switches work correctly" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    var context1 = ProcessContext.init(0x10000, 0x400000, 0x10000);
    var context2 = ProcessContext.init(0x20000, 0x500000, 0x20000);
    
    // Switch to context1.
    pe.switch_to_process_context(&vm, &context1);
    try testing.expect(vm.regs.pc == 0x10000);
    try testing.expect(vm.regs.get(2) == 0x400000);
    
    // Modify VM state.
    vm.regs.pc = 0x10010;
    vm.regs.set(2, 0x400010);
    
    // Save context1.
    pe.save_process_context(&vm, &context1);
    
    // Switch to context2.
    pe.switch_to_process_context(&vm, &context2);
    try testing.expect(vm.regs.pc == 0x20000);
    try testing.expect(vm.regs.get(2) == 0x500000);
    
    // Modify VM state.
    vm.regs.pc = 0x20010;
    vm.regs.set(2, 0x500010);
    
    // Save context2.
    pe.save_process_context(&vm, &context2);
    
    // Switch back to context1.
    pe.switch_to_process_context(&vm, &context1);
    try testing.expect(vm.regs.pc == 0x10010);
    try testing.expect(vm.regs.get(2) == 0x400010);
    
    // Switch back to context2.
    pe.switch_to_process_context(&vm, &context2);
    try testing.expect(vm.regs.pc == 0x20010);
    try testing.expect(vm.regs.get(2) == 0x500010);
}

