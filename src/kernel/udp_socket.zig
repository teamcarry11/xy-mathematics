//! UDP Socket Management
//! Why: Manage UDP sockets for network communication.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const UdpSocketStats = @import("udp_socket_stats.zig").UdpSocketStats;

/// Maximum number of UDP sockets.
/// Why: Bounded allocation for socket tracking.
const MAX_UDP_SOCKETS: u32 = 64;

/// Maximum socket buffer size (64KB).
/// Why: Bounded buffer allocation for socket data.
const MAX_SOCKET_BUFFER_SIZE: u32 = 64 * 1024;

/// UDP socket state.
/// Why: Track socket state for connection management.
pub const UdpSocketState = enum(u8) {
    closed = 0,
    bound = 1,
};

/// UDP socket entry.
/// Why: Track UDP socket configuration and state.
/// Grain Style: Static allocation, explicit types.
pub const UdpSocket = struct {
    /// Socket ID (non-zero if allocated).
    socket_id: u64,
    
    /// Socket state.
    state: UdpSocketState,
    
    /// Local IPv4 address (network byte order).
    local_addr: u32,
    
    /// Local port (host byte order).
    local_port: u16,
    
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
    
    /// Initialize empty UDP socket entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() UdpSocket {
        return UdpSocket{
            .socket_id = 0,
            .state = .closed,
            .local_addr = 0,
            .local_port = 0,
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
    pub fn is_valid(self: *const UdpSocket) bool {
        // Assert: Socket must be allocated.
        Debug.kassert(self.allocated, "Socket not allocated", .{});
        
        return self.state != .closed;
    }
};

/// UDP socket manager.
/// Why: Manage all UDP sockets.
/// Grain Style: Static allocation, bounded operations.
pub const UdpSocketManager = struct {
    /// Socket entries.
    sockets: [MAX_UDP_SOCKETS]UdpSocket,
    
    /// Next socket ID (simple allocator, starts at 1).
    /// Why: Track socket ID allocation (1-based, 0 is invalid).
    next_socket_id: u64,
    
    /// Whether manager is initialized.
    initialized: bool,
    
    /// UDP socket statistics tracker.
    /// Why: Track socket performance metrics.
    stats: UdpSocketStats,
    
    /// Initialize UDP socket manager.
    /// Why: Set up manager state.
    pub fn init() UdpSocketManager {
        const manager = UdpSocketManager{
            .sockets = [_]UdpSocket{UdpSocket.init()} ** MAX_UDP_SOCKETS,
            .next_socket_id = 1,
            .initialized = true,
            .stats = UdpSocketStats.init(),
        };
        
        return manager;
    }
    
    /// Create a new UDP socket.
    /// Why: Allocate a new UDP socket.
    /// Contract: Returns socket ID, or null if no free slot.
    pub fn create_socket(
        self: *UdpSocketManager,
        owner_process_id: u32,
    ) ?u64 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Find free slot.
        var idx: u32 = 0;
        while (idx < MAX_UDP_SOCKETS) : (idx += 1) {
            if (!self.sockets[idx].allocated) {
                // Initialize socket.
                self.sockets[idx] = UdpSocket.init();
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
        self: *UdpSocketManager,
        socket_id: u64,
    ) ?*UdpSocket {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return null;
        }
        
        // Search for socket with matching ID.
        var idx: u32 = 0;
        while (idx < MAX_UDP_SOCKETS) : (idx += 1) {
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
        self: *UdpSocketManager,
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
        socket.state = .bound;
        
        // Record statistics.
        self.stats.record_bound_socket();
        
        return true;
    }
    
    /// Send data to remote address and port.
    /// Why: Transmit data to remote endpoint.
    /// Contract: socket_id must be valid, data must be valid, addr and port must be valid.
    /// Returns: Number of bytes sent, or null on error.
    pub fn sendto(
        self: *UdpSocketManager,
        socket_id: u64,
        data: []const u8,
        addr: u32,
        port: u16,
    ) ?u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const socket = self.get_socket(socket_id) orelse {
            self.stats.record_send_error();
            return null;
        };
        
        // Assert: Socket must be in bound state.
        if (socket.state != .bound) {
            self.stats.record_send_error();
            return null;
        }
        
        // Assert: Data must fit in send buffer.
        if (socket.send_buffer_size + data.len > MAX_SOCKET_BUFFER_SIZE) {
            self.stats.record_send_error();
            return null; // Buffer full
        }
        
        // Copy data to send buffer (stub: would transmit over network).
        std.mem.copyForwards(u8, socket.send_buffer[socket.send_buffer_size..], data);
        const bytes_sent = @as(u32, @truncate(data.len));
        socket.send_buffer_size += bytes_sent;
        
        // Record statistics.
        self.stats.record_bytes_sent(bytes_sent);
        
        // Note: addr and port are validated but not used in stub implementation.
        _ = addr;
        _ = port;
        
        return bytes_sent;
    }
    
    /// Receive data from socket.
    /// Why: Read incoming data from bound socket.
    /// Contract: socket_id must be valid, buffer must be valid, socket must be bound.
    /// Returns: Number of bytes received, or null on error.
    pub fn recvfrom(
        self: *UdpSocketManager,
        socket_id: u64,
        buffer: []u8,
        addr_ptr: ?*u32,
        port_ptr: ?*u16,
    ) ?u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        const socket = self.get_socket(socket_id) orelse {
            self.stats.record_receive_error();
            return null;
        };
        
        // Assert: Socket must be in bound state.
        if (socket.state != .bound) {
            self.stats.record_receive_error();
            return null;
        }
        
        // Assert: Buffer must be non-empty.
        if (buffer.len == 0) {
            self.stats.record_receive_error();
            return null;
        }
        
        // Copy data from receive buffer (stub: would read from network).
        const bytes_to_copy = @min(socket.recv_buffer_size, @as(u32, @truncate(buffer.len)));
        if (bytes_to_copy > 0) {
            std.mem.copyForwards(u8, buffer, socket.recv_buffer[0..bytes_to_copy]);
            // Remove copied data from buffer (shift remaining data).
            std.mem.copyForwards(u8, socket.recv_buffer[0..], socket.recv_buffer[bytes_to_copy..socket.recv_buffer_size]);
            socket.recv_buffer_size -= bytes_to_copy;
            
            // Record statistics.
            self.stats.record_bytes_received(bytes_to_copy);
        }
        
        // Set remote address and port (stub: would get from received packet).
        if (addr_ptr) |addr| {
            addr.* = 0; // Stub: would set from received packet
        }
        if (port_ptr) |port| {
            port.* = 0; // Stub: would set from received packet
        }
        
        return bytes_to_copy;
    }
    
    /// Enumerate all UDP sockets.
    /// Why: Get list of all allocated sockets.
    /// Contract: socket_ids array must be large enough (MAX_UDP_SOCKETS).
    /// Returns: Number of sockets found.
    pub fn enumerate_sockets(
        self: *UdpSocketManager,
        socket_ids: []u64,
    ) u32 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Socket IDs array must be large enough.
        Debug.kassert(socket_ids.len >= MAX_UDP_SOCKETS, "Socket IDs array too small", .{});
        
        var count: u32 = 0;
        var idx: u32 = 0;
        while (idx < MAX_UDP_SOCKETS) : (idx += 1) {
            if (self.sockets[idx].allocated) {
                socket_ids[count] = self.sockets[idx].socket_id;
                count += 1;
            }
        }
        
        return count;
    }
    
    /// Close socket.
    /// Why: Release socket resources.
    /// Contract: socket_id must be valid.
    pub fn close_socket(
        self: *UdpSocketManager,
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
        
        // Record statistics.
        self.stats.record_closed_socket();
        
        return true;
    }
    
    /// Get UDP socket statistics snapshot.
    /// Why: Provide statistics for userspace queries.
    /// Returns: Reference to statistics tracker.
    pub fn get_stats(self: *const UdpSocketManager) *const UdpSocketStats {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        return &self.stats;
    }
};

