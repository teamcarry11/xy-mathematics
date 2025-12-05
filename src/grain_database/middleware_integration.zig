//! Grain Database Middleware Integration: Bridge Database middleware to Grain OS.
//!
//! Why: Integrate Database Agent's rate limiter and auth middleware with Grain OS API Server.
//! Architecture: Adapter functions that bridge Database middleware to Grain OS middleware.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-05-083545-pst: Grain Database Agent

const std = @import("std");
const api = @import("api.zig");
const integration_os = @import("integration_os.zig");
const grain_os_api_server = @import("../grain_os/api_server.zig");
const grain_os_middleware = @import("../grain_os/middleware.zig");

// Get database context for middleware access.
fn get_db_context() ?*integration_os.DatabaseContext {
    return integration_os.get_database_context();
}

// Database rate limiting middleware adapter.
// Uses Database Agent's RateLimiter with Grain OS middleware interface.
pub fn database_rate_limit_middleware(
    request: *grain_os_api_server.HttpRequest,
    response: *grain_os_api_server.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_db_context() orelse {
        response.status = grain_os_api_server.HttpStatus.internal_server_error;
        return false;
    };
    const client_id = extract_client_id(request) orelse {
        response.status = grain_os_api_server.HttpStatus.bad_request;
        return false;
    };
    const allowed = context.rate_limiter.check_rate_limit(client_id) catch {
        response.status = grain_os_api_server.HttpStatus.service_unavailable;
        return false;
    };
    if (!allowed) {
        response.status = grain_os_api_server.HttpStatus.service_unavailable;
        _ = response.add_header("Content-Type", "application/json");
        const error_body = "{\"error\":\"rate_limit_exceeded\"}";
        const body_len = @min(error_body.len, grain_os_api_server.MAX_RESPONSE_SIZE);
        var i: u32 = 0;
        while (i < body_len) : (i += 1) {
            response.body[i] = error_body[i];
        }
        response.body_len = @intCast(body_len);
        return false;
    }
    return true;
}

// Extract client ID from request (IP address or user ID).
fn extract_client_id(request: *grain_os_api_server.HttpRequest) ?[]const u8 {
    std.debug.assert(request != null);
    if (request.get_header("X-Client-ID")) |client_id| {
        return client_id;
    }
    if (request.get_header("X-Forwarded-For")) |forwarded| {
        return forwarded;
    }
    const unknown: []const u8 = "unknown";
    return unknown;
}

// Database authentication middleware adapter.
// Uses Grain OS auth middleware (basic Authorization header check).
// Full JWT validation can be added later when needed.
pub fn database_auth_middleware(
    request: *grain_os_api_server.HttpRequest,
    response: *grain_os_api_server.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    return grain_os_middleware.auth_middleware(request, response);
}

// Database CORS middleware adapter.
// Uses Grain OS CORS middleware (already implemented).
pub fn database_cors_middleware(
    request: *grain_os_api_server.HttpRequest,
    response: *grain_os_api_server.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    return grain_os_middleware.cors_middleware(request, response);
}

// Database content-type middleware adapter.
// Uses Grain OS content-type middleware (already implemented).
pub fn database_content_type_middleware(
    request: *grain_os_api_server.HttpRequest,
    response: *grain_os_api_server.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    return grain_os_middleware.content_type_middleware(request, response);
}

// Register database middleware with API server routes.
// This function registers CORS, rate limiting, and content-type middleware.
pub fn register_database_middleware(
    add_middleware_fn: *const fn (
        grain_os_api_server.HttpMethod,
        []const u8,
        grain_os_api_server.Middleware,
    ) bool,
) bool {
    std.debug.assert(add_middleware_fn != null);
    if (!add_middleware_fn(
        grain_os_api_server.HttpMethod.get,
        "/api/v1/records/{id}",
        database_cors_middleware,
    )) {
        return false;
    }
    if (!add_middleware_fn(
        grain_os_api_server.HttpMethod.post,
        "/api/v1/records",
        database_content_type_middleware,
    )) {
        return false;
    }
    if (!add_middleware_fn(
        grain_os_api_server.HttpMethod.post,
        "/api/v1/records",
        database_rate_limit_middleware,
    )) {
        return false;
    }
    if (!add_middleware_fn(
        grain_os_api_server.HttpMethod.put,
        "/api/v1/records/{id}",
        database_content_type_middleware,
    )) {
        return false;
    }
    if (!add_middleware_fn(
        grain_os_api_server.HttpMethod.put,
        "/api/v1/records/{id}",
        database_rate_limit_middleware,
    )) {
        return false;
    }
    if (!add_middleware_fn(
        grain_os_api_server.HttpMethod.delete,
        "/api/v1/records/{id}",
        database_rate_limit_middleware,
    )) {
        return false;
    }
    if (!add_middleware_fn(
        grain_os_api_server.HttpMethod.post,
        "/api/v1/query",
        database_auth_middleware,
    )) {
        return false;
    }
    if (!add_middleware_fn(
        grain_os_api_server.HttpMethod.post,
        "/api/v1/query",
        database_content_type_middleware,
    )) {
        return false;
    }
    if (!add_middleware_fn(
        grain_os_api_server.HttpMethod.post,
        "/api/v1/graph/traverse",
        database_auth_middleware,
    )) {
        return false;
    }
    return true;
}
