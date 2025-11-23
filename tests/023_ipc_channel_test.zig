//! IPC Channel Tests
//! Why: Comprehensive TigerStyle tests for IPC channel functionality.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const Channel = basin_kernel.basin_kernel.Channel;
const ChannelTable = basin_kernel.basin_kernel.ChannelTable;
const MAX_MESSAGE_SIZE = basin_kernel.basin_kernel.MAX_MESSAGE_SIZE;

// Test channel initialization.
test "channel init" {
    const channel_instance = Channel.init();
    
    // Assert: Channel must be unallocated initially.
    try std.testing.expect(!channel_instance.allocated);
    try std.testing.expect(channel_instance.id == 0);
    try std.testing.expect(channel_instance.message_count == 0);
    try std.testing.expect(channel_instance.read_pos == 0);
    try std.testing.expect(channel_instance.write_pos == 0);
}

// Test channel send and receive.
test "channel send receive" {
    var channel_instance = Channel.init();
    channel_instance.allocated = true;
    channel_instance.id = 1;
    
    const data = "Hello, World!";
    const sent = channel_instance.send(data);
    
    // Assert: Message must be sent.
    try std.testing.expect(sent);
    try std.testing.expect(channel_instance.message_count == 1);
    try std.testing.expect(channel_instance.has_messages());
    
    var buffer: [MAX_MESSAGE_SIZE]u8 = undefined;
    const received = channel_instance.receive(&buffer);
    
    // Assert: Message must be received.
    try std.testing.expect(received == data.len);
    try std.testing.expect(std.mem.eql(u8, buffer[0..received], data));
    try std.testing.expect(channel_instance.message_count == 0);
    try std.testing.expect(!channel_instance.has_messages());
}

// Test channel send multiple messages.
test "channel send multiple" {
    var channel_instance = Channel.init();
    channel_instance.allocated = true;
    channel_instance.id = 1;
    
    const data1 = "Message 1";
    const data2 = "Message 2";
    
    const sent1 = channel_instance.send(data1);
    const sent2 = channel_instance.send(data2);
    
    // Assert: Both messages must be sent.
    try std.testing.expect(sent1);
    try std.testing.expect(sent2);
    try std.testing.expect(channel_instance.message_count == 2);
    
    var buffer: [MAX_MESSAGE_SIZE]u8 = undefined;
    const received1 = channel_instance.receive(&buffer);
    
    // Assert: First message must be received.
    try std.testing.expect(received1 == data1.len);
    try std.testing.expect(std.mem.eql(u8, buffer[0..received1], data1));
    try std.testing.expect(channel_instance.message_count == 1);
    
    const received2 = channel_instance.receive(&buffer);
    
    // Assert: Second message must be received.
    try std.testing.expect(received2 == data2.len);
    try std.testing.expect(std.mem.eql(u8, buffer[0..received2], data2));
    try std.testing.expect(channel_instance.message_count == 0);
}

// Test channel queue full.
test "channel queue full" {
    var channel_instance = Channel.init();
    channel_instance.allocated = true;
    channel_instance.id = 1;
    
    // Fill channel queue (32 messages max).
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        const data = "X";
        const sent = channel_instance.send(data);
        try std.testing.expect(sent);
    }
    
    // Assert: Channel must be full.
    try std.testing.expect(channel_instance.message_count == 32);
    
    // Try to send one more (should fail).
    const data = "Y";
    const sent = channel_instance.send(data);
    
    // Assert: Send must fail (queue full).
    try std.testing.expect(!sent);
    try std.testing.expect(channel_instance.message_count == 32);
}

// Test channel receive empty.
test "channel receive empty" {
    var channel_instance = Channel.init();
    channel_instance.allocated = true;
    channel_instance.id = 1;
    
    var buffer: [MAX_MESSAGE_SIZE]u8 = undefined;
    const received = channel_instance.receive(&buffer);
    
    // Assert: Receive must return 0 (queue empty).
    try std.testing.expect(received == 0);
    try std.testing.expect(!channel_instance.has_messages());
}

// Test channel table create.
test "channel table create" {
    var table = ChannelTable.init();
    
    const id1 = table.create();
    
    // Assert: Channel must be created.
    try std.testing.expect(id1 != 0);
    try std.testing.expect(table.channel_count == 1);
    
    const found_channel = table.find(id1);
    
    // Assert: Channel must be found.
    try std.testing.expect(found_channel != null);
    try std.testing.expect(found_channel.?.id == id1);
    try std.testing.expect(found_channel.?.allocated);
}

// Test channel table find non-existent.
test "channel table find non-existent" {
    var table = ChannelTable.init();
    
    const found_channel = table.find(999);
    
    // Assert: Channel must not be found.
    try std.testing.expect(found_channel == null);
}

// Test channel table create multiple.
test "channel table create multiple" {
    var table = ChannelTable.init();
    
    const id1 = table.create();
    const id2 = table.create();
    const id3 = table.create();
    
    // Assert: All channels must be created with unique IDs.
    try std.testing.expect(id1 != 0);
    try std.testing.expect(id2 != 0);
    try std.testing.expect(id3 != 0);
    try std.testing.expect(id1 != id2);
    try std.testing.expect(id2 != id3);
    try std.testing.expect(id1 != id3);
    try std.testing.expect(table.channel_count == 3);
}

// Test kernel channel create syscall.
test "kernel channel create" {
    var kernel = BasinKernel.init();
    
    const result = kernel.handle_syscall(
        20, // channel_create syscall number
        0,
        0,
        0,
        0,
    );
    
    // Assert: Channel must be created.
    const syscall_result = try result;
    try std.testing.expect(syscall_result == .success or syscall_result == .err);
    if (syscall_result == .err) return error.TestUnexpectedError;
    try std.testing.expect(syscall_result.success != 0);
    try std.testing.expect(kernel.channels.channel_count == 1);
}

// Test kernel channel send syscall (validation only).
test "kernel channel send validation" {
    var kernel = BasinKernel.init();
    
    // Create channel first.
    const create_result_raw = kernel.handle_syscall(
        20, // channel_create syscall number
        0,
        0,
        0,
        0,
    );
    const create_result = try create_result_raw;
    try std.testing.expect(create_result == .success or create_result == .err);
    if (create_result == .err) return error.TestUnexpectedError;
    const channel_id = create_result.success;
    
    // Try to send with invalid channel ID.
    const send_result_invalid = kernel.handle_syscall(
        81, // channel_send syscall number
        999, // Invalid channel ID
        0x1000,
        10,
        0,
    );
    
    // Assert: Send must fail (channel not found).
    const send_result_unwrapped = try send_result_invalid;
    try std.testing.expect(send_result_unwrapped == .err);
    try std.testing.expect(send_result_unwrapped.err == BasinError.not_found);
    
    // Try to send with valid channel ID (but invalid data pointer).
    const send_result_null = kernel.handle_syscall(
        81, // channel_send syscall number
        channel_id,
        0, // Null pointer
        10,
        0,
    );
    
    // Assert: Send must fail (null pointer).
    try std.testing.expect(send_result_null == .err);
    try std.testing.expect(send_result_null.err == .invalid_argument);
}

// Test kernel channel recv syscall (validation only).
test "kernel channel recv validation" {
    var kernel = BasinKernel.init();
    
    // Create channel first.
    const create_result_raw = kernel.handle_syscall(
        20, // channel_create syscall number
        0,
        0,
        0,
        0,
    );
    const create_result = try create_result_raw;
    try std.testing.expect(create_result == .success or create_result == .err);
    if (create_result == .err) return error.TestUnexpectedError;
    const channel_id = create_result.success;
    
    // Try to receive with invalid channel ID.
    const recv_result_invalid = kernel.handle_syscall(
        82, // channel_recv syscall number
        999, // Invalid channel ID
        0x1000,
        4096,
        0,
    );
    
    // Assert: Receive must fail (channel not found).
    const recv_result_unwrapped = try recv_result_invalid;
    try std.testing.expect(recv_result_unwrapped == .err);
    try std.testing.expect(recv_result_unwrapped.err == BasinError.not_found);
    
    // Try to receive with valid channel ID but empty queue.
    const recv_result_empty = kernel.handle_syscall(
        82, // channel_recv syscall number
        channel_id,
        0x1000,
        4096,
        0,
    );
    
    // Assert: Receive must fail (queue empty).
    try std.testing.expect(recv_result_empty == .err);
    try std.testing.expect(recv_result_empty.err == .would_block);
}

