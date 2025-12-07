//! Tests for Grain Carry Core HTTP Client Integration.
//!
//! Why: Verify HTTP client integration functionality for external API calls.
//! Architecture: Comprehensive test coverage for HTTP client integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-020402-pst: Grain Carry Agent

const std = @import("std");
const testing = std.testing;
const grain_carry_core = @import("grain_carry_core");
const http_integration = grain_carry_core.api.http_client_integration;
const api_client = grain_carry_core.api.client;
const grain_core = @import("grain_core");
const grain_core_http = grain_core.http_client;
const grain_core_api = grain_core.api_server;
const grain_core_network = grain_core.network_stack;
const grain_core_dns = grain_core.dns_resolver;

test "http client integration set and get" {
    var network_stack = grain_core_network.NetworkStack.init();
    var dns_resolver = grain_core_dns.DnsResolver.init();
    var http_client = grain_core_http.HttpClient.init(&network_stack, &dns_resolver);
    
    http_integration.set_http_client(&http_client);
    const retrieved = http_integration.get_http_client();
    
    try testing.expect(retrieved != null);
}

test "http client integration create external request" {
    var network_stack = grain_core_network.NetworkStack.init();
    var dns_resolver = grain_core_dns.DnsResolver.init();
    var http_client = grain_core_http.HttpClient.init(&network_stack, &dns_resolver);
    http_integration.set_http_client(&http_client);
    
    const url = "https://api.example.com/v1/test";
    const request = http_integration.create_external_request(api_client.HttpMethod.get, url);
    
    try testing.expect(request != null);
    try testing.expect(request.?.url_len > 0);
}

test "http client integration add external header" {
    var network_stack = grain_core_network.NetworkStack.init();
    var dns_resolver = grain_core_dns.DnsResolver.init();
    var http_client = grain_core_http.HttpClient.init(&network_stack, &dns_resolver);
    http_integration.set_http_client(&http_client);
    
    const url = "https://api.example.com/v1/test";
    const request = http_integration.create_external_request(api_client.HttpMethod.get, url);
    try testing.expect(request != null);
    
    const success = http_integration.add_external_header(request.?, "Content-Type", "application/json");
    
    try testing.expect(success);
    try testing.expect(request.?.headers_len == 1);
}

test "http client integration set external body" {
    var network_stack = grain_core_network.NetworkStack.init();
    var dns_resolver = grain_core_dns.DnsResolver.init();
    var http_client = grain_core_http.HttpClient.init(&network_stack, &dns_resolver);
    http_integration.set_http_client(&http_client);
    
    const url = "https://api.example.com/v1/test";
    const request = http_integration.create_external_request(api_client.HttpMethod.post, url);
    try testing.expect(request != null);
    
    const body = "{\"test\": \"data\"}";
    const success = http_integration.set_external_body(request.?, body);
    
    try testing.expect(success);
    try testing.expect(request.?.body_len > 0);
}

test "http client integration get request state" {
    var network_stack = grain_core_network.NetworkStack.init();
    var dns_resolver = grain_core_dns.DnsResolver.init();
    var http_client = grain_core_http.HttpClient.init(&network_stack, &dns_resolver);
    http_integration.set_http_client(&http_client);
    
    const url = "https://api.example.com/v1/test";
    const request = http_integration.create_external_request(api_client.HttpMethod.get, url);
    try testing.expect(request != null);
    
    const state = http_integration.get_request_state(request.?);
    
    try testing.expect(state == grain_core_http.RequestState.pending);
}

test "http client integration is request completed" {
    var network_stack = grain_core_network.NetworkStack.init();
    var dns_resolver = grain_core_dns.DnsResolver.init();
    var http_client = grain_core_http.HttpClient.init(&network_stack, &dns_resolver);
    http_integration.set_http_client(&http_client);
    
    const url = "https://api.example.com/v1/test";
    const request = http_integration.create_external_request(api_client.HttpMethod.get, url);
    try testing.expect(request != null);
    
    const is_completed = http_integration.is_request_completed(request.?);
    
    try testing.expect(!is_completed);
}

test "http client integration is request failed" {
    var network_stack = grain_core_network.NetworkStack.init();
    var dns_resolver = grain_core_dns.DnsResolver.init();
    var http_client = grain_core_http.HttpClient.init(&network_stack, &dns_resolver);
    http_integration.set_http_client(&http_client);
    
    const url = "https://api.example.com/v1/test";
    const request = http_integration.create_external_request(api_client.HttpMethod.get, url);
    try testing.expect(request != null);
    
    const is_failed = http_integration.is_request_failed(request.?);
    
    try testing.expect(!is_failed);
}

test "http client integration convert external response" {
    var core_response = grain_core_api.HttpResponse.init();
    core_response.status = grain_core_api.HttpStatus.ok;
    _ = core_response.add_header("Content-Type", "application/json");
    const body_text = "{\"success\": true}";
    std.mem.copyForwards(u8, &core_response.body, body_text);
    core_response.body_len = @intCast(body_text.len);
    
    var response_out = api_client.Response.init();
    const success = http_integration.convert_external_response(&core_response, &response_out);
    
    try testing.expect(success);
    try testing.expect(response_out.status == api_client.HttpStatus.ok);
    try testing.expect(response_out.headers_len > 0);
    try testing.expect(response_out.body_len > 0);
}

