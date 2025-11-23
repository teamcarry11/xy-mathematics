const std = @import("std");
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;

// Cancellation support: track pending requests
// Bounded: Max 100 pending requests
pub const MAX_PENDING_REQUESTS: u32 = 100;

/// LSP client for Aurora IDE: communicates with ZLS (Zig Language Server) via JSON-RPC 2.0.
/// ~<~ Glow Airbend: static allocation for message buffers; process lifecycle explicit.
/// ~~~~ Glow Waterbend: snapshot model tracks incremental document changes (Matklad-style).
pub const LspClient = struct {
    // Snapshot model: track document versions incrementally (Matklad-style)
    // Bounded: Max 1000 document snapshots
    pub const MAX_SNAPSHOTS: u32 = 1000;
    allocator: std.mem.Allocator,
    server_process: ?std.process.Child = null,
    request_id: u64 = 1,
    message_buffer: [8192]u8 = undefined,
    snapshots: std.ArrayList(DocumentSnapshot) = undefined,
    current_snapshot_id: u64 = 0,
    pending_requests: std.AutoHashMap(u64, void) = undefined,

    pub const Message = struct {
        jsonrpc: []const u8 = "2.0",
        id: ?u64 = null,
        method: ?[]const u8 = null,
        params: ?std.json.Value = null,
        result: ?std.json.Value = null,
        lsp_error: ?LspError = null,
    };

    pub const LspError = struct {
        code: i32,
        message: []const u8,
        data: ?std.json.Value = null,
    };

    pub const CompletionItem = struct {
        label: []const u8,
        kind: ?u32 = null,
        detail: ?[]const u8 = null,
        documentation: ?[]const u8 = null,
    };

    pub const Diagnostic = struct {
        range: Range,
        severity: ?u32 = null,
        message: []const u8,
        source: ?[]const u8 = null,
    };

    pub const Range = struct {
        start: Position,
        end: Position,
    };

    pub const Position = struct {
        line: u32,
        character: u32,
    };
    
    /// Document snapshot: incremental change tracking (Matklad-style).
    /// Tracks document version, URI, and text content.
    pub const DocumentSnapshot = struct {
        id: u64,
        uri: []const u8,
        version: u64,
        text: []const u8,
    };
    
    /// Text document change: incremental edit (LSP textDocument/didChange).
    pub const TextDocumentChange = struct {
        range: ?Range = null, // null = full document replacement
        range_length: ?u32 = null,
        text: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) LspClient {
        return LspClient{
            .allocator = allocator,
            .snapshots = std.ArrayList(DocumentSnapshot){ .items = &.{}, .capacity = 0 },
            .pending_requests = std.AutoHashMap(u64, void).init(allocator),
        };
    }

    pub fn deinit(self: *LspClient) void {
        // Free snapshot URIs and text
        for (self.snapshots.items) |*snapshot| {
            self.allocator.free(snapshot.uri);
            self.allocator.free(snapshot.text);
        }
        self.snapshots.deinit(self.allocator);
        self.pending_requests.deinit();
        
        if (self.server_process) |*proc| {
            _ = proc.kill() catch {};
            _ = proc.wait() catch {};
        }
        self.* = undefined;
    }

    /// Spawn ZLS process: expects `zls` in PATH or use explicit path.
    pub fn startServer(self: *LspClient, zls_path: []const u8) !void {
        if (self.server_process != null) return;

        const argv = [_][]const u8{ zls_path };
        var child = std.process.Child.init(&argv, self.allocator);
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        try child.spawn();
        self.server_process = child;
    }

    /// Send initialize request to LSP server.
    pub fn initialize(self: *LspClient, root_uri: []const u8) !void {
        // Assert: Root URI must be non-empty
        std.debug.assert(root_uri.len > 0);
        std.debug.assert(root_uri.len <= 4096); // Bounded URI length
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        try params_obj.put("rootUri", std.json.Value{ .string = root_uri });
        
        const capabilities_obj = std.json.ObjectMap.init(self.allocator);
        try params_obj.put("capabilities", std.json.Value{ .object = capabilities_obj });
        
        const params = std.json.Value{ .object = params_obj };
        _ = try self.sendRequest("initialize", params);
    }

    /// Request textDocument/completion at a position.
    pub fn requestCompletion(
        self: *LspClient,
        uri: []const u8,
        line: u32,
        character: u32,
    ) !?[]CompletionItem {
        // Assert: URI and position must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        var position_obj = std.json.ObjectMap.init(self.allocator);
        defer position_obj.deinit();
        try position_obj.put("line", std.json.Value{ .integer = @intCast(line) });
        try position_obj.put("character", std.json.Value{ .integer = @intCast(character) });
        try params_obj.put("position", std.json.Value{ .object = position_obj });
        
        const params = std.json.Value{ .object = params_obj };
        const response = try self.sendRequest("textDocument/completion", params);
        
        // Parse completion items from response.result
        if (response.result) |result| {
            if (result == .array) {
                const items = result.array.items;
                var completions = try self.allocator.alloc(CompletionItem, items.len);
                for (items, 0..) |item, i| {
                    if (item == .object) {
                        const obj = item.object;
                        completions[i] = CompletionItem{
                            .label = if (obj.get("label")) |l| l.string else "",
                            .kind = if (obj.get("kind")) |k| @intCast(k.integer) else null,
                            .detail = if (obj.get("detail")) |d| d.string else null,
                            .documentation = if (obj.get("documentation")) |doc| doc.string else null,
                        };
                    }
                }
                return completions;
            }
        }
        return null;
    }
    
    /// Send textDocument/didOpen notification (document opened).
    pub fn didOpen(self: *LspClient, uri: []const u8, text: []const u8) !void {
        // Assert: URI and text must be valid
        std.debug.assert(uri.len > 0);
        std.debug.assert(uri.len <= 4096); // Bounded URI length
        std.debug.assert(text.len <= 100 * 1024 * 1024); // Bounded text size (100MB)
        
        // Assert: Bounded snapshots
        std.debug.assert(self.snapshots.items.len < MAX_SNAPSHOTS);
        
        // Create snapshot
        const snapshot = DocumentSnapshot{
            .id = self.current_snapshot_id,
            .uri = try self.allocator.dupe(u8, uri),
            .version = 0,
            .text = try self.allocator.dupe(u8, text),
        };
        self.current_snapshot_id += 1;
        
        try self.snapshots.append(self.allocator, snapshot);
        
        // Assert: Snapshot added successfully
        std.debug.assert(self.snapshots.items.len <= MAX_SNAPSHOTS);
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        defer text_doc_obj.deinit();
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try text_doc_obj.put("languageId", std.json.Value{ .string = "zig" });
        try text_doc_obj.put("version", std.json.Value{ .integer = 0 });
        try text_doc_obj.put("text", std.json.Value{ .string = text });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        
        const params = std.json.Value{ .object = params_obj };
        try self.sendNotification("textDocument/didOpen", params);
    }
    
    /// Send textDocument/didChange notification (incremental update, Matklad snapshot model).
    pub fn didChange(self: *LspClient, uri: []const u8, changes: []const TextDocumentChange) !void {
        // Find existing snapshot
        var snapshot_idx: ?u32 = null;
        for (self.snapshots.items, 0..) |*snapshot, i| {
            if (std.mem.eql(u8, snapshot.uri, uri)) {
                // Assert: Index fits in u32
                std.debug.assert(i <= std.math.maxInt(u32));
                snapshot_idx = @intCast(i);
                break;
            }
        }
        
        // Assert: Snapshot must exist
        std.debug.assert(snapshot_idx != null);
        const snapshot = &self.snapshots.items[snapshot_idx.?];
        
        // Apply incremental changes (Matklad snapshot model)
        var new_text = try self.allocator.dupe(u8, snapshot.text);
        errdefer self.allocator.free(new_text);
        
        for (changes) |change| {
            if (change.range) |range| {
                // Incremental edit: replace range with new text
                const start_byte = try self.positionToByte(snapshot.text, range.start);
                const end_byte = try self.positionToByte(snapshot.text, range.end);
                
                // Replace range in text
                var updated = try self.allocator.alloc(u8, new_text.len - (end_byte - start_byte) + change.text.len);
                @memcpy(updated[0..start_byte], new_text[0..start_byte]);
                @memcpy(updated[start_byte..start_byte + change.text.len], change.text);
                @memcpy(updated[start_byte + change.text.len..], new_text[end_byte..]);
                
                self.allocator.free(new_text);
                new_text = updated;
            } else {
                // Full document replacement
                self.allocator.free(new_text);
                new_text = try self.allocator.dupe(u8, change.text);
            }
        }
        
        // Update snapshot
        self.allocator.free(snapshot.text);
        snapshot.text = new_text;
        snapshot.version += 1;
        
        // Build LSP params
        var change_objects = std.ArrayList(std.json.Value){ .items = &.{}, .capacity = 0 };
        defer change_objects.deinit(self.allocator);
        
        for (changes) |change| {
            var change_obj = std.json.ObjectMap.init(self.allocator);
            if (change.range) |range| {
                var range_obj = std.json.ObjectMap.init(self.allocator);
                
                var start_obj = std.json.ObjectMap.init(self.allocator);
                try start_obj.put("line", std.json.Value{ .integer = @intCast(range.start.line) });
                try start_obj.put("character", std.json.Value{ .integer = @intCast(range.start.character) });
                try range_obj.put("start", std.json.Value{ .object = start_obj });
                
                var end_obj = std.json.ObjectMap.init(self.allocator);
                try end_obj.put("line", std.json.Value{ .integer = @intCast(range.end.line) });
                try end_obj.put("character", std.json.Value{ .integer = @intCast(range.end.character) });
                try range_obj.put("end", std.json.Value{ .object = end_obj });
                
                try change_obj.put("range", std.json.Value{ .object = range_obj });
                
                if (change.range_length) |len| {
                    try change_obj.put("rangeLength", std.json.Value{ .integer = @intCast(len) });
                }
            }
            try change_obj.put("text", std.json.Value{ .string = change.text });
            try change_objects.append(self.allocator, std.json.Value{ .object = change_obj });
        }
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        
        var text_doc_obj = std.json.ObjectMap.init(self.allocator);
        try text_doc_obj.put("uri", std.json.Value{ .string = uri });
        try text_doc_obj.put("version", std.json.Value{ .integer = @intCast(snapshot.version) });
        try params_obj.put("textDocument", std.json.Value{ .object = text_doc_obj });
        const changes_slice = try change_objects.toOwnedSlice(self.allocator);
        try params_obj.put("contentChanges", std.json.Value{ .array = .{ .items = changes_slice, .capacity = changes_slice.len } });
        
        const params = std.json.Value{ .object = params_obj };
        try self.sendNotification("textDocument/didChange", params);
    }
    
    /// Cancel a pending request.
    pub fn cancelRequest(self: *LspClient, request_id: u64) !void {
        // Assert: Request must be pending
        std.debug.assert(self.pending_requests.contains(request_id));
        
        var params_obj = std.json.ObjectMap.init(self.allocator);
        defer params_obj.deinit();
        try params_obj.put("id", std.json.Value{ .integer = @intCast(request_id) });
        
        const params = std.json.Value{ .object = params_obj };
        try self.sendNotification("$/cancelRequest", params);
        _ = self.pending_requests.remove(request_id);
    }
    
    /// Convert LSP Position to byte offset in text (for incremental edits).
    fn positionToByte(self: *LspClient, text: []const u8, pos: Position) !u32 {
        _ = self;
        var byte: u32 = 0;
        var line: u32 = 0;
        var char: u32 = 0;
        
        for (text) |c| {
            if (line == pos.line and char == pos.character) {
                return byte;
            }
            byte += 1;
            if (c == '\n') {
                line += 1;
                char = 0;
            } else {
                char += 1;
            }
        }
        
        // Position at end of document
        if (line == pos.line and char == pos.character) {
            return byte;
        }
        
        return error.InvalidPosition;
    }

    /// Serialize JSON Value to string (manual implementation for Zig 0.15 compatibility).
    /// Bounded: Max 10MB JSON output.
    fn serialize_json_value(
        self: *LspClient,
        value: std.json.Value,
    ) ![]const u8 {
        var buffer = std.ArrayList(u8){ .items = &.{}, .capacity = 0 };
        errdefer buffer.deinit(self.allocator);
        const writer = buffer.writer(self.allocator);
        
        try self.write_json_value(writer, value);
        
        return try buffer.toOwnedSlice(self.allocator);
    }
    
    /// Recursively write JSON value to writer.
    fn write_json_value(
        self: *LspClient,
        writer: anytype,
        value: std.json.Value,
    ) !void {
        switch (value) {
            .string => |s| {
                try writer.writeByte('"');
                // Escape JSON special characters
                for (s) |ch| {
                    switch (ch) {
                        '"' => try writer.writeAll("\\\""),
                        '\\' => try writer.writeAll("\\\\"),
                        '\n' => try writer.writeAll("\\n"),
                        '\r' => try writer.writeAll("\\r"),
                        '\t' => try writer.writeAll("\\t"),
                        else => try writer.writeByte(ch),
                    }
                }
                try writer.writeByte('"');
            },
            .integer => |i| try writer.print("{d}", .{i}),
            .float => |f| try writer.print("{d}", .{f}),
            .bool => |b| try writer.print("{}", .{b}),
            .null => try writer.writeAll("null"),
            .array => |arr| {
                try writer.writeByte('[');
                for (arr.items, 0..) |item, i| {
                    if (i > 0) try writer.writeByte(',');
                    try self.write_json_value(writer, item);
                }
                try writer.writeByte(']');
            },
            .object => |obj| {
                try writer.writeByte('{');
                var it = obj.iterator();
                var first = true;
                while (it.next()) |entry| {
                    if (!first) try writer.writeByte(',');
                    first = false;
                    // Write key
                    try writer.writeByte('"');
                    try writer.writeAll(entry.key_ptr.*);
                    try writer.writeByte('"');
                    try writer.writeByte(':');
                    // Write value
                    try self.write_json_value(writer, entry.value_ptr.*);
                }
                try writer.writeByte('}');
            },
            .number_string => |ns| {
                // Number stored as string (e.g., "123")
                try writer.writeAll(ns);
            },
        }
    }
    
    /// Send a JSON-RPC request; returns response message.
    fn sendRequest(
        self: *LspClient,
        method: []const u8,
        params: std.json.Value,
    ) !Message {
        const id = self.request_id;
        self.request_id += 1;
        
        // Assert: Bounded pending requests
        std.debug.assert(self.pending_requests.count() < MAX_PENDING_REQUESTS);
        try self.pending_requests.put(id, {});
        
        // Build request object
        var request_obj = std.json.ObjectMap.init(self.allocator);
        defer request_obj.deinit();
        try request_obj.put("jsonrpc", std.json.Value{ .string = "2.0" });
        try request_obj.put("id", std.json.Value{ .integer = @intCast(id) });
        try request_obj.put("method", std.json.Value{ .string = method });
        try request_obj.put("params", params);
        
        // Serialize to JSON string
        const request_value = std.json.Value{ .object = request_obj };
        const json_string = try self.serialize_json_value(request_value);
        defer self.allocator.free(json_string);
        
        // Write to server stdin (LSP uses Content-Length header)
        if (self.server_process) |*proc| {
            const stdin = proc.stdin orelse return error.NoStdin;
            const header = try std.fmt.allocPrint(
                self.allocator,
                "Content-Length: {d}\r\n\r\n",
                .{json_string.len},
            );
            defer self.allocator.free(header);
            
            try stdin.writeAll(header);
            try stdin.writeAll(json_string);
        }
        
        // Read response from server stdout
        const response = try self.readResponse();
        _ = self.pending_requests.remove(id);
        
        return response;
    }
    
    /// Send a JSON-RPC notification (no response expected).
    fn sendNotification(
        self: *LspClient,
        method: []const u8,
        params: std.json.Value,
    ) !void {
        // Build notification object
        var notification_obj = std.json.ObjectMap.init(self.allocator);
        defer notification_obj.deinit();
        try notification_obj.put("jsonrpc", std.json.Value{ .string = "2.0" });
        try notification_obj.put("method", std.json.Value{ .string = method });
        try notification_obj.put("params", params);
        
        // Serialize to JSON string
        const notification_value = std.json.Value{ .object = notification_obj };
        const json_string = try self.serialize_json_value(notification_value);
        defer self.allocator.free(json_string);
        
        // Write to server stdin
        if (self.server_process) |*proc| {
            const stdin = proc.stdin orelse return error.NoStdin;
            const header = try std.fmt.allocPrint(
                self.allocator,
                "Content-Length: {d}\r\n\r\n",
                .{json_string.len},
            );
            defer self.allocator.free(header);
            
            try stdin.writeAll(header);
            try stdin.writeAll(json_string);
        }
    }
    
    /// Read JSON-RPC response from server stdout.
    fn readResponse(self: *LspClient) !Message {
        if (self.server_process == null) return error.NoServer;
        const stdout = self.server_process.?.stdout orelse return error.NoStdout;
        
        // Read Content-Length header
        // Bounded: Max 1024 bytes for header
        var header_buf: [1024]u8 = undefined;
        var header_len: u32 = 0;
        
        // Assert: Bounded header length
        std.debug.assert(header_buf.len <= std.math.maxInt(u32));
        while (header_len < header_buf.len) {
            const byte = try stdout.readByte();
            // Assert: Header length within bounds
            std.debug.assert(header_len < header_buf.len);
            header_buf[header_len] = byte;
            header_len += 1;
            
            if (header_len >= 2 and header_buf[header_len - 2] == '\r' and header_buf[header_len - 1] == '\n') {
                if (header_len >= 4 and 
                    header_buf[header_len - 4] == '\r' and 
                    header_buf[header_len - 3] == '\n') {
                    // Double CRLF: end of headers
                    break;
                }
            }
        }
        
        // Parse Content-Length
        const header_str = header_buf[0..header_len];
        var content_length: u32 = 0;
        if (std.mem.indexOf(u8, header_str, "Content-Length: ")) |idx| {
            const start = idx + "Content-Length: ".len;
            const end = std.mem.indexOfScalar(u8, header_str[start..], '\r') orelse header_str.len;
            // Assert: Content length fits in u32
            const parsed = try std.fmt.parseInt(u64, header_str[start..end], 10);
            std.debug.assert(parsed <= std.math.maxInt(u32));
            content_length = @intCast(parsed);
        }
        
        // Assert: Bounded content length (prevent memory exhaustion)
        std.debug.assert(content_length <= 10 * 1024 * 1024); // Max 10MB
        
        // Read JSON body
        var json_buf = try self.allocator.alloc(u8, content_length);
        defer self.allocator.free(json_buf);
        
        var bytes_read: u32 = 0;
        while (bytes_read < content_length) {
            const read_count = try stdout.read(json_buf[bytes_read..]);
            // Assert: Read count fits in u32
            std.debug.assert(read_count <= std.math.maxInt(u32));
            bytes_read += @intCast(read_count);
        }
        
        // Assert: All bytes read
        std.debug.assert(bytes_read == content_length);
        
        // Parse JSON response
        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            json_buf,
            .{},
        );
        defer parsed.deinit();
        
        const root = parsed.value;
        var message = Message{};
        
        if (root == .object) {
            const obj = root.object;
            if (obj.get("id")) |id| {
                message.id = @intCast(id.integer);
            }
            if (obj.get("method")) |method| {
                message.method = method.string;
            }
            if (obj.get("result")) |result| {
                message.result = result;
            }
            if (obj.get("error")) |err| {
                if (err == .object) {
                    const err_obj = err.object;
                    message.lsp_error = LspError{
                        .code = if (err_obj.get("code")) |c| @intCast(c.integer) else 0,
                        .message = if (err_obj.get("message")) |m| m.string else "",
                        .data = if (err_obj.get("data")) |d| d else null,
                    };
                }
            }
        }
        
        return message;
    }
};

test "lsp client lifecycle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var client = LspClient.init(arena.allocator());
    defer client.deinit();
    // Stub: don't actually spawn ZLS in tests.
}

test "lsp snapshot model" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var client = LspClient.init(arena.allocator());
    defer client.deinit();
    
    // Test snapshot creation
    try client.didOpen("file:///test.zig", "const x = 1;");
    std.debug.assert(client.snapshots.items.len == 1);
    std.debug.assert(client.snapshots.items[0].version == 0);
    
    // Test incremental change
    const change = LspClient.TextDocumentChange{
        .range = LspClient.Range{
            .start = LspClient.Position{ .line = 0, .character = 11 },
            .end = LspClient.Position{ .line = 0, .character = 12 },
        },
        .text = "2",
    };
    try client.didChange("file:///test.zig", &.{change});
    std.debug.assert(client.snapshots.items[0].version == 1);
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].text, "const x = 2;"));
}

