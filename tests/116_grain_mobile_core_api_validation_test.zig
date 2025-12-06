//! Tests for Grain Mobile Core API request validation.
//!
//! Why: Verify API request validation functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_carry_core = @import("grain_carry_core");
const api = grain_carry_core.api;

test "validate register request valid" {
    const email = "user@example.com";
    const password = "MySecurePassword123!With32CharsMinimum";
    const username = "testuser";
    
    const req = api.models.RegisterRequest.init(email, password, username);
    const is_valid = api.validation.validate_register_request(&req);
    
    std.debug.assert(is_valid);
}

test "validate register request invalid email" {
    const email = "invalid-email";
    const password = "MySecurePassword123!With32CharsMinimum";
    const username = "testuser";
    
    const req = api.models.RegisterRequest.init(email, password, username);
    const is_valid = api.validation.validate_register_request(&req);
    
    std.debug.assert(!is_valid);
}

test "validate login request valid" {
    const email = "user@example.com";
    const password = "MySecurePassword123!With32CharsMinimum";
    
    const req = api.models.LoginRequest.init(email, password);
    const is_valid = api.validation.validate_login_request(&req);
    
    std.debug.assert(is_valid);
}

test "validate login request invalid password" {
    const email = "user@example.com";
    const password = "short";
    
    const req = api.models.LoginRequest.init(email, password);
    const is_valid = api.validation.validate_login_request(&req);
    
    std.debug.assert(!is_valid);
}

test "validate otp send request valid" {
    const email = "user@example.com";
    
    const req = api.models.OtpSendRequest.init(email);
    const is_valid = api.validation.validate_otp_send_request(&req);
    
    std.debug.assert(is_valid);
}

test "validate otp verify request valid" {
    const email = "user@example.com";
    const code = "123456";
    
    const req = api.models.OtpVerifyRequest.init(email, code);
    const is_valid = api.validation.validate_otp_verify_request(&req);
    
    std.debug.assert(is_valid);
}

test "validate otp verify request invalid code" {
    const email = "user@example.com";
    const code = "12345";
    
    const req = api.models.OtpVerifyRequest.init(email, code);
    const is_valid = api.validation.validate_otp_verify_request(&req);
    
    std.debug.assert(!is_valid);
}

test "validate otp verify request non-numeric code" {
    const email = "user@example.com";
    const code = "abc123";
    
    const req = api.models.OtpVerifyRequest.init(email, code);
    const is_valid = api.validation.validate_otp_verify_request(&req);
    
    std.debug.assert(!is_valid);
}

