//! Error Logging System
//!
//! Objective: Structured error logging for VM and kernel operations.
//! Why: Track errors for debugging, monitoring, and recovery decisions.
//! GrainStyle: Static allocation, bounded buffers, explicit types, deterministic logging.
//!
//! Methodology:
//! - Circular buffer for error logs (bounded, prevents memory growth)
//! - Structured error entries (timestamp, error type, message, context)
//! - Thread-safe logging (single-threaded VM, but prepare for future)
//! - Error statistics (count by type, recent errors)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size circular buffer (no dynamic allocation)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive error tracking, deterministic behavior, explicit limits

const std = @import("std");

/// Maximum number of error log entries (bounded buffer).
/// Why: Prevent unbounded memory growth, limit log size for embedded systems.
/// Note: 256 entries is sufficient for debugging, can be increased if needed.
const MAX_ERROR_LOG_ENTRIES: u32 = 256;

/// Error log entry.
/// Why: Structured error information for debugging and monitoring.
/// GrainStyle: Explicit types, static allocation, deterministic encoding.
pub const ErrorLogEntry = struct {
    /// Timestamp (monotonic nanoseconds since VM start).
    /// Why: Order errors chronologically, measure error rates.
    timestamp: u64,
    /// Error type (encoded as u32 for compact storage).
    /// Why: Categorize errors for statistics and filtering.
    error_type: u32,
    /// Error message (null-terminated string, max 64 bytes).
    /// Why: Human-readable error description.
    message: [64]u8,
    /// Message length (actual bytes used in message).
    /// Why: Avoid scanning for null terminator.
    message_len: u32,
    /// Context data (optional, for error-specific information).
    /// Why: Store additional error context (e.g., address, register values).
    context: u64,
    
    /// Initialize error log entry.
    /// Why: Create structured error entry from error information.
    /// Contract: message must be non-empty, message_len must match message length.
    pub fn init(timestamp: u64, error_type: u32, message: []const u8, context: u64) ErrorLogEntry {
        // Assert: Message must be non-empty (precondition).
        std.debug.assert(message.len > 0);
        std.debug.assert(message.len <= 64);
        
        var entry = ErrorLogEntry{
            .timestamp = timestamp,
            .error_type = error_type,
            .message = [_]u8{0} ** 64,
            .message_len = 0,
            .context = context,
        };
        
        // Copy message (truncate if too long).
        const copy_len = @min(message.len, 63);
        @memcpy(entry.message[0..copy_len], message[0..copy_len]);
        entry.message[copy_len] = 0; // Null terminator.
        entry.message_len = @as(u32, @intCast(copy_len));
        
        // Assert: Message must be copied correctly (postcondition).
        std.debug.assert(entry.message_len <= 63);
        std.debug.assert(entry.message[entry.message_len] == 0);
        
        return entry;
    }
    
    /// Get error message as slice.
    /// Why: Return message without null terminator for display.
    pub fn get_message(self: *const ErrorLogEntry) []const u8 {
        return self.message[0..self.message_len];
    }
};

/// Error log (circular buffer).
/// Why: Track recent errors for debugging and monitoring.
/// GrainStyle: Static allocation, bounded buffer, deterministic behavior.
pub const ErrorLog = struct {
    /// Error entries (circular buffer).
    entries: [MAX_ERROR_LOG_ENTRIES]ErrorLogEntry = [_]ErrorLogEntry{undefined} ** MAX_ERROR_LOG_ENTRIES,
    /// Write index (next position to write).
    write_idx: u32 = 0,
    /// Number of entries written (for full buffer detection).
    entry_count: u32 = 0,
    /// Error statistics (count by type).
    /// Why: Track error frequency for monitoring and recovery decisions.
    stats: ErrorStats = .{},
    
    /// Error statistics.
    /// Why: Aggregate error information for monitoring.
    pub const ErrorStats = struct {
        /// Total error count.
        total_errors: u32 = 0,
        /// Error count by type (indexed by error_type).
        /// Note: Limited to 32 error types (can be expanded if needed).
        errors_by_type: [32]u32 = [_]u32{0} ** 32,
        
        /// Increment error count for type.
        /// Why: Track error frequency.
        pub fn increment(self: *ErrorStats, error_type: u32) void {
            self.total_errors += 1;
            if (error_type < 32) {
                self.errors_by_type[error_type] += 1;
            }
            
            // Assert: Statistics must be consistent (postcondition).
            std.debug.assert(self.total_errors > 0);
        }
        
        /// Get error count for type.
        /// Why: Query error frequency for specific type.
        pub fn get_count(self: *const ErrorStats, error_type: u32) u32 {
            if (error_type < 32) {
                return self.errors_by_type[error_type];
            }
            return 0;
        }
    };
    
    /// Log error entry.
    /// Why: Record error for debugging and monitoring.
    /// Contract: timestamp must be monotonic, error_type must be valid.
    pub fn log(self: *ErrorLog, timestamp: u64, error_type: u32, message: []const u8, context: u64) void {
        // Assert: Message must be non-empty (precondition).
        std.debug.assert(message.len > 0);
        std.debug.assert(message.len <= 64);
        
        // Create error entry.
        const entry = ErrorLogEntry.init(timestamp, error_type, message, context);
        
        // Write to circular buffer.
        self.entries[self.write_idx] = entry;
        self.write_idx = (self.write_idx + 1) % MAX_ERROR_LOG_ENTRIES;
        
        // Update entry count (saturate at MAX_ERROR_LOG_ENTRIES).
        if (self.entry_count < MAX_ERROR_LOG_ENTRIES) {
            self.entry_count += 1;
        }
        
        // Update statistics.
        self.stats.increment(error_type);
        
        // Assert: Write index must be valid (postcondition).
        std.debug.assert(self.write_idx < MAX_ERROR_LOG_ENTRIES);
        std.debug.assert(self.entry_count <= MAX_ERROR_LOG_ENTRIES);
    }
    
    /// Get recent errors (last N entries).
    /// Why: Retrieve recent errors for debugging and display.
    /// Contract: count must be <= MAX_ERROR_LOG_ENTRIES.
    /// Returns: Slice of error entries (most recent first).
    pub fn get_recent(self: *const ErrorLog, count: u32, buffer: []ErrorLogEntry) []ErrorLogEntry {
        // Assert: Count must be valid (precondition).
        std.debug.assert(count <= MAX_ERROR_LOG_ENTRIES);
        std.debug.assert(count <= buffer.len);
        
        const actual_count = @min(count, self.entry_count);
        if (actual_count == 0) {
            return buffer[0..0];
        }
        
        // Copy entries in reverse order (most recent first).
        var i: u32 = 0;
        var read_idx: u32 = if (self.entry_count >= MAX_ERROR_LOG_ENTRIES)
            self.write_idx
        else
            0;
        
        // Start from most recent entry and work backwards.
        while (i < actual_count) : (i += 1) {
            const idx = if (read_idx == 0)
                MAX_ERROR_LOG_ENTRIES - 1
            else
                read_idx - 1;
            
            buffer[i] = self.entries[idx];
            read_idx = idx;
        }
        
        // Assert: Returned count must match actual count (postcondition).
        std.debug.assert(i == actual_count);
        
        return buffer[0..actual_count];
    }
    
    /// Clear error log.
    /// Why: Reset error log for testing or after recovery.
    pub fn clear(self: *ErrorLog) void {
        self.write_idx = 0;
        self.entry_count = 0;
        self.stats = .{};
        
        // Assert: Log must be cleared (postcondition).
        std.debug.assert(self.write_idx == 0);
        std.debug.assert(self.entry_count == 0);
        std.debug.assert(self.stats.total_errors == 0);
    }
    
    /// Get error statistics.
    /// Why: Query error statistics for monitoring.
    pub fn get_stats(self: *const ErrorLog) ErrorStats {
        return self.stats;
    }
};

/// Error type constants (for error_type field).
/// Why: Standardize error type encoding for statistics and filtering.
pub const ErrorType = enum(u32) {
    /// Invalid instruction.
    invalid_instruction = 0,
    /// Invalid memory access.
    invalid_memory_access = 1,
    /// Unaligned memory access.
    unaligned_access = 2,
    /// Syscall error.
    syscall_error = 3,
    /// JIT compilation error.
    jit_error = 4,
    /// Integration error.
    integration_error = 5,
    /// Unknown error.
    unknown = 31,
};

