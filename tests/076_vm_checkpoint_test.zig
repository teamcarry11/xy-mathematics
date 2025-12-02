//! Tests for VM Checkpoint/Restore System
//!
//! Objective: Verify checkpoint/restore works correctly.
//! Why: Ensure checkpoint/restore accurately saves and restores VM state.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM checkpoint initialization" {
    const checkpoint = kernel_vm.checkpoint.VMCheckpoint.init();
    try testing.expect(checkpoint.checkpoint_count == 0);
}

test "VM checkpoint create" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    program[0] = 0x12;
    program[1] = 0x34;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    vm.regs.set(5, 0x12345678);
    const created = try vm.checkpoint.create_checkpoint(&vm, 0);
    try testing.expect(created == true);
    try testing.expect(vm.checkpoint.checkpoint_count == 1);
    try testing.expect(vm.checkpoint.has_checkpoint(0) == true);
}

test "VM checkpoint restore" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    program[0] = 0x12;
    program[1] = 0x34;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    vm.regs.set(5, 0x12345678);
    _ = try vm.checkpoint.create_checkpoint(&vm, 0);
    vm.regs.set(5, 0x87654321);
    vm.regs.pc = 0x80000004;
    const restored = try vm.checkpoint.restore_checkpoint(&vm, 0);
    try testing.expect(restored == true);
    try testing.expect(vm.regs.get(5) == 0x12345678);
    try testing.expect(vm.regs.pc == 0x80000000);
}

test "VM checkpoint restore memory" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    program[0] = 0x12;
    program[1] = 0x34;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    _ = try vm.checkpoint.create_checkpoint(&vm, 0);
    vm.memory[0] = 0x99;
    vm.memory[1] = 0x88;
    const restored = try vm.checkpoint.restore_checkpoint(&vm, 0);
    try testing.expect(restored == true);
    try testing.expect(vm.memory[0] == 0x12);
    try testing.expect(vm.memory[1] == 0x34);
}

test "VM checkpoint delete" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    _ = try vm.checkpoint.create_checkpoint(&vm, 0);
    try testing.expect(vm.checkpoint.has_checkpoint(0) == true);
    const deleted = vm.checkpoint.delete_checkpoint(0);
    try testing.expect(deleted == true);
    try testing.expect(vm.checkpoint.has_checkpoint(0) == false);
    try testing.expect(vm.checkpoint.checkpoint_count == 0);
}

test "VM checkpoint multiple" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    vm.regs.set(5, 0x11111111);
    _ = try vm.checkpoint.create_checkpoint(&vm, 0);
    vm.regs.set(5, 0x22222222);
    _ = try vm.checkpoint.create_checkpoint(&vm, 1);
    try testing.expect(vm.checkpoint.checkpoint_count == 2);
    const restored = try vm.checkpoint.restore_checkpoint(&vm, 0);
    try testing.expect(restored == true);
    try testing.expect(vm.regs.get(5) == 0x11111111);
    const restored2 = try vm.checkpoint.restore_checkpoint(&vm, 1);
    try testing.expect(restored2 == true);
    try testing.expect(vm.regs.get(5) == 0x22222222);
}

test "VM checkpoint invalid id" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    const created = vm.checkpoint.create_checkpoint(&vm, 100);
    try testing.expectError(kernel_vm_mod.VMError.invalid_memory_access, created);
}

test "VM checkpoint restore invalid" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    const restored = vm.checkpoint.restore_checkpoint(&vm, 0);
    try testing.expectError(kernel_vm_mod.VMError.invalid_memory_access, restored);
}

