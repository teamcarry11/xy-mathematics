//! Grain Core Async Pattern: Event-driven async operations using Flow Agent Event Bus.
//!
//! Why: Enable async HTTP, WebSocket, and File I/O operations via event bus.
//! Architecture: Publish events to Flow Agent Event Bus for async responses.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const api_server = @import("api_server.zig");
const http_errors = @import("http_errors.zig");
const websocket_errors = @import("websocket_errors.zig");
const file_io_errors = @import("file_io_errors.zig");
const json_helpers = @import("json_helpers.zig");

// Bounded: Max async request ID.
pub const MAX_ASYNC_REQUEST_ID: u32 = 4294967295;

// Bounded: Max async response payload size.
pub const MAX_ASYNC_PAYLOAD_SIZE: u32 = 65536;

// Async HTTP request context.
pub const AsyncHttpRequest = struct {
    request_id: u32,
    agent_id: u32,
    callback_fn: *const fn (
        request_id: u32,
        result: http_errors.HttpClientError!api_server.HttpResponse,
        user_data: ?*anyopaque,
    ) void,
    user_data: ?*anyopaque,
};

// Async WebSocket connection context.
pub const AsyncWebSocketConnection = struct {
    connection_id: u32,
    agent_id: u32,
    callback_fn: *const fn (
        connection_id: u32,
        result: websocket_errors.WebSocketError!void,
        user_data: ?*anyopaque,
    ) void,
    user_data: ?*anyopaque,
};

// Async File I/O operation context.
pub const AsyncFileIoOperation = struct {
    operation_id: u32,
    agent_id: u32,
    callback_fn: *const fn (
        operation_id: u32,
        result: file_io_errors.FileIoError!void,
        user_data: ?*anyopaque,
    ) void,
    user_data: ?*anyopaque,
};

// Publish HTTP request completed event to event bus.
pub fn publish_http_request_completed(
    event_bus: anytype,
    request_id: u32,
    agent_id: u32,
    response: api_server.HttpResponse,
    timestamp: u64,
) bool {
    std.debug.assert(request_id > 0);
    std.debug.assert(agent_id > 0);
    std.debug.assert(timestamp > 0);
    var payload: [MAX_ASYNC_PAYLOAD_SIZE]u8 = undefined;
    var payload_len: u32 = 0;
    const response_json = format_http_response_json(response, &payload, &payload_len);
    if (!response_json) {
        return false;
    }
    return event_bus.publish_event_with_payload(
        .http_request_completed,
        agent_id,
        0,
        timestamp,
        payload[0..payload_len],
    );
}

// Publish HTTP request failed event to event bus.
pub fn publish_http_request_failed(
    event_bus: anytype,
    request_id: u32,
    agent_id: u32,
    error: http_errors.HttpClientError,
    timestamp: u64,
) bool {
    std.debug.assert(request_id > 0);
    std.debug.assert(agent_id > 0);
    std.debug.assert(timestamp > 0);
    var payload: [MAX_ASYNC_PAYLOAD_SIZE]u8 = undefined;
    var payload_len: u32 = 0;
    const error_json = format_http_error_json(error, &payload, &payload_len);
    if (!error_json) {
        return false;
    }
    return event_bus.publish_event_with_payload(
        .http_request_failed,
        agent_id,
        0,
        timestamp,
        payload[0..payload_len],
    );
}

// Format HTTP response as JSON for event payload.
fn format_http_response_json(
    response: api_server.HttpResponse,
    payload_out: []u8,
    payload_len_out: *u32,
) bool {
    std.debug.assert(payload_out.len >= MAX_ASYNC_PAYLOAD_SIZE);
    var pos: u32 = 0;
    payload_out[pos] = '{';
    pos += 1;
    if (!json_helpers.write_json_string(payload_out, &pos, "status")) {
        return false;
    }
    payload_out[pos] = ':';
    pos += 1;
    if (!json_helpers.write_json_number(payload_out, &pos, response.status.code)) {
        return false;
    }
    payload_out[pos] = ',';
    pos += 1;
    if (!json_helpers.write_json_string(payload_out, &pos, "body")) {
        return false;
    }
    payload_out[pos] = ':';
    pos += 1;
    const body_str = response.body[0..response.body_len];
    if (!json_helpers.write_json_string(payload_out, &pos, body_str)) {
        return false;
    }
    payload_out[pos] = '}';
    pos += 1;
    payload_len_out.* = pos;
    return true;
}

// Format HTTP error as JSON for event payload.
fn format_http_error_json(
    error: http_errors.HttpClientError,
    payload_out: []u8,
    payload_len_out: *u32,
) bool {
    std.debug.assert(payload_out.len >= MAX_ASYNC_PAYLOAD_SIZE);
    const error_msg = http_errors.get_http_error_message(error);
    var pos: u32 = 0;
    payload_out[pos] = '{';
    pos += 1;
    if (!json_helpers.write_json_string(payload_out, &pos, "error")) {
        return false;
    }
    payload_out[pos] = ':';
    pos += 1;
    if (!json_helpers.write_json_string(payload_out, &pos, error_msg)) {
        return false;
    }
    payload_out[pos] = '}';
    pos += 1;
    payload_len_out.* = pos;
    return true;
}
