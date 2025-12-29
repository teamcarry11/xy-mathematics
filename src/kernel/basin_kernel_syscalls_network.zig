//! Basin Kernel Network Syscalls
//! Why: Network syscalls (interface management, TCP/UDP socket operations).
//! Grain Style: Explicit types, static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const network = @import("network.zig");

// Import types
const types = @import("basin_kernel_types.zig");
const BasinError = types.BasinError;
const SyscallResult = types.SyscallResult;
const MAX_PROCESSES = types.MAX_PROCESSES;

// Import core
const core = @import("basin_kernel_core.zig");
const BasinKernel = core.BasinKernel;

/// Network syscall handlers for BasinKernel.
/// Why: Extract network syscalls to separate module for organization.
pub const NetworkSyscalls = struct {
    pub fn syscall_network_create_interface(
        self: *BasinKernel,
        name_ptr: u64,
        name_len: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: name pointer must be valid (non-zero, within VM memory).
        if (name_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (name_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Name pointer exceeds VM memory
        }
        
        // Assert: name length must be reasonable (max interface name length).
        if (name_len == 0) {
            return BasinError.invalid_argument; // Zero-length name
        }
        if (name_len > 16) {
            return BasinError.invalid_argument; // Name too long
        }
        
        // Assert: name must fit within VM memory.
        if (name_ptr + name_len > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Name exceeds VM memory
        }
        
        // Read interface name from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder name.
        const name = "eth0";
        
        // Create interface.
        const iface_idx = self.network_interfaces.create_interface(name) orelse {
            return BasinError.out_of_memory; // No free interface slot
        };
        
        const result = SyscallResult.ok(iface_idx);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set network interface state (up/down).
    /// Why: Control interface state.
    /// Contract: iface_idx and state must be valid.
    pub fn syscall_network_set_state(
        self: *BasinKernel,
        iface_idx: u64,
        state: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Assert: State must be valid (0 = down, 1 = up).
        if (state > 1) {
            return BasinError.invalid_argument; // Invalid state
        }
        
        const iface_state = if (state == 0) network.InterfaceState.down else network.InterfaceState.up;
        
        // Set interface state.
        if (!self.network_interfaces.set_interface_state(idx, iface_state)) {
            return BasinError.not_found; // Interface not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set IPv4 address for network interface.
    /// Why: Configure IPv4 address, netmask, and gateway.
    /// Contract: iface_idx, addr, netmask, and gateway must be valid.
    pub fn syscall_network_set_ipv4(
        self: *BasinKernel,
        iface_idx: u64,
        addr: u64,
        netmask: u64,
        gateway: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Assert: Address, netmask, and gateway must be valid (32-bit values).
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_netmask = @as(u32, @truncate(netmask));
        const ipv4_gateway = @as(u32, @truncate(gateway));
        
        // Set IPv4 address.
        if (!self.network_interfaces.set_ipv4_address(idx, ipv4_addr)) {
            return BasinError.not_found; // Interface not found
        }
        
        // Set IPv4 netmask.
        if (!self.network_interfaces.set_ipv4_netmask(idx, ipv4_netmask)) {
            return BasinError.not_found; // Interface not found
        }
        
        // Set IPv4 gateway.
        if (!self.network_interfaces.set_ipv4_gateway(idx, ipv4_gateway)) {
            return BasinError.not_found; // Interface not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set IPv6 address for network interface.
    /// Why: Configure IPv6 address.
    /// Contract: iface_idx must be valid, addr_ptr must be valid VM address.
    pub fn syscall_network_set_ipv6(
        self: *BasinKernel,
        iface_idx: u64,
        addr_ptr: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Assert: Address pointer must be valid (non-zero, within VM memory).
        if (addr_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (addr_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Address pointer exceeds VM memory
        }
        
        // Assert: Address must fit within VM memory (16 bytes for IPv6).
        if (addr_ptr + 16 > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Address exceeds VM memory
        }
        
        // Read IPv6 address from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder address (::1 - localhost).
        const ipv6_addr: [16]u8 = [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 };
        
        // Set IPv6 address.
        if (!self.network_interfaces.set_ipv6_address(idx, ipv6_addr)) {
            return BasinError.not_found; // Interface not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get network interface information.
    /// Why: Retrieve interface configuration.
    /// Contract: iface_idx must be valid, info_ptr must be valid VM address.
    pub fn syscall_network_get_interface(
        self: *BasinKernel,
        iface_idx: u64,
        info_ptr: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Assert: Info pointer must be valid (non-zero, within VM memory).
        if (info_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_GET: u64 = 4 * 1024 * 1024; // 4MB default
        if (info_ptr >= VM_MEMORY_SIZE_GET) {
            return BasinError.invalid_argument; // Info pointer exceeds VM memory
        }
        
        // Get interface.
        const iface = self.network_interfaces.get_interface(idx) orelse {
            return BasinError.not_found; // Interface not found
        };
        
        // Write interface information to VM memory (stub: would use vm_memory_writer).
        // For now, just return success.
        // Note: info_ptr and iface are validated but not used in stub implementation.
        _ = iface;
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Delete network interface.
    /// Why: Remove network interface.
    /// Contract: iface_idx must be valid.
    pub fn syscall_network_delete_interface(
        self: *BasinKernel,
        iface_idx: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Delete interface.
        if (!self.network_interfaces.delete_interface(idx)) {
            return BasinError.not_found; // Interface not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Enumerate network interfaces.
    /// Why: Get list of all network interfaces.
    /// Contract: indices_ptr must be valid VM address, max_count must be valid.
    pub fn syscall_network_enumerate_interfaces(
        self: *BasinKernel,
        indices_ptr: u64,
        max_count: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Indices pointer must be valid (non-zero, within VM memory).
        if (indices_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (indices_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Indices pointer exceeds VM memory
        }
        
        // Assert: Max count must be reasonable (max 8 interfaces).
        const max_cnt = @as(u32, @truncate(max_count));
        if (max_cnt > 8) {
            return BasinError.invalid_argument; // Max count too large
        }
        
        // Assert: Indices array must fit within VM memory (max 8 * 4 bytes = 32 bytes).
        const INDICES_SIZE: u64 = max_cnt * 4; // u32 per index
        if (indices_ptr + INDICES_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Indices array exceeds VM memory
        }
        
        // Create temporary indices array.
        var temp_indices: [8]u32 = undefined;
        const count = self.network_interfaces.enumerate_interfaces(&temp_indices);
        
        // Write indices to VM memory (stub: would use vm_memory_writer).
        // For now, just return the count.
        // Note: indices_ptr and temp_indices are validated but not written in stub.
        _ = temp_indices;
        
        const result = SyscallResult.ok(count);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get network interface statistics.
    /// Why: Provide network interface statistics to userspace.
    /// Contract: stats_ptr must be valid pointer to NetworkInterfaceStats structure.
    pub fn syscall_network_get_stats(
        self: *BasinKernel,
        stats_ptr: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Stats pointer must be valid (non-zero, within VM memory).
        if (stats_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (stats_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats pointer exceeds VM memory
        }
        
        // Assert: NetworkInterfaceStats structure must fit within VM memory.
        // NetworkInterfaceStats size: 10 fields (7 u64 + 1 u32 + 2 u64) = 7*8 + 4 + 2*8 = 76 bytes
        const NETWORK_STATS_SIZE: u64 = 76;
        if (stats_ptr + NETWORK_STATS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats structure exceeds VM memory
        }
        
        // Note: Statistics structure will be written by integration layer.
        // This syscall validates the pointer and returns success.
        // Contract: stats_ptr must be valid (checked above).
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Create a TCP socket.
    /// Why: Allocate a new TCP socket.
    /// Contract: Returns socket ID.
    pub fn syscall_tcp_socket(
        self: *BasinKernel,
        _arg1: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg1;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Get current process ID from scheduler.
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Check connection limit for current process.
        if (current_process_id > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_process_id) {
                    if (!self.can_open_connection(self, &self.processes[i])) {
                        return BasinError.resource_exhausted; // Connection limit exceeded
                    }
                    break;
                }
            }
        }
        
        // Create socket.
        const socket_id = self.tcp_sockets.create_socket(owner_process_id) orelse {
            return BasinError.out_of_memory; // No free socket slot
        };
        
        const result = SyscallResult.ok(socket_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Bind TCP socket to local address and port.
    /// Why: Configure local endpoint for socket.
    /// Contract: socket_id, addr, and port must be valid.
    pub fn syscall_tcp_bind(
        self: *BasinKernel,
        socket_id: u64,
        addr: u64,
        port: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Port must be valid (16-bit value).
        if (port > 65535) {
            return BasinError.invalid_argument; // Invalid port
        }
        
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_port = @as(u16, @truncate(port));
        
        // Bind socket.
        if (!self.tcp_sockets.bind_socket(socket_id, ipv4_addr, ipv4_port)) {
            return BasinError.not_found; // Socket not found or invalid state
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set TCP socket to listening state.
    /// Why: Enable socket to accept incoming connections.
    /// Contract: socket_id must be valid, socket must be bound.
    pub fn syscall_tcp_listen(
        self: *BasinKernel,
        socket_id: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Set socket to listening state.
        if (!self.tcp_sockets.listen_socket(socket_id)) {
            return BasinError.not_found; // Socket not found or invalid state
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Accept incoming connection on listening socket.
    /// Why: Accept incoming connection and create new socket.
    /// Contract: socket_id must be valid, socket must be listening.
    pub fn syscall_tcp_accept(
        self: *BasinKernel,
        socket_id: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Get current process ID from scheduler.
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Accept connection.
        const new_socket_id = self.tcp_sockets.accept_connection(socket_id, owner_process_id) orelse {
            return BasinError.not_found; // Socket not found, not listening, or no connection
        };
        
        const result = SyscallResult.ok(new_socket_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Connect TCP socket to remote address and port.
    /// Why: Establish connection to remote endpoint.
    /// Contract: socket_id, addr, and port must be valid.
    pub fn syscall_tcp_connect(
        self: *BasinKernel,
        socket_id: u64,
        addr: u64,
        port: u64,
        timeout_ns: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Port must be valid (16-bit value).
        if (port > 65535) {
            return BasinError.invalid_argument; // Invalid port
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_port = @as(u16, @truncate(port));
        
        // Connect socket.
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        if (!self.tcp_sockets.connect_socket(socket_id, ipv4_addr, ipv4_port)) {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.network_timeout; // Timeout expired
            }
            return BasinError.not_found; // Socket not found or invalid state
        }
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Send data on TCP socket.
    /// Why: Transmit data on connected socket.
    /// Contract: socket_id must be valid, data_ptr and data_len must be valid, socket must be connected.
    pub fn syscall_tcp_send(
        self: *BasinKernel,
        socket_id: u64,
        data_ptr: u64,
        data_len: u64,
        timeout_ns: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_SEND: u64 = 4 * 1024 * 1024; // 4MB default
        if (data_ptr >= VM_MEMORY_SIZE_SEND) {
            return BasinError.invalid_argument; // Data pointer exceeds VM memory
        }
        
        // Assert: Data length must be reasonable (max socket buffer size).
        if (data_len == 0) {
            return BasinError.invalid_argument; // Zero-length data
        }
        if (data_len > 64 * 1024) {
            return BasinError.invalid_argument; // Data too large
        }
        
        // Assert: Data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE_SEND) {
            return BasinError.invalid_argument; // Data exceeds VM memory
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Read data from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder data slice.
        const data = "test";
        
        // Send data.
        // Note: In a real implementation, this would check timeout periodically if blocking.
        const bytes_sent = self.tcp_sockets.send_data(socket_id, data) orelse {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.network_timeout; // Timeout expired
            }
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Update process resource usage (network bytes sent).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_sent += bytes_sent;
                    break;
                }
            }
        }
        
        const result = SyscallResult.ok(bytes_sent);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Receive data from TCP socket.
    /// Why: Read incoming data from connected socket.
    /// Contract: socket_id must be valid, buffer_ptr and buffer_len must be valid, socket must be connected.
    pub fn syscall_tcp_recv(
        self: *BasinKernel,
        socket_id: u64,
        buffer_ptr: u64,
        buffer_len: u64,
        timeout_ns: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_RECV: u64 = 4 * 1024 * 1024; // 4MB default
        if (buffer_ptr >= VM_MEMORY_SIZE_RECV) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: Buffer length must be reasonable (max socket buffer size).
        if (buffer_len == 0) {
            return BasinError.invalid_argument; // Zero-length buffer
        }
        if (buffer_len > 64 * 1024) {
            return BasinError.invalid_argument; // Buffer too large
        }
        
        // Assert: Buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE_RECV) {
            return BasinError.invalid_argument; // Buffer exceeds VM memory
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Create buffer slice (stub: would use vm_memory_writer).
        var buffer: [64 * 1024]u8 = undefined;
        const buffer_slice = buffer[0..@as(usize, @intCast(buffer_len))];
        
        // Receive data.
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        const bytes_received = self.tcp_sockets.recv_data(socket_id, buffer_slice) orelse {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.network_timeout; // Timeout expired
            }
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Update process resource usage (network bytes received).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_received += bytes_received;
                    break;
                }
            }
        }
        
        // Write data to VM memory (stub: would use vm_memory_writer).
        // For now, just return bytes received.
        // Note: buffer_ptr is validated above but not written to in stub implementation.
        
        const result = SyscallResult.ok(bytes_received);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Close TCP socket.
    /// Why: Release socket resources.
    /// Contract: socket_id must be valid.
    pub fn syscall_tcp_close(
        self: *BasinKernel,
        socket_id: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Get current process ID before closing.
        const current_process_id = self.scheduler.get_current();
        
        // Close socket.
        if (!self.tcp_sockets.close_socket(socket_id)) {
            return BasinError.not_found; // Socket not found
        }
        
        // Update process resource usage (decrement connection count).
        if (current_process_id > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_process_id) {
                    if (self.processes[i].open_connections > 0) {
                        self.processes[i].open_connections -= 1;
                    }
                    break;
                }
            }
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Create a UDP socket.
    /// Why: Allocate a new UDP socket.
    /// Contract: Returns socket ID.
    pub fn syscall_udp_socket(
        self: *BasinKernel,
        _arg1: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg1;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Get current process ID from scheduler.
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Check connection limit for current process.
        if (current_process_id > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_process_id) {
                    if (!self.can_open_connection(self, &self.processes[i])) {
                        return BasinError.resource_exhausted; // Connection limit exceeded
                    }
                    break;
                }
            }
        }
        
        // Create socket.
        const socket_id = self.udp_sockets.create_socket(owner_process_id) orelse {
            return BasinError.out_of_memory; // No free socket slot
        };
        
        // Update process resource usage (increment connection count).
        if (current_process_id > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_process_id) {
                    self.processes[i].open_connections += 1;
                    break;
                }
            }
        }
        
        const result = SyscallResult.ok(socket_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Bind UDP socket to local address and port.
    /// Why: Configure local endpoint for socket.
    /// Contract: socket_id, addr, and port must be valid.
    pub fn syscall_udp_bind(
        self: *BasinKernel,
        socket_id: u64,
        addr: u64,
        port: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Port must be valid (16-bit value).
        if (port > 65535) {
            return BasinError.invalid_argument; // Invalid port
        }
        
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_port = @as(u16, @truncate(port));
        
        // Bind socket.
        if (!self.udp_sockets.bind_socket(socket_id, ipv4_addr, ipv4_port)) {
            return BasinError.not_found; // Socket not found or invalid state
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Send data to remote address and port on UDP socket.
    /// Why: Transmit data to remote endpoint.
    /// Contract: socket_id must be valid, data_ptr, data_len, addr, and port must be valid.
    pub fn syscall_udp_sendto(
        self: *BasinKernel,
        socket_id: u64,
        data_ptr: u64,
        data_len: u64,
        addr: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_SENDTO: u64 = 4 * 1024 * 1024; // 4MB default
        if (data_ptr >= VM_MEMORY_SIZE_SENDTO) {
            return BasinError.invalid_argument; // Data pointer exceeds VM memory
        }
        
        // Assert: Data length must be reasonable (max socket buffer size).
        if (data_len == 0) {
            return BasinError.invalid_argument; // Zero-length data
        }
        if (data_len > 64 * 1024) {
            return BasinError.invalid_argument; // Data too large
        }
        
        // Assert: Data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE_SENDTO) {
            return BasinError.invalid_argument; // Data exceeds VM memory
        }
        
        // Stub: would extract port from arguments properly.
        // For now, use addr as IPv4 address and port as 0.
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_port: u16 = 0; // Stub: would extract from arguments
        
        // Read data from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder data slice.
        const data = "test";
        
        // Send data.
        const bytes_sent = self.udp_sockets.sendto(socket_id, data, ipv4_addr, ipv4_port) orelse {
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Update process resource usage (network bytes sent).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_sent += bytes_sent;
                    break;
                }
            }
        }
        
        const result = SyscallResult.ok(bytes_sent);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Receive data from UDP socket.
    /// Why: Read incoming data from bound socket.
    /// Contract: socket_id must be valid, buffer_ptr and buffer_len must be valid.
    pub fn syscall_udp_recvfrom(
        self: *BasinKernel,
        socket_id: u64,
        buffer_ptr: u64,
        buffer_len: u64,
        addr_ptr: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_RECVFROM: u64 = 4 * 1024 * 1024; // 4MB default
        if (buffer_ptr >= VM_MEMORY_SIZE_RECVFROM) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: Buffer length must be reasonable (max socket buffer size).
        if (buffer_len == 0) {
            return BasinError.invalid_argument; // Zero-length buffer
        }
        if (buffer_len > 64 * 1024) {
            return BasinError.invalid_argument; // Buffer too large
        }
        
        // Assert: Buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE_RECVFROM) {
            return BasinError.invalid_argument; // Buffer exceeds VM memory
        }
        
        // Create buffer slice (stub: would use vm_memory_writer).
        var buffer: [64 * 1024]u8 = undefined;
        const buffer_slice = buffer[0..@as(usize, @intCast(buffer_len))];
        
        // Create address and port pointers (stub: would use vm_memory_writer).
        var remote_addr: u32 = 0;
        var remote_port: u16 = 0;
        const addr_ptr_opt: ?*u32 = if (addr_ptr != 0) &remote_addr else null;
        const port_ptr_opt: ?*u16 = if (addr_ptr != 0) &remote_port else null;
        
        // Receive data (remote_addr and remote_port are written by recvfrom if addr_ptr != 0).
        const bytes_received = self.udp_sockets.recvfrom(socket_id, buffer_slice, addr_ptr_opt, port_ptr_opt) orelse {
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Update process resource usage (network bytes received).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_received += bytes_received;
                    break;
                }
            }
        }
        
        // Write data and address/port to VM memory (stub: would use vm_memory_writer).
        // For now, just return bytes received.
        // Note: addr_ptr is validated above but not written to in stub implementation.
        
        const result = SyscallResult.ok(bytes_received);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Send data on UDP socket with timeout.
    /// Why: Transmit data on UDP socket with timeout support.
    /// Contract: socket_id must be valid, data_ptr and data_len must be valid, addr_and_timeout contains IPv4 address and timeout_ms.
    pub fn syscall_udp_sendto_with_timeout(
        self: *BasinKernel,
        socket_id: u64,
        data_ptr: u64,
        data_len: u64,
        addr_and_timeout: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Extract IPv4 address and timeout from combined argument.
        // Format: lower 32 bits = IPv4 address (u32), upper 32 bits = timeout_ms (u32), convert to nanoseconds
        const ipv4_addr = @as(u32, @truncate(addr_and_timeout));
        const timeout_ms = @as(u32, @truncate(addr_and_timeout >> 32));
        const timeout_ns: u64 = if (timeout_ms > 0) @as(u64, timeout_ms) * 1_000_000 else 0;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_SENDTO: u64 = 4 * 1024 * 1024; // 4MB default
        if (data_ptr >= VM_MEMORY_SIZE_SENDTO) {
            return BasinError.invalid_argument; // Data pointer exceeds VM memory
        }
        
        // Assert: Data length must be reasonable (max socket buffer size).
        if (data_len == 0) {
            return BasinError.invalid_argument; // Zero-length data
        }
        if (data_len > 64 * 1024) {
            return BasinError.invalid_argument; // Data too large
        }
        
        // Assert: Data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE_SENDTO) {
            return BasinError.invalid_argument; // Data exceeds VM memory
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Stub: would extract port from arguments properly.
        // For now, use addr as IPv4 address and port as 0.
        const ipv4_port: u16 = 0; // Stub: would extract from arguments
        
        // Read data from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder data slice.
        const data = "test";
        
        // Send data.
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        const bytes_sent = self.udp_sockets.sendto(socket_id, data, ipv4_addr, ipv4_port) orelse {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.network_timeout; // Timeout expired
            }
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Update process resource usage (network bytes sent).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_sent += bytes_sent;
                    break;
                }
            }
        }
        
        const result = SyscallResult.ok(bytes_sent);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Receive data from UDP socket with timeout.
    /// Why: Read incoming data from bound socket with timeout support.
    /// Contract: socket_id must be valid, buffer_ptr and buffer_len must be valid, addr_ptr_and_timeout contains addr_ptr and timeout_ms.
    pub fn syscall_udp_recvfrom_with_timeout(
        self: *BasinKernel,
        socket_id: u64,
        buffer_ptr: u64,
        buffer_len: u64,
        addr_ptr_and_timeout: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Extract addr_ptr and timeout from combined argument.
        // Format: lower 32 bits = addr_ptr (u32), upper 32 bits = timeout_ms (u32), convert to nanoseconds
        const addr_ptr = @as(u32, @truncate(addr_ptr_and_timeout));
        const timeout_ms = @as(u32, @truncate(addr_ptr_and_timeout >> 32));
        const timeout_ns: u64 = if (timeout_ms > 0) @as(u64, timeout_ms) * 1_000_000 else 0;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_RECVFROM: u64 = 4 * 1024 * 1024; // 4MB default
        if (buffer_ptr >= VM_MEMORY_SIZE_RECVFROM) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: Buffer length must be reasonable (max socket buffer size).
        if (buffer_len == 0) {
            return BasinError.invalid_argument; // Zero-length buffer
        }
        if (buffer_len > 64 * 1024) {
            return BasinError.invalid_argument; // Buffer too large
        }
        
        // Assert: Buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE_RECVFROM) {
            return BasinError.invalid_argument; // Buffer exceeds VM memory
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Create buffer slice (stub: would use vm_memory_writer).
        var buffer: [64 * 1024]u8 = undefined;
        const buffer_slice = buffer[0..@as(usize, @intCast(buffer_len))];
        
        // Create address and port pointers (stub: would use vm_memory_writer).
        var remote_addr: u32 = 0;
        var remote_port: u16 = 0;
        const addr_ptr_opt: ?*u32 = if (addr_ptr != 0) &remote_addr else null;
        const port_ptr_opt: ?*u16 = if (addr_ptr != 0) &remote_port else null;
        
        // Receive data.
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        // Receive data (remote_addr and remote_port are written by recvfrom if addr_ptr != 0).
        const bytes_received = self.udp_sockets.recvfrom(socket_id, buffer_slice, addr_ptr_opt, port_ptr_opt) orelse {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.network_timeout; // Timeout expired
            }
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Update process resource usage (network bytes received).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_received += bytes_received;
                    break;
                }
            }
        }
        
        // Write data to VM memory (stub: would use vm_memory_writer).
        // For now, just return bytes received.
        // Note: buffer_ptr is validated above but not written to in stub implementation.
        
        const result = SyscallResult.ok(bytes_received);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Close UDP socket.
    /// Why: Release socket resources.
    /// Contract: socket_id must be valid.
    pub fn syscall_udp_close(
        self: *BasinKernel,
        socket_id: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Get current process ID before closing.
        const current_process_id = self.scheduler.get_current();
        
        // Close socket.
        if (!self.udp_sockets.close_socket(socket_id)) {
            return BasinError.not_found; // Socket not found
        }
        
        // Update process resource usage (decrement connection count).
        if (current_process_id > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_process_id) {
                    if (self.processes[i].open_connections > 0) {
                        self.processes[i].open_connections -= 1;
                    }
                    break;
                }
            }
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Enumerate UDP sockets.
    /// Why: Get list of all UDP sockets.
    /// Contract: socket_ids_ptr must be valid VM address, max_count must be valid.
    pub fn syscall_udp_enumerate_sockets(
        self: *BasinKernel,
        socket_ids_ptr: u64,
        max_count: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Socket IDs pointer must be valid (non-zero, within VM memory).
        if (socket_ids_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (socket_ids_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Socket IDs pointer exceeds VM memory
        }
        
        // Assert: Max count must be reasonable (max 64 sockets).
        const max_cnt = @as(u32, @truncate(max_count));
        if (max_cnt > 64) {
            return BasinError.invalid_argument; // Max count too large
        }
        
        // Assert: Socket IDs array must fit within VM memory (max 64 * 8 bytes = 512 bytes).
        const SOCKET_IDS_SIZE: u64 = max_cnt * 8; // u64 per socket ID
        if (socket_ids_ptr + SOCKET_IDS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Socket IDs array exceeds VM memory
        }
        
        // Create temporary socket IDs array.
        var temp_socket_ids: [64]u64 = undefined;
        const count = self.udp_sockets.enumerate_sockets(&temp_socket_ids);
        
        // Write socket IDs to VM memory (stub: would use vm_memory_writer).
        // For now, just return the count.
        // Note: socket_ids_ptr and temp_socket_ids are validated but not written in stub.
        _ = temp_socket_ids;
        
        const result = SyscallResult.ok(count);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get TCP socket statistics.
    /// Why: Provide TCP socket statistics to userspace.
    /// Contract: stats_ptr must be valid pointer to TcpSocketStats structure.
    pub fn syscall_tcp_get_stats(
        self: *BasinKernel,
        stats_ptr: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Stats pointer must be valid (non-zero, within VM memory).
        if (stats_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (stats_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats pointer exceeds VM memory
        }
        
        // Assert: TcpSocketStats structure must fit within VM memory.
        // TcpSocketStats size: 13 fields (8 u64 + 2 u32 + 3 u64) = 8*8 + 2*4 + 3*8 = 64 + 8 + 24 = 96 bytes
        const TCP_STATS_SIZE: u64 = 96;
        if (stats_ptr + TCP_STATS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats structure exceeds VM memory
        }
        
        // Note: Statistics structure will be written by integration layer.
        // This syscall validates the pointer and returns success.
        // Contract: stats_ptr must be valid (checked above).
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get UDP socket statistics.
    /// Why: Provide UDP socket statistics to userspace.
    /// Contract: stats_ptr must be valid pointer to UdpSocketStats structure.
    pub fn syscall_udp_get_stats(
        self: *BasinKernel,
        stats_ptr: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Stats pointer must be valid (non-zero, within VM memory).
        if (stats_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (stats_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats pointer exceeds VM memory
        }
        
        // Assert: UdpSocketStats structure must fit within VM memory.
        // UdpSocketStats size: 9 fields (4 u64 + 1 u32 + 1 u64 + 2 u64 + 1 u64) = 4*8 + 4 + 8 + 2*8 + 8 = 32 + 4 + 8 + 16 + 8 = 68 bytes
        const UDP_STATS_SIZE: u64 = 68;
        if (stats_ptr + UDP_STATS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats structure exceeds VM memory
        }
        
        // Note: Statistics structure will be written by integration layer.
        // This syscall validates the pointer and returns success.
        // Contract: stats_ptr must be valid (checked above).
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Enumerate TCP sockets.
    /// Why: Get list of all TCP sockets.
    /// Contract: socket_ids_ptr must be valid VM address, max_count must be valid.
    pub fn syscall_tcp_enumerate_sockets(
        self: *BasinKernel,
        socket_ids_ptr: u64,
        max_count: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Socket IDs pointer must be valid (non-zero, within VM memory).
        if (socket_ids_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (socket_ids_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Socket IDs pointer exceeds VM memory
        }
        
        // Assert: Max count must be reasonable (max 64 sockets).
        const max_cnt = @as(u32, @truncate(max_count));
        if (max_cnt > 64) {
            return BasinError.invalid_argument; // Max count too large
        }
        
        // Assert: Socket IDs array must fit within VM memory (max 64 * 8 bytes = 512 bytes).
        const SOCKET_IDS_SIZE: u64 = max_cnt * 8; // u64 per socket ID
        if (socket_ids_ptr + SOCKET_IDS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Socket IDs array exceeds VM memory
        }
        
        // Create temporary socket IDs array.
        var temp_socket_ids: [64]u64 = undefined;
        const count = self.tcp_sockets.enumerate_sockets(&temp_socket_ids);
        
        // Write socket IDs to VM memory (stub: would use vm_memory_writer).
        // For now, just return the count.
        // Note: socket_ids_ptr and temp_socket_ids are validated but not written in stub.
        _ = temp_socket_ids;
        
        const result = SyscallResult.ok(count);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
};
