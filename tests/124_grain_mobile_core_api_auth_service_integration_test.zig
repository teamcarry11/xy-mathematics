//! Tests for Grain Mobile Core API auth service integration.
//!
//! Why: Verify auth service integration functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_carry_core = @import("grain_carry_core");
const grain_core = @import("grain_core");
const api = grain_carry_core.api;

test "set and get auth service" {
    var auth_service = grain_core.auth_service.AuthService.init("test_secret_key_12345678901234567890");
    
    api.auth_integration.set_auth_service(&auth_service);
    
    std.debug.assert(api.auth_integration.get_auth_service_public() != null);
}

test "hash password" {
    const password = "MySecurePassword123!With32CharsMinimum";
    var hash: [grain_core.auth_service.HASH_OUTPUT_LEN]u8 = undefined;
    
    api.auth_integration.hash_password(password, &hash);
    
    std.debug.assert(hash.len >= grain_core.auth_service.HASH_OUTPUT_LEN);
}

test "verify password" {
    const password = "MySecurePassword123!With32CharsMinimum";
    var hash: [grain_core.auth_service.HASH_OUTPUT_LEN]u8 = undefined;
    
    api.auth_integration.hash_password(password, &hash);
    const is_valid = api.auth_service_integration.verify_password(password, &hash);
    
    std.debug.assert(is_valid);
}

test "verify password wrong password" {
    const password = "MySecurePassword123!With32CharsMinimum";
    const wrong_password = "WrongPassword123!With32CharsMinimum";
    var hash: [grain_core.auth_service.HASH_OUTPUT_LEN]u8 = undefined;
    
    api.auth_integration.hash_password(password, &hash);
    const is_valid = api.auth_service_integration.verify_password(wrong_password, &hash);
    
    std.debug.assert(!is_valid);
}

test "generate tokens for user" {
    var auth_service = grain_core.auth_service.AuthService.init("test_secret_key_12345678901234567890");
    api.auth_integration.set_auth_service(&auth_service);
    
    const user_id = "user_123456789012345678901234567890";
    const current_time: u64 = 1000000;
    var access_token: [grain_core.auth_service.MAX_JWT_LEN]u8 = undefined;
    var refresh_token: [grain_core.auth_service.MAX_JWT_LEN]u8 = undefined;
    
    const success = api.auth_service_integration.generate_tokens_for_user(
        user_id,
        current_time,
        &access_token,
        &refresh_token,
    );
    
    std.debug.assert(success);
}

test "create user session" {
    var auth_service = grain_core.auth_service.AuthService.init("test_secret_key_12345678901234567890");
    api.auth_integration.set_auth_service(&auth_service);
    
    const user_id = "user_123456789012345678901234567890";
    const current_time: u64 = 1000000;
    var session = grain_core.auth_service.Session{
        .session_id = undefined,
        .session_id_len = 0,
        .user_id = undefined,
        .user_id_len = 0,
        .created_at = 0,
        .expires_at = 0,
        .is_active = false,
    };
    
    const success = api.auth_service_integration.create_user_session(user_id, current_time, &session);
    
    std.debug.assert(success);
    std.debug.assert(session.session_id_len > 0);
    std.debug.assert(session.is_active);
}

test "validate user session" {
    var auth_service = grain_core.auth_service.AuthService.init("test_secret_key_12345678901234567890");
    api.auth_integration.set_auth_service(&auth_service);
    
    const user_id = "user_123456789012345678901234567890";
    const current_time: u64 = 1000000;
    var session = grain_core.auth_service.Session{
        .session_id = undefined,
        .session_id_len = 0,
        .user_id = undefined,
        .user_id_len = 0,
        .created_at = 0,
        .expires_at = 0,
        .is_active = false,
    };
    
    _ = api.auth_service_integration.create_user_session(user_id, current_time, &session);
    
    var validated_session = grain_core.auth_service.Session{
        .session_id = undefined,
        .session_id_len = 0,
        .user_id = undefined,
        .user_id_len = 0,
        .created_at = 0,
        .expires_at = 0,
        .is_active = false,
    };
    
    const is_valid = api.auth_service_integration.validate_user_session(
        session.session_id[0..session.session_id_len],
        current_time,
        &validated_session,
    );
    
    std.debug.assert(is_valid);
}

test "generate email OTP" {
    var auth_service = grain_core.auth_service.AuthService.init("test_secret_key_12345678901234567890");
    api.auth_integration.set_auth_service(&auth_service);
    
    const email = "user@example.com";
    const current_time: u64 = 1000000;
    var otp = grain_core.auth_service.Otp{
        .code = undefined,
        .code_len = 0,
        .email = undefined,
        .email_len = 0,
        .created_at = 0,
        .expires_at = 0,
        .is_used = false,
    };
    
    const success = api.auth_service_integration.generate_email_otp(email, current_time, &otp);
    
    std.debug.assert(success);
    std.debug.assert(otp.code_len > 0);
}

test "validate email OTP" {
    var auth_service = grain_core.auth_service.AuthService.init("test_secret_key_12345678901234567890");
    api.auth_integration.set_auth_service(&auth_service);
    
    const email = "user@example.com";
    const current_time: u64 = 1000000;
    var otp = grain_core.auth_service.Otp{
        .code = undefined,
        .code_len = 0,
        .email = undefined,
        .email_len = 0,
        .created_at = 0,
        .expires_at = 0,
        .is_used = false,
    };
    
    _ = api.auth_service_integration.generate_email_otp(email, current_time, &otp);
    
    const is_valid = api.auth_service_integration.validate_email_otp(
        email,
        otp.code[0..otp.code_len],
        current_time,
    );
    
    std.debug.assert(is_valid);
}

test "generate TOTP code" {
    const secret = "JBSWY3DPEHPK3PXP";
    const timestamp: u64 = 1000000;
    
    const code = api.auth_service_integration.generate_totp_code(secret, timestamp);
    
    std.debug.assert(code < 1000000);
}

test "validate TOTP code" {
    const secret = "JBSWY3DPEHPK3PXP";
    const timestamp: u64 = 1000000;
    
    const code = api.auth_service_integration.generate_totp_code(secret, timestamp);
    const is_valid = api.auth_service_integration.validate_totp_code(secret, code, timestamp);
    
    std.debug.assert(is_valid);
}

