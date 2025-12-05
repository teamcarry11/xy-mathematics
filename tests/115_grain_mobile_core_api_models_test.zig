//! Tests for Grain Mobile Core API data models.
//!
//! Why: Verify API request/response model functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_mobile_core = @import("grain_mobile_core");
const api = grain_mobile_core.api;

test "register request initialization" {
    const email = "user@example.com";
    const password = "MySecurePassword123!With32CharsMinimum";
    const username = "testuser";
    
    const req = api.models.RegisterRequest.init(email, password, username);
    
    std.debug.assert(req.email_len > 0);
    std.debug.assert(req.password_len >= 32);
    std.debug.assert(req.username_len > 0);
}

test "login request initialization" {
    const email = "user@example.com";
    const password = "MySecurePassword123!With32CharsMinimum";
    
    const req = api.models.LoginRequest.init(email, password);
    
    std.debug.assert(req.email_len > 0);
    std.debug.assert(req.password_len >= 32);
}

test "otp send request initialization" {
    const email = "user@example.com";
    
    const req = api.models.OtpSendRequest.init(email);
    
    std.debug.assert(req.email_len > 0);
}

test "otp verify request initialization" {
    const email = "user@example.com";
    const code = "123456";
    
    const req = api.models.OtpVerifyRequest.init(email, code);
    
    std.debug.assert(req.email_len > 0);
    std.debug.assert(req.code_len == 6);
}

test "auth response initialization" {
    const resp = api.models.AuthResponse.init();
    
    std.debug.assert(!resp.success);
    std.debug.assert(resp.token_len == 0);
    std.debug.assert(resp.user_id_len == 0);
}

test "auth response set token" {
    var resp = api.models.AuthResponse.init();
    const token = "test_jwt_token_12345678901234567890";
    const success = resp.set_token(token);
    
    std.debug.assert(success);
    std.debug.assert(resp.token_len == token.len);
    std.debug.assert(resp.token_len > 0);
}

test "auth response set user id" {
    var resp = api.models.AuthResponse.init();
    const user_id = "user_123456789012345678901234567890";
    const success = resp.set_user_id(user_id);
    
    std.debug.assert(success);
    std.debug.assert(resp.user_id_len == user_id.len);
}

test "error response initialization" {
    const error_code = "INVALID_EMAIL";
    const message = "Invalid email address format";
    
    const err = api.models.ErrorResponse.init(error_code, message);
    
    std.debug.assert(err.error_code_len > 0);
    std.debug.assert(err.message_len > 0);
}

test "build success response" {
    const message = "Operation successful";
    const data = "{\"id\":123}";
    var json: [api.responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    
    const json_len = api.responses.build_success_response(message, data, &json);
    
    std.debug.assert(json_len > 0);
    std.debug.assert(json_len <= api.responses.MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json[0] == '{');
}

test "build error response" {
    const error_code = "INVALID_INPUT";
    const message = "Invalid input provided";
    var json: [api.responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    
    const json_len = api.responses.build_error_response(error_code, message, &json);
    
    std.debug.assert(json_len > 0);
    std.debug.assert(json_len <= api.responses.MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json[0] == '{');
}

test "build auth response" {
    var auth_resp = api.models.AuthResponse.init();
    auth_resp.success = true;
    _ = auth_resp.set_token("test_token_123");
    _ = auth_resp.set_user_id("user_123");
    var json: [api.responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    
    const json_len = api.responses.build_auth_response(&auth_resp, &json);
    
    std.debug.assert(json_len > 0);
    std.debug.assert(json_len <= api.responses.MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json[0] == '{');
}

