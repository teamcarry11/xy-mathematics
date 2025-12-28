//! Grain Core WebSocket Errors: Structured error types for WebSocket operations.
//!
//! Why: Replace generic anyerror with structured error unions for better error
//! handling and retryability classification.
//! Architecture: Error enum with retryability classification.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");

// WebSocket error types.
pub const WebSocketError = error{
    timeout,
    connection_failed,
    handshake_failed,
    message_send_failed,
    message_receive_failed,
};

// Check if WebSocket error is retryable.
pub fn is_websocket_error_retryable(err: WebSocketError) bool {
    return switch (err) {
        .timeout => true,
        .connection_failed => true,
        .handshake_failed => true,
        .message_send_failed => true,
        .message_receive_failed => true,
    };
}

// Get error message for WebSocket error.
pub fn get_websocket_error_message(err: WebSocketError) []const u8 {
    return switch (err) {
        .timeout => "WebSocket operation timed out",
        .connection_failed => "WebSocket connection failed",
        .handshake_failed => "WebSocket handshake failed",
        .message_send_failed => "WebSocket message send failed",
        .message_receive_failed => "WebSocket message receive failed",
    };
}
