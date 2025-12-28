//! Grain Core File I/O Errors: Structured error types for file operations.
//!
//! Why: Replace generic anyerror with structured error unions for better error
//! handling and retryability classification.
//! Architecture: Error enum with retryability classification.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");

// File I/O error types.
pub const FileIoError = error{
    timeout,
    not_found,
    permission_denied,
    disk_full,
    invalid_path,
};

// Check if file I/O error is retryable.
pub fn is_file_io_error_retryable(err: FileIoError) bool {
    return switch (err) {
        .timeout => true,
        .disk_full => true,
        .not_found => false,
        .permission_denied => false,
        .invalid_path => false,
    };
}

// Get error message for file I/O error.
pub fn get_file_io_error_message(err: FileIoError) []const u8 {
    return switch (err) {
        .timeout => "File I/O operation timed out",
        .not_found => "File not found",
        .permission_denied => "Permission denied",
        .disk_full => "Disk full",
        .invalid_path => "Invalid file path",
    };
}
