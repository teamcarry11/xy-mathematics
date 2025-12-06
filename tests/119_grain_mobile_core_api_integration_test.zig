//! Tests for Grain Mobile Core API HTTP integration.
//!
//! Why: Verify HTTP request/response integration functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_carry_core = @import("grain_carry_core");
const api = grain_carry_core.api;

test "get header value from request" {
    var request = api.integration.HttpRequest{
        .method = 1,
        .path = undefined,
        .path_len = 0,
        .query = undefined,
        .query_len = 0,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    request.headers[0].name_len = 13;
    std.mem.copyForwards(u8, &request.headers[0].name, "Authorization");
    request.headers[0].value_len = 20;
    std.mem.copyForwards(u8, &request.headers[0].value, "Bearer test_token_123");
    request.headers_len = 1;
    
    var value: [512]u8 = undefined;
    const value_len = api.integration.get_header_value(&request, "Authorization", &value);
    
    std.debug.assert(value_len > 0);
}

test "get auth token from request" {
    var request = api.integration.HttpRequest{
        .method = 1,
        .path = undefined,
        .path_len = 0,
        .query = undefined,
        .query_len = 0,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    request.headers[0].name_len = 13;
    std.mem.copyForwards(u8, &request.headers[0].name, "Authorization");
    request.headers[0].value_len = 20;
    std.mem.copyForwards(u8, &request.headers[0].value, "Bearer test_token_123");
    request.headers_len = 1;
    
    var token: [api.models.MAX_TOKEN_LEN]u8 = undefined;
    const token_len = api.integration.get_auth_token(&request, &token);
    
    std.debug.assert(token_len > 0);
}

test "set response status" {
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    api.integration.set_response_status(&response, 201);
    
    std.debug.assert(response.status == 201);
}

test "add response header" {
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const success = api.integration.add_response_header(&response, "Content-Type", "application/json");
    
    std.debug.assert(success);
    std.debug.assert(response.headers_len == 1);
}

test "set response body json" {
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const json = "{\"status\":\"success\"}";
    const success = api.integration.set_response_body_json(&response, json);
    
    std.debug.assert(success);
    std.debug.assert(response.body_len == json.len);
}

test "build auth http response" {
    var auth_resp = api.models.AuthResponse.init();
    auth_resp.success = true;
    _ = auth_resp.set_token("test_token_12345678901234567890");
    _ = auth_resp.set_user_id("user_123");
    
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const success = api.integration.build_auth_http_response(&auth_resp, &response);
    
    std.debug.assert(success);
    std.debug.assert(response.status == 200);
    std.debug.assert(response.body_len > 0);
}

test "build error http response" {
    const error_resp = api.models.ErrorResponse.init("INVALID_INPUT", "Invalid input provided");
    
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const success = api.integration.build_error_http_response(&error_resp, &response);
    
    std.debug.assert(success);
    std.debug.assert(response.status == 400);
    std.debug.assert(response.body_len > 0);
}

test "build success http response" {
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const success = api.integration.build_success_http_response("Operation successful", "{\"id\":123}", &response);
    
    std.debug.assert(success);
    std.debug.assert(response.status == 200);
    std.debug.assert(response.body_len > 0);
}

