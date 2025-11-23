//! Exception Statistics in State Snapshot Tests
//! Why: Comprehensive TigerStyle tests for exception statistics in VM state snapshots.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const VMStateSnapshot = kernel_vm.state_snapshot.VMStateSnapshot;

// VM memory size constant (matches VM_MEMORY_SIZE).
const VM_MEMORY_SIZE: u64 = 8 * 1024 * 1024; // 8MB

// Test exception statistics in snapshot creation.
test "exception stats snapshot create" {
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
    
    // Create snapshot.
    var memory_buffer: [VM_MEMORY_SIZE]u8 = undefined;
    const snapshot = try vm.save_state(&memory_buffer);
    
    // Assert: Exception statistics must be captured (postcondition).
    try std.testing.expect(snapshot.exception_stats.total_count == 2);
    try std.testing.expect(snapshot.exception_stats.exception_counts[2] == 1);
    try std.testing.expect(snapshot.exception_stats.exception_counts[4] == 1);
}

// Test exception statistics in snapshot restoration.
test "exception stats snapshot restore" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Record some exceptions.
    vm.exception_stats.record_exception(2);
    vm.exception_stats.record_exception(5);
    vm.exception_stats.record_exception(7);
    
    // Assert: Exceptions must be recorded (precondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == 3);
    
    // Create snapshot.
    var memory_buffer: [VM_MEMORY_SIZE]u8 = undefined;
    const snapshot = try vm.save_state(&memory_buffer);
    
    // Clear exception statistics.
    vm.exception_stats.reset();
    
    // Assert: Exception statistics must be cleared (precondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == 0);
    
    // Restore from snapshot.
    try snapshot.restore(&vm);
    
    // Assert: Exception statistics must be restored (postcondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == 3);
    try std.testing.expect(vm.exception_stats.get_count(2) == 1);
    try std.testing.expect(vm.exception_stats.get_count(5) == 1);
    try std.testing.expect(vm.exception_stats.get_count(7) == 1);
}

// Test exception statistics snapshot with all exception types.
test "exception stats snapshot all types" {
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
    
    // Create snapshot.
    var memory_buffer: [VM_MEMORY_SIZE]u8 = undefined;
    const snapshot = try vm.save_state(&memory_buffer);
    
    // Assert: All exception statistics must be captured (postcondition).
    try std.testing.expect(snapshot.exception_stats.total_count == 16);
    for (0..16) |i| {
        try std.testing.expect(snapshot.exception_stats.exception_counts[i] == 1);
    }
}

// Test exception statistics snapshot with high counts.
test "exception stats snapshot high counts" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Record many exceptions of same type.
    const count: u32 = 100;
    for (0..count) |_| {
        vm.exception_stats.record_exception(2); // Illegal instruction
    }
    
    // Assert: Exceptions must be recorded (precondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == count);
    
    // Create snapshot.
    var memory_buffer: [VM_MEMORY_SIZE]u8 = undefined;
    const snapshot = try vm.save_state(&memory_buffer);
    
    // Assert: Exception statistics must be captured (postcondition).
    try std.testing.expect(snapshot.exception_stats.total_count == count);
    try std.testing.expect(snapshot.exception_stats.exception_counts[2] == count);
}

// Test exception statistics snapshot consistency.
test "exception stats snapshot consistency" {
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
    
    // Create snapshot.
    var memory_buffer: [VM_MEMORY_SIZE]u8 = undefined;
    const snapshot = try vm.save_state(&memory_buffer);
    
    // Restore from snapshot.
    vm.exception_stats.reset();
    try snapshot.restore(&vm);
    
    // Assert: Exception statistics must be consistent (postcondition).
    var calculated_total: u64 = 0;
    for (0..16) |i| {
        calculated_total += vm.exception_stats.exception_counts[i];
    }
    try std.testing.expect(calculated_total == vm.exception_stats.total_count);
    try std.testing.expect(vm.exception_stats.total_count == 5);
}

// Test exception statistics snapshot with zero exceptions.
test "exception stats snapshot zero exceptions" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Assert: No exceptions recorded (precondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == 0);
    
    // Create snapshot.
    var memory_buffer: [VM_MEMORY_SIZE]u8 = undefined;
    const snapshot = try vm.save_state(&memory_buffer);
    
    // Assert: Exception statistics must be zero (postcondition).
    try std.testing.expect(snapshot.exception_stats.total_count == 0);
    for (0..16) |i| {
        try std.testing.expect(snapshot.exception_stats.exception_counts[i] == 0);
    }
}

// Test exception statistics snapshot restore after modifications.
test "exception stats snapshot restore after modifications" {
    var vm: VM = undefined;
    const program = [_]u8{};
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be initialized (precondition).
    try std.testing.expect(vm.exception_stats.initialized);
    
    // Record initial exceptions.
    vm.exception_stats.record_exception(2);
    vm.exception_stats.record_exception(4);
    
    // Create snapshot.
    var memory_buffer: [VM_MEMORY_SIZE]u8 = undefined;
    const snapshot = try vm.save_state(&memory_buffer);
    
    // Modify exception statistics.
    vm.exception_stats.record_exception(6);
    vm.exception_stats.record_exception(7);
    
    // Assert: Exception statistics must be modified (precondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == 4);
    
    // Restore from snapshot.
    try snapshot.restore(&vm);
    
    // Assert: Exception statistics must be restored to snapshot state (postcondition).
    try std.testing.expect(vm.exception_stats.get_total_count() == 2);
    try std.testing.expect(vm.exception_stats.get_count(2) == 1);
    try std.testing.expect(vm.exception_stats.get_count(4) == 1);
    try std.testing.expect(vm.exception_stats.get_count(6) == 0);
    try std.testing.expect(vm.exception_stats.get_count(7) == 0);
}

