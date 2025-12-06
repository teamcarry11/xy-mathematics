//! Grain Carry Core WebSocket Client: WebSocket client for mobile apps.
//!
//! Why: Provide WebSocket client functionality for livestream coordination.
//! Architecture: WebSocket client connection, frame sending/receiving, message handling.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-06-033256-pst: Grain Carry Agent

const std = @import("std");
const grain_core_ws = @import("../../../grain_core/websocket.zig");
const grain_core_api = @import("../../../grain_core/api_server.zig");

// Bounded: Max WebSocket client connections.
pub const MAX_CLIENT_CONNECTIONS: u32 = 16;

// Bounded: Max WebSocket client message size.
pub const MAX_CLIENT_MESSAGE_SIZE: u32 = grain_core_ws.MAX_MESSAGE_SIZE;

// WebSocket client connection state.
pub const ClientState = enum(u8) {
    disconnected,
    connecting,
    connected,
    closing,
    closed,
};

// WebSocket client connection.
pub const WebSocketClient = struct {
    connection_id: u32,
    state: ClientState,
    url: [256]u8,
    url_len: u32,
    socket_fd: u32,
    created_at: u64,
    last_activity: u64,
    active: bool,

    pub fn init(connection_id: u32) WebSocketClient {
        std.debug.assert(connection_id > 0);
        var client = WebSocketClient{
            .connection_id = connection_id,
            .state = ClientState.disconnected,
            .url = undefined,
            .url_len = 0,
            .socket_fd = 0,
            .created_at = 0,
            .last_activity = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < 256) : (i += 1) {
            client.url[i] = 0;
        }
        std.debug.assert(client.state == ClientState.disconnected);
        std.debug.assert(client.connection_id > 0);
        return client;
    }

    // Set URL for connection.
    pub fn set_url(self: *WebSocketClient, url: []const u8) bool {
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= 256);
        if (url.len > 256) {
            return false;
        }
        std.mem.copyForwards(u8, &self.url, url);
        self.url_len = @intCast(url.len);
        std.debug.assert(self.url_len > 0);
        std.debug.assert(self.url_len <= 256);
        return true;
    }
};

// WebSocket client manager.
pub const WebSocketClientManager = struct {
    clients: [MAX_CLIENT_CONNECTIONS]WebSocketClient,
    clients_len: u32,
    next_connection_id: u32,

    pub fn init() WebSocketClientManager {
        var manager = WebSocketClientManager{
            .clients = undefined,
            .clients_len = 0,
            .next_connection_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_CLIENT_CONNECTIONS) : (i += 1) {
            manager.clients[i] = WebSocketClient.init(0);
        }
        std.debug.assert(manager.clients_len == 0);
        std.debug.assert(manager.next_connection_id == 1);
        return manager;
    }

    // Create new client connection.
    pub fn create_client(self: *WebSocketClientManager) ?*WebSocketClient {
        if (self.clients_len >= MAX_CLIENT_CONNECTIONS) {
            return null;
        }
        const conn_id = self.next_connection_id;
        self.next_connection_id += 1;
        self.clients[self.clients_len] = WebSocketClient.init(conn_id);
        self.clients[self.clients_len].active = true;
        const client = &self.clients[self.clients_len];
        self.clients_len += 1;
        std.debug.assert(client.connection_id > 0);
        std.debug.assert(client.state == ClientState.disconnected);
        return client;
    }

    // Find client by connection ID.
    pub fn find_client(
        self: *WebSocketClientManager,
        connection_id: u32,
    ) ?*WebSocketClient {
        std.debug.assert(connection_id > 0);
        var i: u32 = 0;
        while (i < self.clients_len) : (i += 1) {
            if (self.clients[i].connection_id == connection_id) {
                return &self.clients[i];
            }
        }
        return null;
    }

    // Remove client connection.
    pub fn remove_client(
        self: *WebSocketClientManager,
        connection_id: u32,
    ) bool {
        std.debug.assert(connection_id > 0);
        var i: u32 = 0;
        while (i < self.clients_len) : (i += 1) {
            if (self.clients[i].connection_id == connection_id) {
                self.clients[i].active = false;
                self.clients[i].state = ClientState.closed;
                var j: u32 = i;
                while (j < self.clients_len - 1) : (j += 1) {
                    self.clients[j] = self.clients[j + 1];
                }
                self.clients_len -= 1;
                return true;
            }
        }
        return false;
    }
};

// Generate WebSocket client key for handshake.
pub fn generate_client_key(key_buf: []u8) u32 {
    std.debug.assert(key_buf.len >= grain_core_ws.MAX_WEBSOCKET_KEY_LEN);
    var random_bytes: [16]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    const base64_len = std.base64.standard.Encoder.calcSize(16);
    _ = std.base64.standard.Encoder.encode(key_buf, &random_bytes);
    std.debug.assert(base64_len <= grain_core_ws.MAX_WEBSOCKET_KEY_LEN);
    return @intCast(base64_len);
}

// Build WebSocket upgrade request.
pub fn build_upgrade_request(
    url: []const u8,
    client_key: []const u8,
    request_buf: []u8,
) u32 {
    std.debug.assert(url.len > 0);
    std.debug.assert(client_key.len > 0);
    std.debug.assert(request_buf.len >= 1024);
    var request_len: u32 = 0;
    const get_prefix = "GET ";
    std.mem.copyForwards(u8, request_buf[request_len..], get_prefix);
    request_len += @intCast(get_prefix.len);
    std.mem.copyForwards(u8, request_buf[request_len..], url);
    request_len += @intCast(url.len);
    const get_suffix = " HTTP/1.1\r\n";
    std.mem.copyForwards(u8, request_buf[request_len..], get_suffix);
    request_len += @intCast(get_suffix.len);
    const host_line = "Host: localhost\r\n";
    std.mem.copyForwards(u8, request_buf[request_len..], host_line);
    request_len += @intCast(host_line.len);
    const upgrade_line = "Upgrade: websocket\r\n";
    std.mem.copyForwards(u8, request_buf[request_len..], upgrade_line);
    request_len += @intCast(upgrade_line.len);
    const connection_line = "Connection: Upgrade\r\n";
    std.mem.copyForwards(u8, request_buf[request_len..], connection_line);
    request_len += @intCast(connection_line.len);
    const key_header = "Sec-WebSocket-Key: ";
    std.mem.copyForwards(u8, request_buf[request_len..], key_header);
    request_len += @intCast(key_header.len);
    std.mem.copyForwards(u8, request_buf[request_len..], client_key);
    request_len += @intCast(client_key.len);
    const key_end = "\r\n";
    std.mem.copyForwards(u8, request_buf[request_len..], key_end);
    request_len += @intCast(key_end.len);
    const version_line = "Sec-WebSocket-Version: 13\r\n";
    std.mem.copyForwards(u8, request_buf[request_len..], version_line);
    request_len += @intCast(version_line.len);
    const end_line = "\r\n";
    std.mem.copyForwards(u8, request_buf[request_len..], end_line);
    request_len += @intCast(end_line.len);
    std.debug.assert(request_len <= request_buf.len);
    return request_len;
}

// Send text message via WebSocket.
pub fn send_text_message(
    client: *WebSocketClient,
    message: []const u8,
    frame_buf: []u8,
) u32 {
    std.debug.assert(client != null);
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= MAX_CLIENT_MESSAGE_SIZE);
    std.debug.assert(frame_buf.len >= grain_core_ws.MAX_FRAME_SIZE + 14);
    if (client.state != ClientState.connected) {
        return 0;
    }
    var frame = grain_core_ws.WebSocketFrame.init();
    frame.flags.fin = true;
    frame.flags.opcode = grain_core_ws.FrameOpcode.text;
    frame.flags.masked = true;
    frame.flags.payload_len = message.len;
    std.crypto.random.bytes(&frame.flags.mask_key);
    std.mem.copyForwards(u8, &frame.payload, message);
    frame.payload_len = @intCast(message.len);
    const frame_len = grain_core_ws.generate_websocket_frame(&frame, frame_buf);
    std.debug.assert(frame_len > 0);
    std.debug.assert(frame_len <= frame_buf.len);
    return frame_len;
}

// Send binary message via WebSocket.
pub fn send_binary_message(
    client: *WebSocketClient,
    message: []const u8,
    frame_buf: []u8,
) u32 {
    std.debug.assert(client != null);
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= MAX_CLIENT_MESSAGE_SIZE);
    std.debug.assert(frame_buf.len >= grain_core_ws.MAX_FRAME_SIZE + 14);
    if (client.state != ClientState.connected) {
        return 0;
    }
    var frame = grain_core_ws.WebSocketFrame.init();
    frame.flags.fin = true;
    frame.flags.opcode = grain_core_ws.FrameOpcode.binary;
    frame.flags.masked = true;
    frame.flags.payload_len = message.len;
    std.crypto.random.bytes(&frame.flags.mask_key);
    std.mem.copyForwards(u8, &frame.payload, message);
    frame.payload_len = @intCast(message.len);
    const frame_len = grain_core_ws.generate_websocket_frame(&frame, frame_buf);
    std.debug.assert(frame_len > 0);
    std.debug.assert(frame_len <= frame_buf.len);
    return frame_len;
}

// Parse received WebSocket frame.
pub fn parse_received_frame(
    buffer: []const u8,
    frame: *grain_core_ws.WebSocketFrame,
) bool {
    std.debug.assert(buffer.len > 0);
    std.debug.assert(frame != null);
    return grain_core_ws.parse_websocket_frame(buffer, frame);
}

// Handle received WebSocket frame (update client state).
pub fn handle_received_frame(
    client: *WebSocketClient,
    frame: *const grain_core_ws.WebSocketFrame,
) bool {
    std.debug.assert(client != null);
    std.debug.assert(frame != null);
    if (client.state != ClientState.connected) {
        return false;
    }
    const current_time: u64 = @intCast(std.time.timestamp());
    client.last_activity = current_time;
    std.debug.assert(client.last_activity > 0);
    return true;
}

// Send ping frame for keepalive.
pub fn send_ping(
    client: *WebSocketClient,
    frame_buf: []u8,
) u32 {
    std.debug.assert(client != null);
    std.debug.assert(frame_buf.len >= grain_core_ws.MAX_FRAME_SIZE + 14);
    if (client.state != ClientState.connected) {
        return 0;
    }
    var frame = grain_core_ws.WebSocketFrame.init();
    frame.flags.fin = true;
    frame.flags.opcode = grain_core_ws.FrameOpcode.ping;
    frame.flags.masked = true;
    frame.flags.payload_len = 0;
    std.crypto.random.bytes(&frame.flags.mask_key);
    frame.payload_len = 0;
    const frame_len = grain_core_ws.generate_websocket_frame(&frame, frame_buf);
    std.debug.assert(frame_len > 0);
    std.debug.assert(frame_len <= frame_buf.len);
    return frame_len;
}

// Send pong frame in response to ping.
pub fn send_pong(
    client: *WebSocketClient,
    ping_payload: []const u8,
    frame_buf: []u8,
) u32 {
    std.debug.assert(client != null);
    std.debug.assert(frame_buf.len >= grain_core_ws.MAX_FRAME_SIZE + 14);
    if (client.state != ClientState.connected) {
        return 0;
    }
    var frame = grain_core_ws.WebSocketFrame.init();
    frame.flags.fin = true;
    frame.flags.opcode = grain_core_ws.FrameOpcode.pong;
    frame.flags.masked = true;
    const payload_len = if (ping_payload.len <= grain_core_ws.MAX_FRAME_SIZE) ping_payload.len else grain_core_ws.MAX_FRAME_SIZE;
    frame.flags.payload_len = payload_len;
    std.crypto.random.bytes(&frame.flags.mask_key);
    if (payload_len > 0) {
        std.mem.copyForwards(u8, &frame.payload, ping_payload[0..payload_len]);
    }
    frame.payload_len = @intCast(payload_len);
    const frame_len = grain_core_ws.generate_websocket_frame(&frame, frame_buf);
    std.debug.assert(frame_len > 0);
    std.debug.assert(frame_len <= frame_buf.len);
    return frame_len;
}

// Close WebSocket connection.
pub fn close_connection(
    client: *WebSocketClient,
    code: u16,
    reason: []const u8,
    frame_buf: []u8,
) u32 {
    std.debug.assert(client != null);
    std.debug.assert(frame_buf.len >= grain_core_ws.MAX_FRAME_SIZE + 14);
    if (client.state == ClientState.closed or client.state == ClientState.closing) {
        return 0;
    }
    client.state = ClientState.closing;
    var frame = grain_core_ws.WebSocketFrame.init();
    frame.flags.fin = true;
    frame.flags.opcode = grain_core_ws.FrameOpcode.close;
    frame.flags.masked = true;
    var payload_len: u32 = 2;
    frame.payload[0] = @as(u8, @truncate(code >> 8));
    frame.payload[1] = @as(u8, @truncate(code));
    const reason_len = if (reason.len <= grain_core_ws.MAX_FRAME_SIZE - 2) reason.len else grain_core_ws.MAX_FRAME_SIZE - 2;
    if (reason_len > 0) {
        std.mem.copyForwards(u8, frame.payload[2..], reason[0..reason_len]);
        payload_len += reason_len;
    }
    frame.flags.payload_len = payload_len;
    std.crypto.random.bytes(&frame.flags.mask_key);
    frame.payload_len = payload_len;
    const frame_len = grain_core_ws.generate_websocket_frame(&frame, frame_buf);
    std.debug.assert(frame_len > 0);
    std.debug.assert(frame_len <= frame_buf.len);
    return frame_len;
}

// Update client state to connected.
pub fn set_connected(client: *WebSocketClient) void {
    std.debug.assert(client != null);
    client.state = ClientState.connected;
    const current_time: u64 = @intCast(std.time.timestamp());
    client.created_at = current_time;
    client.last_activity = current_time;
    std.debug.assert(client.state == ClientState.connected);
    std.debug.assert(client.created_at > 0);
    std.debug.assert(client.last_activity > 0);
}

// Update client state to disconnected.
pub fn set_disconnected(client: *WebSocketClient) void {
    std.debug.assert(client != null);
    client.state = ClientState.disconnected;
    client.socket_fd = 0;
    std.debug.assert(client.state == ClientState.disconnected);
}

// Extract text message from received frame.
pub fn extract_text_message(
    frame: *const grain_core_ws.WebSocketFrame,
    message_out: []u8,
) u32 {
    std.debug.assert(frame != null);
    std.debug.assert(message_out.len >= MAX_CLIENT_MESSAGE_SIZE);
    if (frame.flags.opcode != grain_core_ws.FrameOpcode.text) {
        return 0;
    }
    if (frame.payload_len > MAX_CLIENT_MESSAGE_SIZE) {
        return 0;
    }
    const msg_len = if (frame.payload_len <= message_out.len) frame.payload_len else message_out.len;
    std.mem.copyForwards(u8, message_out[0..msg_len], frame.payload[0..frame.payload_len]);
    std.debug.assert(msg_len > 0);
    std.debug.assert(msg_len <= MAX_CLIENT_MESSAGE_SIZE);
    return msg_len;
}

// Extract binary message from received frame.
pub fn extract_binary_message(
    frame: *const grain_core_ws.WebSocketFrame,
    message_out: []u8,
) u32 {
    std.debug.assert(frame != null);
    std.debug.assert(message_out.len >= MAX_CLIENT_MESSAGE_SIZE);
    if (frame.flags.opcode != grain_core_ws.FrameOpcode.binary) {
        return 0;
    }
    if (frame.payload_len > MAX_CLIENT_MESSAGE_SIZE) {
        return 0;
    }
    const msg_len = if (frame.payload_len <= message_out.len) frame.payload_len else message_out.len;
    std.mem.copyForwards(u8, message_out[0..msg_len], frame.payload[0..frame.payload_len]);
    std.debug.assert(msg_len > 0);
    std.debug.assert(msg_len <= MAX_CLIENT_MESSAGE_SIZE);
    return msg_len;
}

