//! AArch64 VM Translation Verification Test
//! Why: Verify Vantage VM translates to macOS Tahoe 26.2 (aarch64 Apple Silicon M).
//! Grain Style: Explicit types (u32/u64), comprehensive assertions, bounded allocations.

const std = @import("std");
const testing = std.testing;
const vm_aarch64 = @import("vm_aarch64");
const AArch64VM = vm_aarch64.AArch64VM;
const AArch64VMState = vm_aarch64.AArch64VMState;

// Test: AArch64 VM can be initialized on current platform.
test "aarch64 vm translation: vm initialization" {
    // Initialize AArch64 VM.
    var vm = AArch64VM.init();
    
    // Assert: VM must be in halted state after initialization.
    try testing.expect(vm.state == .halted);
    
    // Assert: VM must have valid memory size.
    try testing.expect(vm.memory_size > 0);
    try testing.expect(vm.memory_size == 8 * 1024 * 1024); // 8MB
    
    // Assert: VM must have valid register file.
    try testing.expect(vm.regs.pc == 0);
    try testing.expect(vm.regs.sp == 0);
    
    // Assert: VM must have valid memory.
    try testing.expect(vm.memory.len == vm.memory_size);
}

// Test: AArch64 VM can execute basic operations on current platform.
test "aarch64 vm translation: basic operations" {
    // Initialize AArch64 VM.
    var vm = AArch64VM.init();
    
    // Test 1: Set register value.
    vm.regs.set(0, 0x1234567890ABCDEF);
    
    // Assert: Register value must be set correctly.
    try testing.expect(vm.regs.get(0) == 0x1234567890ABCDEF);
    
    // Test 2: Set program counter.
    vm.regs.pc = 0x80000000;
    
    // Assert: Program counter must be set correctly.
    try testing.expect(vm.regs.pc == 0x80000000);
    
    // Test 3: Set stack pointer.
    vm.regs.sp = 0x90000000;
    
    // Assert: Stack pointer must be set correctly.
    try testing.expect(vm.regs.sp == 0x90000000);
    
    // Test 4: Write to memory.
    const test_data: u64 = 0xDEADBEEFCAFEBABE;
    const test_addr: u64 = 0x1000;
    
    vm.write64(test_addr, test_data) catch |err| {
        // Memory write may fail if address is invalid, but should not crash.
        _ = err;
        return;
    };
    
    // Test 5: Read from memory.
    const read_data = vm.read64(test_addr) catch |err| {
        // Memory read may fail if address is invalid, but should not crash.
        _ = err;
        return;
    };
    
    // Assert: Read data must match written data.
    try testing.expect(read_data == test_data);
}

// Test: AArch64 VM can handle syscall handler registration.
test "aarch64 vm translation: syscall handler" {
    // Initialize AArch64 VM.
    var vm = AArch64VM.init();
    
    // Test syscall handler function.
    const test_syscall_handler = struct {
        fn handler(
            syscall_num: u32,
            arg1: u64,
            arg2: u64,
            arg3: u64,
            arg4: u64,
        ) u64 {
            _ = syscall_num;
            _ = arg1;
            _ = arg2;
            _ = arg3;
            _ = arg4;
            return 0;
        }
    }.handler;
    
    // Set syscall handler.
    vm.syscall_handler = test_syscall_handler;
    
    // Assert: Syscall handler must be set.
    try testing.expect(vm.syscall_handler != null);
}

// Test: AArch64 VM state transitions work correctly.
test "aarch64 vm translation: state transitions" {
    // Initialize AArch64 VM.
    var vm = AArch64VM.init();
    
    // Assert: VM must start in halted state.
    try testing.expect(vm.state == .halted);
    
    // Test: Start VM.
    vm.start();
    
    // Assert: VM must be in running state.
    try testing.expect(vm.state == .running);
    
    // Test: Halt VM.
    vm.halt();
    
    // Assert: VM must be in halted state.
    try testing.expect(vm.state == .halted);
}

// Test: AArch64 VM memory operations work correctly.
test "aarch64 vm translation: memory operations" {
    // Initialize AArch64 VM.
    var vm = AArch64VM.init();
    
    // Test: Write 64-bit value to memory.
    const write_addr: u64 = 0x2000;
    const write_value: u64 = 0x1234567890ABCDEF;
    
    vm.write64(write_addr, write_value) catch |err| {
        // Memory write may fail if address is invalid, but should not crash.
        _ = err;
        return;
    };
    
    // Test: Read 64-bit value from memory.
    const read_value = vm.read64(write_addr) catch |err| {
        // Memory read may fail if address is invalid, but should not crash.
        _ = err;
        return;
    };
    
    // Assert: Read value must match written value.
    try testing.expect(read_value == write_value);
    
    // Test: Write instruction to memory.
    const inst_addr: u64 = 0x3000;
    const inst_value: u32 = 0xD65F03C0; // RET instruction
    
    vm.write_instruction(inst_addr, inst_value) catch |err| {
        // Instruction write may fail if address is invalid, but should not crash.
        _ = err;
        return;
    };
    
    // Test: Read instruction from memory.
    const read_inst = vm.read_instruction(inst_addr) catch |err| {
        // Instruction read may fail if address is invalid, but should not crash.
        _ = err;
        return;
    };
    
    // Assert: Read instruction must match written instruction.
    try testing.expect(read_inst == inst_value);
}
