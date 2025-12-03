// Error types and handling for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions

const std = @import("std");

pub const Error = error{
    InvalidInput,
    BufferTooSmall,
    InvalidEmail,
    InvalidPassword,
    NetworkError,
    AuthenticationFailed,
    TokenExpired,
    RateLimitExceeded,
};

pub const MAX_ERROR_MESSAGE_LEN: u32 = 256;

pub fn error_to_string(err: Error) []const u8 {
    std.debug.assert(@intFromError(err) >= 0);
    std.debug.assert(@intFromError(err) < error_count);
    
    return switch (err) {
        .InvalidInput => "Invalid input provided",
        .BufferTooSmall => "Buffer too small for operation",
        .InvalidEmail => "Invalid email address format",
        .InvalidPassword => "Invalid password format or strength",
        .NetworkError => "Network operation failed",
        .AuthenticationFailed => "Authentication failed",
        .TokenExpired => "Token has expired",
        .RateLimitExceeded => "Rate limit exceeded",
    };
}

const error_count = 8;
std.debug.assert(@typeInfo(Error).ErrorSet.?.len == error_count);

