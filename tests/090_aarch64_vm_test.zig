//! AArch64 VM Tests
//! Why: Test AArch64 virtual machine functionality.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const vm_aarch64 = @import("vm_aarch64");
const AArch64VM = vm_aarch64.AArch64VM;
const AArch64VMError = vm_aarch64.AArch64VMError;

// Test: AArch64 VM initialization.
test "aarch64 vm init" {
    var vm = AArch64VM.init();
    
    // VM should be initialized in halted state.
    try testing.expect(vm.state == .halted);
    try testing.expect(vm.memory_size == 8 * 1024 * 1024); // 8MB
    try testing.expect(vm.regs.pc == 0);
    try testing.expect(vm.regs.sp == 0);
}

// Test: AArch64 register file operations.
test "aarch64 register file" {
    var vm = AArch64VM.init();
    
    // Set and get register x0.
    vm.regs.set(0, 0x1234567890ABCDEF);
    const value = vm.regs.get(0);
    try testing.expect(value == 0x1234567890ABCDEF);
    
    // Set and get register x1.
    vm.regs.set(1, 0xFEDCBA0987654321);
    const value1 = vm.regs.get(1);
    try testing.expect(value1 == 0xFEDCBA0987654321);
    
    // Set and get stack pointer.
    vm.regs.set_sp(0x80000000);
    const sp = vm.regs.get_sp();
    try testing.expect(sp == 0x80000000);
    
    // Set and get program counter.
    vm.regs.set_pc(0x400000);
    const pc = vm.regs.get_pc();
    try testing.expect(pc == 0x400000);
}

// Test: AArch64 memory read/write.
test "aarch64 memory read write" {
    var vm = AArch64VM.init();
    
    // Write and read 64-bit value.
    const addr: u64 = 0x1000;
    const value: u64 = 0x1234567890ABCDEF;
    try vm.write64(addr, value);
    const read_value = try vm.read64(addr);
    try testing.expect(read_value == value);
}

// Test: AArch64 memory alignment.
test "aarch64 memory alignment" {
    var vm = AArch64VM.init();
    
    // Try to read from unaligned address (should fail).
    const unaligned_addr: u64 = 0x1001; // Not 8-byte aligned
    const result = vm.read64(unaligned_addr);
    try testing.expectError(AArch64VMError.unaligned_memory_access, result);
    
    // Try to write to unaligned address (should fail).
    const result2 = vm.write64(unaligned_addr, 0x1234567890ABCDEF);
    try testing.expectError(AArch64VMError.unaligned_memory_access, result2);
}

// Test: AArch64 instruction read.
test "aarch64 instruction read" {
    var vm = AArch64VM.init();
    
    // Write instruction at aligned address.
    const addr: u64 = 0x1000;
    const instruction: u32 = 0xD2800000; // MOV x0, #0 (example AArch64 instruction)
    
    // Write instruction bytes (little-endian).
    const bytes = std.mem.asBytes(&instruction);
    std.mem.copyForwards(u8, vm.memory[@intCast(addr)..][0..4], bytes);
    
    // Read instruction.
    const read_instruction = try vm.read_instruction(addr);
    try testing.expect(read_instruction == instruction);
}

// Test: AArch64 VM start/halt.
test "aarch64 vm start halt" {
    var vm = AArch64VM.init();
    
    // VM should start in halted state.
    try testing.expect(vm.state == .halted);
    
    // Set PC to valid address.
    vm.regs.set_pc(0x1000);
    
    // Start VM.
    vm.start();
    try testing.expect(vm.state == .running);
    
    // Halt VM.
    vm.halt();
    try testing.expect(vm.state == .halted);
}

// Test: AArch64 architecture configuration.
test "aarch64 arch config" {
    var vm = AArch64VM.init();
    
    const config = vm.get_arch_config();
    try testing.expect(config.arch == .aarch64);
    try testing.expect(config.memory_size == 8 * 1024 * 1024); // 8MB
    try testing.expect(config.instruction_length == 4);
    try testing.expect(config.register_count == 31);
    try testing.expect(config.is_valid());
}

// Test: AArch64 memory bounds checking.
test "aarch64 memory bounds" {
    var vm = AArch64VM.init();
    
    // Try to read from out-of-bounds address (should fail).
    const out_of_bounds: u64 = vm.memory_size;
    const result = vm.read64(out_of_bounds);
    try testing.expectError(AArch64VMError.invalid_memory_access, result);
    
    // Try to write to out-of-bounds address (should fail).
    const result2 = vm.write64(out_of_bounds, 0x1234567890ABCDEF);
    try testing.expectError(AArch64VMError.invalid_memory_access, result2);
}

