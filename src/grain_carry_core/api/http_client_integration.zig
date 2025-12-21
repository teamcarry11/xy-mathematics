//! Grain Carry Core HTTP Client Integration: Integration with Grain Core HTTP Client.
//!
//! Why: Enable Carry Agent to make external API calls using Grain Core HTTP Client.
//! Architecture: Integration layer between Carry API client and Core HTTP client.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-07-020402-pst: Grain Carry Agent

const std = @import("std");
const grain_core_http = @import("../../../grain_core/http_client.zig");
const grain_core_api = @import("../../../grain_core/api_server.zig");
const grain_core_network = @import("../../../grain_core/network_stack.zig");
const grain_core_dns = @import("../../../grain_core/dns_resolver.zig");
const client = @import("client.zig");

// Global HTTP client instance (set during initialization).
var global_http_client: ?*grain_core_http.HttpClient = null;

// Set HTTP client instance.
pub fn set_http_client(http_client: *grain_core_http.HttpClient) void {
    global_http_client = http_client;
    std.debug.assert(global_http_client != null);
}

// Get HTTP client instance.
pub fn get_http_client() ?*grain_core_http.HttpClient {
    return global_http_client;
}

// Convert Carry API client method to Core API server method.
fn convert_method(method: client.HttpMethod) grain_core_api.HttpMethod {
    std.debug.assert(@intFromEnum(method) < 5);
    return switch (method) {
        .get => grain_core_api.HttpMethod.get,
        .post => grain_core_api.HttpMethod.post,
        .put => grain_core_api.HttpMethod.put,
        .delete => grain_core_api.HttpMethod.delete,
        .patch => grain_core_api.HttpMethod.patch,
    };
}

// Convert Core API server status to Carry API client status.
fn convert_status(status: grain_core_api.HttpStatus) client.HttpStatus {
    std.debug.assert(@intFromEnum(status) >= 200);
    std.debug.assert(@intFromEnum(status) <= 503);
    return switch (status) {
        .ok => client.HttpStatus.ok,
        .created => client.HttpStatus.created,
        .no_content => client.HttpStatus.no_content,
        .bad_request => client.HttpStatus.bad_request,
        .unauthorized => client.HttpStatus.unauthorized,
        .forbidden => client.HttpStatus.forbidden,
        .not_found => client.HttpStatus.not_found,
        .conflict => client.HttpStatus.conflict,
        .internal_server_error => client.HttpStatus.internal_server_error,
        .service_unavailable => client.HttpStatus.service_unavailable,
        else => client.HttpStatus.internal_server_error,
    };
}

// Create external API request using Core HTTP client.
pub fn create_external_request(
    method: client.HttpMethod,
    url: []const u8,
) ?*grain_core_http.HttpClientRequest {
    std.debug.assert(url.len > 0);
    std.debug.assert(url.len <= client.MAX_URL_LEN);
    const http_client = get_http_client() orelse {
        return null;
    };
    const core_method = convert_method(method);
    const request = http_client.create_request(core_method, url) orelse {
        return null;
    };
    std.debug.assert(request.url_len > 0);
    std.debug.assert(request.url_len <= client.MAX_URL_LEN);
    return request;
}

// Add header to external request.
pub fn add_external_header(
    request: *grain_core_http.HttpClientRequest,
    name: []const u8,
    value: []const u8,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(name.len > 0);
    std.debug.assert(value.len > 0);
    std.debug.assert(name.len <= client.MAX_HEADER_NAME_LEN);
    std.debug.assert(value.len <= client.MAX_HEADER_VALUE_LEN);
    const success = request.add_header(name, value);
    std.debug.assert(name.len > 0);
    std.debug.assert(value.len > 0);
    return success;
}

// Set body for external request.
pub fn set_external_body(
    request: *grain_core_http.HttpClientRequest,
    body: []const u8,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(body.len <= client.MAX_BODY_LEN);
    if (body.len > grain_core_api.MAX_REQUEST_SIZE) {
        return false;
    }
    const body_len = @min(body.len, grain_core_api.MAX_REQUEST_SIZE);
    std.mem.copyForwards(u8, &request.body, body[0..body_len]);
    request.body_len = @intCast(body_len);
    std.debug.assert(request.body_len <= grain_core_api.MAX_REQUEST_SIZE);
    return true;
}

// Convert external request response to Carry API client response.
pub fn convert_external_response(
    core_response: *const grain_core_api.HttpResponse,
    response_out: *client.Response,
) bool {
    std.debug.assert(core_response != null);
    std.debug.assert(response_out != null);
    response_out.* = client.Response.init();
    response_out.status = convert_status(core_response.status);
    response_out.headers_len = 0;
    const headers_count = @min(core_response.headers_len, client.MAX_HEADERS);
    var i: u32 = 0;
    while (i < headers_count) : (i += 1) {
        const core_header = core_response.headers[i];
        const header_name = core_header.name[0..core_header.name_len];
        const header_value = core_header.value[0..core_header.value_len];
        if (response_out.headers_len >= client.MAX_HEADERS) {
            break;
        }
        response_out.headers[response_out.headers_len] = client.Header.init(header_name, header_value);
        response_out.headers_len += 1;
    }
    const body_len = @min(core_response.body_len, client.MAX_BODY_LEN);
    std.mem.copyForwards(u8, &response_out.body, core_response.body[0..body_len]);
    response_out.body_len = @intCast(body_len);
    std.debug.assert(response_out.headers_len <= client.MAX_HEADERS);
    std.debug.assert(response_out.body_len <= client.MAX_BODY_LEN);
    return true;
}

// Get request state.
pub fn get_request_state(
    request: *const grain_core_http.HttpClientRequest,
) grain_core_http.RequestState {
    std.debug.assert(request != null);
    return request.state;
}

// Check if request is completed.
pub fn is_request_completed(
    request: *const grain_core_http.HttpClientRequest,
) bool {
    std.debug.assert(request != null);
    return request.state == grain_core_http.RequestState.completed;
}

// Check if request failed.
pub fn is_request_failed(
    request: *const grain_core_http.HttpClientRequest,
) bool {
    std.debug.assert(request != null);
    return request.state == grain_core_http.RequestState.failed;
}

// Get request response.
pub fn get_request_response(
    request: *const grain_core_http.HttpClientRequest,
) ?*const grain_core_api.HttpResponse {
    std.debug.assert(request != null);
    if (request.response) |resp| {
        return &resp;
    }
    return null;
}

