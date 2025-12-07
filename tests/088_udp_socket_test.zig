//! UDP Socket Tests
//! Why: Test UDP socket syscalls.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const SyscallResult = basin_kernel.basin_kernel.SyscallResult;

// Test: UDP socket manager initialization.
test "udp socket manager init" {
    var kernel = BasinKernel.init();
    
    // UDP socket manager should be initialized.
    // We can't directly access it, but we can test through syscalls.
    const result = try kernel.syscall_udp_socket(0, 0, 0, 0);
    try testing.expect(result == .success);
    const socket_id = result.success;
    try testing.expect(socket_id > 0);
}

// Test: create UDP socket.
test "udp socket create" {
    var kernel = BasinKernel.init();
    
    const result = try kernel.syscall_udp_socket(0, 0, 0, 0);
    try testing.expect(result == .success);
    const socket_id = result.success;
    try testing.expect(socket_id > 0);
}

// Test: bind UDP socket.
test "udp socket bind" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_udp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Bind socket to address and port.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result2 = try kernel.syscall_udp_bind(socket_id, addr, port, 0);
    try testing.expect(result2 == .success);
}

// Test: send data on UDP socket.
test "udp socket sendto" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_udp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Bind socket.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result2 = try kernel.syscall_udp_bind(socket_id, addr, port, 0);
    try testing.expect(result2 == .success);
    
    // Send data.
    const data_ptr: u64 = 0x10000;
    const data_len: u64 = 4; // "test"
    const remote_addr: u64 = 0x0101A8C1; // 192.168.1.2
    const result3 = try kernel.syscall_udp_sendto(socket_id, data_ptr, data_len, remote_addr);
    try testing.expect(result3 == .success);
}

// Test: receive data from UDP socket.
test "udp socket recvfrom" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_udp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Bind socket.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result2 = try kernel.syscall_udp_bind(socket_id, addr, port, 0);
    try testing.expect(result2 == .success);
    
    // Receive data.
    const buffer_ptr: u64 = 0x20000;
    const buffer_len: u64 = 1024;
    const addr_ptr: u64 = 0x30000;
    const result3 = try kernel.syscall_udp_recvfrom(socket_id, buffer_ptr, buffer_len, addr_ptr);
    try testing.expect(result3 == .success);
}

// Test: close UDP socket.
test "udp socket close" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_udp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Close socket.
    const result2 = try kernel.syscall_udp_close(socket_id, 0, 0, 0);
    try testing.expect(result2 == .success);
}

// Test: invalid socket ID.
test "udp socket invalid id" {
    var kernel = BasinKernel.init();
    
    // Try to bind invalid socket.
    const invalid_socket_id: u64 = 999;
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result = kernel.syscall_udp_bind(invalid_socket_id, addr, port, 0);
    try testing.expectError(BasinError.not_found, result);
}

// Test: invalid port.
test "udp socket invalid port" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_udp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Try to bind with invalid port.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const invalid_port: u64 = 99999; // > 65535
    const result2 = kernel.syscall_udp_bind(socket_id, addr, invalid_port, 0);
    try testing.expectError(BasinError.invalid_argument, result2);
}

