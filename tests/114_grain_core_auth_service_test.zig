//! Tests for Grain OS Authentication Service
//! Grain Style: grain_case, u32/u64, bounded allocations, assertions

const std = @import("std");
const auth_service = @import("grain_core").auth_service;

test "auth_service_init" {
    const secret = "test_secret_key_for_jwt_signing";
    var service = auth_service.AuthService.init(secret);
    std.debug.assert(service.secret_len > 0);
    std.debug.assert(service.session_count == 0);
    std.debug.assert(service.otp_count == 0);
    std.debug.assert(service.revoked_count == 0);
}

test "auth_service_generate_access_token" {
    const secret = "test_secret_key_for_jwt_signing";
    var service = auth_service.AuthService.init(secret);
    const user_id = "user123";
    const current_time: u64 = 1000000;
    var token: [auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = service.generate_access_token(user_id, current_time, &token);
    std.debug.assert(token_len > 0);
    std.debug.assert(token_len <= auth_service.MAX_JWT_LEN);
}

test "auth_service_validate_jwt_token" {
    const secret = "test_secret_key_for_jwt_signing";
    var service = auth_service.AuthService.init(secret);
    const user_id = "user123";
    const current_time: u64 = 1000000;
    var token: [auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = service.generate_access_token(user_id, current_time, &token);
    std.debug.assert(token_len > 0);
    var claims: auth_service.JwtClaims = undefined;
    const is_valid = service.validate_jwt_token(
        token[0..token_len],
        current_time,
        &claims,
    );
    std.debug.assert(is_valid);
    std.debug.assert(claims.user_id_len > 0);
    std.debug.assert(claims.exp > current_time);
}

test "auth_service_revoke_token" {
    const secret = "test_secret_key_for_jwt_signing";
    var service = auth_service.AuthService.init(secret);
    const user_id = "user123";
    const current_time: u64 = 1000000;
    var token: [auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = service.generate_access_token(user_id, current_time, &token);
    std.debug.assert(token_len > 0);
    const revoked = service.revoke_token(token[0..token_len]);
    std.debug.assert(revoked);
    std.debug.assert(service.revoked_count == 1);
    var claims: auth_service.JwtClaims = undefined;
    const is_valid = service.validate_jwt_token(
        token[0..token_len],
        current_time,
        &claims,
    );
    std.debug.assert(!is_valid);
}

test "auth_service_hash_password" {
    const password = "test_password_123";
    var hash: [auth_service.HASH_OUTPUT_LEN]u8 = undefined;
    auth_service.AuthService.hash_password_static(password, &hash);
    std.debug.assert(hash.len == auth_service.HASH_OUTPUT_LEN);
}

test "auth_service_verify_password" {
    const password = "test_password_123";
    var hash: [auth_service.HASH_OUTPUT_LEN]u8 = undefined;
    auth_service.AuthService.hash_password_static(password, &hash);
    const is_valid = auth_service.AuthService.verify_password_static(password, &hash);
    std.debug.assert(is_valid);
    const wrong_password = "wrong_password";
    const is_invalid = auth_service.AuthService.verify_password_static(wrong_password, &hash);
    std.debug.assert(!is_invalid);
}

test "auth_service_create_session" {
    const secret = "test_secret_key_for_jwt_signing";
    var service = auth_service.AuthService.init(secret);
    const user_id = "user123";
    const current_time: u64 = 1000000;
    var session: auth_service.Session = undefined;
    const created = service.create_session(user_id, current_time, &session);
    std.debug.assert(created);
    std.debug.assert(service.session_count == 1);
    std.debug.assert(session.user_id_len > 0);
    std.debug.assert(session.is_active);
    std.debug.assert(session.expires_at > current_time);
}

test "auth_service_validate_session" {
    const secret = "test_secret_key_for_jwt_signing";
    var service = auth_service.AuthService.init(secret);
    const user_id = "user123";
    const current_time: u64 = 1000000;
    var session: auth_service.Session = undefined;
    const created = service.create_session(user_id, current_time, &session);
    std.debug.assert(created);
    const session_id = session.session_id[0..session.session_id_len];
    var validated_session: auth_service.Session = undefined;
    const is_valid = service.validate_session(session_id, current_time, &validated_session);
    std.debug.assert(is_valid);
    std.debug.assert(validated_session.user_id_len > 0);
}

test "auth_service_revoke_session" {
    const secret = "test_secret_key_for_jwt_signing";
    var service = auth_service.AuthService.init(secret);
    const user_id = "user123";
    const current_time: u64 = 1000000;
    var session: auth_service.Session = undefined;
    const created = service.create_session(user_id, current_time, &session);
    std.debug.assert(created);
    const session_id = session.session_id[0..session.session_id_len];
    const revoked = service.revoke_session(session_id);
    std.debug.assert(revoked);
    const is_valid = service.validate_session(session_id, current_time, null);
    std.debug.assert(!is_valid);
}

test "auth_service_generate_otp" {
    const secret = "test_secret_key_for_jwt_signing";
    var service = auth_service.AuthService.init(secret);
    const email = "test@example.com";
    const current_time: u64 = 1000000;
    var otp: auth_service.Otp = undefined;
    const generated = service.generate_otp(email, current_time, &otp);
    std.debug.assert(generated);
    std.debug.assert(service.otp_count == 1);
    std.debug.assert(otp.code_len > 0);
    std.debug.assert(otp.email_len > 0);
    std.debug.assert(!otp.is_used);
    std.debug.assert(otp.expires_at > current_time);
}

test "auth_service_validate_otp" {
    const secret = "test_secret_key_for_jwt_signing";
    var service = auth_service.AuthService.init(secret);
    const email = "test@example.com";
    const current_time: u64 = 1000000;
    var otp: auth_service.Otp = undefined;
    const generated = service.generate_otp(email, current_time, &otp);
    std.debug.assert(generated);
    const code = otp.code[0..otp.code_len];
    const is_valid = service.validate_otp(email, code, current_time);
    std.debug.assert(is_valid);
    const is_invalid = service.validate_otp(email, code, current_time);
    std.debug.assert(!is_invalid);
}

test "auth_service_generate_totp" {
    const secret = "test_secret_for_totp";
    const timestamp: u64 = 1000000;
    const code = auth_service.AuthService.generate_totp(secret, timestamp);
    std.debug.assert(code < 1000000);
    std.debug.assert(code >= 0);
}

test "auth_service_validate_totp" {
    const secret = "test_secret_for_totp";
    const timestamp: u64 = 1000000;
    const code = auth_service.AuthService.generate_totp(secret, timestamp);
    const is_valid = auth_service.AuthService.validate_totp(secret, code, timestamp);
    std.debug.assert(is_valid);
    const wrong_code: u32 = 123456;
    const is_invalid = auth_service.AuthService.validate_totp(secret, wrong_code, timestamp);
    std.debug.assert(!is_invalid);
}

