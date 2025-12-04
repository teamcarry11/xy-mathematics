//! Tests for Grain Mobile Core API client.
//!
//! Why: Verify API client functionality (request/response models).
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_mobile_core = @import("grain_mobile_core");
const api = grain_mobile_core.api.client;

test "request initialization" {
    const req = api.Request.init(.get, "https://api.example.com/users");
    
    std.debug.assert(req.method == .get);
    std.debug.assert(req.url_len > 0);
    std.debug.assert(req.headers_len == 0);
    std.debug.assert(req.body_len == 0);
}

test "request add header" {
    var req = api.Request.init(.post, "https://api.example.com/users");
    const success = req.add_header("Content-Type", "application/json");
    
    std.debug.assert(success);
    std.debug.assert(req.headers_len == 1);
    std.debug.assert(req.headers[0].name_len > 0);
}

test "request add multiple headers" {
    var req = api.Request.init(.post, "https://api.example.com/users");
    _ = req.add_header("Content-Type", "application/json");
    _ = req.add_header("Authorization", "Bearer token123");
    
    std.debug.assert(req.headers_len == 2);
}

test "request set body" {
    var req = api.Request.init(.post, "https://api.example.com/users");
    const body = "{\"name\":\"test\"}";
    const success = req.set_body(body);
    
    std.debug.assert(success);
    std.debug.assert(req.body_len == body.len);
}

test "response initialization" {
    const resp = api.Response.init();
    
    std.debug.assert(resp.status == .ok);
    std.debug.assert(resp.headers_len == 0);
    std.debug.assert(resp.body_len == 0);
}

test "api client initialization" {
    const client = api.ApiClient.init("https://api.example.com");
    
    std.debug.assert(client.base_url_len > 0);
    std.debug.assert(client.default_headers_len == 0);
}

test "api client add default header" {
    var client = api.ApiClient.init("https://api.example.com");
    const success = client.add_default_header("User-Agent", "GrainMobile/1.0");
    
    std.debug.assert(success);
    std.debug.assert(client.default_headers_len == 1);
}

test "api client build url" {
    const client = api.ApiClient.init("https://api.example.com");
    var url: [api.MAX_URL_LEN]u8 = undefined;
    const url_len = client.build_url("/users", &url);
    
    std.debug.assert(url_len > 0);
    std.debug.assert(url_len <= api.MAX_URL_LEN);
}

test "api client create request" {
    const client = api.ApiClient.init("https://api.example.com");
    _ = client.add_default_header("User-Agent", "GrainMobile/1.0");
    const req = client.create_request(.get, "/users");
    
    std.debug.assert(req.method == .get);
    std.debug.assert(req.url_len > 0);
    std.debug.assert(req.headers_len >= 1);
}

test "api client create request with body" {
    const client = api.ApiClient.init("https://api.example.com");
    var req = client.create_request(.post, "/users");
    const body = "{\"name\":\"test\"}";
    _ = req.set_body(body);
    
    std.debug.assert(req.method == .post);
    std.debug.assert(req.body_len == body.len);
}

