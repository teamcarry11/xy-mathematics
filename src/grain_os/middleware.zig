//! Grain OS Middleware: Common middleware functions for API server.
//!
//! Why: Provide reusable middleware for authentication, CORS, logging, rate limiting.
//! Architecture: Middleware functions that can be registered with API routes.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const api_server = @import("api_server.zig");

// CORS middleware: Add CORS headers to response.
pub fn cors_middleware(
    _request: *api_server.HttpRequest,
    response: *api_server.HttpResponse,
) bool {
    _ = _request;
    std.debug.assert(response != null);
    _ = response.add_header("Access-Control-Allow-Origin", "*");
    _ = response.add_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS");
    _ = response.add_header("Access-Control-Allow-Headers", "Content-Type, Authorization");
    _ = response.add_header("Access-Control-Max-Age", "3600");
    return true;
}

// Logging middleware: Log request method and path (stub for now).
pub fn logging_middleware(
    request: *api_server.HttpRequest,
    _response: *api_server.HttpResponse,
) bool {
    std.debug.assert(request != null);
    _ = _response;
    const method_str = switch (request.method) {
        api_server.HttpMethod.get => "GET",
        api_server.HttpMethod.post => "POST",
        api_server.HttpMethod.put => "PUT",
        api_server.HttpMethod.delete => "DELETE",
        api_server.HttpMethod.patch => "PATCH",
        api_server.HttpMethod.head => "HEAD",
        api_server.HttpMethod.options => "OPTIONS",
    };
    const path = request.path[0..request.path_len];
    _ = method_str;
    _ = path;
    return true;
}

// Rate limiting middleware: Check rate limit (stub for now).
pub fn rate_limit_middleware(
    _request: *api_server.HttpRequest,
    response: *api_server.HttpResponse,
) bool {
    std.debug.assert(_request != null);
    std.debug.assert(response != null);
    _ = _request;
    _ = response;
    return true;
}

// Authentication middleware: Check Authorization header (stub for now).
pub fn auth_middleware(
    request: *api_server.HttpRequest,
    response: *api_server.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    if (request.get_header("Authorization")) |auth_header| {
        _ = auth_header;
        return true;
    }
    response.status = api_server.HttpStatus.unauthorized;
    _ = response.add_header("Content-Type", "application/json");
    const error_body = "{\"error\":\"unauthorized\",\"message\":\"Missing Authorization header\"}";
    var i: u32 = 0;
    while (i < error_body.len and i < api_server.MAX_RESPONSE_SIZE) : (i += 1) {
        response.body[i] = error_body[i];
    }
    response.body_len = @intCast(error_body.len);
    return false;
}

// Content-Type validation middleware: Check Content-Type header.
pub fn content_type_middleware(
    request: *api_server.HttpRequest,
    response: *api_server.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    if (request.method == api_server.HttpMethod.get or request.method == api_server.HttpMethod.delete) {
        return true;
    }
    if (request.get_header("Content-Type")) |content_type| {
        if (std.mem.startsWith(u8, content_type, "application/json")) {
            return true;
        }
    }
    response.status = api_server.HttpStatus.bad_request;
    _ = response.add_header("Content-Type", "application/json");
    const error_body = "{\"error\":\"bad_request\",\"message\":\"Content-Type must be application/json\"}";
    const body_len = @min(error_body.len, api_server.MAX_RESPONSE_SIZE);
    var i: u32 = 0;
    while (i < body_len) : (i += 1) {
        response.body[i] = error_body[i];
    }
    response.body_len = @intCast(body_len);
    return false;
}

