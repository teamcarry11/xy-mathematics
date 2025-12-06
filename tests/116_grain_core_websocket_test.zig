const std = @import("std");
const testing = std.testing;
const websocket = @import("grain_core").websocket;
const api_server = @import("grain_core").api_server;

test "websocket manager init" {
    const manager = websocket.WebSocketManager.init();
    std.debug.assert(manager.connections_len == 0);
    std.debug.assert(manager.next_connection_id == 1);
}

test "websocket manager add connection" {
    var manager = websocket.WebSocketManager.init();
    const conn = manager.add_connection(1);
    std.debug.assert(conn != null);
    std.debug.assert(manager.connections_len == 1);
    std.debug.assert(conn.?.connection_id == 1);
    std.debug.assert(conn.?.socket_fd == 1);
    std.debug.assert(conn.?.active == true);
}

test "websocket manager remove connection" {
    var manager = websocket.WebSocketManager.init();
    const conn = manager.add_connection(1);
    std.debug.assert(conn != null);
    const removed = manager.remove_connection(conn.?.connection_id);
    std.debug.assert(removed);
    std.debug.assert(manager.connections_len == 0);
}

test "websocket manager find connection" {
    var manager = websocket.WebSocketManager.init();
    const conn = manager.add_connection(1);
    std.debug.assert(conn != null);
    const found = manager.find_connection(conn.?.connection_id);
    std.debug.assert(found != null);
    std.debug.assert(found.?.connection_id == conn.?.connection_id);
}

test "generate websocket accept" {
    const client_key = "dGhlIHNhbXBsZSBub25jZQ==";
    var accept_buf: [websocket.MAX_WEBSOCKET_ACCEPT_LEN]u8 = undefined;
    const accept_len = websocket.generate_websocket_accept(client_key, &accept_buf);
    std.debug.assert(accept_len > 0);
    std.debug.assert(accept_len <= websocket.MAX_WEBSOCKET_ACCEPT_LEN);
}

test "is websocket upgrade" {
    var request = api_server.HttpRequest.init();
    request.method = api_server.HttpMethod.get;
    _ = request.add_header("Upgrade", "websocket");
    _ = request.add_header("Connection", "Upgrade");
    _ = request.add_header("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==");
    const is_upgrade = websocket.is_websocket_upgrade(&request);
    std.debug.assert(is_upgrade);
}

test "is not websocket upgrade" {
    var request = api_server.HttpRequest.init();
    request.method = api_server.HttpMethod.get;
    _ = request.add_header("Upgrade", "http");
    const is_upgrade = websocket.is_websocket_upgrade(&request);
    std.debug.assert(!is_upgrade);
}

test "parse websocket frame" {
    var frame = websocket.WebSocketFrame.init();
    const buffer = [_]u8{ 0x81, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F };
    const parsed = websocket.parse_websocket_frame(&buffer, &frame);
    std.debug.assert(parsed);
    std.debug.assert(frame.flags.fin == true);
    std.debug.assert(frame.flags.opcode == websocket.FrameOpcode.text);
    std.debug.assert(frame.payload_len == 5);
}

test "generate websocket frame" {
    var frame = websocket.WebSocketFrame.init();
    frame.flags.fin = true;
    frame.flags.opcode = websocket.FrameOpcode.text;
    frame.flags.masked = false;
    const message = "Hello";
    var i: u32 = 0;
    while (i < message.len) : (i += 1) {
        frame.payload[i] = message[i];
    }
    frame.payload_len = @intCast(message.len);
    var buffer: [websocket.MAX_FRAME_SIZE + 14]u8 = undefined;
    const frame_len = websocket.generate_websocket_frame(&frame, &buffer);
    std.debug.assert(frame_len > 0);
    std.debug.assert(buffer[0] == 0x81);
    std.debug.assert(buffer[1] == 0x05);
}

