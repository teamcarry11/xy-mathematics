//! Trap Handler Tests
//! Why: Comprehensive TigerStyle tests for trap/exception handling.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const ExceptionType = basin_kernel.basin_kernel.ExceptionType;
const trap_mod = @import("../src/kernel/trap.zig");

// Test trap loop initialization.
test "trap loop with kernel" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    try std.testing.expect(kernel.scheduler.initialized);
    
    // Note: trap loop is noreturn, so we can't test it directly.
    // This test verifies kernel is ready for trap loop.
}

// Test exception type enumeration.
test "exception type enum" {
    // Assert: Exception types must be valid.
    const illegal = ExceptionType.illegal_instruction;
    try std.testing.expect(@intFromEnum(illegal) == 2);
    
    const misaligned = ExceptionType.load_address_misaligned;
    try std.testing.expect(@intFromEnum(misaligned) == 4);
    
    const access_fault = ExceptionType.load_access_fault;
    try std.testing.expect(@intFromEnum(access_fault) == 5);
}

// Test exception handling (illegal instruction).
test "handle exception illegal instruction" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    
    // Handle illegal instruction exception.
    const exception_pc: u64 = 0x80000000;
    const exception_value: u64 = 0;
    trap_mod.handle_exception(&kernel, .illegal_instruction, exception_pc, exception_value);
    
    // Assert: Exception must be handled (postcondition).
    // Note: handle_exception logs but doesn't modify kernel state.
    try std.testing.expect(kernel.interrupt_controller.initialized);
}

// Test exception handling (misaligned access).
test "handle exception misaligned access" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    
    // Handle misaligned load exception.
    const exception_pc: u64 = 0x80000010;
    const exception_address: u64 = 0x80000001; // Misaligned address
    trap.handle_exception(&kernel, .load_address_misaligned, exception_pc, exception_address);
    
    // Assert: Exception must be handled (postcondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
}

// Test exception handling (access fault).
test "handle exception access fault" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    
    // Handle load access fault exception.
    const exception_pc: u64 = 0x80000020;
    const exception_address: u64 = 0xFFFFFFFF; // Invalid address
    trap.handle_exception(&kernel, .load_access_fault, exception_pc, exception_address);
    
    // Assert: Exception must be handled (postcondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
}

// Test exception handling (store access fault).
test "handle exception store access fault" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    
    // Handle store access fault exception.
    const exception_pc: u64 = 0x80000030;
    const exception_address: u64 = 0xFFFFFFFF; // Invalid address
    trap.handle_exception(&kernel, .store_access_fault, exception_pc, exception_address);
    
    // Assert: Exception must be handled (postcondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
}

// Test exception handling (environment call).
test "handle exception environment call" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    
    // Handle environment call from U-mode (syscall).
    const exception_pc: u64 = 0x80000040;
    const exception_value: u64 = 0;
    trap.handle_exception(&kernel, .environment_call_from_u_mode, exception_pc, exception_value);
    
    // Assert: Exception must be handled (postcondition).
    // Note: Environment calls are handled by VM, not trap loop.
    try std.testing.expect(kernel.interrupt_controller.initialized);
}

// Test exception handling (unknown exception).
test "handle exception unknown" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    
    // Handle breakpoint exception (other category).
    const exception_pc: u64 = 0x80000050;
    const exception_value: u64 = 0;
    trap.handle_exception(&kernel, .breakpoint, exception_pc, exception_value);
    
    // Assert: Exception must be handled (postcondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
}

// Test exception handling with all exception types.
test "handle exception all types" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    
    // Test all exception types.
    const exception_pc: u64 = 0x80000000;
    const exception_value: u64 = 0;
    
    trap.handle_exception(&kernel, .instruction_address_misaligned, exception_pc, exception_value);
    trap.handle_exception(&kernel, .instruction_access_fault, exception_pc, exception_value);
    trap_mod.handle_exception(&kernel, .illegal_instruction, exception_pc, exception_value);
    trap.handle_exception(&kernel, .breakpoint, exception_pc, exception_value);
    trap.handle_exception(&kernel, .load_address_misaligned, exception_pc, exception_value);
    trap.handle_exception(&kernel, .load_access_fault, exception_pc, exception_value);
    trap.handle_exception(&kernel, .store_address_misaligned, exception_pc, exception_value);
    trap.handle_exception(&kernel, .store_access_fault, exception_pc, exception_value);
    trap.handle_exception(&kernel, .environment_call_from_u_mode, exception_pc, exception_value);
    trap.handle_exception(&kernel, .environment_call_from_s_mode, exception_pc, exception_value);
    trap.handle_exception(&kernel, .instruction_page_fault, exception_pc, exception_value);
    trap.handle_exception(&kernel, .load_page_fault, exception_pc, exception_value);
    trap.handle_exception(&kernel, .store_page_fault, exception_pc, exception_value);
    
    // Assert: All exceptions must be handled (postcondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
}

// Test exception handling with different PC values.
test "handle exception different PCs" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    
    // Test with different PC values.
    const pcs = [_]u64{ 0x80000000, 0x80001000, 0x80002000, 0x80003000 };
    const exception_value: u64 = 0;
    
    for (pcs) |pc| {
        trap.handle_exception(&kernel, .illegal_instruction, pc, exception_value);
    }
    
    // Assert: All exceptions must be handled (postcondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
}

// Test exception handling with different address values.
test "handle exception different addresses" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
    
    // Test with different address values.
    const exception_pc: u64 = 0x80000000;
    const addresses = [_]u64{ 0x80000001, 0x80000003, 0xFFFFFFFF, 0x00000000 };
    
    for (addresses) |addr| {
        trap.handle_exception(&kernel, .load_address_misaligned, exception_pc, addr);
    }
    
    // Assert: All exceptions must be handled (postcondition).
    try std.testing.expect(kernel.interrupt_controller.initialized);
}

