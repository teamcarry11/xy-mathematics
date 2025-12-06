// HTTP request/response integration for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Provides adapters between Grain Mobile Core API models and Grain OS API Server HTTP structures
// Ready for use with parsed HTTP requests and response generation

const std = @import("std");
const models = @import("models.zig");
const responses = @import("responses.zig");
const validation = @import("validation.zig");

// Note: This module will use Grain OS API Server types when integrated
// For now, we define compatible structures to prepare for integration

// Compatible HTTP request structure (matches Grain OS API Server HttpRequest)
pub const HttpRequest = struct {
    method: u8,  // HttpMethod as u8
    path: [2048]u8,
    path_len: u32,
    query: [2048]u8,
    query_len: u32,
    headers: [32]struct {
        name: [128]u8,
        name_len: u32,
        value: [512]u8,
        value_len: u32,
    },
    headers_len: u32,
    body: [65536]u8,
    body_len: u32,
};

// Compatible HTTP response structure (matches Grain OS API Server HttpResponse)
pub const HttpResponse = struct {
    status: u16,  // HttpStatus as u16
    headers: [32]struct {
        name: [128]u8,
        name_len: u32,
        value: [512]u8,
        value_len: u32,
    },
    headers_len: u32,
    body: [65536]u8,
    body_len: u32,
};

// Extract header value from HTTP request
pub fn get_header_value(
    request: *const HttpRequest,
    header_name: []const u8,
    value_out: []u8,
) u32 {
    std.debug.assert(header_name.len > 0);
    std.debug.assert(value_out.len > 0);
    
    var i: u32 = 0;
    while (i < request.headers_len) : (i += 1) {
        if (request.headers[i].name_len == header_name.len) {
            var match: bool = true;
            var j: u32 = 0;
            while (j < header_name.len) : (j += 1) {
                if (request.headers[i].name[j] != header_name[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                const value_len = @min(request.headers[i].value_len, value_out.len);
                std.mem.copyForwards(u8, value_out[0..value_len], request.headers[i].value[0..request.headers[i].value_len]);
                return value_len;
            }
        }
    }
    return 0;
}

// Extract authorization token from HTTP request
pub fn get_auth_token(
    request: *const HttpRequest,
    token_out: []u8,
) u32 {
    std.debug.assert(token_out.len >= models.MAX_TOKEN_LEN);
    
    var auth_header: [512]u8 = undefined;
    const auth_len = get_header_value(request, "Authorization", &auth_header);
    
    if (auth_len == 0) {
        return 0;
    }
    
    // Extract token from "Bearer <token>" format
    const bearer_prefix = "Bearer ";
    if (auth_len < bearer_prefix.len) {
        return 0;
    }
    
    var i: u32 = 0;
    while (i < bearer_prefix.len) : (i += 1) {
        if (auth_header[i] != bearer_prefix[i]) {
            return 0;
        }
    }
    
    const token_start = bearer_prefix.len;
    const token_len = @min(auth_len - token_start, @min(token_out.len, models.MAX_TOKEN_LEN));
    std.mem.copyForwards(u8, token_out[0..token_len], auth_header[token_start..auth_len]);
    
    std.debug.assert(token_len <= models.MAX_TOKEN_LEN);
    
    return token_len;
}

// Set response status
pub fn set_response_status(
    response: *HttpResponse,
    status: u16,
) void {
    std.debug.assert(status >= 200 and status <= 599);
    response.status = status;
    std.debug.assert(response.status >= 200);
}

// Add header to HTTP response
pub fn add_response_header(
    response: *HttpResponse,
    name: []const u8,
    value: []const u8,
) bool {
    std.debug.assert(name.len > 0);
    std.debug.assert(value.len > 0);
    std.debug.assert(name.len <= 128);
    std.debug.assert(value.len <= 512);
    
    if (response.headers_len >= 32) {
        return false;
    }
    
    const header_idx = response.headers_len;
    std.mem.copyForwards(u8, response.headers[header_idx].name[0..name.len], name);
    response.headers[header_idx].name_len = @intCast(name.len);
    std.mem.copyForwards(u8, response.headers[header_idx].value[0..value.len], value);
    response.headers[header_idx].value_len = @intCast(value.len);
    response.headers_len += 1;
    
    std.debug.assert(response.headers_len <= 32);
    
    return true;
}

// Set response body from JSON string
pub fn set_response_body_json(
    response: *HttpResponse,
    json: []const u8,
) bool {
    std.debug.assert(json.len > 0);
    std.debug.assert(json.len <= 65536);
    
    if (json.len > 65536) {
        return false;
    }
    
    std.mem.copyForwards(u8, response.body[0..json.len], json);
    response.body_len = @intCast(json.len);
    
    std.debug.assert(response.body_len > 0);
    std.debug.assert(response.body_len <= 65536);
    
    return true;
}

// Build HTTP response from AuthResponse model
pub fn build_auth_http_response(
    auth_resp: *const models.AuthResponse,
    response: *HttpResponse,
) bool {
    std.debug.assert(auth_resp != null);
    std.debug.assert(response != null);
    
    var json: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(auth_resp, &json);
    
    if (json_len == 0) {
        return false;
    }
    
    set_response_status(response, if (auth_resp.success) 200 else 401);
    _ = add_response_header(response, "Content-Type", "application/json");
    _ = set_response_body_json(response, json[0..json_len]);
    
    std.debug.assert(response.status >= 200);
    std.debug.assert(response.body_len > 0);
    
    return true;
}

// Build HTTP response from ErrorResponse model
pub fn build_error_http_response(
    error_resp: *const models.ErrorResponse,
    response: *HttpResponse,
) bool {
    std.debug.assert(error_resp != null);
    std.debug.assert(response != null);
    
    var json: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_error_response(
        error_resp.error_code[0..error_resp.error_code_len],
        error_resp.message[0..error_resp.message_len],
        &json,
    );
    
    if (json_len == 0) {
        return false;
    }
    
    set_response_status(response, 400);
    _ = add_response_header(response, "Content-Type", "application/json");
    _ = set_response_body_json(response, json[0..json_len]);
    
    std.debug.assert(response.status == 400);
    std.debug.assert(response.body_len > 0);
    
    return true;
}

// Build HTTP response from success message
pub fn build_success_http_response(
    message: []const u8,
    data: []const u8,
    response: *HttpResponse,
) bool {
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= models.MAX_MESSAGE_LEN);
    std.debug.assert(response != null);
    
    var json: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response(message, data, &json);
    
    if (json_len == 0) {
        return false;
    }
    
    set_response_status(response, 200);
    _ = add_response_header(response, "Content-Type", "application/json");
    _ = set_response_body_json(response, json[0..json_len]);
    
    std.debug.assert(response.status == 200);
    std.debug.assert(response.body_len > 0);
    
    return true;
}

