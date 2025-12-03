//! Tests for JIT SLT/SLTU/SLTI/SLTIU instruction support.
//! Why: Verify JIT compiler correctly implements set-less-than instructions.

const std = @import("std");
const testing = std.testing;
const kernel_vm_mod = @import("kernel_vm");
const builtin = @import("builtin");

test "JIT SLT instruction (signed less than)" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Program: SLT x1, x2, x3 (set x1 to 1 if x2 < x3, else 0)
    // x2 = 5, x3 = 10 -> x1 should be 1
    // x2 = 10, x3 = 5 -> x1 should be 0
    const program = [_]u8{
        0x93, 0x01, 0x50, 0x00, // ADDI x2, x0, 5
        0x93, 0x01, 0xA0, 0x00, // ADDI x3, x0, 10
        0x33, 0x20, 0x73, 0x00, // SLT x1, x2, x3 (funct3=0x2)
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM with JIT.
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute program.
    try vm.step_jit(); // ADDI x2, x0, 5
    try vm.step_jit(); // ADDI x3, x0, 10
    try vm.step_jit(); // SLT x1, x2, x3
    
    // Verify result: x1 should be 1 (5 < 10).
    try testing.expect(vm.regs.get(1) == 1);
    try testing.expect(vm.regs.get(2) == 5);
    try testing.expect(vm.regs.get(3) == 10);
}

test "JIT SLTU instruction (unsigned less than)" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Program: SLTU x1, x2, x3 (unsigned comparison)
    // x2 = 0xFFFFFFFFFFFFFFFF (max u64), x3 = 5 -> x1 should be 0
    // x2 = 5, x3 = 10 -> x1 should be 1
    const program = [_]u8{
        0x93, 0x01, 0x50, 0x00, // ADDI x2, x0, 5
        0x93, 0x01, 0xA0, 0x00, // ADDI x3, x0, 10
        0x33, 0x30, 0x73, 0x00, // SLTU x1, x2, x3 (funct3=0x3)
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM with JIT.
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute program.
    try vm.step_jit(); // ADDI x2, x0, 5
    try vm.step_jit(); // ADDI x3, x0, 10
    try vm.step_jit(); // SLTU x1, x2, x3
    
    // Verify result: x1 should be 1 (5 < 10 unsigned).
    try testing.expect(vm.regs.get(1) == 1);
    try testing.expect(vm.regs.get(2) == 5);
    try testing.expect(vm.regs.get(3) == 10);
}

test "JIT SLTI instruction (signed less than immediate)" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Program: SLTI x1, x2, 10 (set x1 to 1 if x2 < 10, else 0)
    // x2 = 5 -> x1 should be 1
    const program = [_]u8{
        0x93, 0x01, 0x50, 0x00, // ADDI x2, x0, 5
        0x13, 0x21, 0xA2, 0x00, // SLTI x1, x2, 10 (funct3=0x2)
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM with JIT.
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute program.
    try vm.step_jit(); // ADDI x2, x0, 5
    try vm.step_jit(); // SLTI x1, x2, 10
    
    // Verify result: x1 should be 1 (5 < 10).
    try testing.expect(vm.regs.get(1) == 1);
    try testing.expect(vm.regs.get(2) == 5);
}

test "JIT SLTIU instruction (unsigned less than immediate)" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Program: SLTIU x1, x2, 10 (unsigned comparison)
    // x2 = 5 -> x1 should be 1
    const program = [_]u8{
        0x93, 0x01, 0x50, 0x00, // ADDI x2, x0, 5
        0x13, 0x31, 0xA2, 0x00, // SLTIU x1, x2, 10 (funct3=0x3)
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM with JIT.
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute program.
    try vm.step_jit(); // ADDI x2, x0, 5
    try vm.step_jit(); // SLTIU x1, x2, 10
    
    // Verify result: x1 should be 1 (5 < 10 unsigned).
    try testing.expect(vm.regs.get(1) == 1);
    try testing.expect(vm.regs.get(2) == 5);
}

