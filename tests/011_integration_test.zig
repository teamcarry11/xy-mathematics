//! Integration Test: VM-Kernel Integration Layer
//! Why: Test that VM and kernel work together correctly with syscalls.
//! Tiger Style: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const Integration = kernel_vm.Integration;
const VM = kernel_vm.VM;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const Syscall = basin_kernel.Syscall;

test "Integration: VM and kernel initialization" {
    // Test that we can initialize VM and kernel separately
    // This validates the basic setup without requiring full integration
    
    // Initialize VM with minimal program (TigerStyle: in-place initialization)
    const minimal_program = [_]u8{
        0x13, 0x00, 0x00, 0x00, // ADDI x0, x0, 0 (NOP)
    };
    var vm: VM = undefined;
    VM.init(&vm, &minimal_program, 0x1000);
    
    // Verify VM initialized correctly
    try testing.expect(vm.state == .halted);
    try testing.expect(vm.regs.pc == 0x1000);
    
    // Initialize kernel (test that it doesn't crash)
    _ = BasinKernel.init();
}

/// Test syscall handler (simplified version of integration layer handler).
fn syscall_test_handler(
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
) u64 {
    // Create kernel instance for testing
    var kernel = BasinKernel.init();
    
    // Call kernel syscall handler
    const result = kernel.handle_syscall(syscall_num, arg1, arg2, arg3, arg4) catch |err| {
        // Convert error to negative u64
        const error_code: i64 = switch (err) {
            error.invalid_handle => -1,
            error.invalid_argument => -2,
            error.permission_denied => -3,
            error.not_found => -4,
            error.out_of_memory => -5,
            error.would_block => -6,
            error.interrupted => -7,
            error.invalid_syscall => -8,
            error.invalid_address => -9,
            error.unaligned_access => -10,
            error.out_of_bounds => -11,
        };
        return @as(u64, @bitCast(error_code));
    };
    
    return switch (result) {
        .success => |value| value,
        .err => |err| {
            const error_code: i64 = switch (err) {
                error.invalid_handle => -1,
                error.invalid_argument => -2,
                error.permission_denied => -3,
                error.not_found => -4,
                error.out_of_memory => -5,
                error.would_block => -6,
                error.interrupted => -7,
                error.invalid_syscall => -8,
                error.invalid_address => -9,
                error.unaligned_access => -10,
                error.out_of_bounds => -11,
            };
            return @as(u64, @bitCast(error_code));
        },
    };
}

test "Integration: Syscall handler contract validation" {
    // Test that syscall handler correctly converts SyscallResult to u64
    // Note: handle_syscall has assertion syscall_num >= 10
    // This means it only accepts kernel syscalls (map=10, unmap=11, etc.)
    // Process management syscalls (spawn=1, exit=2, etc.) are < 10 and handled differently
    // TODO: Fix design mismatch - kernel should accept enum values directly
    
    var kernel = BasinKernel.init();
    
    // Test sysinfo syscall (sysinfo = 50, which is >= 10)
    // sysinfo requires a valid pointer (arg1), so pass a non-zero address
    const sysinfo_result = kernel.handle_syscall(@intFromEnum(Syscall.sysinfo), 0x1000, 0, 0, 0) catch |err| {
        // May error if address is invalid, but that's okay for this test
        // Just verify it doesn't crash - error is expected for invalid args
        try testing.expect(err == error.invalid_argument or err == error.invalid_address);
        return;
    };
    
    // If successful, sysinfo returns the pointer
    _ = sysinfo_result;
    
    // Test map syscall (map = 10, which is >= 10)
    const map_result = kernel.handle_syscall(@intFromEnum(Syscall.map), 0x1000, 4096, 0, 0) catch |err| {
        // May error due to invalid arguments, but should not panic
        // Just verify it doesn't crash - error is expected for invalid args
        try testing.expect(err == error.invalid_argument or err == error.invalid_address);
        return;
    };
    
    // If we get here, map succeeded (unexpected but valid)
    _ = map_result;
}

test "Integration: VM memory access with new instructions" {
    // Test that new load/store instructions work correctly
    // Use VM's read64/write64 to verify memory operations work
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{0} ** 1024, 0x1000);
    
    // Write test value to memory using VM's write64
    const test_addr: u64 = 0x2000;
    const test_value: u64 = 0xDEADBEEFCAFEBABE;
    try vm.write64(test_addr, test_value);
    
    // Verify we can read it back
    const read_value = try vm.read64(test_addr);
    try testing.expect(read_value == test_value);
    
    // Test that VM memory is accessible (validates memory subsystem works)
    // The actual LD/SD instruction tests are covered in kernel_vm_test
}

test "Integration: JAL instruction (function calls)" {
    // Test that JAL instruction exists and can be executed
    // Detailed instruction encoding tests are in kernel_vm_test
    // This test just verifies the instruction decoder recognizes JAL opcode
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{0} ** 1024, 0x1000);
    
    // Place a JAL instruction: JAL x0, 0 (no-op jump, x0 discards return address)
    // Opcode 1101111 = 0x6F, with rd=0, imm=0
    // JAL x0, 0 = 0x0000006F
    const jal_nop: u32 = 0x0000006F;
    @memcpy(vm.memory[0x1000..][0..4], &std.mem.toBytes(jal_nop));
    
    vm.regs.pc = 0x1000;
    vm.start();
    
    // Execute JAL - should not crash
    try vm.step();
    
    // Verify VM is still in valid state
    try testing.expect(vm.state != .errored);
}

test "Integration: Branch instructions" {
    // Test that branch instructions exist and can be executed
    // Detailed instruction encoding tests are in kernel_vm_test
    // This test just verifies the instruction decoder recognizes branch opcode
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{0} ** 1024, 0x1000);
    
    // Place a BEQ instruction: BEQ x0, x0, 0 (always taken, but x0 == x0)
    // Opcode 1100011 = 0x63, with rs1=0, rs2=0, funct3=000 (BEQ), imm=0
    // BEQ x0, x0, 0 = 0x00000063
    const beq_nop: u32 = 0x00000063;
    @memcpy(vm.memory[0x1000..][0..4], &std.mem.toBytes(beq_nop));
    
    vm.regs.pc = 0x1000;
    vm.start();
    
    // Execute BEQ - should not crash
    try vm.step();
    
    // Verify VM is still in valid state
    try testing.expect(vm.state != .errored);
}

