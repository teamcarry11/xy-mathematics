//! TCP Socket Management
//! Why: Manage TCP sockets for network communication.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Maximum number of TCP sockets.
/// Why: Bounded allocation for socket tracking.
const MAX_TCP_SOCKETS: u32 = 64;

/// Maximum socket buffer size (64KB).
/// Why: Bounded buffer allocation for socket data.
const MAX_SOCKET_BUFFER_SIZE: u32 = 64 * 1024;

/// TCP socket state.
/// Why: Track socket state for connection management.
pub const TcpSocketState = enum(u8) {
    closed = 0,
    listening = 1,
    connecting = 2,
    connected = 3,
    closing = 4,
};

/// TCP socket entry.
/// Why: Track TCP socket configuration and state.
/// Grain Style: Static allocation, explicit types.
pub const TcpSocket = struct {
    /// Socket ID (non-zero if allocated).
    socket_id: u64,
    
    /// Socket state.
    state: TcpSocketState,
    
    /// Local IPv4 address (network byte order).
    local_addr: u32,
    
    /// Local port (host byte order).
    local_port: u16,
    
    /// Remote IPv4 address (network byte order, 0 if not connected).
    remote_addr: u32,
    
    /// Remote port (host byte order, 0 if not connected).
    remote_port: u16,
    
    /// Receive buffer (incoming data).
    recv_buffer: [MAX_SOCKET_BUFFER_SIZE]u8,
    
    /// Receive buffer size (actual data length, bytes).
    recv_buffer_size: u32,
    
    /// Send buffer (outgoing data).
    send_buffer: [MAX_SOCKET_BUFFER_SIZE]u8,
    
    /// Send buffer size (actual data length, bytes).
    send_buffer_size: u32,
    
    /// Whether this entry is allocated (in use).
    allocated: bool,
    
    /// Owner process ID (0 = kernel-owned, non-zero = process-owned).
    /// Why: Track which process owns this socket for resource cleanup.
    owner_process_id: u32,
    
    /// Initialize empty TCP socket entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() TcpSocket {
        return TcpSocket{
            .socket_id = 0,
            .state = .closed,
            .local_addr = 0,
            .local_port = 0,
            .remote_addr = 0,
            .remote_port = 0,
            .recv_buffer = [_]u8{0} ** MAX_SOCKET_BUFFER_SIZE,
            .recv_buffer_size = 0,
            .send_buffer = [_]u8{0} ** MAX_SOCKET_BUFFER_SIZE,
            .send_buffer_size = 0,
            .allocated = false,
            .owner_process_id = 0,
        };
    }
    
    /// Check if socket is in a valid state for operations.
    /// Why: Validate socket state before operations.
    /// Contract: Socket must be allocated.
    pub fn is_valid(self: *const TcpSocket) bool {
        // Assert: Socket must be allocated.
        Debug.kassert(self.allocated, "Socket not allocated", .{});
        
        return self.state != .closed;
    }
};

/// TCP socket manager.
/// Why: Manage all TCP sockets.
/// Grain Style: Static allocation, bounded operations.
pub const TcpSocketManager = struct {
    /// Socket entries.
    sockets: [MAX_TCP_SOCKETS]TcpSocket,
    
    /// Next socket ID (simple allocator, starts at 1).
    /// Why: Track socket ID allocation (1-based, 0 is invalid).
    next_socket_id: u64,
    
    /// Whether manager is initialized.
    initialized: bool,
    
    /// Initialize TCP socket manager.
    /// Why: Set up manager state.
    pub fn init() TcpSocketManager {
        const manager = TcpSocketManager{
            .sockets = [_]TcpSocket{TcpSocket.init()} ** MAX_TCP_SOCKETS,
            .next_socket_id = 1,
            .initialized = true,
        };
        
        return manager;
    }
    
    /// Create a new TCP socket.
    /// Why: Allocate a new TCP socket.
    /// Contract: Returns socket ID, or null if no free slot.
    pub fn create_socket(
        self: *TcpSocketManager,
        owner_process_id: u32,
    ) ?u64 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Find free slot.
        var idx: u32 = 0;
        while (idx < MAX_TCP_SOCKETS) : (idx += 1) {
            if (!self.sockets[idx].allocated) {
                // Initialize socket.
                self.sockets[idx] = TcpSocket.init();
                self.sockets[idx].allocated = true;
                self.sockets[idx].socket_id = self.next_socket_id;
                self.sockets[idx].owner_process_id = owner_process_id;
                
                // Increment socket ID.
                const socket_id = self.next_socket_id;
                self.next_socket_id += 1;
                if (self.next_socket_id == 0) {
                    self.next_socket_id = 1; // Wrap around (skip 0)
                }
                
                return socket_id;
            }
        }
        
        // No free slot found.
        return null;
    }
    
    /// Get socket by ID.
    /// Why: Retrieve socket entry.
    /// Contract: socket_id must be valid (non-zero).
    /// Returns: Pointer to socket entry, or null if not found.
    pub fn get_socket(
        self: *TcpSocketManager,
        socket_id: u64,
    ) ?*TcpSocket {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return null;
        }
        
        // Search for socket with matching ID.
        var idx: u32 = 0;
        while (idx < MAX_TCP_SOCKETS) : (idx += 1) {
            if (self.sockets[idx].allocated and self.sockets[idx].socket_id == socket_id) {
                return &self.sockets[idx];
            }
        }
        
        // Socket not found.
        return null;
    }
    
    /// Bind socket to local address and port.
    /// Why: Configure local endpoint for socket.
    /// Contract: socket_id must be valid, addr and port must be valid.
    pub fn bind_socket(
        self: *TcpSocketManager,
        socket_id: u64,
        addr: u32,
        port: u16,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const socket = self.get_socket(socket_id) orelse {
            return false;
        };
        
        // Assert: Socket must be in closed state.
        if (socket.state != .closed) {
            return false;
        }
        
        // Set local address and port.
        socket.local_addr = addr;
        socket.local_port = port;
        
        return true;
    }
    
    /// Set socket to listening state.
    /// Why: Enable socket to accept incoming connections.
    /// Contract: socket_id must be valid, socket must be bound.
    pub fn listen_socket(
        self: *TcpSocketManager,
        socket_id: u64,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const socket = self.get_socket(socket_id) orelse {
            return false;
        };
        
        // Assert: Socket must be bound (local_addr and local_port set).
        if (socket.local_addr == 0 or socket.local_port == 0) {
            return false;
        }
        
        // Assert: Socket must be in closed state.
        if (socket.state != .closed) {
            return false;
        }
        
        // Set socket to listening state.
        socket.state = .listening;
        
        return true;
    }
    
    /// Accept incoming connection (stub: returns new socket ID).
    /// Why: Accept incoming connection on listening socket.
    /// Contract: socket_id must be valid, socket must be listening.
    /// Returns: New socket ID for accepted connection, or null if no connection.
    pub fn accept_connection(
        self: *TcpSocketManager,
        socket_id: u64,
        owner_process_id: u32,
    ) ?u64 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const socket = self.get_socket(socket_id) orelse {
            return null;
        };
        
        // Assert: Socket must be in listening state.
        if (socket.state != .listening) {
            return null;
        }
        
        // Create new socket for accepted connection (stub: would create from incoming connection).
        const new_socket_id = self.create_socket(owner_process_id) orelse {
            return null;
        };
        
        const new_socket = self.get_socket(new_socket_id).?;
        new_socket.state = .connected;
        new_socket.local_addr = socket.local_addr;
        new_socket.local_port = socket.local_port;
        // Stub: remote_addr and remote_port would be set from incoming connection.
        new_socket.remote_addr = 0;
        new_socket.remote_port = 0;
        
        return new_socket_id;
    }
    
    /// Connect socket to remote address and port.
    /// Why: Establish connection to remote endpoint.
    /// Contract: socket_id must be valid, addr and port must be valid.
    pub fn connect_socket(
        self: *TcpSocketManager,
        socket_id: u64,
        addr: u32,
        port: u16,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const socket = self.get_socket(socket_id) orelse {
            return false;
        };
        
        // Assert: Socket must be in closed state.
        if (socket.state != .closed) {
            return false;
        }
        
        // Set remote address and port.
        socket.remote_addr = addr;
        socket.remote_port = port;
        
        // Set socket to connected state (stub: would establish connection).
        socket.state = .connected;
        
        return true;
    }
    
    /// Send data on socket.
    /// Why: Transmit data on connected socket.
    /// Contract: socket_id must be valid, data must be valid, socket must be connected.
    /// Returns: Number of bytes sent, or null on error.
    pub fn send_data(
        self: *TcpSocketManager,
        socket_id: u64,
        data: []const u8,
    ) ?u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const socket = self.get_socket(socket_id) orelse {
            return null;
        };
        
        // Assert: Socket must be in connected state.
        if (socket.state != .connected) {
            return null;
        }
        
        // Assert: Data must fit in send buffer.
        if (socket.send_buffer_size + data.len > MAX_SOCKET_BUFFER_SIZE) {
            return null; // Buffer full
        }
        
        // Copy data to send buffer (stub: would transmit over network).
        std.mem.copyForwards(u8, socket.send_buffer[socket.send_buffer_size..], data);
        socket.send_buffer_size += @as(u32, @truncate(data.len));
        
        return @as(u32, @truncate(data.len));
    }
    
    /// Receive data from socket.
    /// Why: Read incoming data from connected socket.
    /// Contract: socket_id must be valid, buffer must be valid, socket must be connected.
    /// Returns: Number of bytes received, or null on error.
    pub fn recv_data(
        self: *TcpSocketManager,
        socket_id: u64,
        buffer: []u8,
    ) ?u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const socket = self.get_socket(socket_id) orelse {
            return null;
        };
        
        // Assert: Socket must be in connected state.
        if (socket.state != .connected) {
            return null;
        }
        
        // Assert: Buffer must be non-empty.
        if (buffer.len == 0) {
            return null;
        }
        
        // Copy data from receive buffer (stub: would read from network).
        const bytes_to_copy = @min(socket.recv_buffer_size, @as(u32, @truncate(buffer.len)));
        if (bytes_to_copy > 0) {
            std.mem.copyForwards(u8, buffer, socket.recv_buffer[0..bytes_to_copy]);
            // Remove copied data from buffer (shift remaining data).
            std.mem.copyForwards(u8, socket.recv_buffer[0..], socket.recv_buffer[bytes_to_copy..socket.recv_buffer_size]);
            socket.recv_buffer_size -= bytes_to_copy;
        }
        
        return bytes_to_copy;
    }
    
    /// Close socket.
    /// Why: Release socket resources.
    /// Contract: socket_id must be valid.
    pub fn close_socket(
        self: *TcpSocketManager,
        socket_id: u64,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const socket = self.get_socket(socket_id) orelse {
            return false;
        };
        
        // Set socket to closed state and deallocate.
        socket.state = .closed;
        socket.allocated = false;
        
        return true;
    }
};

