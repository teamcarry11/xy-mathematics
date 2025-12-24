//! Network Interface Management Tests
//! Why: Test network interface management syscalls.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const SyscallResult = basin_kernel.basin_kernel.SyscallResult;

// Test: network interface manager initialization.
test "network interface manager init" {
    var kernel = BasinKernel.init();
    
    // Network interface manager should be initialized.
    // We can't directly access it, but we can test through syscalls.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 4; // "eth0"
    const result = try kernel.syscall_network_create_interface(name_ptr, name_len, 0, 0);
    try testing.expect(result == .success);
    const iface_idx = result.success;
    try testing.expect(iface_idx >= 0);
}

// Test: create network interface.
test "network create interface" {
    var kernel = BasinKernel.init();
    
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 4; // "eth0"
    const result = try kernel.syscall_network_create_interface(name_ptr, name_len, 0, 0);
    try testing.expect(result == .success);
    const iface_idx = result.success;
    try testing.expect(iface_idx >= 0);
}

// Test: set network interface state.
test "network set interface state" {
    var kernel = BasinKernel.init();
    
    // Create interface first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 4; // "eth0"
    const result1 = try kernel.syscall_network_create_interface(name_ptr, name_len, 0, 0);
    try testing.expect(result1 == .success);
    const iface_idx = result1.success;
    
    // Set interface state to up.
    const state: u64 = 1; // up
    const result2 = try kernel.syscall_network_set_state(iface_idx, state, 0, 0);
    try testing.expect(result2 == .success);
    
    // Set interface state to down.
    const state2: u64 = 0; // down
    const result3 = try kernel.syscall_network_set_state(iface_idx, state2, 0, 0);
    try testing.expect(result3 == .success);
}

// Test: set IPv4 address.
test "network set ipv4" {
    var kernel = BasinKernel.init();
    
    // Create interface first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 4; // "eth0"
    const result1 = try kernel.syscall_network_create_interface(name_ptr, name_len, 0, 0);
    try testing.expect(result1 == .success);
    const iface_idx = result1.success;
    
    // Set IPv4 address (192.168.1.1 in network byte order).
    const addr: u64 = 0x0101A8C0; // 192.168.1.1
    const netmask: u64 = 0x00FFFFFF; // 255.255.255.0
    const gateway: u64 = 0x0101A8C0; // 192.168.1.1
    const result2 = try kernel.syscall_network_set_ipv4(iface_idx, addr, netmask, gateway);
    try testing.expect(result2 == .success);
}

// Test: set IPv6 address.
test "network set ipv6" {
    var kernel = BasinKernel.init();
    
    // Create interface first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 4; // "eth0"
    const result1 = try kernel.syscall_network_create_interface(name_ptr, name_len, 0, 0);
    try testing.expect(result1 == .success);
    const iface_idx = result1.success;
    
    // Set IPv6 address (::1 - localhost).
    const addr_ptr: u64 = 0x20000;
    const result2 = try kernel.syscall_network_set_ipv6(iface_idx, addr_ptr, 0, 0);
    try testing.expect(result2 == .success);
}

// Test: delete network interface.
test "network delete interface" {
    var kernel = BasinKernel.init();
    
    // Create interface first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 4; // "eth0"
    const result1 = try kernel.syscall_network_create_interface(name_ptr, name_len, 0, 0);
    try testing.expect(result1 == .success);
    const iface_idx = result1.success;
    
    // Delete interface.
    const result2 = try kernel.syscall_network_delete_interface(iface_idx, 0, 0, 0);
    try testing.expect(result2 == .success);
    
    // Try to delete again (should fail).
    const result3 = kernel.syscall_network_delete_interface(iface_idx, 0, 0, 0);
    try testing.expectError(BasinError.not_found, result3);
}

// Test: enumerate network interfaces.
test "network enumerate interfaces" {
    var kernel = BasinKernel.init();
    
    // Create multiple interfaces.
    const name_ptr1: u64 = 0x10000;
    const name_len1: u64 = 4; // "eth0"
    const result1 = try kernel.syscall_network_create_interface(name_ptr1, name_len1, 0, 0);
    try testing.expect(result1 == .success);
    const iface_idx1 = result1.success;
    
    const name_ptr2: u64 = 0x20000;
    const name_len2: u64 = 4; // "eth1"
    const result2 = try kernel.syscall_network_create_interface(name_ptr2, name_len2, 0, 0);
    try testing.expect(result2 == .success);
    const iface_idx2 = result2.success;
    
    // Enumerate interfaces.
    const indices_ptr: u64 = 0x30000;
    const max_count: u64 = 8;
    const result3 = try kernel.syscall_network_enumerate_interfaces(indices_ptr, max_count, 0, 0);
    try testing.expect(result3 == .success);
    const count = result3.success;
    try testing.expect(count >= 2); // At least 2 interfaces
}

// Test: get network interface.
test "network get interface" {
    var kernel = BasinKernel.init();
    
    // Create interface first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 4; // "eth0"
    const result1 = try kernel.syscall_network_create_interface(name_ptr, name_len, 0, 0);
    try testing.expect(result1 == .success);
    const iface_idx = result1.success;
    
    // Get interface information.
    const info_ptr: u64 = 0x20000;
    const result2 = try kernel.syscall_network_get_interface(iface_idx, info_ptr, 0, 0);
    try testing.expect(result2 == .success);
}

// Test: invalid interface index.
test "network invalid interface index" {
    var kernel = BasinKernel.init();
    
    // Try to set state on invalid interface.
    const invalid_idx: u64 = 999;
    const state: u64 = 1;
    const result = try kernel.syscall_network_set_state(invalid_idx, state, 0, 0);
    try testing.expectError(BasinError.not_found, result);
}

// Test: invalid state value.
test "network invalid state" {
    var kernel = BasinKernel.init();
    
    // Create interface first.
    const name_ptr: u64 = 0x10000;
    const name_len: u64 = 4; // "eth0"
    const result1 = try kernel.syscall_network_create_interface(name_ptr, name_len, 0, 0);
    try testing.expect(result1 == .success);
    const iface_idx = result1.success;
    
    // Try to set invalid state.
    const invalid_state: u64 = 99;
    const result2 = kernel.syscall_network_set_state(iface_idx, invalid_state, 0, 0);
    try testing.expectError(BasinError.invalid_argument, result2);
}

