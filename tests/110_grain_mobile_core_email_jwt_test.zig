//! Tests for Grain Mobile Core email authentication and JWT handling.
//!
//! Why: Verify email/password auth and JWT token functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_mobile_core = @import("grain_mobile_core");
const email_auth = grain_mobile_core.email_auth;
const jwt = grain_mobile_core.jwt;

test "create user account" {
    const email = "user@example.com";
    const password = "MySecurePassword123!With32CharsMinimum";
    const timestamp: u64 = 1000000;
    
    std.debug.assert(email.len > 0);
    std.debug.assert(password.len >= 32);
    
    var account: email_auth.UserAccount = undefined;
    const success = email_auth.create_user_account(email, password, timestamp, &account);
    
    std.debug.assert(success);
    std.debug.assert(account.email_len > 0);
    std.debug.assert(account.user_id_len > 0);
    std.debug.assert(account.created_at == timestamp);
}

test "authenticate user - valid credentials" {
    const email = "user@example.com";
    const password = "MySecurePassword123!With32CharsMinimum";
    const timestamp: u64 = 1000000;
    
    var account: email_auth.UserAccount = undefined;
    const create_success = email_auth.create_user_account(email, password, timestamp, &account);
    std.debug.assert(create_success);
    
    const auth_success = email_auth.authenticate_user(&account, email, password);
    std.debug.assert(auth_success);
}

test "authenticate user - invalid password" {
    const email = "user@example.com";
    const password = "MySecurePassword123!With32CharsMinimum";
    const wrong_password = "WrongPassword123!With32CharsMinimum";
    const timestamp: u64 = 1000000;
    
    var account: email_auth.UserAccount = undefined;
    const create_success = email_auth.create_user_account(email, password, timestamp, &account);
    std.debug.assert(create_success);
    
    const auth_success = email_auth.authenticate_user(&account, email, wrong_password);
    std.debug.assert(!auth_success);
}

test "authenticate user - invalid email" {
    const email = "user@example.com";
    const wrong_email = "wrong@example.com";
    const password = "MySecurePassword123!With32CharsMinimum";
    const timestamp: u64 = 1000000;
    
    var account: email_auth.UserAccount = undefined;
    const create_success = email_auth.create_user_account(email, password, timestamp, &account);
    std.debug.assert(create_success);
    
    const auth_success = email_auth.authenticate_user(&account, wrong_email, password);
    std.debug.assert(!auth_success);
}

test "generate session token" {
    const token = email_auth.generate_session_token();
    
    std.debug.assert(token.len == email_auth.SESSION_TOKEN_LEN);
    
    // Verify token is not all zeros (very unlikely)
    var all_zero: bool = true;
    var i: u32 = 0;
    while (i < token.len) : (i += 1) {
        if (token[i] != 0) {
            all_zero = false;
            break;
        }
    }
    std.debug.assert(!all_zero);
}

test "create and validate JWT" {
    var claims: jwt.JwtClaims = undefined;
    std.mem.copyForwards(u8, &claims.user_id, "test_user_id_123456789012345678901234567890");
    claims.user_id_len = 40;
    claims.exp = 2000000;  // Future timestamp
    claims.iat = 1000000;
    
    const secret = "my_secret_key_for_jwt_signing_32_chars";
    var token: [jwt.MAX_JWT_LEN]u8 = undefined;
    
    const token_len = jwt.create_jwt(&claims, secret, &token);
    
    std.debug.assert(token_len > 0);
    std.debug.assert(token_len <= jwt.MAX_JWT_LEN);
    
    var validated_claims: jwt.JwtClaims = undefined;
    const is_valid = jwt.validate_jwt(token[0..token_len], secret, 1500000, &validated_claims);
    
    std.debug.assert(is_valid);
    std.debug.assert(validated_claims.user_id_len > 0);
    std.debug.assert(validated_claims.exp == claims.exp);
}

test "validate JWT - expired token" {
    var claims: jwt.JwtClaims = undefined;
    std.mem.copyForwards(u8, &claims.user_id, "test_user_id");
    claims.user_id_len = 12;
    claims.exp = 1000000;  // Past timestamp
    claims.iat = 500000;
    
    const secret = "my_secret_key_for_jwt_signing_32_chars";
    var token: [jwt.MAX_JWT_LEN]u8 = undefined;
    
    const token_len = jwt.create_jwt(&claims, secret, &token);
    
    var validated_claims: jwt.JwtClaims = undefined;
    const is_valid = jwt.validate_jwt(token[0..token_len], secret, 2000000, &validated_claims);
    
    std.debug.assert(!is_valid);
}

test "validate JWT - invalid signature" {
    var claims: jwt.JwtClaims = undefined;
    std.mem.copyForwards(u8, &claims.user_id, "test_user_id");
    claims.user_id_len = 12;
    claims.exp = 2000000;
    claims.iat = 1000000;
    
    const secret = "my_secret_key_for_jwt_signing_32_chars";
    const wrong_secret = "wrong_secret_key_for_jwt_signing_32";
    var token: [jwt.MAX_JWT_LEN]u8 = undefined;
    
    const token_len = jwt.create_jwt(&claims, secret, &token);
    
    var validated_claims: jwt.JwtClaims = undefined;
    const is_valid = jwt.validate_jwt(token[0..token_len], wrong_secret, 1500000, &validated_claims);
    
    std.debug.assert(!is_valid);
}

