//! Exception Statistics in Diagnostics Snapshot Tests
//! Why: Comprehensive TigerStyle tests for exception statistics in diagnostics snapshots.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const DiagnosticsSnapshot = kernel_vm.performance.DiagnosticsSnapshot;

// Test exception statistics in diagnostics snapshot creation.
test "exception stats diagnostics create" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Record some exceptions.
    vm.exception_stats.record_exception(2); // Illegal instruction
    vm.exception_stats.record_exception(4); // Load address misaligned
    
    // Assert: Exceptions must be recorded (precondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == 2);
    
    // Create diagnostics snapshot.
    const diagnostics = vm.get_diagnostics();
    
    // Assert: Exception statistics must be captured (postcondition).
    try std.testing.expect(diagnostics.exception_stats.total_count == 2);
    try std.testing.expect(diagnostics.exception_stats.exception_counts[2] == 1);
    try std.testing.expect(diagnostics.exception_stats.exception_counts[4] == 1);
}

// Test exception statistics in diagnostics with all exception types.
test "exception stats diagnostics all types" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Record all exception types.
    for (0..16) |i| {
        const exception_code = @as(u32, @intCast(i));
        vm.exception_stats.record_exception(exception_code);
    }
    
    // Assert: All exceptions must be recorded (precondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == 16);
    
    // Create diagnostics snapshot.
    const diagnostics = vm.get_diagnostics();
    
    // Assert: All exception statistics must be captured (postcondition).
    try std.testing.expect(diagnostics.exception_stats.total_count == 16);
    for (0..16) |i| {
        try std.testing.expect(diagnostics.exception_stats.exception_counts[i] == 1);
    }
}

// Test exception statistics in diagnostics with high counts.
test "exception stats diagnostics high counts" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Record many exceptions of same type.
    const count: u32 = 50;
    for (0..count) |_| {
        vm.exception_stats.record_exception(2); // Illegal instruction
    }
    
    // Assert: Exceptions must be recorded (precondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == count);
    
    // Create diagnostics snapshot.
    const diagnostics = vm.get_diagnostics();
    
    // Assert: Exception statistics must be captured (postcondition).
    try std.testing.expect(diagnostics.exception_stats.total_count == count);
    try std.testing.expect(diagnostics.exception_stats.exception_counts[2] == count);
}

// Test exception statistics in diagnostics consistency.
test "exception stats diagnostics consistency" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Record various exceptions.
    vm.exception_stats.record_exception(0);
    vm.exception_stats.record_exception(1);
    vm.exception_stats.record_exception(2);
    vm.exception_stats.record_exception(4);
    vm.exception_stats.record_exception(5);
    
    // Create diagnostics snapshot.
    const diagnostics = vm.get_diagnostics();
    
    // Assert: Exception statistics must be consistent (postcondition).
    var calculated_total: u64 = 0;
    for (0..16) |i| {
        calculated_total += diagnostics.exception_stats.exception_counts[i];
    }
    try std.testing.expect(calculated_total == diagnostics.exception_stats.total_count);
    try std.testing.expect(diagnostics.exception_stats.total_count == 5);
}

// Test exception statistics in diagnostics with zero exceptions.
test "exception stats diagnostics zero exceptions" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Assert: No exceptions recorded (precondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == 0);
    
    // Create diagnostics snapshot.
    const diagnostics = vm.get_diagnostics();
    
    // Assert: Exception statistics must be zero (postcondition).
    try std.testing.expect(diagnostics.exception_stats.total_count == 0);
    for (0..16) |i| {
        try std.testing.expect(diagnostics.exception_stats.exception_counts[i] == 0);
    }
}

// Test exception statistics in diagnostics after VM execution.
test "exception stats diagnostics after execution" {
    var vm: VM = undefined;
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
    };
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Start VM and execute instruction.
    vm.start();
    _ = vm.step() catch {};
    
    // Record some exceptions (simulate errors during execution).
    vm.exception_stats.record_exception(2);
    
    // Create diagnostics snapshot.
    const diagnostics = vm.get_diagnostics();
    
    // Assert: Exception statistics must be captured (postcondition).
    try std.testing.expect(diagnostics.exception_stats.total_count == 1);
    try std.testing.expect(diagnostics.exception_stats.exception_counts[2] == 1);
    try std.testing.expect(diagnostics.pc == vm.regs.pc);
}

// Test exception statistics in diagnostics print.
test "exception stats diagnostics print" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Record some exceptions.
    vm.exception_stats.record_exception(2);
    vm.exception_stats.record_exception(4);
    vm.exception_stats.record_exception(5);
    
    // Create diagnostics snapshot.
    const diagnostics = vm.get_diagnostics();
    
    // Assert: Exception statistics must be captured (precondition).
    try std.testing.expect(diagnostics.exception_stats.total_count == 3);
    
    // Print diagnostics (should include exception statistics).
    diagnostics.print();
    
    // Assert: Print must complete without error (postcondition).
    try std.testing.expect(diagnostics.exception_stats.total_count == 3);
}

