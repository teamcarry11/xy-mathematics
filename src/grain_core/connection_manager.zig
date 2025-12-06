//! Grain OS Connection Manager: HTTP connection handling with keep-alive and timeout.
//!
//! Why: Provide connection management for API server (keep-alive, timeout, pooling).
//! Architecture: Connection state tracking, keep-alive management, timeout handling.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const api_server = @import("api_server.zig");

// Bounded: Max concurrent connections.
pub const MAX_CONNECTIONS: u32 = 1024;

// Bounded: Default keep-alive timeout (seconds).
pub const DEFAULT_KEEP_ALIVE_TIMEOUT: u32 = 5;

// Bounded: Default request timeout (seconds).
pub const DEFAULT_REQUEST_TIMEOUT: u32 = 30;

// Connection state.
pub const ConnectionState = enum(u8) {
    idle,
    reading,
    writing,
    keep_alive,
    closing,
    closed,
};

// HTTP connection.
pub const HttpConnection = struct {
    connection_id: u64,
    state: ConnectionState,
    keep_alive: bool,
    keep_alive_timeout: u32,
    request_timeout: u32,
    last_activity_time: u64,
    request_count: u32,
    active: bool,

    pub fn init(connection_id: u64) HttpConnection {
        std.debug.assert(connection_id > 0);
        return HttpConnection{
            .connection_id = connection_id,
            .state = ConnectionState.idle,
            .keep_alive = false,
            .keep_alive_timeout = DEFAULT_KEEP_ALIVE_TIMEOUT,
            .request_timeout = DEFAULT_REQUEST_TIMEOUT,
            .last_activity_time = 0,
            .request_count = 0,
            .active = true,
        };
    }

    // Update activity time.
    pub fn update_activity(self: *HttpConnection, current_time: u64) void {
        std.debug.assert(self.active);
        self.last_activity_time = current_time;
    }

    // Check if connection has timed out.
    pub fn is_timed_out(self: *const HttpConnection, current_time: u64) bool {
        std.debug.assert(self.active);
        if (self.state == ConnectionState.keep_alive) {
            const elapsed = current_time - self.last_activity_time;
            return elapsed > self.keep_alive_timeout;
        } else {
            const elapsed = current_time - self.last_activity_time;
            return elapsed > self.request_timeout;
        }
    }

    // Set keep-alive.
    pub fn set_keep_alive(self: *HttpConnection, keep_alive: bool) void {
        std.debug.assert(self.active);
        self.keep_alive = keep_alive;
        if (keep_alive) {
            self.state = ConnectionState.keep_alive;
        }
    }

    // Increment request count.
    pub fn increment_request_count(self: *HttpConnection) void {
        std.debug.assert(self.active);
        self.request_count += 1;
    }

    // Close connection.
    pub fn close(self: *HttpConnection) void {
        std.debug.assert(self.active);
        self.state = ConnectionState.closing;
    }
};

// Connection manager: manages HTTP connections.
pub const ConnectionManager = struct {
    connections: [MAX_CONNECTIONS]HttpConnection,
    connections_len: u32,
    next_connection_id: u64,
    current_time: u64,

    pub fn init() ConnectionManager {
        return ConnectionManager{
            .connections = undefined,
            .connections_len = 0,
            .next_connection_id = 1,
            .current_time = 0,
        };
    }

    // Add connection.
    pub fn add_connection(self: *ConnectionManager) ?u32 {
        if (self.connections_len >= MAX_CONNECTIONS) {
            return null;
        }
        const connection_id = self.next_connection_id;
        self.next_connection_id += 1;
        self.connections[self.connections_len] = HttpConnection.init(connection_id);
        self.connections[self.connections_len].last_activity_time = self.current_time;
        const idx = self.connections_len;
        self.connections_len += 1;
        return idx;
    }

    // Get connection by index.
    pub fn get_connection(self: *ConnectionManager, idx: u32) ?*HttpConnection {
        if (idx >= self.connections_len) {
            return null;
        }
        if (!self.connections[idx].active) {
            return null;
        }
        return &self.connections[idx];
    }

    // Remove connection.
    pub fn remove_connection(self: *ConnectionManager, idx: u32) bool {
        if (idx >= self.connections_len) {
            return false;
        }
        if (!self.connections[idx].active) {
            return false;
        }
        self.connections[idx].active = false;
        self.connections[idx].state = ConnectionState.closed;
        if (idx < self.connections_len - 1) {
            self.connections[idx] = self.connections[self.connections_len - 1];
        }
        self.connections_len -= 1;
        return true;
    }

    // Update current time.
    pub fn update_time(self: *ConnectionManager, current_time: u64) void {
        self.current_time = current_time;
    }

    // Clean up timed out connections.
    pub fn cleanup_timeouts(self: *ConnectionManager) u32 {
        var cleaned: u32 = 0;
        var i: u32 = 0;
        while (i < self.connections_len) : (i += 1) {
            if (self.connections[i].active and self.connections[i].is_timed_out(self.current_time)) {
                self.remove_connection(i);
                cleaned += 1;
                i -= 1;
            }
        }
        return cleaned;
    }

    // Get connection count.
    pub fn get_connection_count(self: *const ConnectionManager) u32 {
        return self.connections_len;
    }

    // Get active connection count.
    pub fn get_active_connection_count(self: *const ConnectionManager) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.connections_len) : (i += 1) {
            if (self.connections[i].active) {
                count += 1;
            }
        }
        return count;
    }
};

