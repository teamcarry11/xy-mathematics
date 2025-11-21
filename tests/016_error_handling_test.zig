//! Error Handling and Recovery Tests
//!
//! Objective: Validate error logging and recovery mechanisms in VM and integration layer.
//! Tests verify that errors are correctly logged, statistics are tracked, and recovery works.
//!
//! Methodology:
//! - Test error logging (invalid instruction, memory access)
//! - Test error statistics (count by type)
//! - Test error log retrieval (recent errors)
//! - Test error recovery (VM can restart after error)
//! - Test error log clearing
//!
//! TigerStyle Principles:
//! - Exhaustive testing: valid data, invalid data, edge cases
//! - Assertions detect programmer errors: assert preconditions, postconditions, invariants
//! - Explicit types: u32/u64 instead of usize for cross-platform consistency
//! - Bounded loops: all loops have fixed upper bounds
//! - Comments explain why: not just what the code does, but why it's written this way
//! - Pair assertions: verify both input validation and output correctness
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive test coverage, deterministic behavior, explicit limits

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const error_log_mod = kernel_vm.error_log;
const ErrorLog = error_log_mod.ErrorLog;
const ErrorType = error_log_mod.ErrorType;

test "Error Log: Log single error" {
    // Objective: Verify error logging records errors correctly.
    // Methodology: Log error, verify entry is recorded.
    // Why: Foundation test for error logging system.
    
    var error_log = ErrorLog{};
    
    // Assert: Error log must start empty (precondition).
    try testing.expect(error_log.entry_count == 0);
    
    // Log error.
    const timestamp: u64 = 1000;
    const error_type: u32 = @intFromEnum(ErrorType.invalid_instruction);
    const message = "Test error";
    const context: u64 = 0x80000000;
    error_log.log(timestamp, error_type, message, context);
    
    // Assert: Error must be logged (postcondition).
    try testing.expect(error_log.entry_count == 1);
    try testing.expect(error_log.stats.total_errors == 1);
}

test "Error Log: Error statistics" {
    // Objective: Verify error statistics track error counts correctly.
    // Methodology: Log multiple errors of different types, verify statistics.
    // Why: Statistics enable monitoring and recovery decisions.
    
    var error_log = ErrorLog{};
    
    // Log multiple errors of same type.
    error_log.log(1000, @intFromEnum(ErrorType.invalid_instruction), "Error 1", 0);
    error_log.log(2000, @intFromEnum(ErrorType.invalid_instruction), "Error 2", 0);
    error_log.log(3000, @intFromEnum(ErrorType.invalid_memory_access), "Error 3", 0);
    
    // Assert: Statistics must be correct (postcondition).
    try testing.expect(error_log.stats.total_errors == 3);
    try testing.expect(error_log.stats.get_count(@intFromEnum(ErrorType.invalid_instruction)) == 2);
    try testing.expect(error_log.stats.get_count(@intFromEnum(ErrorType.invalid_memory_access)) == 1);
}

test "Error Log: Get recent errors" {
    // Objective: Verify recent error retrieval returns correct entries.
    // Methodology: Log multiple errors, retrieve recent, verify order.
    // Why: Recent errors are most useful for debugging.
    
    var error_log = ErrorLog{};
    
    // Log multiple errors.
    error_log.log(1000, @intFromEnum(ErrorType.invalid_instruction), "Error 1", 0);
    error_log.log(2000, @intFromEnum(ErrorType.invalid_memory_access), "Error 2", 0);
    error_log.log(3000, @intFromEnum(ErrorType.syscall_error), "Error 3", 0);
    
    // Get recent errors.
    var buffer: [10]error_log_mod.ErrorLogEntry = undefined;
    const recent = error_log.get_recent(3, &buffer);
    
    // Assert: Must return 3 errors (postcondition).
    try testing.expect(recent.len == 3);
    
    // Assert: Most recent error must be last logged (postcondition).
    // Why: get_recent returns most recent first.
    try testing.expect(recent[0].error_type == @intFromEnum(ErrorType.syscall_error));
    try testing.expect(recent[1].error_type == @intFromEnum(ErrorType.invalid_memory_access));
    try testing.expect(recent[2].error_type == @intFromEnum(ErrorType.invalid_instruction));
}

test "Error Log: Clear error log" {
    // Objective: Verify clearing error log resets all state.
    // Methodology: Log errors, clear, verify log is empty.
    // Why: Clearing allows resetting error state after recovery.
    
    var error_log = ErrorLog{};
    
    // Log errors.
    error_log.log(1000, @intFromEnum(ErrorType.invalid_instruction), "Error 1", 0);
    error_log.log(2000, @intFromEnum(ErrorType.invalid_memory_access), "Error 2", 0);
    
    // Assert: Errors must be logged (precondition).
    try testing.expect(error_log.entry_count == 2);
    try testing.expect(error_log.stats.total_errors == 2);
    
    // Clear error log.
    error_log.clear();
    
    // Assert: Error log must be cleared (postcondition).
    try testing.expect(error_log.entry_count == 0);
    try testing.expect(error_log.stats.total_errors == 0);
}

test "VM Error Logging: Invalid instruction" {
    // Objective: Verify VM logs errors when invalid instruction is encountered.
    // Methodology: Execute invalid instruction, verify error is logged.
    // Why: Error logging enables debugging and monitoring.
    
    // Create VM with invalid instruction.
    const invalid_program = [_]u8{
        0xFF, 0xFF, 0xFF, 0xFF, // Invalid instruction
    };
    
    var vm: VM = undefined;
    VM.init(&vm, &invalid_program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try testing.expect(vm.state == .halted);
    
    // Start VM.
    vm.start();
    
    // Execute step (should encounter invalid instruction).
    vm.step() catch |err| {
        // Error is expected.
        _ = err;
    };
    
    // Assert: VM must be in errored state (postcondition).
    try testing.expect(vm.state == .errored);
    
    // Assert: Error must be logged (postcondition).
    try testing.expect(vm.error_log.stats.total_errors > 0);
}

test "VM Error Recovery: Restart after error" {
    // Objective: Verify VM can restart after error (recovery mechanism).
    // Methodology: Cause error, restart VM, verify VM can execute again.
    // Why: Recovery enables continued operation after transient errors.
    
    // Create VM with program that will error.
    const invalid_program = [_]u8{
        0xFF, 0xFF, 0xFF, 0xFF, // Invalid instruction
    };
    
    var vm: VM = undefined;
    VM.init(&vm, &invalid_program, 0x80000000);
    
    // Start and execute (will error).
    vm.start();
    vm.step() catch |err| {
        _ = err;
    };
    
    // Assert: VM must be in errored state (precondition).
    try testing.expect(vm.state == .errored);
    
    // Restart VM (recovery).
    vm.start();
    
    // Assert: VM must be in running state after restart (postcondition).
    try testing.expect(vm.state == .running);
    
    // Assert: Last error must be cleared (postcondition).
    try testing.expect(vm.last_error == null);
}

test "Error Log: Circular buffer behavior" {
    // Objective: Verify error log circular buffer handles overflow correctly.
    // Methodology: Log more errors than buffer size, verify oldest are overwritten.
    // Why: Circular buffer prevents unbounded memory growth.
    
    var error_log = ErrorLog{};
    
    // Log more errors than buffer size.
    const OVERFLOW_COUNT: u32 = 300; // More than MAX_ERROR_LOG_ENTRIES (256)
    var i: u32 = 0;
    while (i < OVERFLOW_COUNT) : (i += 1) {
        error_log.log(i * 1000, @intFromEnum(ErrorType.unknown), "Error", i);
    }
    
    // Assert: Entry count must be bounded (postcondition).
    try testing.expect(error_log.entry_count == error_log_mod.MAX_ERROR_LOG_ENTRIES);
    
    // Assert: Statistics must reflect all errors (postcondition).
    try testing.expect(error_log.stats.total_errors == OVERFLOW_COUNT);
}

test "Error Log: Error entry message truncation" {
    // Objective: Verify error entry truncates long messages correctly.
    // Methodology: Log error with long message, verify truncation.
    // Why: Bounded message size prevents memory issues.
    
    var error_log = ErrorLog{};
    
    // Log error with long message (longer than 64 bytes).
    const long_message = "This is a very long error message that should be truncated to fit in the error log entry buffer which has a maximum size of 64 bytes including the null terminator";
    error_log.log(1000, @intFromEnum(ErrorType.unknown), long_message, 0);
    
    // Get recent errors.
    var buffer: [1]error_log_mod.ErrorLogEntry = undefined;
    const recent = error_log.get_recent(1, &buffer);
    
    // Assert: Must return one error (postcondition).
    try testing.expect(recent.len == 1);
    
    // Assert: Message must be truncated (postcondition).
    const entry_message = recent[0].get_message();
    try testing.expect(entry_message.len <= 63); // 64 - 1 (null terminator)
}

