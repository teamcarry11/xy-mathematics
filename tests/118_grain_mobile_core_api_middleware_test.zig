//! Tests for Grain Mobile Core API middleware.
//!
//! Why: Verify API middleware functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_mobile_core = @import("grain_mobile_core");
const api = grain_mobile_core.api;

test "check authentication returns authenticated" {
    const result = api.middleware.check_authentication();
    
    std.debug.assert(result == api.middleware.AuthMiddlewareResult.authenticated);
}

test "validate request body returns true" {
    const result = api.middleware.validate_request_body();
    
    std.debug.assert(result);
}

test "build error response middleware" {
    const error_code = "INVALID_INPUT";
    const message = "Invalid input provided";
    var json: [api.responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    
    const json_len = api.middleware.build_error_response_middleware(error_code, message, &json);
    
    std.debug.assert(json_len > 0);
    std.debug.assert(json_len <= api.responses.MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json[0] == '{');
}

test "build success response middleware" {
    const message = "Operation successful";
    const data = "{\"id\":123}";
    var json: [api.responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    
    const json_len = api.middleware.build_success_response_middleware(message, data, &json);
    
    std.debug.assert(json_len > 0);
    std.debug.assert(json_len <= api.responses.MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json[0] == '{');
}

test "auth middleware result enum values" {
    std.debug.assert(@intFromEnum(api.middleware.AuthMiddlewareResult.authenticated) == 0);
    std.debug.assert(@intFromEnum(api.middleware.AuthMiddlewareResult.missing_token) == 1);
    std.debug.assert(@intFromEnum(api.middleware.AuthMiddlewareResult.invalid_token) == 2);
}

