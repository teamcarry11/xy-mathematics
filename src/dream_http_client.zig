const std = @import("std");
const TlsClient = @import("grain_tls/tls_client.zig").TlsClient;

/// HTTP client for Dream Editor/Browser: HTTPS support via TLS.
/// ~<~ Glow Airbend: explicit HTTP requests, bounded buffers.
/// ~~~~ Glow Waterbend: streaming responses flow deterministically.
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    
    // Bounded: Max 8KB response buffer
    pub const MAX_RESPONSE_SIZE: usize = 8 * 1024;
    
    // Bounded: Max 1MB request body
    pub const MAX_REQUEST_SIZE: usize = 1024 * 1024;
    
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
    
    /// Send HTTPS request and receive response.
    pub fn request(
        self: *HttpClient,
        host: []const u8,
        port: u16,
        req: Request,
    ) !Response {
        // Assert: Request body must be within bounds
        if (req.body) |body| {
            std.debug.assert(body.len <= MAX_REQUEST_SIZE);
        }
        
        // Connect TCP
        var tcp_stream = try std.net.tcpConnectToHost(self.allocator, host, port);
        defer tcp_stream.close();
        
        // Upgrade to TLS (HTTPS)
        var tls_client = try TlsClient.init(self.allocator, tcp_stream, host);
        defer tls_client.deinit();
        
        // Build HTTP request
        var request_buf: [MAX_REQUEST_SIZE + 1024]u8 = undefined;
        const request_text = try self.buildRequest(req, &request_buf);
        
        // Send request
        try tls_client.writeAll(request_text);
        
        // Read response
        var response_buf: [MAX_RESPONSE_SIZE]u8 = undefined;
        var response_len: usize = 0;
        
        while (try tls_client.next()) |chunk| {
            if (response_len + chunk.len > MAX_RESPONSE_SIZE) {
                return error.ResponseTooLarge;
            }
            std.mem.copyForwards(u8, response_buf[response_len..], chunk);
            response_len += chunk.len;
        }
        
        // Parse response
        const response = try self.parseResponse(response_buf[0..response_len]);
        
        // Assert: Response must be valid
        std.debug.assert(response.status_code > 0);
        
        return response;
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
        _ = self;
        
        // Simple parser: find status line, headers, body
        var lines = std.mem.splitSequence(u8, data, "\r\n");
        
        // Status line: "HTTP/1.1 200 OK"
        const status_line = lines.next() orelse return error.InvalidResponse;
        const status_code = try self.parseStatusCode(status_line);
        
        // Headers (until empty line)
        var headers = std.ArrayList(Header).init(self.allocator);
        defer headers.deinit();
        
        while (lines.next()) |line| {
            if (line.len == 0) break; // Empty line = end of headers
            
            const colon_idx = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            const name = line[0..colon_idx];
            const value = line[colon_idx + 1..];
            // Skip leading space in value
            const value_start = std.mem.indexOfNone(u8, value, " \t") orelse value.len;
            
            try headers.append(Header{
                .name = name,
                .value = value[value_start..],
            });
        }
        
        // Body (rest of data)
        const body_start = std.mem.indexOf(u8, data, "\r\n\r\n") orelse return error.InvalidResponse;
        const body = data[body_start + 4..];
        
        return Response{
            .status_code = status_code,
            .headers = try headers.toOwnedSlice(),
            .body = body,
        };
    }
    
    /// Parse status code from status line.
    fn parseStatusCode(self: *HttpClient, status_line: []const u8) !u16 {
        _ = self;
        
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

