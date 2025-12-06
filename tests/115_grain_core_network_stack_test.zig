//! Tests for Grain OS Network Stack
//! Grain Style: grain_case, u32/u64, bounded allocations, assertions

const std = @import("std");
const network_stack = @import("grain_core").network_stack;

test "network_stack_init" {
    const stack = network_stack.NetworkStack.init();
    std.debug.assert(stack.socket_count == 0);
    std.debug.assert(stack.connection_count == 0);
    std.debug.assert(stack.next_socket_id == 1);
}

test "network_stack_create_tcp_socket" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket();
    std.debug.assert(socket_id != null);
    std.debug.assert(socket_id.? > 0);
    std.debug.assert(stack.socket_count == 1);
    if (stack.get_socket(socket_id.?)) |socket| {
        std.debug.assert(socket.socket_type == network_stack.SocketType.tcp);
        std.debug.assert(socket.state == network_stack.SocketState.closed);
    }
}

test "network_stack_create_udp_socket" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_udp_socket();
    std.debug.assert(socket_id != null);
    std.debug.assert(socket_id.? > 0);
    std.debug.assert(stack.socket_count == 1);
    if (stack.get_socket(socket_id.?)) |socket| {
        std.debug.assert(socket.socket_type == network_stack.SocketType.udp);
        std.debug.assert(socket.state == network_stack.SocketState.closed);
    }
}

test "network_stack_bind_socket" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const address = network_stack.IpAddress.init_ipv4([4]u8{ 127, 0, 0, 1 }, 8080);
    const bound = stack.bind_socket(socket_id.?, address);
    std.debug.assert(bound);
    if (stack.get_socket(socket_id.?)) |socket| {
        std.debug.assert(socket.local_address.port == 8080);
        std.debug.assert(socket.local_address.family == network_stack.AddressFamily.ipv4);
    }
}

test "network_stack_listen_socket" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const address = network_stack.IpAddress.init_ipv4([4]u8{ 127, 0, 0, 1 }, 8080);
    _ = stack.bind_socket(socket_id.?, address);
    const listening = stack.listen_socket(socket_id.?, 10);
    std.debug.assert(listening);
    if (stack.get_socket(socket_id.?)) |socket| {
        std.debug.assert(socket.state == network_stack.SocketState.listening);
        std.debug.assert(socket.is_listening);
    }
}

test "network_stack_connect_socket" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const remote_address = network_stack.IpAddress.init_ipv4([4]u8{ 127, 0, 0, 1 }, 8080);
    const connected = stack.connect_socket(socket_id.?, remote_address);
    std.debug.assert(connected);
    if (stack.get_socket(socket_id.?)) |socket| {
        std.debug.assert(socket.state == network_stack.SocketState.connected);
        std.debug.assert(socket.remote_address != null);
    }
}

test "network_stack_send_data" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const remote_address = network_stack.IpAddress.init_ipv4([4]u8{ 127, 0, 0, 1 }, 8080);
    _ = stack.connect_socket(socket_id.?, remote_address);
    const data = "Hello, World!";
    var bytes_sent: u32 = 0;
    const sent = stack.send_data(socket_id.?, data, &bytes_sent);
    std.debug.assert(sent);
    std.debug.assert(bytes_sent > 0);
    std.debug.assert(bytes_sent <= data.len);
}

test "network_stack_receive_data" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const remote_address = network_stack.IpAddress.init_ipv4([4]u8{ 127, 0, 0, 1 }, 8080);
    _ = stack.connect_socket(socket_id.?, remote_address);
    var buffer: [1024]u8 = undefined;
    var bytes_received: u32 = 0;
    const received = stack.receive_data(socket_id.?, &buffer, &bytes_received);
    std.debug.assert(received);
    std.debug.assert(bytes_received <= buffer.len);
}

test "network_stack_close_socket" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const closed = stack.close_socket(socket_id.?);
    std.debug.assert(closed);
    std.debug.assert(stack.socket_count == 0);
    std.debug.assert(stack.get_socket(socket_id.?) == null);
}

test "network_stack_set_non_blocking" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const set = stack.set_non_blocking(socket_id.?, true);
    std.debug.assert(set);
    if (stack.get_socket(socket_id.?)) |socket| {
        std.debug.assert(!socket.is_blocking);
    }
}

test "network_stack_get_socket_count" {
    var stack = network_stack.NetworkStack.init();
    std.debug.assert(stack.get_socket_count() == 0);
    _ = stack.create_tcp_socket();
    std.debug.assert(stack.get_socket_count() == 1);
    _ = stack.create_udp_socket();
    std.debug.assert(stack.get_socket_count() == 2);
}

test "network_stack_get_connection_count" {
    var stack = network_stack.NetworkStack.init();
    std.debug.assert(stack.get_connection_count() == 0);
    const socket_id = stack.create_tcp_socket() orelse return;
    const address = network_stack.IpAddress.init_ipv4([4]u8{ 127, 0, 0, 1 }, 8080);
    _ = stack.bind_socket(socket_id.?, address);
    _ = stack.listen_socket(socket_id.?, 10);
    _ = stack.accept_connection(socket_id.?, null);
    std.debug.assert(stack.get_connection_count() == 1);
}

test "network_stack_ipv6_address" {
    const addr: [16]u8 = [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 };
    const address = network_stack.IpAddress.init_ipv6(addr, 8080);
    std.debug.assert(address.family == network_stack.AddressFamily.ipv6);
    std.debug.assert(address.port == 8080);
    std.debug.assert(address.address_len == 16);
}

test "network_stack_set_socket_option_reuse_address" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const set = stack.set_socket_option(
        socket_id.?,
        network_stack.SocketOption.reuse_address,
        1,
    );
    std.debug.assert(set);
    const value = stack.get_socket_option(
        socket_id.?,
        network_stack.SocketOption.reuse_address,
    );
    std.debug.assert(value != null);
    std.debug.assert(value.? == 1);
}

test "network_stack_set_socket_option_keep_alive" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const set = stack.set_socket_option(
        socket_id.?,
        network_stack.SocketOption.keep_alive,
        1,
    );
    std.debug.assert(set);
    const value = stack.get_socket_option(
        socket_id.?,
        network_stack.SocketOption.keep_alive,
    );
    std.debug.assert(value != null);
    std.debug.assert(value.? == 1);
}

test "network_stack_set_socket_option_timeout" {
    var stack = network_stack.NetworkStack.init();
    const socket_id = stack.create_tcp_socket() orelse return;
    const timeout_value: u64 = 60000;
    const set = stack.set_socket_option(
        socket_id.?,
        network_stack.SocketOption.timeout,
        timeout_value,
    );
    std.debug.assert(set);
    const value = stack.get_socket_option(
        socket_id.?,
        network_stack.SocketOption.timeout,
    );
    std.debug.assert(value != null);
    std.debug.assert(value.? == timeout_value);
}

test "network_stack_get_socket_option_invalid_socket" {
    var stack = network_stack.NetworkStack.init();
    const value = stack.get_socket_option(
        999,
        network_stack.SocketOption.reuse_address,
    );
    std.debug.assert(value == null);
}

