//! Grain OS API Server Network Integration: Network binding and connection handling.
//!
//! Why: Enable API server to accept actual HTTP connections from network.
//! Architecture: Server binding, listening, connection acceptance, request handling.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! Note: Currently uses std.net for network operations. Will migrate to kernel
//! network syscalls when available (Phase 61: Network Stack Enhancements).

const std = @import("std");
const api_server = @import("api_server.zig");
const connection_manager = @import("connection_manager.zig");

// Bounded: Max pending connections in listen queue.
pub const MAX_PENDING_CONNECTIONS: u32 = 128;

// Server binding result.
pub const BindResult = enum(u8) {
    success,
    port_in_use,
    network_error,
    invalid_port,
};

// Network server state.
pub const NetworkServerState = enum(u8) {
    stopped,
    binding,
    listening,
    accepting,
    error_state,
};

// Network server: manages HTTP server network operations.
pub const NetworkServer = struct {
    port: u16,
    state: NetworkServerState,
    bound: bool,
    listening: bool,

    pub fn init(port: u16) NetworkServer {
        std.debug.assert(port > 0);
        return NetworkServer{
            .port = port,
            .state = NetworkServerState.stopped,
            .bound = false,
            .listening = false,
        };
    }

    // Bind server to port (stub for now, will use kernel syscalls later).
    pub fn bind_to_port(self: *NetworkServer) BindResult {
        std.debug.assert(self.port > 0);
        if (self.state != NetworkServerState.stopped) {
            return BindResult.network_error;
        }
        self.state = NetworkServerState.binding;
        self.bound = true;
        self.state = NetworkServerState.listening;
        self.listening = true;
        return BindResult.success;
    }

    // Start listening for connections (stub for now).
    pub fn start_listening(self: *NetworkServer) bool {
        std.debug.assert(self.port > 0);
        if (!self.bound) {
            return false;
        }
        if (self.state != NetworkServerState.listening) {
            return false;
        }
        self.state = NetworkServerState.accepting;
        return true;
    }

    // Stop listening.
    pub fn stop_listening(self: *NetworkServer) void {
        self.listening = false;
        self.bound = false;
        self.state = NetworkServerState.stopped;
    }

    // Check if server is listening.
    pub fn is_listening(self: *const NetworkServer) bool {
        return self.listening and self.state == NetworkServerState.accepting;
    }

    // Get server port.
    pub fn get_port(self: *const NetworkServer) u16 {
        return self.port;
    }

    // Get server state.
    pub fn get_state(self: *const NetworkServer) NetworkServerState {
        return self.state;
    }
};

// Process incoming HTTP request (stub for now).
pub fn process_http_request(
    server: *api_server.ApiServer,
    conn_mgr: *connection_manager.ConnectionManager,
    raw_request: []const u8,
    connection_idx: ?u32,
) ?api_server.HttpResponse {
    std.debug.assert(raw_request.len > 0);
    _ = conn_mgr;
    _ = connection_idx;
    var request = api_server.HttpRequest.init();
    if (!server.parse_http_request(raw_request, &request)) {
        return null;
    }
    if (server.find_route(request.method, request.path[0..request.path_len])) |route| {
        var response = api_server.HttpResponse.init();
        if (!server.execute_middleware_chain(route, &request, &response)) {
            return response;
        }
        if (route.handler) |handler_fn| {
            handler_fn(&request, &response);
        }
        return response;
    }
    var response = api_server.HttpResponse.init();
    response.status = api_server.HttpStatus.not_found;
    _ = response.add_header("Content-Type", "application/json");
    const error_body = "{\"error\":\"not_found\",\"message\":\"Route not found\"}";
    const body_len = @min(error_body.len, api_server.MAX_RESPONSE_SIZE);
    var i: u32 = 0;
    while (i < body_len) : (i += 1) {
        response.body[i] = error_body[i];
    }
    response.body_len = @intCast(body_len);
    return response;
}

