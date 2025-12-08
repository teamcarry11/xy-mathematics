// API middleware helpers for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Provides middleware functions for authentication, validation, etc.
// Ready for use with Grain OS API Server middleware framework

const std = @import("std");
const models = @import("models.zig");
const responses = @import("responses.zig");

// Authentication middleware result
pub const AuthMiddlewareResult = enum(u8) {
    authenticated,
    missing_token,
    invalid_token,
    expired_token,
};

// Authentication middleware
// Note: This will be adapted to use Grain OS API Server middleware when integrated
pub fn check_authentication(
    // token: []const u8,  // JWT token from request headers (when JSON support available)
) AuthMiddlewareResult {
    // TODO: When JSON support and auth service available:
    // 1. Extract JWT token from request headers
    // 2. Validate JWT token using JWT validation
    // 3. Check token expiration
    // 4. Return authentication result
    
    return AuthMiddlewareResult.authenticated;
}

// Request validation middleware
pub fn validate_request_body(
    // body: []const u8,  // Request body (when JSON support available)
) bool {
    // TODO: When JSON support available:
    // 1. Parse JSON request body
    // 2. Validate required fields
    // 3. Return validation result
    
    return true;
}

// Error response builder middleware
pub fn build_error_response_middleware(
    error_code: []const u8,
    message: []const u8,
    json_out: []u8,
) u32 {
    std.debug.assert(error_code.len > 0);
    std.debug.assert(error_code.len <= 32);
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= models.MAX_MESSAGE_LEN);
    std.debug.assert(json_out.len >= responses.MAX_JSON_RESPONSE_LEN);
    
    return responses.build_error_response(error_code, message, json_out);
}

// Success response builder middleware
pub fn build_success_response_middleware(
    message: []const u8,
    data: []const u8,
    json_out: []u8,
) u32 {
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= models.MAX_MESSAGE_LEN);
    std.debug.assert(data.len <= responses.MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json_out.len >= responses.MAX_JSON_RESPONSE_LEN);
    
    return responses.build_success_response(message, data, json_out);
}

