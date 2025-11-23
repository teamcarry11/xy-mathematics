//! Channel Send/Receive Tests (Phase 3.22)
//! Why: Test IPC channel send and receive syscalls with actual message queue functionality.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const BasinError = basin_kernel.BasinError;
const Syscall = basin_kernel.Syscall;
const RawIO = basin_kernel.RawIO;

// Test: syscall_channel_send sends message to channel.
test "syscall_channel_send sends message to channel" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();

    // Create VM memory reader/writer.
    const VmAccess = struct {
        mem: *[4 * 1024 * 1024]u8,
        fn read_fn(addr: u64, len: u32, buffer: []u8) ?u32 {
            if (addr + len > VmAccess.mem.len) return null;
            @memcpy(buffer[0..len], VmAccess.mem[@intCast(addr)..][0..len]);
            return len;
        }
        fn write_fn(addr: u64, len: u32, data: []const u8) ?u32 {
            if (addr + len > VmAccess.mem.len) return null;
            @memcpy(VmAccess.mem[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    var vm_access = VmAccess{ .mem = &vm_memory };

    kernel.vm_memory_reader = vm_access.read_fn;
    kernel.vm_memory_writer = vm_access.write_fn;

    // Create a process and channel.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;

    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);

    // Create channel.
    const channel_create_num = @intFromEnum(Syscall.channel_create);
    const channel_result = try kernel.handle_syscall(channel_create_num, 0, 0, 0, 0);
    try testing.expect(channel_result == .success);
    const channel_id = channel_result.success;

    // Write test message to VM memory.
    const message = "Hello, Channel!";
    const data_ptr: u64 = 0x100000;
    @memcpy(vm_memory[@intCast(data_ptr)..][0..message.len], message);

    // Send message to channel.
    const send_num = @intFromEnum(Syscall.channel_send);
    const send_result = try kernel.handle_syscall(send_num, channel_id, data_ptr, message.len, 0);
    try testing.expect(send_result == .success);

    // Verify message is in channel.
    const channel = kernel.channels.find(channel_id);
    try testing.expect(channel != null);
    try testing.expect(channel.?.message_count == 1);
}

// Test: syscall_channel_recv receives message from channel.
test "syscall_channel_recv receives message from channel" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();

    // Create VM memory reader/writer.
    const VmAccess = struct {
        mem: *[4 * 1024 * 1024]u8,
        fn read_fn(addr: u64, len: u32, buffer: []u8) ?u32 {
            if (addr + len > VmAccess.mem.len) return null;
            @memcpy(buffer[0..len], VmAccess.mem[@intCast(addr)..][0..len]);
            return len;
        }
        fn write_fn(addr: u64, len: u32, data: []const u8) ?u32 {
            if (addr + len > VmAccess.mem.len) return null;
            @memcpy(VmAccess.mem[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    var vm_access = VmAccess{ .mem = &vm_memory };

    kernel.vm_memory_reader = vm_access.read_fn;
    kernel.vm_memory_writer = vm_access.write_fn;

    // Create a process and channel.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;

    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);

    // Create channel.
    const channel_create_num = @intFromEnum(Syscall.channel_create);
    const channel_result = try kernel.handle_syscall(channel_create_num, 0, 0, 0, 0);
    try testing.expect(channel_result == .success);
    const channel_id = channel_result.success;

    // Send message to channel (directly via channel API for setup).
    const message = "Test Message";
    const channel = kernel.channels.find(channel_id);
    try testing.expect(channel != null);
    const sent = channel.?.send(message);
    try testing.expect(sent);

    // Receive message from channel.
    const buffer_ptr: u64 = 0x200000;
    const buffer_len: u64 = 4096;
    const recv_num = @intFromEnum(Syscall.channel_recv);
    const recv_result = try kernel.handle_syscall(recv_num, channel_id, buffer_ptr, buffer_len, 0);
    try testing.expect(recv_result == .success);
    try testing.expect(recv_result.success == message.len);

    // Verify message data in VM memory.
    var received_message: [4096]u8 = undefined;
    @memcpy(&received_message, vm_memory[@intCast(buffer_ptr)..][0..message.len]);
    try testing.expect(std.mem.eql(u8, received_message[0..message.len], message));
}

// Test: syscall_channel_recv returns 0 when channel is empty.
test "syscall_channel_recv returns 0 when channel is empty" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();

    // Create VM memory reader/writer.
    const VmAccess = struct {
        mem: *[4 * 1024 * 1024]u8,
        fn read_fn(addr: u64, len: u32, buffer: []u8) ?u32 {
            if (addr + len > VmAccess.mem.len) return null;
            @memcpy(buffer[0..len], VmAccess.mem[@intCast(addr)..][0..len]);
            return len;
        }
        fn write_fn(addr: u64, len: u32, data: []const u8) ?u32 {
            if (addr + len > VmAccess.mem.len) return null;
            @memcpy(VmAccess.mem[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    var vm_access = VmAccess{ .mem = &vm_memory };

    kernel.vm_memory_reader = vm_access.read_fn;
    kernel.vm_memory_writer = vm_access.write_fn;

    // Create a process and channel.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;

    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);

    // Create channel.
    const channel_create_num = @intFromEnum(Syscall.channel_create);
    const channel_result = try kernel.handle_syscall(channel_create_num, 0, 0, 0, 0);
    try testing.expect(channel_result == .success);
    const channel_id = channel_result.success;

    // Receive from empty channel.
    const buffer_ptr: u64 = 0x200000;
    const buffer_len: u64 = 4096;
    const recv_num = @intFromEnum(Syscall.channel_recv);
    const recv_result = try kernel.handle_syscall(recv_num, channel_id, buffer_ptr, buffer_len, 0);
    try testing.expect(recv_result == .success);
    try testing.expect(recv_result.success == 0); // Empty channel returns 0
}

// Test: syscall_channel_send returns error when channel not found.
test "syscall_channel_send returns error when channel not found" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();

    // Create VM memory reader.
    const VmAccess = struct {
        mem: *[4 * 1024 * 1024]u8,
        fn read_fn(addr: u64, len: u32, buffer: []u8) ?u32 {
            if (addr + len > VmAccess.mem.len) return null;
            @memcpy(buffer[0..len], VmAccess.mem[@intCast(addr)..][0..len]);
            return len;
        }
    };
    var vm_access = VmAccess{ .mem = &vm_memory };

    kernel.vm_memory_reader = vm_access.read_fn;

    // Create a process.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;

    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);

    // Try to send to non-existent channel.
    const invalid_channel_id: u64 = 999;
    const message = "Test";
    const data_ptr: u64 = 0x100000;
    @memcpy(vm_memory[@intCast(data_ptr)..][0..message.len], message);

    const send_num = @intFromEnum(Syscall.channel_send);
    const send_result = kernel.handle_syscall(send_num, invalid_channel_id, data_ptr, message.len, 0);
    try testing.expect(send_result == .err);
    try testing.expect(send_result.err == BasinError.not_found);
}
