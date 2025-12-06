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
const grain_core_network = @import("../../../grain_core/network_stack.zig");

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

// Parse port from URL string.
fn parse_port_from_url(url: []const u8, start_idx: u32, port_out: *u16, path_start_out: *u32) bool {
    std.debug.assert(start_idx < url.len);
    std.debug.assert(port_out != null);
    std.debug.assert(path_start_out != null);
    var port_val: u32 = 0;
    var j: u32 = start_idx;
    var found_slash = false;
    while (j < url.len) : (j += 1) {
        const port_c = url[j];
        if (port_c == '/') {
            found_slash = true;
            path_start_out.* = j;
            break;
        }
        if (port_c < '0' or port_c > '9') {
            return false;
        }
        port_val = port_val * 10 + (port_c - '0');
        if (port_val > 65535) {
            return false;
        }
    }
    if (!found_slash) {
        path_start_out.* = url.len;
    }
    if (port_val == 0) {
        return false;
    }
    port_out.* = @intCast(port_val);
    std.debug.assert(port_out.* > 0);
    std.debug.assert(port_out.* <= 65535);
    return true;
}

// Extract host, port, and path from URL components.
fn extract_url_components(
    url: []const u8,
    url_offset: u32,
    host_out: []u8,
    port_out: *u16,
    path_out: []u8,
    host_end_out: *u32,
    path_start_out: *u32,
) bool {
    std.debug.assert(url_offset < url.len);
    std.debug.assert(host_out.len >= 256);
    std.debug.assert(path_out.len >= 256);
    std.debug.assert(port_out != null);
    std.debug.assert(host_end_out != null);
    std.debug.assert(path_start_out != null);
    var host_start = url_offset;
    var host_end: u32 = host_start;
    var port: u16 = 80;
    var path_start: u32 = url.len;
    var found_colon = false;
    var i: u32 = host_start;
    while (i < url.len) : (i += 1) {
        const c = url[i];
        if (c == ':') {
            if (found_colon) {
                return false;
            }
            found_colon = true;
            host_end = i;
            if (i + 1 >= url.len) {
                return false;
            }
            if (!parse_port_from_url(url, i + 1, &port, &path_start)) {
                return false;
            }
            break;
        } else if (c == '/') {
            host_end = i;
            path_start = i;
            break;
        }
    }
    if (!found_colon and path_start == url.len) {
        host_end = url.len;
    }
    const host_len = host_end - host_start;
    if (host_len == 0 or host_len > 255) {
        return false;
    }
    if (host_len > host_out.len) {
        return false;
    }
    std.mem.copyForwards(u8, host_out[0..host_len], url[host_start..host_end]);
    const path_len = if (path_start < url.len) url.len - path_start else 0;
    if (path_len > 0) {
        if (path_len > path_out.len) {
            return false;
        }
        std.mem.copyForwards(u8, path_out[0..path_len], url[path_start..]);
    } else {
        path_out[0] = '/';
    }
    port_out.* = port;
    host_end_out.* = host_end;
    path_start_out.* = path_start;
    std.debug.assert(host_len > 0);
    std.debug.assert(host_len <= 255);
    std.debug.assert(port > 0);
    std.debug.assert(port <= 65535);
    return true;
}

// Parse WebSocket URL (ws://host:port/path or wss://host:port/path).
pub fn parse_websocket_url(
    url: []const u8,
    host_out: []u8,
    port_out: *u16,
    path_out: []u8,
) bool {
    std.debug.assert(url.len > 0);
    std.debug.assert(host_out.len >= 256);
    std.debug.assert(path_out.len >= 256);
    std.debug.assert(port_out != null);
    if (url.len < 5) {
        return false;
    }
    const ws_prefix = "ws://";
    const wss_prefix = "wss://";
    var url_offset: u32 = 0;
    if (std.mem.startsWith(u8, url, ws_prefix)) {
        url_offset = 5;
    } else if (std.mem.startsWith(u8, url, wss_prefix)) {
        url_offset = 6;
    } else {
        return false;
    }
    if (url_offset >= url.len) {
        return false;
    }
    var host_end: u32 = 0;
    var path_start: u32 = 0;
    const success = extract_url_components(
        url,
        url_offset,
        host_out,
        port_out,
        path_out,
        &host_end,
        &path_start,
    );
    std.debug.assert(host_end > 0);
    return success;
}

// Parse HTTP response header to extract Sec-WebSocket-Accept.
pub fn parse_accept_header(
    response: []const u8,
    accept_out: []u8,
) bool {
    std.debug.assert(response.len > 0);
    std.debug.assert(accept_out.len >= grain_core_ws.MAX_WEBSOCKET_ACCEPT_LEN);
    const accept_header = "Sec-WebSocket-Accept: ";
    var i: u32 = 0;
    while (i < response.len) : (i += 1) {
        if (i + accept_header.len > response.len) {
            break;
        }
        if (std.mem.eql(u8, response[i..i + accept_header.len], accept_header)) {
            var accept_start = i + accept_header.len;
            var accept_end: u32 = accept_start;
            var j: u32 = accept_start;
            while (j < response.len) : (j += 1) {
                const c = response[j];
                if (c == '\r' or c == '\n') {
                    accept_end = j;
                    break;
                }
            }
            if (accept_end == accept_start) {
                return false;
            }
            const accept_len = accept_end - accept_start;
            if (accept_len > accept_out.len) {
                return false;
            }
            if (accept_len > grain_core_ws.MAX_WEBSOCKET_ACCEPT_LEN) {
                return false;
            }
            std.mem.copyForwards(u8, accept_out[0..accept_len], response[accept_start..accept_end]);
            std.debug.assert(accept_len > 0);
            std.debug.assert(accept_len <= grain_core_ws.MAX_WEBSOCKET_ACCEPT_LEN);
            return true;
        }
    }
    return false;
}

// Validate WebSocket accept key from server response.
pub fn validate_accept_key(
    client_key: []const u8,
    server_accept: []const u8,
) bool {
    std.debug.assert(client_key.len > 0);
    std.debug.assert(server_accept.len > 0);
    var expected_accept: [grain_core_ws.MAX_WEBSOCKET_ACCEPT_LEN]u8 = undefined;
    const expected_len = grain_core_ws.generate_websocket_accept(client_key, &expected_accept);
    if (expected_len != server_accept.len) {
        return false;
    }
    var i: u32 = 0;
    while (i < expected_len) : (i += 1) {
        if (expected_accept[i] != server_accept[i]) {
            return false;
        }
    }
    std.debug.assert(expected_len > 0);
    std.debug.assert(expected_len <= grain_core_ws.MAX_WEBSOCKET_ACCEPT_LEN);
    return true;
}

// Check if HTTP response indicates successful WebSocket upgrade.
pub fn is_upgrade_successful(response: []const u8) bool {
    std.debug.assert(response.len > 0);
    const status_line = "HTTP/1.1 101";
    if (response.len < status_line.len) {
        return false;
    }
    var i: u32 = 0;
    while (i < status_line.len) : (i += 1) {
        if (response[i] != status_line[i]) {
            return false;
        }
    }
    std.debug.assert(response.len >= status_line.len);
    return true;
}

