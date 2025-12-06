//! Tests for Grain Mobile Core Authentication Integration.
//!
//! Why: Verify authentication integration with Grain OS AuthService.
//! Architecture: Comprehensive test coverage for auth integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-05-140857-pst: Grain Mobile Agent

const std = @import("std");
const testing = std.testing;
const grain_mobile = @import("grain_carry_core");
const grain_core = @import("grain_core");
const auth_integration = grain_mobile.api.auth_integration;

test "auth integration set and get auth service" {
    const secret = "test-secret-key-for-jwt-token-generation";
    var auth_service = grain_core.auth_service.AuthService.init(secret);
    auth_integration.set_auth_service(&auth_service);
    const retrieved = auth_integration.get_auth_service();
    try testing.expect(retrieved != null);
    try testing.expect(retrieved.? == &auth_service);
}

test "auth integration generate access token" {
    const secret = "test-secret-key-for-jwt-token-generation";
    var auth_service = grain_core.auth_service.AuthService.init(secret);
    auth_integration.set_auth_service(&auth_service);
    const user_id = "test-user-123";
    const current_time = @intCast(std.time.timestamp());
    var token: [grain_core.auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = auth_integration.generate_access_token(
        user_id,
        current_time,
        &token,
    );
    try testing.expect(token_len > 0);
    try testing.expect(token_len <= grain_core.auth_service.MAX_JWT_LEN);
}

test "auth integration validate jwt token" {
    const secret = "test-secret-key-for-jwt-token-generation";
    var auth_service = grain_core.auth_service.AuthService.init(secret);
    auth_integration.set_auth_service(&auth_service);
    const user_id = "test-user-123";
    const current_time = @intCast(std.time.timestamp());
    var token: [grain_core.auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = auth_integration.generate_access_token(
        user_id,
        current_time,
        &token,
    );
    try testing.expect(token_len > 0);
    var claims: grain_core.auth_service.JwtClaims = undefined;
    const is_valid = auth_integration.validate_jwt_token(
        token[0..token_len],
        current_time,
        &claims,
    );
    try testing.expect(is_valid);
    try testing.expect(claims.user_id_len > 0);
}

test "auth integration hash and verify password" {
    const password = "test-password-123456789012345678901234";
    var hash: [grain_core.auth_service.HASH_OUTPUT_LEN]u8 = undefined;
    auth_integration.hash_password(password, &hash);
    const is_valid = auth_integration.verify_password(password, &hash);
    try testing.expect(is_valid);
    const wrong_password = "wrong-password-123456789012345678901234";
    const is_invalid = auth_integration.verify_password(wrong_password, &hash);
    try testing.expect(!is_invalid);
}

test "auth integration extract jwt token from request" {
    const secret = "test-secret-key-for-jwt-token-generation";
    var auth_service = grain_core.auth_service.AuthService.init(secret);
    auth_integration.set_auth_service(&auth_service);
    var request = grain_core.api_server.HttpRequest.init();
    const user_id = "test-user-123";
    const current_time = @intCast(std.time.timestamp());
    var token: [grain_core.auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = auth_integration.generate_access_token(
        user_id,
        current_time,
        &token,
    );
    const bearer_token = "Bearer " ++ token[0..token_len];
    _ = request.add_header("Authorization", bearer_token);
    var extracted_token: [grain_core.auth_service.MAX_JWT_LEN]u8 = undefined;
    const extracted_len = auth_integration.extract_jwt_token_from_request(
        &request,
        &extracted_token,
    );
    try testing.expect(extracted_len == token_len);
    try testing.expect(std.mem.eql(
        u8,
        token[0..token_len],
        extracted_token[0..extracted_len],
    ));
}

