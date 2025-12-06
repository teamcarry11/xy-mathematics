//! Grain Mobile Core Auth Service Integration: Connect handlers to Grain OS Auth Service.
//!
//! Why: Integrate mobile handlers with Grain OS Authentication Service.
//! Architecture: Auth service helpers, JWT validation, password verification, session management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const grain_core_auth = @import("../../grain_core/auth_service.zig");
const grain_core_api = @import("../../grain_core/api_server.zig");
const models = @import("models.zig");
const responses = @import("responses.zig");

// Global auth service instance (set during initialization).
var global_auth_service: ?*grain_core_auth.AuthService = null;

// Set auth service instance.
pub fn set_auth_service(service: *grain_core_auth.AuthService) void {
    global_auth_service = service;
    std.debug.assert(global_auth_service != null);
}

// Get auth service instance (internal).
fn get_auth_service() ?*grain_core_auth.AuthService {
    return global_auth_service;
}

// Get auth service instance (public, for testing).
pub fn get_auth_service_public() ?*grain_core_auth.AuthService {
    return global_auth_service;
}

// Helper: extract Bearer token from Authorization header.
fn extract_bearer_token(auth_header: []const u8) ?[]const u8 {
    std.debug.assert(auth_header.len > 0);
    
    const bearer_prefix = "Bearer ";
    if (auth_header.len < bearer_prefix.len) {
        return null;
    }
    
    var i: u32 = 0;
    while (i < bearer_prefix.len) : (i += 1) {
        if (auth_header[i] != bearer_prefix[i]) {
            return null;
        }
    }
    
    const token = auth_header[bearer_prefix.len..];
    if (token.len == 0 or token.len > grain_core_auth.MAX_JWT_LEN) {
        return null;
    }
    
    return token;
}

// Extract and validate JWT token from HTTP request.
pub fn extract_and_validate_token(
    request: *grain_core_api.HttpRequest,
    current_time: u64,
    claims_out: *grain_core_auth.JwtClaims,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(current_time > 0);
    std.debug.assert(claims_out != null);
    
    const service = get_auth_service() orelse return false;
    const auth_header = request.get_header("Authorization") orelse return false;
    const token = extract_bearer_token(auth_header) orelse return false;
    
    const is_valid = service.validate_jwt_token(token, current_time, claims_out);
    
    std.debug.assert(!is_valid or claims_out.user_id_len > 0);
    
    return is_valid;
}

// Generate access and refresh tokens for user.
pub fn generate_tokens_for_user(
    user_id: []const u8,
    current_time: u64,
    access_token_out: []u8,
    refresh_token_out: []u8,
) bool {
    std.debug.assert(user_id.len > 0);
    std.debug.assert(user_id.len <= grain_core_auth.MAX_USER_ID_LEN);
    std.debug.assert(current_time > 0);
    std.debug.assert(access_token_out.len >= grain_core_auth.MAX_JWT_LEN);
    std.debug.assert(refresh_token_out.len >= grain_core_auth.MAX_JWT_LEN);
    
    const service = get_auth_service() orelse {
        return false;
    };
    
    const access_len = service.generate_access_token(user_id, current_time, access_token_out);
    if (access_len == 0) {
        return false;
    }
    
    const refresh_len = service.generate_refresh_token(user_id, current_time, refresh_token_out);
    if (refresh_len == 0) {
        return false;
    }
    
    std.debug.assert(access_len > 0);
    std.debug.assert(refresh_len > 0);
    
    return true;
}

// Hash password using auth service.
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

// Verify password using auth service.
pub fn verify_password(
    password: []const u8,
    stored_hash: []const u8,
) bool {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= grain_core_auth.MAX_PASSWORD_LEN);
    std.debug.assert(stored_hash.len >= grain_core_auth.HASH_OUTPUT_LEN);
    
    const is_valid = grain_core_auth.AuthService.verify_password_static(password, stored_hash);
    
    std.debug.assert(password.len > 0);
    std.debug.assert(stored_hash.len >= grain_core_auth.HASH_OUTPUT_LEN);
    
    return is_valid;
}

// Create session for user.
pub fn create_user_session(
    user_id: []const u8,
    current_time: u64,
    session_out: *grain_core_auth.Session,
) bool {
    std.debug.assert(user_id.len > 0);
    std.debug.assert(user_id.len <= grain_core_auth.MAX_USER_ID_LEN);
    std.debug.assert(current_time > 0);
    std.debug.assert(session_out != null);
    
    const service = get_auth_service() orelse {
        return false;
    };
    
    const success = service.create_session(user_id, current_time, session_out);
    
    std.debug.assert(!success or session_out.session_id_len > 0);
    
    return success;
}

// Validate session.
pub fn validate_user_session(
    session_id: []const u8,
    current_time: u64,
    session_out: ?*grain_core_auth.Session,
) bool {
    std.debug.assert(session_id.len > 0);
    std.debug.assert(session_id.len <= grain_core_auth.MAX_SESSION_ID_LEN);
    std.debug.assert(current_time > 0);
    
    const service = get_auth_service() orelse {
        return false;
    };
    
    const is_valid = service.validate_session(session_id, current_time, session_out);
    
    std.debug.assert(session_id.len > 0);
    
    return is_valid;
}

// Generate OTP for email.
pub fn generate_email_otp(
    email: []const u8,
    current_time: u64,
    otp_out: *grain_core_auth.Otp,
) bool {
    std.debug.assert(email.len > 0);
    std.debug.assert(email.len <= grain_core_auth.MAX_EMAIL_LEN);
    std.debug.assert(current_time > 0);
    std.debug.assert(otp_out != null);
    
    const service = get_auth_service() orelse {
        return false;
    };
    
    const success = service.generate_otp(email, current_time, otp_out);
    
    std.debug.assert(!success or otp_out.code_len > 0);
    
    return success;
}

// Validate OTP code.
pub fn validate_email_otp(
    email: []const u8,
    code: []const u8,
    current_time: u64,
) bool {
    std.debug.assert(email.len > 0);
    std.debug.assert(email.len <= grain_core_auth.MAX_EMAIL_LEN);
    std.debug.assert(code.len > 0);
    std.debug.assert(code.len <= grain_core_auth.MAX_OTP_CODE_LEN);
    std.debug.assert(current_time > 0);
    
    const service = get_auth_service() orelse {
        return false;
    };
    
    const is_valid = service.validate_otp(email, code, current_time);
    
    std.debug.assert(email.len > 0);
    std.debug.assert(code.len > 0);
    
    return is_valid;
}

// Generate TOTP code from secret (static function).
pub fn generate_totp_code(
    secret: []const u8,
    timestamp: u64,
) u32 {
    std.debug.assert(secret.len > 0);
    std.debug.assert(timestamp > 0);
    
    const code = grain_core_auth.AuthService.generate_totp(secret, timestamp);
    
    std.debug.assert(code < 1000000);
    
    return code;
}

// Validate TOTP code (static function).
pub fn validate_totp_code(
    secret: []const u8,
    code: u32,
    timestamp: u64,
) bool {
    std.debug.assert(secret.len > 0);
    std.debug.assert(code < 1000000);
    std.debug.assert(timestamp > 0);
    
    const is_valid = grain_core_auth.AuthService.validate_totp(secret, code, timestamp);
    
    std.debug.assert(secret.len > 0);
    std.debug.assert(code < 1000000);
    
    return is_valid;
}

// Revoke token (logout).
pub fn revoke_user_token(
    token: []const u8,
) bool {
    std.debug.assert(token.len > 0);
    std.debug.assert(token.len <= grain_core_auth.MAX_JWT_LEN);
    
    const service = get_auth_service() orelse {
        return false;
    };
    
    const success = service.revoke_token(token);
    
    std.debug.assert(token.len > 0);
    
    return success;
}

