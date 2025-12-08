//! Segment Loader for Process Spawning
//! Why: Extract segment loading logic from syscall_spawn to reduce nesting and function length.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions, static allocation.

const std = @import("std");
const Debug = @import("debug.zig");
const elf_parser = @import("elf_parser.zig");
const BasinKernel = @import("basin_kernel.zig").BasinKernel;
const MapFlags = @import("basin_kernel.zig").MapFlags;
const SyscallResult = @import("basin_kernel.zig").SyscallResult;

/// Load a single program segment into VM memory.
/// Why: Extract segment loading logic to reduce nesting in syscall_spawn.
/// Contract: segment must be valid, read_fn and write_fn must be non-null, executable must be valid.
/// Returns: true if segment was loaded successfully, false otherwise.
/// Grain Style: Static allocation, explicit types, bounded operations.
pub fn load_program_segment(
    segment: elf_parser.ProgramSegment,
    executable: u64,
    read_fn: *const fn (addr: u64, len: u32, buffer: []u8) ?u32,
    write_fn: *const fn (addr: u64, len: u32, data: []const u8) ?u32,
    kernel: *BasinKernel,
) bool {
    // Assert: Segment must be valid (precondition).
    Debug.kassert(segment.valid, "Segment not valid", .{});
    Debug.kassert(segment.p_type == 1, "Segment not PT_LOAD", .{}); // PT_LOAD = 1
    
    // Create memory mapping for segment (page-aligned size).
    // Why: Map segment virtual address range with proper permissions.
    const segment_size = segment.p_memsz;
    const page_size: u64 = 4096;
    const aligned_size = ((segment_size + page_size - 1) / page_size) * page_size;
    
    // Convert segment flags to MapFlags.
    // Why: RISC-V ELF uses PF_R (0x4), PF_W (0x2), PF_X (0x1) flags.
    const PF_R: u32 = 0x4;
    const PF_W: u32 = 0x2;
    const PF_X: u32 = 0x1;
    
    const map_flags = MapFlags{
        .read = (segment.p_flags & PF_R) != 0,
        .write = (segment.p_flags & PF_W) != 0,
        .execute = (segment.p_flags & PF_X) != 0,
        .shared = false,
        ._padding = 0,
    };
    
    // Create mapping for segment (use segment's virtual address).
    // Why: Map segment at its intended virtual address.
    const map_result = kernel.syscall_map(segment.p_vaddr, aligned_size, @as(u64, @intCast(@as(u32, @bitCast(map_flags)))), 0) catch {
        return false; // Mapping failed
    };
    
    if (map_result != .success) {
        return false; // Mapping failed
    }
    
    // Load segment data into VM memory.
    // Why: Copy segment data from ELF file to VM memory after mapping is created.
    return load_segment_data(segment, executable, read_fn, write_fn);
}

/// Load segment data from ELF file into VM memory.
/// Why: Extract data loading logic to reduce nesting.
/// Contract: segment must be valid, read_fn and write_fn must be non-null, executable must be valid.
/// Returns: true if segment data was loaded successfully, false otherwise.
/// Grain Style: Static allocation, explicit types, bounded operations.
fn load_segment_data(
    segment: elf_parser.ProgramSegment,
    executable: u64,
    read_fn: *const fn (addr: u64, len: u32, buffer: []u8) ?u32,
    write_fn: *const fn (addr: u64, len: u32, data: []const u8) ?u32,
) bool {
    // Assert: Segment must be valid (precondition).
    Debug.kassert(segment.valid, "Segment not valid", .{});
    
    // Read segment data from ELF file.
    // Why: Segment data is at executable + p_offset in ELF file.
    const segment_data_size = @as(u32, @intCast(segment.p_filesz));
    if (segment_data_size == 0) {
        // Empty segment, just zero-fill if needed.
        return zero_fill_bss(segment, write_fn);
    }
    
    // Assert: Segment data size must be reasonable (max 1MB per segment).
    const MAX_SEGMENT_SIZE: u32 = 1024 * 1024;
    if (segment_data_size > MAX_SEGMENT_SIZE) {
        return false; // Segment too large
    }
    
    // Read segment data from ELF file.
    var segment_data_buffer: [1024 * 1024]u8 = undefined;
    const segment_data = segment_data_buffer[0..segment_data_size];
    
    const bytes_read = read_fn(executable + segment.p_offset, segment_data_size, segment_data) orelse {
        return false; // Failed to read segment data
    };
    
    if (bytes_read != segment_data_size) {
        return false; // Incomplete read
    }
    
    // Write segment data to VM memory at segment's virtual address.
    const bytes_written = write_fn(segment.p_vaddr, segment_data_size, segment_data) orelse {
        return false; // Failed to write segment data
    };
    
    // Assert: All segment data must be written.
    Debug.kassert(bytes_written == segment_data_size, "Segment data not fully written", .{});
    
    // Zero-fill remaining memory if memsz > filesz (BSS section).
    return zero_fill_bss(segment, write_fn);
}

/// Zero-fill BSS section (memory beyond file size).
/// Why: Extract BSS zero-filling logic to reduce nesting.
/// Contract: segment must be valid, write_fn must be non-null.
/// Returns: true if BSS was zero-filled successfully, false otherwise.
/// Grain Style: Static allocation, explicit types, bounded operations.
fn zero_fill_bss(
    segment: elf_parser.ProgramSegment,
    write_fn: *const fn (addr: u64, len: u32, data: []const u8) ?u32,
) bool {
    // Assert: Segment must be valid (precondition).
    Debug.kassert(segment.valid, "Segment not valid", .{});
    
    // Zero-fill remaining memory if memsz > filesz (BSS section).
    if (segment.p_memsz <= segment.p_filesz) {
        return true; // No BSS section
    }
    
    const zero_fill_size = @as(u32, @intCast(segment.p_memsz - segment.p_filesz));
    const MAX_ZERO_FILL: u32 = 1024 * 1024; // Max 1MB BSS
    
    if (zero_fill_size > MAX_ZERO_FILL) {
        return false; // BSS too large
    }
    
    var zero_buffer: [1024 * 1024]u8 = undefined;
    @memset(zero_buffer[0..zero_fill_size], 0);
    
    const zero_addr = segment.p_vaddr + segment.p_filesz;
    const bytes_written = write_fn(zero_addr, zero_fill_size, zero_buffer[0..zero_fill_size]) orelse {
        return false; // Failed to zero-fill BSS
    };
    
    // Assert: All BSS must be zero-filled.
    Debug.kassert(bytes_written == zero_fill_size, "BSS not fully zero-filled", .{});
    
    return true;
}

