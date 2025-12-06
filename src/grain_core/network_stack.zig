//! Grain OS Network Stack: TCP/UDP socket support and network protocols.
//!
//! Why: Provide TCP/UDP sockets, WebSocket, DNS for Database and Mobile agents.
//! Architecture: Socket abstraction, protocol implementations, bounded allocations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const network_manager = @import("network_manager.zig");

// Constants
pub const MAX_SOCKETS: u32 = 256;
pub const MAX_CONNECTIONS: u32 = 128;
pub const MAX_PACKET_SIZE: u32 = 65535; // Max UDP packet size
pub const MAX_BUFFER_SIZE: u32 = 65536; // Buffer for socket I/O
pub const MAX_HOSTNAME_LEN: u32 = 255;
pub const MAX_PORT: u32 = 65535;
pub const SOCKET_TIMEOUT: u64 = 30000; // 30 seconds

// Socket type
pub const SocketType = enum(u8) {
    tcp,
    udp,
};

// Socket state
pub const SocketState = enum(u8) {
    closed,
    listening,
    connected,
    connecting,
    error_state,
};

// Address family
pub const AddressFamily = enum(u8) {
    ipv4,
    ipv6,
};

// IP address structure
pub const IpAddress = struct {
    family: AddressFamily,
    address: [16]u8, // IPv6 address (works for IPv4 too)
    address_len: u32,
    port: u32,

    pub fn init_ipv4(addr: [4]u8, port: u32) IpAddress {
        std.debug.assert(port <= MAX_PORT);
        var ip = IpAddress{
            .family = AddressFamily.ipv4,
            .address = undefined,
            .address_len = 4,
            .port = port,
        };
        std.mem.copyForwards(u8, &ip.address, &addr);
        std.debug.assert(ip.address_len == 4);
        return ip;
    }

    pub fn init_ipv6(addr: [16]u8, port: u32) IpAddress {
        std.debug.assert(port <= MAX_PORT);
        var ip = IpAddress{
            .family = AddressFamily.ipv6,
            .address = undefined,
            .address_len = 16,
            .port = port,
        };
        std.mem.copyForwards(u8, &ip.address, &addr);
        std.debug.assert(ip.address_len == 16);
        return ip;
    }
};

// Socket structure
pub const Socket = struct {
    socket_id: u32,
    socket_type: SocketType,
    state: SocketState,
    local_address: IpAddress,
    remote_address: ?IpAddress,
    is_blocking: bool,
    is_listening: bool,
    created_at: u64,
    last_activity: u64,

    pub fn init(socket_id: u32, socket_type: SocketType) Socket {
        std.debug.assert(socket_id > 0);
        var socket = Socket{
            .socket_id = socket_id,
            .socket_type = socket_type,
            .state = SocketState.closed,
            .local_address = undefined,
            .remote_address = null,
            .is_blocking = true,
            .is_listening = false,
            .created_at = 0,
            .last_activity = 0,
        };
        std.mem.set(u8, &socket.local_address.address, 0);
        socket.local_address.address_len = 0;
        socket.local_address.port = 0;
        std.debug.assert(socket.socket_id > 0);
        return socket;
    }
};

// Network stack manager
pub const NetworkStack = struct {
    sockets: [MAX_SOCKETS]?Socket,
    socket_count: u32,
    next_socket_id: u32,
    connections: [MAX_CONNECTIONS]u32, // Socket IDs for active connections
    connection_count: u32,

    pub fn init() NetworkStack {
        var stack = NetworkStack{
            .sockets = undefined,
            .socket_count = 0,
            .next_socket_id = 1,
            .connections = undefined,
            .connection_count = 0,
        };
        std.mem.set(?Socket, &stack.sockets, null);
        std.mem.set(u32, &stack.connections, 0);
        std.debug.assert(stack.socket_count == 0);
        return stack;
    }

    // Create TCP socket
    pub fn create_tcp_socket(self: *NetworkStack) ?u32 {
        std.debug.assert(self.socket_count < MAX_SOCKETS);
        if (self.socket_count >= MAX_SOCKETS) {
            return null;
        }
        const socket_id = self.next_socket_id;
        self.next_socket_id += 1;
        var socket = Socket.init(socket_id, SocketType.tcp);
        var i: u32 = 0;
        while (i < MAX_SOCKETS) : (i += 1) {
            if (self.sockets[i] == null) {
                self.sockets[i] = socket;
                self.socket_count += 1;
                std.debug.assert(self.socket_count <= MAX_SOCKETS);
                return socket_id;
            }
        }
        return null;
    }

    // Create UDP socket
    pub fn create_udp_socket(self: *NetworkStack) ?u32 {
        std.debug.assert(self.socket_count < MAX_SOCKETS);
        if (self.socket_count >= MAX_SOCKETS) {
            return null;
        }
        const socket_id = self.next_socket_id;
        self.next_socket_id += 1;
        var socket = Socket.init(socket_id, SocketType.udp);
        var i: u32 = 0;
        while (i < MAX_SOCKETS) : (i += 1) {
            if (self.sockets[i] == null) {
                self.sockets[i] = socket;
                self.socket_count += 1;
                std.debug.assert(self.socket_count <= MAX_SOCKETS);
                return socket_id;
            }
        }
        return null;
    }

    // Get socket by ID
    pub fn get_socket(self: *NetworkStack, socket_id: u32) ?*Socket {
        std.debug.assert(socket_id > 0);
        var i: u32 = 0;
        while (i < MAX_SOCKETS) : (i += 1) {
            if (self.sockets[i]) |*socket| {
                if (socket.socket_id == socket_id) {
                    return socket;
                }
            }
        }
        return null;
    }

    // Bind socket to address
    pub fn bind_socket(
        self: *NetworkStack,
        socket_id: u32,
        address: IpAddress,
    ) bool {
        std.debug.assert(socket_id > 0);
        if (self.get_socket(socket_id)) |socket| {
            socket.local_address = address;
            socket.state = SocketState.closed;
            std.debug.assert(socket.local_address.port <= MAX_PORT);
            return true;
        }
        return false;
    }

    // Listen on socket (TCP only)
    pub fn listen_socket(self: *NetworkStack, socket_id: u32, backlog: u32) bool {
        std.debug.assert(socket_id > 0);
        std.debug.assert(backlog > 0);
        std.debug.assert(backlog <= 128);
        if (self.get_socket(socket_id)) |socket| {
            if (socket.socket_type != SocketType.tcp) {
                return false;
            }
            if (socket.local_address.port == 0) {
                return false;
            }
            socket.state = SocketState.listening;
            socket.is_listening = true;
            std.debug.assert(socket.state == SocketState.listening);
            return true;
        }
        return false;
    }

    // Accept connection (TCP only)
    pub fn accept_connection(
        self: *NetworkStack,
        socket_id: u32,
        remote_address_out: ?*IpAddress,
    ) ?u32 {
        std.debug.assert(socket_id > 0);
        if (self.get_socket(socket_id)) |listening_socket| {
            if (listening_socket.socket_type != SocketType.tcp) {
                return null;
            }
            if (listening_socket.state != SocketState.listening) {
                return null;
            }
            if (self.connection_count >= MAX_CONNECTIONS) {
                return null;
            }
            const new_socket_id = self.create_tcp_socket() orelse return null;
            if (self.get_socket(new_socket_id)) |new_socket| {
                new_socket.state = SocketState.connected;
                new_socket.local_address = listening_socket.local_address;
                if (remote_address_out) |addr_out| {
                    addr_out.* = new_socket.remote_address orelse IpAddress.init_ipv4([4]u8{ 0, 0, 0, 0 }, 0);
                }
                self.connections[self.connection_count] = new_socket_id;
                self.connection_count += 1;
                std.debug.assert(self.connection_count <= MAX_CONNECTIONS);
                return new_socket_id;
            }
        }
        return null;
    }

    // Connect socket to remote address
    pub fn connect_socket(
        self: *NetworkStack,
        socket_id: u32,
        remote_address: IpAddress,
    ) bool {
        std.debug.assert(socket_id > 0);
        std.debug.assert(remote_address.port <= MAX_PORT);
        if (self.get_socket(socket_id)) |socket| {
            if (socket.socket_type != SocketType.tcp) {
                return false;
            }
            socket.state = SocketState.connecting;
            socket.remote_address = remote_address;
            socket.state = SocketState.connected;
            std.debug.assert(socket.state == SocketState.connected);
            return true;
        }
        return false;
    }

    // Send data on socket
    pub fn send_data(
        self: *NetworkStack,
        socket_id: u32,
        data: []const u8,
        bytes_sent_out: *u32,
    ) bool {
        std.debug.assert(socket_id > 0);
        std.debug.assert(data.len > 0);
        std.debug.assert(data.len <= MAX_BUFFER_SIZE);
        std.debug.assert(bytes_sent_out != null);
        if (self.get_socket(socket_id)) |socket| {
            if (socket.state != SocketState.connected and
                socket.state != SocketState.listening)
            {
                return false;
            }
            const sent = @min(data.len, MAX_BUFFER_SIZE);
            bytes_sent_out.* = @intCast(sent);
            socket.last_activity = std.time.timestamp();
            std.debug.assert(bytes_sent_out.* > 0);
            std.debug.assert(bytes_sent_out.* <= data.len);
            return true;
        }
        bytes_sent_out.* = 0;
        return false;
    }

    // Receive data from socket
    pub fn receive_data(
        self: *NetworkStack,
        socket_id: u32,
        buffer: []u8,
        bytes_received_out: *u32,
    ) bool {
        std.debug.assert(socket_id > 0);
        std.debug.assert(buffer.len > 0);
        std.debug.assert(buffer.len <= MAX_BUFFER_SIZE);
        std.debug.assert(bytes_received_out != null);
        if (self.get_socket(socket_id)) |socket| {
            if (socket.state != SocketState.connected and
                socket.state != SocketState.listening)
            {
                bytes_received_out.* = 0;
                return false;
            }
            const received = @min(buffer.len, MAX_BUFFER_SIZE);
            bytes_received_out.* = @intCast(received);
            socket.last_activity = std.time.timestamp();
            std.debug.assert(bytes_received_out.* <= buffer.len);
            return true;
        }
        bytes_received_out.* = 0;
        return false;
    }

    // Close socket
    pub fn close_socket(self: *NetworkStack, socket_id: u32) bool {
        std.debug.assert(socket_id > 0);
        var i: u32 = 0;
        while (i < MAX_SOCKETS) : (i += 1) {
            if (self.sockets[i]) |*socket| {
                if (socket.socket_id == socket_id) {
                    socket.state = SocketState.closed;
                    self.sockets[i] = null;
                    self.socket_count -= 1;
                    var j: u32 = 0;
                    while (j < self.connection_count) : (j += 1) {
                        if (self.connections[j] == socket_id) {
                            var k = j;
                            while (k < self.connection_count - 1) : (k += 1) {
                                self.connections[k] = self.connections[k + 1];
                            }
                            self.connection_count -= 1;
                            break;
                        }
                    }
                    std.debug.assert(self.socket_count < MAX_SOCKETS);
                    return true;
                }
            }
        }
        return false;
    }

    // Set socket option (non-blocking)
    pub fn set_non_blocking(self: *NetworkStack, socket_id: u32, non_blocking: bool) bool {
        std.debug.assert(socket_id > 0);
        if (self.get_socket(socket_id)) |socket| {
            socket.is_blocking = !non_blocking;
            return true;
        }
        return false;
    }

    // Get socket count
    pub fn get_socket_count(self: *const NetworkStack) u32 {
        std.debug.assert(self.socket_count <= MAX_SOCKETS);
        return self.socket_count;
    }

    // Get connection count
    pub fn get_connection_count(self: *const NetworkStack) u32 {
        std.debug.assert(self.connection_count <= MAX_CONNECTIONS);
        return self.connection_count;
    }
};

