//! Tests for Grain Mobile Core crypto and authentication functions.
//!
//! Why: Verify crypto and auth functionality (hashing, OTP, TOTP).
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_mobile_core = @import("grain_mobile_core");
const random = grain_mobile_core.random;
const hash = grain_mobile_core.hash;
const otp = grain_mobile_core.otp;
const totp = grain_mobile_core.totp;

test "random generation" {
    var bytes: [32]u8 = undefined;
    random.generate_random_bytes(&bytes);
    
    std.debug.assert(bytes.len == 32);
    
    // Verify bytes are not all zeros (very unlikely)
    var all_zero: bool = true;
    var i: u32 = 0;
    while (i < bytes.len) : (i += 1) {
        if (bytes[i] != 0) {
            all_zero = false;
            break;
        }
    }
    std.debug.assert(!all_zero);
}

test "password hashing and verification" {
    const password = "MySecurePassword123!With32CharsMinimum";
    
    std.debug.assert(password.len >= 32);
    
    var hash_output: [hash.HASH_OUTPUT_LEN]u8 = undefined;
    hash.hash_password(password, &hash_output);
    
    std.debug.assert(hash_output.len == hash.HASH_OUTPUT_LEN);
    
    const is_valid = hash.verify_password(password, &hash_output);
    std.debug.assert(is_valid);
    
    const wrong_password = "WrongPassword123!With32CharsMinimum";
    const is_invalid = hash.verify_password(wrong_password, &hash_output);
    std.debug.assert(!is_invalid);
}

test "OTP generation and validation" {
    const timestamp: u64 = 1000000;
    var token = otp.create_otp_token(timestamp);
    
    std.debug.assert(token.expires_at > timestamp);
    std.debug.assert(token.attempts == 0);
    std.debug.assert(!token.used);
    
    // Convert code array to slice for validation
    const code_slice = &token.code;
    
    std.debug.assert(code_slice.len == otp.OTP_LEN);
    
    const is_valid = otp.validate_otp(&token, code_slice, timestamp + 100);
    std.debug.assert(is_valid);
    std.debug.assert(token.used);
    
    // Try to use again (should fail)
    const is_invalid = otp.validate_otp(&token, code_slice, timestamp + 100);
    std.debug.assert(!is_invalid);
}

test "OTP expiration" {
    const timestamp: u64 = 1000000;
    var token = otp.create_otp_token(timestamp);
    
    const expired_time = timestamp + otp.OTP_VALIDITY_SECONDS + 1;
    const is_expired = otp.is_otp_expired(&token, expired_time);
    std.debug.assert(is_expired);
}

test "TOTP secret generation" {
    const secret = totp.generate_totp_secret();
    
    std.debug.assert(secret.len == totp.TOTP_SECRET_LEN);
}

test "TOTP code generation and validation" {
    const secret = totp.generate_totp_secret();
    const timestamp: u64 = 1000000;
    
    const code = totp.generate_totp_code(&secret, timestamp);
    
    std.debug.assert(code < 1000000);
    
    const is_valid = totp.validate_totp_code(&secret, code, timestamp);
    std.debug.assert(is_valid);
    
    const wrong_code: u32 = 123456;
    const is_invalid = totp.validate_totp_code(&secret, wrong_code, timestamp);
    std.debug.assert(!is_invalid);
}

test "TOTP code formatting" {
    const code: u32 = 123456;
    const formatted = totp.format_totp_code(code);
    
    std.debug.assert(formatted.len == totp.TOTP_CODE_LEN);
    std.debug.assert(std.mem.eql(u8, &formatted, "123456"));
}

