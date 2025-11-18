const std = @import("std");
const VM = @import("vm.zig").VM;

/// RISC-V64 ELF kernel loader.
/// Grain Style: Static allocation where possible, comprehensive assertions.
/// ~<~ Glow Earthbend: ELF parsing is explicit, no hidden allocations.

/// ELF header structure (64-bit, little-endian).
/// Why: Explicit ELF structure for kernel loading.
const Elf64_Ehdr = extern struct {
    /// ELF magic number: 0x7F "ELF".
    e_ident: [16]u8,
    /// Object file type (1 = relocatable, 2 = executable, 3 = shared).
    e_type: u16,
    /// Machine architecture (243 = RISC-V).
    e_machine: u16,
    /// Object file version (usually 1).
    e_version: u32,
    /// Entry point virtual address.
    e_entry: u64,
    /// Program header table file offset.
    e_phoff: u64,
    /// Section header table file offset.
    e_shoff: u64,
    /// Processor-specific flags.
    e_flags: u32,
    /// ELF header size in bytes.
    e_ehsize: u16,
    /// Program header table entry size.
    e_phentsize: u16,
    /// Program header table entry count.
    e_phnum: u16,
    /// Section header table entry size.
    e_shentsize: u16,
    /// Section header table entry count.
    e_shnum: u16,
    /// Section header string table index.
    e_shstrndx: u16,
};

/// Program header structure (64-bit, little-endian).
/// Why: Explicit program header for loading kernel segments.
const Elf64_Phdr = extern struct {
    /// Segment type (1 = loadable).
    p_type: u32,
    /// Segment flags (read, write, execute).
    p_flags: u32,
    /// Segment file offset.
    p_offset: u64,
    /// Segment virtual address.
    p_vaddr: u64,
    /// Segment physical address.
    p_paddr: u64,
    /// Segment size in file.
    p_filesz: u64,
    /// Segment size in memory.
    p_memsz: u64,
    /// Segment alignment.
    p_align: u64,
};

/// ELF magic number: 0x7F "ELF".
const ELF_MAGIC = [_]u8{ 0x7F, 'E', 'L', 'F' };

/// Loader errors.
/// Why: Explicit error types for ELF loading.
pub const LoaderError = error{
    SegmentOutOfBounds,
    InvalidElfFormat,
};

/// Load RISC-V64 kernel ELF into VM (GrainStyle: in-place initialization).
/// Why: Parse ELF file and load kernel segments into VM memory.
/// Contract: target must point to uninitialized VM struct.
/// Contract: elf_data must be valid ELF format.
/// Errors: SegmentOutOfBounds if ELF segments don't fit in VM memory.
/// Errors: InvalidElfFormat if ELF header is invalid.
/// Postcondition: VM is initialized with ELF segments loaded, PC set to entry point.
pub fn loadKernel(target: *VM, _: std.mem.Allocator, elf_data: []const u8) LoaderError!void {
    std.debug.print("DEBUG loader.zig: loadKernel called, elf_data.len={}\n", .{elf_data.len});
    
    // Check: ELF data must be non-empty.
    if (elf_data.len == 0) {
        std.debug.print("DEBUG loader.zig: ELF data is empty\n", .{});
        return error.InvalidElfFormat;
    }
    
    // Check: ELF data must be large enough for ELF header.
    if (elf_data.len < @sizeOf(Elf64_Ehdr)) {
        std.debug.print("DEBUG loader.zig: ELF data too small ({} < {})\n", .{ elf_data.len, @sizeOf(Elf64_Ehdr) });
        return error.InvalidElfFormat;
    }
    
    // Parse ELF header.
    // Why: @alignCast required because Elf64_Ehdr requires alignment.
    // Note: ELF files are typically aligned, but we check alignment to avoid crashes.
    // Check: ELF data pointer alignment (Elf64_Ehdr requires 8-byte alignment).
    const alignment_required = @alignOf(Elf64_Ehdr);
    const ptr_addr = @intFromPtr(elf_data.ptr);
    std.debug.print("DEBUG loader.zig: ptr_addr=0x{x}, alignment_required={}, aligned={}\n", .{ ptr_addr, alignment_required, ptr_addr % alignment_required == 0 });
    
    const ehdr: *const Elf64_Ehdr = if (ptr_addr % alignment_required != 0) blk: {
        std.debug.print("DEBUG loader.zig: Using aligned buffer (unaligned pointer)\n", .{});
        // ELF data is not properly aligned - copy to aligned buffer.
        var aligned_buffer: [@sizeOf(Elf64_Ehdr)]u8 align(alignment_required) = undefined;
        @memcpy(&aligned_buffer, elf_data[0..@sizeOf(Elf64_Ehdr)]);
        break :blk @as(*const Elf64_Ehdr, @ptrCast(&aligned_buffer));
    } else blk: {
        std.debug.print("DEBUG loader.zig: Using @alignCast (aligned pointer)\n", .{});
        break :blk @as(*const Elf64_Ehdr, @alignCast(@ptrCast(elf_data.ptr)));
    };
    
    std.debug.print("DEBUG loader.zig: ELF header parsed, magic={x:0>2} {x:0>2} {x:0>2} {x:0>2}\n", .{ ehdr.e_ident[0], ehdr.e_ident[1], ehdr.e_ident[2], ehdr.e_ident[3] });
    
    // Check: ELF magic number must match (return error instead of asserting for userspace programs).
    if (!std.mem.eql(u8, ehdr.e_ident[0..4], &ELF_MAGIC)) {
        return error.InvalidElfFormat;
    }
    
    // Check: ELF class must be 64-bit (e_ident[4] = 2).
    if (ehdr.e_ident[4] != 2) {
        return error.InvalidElfFormat;
    }
    
    // Check: ELF endianness must be little-endian (e_ident[5] = 1).
    if (ehdr.e_ident[5] != 1) {
        return error.InvalidElfFormat;
    }
    
    // Check: ELF version must be 1 (e_ident[6] = 1).
    if (ehdr.e_ident[6] != 1) {
        return error.InvalidElfFormat;
    }
    
    // Check: Machine architecture must be RISC-V (243).
    if (ehdr.e_machine != 243) {
        return error.InvalidElfFormat;
    }
    
    // Check: ELF type must be executable (2).
    if (ehdr.e_type != 2) {
        return error.InvalidElfFormat;
    }
    
    // Check: Program header table must be present.
    if (ehdr.e_phnum == 0 or ehdr.e_phoff == 0) {
        return error.InvalidElfFormat;
    }
    
    // Check: Program header table must fit in ELF data.
    const phdr_size = @as(usize, ehdr.e_phnum) * @sizeOf(Elf64_Phdr);
    if (ehdr.e_phoff + phdr_size > elf_data.len) {
        return error.InvalidElfFormat;
    }
    
    // Initialize VM (will be populated with kernel segments).
    // GrainStyle: Use in-place initialization to avoid stack overflow.
    VM.init(target, &[_]u8{}, 0);
    
    // Load each program header segment.
    // Why: Load kernel code/data segments into VM memory.
    const phdr_base = elf_data[@intCast(ehdr.e_phoff)..];
    std.debug.print("DEBUG loader.zig: Loading {} program headers\n", .{ehdr.e_phnum});
    var phdr_idx: u16 = 0;
    var first_load_vaddr: ?u64 = null; // Track first PT_LOAD segment for PIE entry point adjustment
    while (phdr_idx < ehdr.e_phnum) : (phdr_idx += 1) {
        std.debug.print("DEBUG loader.zig: Processing program header {}/{}\n", .{ phdr_idx + 1, ehdr.e_phnum });
        const phdr_offset = phdr_idx * @sizeOf(Elf64_Phdr);
        // Check: Program header must fit in ELF data.
        if (phdr_offset + @sizeOf(Elf64_Phdr) > phdr_base.len) {
            std.debug.print("DEBUG loader.zig: Program header {} out of bounds\n", .{phdr_idx});
            return error.InvalidElfFormat;
        }
        
        // Why: @alignCast required because Elf64_Phdr requires alignment.
        const phdr = @as(*const Elf64_Phdr, @alignCast(@ptrCast(phdr_base.ptr + phdr_offset)));
        std.debug.print("DEBUG loader.zig: Program header {}: type={}, vaddr=0x{x}, filesz={}, memsz={}\n", .{ phdr_idx, phdr.p_type, phdr.p_vaddr, phdr.p_filesz, phdr.p_memsz });
        
        // Only load PT_LOAD segments (type 1).
        if (phdr.p_type == 1) {
            // Track first PT_LOAD segment for PIE entry point adjustment.
            if (first_load_vaddr == null) {
                first_load_vaddr = phdr.p_vaddr;
            }
            std.debug.print("DEBUG loader.zig: Loading PT_LOAD segment at vaddr=0x{x}\n", .{phdr.p_vaddr});
            // Check: Segment must fit in ELF data (return error instead of asserting for userspace programs).
            if (phdr.p_offset + phdr.p_filesz > elf_data.len) {
                return error.InvalidElfFormat;
            }
            
            // Check: Segment must fit in VM memory (return error instead of asserting for userspace programs).
            if (phdr.p_vaddr + phdr.p_memsz > target.memory_size) {
                return error.SegmentOutOfBounds;
            }
            
            // Check: Segment address must be valid for memory copy.
            if (phdr.p_vaddr + phdr.p_filesz > target.memory_size) {
                return error.SegmentOutOfBounds;
            }
            
            // Load segment data into VM memory.
            // Contract: All bounds must be checked before memory operations.
            const segment_data = elf_data[@intCast(phdr.p_offset)..][0..@intCast(phdr.p_filesz)];
            const dest_start = @as(usize, @intCast(phdr.p_vaddr));
            const dest_end = dest_start + segment_data.len;
            
            // Check: Destination must be within VM memory bounds.
            if (dest_start >= target.memory_size) {
                std.debug.print("DEBUG loader.zig: Segment vaddr 0x{x} >= memory_size 0x{x}\n", .{ phdr.p_vaddr, target.memory_size });
                return error.SegmentOutOfBounds;
            }
            if (dest_end > target.memory_size) {
                std.debug.print("DEBUG loader.zig: Segment end 0x{x} > memory_size 0x{x}\n", .{ phdr.p_vaddr + phdr.p_filesz, target.memory_size });
                return error.SegmentOutOfBounds;
            }
            
            // Check: Destination slice must be valid.
            if (dest_start + segment_data.len > target.memory.len) {
                std.debug.print("DEBUG loader.zig: Segment would overflow memory array\n", .{});
                return error.SegmentOutOfBounds;
            }
            
            // Safe to copy: all bounds checked.
            std.debug.print("DEBUG loader.zig: Copying {} bytes from offset {} to vaddr 0x{x}\n", .{ segment_data.len, phdr.p_offset, phdr.p_vaddr });
            @memcpy(target.memory[dest_start..dest_end], segment_data);
            std.debug.print("DEBUG loader.zig: Copy completed successfully\n", .{});
            
            // Zero-fill memory beyond file size (if memsz > filesz).
            if (phdr.p_memsz > phdr.p_filesz) {
                const zero_start = @as(usize, @intCast(phdr.p_vaddr + phdr.p_filesz));
                const zero_len = @as(usize, @intCast(phdr.p_memsz - phdr.p_filesz));
                std.debug.print("DEBUG loader.zig: Zero-filling {} bytes at vaddr 0x{x}\n", .{ zero_len, phdr.p_vaddr + phdr.p_filesz });
                // Check: Zero-fill region must fit in VM memory.
                if (zero_start + zero_len > target.memory_size) {
                    std.debug.print("DEBUG loader.zig: Zero-fill would exceed memory_size\n", .{});
                    return error.SegmentOutOfBounds;
                }
                if (zero_start + zero_len > target.memory.len) {
                    std.debug.print("DEBUG loader.zig: Zero-fill would overflow memory array\n", .{});
                    return error.SegmentOutOfBounds;
                }
                @memset(target.memory[zero_start..zero_start + zero_len], 0);
                std.debug.print("DEBUG loader.zig: Zero-fill completed successfully\n", .{});
            }
        }
    }
    
    // Set VM PC to ELF entry point.
    // Note: For PIE executables, if entry point is 0x0, use first PT_LOAD segment's vaddr as base.
    var entry_point = ehdr.e_entry;
    if (entry_point == 0x0) {
        if (first_load_vaddr) |base_addr| {
            std.debug.print("DEBUG loader.zig: PIE executable detected (entry=0x0), using first PT_LOAD vaddr 0x{x} as entry point\n", .{base_addr});
            entry_point = base_addr;
        }
    }
    std.debug.print("DEBUG loader.zig: Setting entry point to 0x{x}\n", .{entry_point});
    // Check: Entry point must be within VM memory bounds.
    if (entry_point >= target.memory_size) {
        std.debug.print("DEBUG loader.zig: Entry point 0x{x} >= memory_size 0x{x}\n", .{ entry_point, target.memory_size });
        return error.SegmentOutOfBounds;
    }
    
    target.regs.pc = entry_point;
    std.debug.print("DEBUG loader.zig: Entry point set successfully, PC=0x{x}\n", .{target.regs.pc});
    
    // Contract: PC must be set to entry point (verified by assignment above).
    // Note: Entry point can be 0x0 for position-independent executables (adjusted to first PT_LOAD vaddr).
    
    // Assert: VM must be in halted state after loading.
    std.debug.assert(target.state == .halted);
}

