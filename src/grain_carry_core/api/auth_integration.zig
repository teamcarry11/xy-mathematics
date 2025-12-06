//! Grain Mobile Core Authentication Integration: Grain OS AuthService integration.
//!
//! Why: Integrate mobile handlers with Grain OS Authentication Service.
//! Architecture: AuthService integration, JWT validation, password hashing.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-05-140857-pst: Grain Mobile Agent

const std = @import("std");
const grain_core_auth = @import("../../grain_core/auth_service.zig");
const grain_core_api = @import("../../grain_core/api_server.zig");
const models = @import("models.zig");

// Global auth service instance (set during initialization).
var global_auth_service: ?*grain_core_auth.AuthService = null;

// Set auth service instance.
pub fn set_auth_service(service: *grain_core_auth.AuthService) void {
    global_auth_service = service;
    std.debug.assert(global_auth_service != null);
}

// Get auth service instance.
pub fn get_auth_service() ?*grain_core_auth.AuthService {
    return global_auth_service;
}

// Validate JWT token using AuthService.
pub fn validate_jwt_token(
    token: []const u8,
    current_time: u64,
    claims_out: *grain_core_auth.JwtClaims,
) bool {
    std.debug.assert(token.len > 0);
    std.debug.assert(token.len <= grain_core_auth.MAX_JWT_LEN);
    std.debug.assert(current_time > 0);
    std.debug.assert(claims_out != null);
    const service = get_auth_service() orelse {
        return false;
    };
    return service.validate_jwt_token(token, current_time, claims_out);
}

// Generate access token using AuthService.
pub fn generate_access_token(
    user_id: []const u8,
    current_time: u64,
    token_out: []u8,
) u32 {
    std.debug.assert(user_id.len > 0);
    std.debug.assert(user_id.len <= grain_core_auth.MAX_USER_ID_LEN);
    std.debug.assert(current_time > 0);
    std.debug.assert(token_out.len >= grain_core_auth.MAX_JWT_LEN);
    const service = get_auth_service() orelse {
        return 0;
    };
    return service.generate_access_token(user_id, current_time, token_out);
}

// Generate refresh token using AuthService.
pub fn generate_refresh_token(
    user_id: []const u8,
    current_time: u64,
    token_out: []u8,
) u32 {
    std.debug.assert(user_id.len > 0);
    std.debug.assert(user_id.len <= grain_core_auth.MAX_USER_ID_LEN);
    std.debug.assert(current_time > 0);
    std.debug.assert(token_out.len >= grain_core_auth.MAX_JWT_LEN);
    const service = get_auth_service() orelse {
        return 0;
    };
    return service.generate_refresh_token(user_id, current_time, token_out);
}

// Hash password using AuthService.
pub fn hash_password(
    password: []const u8,
    hash_out: []u8,
) void {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= grain_core_auth.MAX_PASSWORD_LEN);
    std.debug.assert(hash_out.len >= grain_core_auth.HASH_OUTPUT_LEN);
    grain_core_auth.AuthService.hash_password_static(password, hash_out);
    std.debug.assert(hash_out.len >= grain_core_auth.HASH_OUTPUT_LEN);
}

// Verify password using AuthService.
pub fn verify_password(
    password: []const u8,
    stored_hash: []const u8,
) bool {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= grain_core_auth.MAX_PASSWORD_LEN);
    std.debug.assert(stored_hash.len >= grain_core_auth.HASH_OUTPUT_LEN);
    return grain_core_auth.AuthService.verify_password_static(password, stored_hash);
}

// Extract JWT token from Authorization header.
pub fn extract_jwt_token_from_request(
    request: *grain_core_api.HttpRequest,
    token_out: []u8,
) u32 {
    std.debug.assert(request != null);
    std.debug.assert(token_out.len >= grain_core_auth.MAX_JWT_LEN);
    var auth_header: [grain_core_api.MAX_HEADER_VALUE_LEN]u8 = undefined;
    var auth_header_len: u32 = 0;
    var i: u32 = 0;
    while (i < request.headers_len) : (i += 1) {
        const header = &request.headers[i];
        if (std.mem.eql(
            u8,
            header.name[0..header.name_len],
            "Authorization",
        )) {
            auth_header_len = header.value_len;
            std.mem.copyForwards(
                u8,
                &auth_header,
                header.value[0..header.value_len],
            );
            break;
        }
    }
    if (auth_header_len == 0) {
        return 0;
    }
    const bearer_prefix = "Bearer ";
    if (auth_header_len < bearer_prefix.len) {
        return 0;
    }
    if (!std.mem.eql(
        u8,
        auth_header[0..bearer_prefix.len],
        bearer_prefix,
    )) {
        return 0;
    }
    const token_start = bearer_prefix.len;
    const token_len = auth_header_len - bearer_prefix.len;
    if (token_len == 0 or token_len > grain_core_auth.MAX_JWT_LEN) {
        return 0;
    }
    std.mem.copyForwards(
        u8,
        token_out[0..token_len],
        auth_header[token_start..auth_header_len],
    );
    std.debug.assert(token_len > 0);
    std.debug.assert(token_len <= grain_core_auth.MAX_JWT_LEN);
    return token_len;
}

