//! TCP Socket Tests
//! Why: Test TCP socket syscalls.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const SyscallResult = basin_kernel.basin_kernel.SyscallResult;

// Test: TCP socket manager initialization.
test "tcp socket manager init" {
    var kernel = BasinKernel.init();
    
    // TCP socket manager should be initialized.
    // We can't directly access it, but we can test through syscalls.
    const result = try kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(result == .success);
    const socket_id = result.success;
    try testing.expect(socket_id > 0);
}

// Test: create TCP socket.
test "tcp socket create" {
    var kernel = BasinKernel.init();
    
    const result = try kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(result == .success);
    const socket_id = result.success;
    try testing.expect(socket_id > 0);
}

// Test: bind TCP socket.
test "tcp socket bind" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Bind socket to address and port.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result2 = try kernel.syscall_tcp_bind(socket_id, addr, port, 0);
    try testing.expect(result2 == .success);
}

// Test: listen on TCP socket.
test "tcp socket listen" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Bind socket.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result2 = try kernel.syscall_tcp_bind(socket_id, addr, port, 0);
    try testing.expect(result2 == .success);
    
    // Listen on socket.
    const result3 = try kernel.syscall_tcp_listen(socket_id, 0, 0, 0);
    try testing.expect(result3 == .success);
}

// Test: connect TCP socket.
test "tcp socket connect" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Connect socket to remote address and port.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result2 = try kernel.syscall_tcp_connect(socket_id, addr, port, 0);
    try testing.expect(result2 == .success);
}

// Test: send data on TCP socket.
test "tcp socket send" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Connect socket.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result2 = try kernel.syscall_tcp_connect(socket_id, addr, port, 0);
    try testing.expect(result2 == .success);
    
    // Send data.
    const data_ptr: u64 = 0x10000;
    const data_len: u64 = 4; // "test"
    const result3 = try kernel.syscall_tcp_send(socket_id, data_ptr, data_len, 0);
    try testing.expect(result3 == .success);
}

// Test: receive data from TCP socket.
test "tcp socket recv" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Connect socket.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result2 = try kernel.syscall_tcp_connect(socket_id, addr, port, 0);
    try testing.expect(result2 == .success);
    
    // Receive data.
    const buffer_ptr: u64 = 0x20000;
    const buffer_len: u64 = 1024;
    const result3 = try kernel.syscall_tcp_recv(socket_id, buffer_ptr, buffer_len, 0);
    try testing.expect(result3 == .success);
}

// Test: close TCP socket.
test "tcp socket close" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Close socket.
    const result2 = try kernel.syscall_tcp_close(socket_id, 0, 0, 0);
    try testing.expect(result2 == .success);
}

// Test: invalid socket ID.
test "tcp socket invalid id" {
    var kernel = BasinKernel.init();
    
    // Try to bind invalid socket.
    const invalid_socket_id: u64 = 999;
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const port: u64 = 8080;
    const result = kernel.syscall_tcp_bind(invalid_socket_id, addr, port, 0);
    try testing.expectError(BasinError.not_found, result);
}

// Test: invalid port.
test "tcp socket invalid port" {
    var kernel = BasinKernel.init();
    
    // Create socket first.
    const result1 = try kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(result1 == .success);
    const socket_id = result1.success;
    
    // Try to bind with invalid port.
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const invalid_port: u64 = 99999; // > 65535
    const result2 = kernel.syscall_tcp_bind(socket_id, addr, invalid_port, 0);
    try testing.expectError(BasinError.invalid_argument, result2);
}

