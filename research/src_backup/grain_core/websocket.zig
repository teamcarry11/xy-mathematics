//! Grain Core WebSocket: WebSocket protocol support for real-time communication.
//!
//! Why: Provide WebSocket support for Silo Agent and Carry Agent (livestream coordination).
//! Architecture: WebSocket handshake, frame parsing/generation, connection management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const api_server = @import("api_server.zig");

// Bounded: Max WebSocket connections.
pub const MAX_WEBSOCKET_CONNECTIONS: u32 = 128;

// Bounded: Max WebSocket frame size (64KB).
pub const MAX_FRAME_SIZE: u32 = 65536;

// Bounded: Max WebSocket message size (64KB).
pub const MAX_MESSAGE_SIZE: u32 = 65536;

// Bounded: Max WebSocket key length (base64 encoded).
pub const MAX_WEBSOCKET_KEY_LEN: u32 = 32;

// Bounded: Max WebSocket accept length (base64 encoded).
pub const MAX_WEBSOCKET_ACCEPT_LEN: u32 = 32;

// WebSocket frame opcode.
pub const FrameOpcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};

// WebSocket frame flags.
pub const FrameFlags = struct {
    fin: bool,
    rsv1: bool,
    rsv2: bool,
    rsv3: bool,
    opcode: FrameOpcode,
    masked: bool,
    payload_len: u64,
    mask_key: [4]u8,
};

// WebSocket connection state.
pub const ConnectionState = enum(u8) {
    connecting,
    open,
    closing,
    closed,
};

// WebSocket connection.
pub const WebSocketConnection = struct {
    connection_id: u32,
    state: ConnectionState,
    socket_fd: u32,
    created_at: u64,
    last_activity: u64,
    path: [api_server.MAX_PATH_LEN]u8,
    path_len: u32,
    subprotocol: [64]u8,
    subprotocol_len: u32,
    active: bool,

    pub fn init(connection_id: u32, socket_fd: u32) WebSocketConnection {
        std.debug.assert(connection_id > 0);
        std.debug.assert(socket_fd > 0);
        var conn = WebSocketConnection{
            .connection_id = connection_id,
            .state = ConnectionState.connecting,
            .socket_fd = socket_fd,
            .created_at = 0,
            .last_activity = 0,
            .path = undefined,
            .path_len = 0,
            .subprotocol = undefined,
            .subprotocol_len = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < api_server.MAX_PATH_LEN) : (i += 1) {
            conn.path[i] = 0;
        }
        i = 0;
        while (i < 64) : (i += 1) {
            conn.subprotocol[i] = 0;
        }
        return conn;
    }
};

// WebSocket frame.
pub const WebSocketFrame = struct {
    flags: FrameFlags,
    payload: [MAX_FRAME_SIZE]u8,
    payload_len: u32,

    pub fn init() WebSocketFrame {
        var frame = WebSocketFrame{
            .flags = FrameFlags{
                .fin = false,
                .rsv1 = false,
                .rsv2 = false,
                .rsv3 = false,
                .opcode = FrameOpcode.text,
                .masked = false,
                .payload_len = 0,
                .mask_key = undefined,
            },
            .payload = undefined,
            .payload_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_FRAME_SIZE) : (i += 1) {
            frame.payload[i] = 0;
        }
        return frame;
    }
};

// WebSocket manager: manages WebSocket connections.
pub const WebSocketManager = struct {
    connections: [MAX_WEBSOCKET_CONNECTIONS]WebSocketConnection,
    connections_len: u32,
    next_connection_id: u32,

    pub fn init() WebSocketManager {
        var manager = WebSocketManager{
            .connections = undefined,
            .connections_len = 0,
            .next_connection_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_WEBSOCKET_CONNECTIONS) : (i += 1) {
            manager.connections[i] = WebSocketConnection.init(0, 0);
        }
        return manager;
    }

    // Add WebSocket connection.
    pub fn add_connection(
        self: *WebSocketManager,
        socket_fd: u32,
    ) ?*WebSocketConnection {
        std.debug.assert(socket_fd > 0);
        if (self.connections_len >= MAX_WEBSOCKET_CONNECTIONS) {
            return null;
        }
        const conn_id = self.next_connection_id;
        self.next_connection_id += 1;
        self.connections[self.connections_len] = WebSocketConnection.init(
            conn_id,
            socket_fd,
        );
        self.connections[self.connections_len].active = true;
        const conn = &self.connections[self.connections_len];
        self.connections_len += 1;
        return conn;
    }

    // Remove WebSocket connection.
    pub fn remove_connection(
        self: *WebSocketManager,
        connection_id: u32,
    ) bool {
        std.debug.assert(connection_id > 0);
        var i: u32 = 0;
        while (i < self.connections_len) : (i += 1) {
            if (self.connections[i].connection_id == connection_id) {
                self.connections[i].active = false;
                self.connections[i].state = ConnectionState.closed;
                var j: u32 = i;
                while (j < self.connections_len - 1) : (j += 1) {
                    self.connections[j] = self.connections[j + 1];
                }
                self.connections_len -= 1;
                return true;
            }
        }
        return false;
    }

    // Find connection by ID.
    pub fn find_connection(
        self: *WebSocketManager,
        connection_id: u32,
    ) ?*WebSocketConnection {
        std.debug.assert(connection_id > 0);
        var i: u32 = 0;
        while (i < self.connections_len) : (i += 1) {
            if (self.connections[i].connection_id == connection_id) {
                return &self.connections[i];
            }
        }
        return null;
    }
};

// Generate WebSocket accept key from client key.
pub fn generate_websocket_accept(
    client_key: []const u8,
    accept_buf: []u8,
) u32 {
    std.debug.assert(client_key.len > 0);
    std.debug.assert(accept_buf.len >= MAX_WEBSOCKET_ACCEPT_LEN);
    const magic_string = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    var combined: [MAX_WEBSOCKET_KEY_LEN + 36]u8 = undefined;
    var combined_len: u32 = 0;
    const key_len = @min(client_key.len, MAX_WEBSOCKET_KEY_LEN);
    var i: u32 = 0;
    while (i < key_len) : (i += 1) {
        combined[combined_len] = client_key[i];
        combined_len += 1;
    }
    i = 0;
    while (i < 36) : (i += 1) {
        combined[combined_len] = magic_string[i];
        combined_len += 1;
    }
    var hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(combined[0..combined_len], &hash, .{});
    var base64_buf: [28]u8 = undefined;
    const base64_len = std.base64.standard.Encoder.calcSize(20);
    _ = std.base64.standard.Encoder.encode(&base64_buf, &hash);
    var j: u32 = 0;
    while (j < base64_len and j < accept_buf.len) : (j += 1) {
        accept_buf[j] = base64_buf[j];
    }
    return @intCast(base64_len);
}

// Check if HTTP request is WebSocket upgrade.
pub fn is_websocket_upgrade(request: *api_server.HttpRequest) bool {
    const upgrade_header = request.get_header("Upgrade");
    if (upgrade_header == null) {
        return false;
    }
    const upgrade_val = upgrade_header.?;
    if (upgrade_val.len < 9) {
        return false;
    }
    const websocket_str = "websocket";
    var i: u32 = 0;
    var match_count: u32 = 0;
    while (i < upgrade_val.len and match_count < 9) : (i += 1) {
        const c = upgrade_val[i];
        const ws_c = websocket_str[match_count];
        if (c == ws_c or c == (ws_c - 32)) {
            match_count += 1;
        } else {
            match_count = 0;
        }
    }
    return match_count == 9;
}

// Parse WebSocket frame from buffer.
pub fn parse_websocket_frame(
    buffer: []const u8,
    frame: *WebSocketFrame,
) bool {
    std.debug.assert(buffer.len > 0);
    if (buffer.len < 2) {
        return false;
    }
    const byte1 = buffer[0];
    const byte2 = buffer[1];
    frame.flags.fin = (byte1 & 0x80) != 0;
    frame.flags.rsv1 = (byte1 & 0x40) != 0;
    frame.flags.rsv2 = (byte1 & 0x20) != 0;
    frame.flags.rsv3 = (byte1 & 0x10) != 0;
    const opcode_val = @as(u4, @truncate(byte1 & 0x0F));
    frame.flags.opcode = @enumFromInt(opcode_val);
    frame.flags.masked = (byte2 & 0x80) != 0;
    var payload_len: u64 = @as(u64, byte2 & 0x7F);
    var header_len: u32 = 2;
    if (payload_len == 126) {
        if (buffer.len < 4) {
            return false;
        }
        payload_len = (@as(u64, buffer[2]) << 8) | @as(u64, buffer[3]);
        header_len = 4;
    } else if (payload_len == 127) {
        if (buffer.len < 10) {
            return false;
        }
        payload_len = (@as(u64, buffer[2]) << 56) |
            (@as(u64, buffer[3]) << 48) |
            (@as(u64, buffer[4]) << 40) |
            (@as(u64, buffer[5]) << 32) |
            (@as(u64, buffer[6]) << 24) |
            (@as(u64, buffer[7]) << 16) |
            (@as(u64, buffer[8]) << 8) |
            @as(u64, buffer[9]);
        header_len = 10;
    }
    if (payload_len > MAX_FRAME_SIZE) {
        return false;
    }
    frame.flags.payload_len = payload_len;
    if (frame.flags.masked) {
        if (buffer.len < header_len + 4) {
            return false;
        }
        var i: u32 = 0;
        while (i < 4) : (i += 1) {
            frame.flags.mask_key[i] = buffer[header_len + i];
        }
        header_len += 4;
    }
    if (buffer.len < header_len + payload_len) {
        return false;
    }
    const payload_start = header_len;
    var i: u32 = 0;
    while (i < payload_len) : (i += 1) {
        if (frame.flags.masked) {
            frame.payload[i] = buffer[payload_start + i] ^
                frame.flags.mask_key[i % 4];
        } else {
            frame.payload[i] = buffer[payload_start + i];
        }
    }
    frame.payload_len = @intCast(payload_len);
    return true;
}

// Generate WebSocket frame to buffer.
pub fn generate_websocket_frame(
    frame: *const WebSocketFrame,
    buffer: []u8,
) u32 {
    std.debug.assert(buffer.len >= MAX_FRAME_SIZE + 14);
    std.debug.assert(frame.payload_len <= MAX_FRAME_SIZE);
    var offset: u32 = 0;
    var byte1: u8 = 0;
    if (frame.flags.fin) {
        byte1 |= 0x80;
    }
    if (frame.flags.rsv1) {
        byte1 |= 0x40;
    }
    if (frame.flags.rsv2) {
        byte1 |= 0x20;
    }
    if (frame.flags.rsv3) {
        byte1 |= 0x10;
    }
    byte1 |= @intFromEnum(frame.flags.opcode);
    buffer[offset] = byte1;
    offset += 1;
    var byte2: u8 = 0;
    if (frame.flags.masked) {
        byte2 |= 0x80;
    }
    const payload_len = frame.payload_len;
    if (payload_len < 126) {
        byte2 |= @as(u8, @truncate(payload_len));
        buffer[offset] = byte2;
        offset += 1;
    } else if (payload_len < 65536) {
        byte2 |= 126;
        buffer[offset] = byte2;
        offset += 1;
        buffer[offset] = @as(u8, @truncate(payload_len >> 8));
        offset += 1;
        buffer[offset] = @as(u8, @truncate(payload_len));
        offset += 1;
    } else {
        byte2 |= 127;
        buffer[offset] = byte2;
        offset += 1;
        var i: u32 = 0;
        while (i < 8) : (i += 1) {
            const byte_idx: u32 = 7 - i;
            const shift_amt: u6 = @intCast(byte_idx * 8);
            buffer[offset] = @as(u8, @truncate(payload_len >> shift_amt));
            offset += 1;
        }
    }
    if (frame.flags.masked) {
        var i: u32 = 0;
        while (i < 4) : (i += 1) {
            buffer[offset] = frame.flags.mask_key[i];
            offset += 1;
        }
    }
    var i: u32 = 0;
    while (i < payload_len) : (i += 1) {
        if (frame.flags.masked) {
            buffer[offset] = frame.payload[i] ^ frame.flags.mask_key[i % 4];
        } else {
            buffer[offset] = frame.payload[i];
        }
        offset += 1;
    }
    return offset;
}

