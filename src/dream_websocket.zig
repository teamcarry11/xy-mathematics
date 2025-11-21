const std = @import("std");

/// WebSocket client for Dream Protocol: low-latency bidirectional communication.
/// ~<~ Glow Airbend: explicit frames, bounded buffers.
/// ~~~~ Glow Waterbend: streaming frames flow deterministically.
pub const WebSocketClient = struct {
    allocator: std.mem.Allocator,
    stream: std.net.Stream,
    host: []const u8,
    
    // Bounded: Max 16MB frame size
    pub const MAX_FRAME_SIZE: usize = 16 * 1024 * 1024;
    
    // Bounded: Max 64KB control frame
    pub const MAX_CONTROL_FRAME_SIZE: usize = 64 * 1024;
    
    pub const Opcode = enum(u4) {
        continuation = 0x0,
        text = 0x1,
        binary = 0x2,
        close = 0x8,
        ping = 0x9,
        pong = 0xA,
    };
    
    pub const Frame = struct {
        fin: bool, // Final frame in message
        opcode: Opcode,
        masked: bool,
        payload: []const u8,
    };
    
    pub fn init(allocator: std.mem.Allocator, stream: std.net.Stream, host: []const u8) WebSocketClient {
        return WebSocketClient{
            .allocator = allocator,
            .stream = stream,
            .host = host,
        };
    }
    
    pub fn deinit(self: *WebSocketClient) void {
        self.stream.close();
        self.* = undefined;
    }
    
    /// Perform WebSocket handshake (HTTP upgrade).
    pub fn handshake(self: *WebSocketClient, path: []const u8) !void {
        // Assert: Path must be non-empty
        std.debug.assert(path.len > 0);
        
        // Generate WebSocket key (base64-encoded random 16 bytes)
        var key_buf: [16]u8 = undefined;
        std.crypto.random.bytes(&key_buf);
        const key = try std.base64.standard.Encoder.encode(&key_buf, &key_buf);
        
        // Build HTTP upgrade request
        var request_buf: [1024]u8 = undefined;
        var writer = std.io.fixedBufferStream(&request_buf).writer();
        
        try writer.print("GET {s} HTTP/1.1\r\n", .{path});
        try writer.print("Host: {s}\r\n", .{self.host});
        try writer.print("Upgrade: websocket\r\n", .{});
        try writer.print("Connection: Upgrade\r\n", .{});
        try writer.print("Sec-WebSocket-Key: {s}\r\n", .{key});
        try writer.print("Sec-WebSocket-Version: 13\r\n", .{});
        try writer.print("\r\n", .{});
        
        const request = writer.getWritten();
        
        // Send request
        try self.stream.writeAll(request);
        
        // Read response
        var response_buf: [4096]u8 = undefined;
        const response_len = try self.stream.read(&response_buf);
        const response = response_buf[0..response_len];
        
        // Parse response: check for "101 Switching Protocols"
        if (!std.mem.containsAtLeast(u8, response, 1, "101")) {
            return error.HandshakeFailed;
        }
        
        // Check for "Upgrade: websocket"
        if (!std.mem.containsAtLeast(u8, response, 1, "Upgrade: websocket")) {
            return error.HandshakeFailed;
        }
        
        // TODO: Verify Sec-WebSocket-Accept header
        // For now, assume handshake succeeded
    }
    
    /// Read WebSocket frame.
    pub fn readFrame(self: *WebSocketClient) !Frame {
        // Read first 2 bytes (FIN, opcode, mask, payload length)
        var header_buf: [2]u8 = undefined;
        _ = try self.stream.read(&header_buf);
        
        const byte1 = header_buf[0];
        const byte2 = header_buf[1];
        
        const fin = (byte1 & 0x80) != 0;
        const opcode_raw = @as(u4, @truncate(byte1 & 0x0F));
        const opcode = @as(Opcode, @enumFromInt(opcode_raw));
        const masked = (byte2 & 0x80) != 0;
        const payload_len_raw = byte2 & 0x7F;
        
        // Read extended payload length (if needed)
        var payload_len: u64 = payload_len_raw;
        if (payload_len_raw == 126) {
            var len_buf: [2]u8 = undefined;
            _ = try self.stream.read(&len_buf);
            payload_len = std.mem.readInt(u16, &len_buf, .big);
        } else if (payload_len_raw == 127) {
            var len_buf: [8]u8 = undefined;
            _ = try self.stream.read(&len_buf);
            payload_len = std.mem.readInt(u64, &len_buf, .big);
        }
        
        // Assert: Payload length must be within bounds
        if (opcode == .text or opcode == .binary) {
            std.debug.assert(payload_len <= MAX_FRAME_SIZE);
        } else {
            std.debug.assert(payload_len <= MAX_CONTROL_FRAME_SIZE);
        }
        
        // Read masking key (if present)
        var masking_key: [4]u8 = undefined;
        if (masked) {
            _ = try self.stream.read(&masking_key);
        }
        
        // Read payload
        var payload_buf = try self.allocator.alloc(u8, payload_len);
        errdefer self.allocator.free(payload_buf);
        _ = try self.stream.read(payload_buf);
        
        // Unmask payload (if masked)
        if (masked) {
            var i: usize = 0;
            while (i < payload_len) : (i += 1) {
                payload_buf[i] ^= masking_key[i % 4];
            }
        }
        
        return Frame{
            .fin = fin,
            .opcode = opcode,
            .masked = masked,
            .payload = payload_buf,
        };
    }
    
    /// Write WebSocket frame.
    pub fn writeFrame(self: *WebSocketClient, frame: Frame) !void {
        // Assert: Payload length must be within bounds
        if (frame.opcode == .text or frame.opcode == .binary) {
            std.debug.assert(frame.payload.len <= MAX_FRAME_SIZE);
        } else {
            std.debug.assert(frame.payload.len <= MAX_CONTROL_FRAME_SIZE);
        }
        
        // Build frame header
        var header_buf: [14]u8 = undefined; // Max header size (2 + 8 + 4)
        var header_len: usize = 0;
        
        // Byte 1: FIN + opcode
        header_buf[0] = if (frame.fin) 0x80 else 0x00;
        header_buf[0] |= @as(u8, @intFromEnum(frame.opcode));
        header_len = 1;
        
        // Byte 2: MASK + payload length
        const payload_len = frame.payload.len;
        if (payload_len < 126) {
            header_buf[1] = @as(u8, @intCast(payload_len));
            header_len = 2;
        } else if (payload_len < 65536) {
            header_buf[1] = 126;
            std.mem.writeInt(u16, header_buf[2..4], @as(u16, @intCast(payload_len)), .big);
            header_len = 4;
        } else {
            header_buf[1] = 127;
            std.mem.writeInt(u64, header_buf[2..10], payload_len, .big);
            header_len = 10;
        }
        
        // Client must mask frames
        // Generate masking key
        var masking_key: [4]u8 = undefined;
        std.crypto.random.bytes(&masking_key);
        header_buf[1] |= 0x80; // Set MASK bit
        std.mem.copyForwards(u8, header_buf[header_len..][0..4], &masking_key);
        header_len += 4;
        
        // Mask payload
        var masked_payload = try self.allocator.alloc(u8, payload_len);
        defer self.allocator.free(masked_payload);
        std.mem.copyForwards(u8, masked_payload, frame.payload);
        var i: usize = 0;
        while (i < payload_len) : (i += 1) {
            masked_payload[i] ^= masking_key[i % 4];
        }
        
        // Send header + masked payload
        try self.stream.writeAll(header_buf[0..header_len]);
        try self.stream.writeAll(masked_payload);
    }
    
    /// Close WebSocket connection.
    pub fn close(self: *WebSocketClient) !void {
        // Send close frame
        const close_frame = Frame{
            .fin = true,
            .opcode = .close,
            .masked = true,
            .payload = "",
        };
        try self.writeFrame(close_frame);
        
        // Read close frame from server
        const response_frame = try self.readFrame();
        if (response_frame.opcode != .close) {
            return error.UnexpectedFrame;
        }
        
        // Close stream
        self.stream.close();
    }
};

test "websocket client init" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    // Create dummy stream (would be real TCP stream in production)
    const dummy_stream = std.net.Stream{ .handle = 0 };
    var client = WebSocketClient.init(arena.allocator(), dummy_stream, "example.com");
    defer client.deinit();
    
    // Assert: Client initialized correctly
    std.debug.assert(std.mem.eql(u8, client.host, "example.com"));
}

