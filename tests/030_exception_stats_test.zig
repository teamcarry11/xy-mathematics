//! Exception Statistics Tests
//! Why: Comprehensive TigerStyle tests for exception statistics tracking.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const ExceptionStats = kernel_vm.exception_stats.ExceptionStats;
const ExceptionSummary = kernel_vm.exception_stats.ExceptionSummary;

// Test exception statistics initialization.
test "exception stats init" {
    const stats = ExceptionStats.init();
    
    // Assert: Statistics must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    try std.testing.expect(stats.total_count == 0);
    
    // Assert: All exception counts must be zero (postcondition).
    for (0..16) |i| {
        try std.testing.expect(stats.exception_counts[i] == 0);
    }
}

// Test recording illegal instruction exception.
test "record exception illegal instruction" {
    var stats = ExceptionStats.init();
    
    // Assert: Statistics must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record illegal instruction exception (code 2).
    stats.record_exception(2);
    
    // Assert: Exception must be recorded (postcondition).
    try std.testing.expect(stats.get_count(2) == 1);
    try std.testing.expect(stats.get_total_count() == 1);
}

// Test recording multiple exceptions.
test "record exception multiple" {
    var stats = ExceptionStats.init();
    
    // Assert: Statistics must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record multiple exceptions.
    stats.record_exception(2); // Illegal instruction
    stats.record_exception(4); // Load address misaligned
    stats.record_exception(6); // Store address misaligned
    
    // Assert: All exceptions must be recorded (postcondition).
    try std.testing.expect(stats.get_count(2) == 1);
    try std.testing.expect(stats.get_count(4) == 1);
    try std.testing.expect(stats.get_count(6) == 1);
    try std.testing.expect(stats.get_total_count() == 3);
}

// Test recording same exception multiple times.
test "record exception same type multiple" {
    var stats = ExceptionStats.init();
    
    // Assert: Statistics must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record same exception multiple times.
    stats.record_exception(2);
    stats.record_exception(2);
    stats.record_exception(2);
    
    // Assert: Count must be correct (postcondition).
    try std.testing.expect(stats.get_count(2) == 3);
    try std.testing.expect(stats.get_total_count() == 3);
}

// Test exception statistics summary.
test "exception stats summary" {
    var stats = ExceptionStats.init();
    
    // Assert: Statistics must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record various exceptions.
    stats.record_exception(2); // Illegal instruction
    stats.record_exception(4); // Load address misaligned
    stats.record_exception(5); // Load access fault
    stats.record_exception(7); // Store access fault
    stats.record_exception(8); // Environment call from U-mode
    
    // Get summary.
    const summary = stats.get_summary();
    
    // Assert: Summary must be correct (postcondition).
    try std.testing.expect(summary.total_count == 5);
    try std.testing.expect(summary.illegal_instruction == 1);
    try std.testing.expect(summary.load_address_misaligned == 1);
    try std.testing.expect(summary.load_access_fault == 1);
    try std.testing.expect(summary.store_access_fault == 1);
    try std.testing.expect(summary.environment_call == 1);
}

// Test exception statistics reset.
test "exception stats reset" {
    var stats = ExceptionStats.init();
    
    // Assert: Statistics must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record some exceptions.
    stats.record_exception(2);
    stats.record_exception(4);
    
    // Assert: Exceptions must be recorded (precondition).
    try std.testing.expect(stats.get_total_count() == 2);
    
    // Reset statistics.
    stats.reset();
    
    // Assert: Statistics must be reset (postcondition).
    try std.testing.expect(stats.get_total_count() == 0);
    try std.testing.expect(stats.get_count(2) == 0);
    try std.testing.expect(stats.get_count(4) == 0);
}

// Test exception statistics with all exception types.
test "exception stats all types" {
    var stats = ExceptionStats.init();
    
    // Assert: Statistics must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record all exception types.
    for (0..16) |i| {
        const exception_code = @as(u32, @intCast(i));
        stats.record_exception(exception_code);
    }
    
    // Assert: All exceptions must be recorded (postcondition).
    try std.testing.expect(stats.get_total_count() == 16);
    for (0..16) |i| {
        try std.testing.expect(stats.get_count(@as(u32, @intCast(i))) == 1);
    }
}

// Test exception statistics in VM context.
test "exception stats vm integration" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    try std.testing.expect(vm.exception_stats.get_total_count() == 0);
    
    // Record exception via VM (simulate illegal instruction).
    vm.exception_stats.record_exception(2);
    
    // Assert: Exception must be recorded (postcondition).
    try std.testing.expect(vm.exception_stats.get_count(2) == 1);
    try std.testing.expect(vm.exception_stats.get_total_count() == 1);
}

// Test exception statistics summary consistency.
test "exception stats summary consistency" {
    var stats = ExceptionStats.init();
    
    // Assert: Statistics must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record various exceptions.
    stats.record_exception(0); // Instruction address misaligned
    stats.record_exception(1); // Instruction access fault
    stats.record_exception(2); // Illegal instruction
    stats.record_exception(4); // Load address misaligned
    stats.record_exception(5); // Load access fault
    stats.record_exception(6); // Store address misaligned
    stats.record_exception(7); // Store access fault
    stats.record_exception(8); // Environment call from U-mode
    stats.record_exception(12); // Instruction page fault
    stats.record_exception(13); // Load page fault
    stats.record_exception(15); // Store page fault
    
    // Get summary.
    const summary = stats.get_summary();
    
    // Assert: Summary must be consistent (postcondition).
    const calculated_total = summary.illegal_instruction +
        summary.load_address_misaligned + summary.store_address_misaligned +
        summary.load_access_fault + summary.store_access_fault +
        summary.instruction_access_fault + summary.instruction_address_misaligned +
        summary.environment_call + summary.page_faults + summary.other;
    try std.testing.expect(calculated_total == summary.total_count);
    try std.testing.expect(summary.total_count == 11);
}

// Test exception statistics with high counts.
test "exception stats high counts" {
    var stats = ExceptionStats.init();
    
    // Assert: Statistics must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record many exceptions of same type.
    const count: u32 = 1000;
    for (0..count) |_| {
        stats.record_exception(2); // Illegal instruction
    }
    
    // Assert: Count must be correct (postcondition).
    try std.testing.expect(stats.get_count(2) == count);
    try std.testing.expect(stats.get_total_count() == count);
}

