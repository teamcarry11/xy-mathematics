//! Tests for Grain Carry Core WebSocket Client.
//!
//! Why: Verify WebSocket client functionality for livestream coordination.
//! Architecture: Comprehensive test coverage for WebSocket client.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-033256-pst: Grain Carry Agent

const std = @import("std");
const testing = std.testing;
const grain_carry_core = @import("grain_carry_core");
const websocket = grain_carry_core.websocket.client;

test "websocket client manager initialization" {
    var manager = websocket.WebSocketClientManager.init();
    
    std.debug.assert(manager.clients_len == 0);
    std.debug.assert(manager.next_connection_id == 1);
}

test "websocket client manager create client" {
    var manager = websocket.WebSocketClientManager.init();
    const client = manager.create_client();
    
    try testing.expect(client != null);
    try testing.expect(client.?.connection_id == 1);
    try testing.expect(client.?.state == websocket.ClientState.disconnected);
    try testing.expect(manager.clients_len == 1);
}

test "websocket client set url" {
    var manager = websocket.WebSocketClientManager.init();
    const client = manager.create_client();
    try testing.expect(client != null);
    
    const url = "ws://localhost:8080/ws";
    const success = client.?.set_url(url);
    
    try testing.expect(success);
    try testing.expect(client.?.url_len == url.len);
}

test "websocket client generate client key" {
    var key_buf: [32]u8 = undefined;
    const key_len = websocket.generate_client_key(&key_buf);
    
    try testing.expect(key_len > 0);
    try testing.expect(key_len <= 32);
}

test "websocket client build upgrade request" {
    const url = "/ws";
    var key_buf: [32]u8 = undefined;
    const key_len = websocket.generate_client_key(&key_buf);
    try testing.expect(key_len > 0);
    
    var request_buf: [1024]u8 = undefined;
    const request_len = websocket.build_upgrade_request(
        url,
        key_buf[0..key_len],
        &request_buf,
    );
    
    try testing.expect(request_len > 0);
    try testing.expect(request_len <= 1024);
}

test "websocket client manager find client" {
    var manager = websocket.WebSocketClientManager.init();
    const client = manager.create_client();
    try testing.expect(client != null);
    
    const found = manager.find_client(client.?.connection_id);
    
    try testing.expect(found != null);
    try testing.expect(found.?.connection_id == client.?.connection_id);
}

test "websocket client manager remove client" {
    var manager = websocket.WebSocketClientManager.init();
    const client = manager.create_client();
    try testing.expect(client != null);
    try testing.expect(manager.clients_len == 1);
    
    const success = manager.remove_client(client.?.connection_id);
    
    try testing.expect(success);
    try testing.expect(manager.clients_len == 0);
}

test "websocket client set connected" {
    var manager = websocket.WebSocketClientManager.init();
    const client = manager.create_client();
    try testing.expect(client != null);
    
    websocket.set_connected(client.?);
    
    try testing.expect(client.?.state == websocket.ClientState.connected);
    try testing.expect(client.?.created_at > 0);
    try testing.expect(client.?.last_activity > 0);
}

test "websocket client set disconnected" {
    var manager = websocket.WebSocketClientManager.init();
    const client = manager.create_client();
    try testing.expect(client != null);
    websocket.set_connected(client.?);
    
    websocket.set_disconnected(client.?);
    
    try testing.expect(client.?.state == websocket.ClientState.disconnected);
    try testing.expect(client.?.socket_fd == 0);
}

test "websocket client send ping" {
    var manager = websocket.WebSocketClientManager.init();
    const client = manager.create_client();
    try testing.expect(client != null);
    websocket.set_connected(client.?);
    
    var frame_buf: [1024]u8 = undefined;
    const frame_len = websocket.send_ping(client.?, &frame_buf);
    
    try testing.expect(frame_len > 0);
    try testing.expect(frame_len <= 1024);
}

test "websocket client send pong" {
    var manager = websocket.WebSocketClientManager.init();
    const client = manager.create_client();
    try testing.expect(client != null);
    websocket.set_connected(client.?);
    
    const ping_payload = "ping";
    var frame_buf: [1024]u8 = undefined;
    const frame_len = websocket.send_pong(client.?, ping_payload, &frame_buf);
    
    try testing.expect(frame_len > 0);
    try testing.expect(frame_len <= 1024);
}

test "websocket client close connection" {
    var manager = websocket.WebSocketClientManager.init();
    const client = manager.create_client();
    try testing.expect(client != null);
    websocket.set_connected(client.?);
    
    var frame_buf: [1024]u8 = undefined;
    const frame_len = websocket.close_connection(client.?, 1000, "Normal closure", &frame_buf);
    
    try testing.expect(frame_len > 0);
    try testing.expect(frame_len <= 1024);
    try testing.expect(client.?.state == websocket.ClientState.closing);
}

