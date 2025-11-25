//! Tests for VM State Inspection System
//!
//! Objective: Verify state inspection (registers, memory, stack) works correctly.
//! Why: Ensure state inspection accurately reads VM state for debugging.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM state inspection initialization" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var inspector = kernel_vm_mod.state_inspection.VMStateInspector.init(&vm);
    const pc = inspector.get_pc();
    try testing.expect(pc == 0x80000000);
}

test "VM state inspection get register" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    vm.regs.set(5, 0x12345678);
    var inspector = kernel_vm_mod.state_inspection.VMStateInspector.init(&vm);
    const reg5 = inspector.get_register(5);
    try testing.expect(reg5 == 0x12345678);
}

test "VM state inspection get register state" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    vm.regs.set(1, 0x100);
    vm.regs.set(2, 0x200);
    var inspector = kernel_vm_mod.state_inspection.VMStateInspector.init(&vm);
    const state = inspector.get_register_state();
    try testing.expect(state.pc == 0x80000000);
    try testing.expect(state.regs[1] == 0x100);
    try testing.expect(state.regs[2] == 0x200);
}

test "VM state inspection dump memory" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    program[0] = 0x12;
    program[1] = 0x34;
    program[2] = 0x56;
    program[3] = 0x78;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var inspector = kernel_vm_mod.state_inspection.VMStateInspector.init(&vm);
    const dump = inspector.dump_memory(0, 4);
    try testing.expect(dump != null);
    if (dump) |d| {
        try testing.expect(d.address == 0);
        try testing.expect(d.size == 4);
        try testing.expect(d.data[0] == 0x12);
        try testing.expect(d.data[1] == 0x34);
        try testing.expect(d.data[2] == 0x56);
        try testing.expect(d.data[3] == 0x78);
    }
}

test "VM state inspection read memory u64" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    program[0] = 0x78;
    program[1] = 0x56;
    program[2] = 0x34;
    program[3] = 0x12;
    program[4] = 0x00;
    program[5] = 0x00;
    program[6] = 0x00;
    program[7] = 0x00;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var inspector = kernel_vm_mod.state_inspection.VMStateInspector.init(&vm);
    const value = inspector.read_memory_u64(0);
    try testing.expect(value != null);
    if (value) |v| {
        try testing.expect(v == 0x12345678);
    }
}

test "VM state inspection read memory u32" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    program[0] = 0x78;
    program[1] = 0x56;
    program[2] = 0x34;
    program[3] = 0x12;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var inspector = kernel_vm_mod.state_inspection.VMStateInspector.init(&vm);
    const value = inspector.read_memory_u32(0);
    try testing.expect(value != null);
    if (value) |v| {
        try testing.expect(v == 0x12345678);
    }
}

test "VM state inspection dump stack" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    vm.regs.set(2, 0x1000);
    var inspector = kernel_vm_mod.state_inspection.VMStateInspector.init(&vm);
    const stack_pointer = inspector.get_register(2);
    const dump = inspector.dump_stack(stack_pointer);
    try testing.expect(dump != null);
}

