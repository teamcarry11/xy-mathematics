//! Grain Core HTTP Client: HTTP client for making external API requests.
//!
//! Why: Enable agents to make HTTP requests to external APIs (Carry, Silo, etc.).
//! Architecture: HTTP/1.1 client, request building, response parsing, connection management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const network_stack = @import("network_stack.zig");
const api_server = @import("api_server.zig");
const dns_resolver = @import("dns_resolver.zig");
const http_errors = @import("http_errors.zig");

// Bounded: Max concurrent requests.
pub const MAX_CONCURRENT_REQUESTS: u32 = 32;

// Bounded: Max URL length.
pub const MAX_URL_LEN: u32 = 2048;

// Bounded: Max hostname length.
pub const MAX_HOSTNAME_LEN: u32 = 255;

// Default timeout values (milliseconds).
pub const DEFAULT_API_TIMEOUT_MS: u32 = 30000; // 30 seconds
pub const DEFAULT_CONTENT_TIMEOUT_MS: u32 = 60000; // 60 seconds

// Request state.
pub const RequestState = enum(u8) {
    pending,
    connecting,
    sending,
    receiving,
    completed,
    failed,
};

// HTTP client request.
pub const HttpClientRequest = struct {
    request_id: u32,
    method: api_server.HttpMethod,
    url: [MAX_URL_LEN]u8,
    url_len: u32,
    hostname: [MAX_HOSTNAME_LEN]u8,
    hostname_len: u32,
    port: u32,
    path: [api_server.MAX_PATH_LEN]u8,
    path_len: u32,
    headers: [api_server.MAX_HEADERS]api_server.HttpHeader,
    headers_len: u32,
    body: [api_server.MAX_REQUEST_SIZE]u8,
    body_len: u32,
    state: RequestState,
    socket_id: ?u32,
    response: ?api_server.HttpResponse,
    created_at: u64,
    timeout_ms: u32,

    pub fn init(request_id: u32) HttpClientRequest {
        std.debug.assert(request_id > 0);
        var req = HttpClientRequest{
            .request_id = request_id,
            .method = api_server.HttpMethod.get,
            .url = undefined,
            .url_len = 0,
            .hostname = undefined,
            .hostname_len = 0,
            .port = 80,
            .path = undefined,
            .path_len = 0,
            .headers = undefined,
            .headers_len = 0,
            .body = undefined,
            .body_len = 0,
            .state = RequestState.pending,
            .socket_id = null,
            .response = null,
            .created_at = 0,
            .timeout_ms = DEFAULT_API_TIMEOUT_MS,
        };
        var i: u32 = 0;
        while (i < MAX_URL_LEN) : (i += 1) {
            req.url[i] = 0;
        }
        i = 0;
        while (i < MAX_HOSTNAME_LEN) : (i += 1) {
            req.hostname[i] = 0;
        }
        i = 0;
        while (i < api_server.MAX_PATH_LEN) : (i += 1) {
            req.path[i] = 0;
        }
        i = 0;
        while (i < api_server.MAX_REQUEST_SIZE) : (i += 1) {
            req.body[i] = 0;
        }
        std.debug.assert(req.request_id > 0);
        return req;
    }

    pub fn set_url(self: *HttpClientRequest, url: []const u8) bool {
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= MAX_URL_LEN);
        const url_len = @min(url.len, MAX_URL_LEN);
        var i: u32 = 0;
        while (i < MAX_URL_LEN) : (i += 1) {
            self.url[i] = 0;
        }
        i = 0;
        while (i < url_len) : (i += 1) {
            self.url[i] = url[i];
        }
        self.url_len = url_len;
        return true;
    }

    pub fn add_header(
        self: *HttpClientRequest,
        name: []const u8,
        value: []const u8,
    ) bool {
        std.debug.assert(name.len > 0);
        std.debug.assert(value.len > 0);
        if (self.headers_len >= api_server.MAX_HEADERS) {
            return false;
        }
        if (name.len > api_server.MAX_HEADER_NAME_LEN) {
            return false;
        }
        if (value.len > api_server.MAX_HEADER_VALUE_LEN) {
            return false;
        }
        var header = api_server.HttpHeader.init();
        var i: u32 = 0;
        const name_len = @min(name.len, api_server.MAX_HEADER_NAME_LEN);
        while (i < name_len) : (i += 1) {
            header.name[i] = name[i];
        }
        header.name_len = @intCast(name_len);
        i = 0;
        const value_len = @min(value.len, api_server.MAX_HEADER_VALUE_LEN);
        while (i < value_len) : (i += 1) {
            header.value[i] = value[i];
        }
        header.value_len = @intCast(value_len);
        self.headers[self.headers_len] = header;
        self.headers_len += 1;
        return true;
    }

    // Set timeout for request.
    pub fn set_timeout(self: *HttpClientRequest, timeout_ms: ?u32) void {
        if (timeout_ms) |timeout| {
            self.timeout_ms = timeout;
        } else {
            self.timeout_ms = DEFAULT_API_TIMEOUT_MS;
        }
    }

    // Check if request has timed out.
    pub fn is_timed_out(self: *const HttpClientRequest, current_time: u64) bool {
        if (self.created_at == 0) {
            return false;
        }
        const elapsed_ms = (current_time - self.created_at) / 1000000; // Convert ns to ms
        return elapsed_ms > self.timeout_ms;
    }
};

// HTTP client manager.
pub const HttpClient = struct {
    requests: [MAX_CONCURRENT_REQUESTS]?HttpClientRequest,
    requests_len: u32,
    next_request_id: u32,
    network_stack: *network_stack.NetworkStack,
    dns_resolver: *dns_resolver.DnsResolver,

    pub fn init(
        net_stack: *network_stack.NetworkStack,
        resolver: *dns_resolver.DnsResolver,
    ) HttpClient {
        std.debug.assert(net_stack != null);
        std.debug.assert(resolver != null);
        var client = HttpClient{
            .requests = undefined,
            .requests_len = 0,
            .next_request_id = 1,
            .network_stack = net_stack,
            .dns_resolver = resolver,
        };
        var i: u32 = 0;
        while (i < MAX_CONCURRENT_REQUESTS) : (i += 1) {
            client.requests[i] = null;
        }
        std.debug.assert(client.requests_len == 0);
        return client;
    }

    pub fn create_request(
        self: *HttpClient,
        method: api_server.HttpMethod,
        url: []const u8,
        timeout_ms: ?u32,
    ) ?*HttpClientRequest {
        std.debug.assert(url.len > 0);
        if (self.requests_len >= MAX_CONCURRENT_REQUESTS) {
            return null;
        }
        const request_id = self.next_request_id;
        self.next_request_id += 1;
        var req = HttpClientRequest.init(request_id);
        req.method = method;
        req.set_timeout(timeout_ms);
        req.created_at = std.time.nanoTimestamp();
        if (!req.set_url(url)) {
            return null;
        }
        var i: u32 = 0;
        while (i < MAX_CONCURRENT_REQUESTS) : (i += 1) {
            if (self.requests[i] == null) {
                self.requests[i] = req;
                self.requests_len += 1;
                return &self.requests[i].?;
            }
        }
        return null;
    }

    // Check for timed out requests and mark them as failed.
    pub fn check_timeouts(self: *HttpClient, current_time: u64) void {
        var i: u32 = 0;
        while (i < MAX_CONCURRENT_REQUESTS) : (i += 1) {
            if (self.requests[i]) |*req| {
                if (req.is_timed_out(current_time)) {
                    req.state = RequestState.failed;
                }
            }
        }
    }

    pub fn find_request(
        self: *HttpClient,
        request_id: u32,
    ) ?*HttpClientRequest {
        std.debug.assert(request_id > 0);
        var i: u32 = 0;
        while (i < MAX_CONCURRENT_REQUESTS) : (i += 1) {
            if (self.requests[i]) |*req| {
                if (req.request_id == request_id) {
                    return req;
                }
            }
        }
        return null;
    }

    pub fn remove_request(
        self: *HttpClient,
        request_id: u32,
    ) bool {
        std.debug.assert(request_id > 0);
        var i: u32 = 0;
        while (i < MAX_CONCURRENT_REQUESTS) : (i += 1) {
            if (self.requests[i]) |*req| {
                if (req.request_id == request_id) {
                    self.requests[i] = null;
                    self.requests_len -= 1;
                    return true;
                }
            }
        }
        return false;
    }

    pub fn get_request_count(self: *const HttpClient) u32 {
        std.debug.assert(self.requests_len <= MAX_CONCURRENT_REQUESTS);
        return self.requests_len;
    }
};

