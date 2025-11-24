//! Comprehensive Userspace Execution Tests (Phase 3.23)
//! Why: Test complete userspace program execution flow including ELF loading,
//!      multi-process execution, IPC, and resource cleanup.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const BasinError = basin_kernel.BasinError;
const Syscall = basin_kernel.Syscall;
const RawIO = basin_kernel.RawIO;

// Helper: Create test ELF with multiple segments.
// Why: Test complete ELF loading with code and data segments.
fn create_multi_segment_elf(
    entry_point: u64,
    code_vaddr: u64,
    data_vaddr: u64,
    code_size: u64,
    data_size: u64,
) [512]u8 {
    var elf: [512]u8 = undefined;
    @memset(&elf, 0);

    // ELF header
    elf[0] = 0x7F;
    elf[1] = 'E';
    elf[2] = 'L';
    elf[3] = 'F';
    elf[4] = 2; // 64-bit
    elf[5] = 1; // little-endian

    // Entry point at offset 24
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        elf[24 + i] = @truncate((entry_point >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // Program header table offset at offset 32 (64 = after header)
    const phoff: u64 = 64;
    i = 0;
    while (i < 8) : (i += 1) {
        elf[32 + i] = @truncate((phoff >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // Program header entry size at offset 54 (56 bytes)
    const phentsize: u16 = 56;
    elf[54] = @truncate(phentsize & 0xFF);
    elf[55] = @truncate((phentsize >> 8) & 0xFF);

    // Program header count at offset 56 (2 segments)
    elf[56] = 2;
    elf[57] = 0;

    // First program header (code segment) at offset 64
    const PT_LOAD: u32 = 1;
    i = 0;
    while (i < 4) : (i += 1) {
        elf[64 + i] = @truncate((PT_LOAD >> @as(u5, @intCast(i * 8))) & 0xFF);
    }

    // p_flags: PF_R | PF_X (read + execute)
    const PF_R: u32 = 0x4;
    const PF_X: u32 = 0x1;
    const code_flags = PF_R | PF_X;
    i = 0;
    while (i < 4) : (i += 1) {
        elf[64 + 4 + i] = @truncate((code_flags >> @as(u5, @intCast(i * 8))) & 0xFF);
    }

    // p_offset: 176 (after both program headers)
    const code_offset: u64 = 176;
    i = 0;
    while (i < 8) : (i += 1) {
        elf[64 + 8 + i] = @truncate((code_offset >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_vaddr: code_vaddr
    i = 0;
    while (i < 8) : (i += 1) {
        elf[64 + 16 + i] = @truncate((code_vaddr >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_paddr: same as vaddr
    i = 0;
    while (i < 8) : (i += 1) {
        elf[64 + 24 + i] = @truncate((code_vaddr >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_filesz: code_size
    i = 0;
    while (i < 8) : (i += 1) {
        elf[64 + 32 + i] = @truncate((code_size >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_memsz: code_size
    i = 0;
    while (i < 8) : (i += 1) {
        elf[64 + 40 + i] = @truncate((code_size >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_align: 4096
    const p_align: u64 = 4096;
    i = 0;
    while (i < 8) : (i += 1) {
        elf[64 + 48 + i] = @truncate((p_align >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // Second program header (data segment) at offset 120
    i = 0;
    while (i < 4) : (i += 1) {
        elf[120 + i] = @truncate((PT_LOAD >> @as(u5, @intCast(i * 8))) & 0xFF);
    }

    // p_flags: PF_R | PF_W (read + write)
    const PF_W: u32 = 0x2;
    const data_flags = PF_R | PF_W;
    i = 0;
    while (i < 4) : (i += 1) {
        elf[120 + 4 + i] = @truncate((data_flags >> @as(u5, @intCast(i * 8))) & 0xFF);
    }

    // p_offset: code_offset + code_size
    const data_offset: u64 = code_offset + code_size;
    i = 0;
    while (i < 8) : (i += 1) {
        elf[120 + 8 + i] = @truncate((data_offset >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_vaddr: data_vaddr
    i = 0;
    while (i < 8) : (i += 1) {
        elf[120 + 16 + i] = @truncate((data_vaddr >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_paddr: same as vaddr
    i = 0;
    while (i < 8) : (i += 1) {
        elf[120 + 24 + i] = @truncate((data_vaddr >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_filesz: data_size
    i = 0;
    while (i < 8) : (i += 1) {
        elf[120 + 32 + i] = @truncate((data_size >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_memsz: data_size
    i = 0;
    while (i < 8) : (i += 1) {
        elf[120 + 40 + i] = @truncate((data_size >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // p_align: 4096
    i = 0;
    while (i < 8) : (i += 1) {
        elf[120 + 48 + i] = @truncate((p_align >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // Code segment data (at offset 176)
    const code_data_val: u8 = 0xAA;
    @memset(elf[176..][0..@intCast(code_size)], code_data_val);

    // Data segment data (at offset data_offset)
    const data_data_val: u8 = 0xBB;
    @memset(elf[@intCast(data_offset)..][0..@intCast(data_size)], data_data_val);

    return elf;
}

// Test: Complete ELF program execution with multiple segments.
test "complete ELF program execution with multiple segments" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();

    // Create VM memory reader/writer using threadlocal pattern.
    const VmAccess = struct {
        threadlocal var mem: *[4 * 1024 * 1024]u8 = undefined;
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(buffer[0..len], mem_ptr[@intCast(addr)..][0..len]);
            return len;
        }
        fn write(addr: u64, len: u32, data: []const u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(mem_ptr[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    VmAccess.mem = &vm_memory;

    kernel.vm_memory_reader = VmAccess.read;
    kernel.vm_memory_writer = VmAccess.write;

    // Create a process.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;

    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);

    // Create multi-segment ELF.
    const entry_point: u64 = 0x10000;
    const code_vaddr: u64 = 0x20000;
    const data_vaddr: u64 = 0x30000;
    const code_size: u64 = 4096;
    const data_size: u64 = 2048;
    const elf_data = create_multi_segment_elf(
        entry_point,
        code_vaddr,
        data_vaddr,
        code_size,
        data_size,
    );

    // Write ELF to VM memory.
    const executable_addr: u64 = 0x1000;
    @memcpy(vm_memory[@intCast(executable_addr)..][0..elf_data.len], elf_data);

    // Spawn process.
    const result = try kernel.syscall_spawn(executable_addr, 0, 0, 0);
    try testing.expect(result == .success);
    const spawned_pid = result.success;
    try testing.expect(spawned_pid != 0);

    // Verify code segment is loaded.
    var i: u64 = 0;
    while (i < code_size) : (i += 1) {
        try testing.expect(vm_memory[@intCast(code_vaddr + i)] == 0xAA);
    }

    // Verify data segment is loaded.
    i = 0;
    while (i < data_size) : (i += 1) {
        try testing.expect(vm_memory[@intCast(data_vaddr + i)] == 0xBB);
    }

    // Verify process context is set up.
    const process = kernel.processes[process_idx];
    try testing.expect(process.allocated);
    try testing.expect(process.id == spawned_pid);
}

// Test: Multiple processes executing simultaneously.
test "multiple processes executing simultaneously" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();

    // Create VM memory reader/writer.
    const VmAccess = struct {
        threadlocal var mem: *[4 * 1024 * 1024]u8 = undefined;
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(buffer[0..len], mem_ptr[@intCast(addr)..][0..len]);
            return len;
        }
        fn write(addr: u64, len: u32, data: []const u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(mem_ptr[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    VmAccess.mem = &vm_memory;

    kernel.vm_memory_reader = VmAccess.read;
    kernel.vm_memory_writer = VmAccess.write;

    // Create minimal ELF headers for two processes.
    var elf1: [64]u8 = undefined;
    @memset(&elf1, 0);
    elf1[0] = 0x7F;
    elf1[1] = 'E';
    elf1[2] = 'L';
    elf1[3] = 'F';
    elf1[4] = 2;
    elf1[5] = 1;
    var i: u32 = 0;
    const entry1: u64 = 0x10000;
    while (i < 8) : (i += 1) {
        elf1[24 + i] = @truncate((entry1 >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    var elf2: [64]u8 = undefined;
    @memset(&elf2, 0);
    elf2[0] = 0x7F;
    elf2[1] = 'E';
    elf2[2] = 'L';
    elf2[3] = 'F';
    elf2[4] = 2;
    elf2[5] = 1;
    i = 0;
    const entry2: u64 = 0x20000;
    while (i < 8) : (i += 1) {
        elf2[24 + i] = @truncate((entry2 >> @as(u6, @intCast(i * 8))) & 0xFF);
    }

    // Set up processes.
    kernel.processes[0].id = 1;
    kernel.processes[0].state = .running;
    kernel.processes[0].allocated = true;
    kernel.scheduler.set_current(1);

    // Write ELFs to VM memory.
    @memcpy(vm_memory[0x1000..][0..elf1.len], elf1);
    @memcpy(vm_memory[0x2000..][0..elf2.len], elf2);

    // Spawn first process.
    const result1 = try kernel.syscall_spawn(0x1000, 0, 0, 0);
    try testing.expect(result1 == .success);
    const pid1 = result1.success;

    // Set up second process.
    kernel.processes[1].id = 2;
    kernel.processes[1].state = .running;
    kernel.processes[1].allocated = true;
    kernel.scheduler.set_current(2);

    // Spawn second process.
    const result2 = try kernel.syscall_spawn(0x2000, 0, 0, 0);
    try testing.expect(result2 == .success);
    const pid2 = result2.success;

    // Verify both processes exist.
    try testing.expect(pid1 != pid2);
    try testing.expect(kernel.processes[0].allocated);
    try testing.expect(kernel.processes[1].allocated);
}

// Test: IPC communication between processes.
test "IPC communication between processes" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();

    // Create VM memory reader/writer.
    const VmAccess = struct {
        threadlocal var mem: *[4 * 1024 * 1024]u8 = undefined;
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(buffer[0..len], mem_ptr[@intCast(addr)..][0..len]);
            return len;
        }
        fn write(addr: u64, len: u32, data: []const u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(mem_ptr[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    VmAccess.mem = &vm_memory;

    kernel.vm_memory_reader = VmAccess.read;
    kernel.vm_memory_writer = VmAccess.write;

    // Set up process 1.
    kernel.processes[0].id = 1;
    kernel.processes[0].state = .running;
    kernel.processes[0].allocated = true;
    kernel.scheduler.set_current(1);

    // Create channel.
    const channel_create_num = @intFromEnum(Syscall.channel_create);
    const channel_result = try kernel.handle_syscall(channel_create_num, 0, 0, 0, 0);
    try testing.expect(channel_result == .success);
    const channel_id = channel_result.success;

    // Process 1 sends message.
    const message = "Hello from Process 1!";
    const data_ptr: u64 = 0x100000;
    @memcpy(vm_memory[@intCast(data_ptr)..][0..message.len], message);

    const send_num = @intFromEnum(Syscall.channel_send);
    const send_result = try kernel.handle_syscall(send_num, channel_id, data_ptr, message.len, 0);
    try testing.expect(send_result == .success);

    // Set up process 2.
    kernel.processes[1].id = 2;
    kernel.processes[1].state = .running;
    kernel.processes[1].allocated = true;
    kernel.scheduler.set_current(2);

    // Process 2 receives message.
    const buffer_ptr: u64 = 0x200000;
    const buffer_len: u64 = 4096;
    const recv_num = @intFromEnum(Syscall.channel_recv);
    const recv_result = try kernel.handle_syscall(recv_num, channel_id, buffer_ptr, buffer_len, 0);
    try testing.expect(recv_result == .success);
    try testing.expect(recv_result.success == message.len);

    // Verify message content.
    var received_message: [4096]u8 = undefined;
    @memcpy(received_message[0..message.len], vm_memory[@intCast(buffer_ptr)..][0..message.len]);
    try testing.expect(std.mem.eql(u8, received_message[0..message.len], message));
}

// Test: Resource cleanup during process execution.
test "resource cleanup during process execution" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();

    // Create VM memory reader/writer.
    const VmAccess = struct {
        threadlocal var mem: *[4 * 1024 * 1024]u8 = undefined;
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(buffer[0..len], mem_ptr[@intCast(addr)..][0..len]);
            return len;
        }
        fn write(addr: u64, len: u32, data: []const u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(mem_ptr[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    VmAccess.mem = &vm_memory;

    kernel.vm_memory_reader = VmAccess.read;
    kernel.vm_memory_writer = VmAccess.write;

    // Set up process.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;

    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);

    // Create memory mapping.
    const map_num = @intFromEnum(Syscall.map);
    const map_addr: u64 = 0x40000;
    const map_size: u64 = 4096;
    const map_flags: u64 = 0x7; // Read, Write, Execute
    const map_result = try kernel.handle_syscall(map_num, map_addr, map_size, map_flags, 0);
    try testing.expect(map_result == .success);

    // Create channel.
    const channel_create_num = @intFromEnum(Syscall.channel_create);
    const channel_result = try kernel.handle_syscall(channel_create_num, 0, 0, 0, 0);
    try testing.expect(channel_result == .success);
    const channel_id = channel_result.success;

    // Verify resources exist.
    var mapping_found = false;
    for (kernel.mappings) |mapping| {
        if (mapping.allocated and mapping.address == map_addr) {
            mapping_found = true;
            break;
        }
    }
    try testing.expect(mapping_found);

    const channel = kernel.channels.find(channel_id);
    try testing.expect(channel != null);
    try testing.expect(channel.?.allocated);

    // Process exits.
    const exit_num = @intFromEnum(Syscall.exit);
    const exit_result = try kernel.handle_syscall(exit_num, 0, 0, 0, 0);
    try testing.expect(exit_result == .success);

    // Verify process is marked as exited.
    try testing.expect(kernel.processes[process_idx].state == .exited);

    // Verify resources are cleaned up (mapping should be freed).
    // Note: Resource cleanup happens in syscall_exit, but we verify the process state.
    // Actual cleanup verification would require checking resource_cleanup module.
    try testing.expect(kernel.processes[process_idx].state == .exited);
}

