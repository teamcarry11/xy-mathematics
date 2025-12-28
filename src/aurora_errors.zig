/// Aurora Agent Error Types: Structured error handling for HTTP, LLM, and DAG operations.
/// ~<~ Glow Airbend: explicit error types, bounded error context.
/// ~~~~ Glow Waterbend: errors flow deterministically through system.
///
/// This module defines structured error types for Aurora Agent operations.
/// Error types are designed to be refined based on coordination with Core Agent,
/// Court Agent, and DAG Core maintainers.
///
/// **Status**: ⏳ **PRELIMINARY** — Will be refined based on coordination
/// - Core Agent: HTTP client timeout/error handling patterns
/// - Court Agent: LLM provider error types
/// - DAG Core: DAG operation error types
const std = @import("std");

/// HTTP client error types.
/// Used by `dream_http_client.zig` for HTTP request errors.
pub const HttpError = error{
    /// Request timed out (no response within timeout period).
    Timeout,
    /// Network connection failed (DNS resolution, TCP connection).
    NetworkError,
    /// HTTP response status indicates error (4xx, 5xx).
    HttpStatusError,
    /// Rate limited (429 Too Many Requests).
    RateLimited,
    /// Response body too large (exceeds MAX_RESPONSE_SIZE).
    ResponseTooLarge,
    /// Request body too large (exceeds MAX_REQUEST_SIZE).
    RequestTooLarge,
    /// Invalid URL format.
    InvalidUrl,
    /// TLS/SSL handshake failed.
    TlsError,
    /// Invalid HTTP response format.
    InvalidResponse,
    /// Server unavailable (503 Service Unavailable).
    ServiceUnavailable,
};

/// LLM request error types.
/// Used by `aurora_glm46.zig` for LLM API request errors.
pub const LlmError = error{
    /// LLM request timed out (no response within timeout period).
    Timeout,
    /// Network error during LLM request (connection failed).
    NetworkError,
    /// LLM API returned error response (API error, not network).
    ApiError,
    /// Rate limited by LLM API (429 Too Many Requests).
    RateLimited,
    /// Invalid response format from LLM API.
    InvalidResponse,
    /// Context window exceeded (too many tokens).
    ContextWindowExceeded,
    /// Invalid request format (malformed JSON, missing fields).
    InvalidRequest,
    /// Authentication failed (invalid API key).
    AuthenticationError,
    /// Service unavailable (503 Service Unavailable).
    ServiceUnavailable,
};

/// DAG operation error types.
/// Used by `aurora_dag_integration.zig` and `dream_browser_dag_integration.zig`.
/// **Note**: Will be refined based on DAG Core coordination.
pub const DagError = error{
    /// DAG node limit exceeded (DAG_MAX_NODES reached).
    NodeLimitExceeded,
    /// DAG event limit exceeded (DAG_MAX_EVENTS reached).
    EventLimitExceeded,
    /// Invalid event data (malformed event, missing fields).
    InvalidEventData,
    /// DAG corruption detected (inconsistent state).
    DagCorruption,
    /// Node not found in DAG.
    NodeNotFound,
    /// Event not found in DAG.
    EventNotFound,
    /// Invalid DAG operation (invalid parameters).
    InvalidOperation,
};

/// WebSocket error types.
/// Used by `dream_browser_websocket.zig` for WebSocket connection errors.
pub const WebSocketError = error{
    /// WebSocket connection timed out (handshake timeout).
    ConnectionTimeout,
    /// WebSocket message send timed out.
    SendTimeout,
    /// WebSocket connection failed (network error).
    ConnectionError,
    /// WebSocket handshake failed (invalid response).
    HandshakeError,
    /// WebSocket frame parsing failed (invalid frame format).
    FrameParseError,
    /// WebSocket connection closed unexpectedly.
    UnexpectedClose,
    /// WebSocket protocol error (invalid opcode, invalid state).
    ProtocolError,
};

/// Error context structure for providing additional error information.
/// Used to provide context about errors (status code, error message, etc.).
pub const ErrorContext = struct {
    /// HTTP status code (if applicable).
    status_code: ?u16 = null,
    /// Error message (if available).
    message: []const u8 = "",
    /// Error details (if available).
    details: []const u8 = "",
};

/// Check if HTTP error is retryable.
/// Retryable errors: Timeout, NetworkError, RateLimited, ServiceUnavailable.
/// Non-retryable errors: ResponseTooLarge, RequestTooLarge, InvalidUrl, TlsError, InvalidResponse.
pub fn isHttpErrorRetryable(err: HttpError) bool {
    return switch (err) {
        .Timeout, .NetworkError, .RateLimited, .ServiceUnavailable => true,
        .HttpStatusError, .ResponseTooLarge, .RequestTooLarge, .InvalidUrl, .TlsError, .InvalidResponse => false,
    };
}

/// Check if LLM error is retryable.
/// Retryable errors: Timeout, NetworkError, RateLimited, ServiceUnavailable.
/// Non-retryable errors: ApiError, InvalidResponse, ContextWindowExceeded, InvalidRequest, AuthenticationError.
pub fn isLlmErrorRetryable(err: LlmError) bool {
    return switch (err) {
        .Timeout, .NetworkError, .RateLimited, .ServiceUnavailable => true,
        .ApiError, .InvalidResponse, .ContextWindowExceeded, .InvalidRequest, .AuthenticationError => false,
    };
}

/// Check if DAG error is retryable.
/// Retryable errors: None (all DAG errors are non-retryable).
/// Non-retryable errors: All DAG errors indicate permanent failures.
pub fn isDagErrorRetryable(err: DagError) bool {
    _ = err;
    return false;
}

/// Check if WebSocket error is retryable.
/// Retryable errors: ConnectionTimeout, SendTimeout, ConnectionError, UnexpectedClose.
/// Non-retryable errors: HandshakeError, FrameParseError, ProtocolError.
pub fn isWebSocketErrorRetryable(err: WebSocketError) bool {
    return switch (err) {
        .ConnectionTimeout, .SendTimeout, .ConnectionError, .UnexpectedClose => true,
        .HandshakeError, .FrameParseError, .ProtocolError => false,
    };
}

/// Convert HTTP status code to HttpError.
/// Returns appropriate HttpError based on HTTP status code.
pub fn httpStatusToError(status_code: u16) ?HttpError {
    return switch (status_code) {
        429 => HttpError.RateLimited,
        503 => HttpError.ServiceUnavailable,
        400...499 => HttpError.HttpStatusError,
        500...599 => HttpError.HttpStatusError,
        else => null,
    };
}

/// Get retry delay for retryable errors (exponential backoff).
/// Returns delay in milliseconds based on retry attempt (1s, 2s, 4s, 8s).
/// Max retries: 3 (attempts 0, 1, 2).
pub fn getRetryDelayMs(attempt: u32) u32 {
    std.debug.assert(attempt < 3);
    return switch (attempt) {
        0 => 1_000,   // 1 second
        1 => 2_000,   // 2 seconds
        2 => 4_000,   // 4 seconds
        else => 8_000, // 8 seconds (max)
    };
}

/// Max retry attempts for retryable errors.
pub const MAX_RETRY_ATTEMPTS: u32 = 3;

/// Default timeout values (in milliseconds).
pub const TimeoutConfig = struct {
    /// Default HTTP request timeout (30 seconds).
    pub const HTTP_REQUEST_MS: u32 = 30_000;
    /// Default HTTP content fetch timeout (60 seconds).
    pub const HTTP_CONTENT_MS: u32 = 60_000;
    /// Default LLM completion request timeout (60 seconds).
    pub const LLM_COMPLETION_MS: u32 = 60_000;
    /// Default WebSocket connection timeout (10 seconds).
    pub const WEBSOCKET_CONNECT_MS: u32 = 10_000;
    /// Default WebSocket message send timeout (5 seconds).
    pub const WEBSOCKET_SEND_MS: u32 = 5_000;
};
