const std = @import("std");
const HttpClient = @import("dream_http_client.zig").HttpClient;

/// GLM-4.6 client for Cerebras API: 1,000 tokens/second agentic coding.
/// ~<~ Glow Airbend: explicit API calls, bounded context windows.
/// ~~~~ Glow Waterbend: streaming responses flow deterministically.
pub const Glm46Client = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    api_url: []const u8 = "https://api.cerebras.ai/v1",
    model: []const u8 = "glm-4.6",
    http_client: HttpClient,
    
    // Bounded: Max 200K token context window
    pub const MAX_CONTEXT_TOKENS: u32 = 200_000;
    
    // Bounded: Max 8KB message size
    pub const MAX_MESSAGE_SIZE: usize = 8 * 1024;
    
    pub const Message = struct {
        role: []const u8, // "system", "user", "assistant"
        content: []const u8,
    };
    
    pub const CompletionRequest = struct {
        model: []const u8,
        messages: []const Message,
        stream: bool = true,
        max_tokens: ?u32 = null,
        temperature: f32 = 0.7,
    };
    
    pub const CompletionChunk = struct {
        id: []const u8,
        object: []const u8,
        created: u64,
        model: []const u8,
        choices: []Choice,
    };
    
    pub const Choice = struct {
        index: u32,
        delta: ?Delta = null,
        finish_reason: ?[]const u8 = null,
    };
    
    pub const Delta = struct {
        role: ?[]const u8 = null,
        content: ?[]const u8 = null,
    };
    
    pub fn init(allocator: std.mem.Allocator, api_key: []const u8) Glm46Client {
        std.debug.assert(api_key.len > 0);
        
        return Glm46Client{
            .allocator = allocator,
            .api_key = api_key,
            .http_client = HttpClient.init(allocator),
        };
    }
    
    pub fn deinit(self: *Glm46Client) void {
        self.http_client.deinit();
        self.* = undefined;
    }
    
    /// Request code completion (ghost text) at 1,000 tokens/second.
    /// Returns streaming chunks via callback.
    pub fn requestCompletion(
        self: *Glm46Client,
        messages: []const Message,
        callback: fn (chunk: []const u8) void,
    ) !void {
        // Assert: Context window must be within bounds
        var total_tokens: u32 = 0;
        for (messages) |msg| {
            // Rough estimate: 1 token ≈ 4 characters
            const msg_tokens = @as(u32, @intCast(msg.content.len / 4));
            total_tokens += msg_tokens;
        }
        std.debug.assert(total_tokens <= MAX_CONTEXT_TOKENS);
        
        // Build request
        const request = CompletionRequest{
            .model = self.model,
            .messages = messages,
            .stream = true,
            .max_tokens = 512, // Reasonable default
        };
        
        // Serialize to JSON
        const json_body = try self.serializeRequest(request);
        defer self.allocator.free(json_body);
        
        // Build HTTP request
        const http_req = HttpClient.Request{
            .method = "POST",
            .path = "/chat/completions",
            .headers = &.{
                .{ .name = "Authorization", .value = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.api_key}) },
                .{ .name = "Content-Type", .value = "application/json" },
            },
            .body = json_body,
        };
        defer self.allocator.free(http_req.headers[0].value);
        
        // Parse URL to get host and port
        const uri = try std.Uri.parse(self.api_url);
        const host = uri.host orelse return error.InvalidUrl;
        const port: u16 = if (uri.port) |p| p else 443;
        
        // Send HTTPS request
        const response = try self.http_client.request(host.percent_encoded, port, http_req);
        defer self.allocator.free(response.headers);
        
        // Parse SSE stream and call callback for each chunk
        try self.parseSSEStream(response.body, callback);
    }
    
    /// Serialize completion request to JSON.
    fn serializeRequest(self: *const Glm46Client, req: CompletionRequest) ![]const u8 {
        // Simple JSON serialization (can use std.json later)
        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();
        const writer = json.writer();
        
        try writer.print("{{\"model\":\"{s}\",\"messages\":[", .{req.model});
        
        for (req.messages, 0..) |msg, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{{\"role\":\"{s}\",\"content\":\"", .{msg.role});
            // Escape JSON in content
            for (msg.content) |ch| {
                switch (ch) {
                    '"' => try writer.writeAll("\\\""),
                    '\\' => try writer.writeAll("\\\\"),
                    '\n' => try writer.writeAll("\\n"),
                    '\r' => try writer.writeAll("\\r"),
                    '\t' => try writer.writeAll("\\t"),
                    else => try writer.writeByte(ch),
                }
            }
            try writer.writeAll("\"}");
        }
        
        try writer.print("],\"stream\":{s}", .{if (req.stream) "true" else "false"});
        if (req.max_tokens) |max| {
            try writer.print(",\"max_tokens\":{d}", .{max});
        }
        try writer.print(",\"temperature\":{d:.2}}}", .{req.temperature});
        
        return try json.toOwnedSlice();
    }
    
    /// Parse SSE (Server-Sent Events) stream and call callback for each chunk.
    fn parseSSEStream(
        _: *const Glm46Client,
        data: []const u8,
        callback: fn (chunk: []const u8) void,
    ) !void {
        // Parse SSE format: "data: {...}\n\n"
        var lines = std.mem.splitSequence(u8, data, "\n");
        
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "data: ")) {
                const json_data = line[6..]; // Skip "data: "
                if (std.mem.eql(u8, json_data, "[DONE]")) {
                    break; // End of stream
                }
                
                // Extract content from JSON (simple parsing)
                // TODO: Use std.json for proper parsing
                if (std.mem.indexOf(u8, json_data, "\"content\"")) |content_start| {
                    const after_content = json_data[content_start + 9..];
                    if (std.mem.indexOf(u8, after_content, "\"")) |quote_start| {
                        const content = after_content[quote_start + 1..];
                        if (std.mem.indexOf(u8, content, "\"")) |content_end| {
                            callback(content[0..content_end]);
                        }
                    }
                }
            }
        }
    }
    
    /// Request code transformation (refactor, extract, inline).
    pub fn requestTransformation(
        self: *const Glm46Client,
        code: []const u8,
        transformation: []const u8, // "extract_function", "inline", "rename"
        context: []const Message,
    ) ![]const u8 {
        // Assert: Code size must be within bounds
        std.debug.assert(code.len <= MAX_MESSAGE_SIZE);
        
        // Build messages with transformation request
        var messages = std.ArrayList(Message).init(self.allocator);
        defer messages.deinit();
        
        // Add context messages
        try messages.appendSlice(context);
        
        // Add transformation request
        const transform_msg = Message{
            .role = "user",
            .content = try std.fmt.allocPrint(
                self.allocator,
                "Transform this code: {s}\n\nCode:\n{s}",
                .{ transformation, code },
            ),
        };
        defer self.allocator.free(transform_msg.content);
        try messages.append(transform_msg);
        
        // TODO: Send request, parse response
        // For now, return stub
        _ = messages;
        return "";
    }
    
    /// Request tool calling (run `zig build`, `jj status`, etc.).
    pub fn requestToolCall(
        self: *const Glm46Client,
        tool_name: []const u8,
        tool_args: []const u8,
        context: []const Message,
    ) ![]const u8 {
        // Assert: Tool name and args must be within bounds
        std.debug.assert(tool_name.len <= MAX_MESSAGE_SIZE);
        std.debug.assert(tool_args.len <= MAX_MESSAGE_SIZE);
        
        // Build tool call request
        const tool_msg = Message{
            .role = "user",
            .content = try std.fmt.allocPrint(
                self.allocator,
                "Call tool: {s} with args: {s}",
                .{ tool_name, tool_args },
            ),
        };
        defer self.allocator.free(tool_msg.content);
        
        // TODO: Send request with tool calling format
        // For now, return stub
        _ = messages;
        return "";
    }
};

test "glm46 client init" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const api_key = "test_key";
    var client = Glm46Client.init(arena.allocator(), api_key);
    defer client.deinit();
    
    // Assert: Client initialized correctly
    std.debug.assert(std.mem.eql(u8, client.api_key, api_key));
    std.debug.assert(std.mem.eql(u8, client.model, "glm-4.6"));
}

test "glm46 context window bounds" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const api_key = "test_key";
    var client = Glm46Client.init(arena.allocator(), api_key);
    defer client.deinit();
    
    // Create messages within bounds
    const messages = [_]Glm46Client.Message{
        .{ .role = "user", .content = "Hello" },
        .{ .role = "assistant", .content = "World" },
    };
    
    // Should not panic (assertions pass)
    _ = try client.requestCompletion(&messages, struct {
        fn callback(chunk: []const u8) void {
            _ = chunk;
        }
    }.callback);
}

