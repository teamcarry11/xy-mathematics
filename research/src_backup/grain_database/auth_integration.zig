//! Grain Database Authentication Integration: AuthService integration.
//!
//! Why: Integrate database authentication with Grain Core AuthService (Phase 60).
//! Architecture: JWT validation, session management, permission checks.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-06-010807-pst: Grain Silo Agent

const std = @import("std");
const integration_os = @import("integration_os.zig");
const grain_core = @import("grain_core");
const grain_core_api_server = grain_core.api_server;
const grain_core_auth_service = grain_core.auth_service;

// Global AuthService instance (set during initialization).
var global_auth_service: ?*grain_core_auth_service.AuthService = null;

// Set AuthService instance.
pub fn set_auth_service(service: *grain_core_auth_service.AuthService) void {
    global_auth_service = service;
    std.debug.assert(global_auth_service != null);
}

// Get AuthService instance.
pub fn get_auth_service() ?*grain_core_auth_service.AuthService {
    return global_auth_service;
}

// Extract JWT token from Authorization header.
fn extract_jwt_token(
    request: *grain_core_api_server.HttpRequest,
    token_out: []u8,
) u32 {
    std.debug.assert(request != null);
    std.debug.assert(token_out.len >= grain_core_auth_service.MAX_JWT_LEN);
    const auth_header = request.get_header("Authorization") orelse return 0;
    const bearer_prefix = "Bearer ";
    if (auth_header.len < bearer_prefix.len) {
        return 0;
    }
    if (!std.mem.startsWith(u8, auth_header, bearer_prefix)) {
        return 0;
    }
    const token_start = bearer_prefix.len;
    const token_len = auth_header.len - token_start;
    if (token_len == 0 or token_len > grain_core_auth_service.MAX_JWT_LEN) {
        return 0;
    }
    std.mem.copyForwards(u8, token_out[0..token_len], auth_header[token_start..]);
    return @intCast(token_len);
}

// Enhanced database authentication middleware using AuthService.
pub fn database_auth_middleware_enhanced(
    request: *grain_core_api_server.HttpRequest,
    response: *grain_core_api_server.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const auth_service = get_auth_service() orelse {
        response.status = grain_core_api_server.HttpStatus.internal_server_error;
        return false;
    };
    var token_buf: [grain_core_auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = extract_jwt_token(request, &token_buf);
    if (token_len == 0) {
        response.status = grain_core_api_server.HttpStatus.unauthorized;
        _ = response.add_header("Content-Type", "application/json");
        const error_body = "{\"error\":\"unauthorized\",\"message\":\"Missing token\"}";
        const body_len = @min(error_body.len, grain_core_api_server.MAX_RESPONSE_SIZE);
        var i: u32 = 0;
        while (i < body_len) : (i += 1) {
            response.body[i] = error_body[i];
        }
        response.body_len = @intCast(body_len);
        return false;
    }
    var claims: grain_core_auth_service.JwtClaims = undefined;
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    const is_valid = auth_service.validate_jwt_token(
        token_buf[0..token_len],
        current_time,
        &claims,
    );
    if (!is_valid) {
        response.status = grain_core_api_server.HttpStatus.unauthorized;
        _ = response.add_header("Content-Type", "application/json");
        const error_body = "{\"error\":\"unauthorized\",\"message\":\"Invalid token\"}";
        const body_len = @min(error_body.len, grain_core_api_server.MAX_RESPONSE_SIZE);
        var i: u32 = 0;
        while (i < body_len) : (i += 1) {
            response.body[i] = error_body[i];
        }
        response.body_len = @intCast(body_len);
        return false;
    }
    std.debug.assert(token_len > 0);
    std.debug.assert(token_len <= grain_core_auth_service.MAX_JWT_LEN);
    return true;
}

// Validate session from request.
pub fn validate_session(
    request: *grain_core_api_server.HttpRequest,
    session_id_out: []u8,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(session_id_out.len >= grain_core_auth_service.MAX_SESSION_ID_LEN);
    const auth_service = get_auth_service() orelse return false;
    const session_header = request.get_header("X-Session-ID") orelse return false;
    if (session_header.len == 0 or session_header.len > grain_core_auth_service.MAX_SESSION_ID_LEN) {
        return false;
    }
    std.mem.copyForwards(u8, session_id_out[0..session_header.len], session_header);
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    return auth_service.validate_session(session_id_out[0..session_header.len], current_time);
}

// Get user ID from JWT token in request.
pub fn get_user_id_from_request(
    request: *grain_core_api_server.HttpRequest,
    user_id_out: []u8,
) u32 {
    std.debug.assert(request != null);
    std.debug.assert(user_id_out.len >= grain_core_auth_service.MAX_USER_ID_LEN);
    const auth_service = get_auth_service() orelse return 0;
    var token_buf: [grain_core_auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = extract_jwt_token(request, &token_buf);
    if (token_len == 0) {
        return 0;
    }
    var claims: grain_core_auth_service.JwtClaims = undefined;
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    if (!auth_service.validate_jwt_token(token_buf[0..token_len], current_time, &claims)) {
        return 0;
    }
    const user_id_len = @min(claims.user_id_len, user_id_out.len);
    std.mem.copyForwards(u8, user_id_out[0..user_id_len], claims.user_id[0..claims.user_id_len]);
    return user_id_len;
}

// Permission types for access control.
pub const Permission = enum(u8) {
    read,
    write,
    delete,
    admin,
};

// Check if user has permission (simplified: admin check).
pub fn check_permission(
    user_id: []const u8,
    permission: Permission,
) bool {
    std.debug.assert(user_id.len > 0);
    std.debug.assert(user_id.len <= grain_core_auth_service.MAX_USER_ID_LEN);
    _ = permission;
    if (std.mem.startsWith(u8, user_id, "admin_")) {
        return true;
    }
    if (permission == Permission.read) {
        return true;
    }
    return false;
}

// Check permission from request (extracts user ID and checks permission).
pub fn check_permission_from_request(
    request: *grain_core_api_server.HttpRequest,
    permission: Permission,
) bool {
    std.debug.assert(request != null);
    var user_id_buf: [grain_core_auth_service.MAX_USER_ID_LEN]u8 = undefined;
    const user_id_len = get_user_id_from_request(request, &user_id_buf);
    if (user_id_len == 0) {
        return false;
    }
    return check_permission(user_id_buf[0..user_id_len], permission);
}

// Create session for user from request.
pub fn create_session_from_request(
    request: *grain_core_api_server.HttpRequest,
    session_out: *grain_core_auth_service.Session,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(session_out != null);
    const auth_service = get_auth_service() orelse return false;
    var user_id_buf: [grain_core_auth_service.MAX_USER_ID_LEN]u8 = undefined;
    const user_id_len = get_user_id_from_request(request, &user_id_buf);
    if (user_id_len == 0) {
        return false;
    }
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    return auth_service.create_session(user_id_buf[0..user_id_len], current_time, session_out);
}

// Revoke session from request (logout).
pub fn revoke_session_from_request(
    request: *grain_core_api_server.HttpRequest,
) bool {
    std.debug.assert(request != null);
    const auth_service = get_auth_service() orelse return false;
    var session_id_buf: [grain_core_auth_service.MAX_SESSION_ID_LEN]u8 = undefined;
    const session_header = request.get_header("X-Session-ID") orelse return false;
    if (session_header.len == 0 or session_header.len > grain_core_auth_service.MAX_SESSION_ID_LEN) {
        return false;
    }
    std.mem.copyForwards(u8, &session_id_buf, session_header);
    return auth_service.revoke_session(session_id_buf[0..session_header.len]);
}

// Get session from request (validates and returns session).
pub fn get_session_from_request(
    request: *grain_core_api_server.HttpRequest,
    session_out: *grain_core_auth_service.Session,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(session_out != null);
    const auth_service = get_auth_service() orelse return false;
    var session_id_buf: [grain_core_auth_service.MAX_SESSION_ID_LEN]u8 = undefined;
    const session_header = request.get_header("X-Session-ID") orelse return false;
    if (session_header.len == 0 or session_header.len > grain_core_auth_service.MAX_SESSION_ID_LEN) {
        return false;
    }
    std.mem.copyForwards(u8, &session_id_buf, session_header);
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    return auth_service.validate_session(session_id_buf[0..session_header.len], current_time, session_out);
}

