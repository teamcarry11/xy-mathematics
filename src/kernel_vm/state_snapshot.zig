//! VM State Snapshot System
//!
//! Objective: Save and restore complete VM state for debugging, testing, and checkpointing.
//! Why: Enable VM state persistence, debugging, and reproducible test scenarios.
//! GrainStyle: Static allocation, explicit types, deterministic serialization.
//!
//! Methodology:
//! - Capture complete VM state (registers, memory, flags, performance metrics)
//! - Serialize to binary format (deterministic, efficient)
//! - Restore from snapshot (reproducible execution)
//! - Validate state consistency (assertions for correctness)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size structures (no dynamic allocation)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive state capture, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;
const VMError = VM.VMError;

/// Performance snapshot type.
/// Why: Explicit type for performance metrics.
pub const PerformanceSnapshot = struct {
    instructions_executed: u64,
    cycles_simulated: u64,
    memory_reads: u64,
    memory_writes: u64,
    syscalls: u64,
    jit_compilations: u64,
    jit_cache_hits: u64,
    jit_cache_misses: u64,
    interpreter_fallbacks: u64,
};

/// Exception statistics snapshot type.
/// Why: Explicit type for exception statistics in snapshot.
pub const ExceptionStatsSnapshot = struct {
    /// Exception counts by type (16 exception types).
    exception_counts: [16]u64,
    /// Total exception count.
    total_count: u64,
};

/// VM state snapshot (complete VM state capture).
/// Why: Enable state persistence, debugging, and reproducible execution.
/// GrainStyle: Explicit types, static allocation, deterministic encoding.
/// Note: Snapshot includes all VM state except JIT code buffer (can be recompiled).
pub const VMStateSnapshot = struct {
    /// Register file (32 GP registers + PC).
    /// Why: Capture all register state for complete restoration.
    regs: [33]u64, // 32 GP registers + PC
    
    /// Memory snapshot (complete VM memory).
    /// Why: Capture memory state for complete restoration.
    /// Note: Size matches VM_MEMORY_SIZE (8MB default).
    memory: []u8,
    
    /// VM state (running, halted, errored).
    state: u32,
    
    /// Last error (if state == errored).
    last_error: u32,
    
    /// Memory size in bytes.
    memory_size: u64,
    
    /// Performance metrics snapshot.
    /// Why: Capture performance state for analysis.
    performance: PerformanceSnapshot,
    
    /// Error log entry count.
    error_count: u32,
    
    /// Exception statistics snapshot.
    /// Why: Capture exception statistics for debugging and analysis.
    exception_stats: ExceptionStatsSnapshot,
    
    /// JIT enabled flag.
    jit_enabled: bool,
    
    /// Create snapshot from VM state.
    /// Why: Capture current VM state for persistence.
    /// Contract: VM must be initialized, memory buffer must be provided.
    pub fn create(vm: *const VM, memory_buffer: []u8) !VMStateSnapshot {
        // Assert: VM must be initialized (precondition).
        std.debug.assert(vm.memory_size > 0);
        std.debug.assert(vm.memory.len > 0);
        
        // Assert: Memory buffer must be large enough (precondition).
        std.debug.assert(memory_buffer.len >= vm.memory.len);
        
        // Capture register file (32 GP registers + PC).
        var regs: [33]u64 = undefined;
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            regs[i] = vm.regs.get(@as(u5, @intCast(i)));
        }
        regs[32] = vm.regs.pc;
        
        // Copy memory (complete VM memory).
        @memcpy(memory_buffer[0..vm.memory.len], vm.memory[0..vm.memory.len]);
        
        // Capture VM state.
        const state_val: u32 = switch (vm.state) {
            .running => 0,
            .halted => 1,
            .errored => 2,
        };
        
        // Capture last error.
        const last_error_val: u32 = if (vm.last_error) |err| blk: {
            if (err == VM.VMError.invalid_instruction) break :blk 0;
            if (err == VM.VMError.invalid_memory_access) break :blk 1;
            if (err == VM.VMError.unaligned_instruction) break :blk 2;
            if (err == VM.VMError.unaligned_memory_access) break :blk 3;
            break :blk 255; // Unknown error
        } else 255; // No error
        
        // Capture performance metrics.
        const perf = vm.performance;
        const performance_snapshot: PerformanceSnapshot = .{
            .instructions_executed = perf.instructions_executed,
            .cycles_simulated = perf.cycles_simulated,
            .memory_reads = perf.memory_reads,
            .memory_writes = perf.memory_writes,
            .syscalls = perf.syscalls,
            .jit_compilations = perf.jit_compilations,
            .jit_cache_hits = perf.jit_cache_hits,
            .jit_cache_misses = perf.jit_cache_misses,
            .interpreter_fallbacks = perf.interpreter_fallbacks,
        };
        
        // Capture exception statistics.
        const exc_stats = vm.exception_stats;
        var exception_counts: [16]u64 = undefined;
        var exc_i: u32 = 0;
        while (exc_i < 16) : (exc_i += 1) {
            exception_counts[exc_i] = exc_stats.exception_counts[exc_i];
        }
        const exception_stats_snapshot: ExceptionStatsSnapshot = .{
            .exception_counts = exception_counts,
            .total_count = exc_stats.total_count,
        };
        
        // Create snapshot.
        const snapshot = VMStateSnapshot{
            .regs = regs,
            .memory = memory_buffer[0..vm.memory.len],
            .state = state_val,
            .last_error = last_error_val,
            .memory_size = vm.memory_size,
            .performance = performance_snapshot,
            .error_count = vm.error_log.entry_count,
            .exception_stats = exception_stats_snapshot,
            .jit_enabled = vm.jit_enabled,
        };
        
        // Assert: Snapshot must be valid (postcondition).
        std.debug.assert(snapshot.memory.len == vm.memory.len);
        std.debug.assert(snapshot.memory_size == vm.memory_size);
        
        return snapshot;
    }
    
    /// Restore VM state from snapshot.
    /// Why: Restore VM to saved state for debugging and testing.
    /// Contract: VM must be initialized, snapshot must be valid.
    pub fn restore(self: *const VMStateSnapshot, vm: *VM) !void {
        // Assert: VM must be initialized (precondition).
        std.debug.assert(vm.memory_size > 0);
        
        // Assert: Snapshot memory size must match VM memory size (precondition).
        std.debug.assert(self.memory_size == vm.memory_size);
        std.debug.assert(self.memory.len == vm.memory.len);
        
        // Restore register file (32 GP registers + PC).
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            vm.regs.set(@as(u5, @intCast(i)), self.regs[i]);
        }
        vm.regs.pc = self.regs[32];
        
        // Restore memory (complete VM memory).
        @memcpy(vm.memory[0..self.memory.len], self.memory[0..self.memory.len]);
        
        // Restore VM state.
        vm.state = switch (self.state) {
            0 => .running,
            1 => .halted,
            2 => .errored,
            else => .halted, // Default to halted for invalid state.
        };
        
        // Restore last error.
        vm.last_error = switch (self.last_error) {
            0 => VMError.invalid_instruction,
            1 => VMError.invalid_memory_access,
            2 => VMError.unaligned_instruction,
            3 => VMError.unaligned_memory_access,
            else => null, // No error.
        };
        
        // Restore performance metrics.
        vm.performance.instructions_executed = self.performance.instructions_executed;
        vm.performance.cycles_simulated = self.performance.cycles_simulated;
        vm.performance.memory_reads = self.performance.memory_reads;
        vm.performance.memory_writes = self.performance.memory_writes;
        vm.performance.syscalls = self.performance.syscalls;
        vm.performance.jit_compilations = self.performance.jit_compilations;
        vm.performance.jit_cache_hits = self.performance.jit_cache_hits;
        vm.performance.jit_cache_misses = self.performance.jit_cache_misses;
        vm.performance.interpreter_fallbacks = self.performance.interpreter_fallbacks;
        
        // Restore exception statistics.
        var exc_i: u32 = 0;
        while (exc_i < 16) : (exc_i += 1) {
            vm.exception_stats.exception_counts[exc_i] = self.exception_stats.exception_counts[exc_i];
        }
        vm.exception_stats.total_count = self.exception_stats.total_count;
        
        // Note: Error log and JIT state are not restored (can be recreated).
        // Why: Error log is for debugging, JIT can be recompiled.
        
        // Assert: VM state must be restored correctly (postcondition).
        std.debug.assert(vm.regs.pc == self.regs[32]);
        std.debug.assert(vm.memory_size == self.memory_size);
    }
    
    /// Validate snapshot consistency.
    /// Why: Verify snapshot is valid before restoration.
    /// Returns: true if valid, false otherwise.
    pub fn is_valid(self: *const VMStateSnapshot) bool {
        // Assert: Memory size must be valid.
        if (self.memory_size == 0) {
            return false;
        }
        
        // Assert: Memory buffer must match memory size.
        if (self.memory.len != self.memory_size) {
            return false;
        }
        
        // Assert: State must be valid (0-2).
        if (self.state > 2) {
            return false;
        }
        
        // Assert: PC must be 4-byte aligned (RISC-V requirement).
        if (self.regs[32] % 4 != 0) {
            return false;
        }
        
        return true;
    }
};
