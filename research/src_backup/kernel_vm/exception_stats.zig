//! Exception Statistics Tracking System
//!
//! Objective: Track exception counts by type for debugging and monitoring.
//! Why: Monitor exception frequency, identify problematic code patterns, and validate exception handling.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track exception counts by type (illegal instruction, misaligned access, etc.)
//! - Track total exception count
//! - Provide statistics interface for querying exception data
//! - Reset capability for new measurement periods
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded counters: fixed-size counters (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive exception tracking, deterministic behavior, explicit limits

const std = @import("std");

/// Maximum number of exception types (RISC-V has 16 exception codes).
/// Why: Bounded array size for exception counters.
const MAX_EXCEPTION_TYPES: u32 = 16;

/// Exception statistics tracker.
/// Why: Track exception counts by type for debugging and monitoring.
/// GrainStyle: Explicit types, bounded counters, deterministic tracking.
pub const ExceptionStats = struct {
    /// Exception counts by type (indexed by exception code).
    /// Why: Track how many times each exception type occurs.
    exception_counts: [MAX_EXCEPTION_TYPES]u64 = [_]u64{0} ** MAX_EXCEPTION_TYPES,
    
    /// Total exception count (sum of all exception types).
    /// Why: Quick access to total exception count.
    total_count: u64 = 0,
    
    /// Whether statistics tracker is initialized.
    /// Why: Track initialization state for safety.
    initialized: bool = false,
    
    /// Initialize exception statistics tracker.
    /// Why: Set up statistics tracker state.
    /// Contract: Must be called once before use.
    pub fn init() ExceptionStats {
        return ExceptionStats{
            .exception_counts = [_]u64{0} ** MAX_EXCEPTION_TYPES,
            .total_count = 0,
            .initialized = true,
        };
    }
    
    /// Record exception occurrence.
    /// Why: Track exception for statistics.
    /// Contract: Exception type must be valid (< 16).
    pub fn record_exception(self: *ExceptionStats, exception_type: u32) void {
        // Assert: Statistics tracker must be initialized (precondition).
        std.debug.assert(self.initialized);
        
        // Assert: Exception type must be valid (precondition).
        std.debug.assert(exception_type < MAX_EXCEPTION_TYPES);
        
        // Increment exception count for this type.
        self.exception_counts[exception_type] += 1;
        self.total_count += 1;
        
        // Assert: Counters must be consistent (postcondition).
        std.debug.assert(self.exception_counts[exception_type] > 0);
        std.debug.assert(self.total_count > 0);
        std.debug.assert(self.total_count >= self.exception_counts[exception_type]);
    }
    
    /// Get exception count for specific type.
    /// Why: Query exception frequency for specific exception type.
    /// Contract: Exception type must be valid (< 16).
    pub fn get_count(self: *const ExceptionStats, exception_type: u32) u64 {
        // Assert: Statistics tracker must be initialized (precondition).
        std.debug.assert(self.initialized);
        
        // Assert: Exception type must be valid (precondition).
        std.debug.assert(exception_type < MAX_EXCEPTION_TYPES);
        
        const count = self.exception_counts[exception_type];
        
        // Assert: Count must be valid (postcondition).
        std.debug.assert(count <= self.total_count);
        
        return count;
    }
    
    /// Get total exception count.
    /// Why: Query total exception frequency.
    pub fn get_total_count(self: *const ExceptionStats) u64 {
        // Assert: Statistics tracker must be initialized (precondition).
        std.debug.assert(self.initialized);
        
        return self.total_count;
    }
    
    /// Get exception statistics summary.
    /// Why: Get complete exception statistics for analysis.
    pub fn get_summary(self: *const ExceptionStats) ExceptionSummary {
        // Assert: Statistics tracker must be initialized (precondition).
        std.debug.assert(self.initialized);
        
        var summary = ExceptionSummary{
            .total_count = self.total_count,
            .illegal_instruction = self.exception_counts[2], // Exception code 2
            .load_address_misaligned = self.exception_counts[4], // Exception code 4
            .store_address_misaligned = self.exception_counts[6], // Exception code 6
            .load_access_fault = self.exception_counts[5], // Exception code 5
            .store_access_fault = self.exception_counts[7], // Exception code 7
            .instruction_access_fault = self.exception_counts[1], // Exception code 1
            .instruction_address_misaligned = self.exception_counts[0], // Exception code 0
            .environment_call = self.exception_counts[8] + self.exception_counts[9], // Codes 8 and 9
            .page_faults = self.exception_counts[12] + self.exception_counts[13] + self.exception_counts[15], // Codes 12, 13, 15
            .other = 0,
        };
        
        // Calculate "other" count (exceptions not in summary).
        var other_count: u64 = 0;
        for (0..MAX_EXCEPTION_TYPES) |i| {
            const exception_code = @as(u32, @intCast(i));
            if (exception_code != 0 and exception_code != 1 and exception_code != 2 and
                exception_code != 4 and exception_code != 5 and exception_code != 6 and
                exception_code != 7 and exception_code != 8 and exception_code != 9 and
                exception_code != 12 and exception_code != 13 and exception_code != 15) {
                other_count += self.exception_counts[i];
            }
        }
        summary.other = other_count;
        
        // Assert: Summary must be consistent (postcondition).
        const calculated_total = summary.illegal_instruction + summary.load_address_misaligned +
            summary.store_address_misaligned + summary.load_access_fault +
            summary.store_access_fault + summary.instruction_access_fault +
            summary.instruction_address_misaligned + summary.environment_call +
            summary.page_faults + summary.other;
        std.debug.assert(calculated_total == summary.total_count);
        
        return summary;
    }
    
    /// Reset all exception statistics.
    /// Why: Clear statistics for new measurement period.
    pub fn reset(self: *ExceptionStats) void {
        // Assert: Statistics tracker must be initialized (precondition).
        std.debug.assert(self.initialized);
        
        // Reset all counters.
        for (0..MAX_EXCEPTION_TYPES) |i| {
            self.exception_counts[i] = 0;
        }
        self.total_count = 0;
        
        // Assert: Statistics must be reset (postcondition).
        std.debug.assert(self.total_count == 0);
        for (0..MAX_EXCEPTION_TYPES) |i| {
            std.debug.assert(self.exception_counts[i] == 0);
        }
    }
    
    /// Print exception statistics summary.
    /// Why: Display statistics for debugging and monitoring.
    pub fn print_summary(self: *const ExceptionStats) void {
        // Assert: Statistics tracker must be initialized (precondition).
        std.debug.assert(self.initialized);
        
        const summary = self.get_summary();
        
        std.debug.print("=== Exception Statistics ===\n", .{});
        std.debug.print("Total exceptions: {}\n", .{summary.total_count});
        std.debug.print("Illegal instruction: {}\n", .{summary.illegal_instruction});
        std.debug.print("Load address misaligned: {}\n", .{summary.load_address_misaligned});
        std.debug.print("Store address misaligned: {}\n", .{summary.store_address_misaligned});
        std.debug.print("Load access fault: {}\n", .{summary.load_access_fault});
        std.debug.print("Store access fault: {}\n", .{summary.store_access_fault});
        std.debug.print("Instruction access fault: {}\n", .{summary.instruction_access_fault});
        std.debug.print("Instruction address misaligned: {}\n", .{summary.instruction_address_misaligned});
        std.debug.print("Environment calls: {}\n", .{summary.environment_call});
        std.debug.print("Page faults: {}\n", .{summary.page_faults});
        std.debug.print("Other exceptions: {}\n", .{summary.other});
        std.debug.print("===========================\n", .{});
    }
};

/// Exception statistics summary.
/// Why: Structured summary of exception statistics for analysis.
/// GrainStyle: Explicit types, clear structure.
pub const ExceptionSummary = struct {
    /// Total exception count.
    total_count: u64,
    /// Illegal instruction exceptions (code 2).
    illegal_instruction: u64,
    /// Load address misaligned exceptions (code 4).
    load_address_misaligned: u64,
    /// Store address misaligned exceptions (code 6).
    store_address_misaligned: u64,
    /// Load access fault exceptions (code 5).
    load_access_fault: u64,
    /// Store access fault exceptions (code 7).
    store_access_fault: u64,
    /// Instruction access fault exceptions (code 1).
    instruction_access_fault: u64,
    /// Instruction address misaligned exceptions (code 0).
    instruction_address_misaligned: u64,
    /// Environment call exceptions (codes 8, 9).
    environment_call: u64,
    /// Page fault exceptions (codes 12, 13, 15).
    page_faults: u64,
    /// Other exceptions (not in above categories).
    other: u64,
};

