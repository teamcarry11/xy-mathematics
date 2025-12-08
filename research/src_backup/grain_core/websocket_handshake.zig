//! Grain Core WebSocket Handshake: HTTP upgrade to WebSocket protocol.
//!
//! Why: Handle WebSocket handshake (HTTP upgrade) for API server integration.
//! Architecture: HTTP upgrade request/response, WebSocket key validation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const api_server = @import("api_server.zig");
const websocket = @import("websocket.zig");

// Handle WebSocket handshake (HTTP upgrade).
pub fn handle_websocket_handshake(
    request: *api_server.HttpRequest,
    response: *api_server.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    if (!websocket.is_websocket_upgrade(request)) {
        return false;
    }
    const sec_websocket_key = request.get_header("Sec-WebSocket-Key");
    if (sec_websocket_key == null) {
        response.status = api_server.HttpStatus.bad_request;
        return false;
    }
    const key = sec_websocket_key.?;
    if (key.len == 0) {
        response.status = api_server.HttpStatus.bad_request;
        return false;
    }
    var accept_buf: [websocket.MAX_WEBSOCKET_ACCEPT_LEN]u8 = undefined;
    const accept_len = websocket.generate_websocket_accept(key, &accept_buf);
    response.status = api_server.HttpStatus.ok;
    _ = response.add_header("Upgrade", "websocket");
    _ = response.add_header("Connection", "Upgrade");
    var accept_str: [websocket.MAX_WEBSOCKET_ACCEPT_LEN]u8 = undefined;
    var i: u32 = 0;
    while (i < accept_len and i < websocket.MAX_WEBSOCKET_ACCEPT_LEN) : (i += 1) {
        accept_str[i] = accept_buf[i];
    }
    _ = response.add_header("Sec-WebSocket-Accept", accept_str[0..accept_len]);
    return true;
}

