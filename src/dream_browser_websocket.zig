const std = @import("std");
const WebSocketClient = @import("dream_websocket.zig").WebSocketClient;

/// Dream Browser WebSocket Transport: Connection management, error handling, reconnection.
/// ~<~ Glow Airbend: explicit connection state, bounded retries.
/// ~~~~ Glow Waterbend: connections flow deterministically through state machine.
///
/// This implements:
/// - Connection management (connect, disconnect, reconnect)
/// - Error handling (network errors, protocol errors)
/// - Automatic reconnection (exponential backoff)
/// - Connection pooling (multiple relay connections)
/// - Health monitoring (ping/pong, connection status)
pub const DreamBrowserWebSocket = struct {
    allocator: std.mem.Allocator,
    
    // Bounded: Max 10 concurrent connections
    pub const MAX_CONNECTIONS: u32 = 10;
    
    // Bounded: Max 10 reconnection attempts
    pub const MAX_RECONNECT_ATTEMPTS: u32 = 10;
    
    // Bounded: Max 60 seconds between reconnection attempts
    pub const MAX_RECONNECT_DELAY: u32 = 60;
    
    /// Connection state.
    pub const ConnectionState = enum {
        disconnected,
        connecting,
        connected,
        reconnecting,
        error_state,
    };
    
    /// Connection information.
    pub const Connection = struct {
        url: []const u8, // WebSocket URL (ws:// or wss://)
        host: []const u8, // Hostname
        port: u16, // Port (80 for ws, 443 for wss)
        path: []const u8, // Path (/)
        ws_client: ?WebSocketClient = null,
        state: ConnectionState = .disconnected,
        reconnect_attempts: u32 = 0,
        last_error: ?[]const u8 = null,
    };
    
    /// Connection pool (multiple relay connections).
    pub const ConnectionPool = struct {
        connections: []Connection,
        connections_len: u32,
        
        pub fn init(allocator: std.mem.Allocator) !ConnectionPool {
            const connections = try allocator.alloc(Connection, MAX_CONNECTIONS);
            
            return ConnectionPool{
                .connections = connections,
                .connections_len = 0,
            };
        }
        
        pub fn deinit(self: *ConnectionPool, allocator: std.mem.Allocator) void {
            // Close all connections
            for (self.connections[0..self.connections_len]) |*conn| {
                if (conn.ws_client) |*ws| {
                    ws.deinit();
                }
                allocator.free(conn.url);
                allocator.free(conn.host);
                allocator.free(conn.path);
                if (conn.last_error) |err| {
                    allocator.free(err);
                }
            }
            allocator.free(self.connections);
        }
        
        /// Add connection to pool.
        pub fn addConnection(
            self: *ConnectionPool,
            allocator: std.mem.Allocator,
            url: []const u8,
        ) !u32 {
            // Assert: Connection count must be within bounds
            std.debug.assert(self.connections_len < MAX_CONNECTIONS);
            
            // Parse URL (ws://host:port/path or wss://host:port/path)
            const scheme_end = std.mem.indexOf(u8, url, "://") orelse return error.InvalidUrl;
            const scheme = url[0..scheme_end];
            const is_secure = std.mem.eql(u8, scheme, "wss");
            
            var remainder = url[scheme_end + 3..];
            
            // Find path start
            const path_start = std.mem.indexOf(u8, remainder, "/") orelse remainder.len;
            const host_port = remainder[0..path_start];
            const path = if (path_start < remainder.len) remainder[path_start..] else "/";
            
            // Parse host:port
            var host: []const u8 = undefined;
            var port: u16 = undefined;
            
            if (std.mem.indexOf(u8, host_port, ":")) |colon_pos| {
                host = host_port[0..colon_pos];
                const port_str = host_port[colon_pos + 1..];
                port = try std.fmt.parseInt(u16, port_str, 10);
            } else {
                host = host_port;
                port = if (is_secure) 443 else 80;
            }
            
            // Create connection
            const conn_idx = self.connections_len;
            self.connections[conn_idx] = Connection{
                .url = try allocator.dupe(u8, url),
                .host = try allocator.dupe(u8, host),
                .port = port,
                .path = try allocator.dupe(u8, path),
                .ws_client = null,
                .state = .disconnected,
                .reconnect_attempts = 0,
                .last_error = null,
            };
            
            self.connections_len += 1;
            
            // Assert: Connection was added
            std.debug.assert(self.connections_len == conn_idx + 1);
            
            return conn_idx;
        }
        
        /// Get connection by index.
        pub fn getConnection(self: *const ConnectionPool, index: u32) ?*Connection {
            if (index >= self.connections_len) return null;
            return &self.connections[index];
        }
    };
    
    pool: ConnectionPool,
    
    /// Initialize WebSocket transport.
    pub fn init(allocator: std.mem.Allocator) !DreamBrowserWebSocket {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        const pool = try ConnectionPool.init(allocator);
        
        return DreamBrowserWebSocket{
            .allocator = allocator,
            .pool = pool,
        };
    }
    
    /// Deinitialize WebSocket transport.
    pub fn deinit(self: *DreamBrowserWebSocket) void {
        self.pool.deinit(self.allocator);
    }
    
    /// Connect to WebSocket URL.
    pub fn connect(
        self: *DreamBrowserWebSocket,
        url: []const u8,
    ) !u32 {
        // Assert: URL must be non-empty
        std.debug.assert(url.len > 0);
        
        // Add connection to pool
        const conn_idx = try self.pool.addConnection(self.allocator, url);
        const conn = self.pool.getConnection(conn_idx).?;
        
        // Update state
        conn.state = .connecting;
        
        // Connect TCP stream
        const tcp_stream = try std.net.tcpConnectToHost(self.allocator, conn.host, conn.port);
        errdefer tcp_stream.close();
        
        // Create WebSocket client
        const ws_client = WebSocketClient.init(self.allocator, tcp_stream, conn.host);
        
        // Perform handshake
        try ws_client.handshake(conn.path);
        
        // Update connection
        conn.ws_client = ws_client;
        conn.state = .connected;
        conn.reconnect_attempts = 0;
        conn.last_error = null;
        
        // Assert: Connection is connected
        std.debug.assert(conn.state == .connected);
        
        return conn_idx;
    }
    
    /// Disconnect from WebSocket.
    pub fn disconnect(self: *DreamBrowserWebSocket, conn_idx: u32) void {
        const conn = self.pool.getConnection(conn_idx) orelse return;
        
        if (conn.ws_client) |*ws| {
            ws.deinit();
            conn.ws_client = null;
        }
        
        conn.state = .disconnected;
        conn.reconnect_attempts = 0;
        conn.last_error = null;
    }
    
    /// Reconnect to WebSocket (with exponential backoff).
    pub fn reconnect(
        self: *DreamBrowserWebSocket,
        conn_idx: u32,
    ) !void {
        const conn = self.pool.getConnection(conn_idx) orelse return error.InvalidConnection;
        
        // Assert: Reconnect attempts must be within bounds
        std.debug.assert(conn.reconnect_attempts < MAX_RECONNECT_ATTEMPTS);
        
        // Update state
        conn.state = .reconnecting;
        conn.reconnect_attempts += 1;
        
        // Calculate exponential backoff delay
        const delay = std.math.min(
            @as(u32, 1) << @as(u5, @intCast(conn.reconnect_attempts - 1)),
            MAX_RECONNECT_DELAY,
        );
        
        // Wait before reconnecting
        std.time.sleep(delay * std.time.ns_per_s);
        
        // Disconnect if connected
        if (conn.ws_client) |*ws| {
            ws.deinit();
            conn.ws_client = null;
        }
        
        // Reconnect
        const tcp_stream = try std.net.tcpConnectToHost(self.allocator, conn.host, conn.port);
        errdefer tcp_stream.close();
        
        const ws_client = WebSocketClient.init(self.allocator, tcp_stream, conn.host);
        try ws_client.handshake(conn.path);
        
        // Update connection
        conn.ws_client = ws_client;
        conn.state = .connected;
        conn.last_error = null;
        
        // Assert: Connection is reconnected
        std.debug.assert(conn.state == .connected);
    }
    
    /// Handle connection error (network, protocol, etc.).
    pub fn handleError(
        self: *DreamBrowserWebSocket,
        conn_idx: u32,
        error_msg: []const u8,
    ) void {
        const conn = self.pool.getConnection(conn_idx) orelse return;
        
        // Store error message
        if (conn.last_error) |old_err| {
            self.allocator.free(old_err);
        }
        conn.last_error = self.allocator.dupe(u8, error_msg) catch null;
        
        // Update state
        conn.state = .error_state;
        
        // Attempt reconnection if within limits
        if (conn.reconnect_attempts < MAX_RECONNECT_ATTEMPTS) {
            // Reconnection will be handled by caller or background task
            // For now, just mark as error state
        }
    }
    
    /// Send message via WebSocket.
    pub fn send(
        self: *DreamBrowserWebSocket,
        conn_idx: u32,
        message: []const u8,
    ) !void {
        const conn = self.pool.getConnection(conn_idx) orelse return error.InvalidConnection;
        
        // Assert: Connection must be connected
        std.debug.assert(conn.state == .connected);
        std.debug.assert(conn.ws_client != null);
        
        const ws = conn.ws_client.?;
        
        // Create text frame
        const frame = WebSocketClient.Frame{
            .fin = true,
            .opcode = .text,
            .masked = true,
            .payload = message,
        };
        
        try ws.writeFrame(frame);
    }
    
    /// Receive message via WebSocket.
    pub fn receive(
        self: *DreamBrowserWebSocket,
        conn_idx: u32,
    ) !?[]const u8 {
        const conn = self.pool.getConnection(conn_idx) orelse return null;
        
        // Assert: Connection must be connected
        std.debug.assert(conn.state == .connected);
        std.debug.assert(conn.ws_client != null);
        
        const ws = conn.ws_client.?;
        const frame = try ws.readFrame();
        
        // Handle control frames
        switch (frame.opcode) {
            .ping => {
                // Send pong
                const pong_frame = WebSocketClient.Frame{
                    .fin = true,
                    .opcode = .pong,
                    .masked = true,
                    .payload = frame.payload,
                };
                try ws.writeFrame(pong_frame);
                return null; // Ping doesn't return data
            },
            .pong => {
                // Pong received (connection is alive)
                return null; // Pong doesn't return data
            },
            .close => {
                // Connection closed
                conn.state = .disconnected;
                return null;
            },
            .text, .binary => {
                // Return payload (caller must free)
                return frame.payload;
            },
            else => {
                return null;
            },
        }
    }
    
    /// Get connection state.
    pub fn getState(self: *const DreamBrowserWebSocket, conn_idx: u32) ?ConnectionState {
        const conn = self.pool.getConnection(conn_idx) orelse return null;
        return conn.state;
    }
    
    /// Get connection statistics.
    pub fn getStats(self: *const DreamBrowserWebSocket) ConnectionStats {
        var stats = ConnectionStats{
            .total_connections = self.pool.connections_len,
            .connected = 0,
            .disconnected = 0,
            .reconnecting = 0,
            .error_state = 0,
        };
        
        for (self.pool.connections[0..self.pool.connections_len]) |conn| {
            switch (conn.state) {
                .connected => stats.connected += 1,
                .disconnected => stats.disconnected += 1,
                .reconnecting => stats.reconnecting += 1,
                .error_state => stats.error_state += 1,
                .connecting => stats.disconnected += 1, // Count as disconnected
            }
        }
        
        return stats;
    }
    
    /// Connection statistics.
    pub const ConnectionStats = struct {
        total_connections: u32,
        connected: u32,
        disconnected: u32,
        reconnecting: u32,
        error_state: u32,
    };
};

test "browser websocket initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var transport = try DreamBrowserWebSocket.init(arena.allocator());
    defer transport.deinit();
    
    // Assert: Transport initialized
    try std.testing.expect(transport.pool.connections_len == 0);
}

test "browser websocket add connection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var transport = try DreamBrowserWebSocket.init(arena.allocator());
    defer transport.deinit();
    
    const conn_idx = try transport.pool.addConnection(arena.allocator(), "ws://example.com:8080/");
    
    // Assert: Connection added
    try std.testing.expect(conn_idx == 0);
    try std.testing.expect(transport.pool.connections_len == 1);
    
    const conn = transport.pool.getConnection(conn_idx);
    try std.testing.expect(conn != null);
    try std.testing.expect(std.mem.eql(u8, conn.?.host, "example.com"));
    try std.testing.expect(conn.?.port == 8080);
}

test "browser websocket get stats" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var transport = try DreamBrowserWebSocket.init(arena.allocator());
    defer transport.deinit();
    
    _ = try transport.pool.addConnection(arena.allocator(), "ws://example.com:8080/");
    
    const stats = transport.getStats();
    
    // Assert: Stats reflect connections
    try std.testing.expect(stats.total_connections == 1);
    try std.testing.expect(stats.disconnected == 1);
}

