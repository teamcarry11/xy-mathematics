const std = @import("std");
const TlsClient = @import("grain_tls/tls_client.zig").TlsClient;
const http_errors = @import("grain_core/http_errors.zig");
const aurora_errors = @import("aurora_errors.zig");

/// HTTP client for Dream Editor/Browser: HTTPS support via TLS.
/// ~<~ Glow Airbend: explicit HTTP requests, bounded buffers.
/// ~~~~ Glow Waterbend: streaming responses flow deterministically.
/// 
/// **Integration**: Uses Core Agent's HTTP error types and timeout handling.
/// Timeout support: Per-request timeout with default values (30s API, 60s content).
/// Error handling: Structured error unions with retryability classification.
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    
    // Bounded: Max 8KB response buffer
    pub const MAX_RESPONSE_SIZE: usize = 8 * 1024;
    
    // Bounded: Max 1MB request body
    pub const MAX_REQUEST_SIZE: usize = 1024 * 1024;
    
    // Default timeout values (from Core Agent)
    pub const DEFAULT_API_TIMEOUT_MS: u32 = 30_000; // 30 seconds
    pub const DEFAULT_CONTENT_TIMEOUT_MS: u32 = 60_000; // 60 seconds
    
    pub const Request = struct {
        method: []const u8, // "GET", "POST", etc.
        path: []const u8,
        headers: []const Header,
        body: ?[]const u8 = null,
    };
    
    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };
    
    pub const Response = struct {
        status_code: u16,
        headers: []const Header,
        body: []const u8,
    };
    
    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return HttpClient{
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *HttpClient) void {
        _ = self;
        // No dynamic allocation to clean up
    }
    
    /// Send HTTPS request and receive response with timeout support.
    /// timeout_ms: Optional timeout in milliseconds (default: DEFAULT_API_TIMEOUT_MS).
    /// Returns Core Agent's HttpClientError on failure.
    pub fn request(
        self: *HttpClient,
        host: []const u8,
        port: u16,
        req: Request,
        timeout_ms: ?u32,
    ) http_errors.HttpClientError!Response {
        // Assert: Request body must be within bounds
        if (req.body) |body| {
            std.debug.assert(body.len <= MAX_REQUEST_SIZE);
        }
        
        const timeout = timeout_ms orelse DEFAULT_API_TIMEOUT_MS;
        const start_time = std.time.nanoTimestamp();
        
        // Connect TCP (with timeout checking)
        const tcp_stream = std.net.tcpConnectToHost(self.allocator, host, port) catch |err| {
            return self.mapNetworkError(err);
        };
        defer tcp_stream.close();
        
        // Check timeout after connection
        if (self.is_timed_out(start_time, timeout)) {
            return http_errors.HttpClientError.timeout;
        }
        
        // Upgrade to TLS (HTTPS)
        const tls_client = TlsClient.init(self.allocator, tcp_stream, host) catch |err| {
            return self.mapTlsError(err);
        };
        defer tls_client.deinit();
        
        // Check timeout after TLS handshake
        if (self.is_timed_out(start_time, timeout)) {
            return http_errors.HttpClientError.timeout;
        }
        
        // Build HTTP request
        var request_buf: [MAX_REQUEST_SIZE + 1024]u8 = undefined;
        const request_text = self.buildRequest(req, &request_buf) catch |err| {
            return self.mapRequestError(err);
        };
        
        // Send request (with timeout checking)
        tls_client.writeAll(request_text) catch |err| {
            return self.mapNetworkError(err);
        };
        
        if (self.is_timed_out(start_time, timeout)) {
            return http_errors.HttpClientError.timeout;
        }
        
        // Read response (with timeout checking)
        var response_buf: [MAX_RESPONSE_SIZE]u8 = undefined;
        var response_len: usize = 0;
        
        while (tls_client.next() catch |err| {
            return self.mapNetworkError(err);
        }) |chunk| {
            if (self.is_timed_out(start_time, timeout)) {
                return http_errors.HttpClientError.timeout;
            }
            
            if (response_len + chunk.len > MAX_RESPONSE_SIZE) {
                return http_errors.HttpClientError.invalid_response;
            }
            std.mem.copyForwards(u8, response_buf[response_len..], chunk);
            response_len += chunk.len;
        }
        
        // Parse response
        const response = self.parseResponse(response_buf[0..response_len]) catch |err| {
            return self.mapParseError(err);
        };
        
        // Check for HTTP error status codes
        if (response.status_code == 429) {
            return http_errors.HttpClientError.rate_limit;
        }
        if (response.status_code >= 500) {
            return http_errors.HttpClientError.server_error;
        }
        
        // Assert: Response must be valid
        std.debug.assert(response.status_code > 0);
        
        return response;
    }
    
    /// Send HTTPS request with retry logic for retryable errors.
    /// max_retries: Maximum number of retry attempts (default: 3).
    /// Returns Core Agent's HttpClientError on failure.
    pub fn request_with_retry(
        self: *HttpClient,
        host: []const u8,
        port: u16,
        req: Request,
        timeout_ms: ?u32,
        max_retries: u32,
    ) http_errors.HttpClientError!Response {
        std.debug.assert(max_retries <= aurora_errors.MAX_RETRY_ATTEMPTS);
        
        var attempt: u32 = 0;
        while (attempt <= max_retries) : (attempt += 1) {
            const result = self.request(host, port, req, timeout_ms);
            
            if (result) |response| {
                return response;
            } else |err| {
                // Check if error is retryable
                if (!http_errors.is_http_error_retryable(err)) {
                    return err;
                }
                
                // If this was the last attempt, return the error
                if (attempt >= max_retries) {
                    return err;
                }
                
                // Calculate exponential backoff delay
                const delay_ms = aurora_errors.getRetryDelayMs(attempt);
                std.time.sleep(delay_ms * 1_000_000); // Convert ms to ns
            }
        }
        
        unreachable;
    }
    
    /// Check if request has timed out.
    fn is_timed_out(self: *HttpClient, start_time: i64, timeout_ms: u32) bool {
        _ = self;
        const elapsed_ns = std.time.nanoTimestamp() - start_time;
        const elapsed_ms = @divTrunc(elapsed_ns, 1_000_000); // Convert ns to ms
        return elapsed_ms > @as(i64, timeout_ms);
    }
    
    /// Map network errors to Core Agent's HttpClientError.
    fn mapNetworkError(self: *HttpClient, err: anyerror) http_errors.HttpClientError {
        _ = self;
        _ = err;
        return http_errors.HttpClientError.network_error;
    }
    
    /// Map TLS errors to Core Agent's HttpClientError.
    fn mapTlsError(self: *HttpClient, err: anyerror) http_errors.HttpClientError {
        _ = self;
        _ = err;
        return http_errors.HttpClientError.network_error;
    }
    
    /// Map request building errors to Core Agent's HttpClientError.
    fn mapRequestError(self: *HttpClient, err: anyerror) http_errors.HttpClientError {
        _ = self;
        _ = err;
        return http_errors.HttpClientError.invalid_response;
    }
    
    /// Map response parsing errors to Core Agent's HttpClientError.
    fn mapParseError(self: *HttpClient, err: anyerror) http_errors.HttpClientError {
        _ = self;
        _ = err;
        return http_errors.HttpClientError.invalid_response;
    }
    
    /// Build HTTP request string.
    fn buildRequest(self: *HttpClient, req: Request, buf: []u8) ![]const u8 {
        _ = self;
        
        var stream = std.io.fixedBufferStream(buf);
        const writer = stream.writer();
        
        // Request line
        try writer.print("{s} {s} HTTP/1.1\r\n", .{ req.method, req.path });
        
        // Headers
        for (req.headers) |header| {
            try writer.print("{s}: {s}\r\n", .{ header.name, header.value });
        }
        
        // Body (if present)
        if (req.body) |body| {
            try writer.print("Content-Length: {d}\r\n", .{body.len});
            try writer.writeAll("\r\n");
            try writer.writeAll(body);
        } else {
            try writer.writeAll("\r\n");
        }
        
        return stream.getWritten();
    }
    
    /// Parse HTTP response.
    fn parseResponse(self: *HttpClient, data: []const u8) !Response {
        
        // Simple parser: find status line, headers, body
        var lines = std.mem.splitSequence(u8, data, "\r\n");
        
        // Status line: "HTTP/1.1 200 OK"
        const status_line = lines.next() orelse return error.InvalidResponse;
        const status_code = try self.parseStatusCode(status_line);
        
        // Headers (until empty line)
        var headers = std.ArrayList(Header){ .items = &.{}, .capacity = 0 };
        defer headers.deinit(self.allocator);
        
        while (lines.next()) |line| {
            if (line.len == 0) break; // Empty line = end of headers
            
            const colon_idx = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            const name = line[0..colon_idx];
            const value = line[colon_idx + 1..];
            // Skip leading space in value
            const value_start = std.mem.indexOfNone(u8, value, " \t") orelse value.len;
            
            try headers.append(self.allocator, Header{
                .name = name,
                .value = value[value_start..],
            });
        }
        
        // Body (rest of data)
        const body_start = std.mem.indexOf(u8, data, "\r\n\r\n") orelse return error.InvalidResponse;
        const body = data[body_start + 4..];
        
        return Response{
            .status_code = status_code,
            .headers = try headers.toOwnedSlice(self.allocator),
            .body = body,
        };
    }
    
    /// Parse status code from status line.
    fn parseStatusCode(_: *HttpClient, status_line: []const u8) !u16 {
        
        // Find first space, then next space
        const first_space = std.mem.indexOfScalar(u8, status_line, ' ') orelse return error.InvalidResponse;
        const second_space = std.mem.indexOfScalar(u8, status_line[first_space + 1..], ' ') orelse status_line.len;
        
        const code_str = status_line[first_space + 1..][0..second_space];
        const code = try std.fmt.parseInt(u16, code_str, 10);
        
        return code;
    }
};

test "http client builds request" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var client = HttpClient.init(arena.allocator());
    defer client.deinit();
    
    const req = HttpClient.Request{
        .method = "POST",
        .path = "/v1/chat/completions",
        .headers = &.{
            .{ .name = "Authorization", .value = "Bearer test" },
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .body = "{\"test\":\"data\"}",
    };
    
    var buf: [1024]u8 = undefined;
    const request_text = try client.buildRequest(req, &buf);
    
    // Assert: Request must contain method, path, headers, body
    try std.testing.expect(std.mem.indexOf(u8, request_text, "POST") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_text, "/v1/chat/completions") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_text, "Authorization") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_text, "{\"test\":\"data\"}") != null);
}

test "http client timeout checking" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var client = HttpClient.init(arena.allocator());
    defer client.deinit();
    
    const start_time = std.time.nanoTimestamp();
    
    // Assert: Timeout check works correctly
    try std.testing.expect(!client.is_timed_out(start_time, 1000));
    
    // Wait a bit (but not enough to timeout)
    std.time.sleep(10 * std.time.ns_per_ms);
    try std.testing.expect(!client.is_timed_out(start_time, 1000));
}

test "http client error mapping" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var client = HttpClient.init(arena.allocator());
    defer client.deinit();
    
    // Assert: Error mapping functions work
    const network_err = client.mapNetworkError(error.ConnectionRefused);
    try std.testing.expect(network_err == http_errors.HttpClientError.network_error);
    
    const tls_err = client.mapTlsError(error.TlsHandshakeFailed);
    try std.testing.expect(tls_err == http_errors.HttpClientError.network_error);
    
    const parse_err = client.mapParseError(error.InvalidResponse);
    try std.testing.expect(parse_err == http_errors.HttpClientError.invalid_response);
}

test "http client parses response" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var client = HttpClient.init(arena.allocator());
    defer client.deinit();
    
    const response_text = 
        \\HTTP/1.1 200 OK\r\n
        \\Content-Type: application/json\r\n
        \\Content-Length: 13\r\n
        \\\r\n
        \\{"status":"ok"}
    ;
    
    const response = try client.parseResponse(response_text);
    defer arena.allocator().free(response.headers);
    
    // Assert: Response must be parsed correctly
    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expectEqual(@as(usize, 2), response.headers.len);
    try std.testing.expect(std.mem.eql(u8, response.body, "{\"status\":\"ok\"}"));
}

