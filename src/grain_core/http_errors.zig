//! Grain Core HTTP Errors: Structured error types for HTTP client operations.
//!
//! Why: Replace generic anyerror with structured error unions for better error
//! handling and retryability classification.
//! Architecture: Error enum with retryability classification.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");

// HTTP client error types.
pub const HttpClientError = error{
    timeout,
    network_error,
    dns_error,
    connection_refused,
    rate_limit,
    server_error,
    invalid_response,
};

// Check if HTTP error is retryable.
pub fn is_http_error_retryable(err: HttpClientError) bool {
    return switch (err) {
        .timeout => true,
        .network_error => true,
        .rate_limit => true,
        .server_error => true,
        .dns_error => false,
        .connection_refused => false,
        .invalid_response => false,
    };
}

// Get error message for HTTP error.
pub fn get_http_error_message(err: HttpClientError) []const u8 {
    return switch (err) {
        .timeout => "HTTP request timed out",
        .network_error => "Network error occurred",
        .dns_error => "DNS resolution failed",
        .connection_refused => "Connection refused",
        .rate_limit => "Rate limit exceeded",
        .server_error => "Server error occurred",
        .invalid_response => "Invalid response received",
    };
}
