//! Performance Monitoring Tests
//!
//! Objective: Validate performance monitoring and diagnostics in VM.
//! Tests verify that performance metrics are correctly tracked and diagnostics work.
//!
//! Methodology:
//! - Test performance metrics tracking (instructions, memory, syscalls)
//! - Test JIT performance tracking (cache hits, misses, fallbacks)
//! - Test diagnostics snapshot creation
//! - Test performance metrics calculation (IPC, cache hit rate)
//! - Test metrics reset
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
const performance_mod = @import("performance");
const PerformanceMetrics = performance_mod.PerformanceMetrics;

test "Performance Metrics: Track instruction execution" {
    // Objective: Verify instruction execution is tracked correctly.
    // Methodology: Execute instructions, verify instruction count increments.
    // Why: Foundation test for performance monitoring.
    
    var metrics = PerformanceMetrics{};
    
    // Assert: Metrics must start at zero (precondition).
    try testing.expect(metrics.instructions_executed == 0);
    try testing.expect(metrics.cycles_simulated == 0);
    
    // Increment instruction count.
    metrics.increment_instruction();
    
    // Assert: Instruction count must increment (postcondition).
    try testing.expect(metrics.instructions_executed == 1);
    try testing.expect(metrics.cycles_simulated == 1);
}

test "Performance Metrics: Track memory operations" {
    // Objective: Verify memory operations are tracked correctly.
    // Methodology: Track memory reads and writes, verify counts.
    // Why: Memory access patterns are important for optimization.
    
    var metrics = PerformanceMetrics{};
    
    // Assert: Memory counters must start at zero (precondition).
    try testing.expect(metrics.memory_reads == 0);
    try testing.expect(metrics.memory_writes == 0);
    
    // Increment memory read and write counts.
    metrics.increment_memory_read();
    metrics.increment_memory_write();
    metrics.increment_memory_read();
    
    // Assert: Memory counters must be correct (postcondition).
    try testing.expect(metrics.memory_reads == 2);
    try testing.expect(metrics.memory_writes == 1);
}

test "Performance Metrics: Track syscalls" {
    // Objective: Verify syscall invocations are tracked correctly.
    // Methodology: Track syscalls, verify count increments.
    // Why: Syscall frequency is important for performance analysis.
    
    var metrics = PerformanceMetrics{};
    
    // Assert: Syscall counter must start at zero (precondition).
    try testing.expect(metrics.syscalls == 0);
    
    // Increment syscall count.
    metrics.increment_syscall();
    metrics.increment_syscall();
    
    // Assert: Syscall count must increment (postcondition).
    try testing.expect(metrics.syscalls == 2);
}

test "Performance Metrics: Calculate IPC" {
    // Objective: Verify IPC (instructions per cycle) calculation.
    // Methodology: Execute instructions, calculate IPC, verify result.
    // Why: IPC measures execution efficiency.
    
    var metrics = PerformanceMetrics{};
    
    // Execute multiple instructions.
    metrics.increment_instruction();
    metrics.increment_instruction();
    metrics.increment_instruction();
    
    // Calculate IPC.
    const ipc = metrics.get_ipc();
    
    // Assert: IPC must be valid (postcondition).
    // Why: Approximate model: 1 cycle per instruction, so IPC should be ~1.0.
    try testing.expect(ipc >= 0.0);
    try testing.expect(ipc <= 1.0);
    try testing.expect(ipc > 0.0);
}

test "Performance Metrics: Calculate JIT cache hit rate" {
    // Objective: Verify JIT cache hit rate calculation.
    // Methodology: Track cache hits and misses, calculate hit rate.
    // Why: Cache hit rate measures JIT effectiveness.
    
    var metrics = PerformanceMetrics{};
    
    // Track cache hits and misses.
    metrics.increment_jit_cache_hit();
    metrics.increment_jit_cache_hit();
    metrics.increment_jit_cache_miss();
    
    // Calculate hit rate.
    const hit_rate = metrics.get_jit_cache_hit_rate();
    
    // Assert: Hit rate must be correct (postcondition).
    // Why: 2 hits out of 3 accesses = 2/3 = 0.667.
    try testing.expect(hit_rate >= 0.0);
    try testing.expect(hit_rate <= 1.0);
    try testing.expect(hit_rate > 0.5); // More hits than misses.
}

test "Performance Metrics: Reset metrics" {
    // Objective: Verify metrics can be reset correctly.
    // Methodology: Track metrics, reset, verify all counters are zero.
    // Why: Reset allows starting new measurement period.
    
    var metrics = PerformanceMetrics{};
    
    // Track various metrics.
    metrics.increment_instruction();
    metrics.increment_memory_read();
    metrics.increment_syscall();
    
    // Assert: Metrics must be non-zero (precondition).
    try testing.expect(metrics.instructions_executed > 0);
    
    // Reset metrics.
    metrics.reset();
    
    // Assert: All metrics must be zero (postcondition).
    try testing.expect(metrics.instructions_executed == 0);
    try testing.expect(metrics.cycles_simulated == 0);
    try testing.expect(metrics.memory_reads == 0);
    try testing.expect(metrics.syscalls == 0);
}

test "VM Performance Monitoring: Track instruction execution" {
    // Objective: Verify VM tracks instruction execution correctly.
    // Methodology: Execute VM instructions, verify performance metrics.
    // Why: End-to-end validation of performance monitoring.
    
    // Create VM with simple program.
    const program = [_]u8{
        0x13, 0x00, 0x00, 0x00, // ADDI x0, x0, 0 (NOP)
        0x13, 0x00, 0x00, 0x00, // ADDI x0, x0, 0 (NOP)
    };
    
    var vm: VM = undefined;
    VM.init(&vm, &program, 0x80000000);
    
    // Start VM.
    vm.start();
    
    // Execute two instructions.
    vm.step() catch |err| {
        _ = err;
    };
    vm.step() catch |err| {
        _ = err;
    };
    
    // Assert: Performance metrics must track instructions (postcondition).
    try testing.expect(vm.performance.instructions_executed >= 2);
    try testing.expect(vm.performance.cycles_simulated >= 2);
}

test "VM Diagnostics: Create diagnostics snapshot" {
    // Objective: Verify diagnostics snapshot captures VM state correctly.
    // Methodology: Create snapshot, verify state and metrics are captured.
    // Why: Diagnostics enable debugging and monitoring.
    
    // Create VM.
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Start VM and execute some instructions.
    vm.start();
    vm.step() catch |err| {
        _ = err;
    };
    
    // Create diagnostics snapshot.
    const snapshot = vm.get_diagnostics();
    
    // Assert: Snapshot must capture VM state (postcondition).
    try testing.expect(snapshot.pc > 0);
    try testing.expect(snapshot.memory_size > 0);
    try testing.expect(snapshot.metrics.instructions_executed > 0);
    
    // Assert: Exception statistics must be captured (postcondition).
    try testing.expect(snapshot.exception_stats.total_count == vm.exception_stats.get_total_count());
}

test "Performance Metrics: JIT tracking" {
    // Objective: Verify JIT performance metrics are tracked correctly.
    // Methodology: Track JIT cache hits, misses, and fallbacks.
    // Why: JIT performance is critical for VM efficiency.
    
    var metrics = PerformanceMetrics{};
    
    // Track JIT activity.
    metrics.increment_jit_compilation();
    metrics.increment_jit_cache_hit();
    metrics.increment_jit_cache_hit();
    metrics.increment_jit_cache_miss();
    metrics.increment_interpreter_fallback();
    
    // Assert: JIT metrics must be correct (postcondition).
    try testing.expect(metrics.jit_compilations == 1);
    try testing.expect(metrics.jit_cache_hits == 2);
    try testing.expect(metrics.jit_cache_misses == 1);
    try testing.expect(metrics.interpreter_fallbacks == 1);
}

