//! VM Performance Monitoring System
//!
//! Objective: Track VM performance metrics for monitoring, optimization, and diagnostics.
//! Why: Measure execution performance, identify bottlenecks, and validate optimizations.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track instruction count, cycle count, IPC (instructions per cycle)
//! - Track memory access patterns (reads, writes, cache hits/misses)
//! - Track JIT performance (compilation time, cache hit rate)
//! - Track syscall performance (count, average latency)
//! - Provide diagnostics interface for state inspection
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded counters: fixed-size counters (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive performance tracking, deterministic behavior, explicit limits

const std = @import("std");
const exception_stats_mod = @import("exception_stats.zig");

/// Performance metrics for VM execution.
/// Why: Track execution performance for monitoring and optimization.
/// GrainStyle: Explicit types, bounded counters, deterministic tracking.
pub const PerformanceMetrics = struct {
    /// Total instructions executed (since VM start).
    /// Why: Measure total work done by VM.
    instructions_executed: u64 = 0,
    
    /// Total cycles simulated (approximate, 1 cycle per instruction).
    /// Why: Estimate execution time for performance analysis.
    cycles_simulated: u64 = 0,
    
    /// Memory read operations count.
    /// Why: Track memory access patterns for optimization.
    memory_reads: u64 = 0,
    
    /// Memory write operations count.
    /// Why: Track memory access patterns for optimization.
    memory_writes: u64 = 0,
    
    /// Syscall invocations count.
    /// Why: Track syscall frequency for optimization.
    syscalls: u64 = 0,
    
    /// JIT compilation count.
    /// Why: Track JIT activity for performance analysis.
    jit_compilations: u64 = 0,
    
    /// JIT cache hits count.
    /// Why: Measure JIT cache effectiveness.
    jit_cache_hits: u64 = 0,
    
    /// JIT cache misses count.
    /// Why: Measure JIT cache effectiveness.
    jit_cache_misses: u64 = 0,
    
    /// Interpreter fallback count (JIT failures).
    /// Why: Track JIT reliability and fallback frequency.
    interpreter_fallbacks: u64 = 0,
    
    /// Increment instruction count.
    /// Why: Track instruction execution.
    pub fn increment_instruction(self: *PerformanceMetrics) void {
        self.instructions_executed += 1;
        self.cycles_simulated += 1; // Approximate: 1 cycle per instruction.
        
        // Assert: Counters must be consistent (postcondition).
        std.debug.assert(self.instructions_executed > 0);
        std.debug.assert(self.cycles_simulated >= self.instructions_executed);
    }
    
    /// Increment memory read count.
    /// Why: Track memory read operations.
    pub fn increment_memory_read(self: *PerformanceMetrics) void {
        self.memory_reads += 1;
        
        // Assert: Counter must be consistent (postcondition).
        std.debug.assert(self.memory_reads > 0);
    }
    
    /// Increment memory write count.
    /// Why: Track memory write operations.
    pub fn increment_memory_write(self: *PerformanceMetrics) void {
        self.memory_writes += 1;
        
        // Assert: Counter must be consistent (postcondition).
        std.debug.assert(self.memory_writes > 0);
    }
    
    /// Increment syscall count.
    /// Why: Track syscall invocations.
    pub fn increment_syscall(self: *PerformanceMetrics) void {
        self.syscalls += 1;
        
        // Assert: Counter must be consistent (postcondition).
        std.debug.assert(self.syscalls > 0);
    }
    
    /// Increment JIT compilation count.
    /// Why: Track JIT compilation activity.
    pub fn increment_jit_compilation(self: *PerformanceMetrics) void {
        self.jit_compilations += 1;
        
        // Assert: Counter must be consistent (postcondition).
        std.debug.assert(self.jit_compilations > 0);
    }
    
    /// Increment JIT cache hit count.
    /// Why: Track JIT cache effectiveness.
    pub fn increment_jit_cache_hit(self: *PerformanceMetrics) void {
        self.jit_cache_hits += 1;
        
        // Assert: Counter must be consistent (postcondition).
        std.debug.assert(self.jit_cache_hits > 0);
    }
    
    /// Increment JIT cache miss count.
    /// Why: Track JIT cache effectiveness.
    pub fn increment_jit_cache_miss(self: *PerformanceMetrics) void {
        self.jit_cache_misses += 1;
        
        // Assert: Counter must be consistent (postcondition).
        std.debug.assert(self.jit_cache_misses > 0);
    }
    
    /// Increment interpreter fallback count.
    /// Why: Track JIT reliability.
    pub fn increment_interpreter_fallback(self: *PerformanceMetrics) void {
        self.interpreter_fallbacks += 1;
        
        // Assert: Counter must be consistent (postcondition).
        std.debug.assert(self.interpreter_fallbacks > 0);
    }
    
    /// Calculate instructions per cycle (IPC).
    /// Why: Measure execution efficiency.
    /// Returns: IPC ratio (instructions / cycles), or 0 if cycles is 0.
    pub fn get_ipc(self: *const PerformanceMetrics) f64 {
        if (self.cycles_simulated == 0) {
            return 0.0;
        }
        
        const ipc = @as(f64, @floatFromInt(self.instructions_executed)) / @as(f64, @floatFromInt(self.cycles_simulated));
        
        // Assert: IPC must be valid (postcondition).
        std.debug.assert(ipc >= 0.0);
        std.debug.assert(ipc <= 1.0); // Approximate: 1 cycle per instruction.
        
        return ipc;
    }
    
    /// Calculate JIT cache hit rate.
    /// Why: Measure JIT cache effectiveness.
    /// Returns: Hit rate (0.0 to 1.0), or 0 if no cache accesses.
    pub fn get_jit_cache_hit_rate(self: *const PerformanceMetrics) f64 {
        const total_cache_accesses = self.jit_cache_hits + self.jit_cache_misses;
        if (total_cache_accesses == 0) {
            return 0.0;
        }
        
        const hit_rate = @as(f64, @floatFromInt(self.jit_cache_hits)) / @as(f64, @floatFromInt(total_cache_accesses));
        
        // Assert: Hit rate must be valid (postcondition).
        std.debug.assert(hit_rate >= 0.0);
        std.debug.assert(hit_rate <= 1.0);
        
        return hit_rate;
    }
    
    /// Reset all metrics.
    /// Why: Clear metrics for new measurement period.
    pub fn reset(self: *PerformanceMetrics) void {
        self.instructions_executed = 0;
        self.cycles_simulated = 0;
        self.memory_reads = 0;
        self.memory_writes = 0;
        self.syscalls = 0;
        self.jit_compilations = 0;
        self.jit_cache_hits = 0;
        self.jit_cache_misses = 0;
        self.interpreter_fallbacks = 0;
        
        // Assert: Metrics must be reset (postcondition).
        std.debug.assert(self.instructions_executed == 0);
        std.debug.assert(self.cycles_simulated == 0);
    }
    
    /// Print performance metrics summary.
    /// Why: Display metrics for debugging and monitoring.
    pub fn print_summary(self: *const PerformanceMetrics) void {
        std.debug.print("=== VM Performance Metrics ===\n", .{});
        std.debug.print("Instructions executed: {}\n", .{self.instructions_executed});
        std.debug.print("Cycles simulated: {}\n", .{self.cycles_simulated});
        std.debug.print("IPC: {d:.3}\n", .{self.get_ipc()});
        std.debug.print("Memory reads: {}\n", .{self.memory_reads});
        std.debug.print("Memory writes: {}\n", .{self.memory_writes});
        std.debug.print("Syscalls: {}\n", .{self.syscalls});
        std.debug.print("JIT compilations: {}\n", .{self.jit_compilations});
        std.debug.print("JIT cache hits: {}\n", .{self.jit_cache_hits});
        std.debug.print("JIT cache misses: {}\n", .{self.jit_cache_misses});
        std.debug.print("JIT cache hit rate: {d:.3}\n", .{self.get_jit_cache_hit_rate()});
        std.debug.print("Interpreter fallbacks: {}\n", .{self.interpreter_fallbacks});
        std.debug.print("==============================\n", .{});
    }
};

/// Diagnostics snapshot for VM state inspection.
/// Why: Capture VM state for debugging and diagnostics.
/// GrainStyle: Explicit types, static allocation, deterministic encoding.
pub const DiagnosticsSnapshot = struct {
    /// VM state (running, halted, errored).
    state: u32,
    /// Program counter.
    pc: u64,
    /// Stack pointer (x2 register).
    sp: u64,
    /// Memory size in bytes.
    memory_size: u64,
    /// Memory usage (bytes used, approximate).
    memory_used: u64,
    /// JIT enabled flag.
    jit_enabled: bool,
    /// Error log entry count.
    error_count: u32,
    /// Performance metrics snapshot.
    metrics: PerformanceMetrics,
    /// Exception statistics snapshot.
    /// Why: Capture exception statistics for debugging and analysis.
    exception_stats: ExceptionStatsSnapshot,
    
    /// Exception statistics snapshot type.
    /// Why: Explicit type for exception statistics in diagnostics.
    pub const ExceptionStatsSnapshot = struct {
        /// Exception counts by type (16 exception types).
        exception_counts: [16]u64,
        /// Total exception count.
        total_count: u64,
    };
    
    /// Create diagnostics snapshot from VM state.
    /// Why: Capture current VM state for inspection.
    pub fn create(
        state: u32,
        pc: u64,
        sp: u64,
        memory_size: u64,
        memory_used: u64,
        jit_enabled: bool,
        error_count: u32,
        metrics: PerformanceMetrics,
        exception_stats: exception_stats_mod.ExceptionStats,
    ) DiagnosticsSnapshot {
        // Capture exception statistics.
        var exception_counts: [16]u64 = undefined;
        var i: u32 = 0;
        while (i < 16) : (i += 1) {
            exception_counts[i] = exception_stats.exception_counts[i];
        }
        const exception_stats_snapshot: DiagnosticsSnapshot.ExceptionStatsSnapshot = .{
            .exception_counts = exception_counts,
            .total_count = exception_stats.total_count,
        };
        
        return DiagnosticsSnapshot{
            .state = state,
            .pc = pc,
            .sp = sp,
            .memory_size = memory_size,
            .memory_used = memory_used,
            .jit_enabled = jit_enabled,
            .error_count = error_count,
            .metrics = metrics,
            .exception_stats = exception_stats_snapshot,
        };
    }
    
    /// Print diagnostics snapshot.
    /// Why: Display VM state for debugging.
    pub fn print(self: *const DiagnosticsSnapshot) void {
        std.debug.print("=== VM Diagnostics Snapshot ===\n", .{});
        std.debug.print("State: {}\n", .{self.state});
        std.debug.print("PC: 0x{x}\n", .{self.pc});
        std.debug.print("SP: 0x{x}\n", .{self.sp});
        std.debug.print("Memory size: {} bytes\n", .{self.memory_size});
        std.debug.print("Memory used: {} bytes\n", .{self.memory_used});
        std.debug.print("JIT enabled: {}\n", .{self.jit_enabled});
        std.debug.print("Error count: {}\n", .{self.error_count});
        self.metrics.print_summary();
        std.debug.print("Exception statistics:\n", .{});
        std.debug.print("  Total exceptions: {}\n", .{self.exception_stats.total_count});
        std.debug.print("  Illegal instruction: {}\n", .{self.exception_stats.exception_counts[2]});
        std.debug.print("  Load address misaligned: {}\n", .{self.exception_stats.exception_counts[4]});
        std.debug.print("  Store address misaligned: {}\n", .{self.exception_stats.exception_counts[6]});
        std.debug.print("  Load access fault: {}\n", .{self.exception_stats.exception_counts[5]});
        std.debug.print("  Store access fault: {}\n", .{self.exception_stats.exception_counts[7]});
        std.debug.print("================================\n", .{});
    }
};

