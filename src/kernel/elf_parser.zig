//! ELF Parser for Kernel
//! Why: Parse ELF headers to extract entry point and segment information for process spawning.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions, static allocation.

const std = @import("std");
const Debug = @import("debug.zig");

/// ELF header structure (64-bit, little-endian).
/// Why: Explicit ELF structure for parsing entry point and segment info.
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

/// ELF magic number: 0x7F "ELF".
/// Why: Validate ELF file format.
const ELF_MAGIC = [_]u8{ 0x7F, 'E', 'L', 'F' };

/// ELF program header structure (64-bit, little-endian).
/// Why: Parse program headers to extract segment information.
const Elf64_Phdr = extern struct {
    /// Segment type (1 = PT_LOAD, 2 = PT_DYNAMIC, etc.).
    p_type: u32,
    /// Segment flags (read, write, execute).
    p_flags: u32,
    /// Segment file offset.
    p_offset: u64,
    /// Segment virtual address.
    p_vaddr: u64,
    /// Segment physical address (usually same as virtual).
    p_paddr: u64,
    /// Segment size in file.
    p_filesz: u64,
    /// Segment size in memory.
    p_memsz: u64,
    /// Segment alignment.
    p_align: u64,
};

/// ELF parser result.
/// Why: Return parsed ELF information for process setup.
pub const ElfInfo = struct {
    /// Entry point virtual address.
    /// Why: Set process PC to entry point.
    entry_point: u64,
    /// Whether ELF is valid.
    /// Why: Validate ELF format before using.
    valid: bool,
    /// Program header table offset.
    /// Why: Location of program headers for segment loading.
    phoff: u64,
    /// Program header entry size.
    /// Why: Size of each program header entry.
    phentsize: u16,
    /// Program header count.
    /// Why: Number of program headers.
    phnum: u16,
    
    /// Initialize empty ELF info.
    /// Why: Explicit initialization, clear state.
    pub fn init() ElfInfo {
        return ElfInfo{
            .entry_point = 0,
            .valid = false,
            .phoff = 0,
            .phentsize = 0,
            .phnum = 0,
        };
    }
};

/// Parse ELF header from memory buffer.
/// Why: Extract entry point and validate ELF format for process spawning.
/// Contract: buffer must be >= 64 bytes (ELF header size), buffer must be valid ELF format.
/// Returns: ElfInfo with entry point if valid, invalid ElfInfo otherwise.
/// Grain Style: Static allocation, no recursion, explicit types.
pub fn parse_elf_header(buffer: []const u8) ElfInfo {
    // Assert: Buffer must be non-empty (precondition).
    Debug.kassert(buffer.len > 0, "Buffer empty", .{});
    
    // Assert: Buffer must be >= ELF header size (64 bytes).
    const ELF_HEADER_SIZE: u32 = 64;
    if (buffer.len < ELF_HEADER_SIZE) {
        return ElfInfo.init(); // Invalid: too small
    }
    
    // Assert: Buffer must start with ELF magic number.
    if (buffer[0] != ELF_MAGIC[0] or buffer[1] != ELF_MAGIC[1] or 
        buffer[2] != ELF_MAGIC[2] or buffer[3] != ELF_MAGIC[3]) {
        return ElfInfo.init(); // Invalid: not ELF format
    }
    
    // Assert: ELF class must be 64-bit (byte 4 = 2).
    if (buffer[4] != 2) {
        return ElfInfo.init(); // Invalid: not 64-bit
    }
    
    // Assert: ELF endianness must be little-endian (byte 5 = 1).
    if (buffer[5] != 1) {
        return ElfInfo.init(); // Invalid: not little-endian
    }
    
    // Parse ELF header (requires alignment, but we can read fields directly).
    // Why: Extract entry point without requiring aligned buffer.
    // Note: e_entry is at offset 24 in ELF64 header.
    const ENTRY_POINT_OFFSET: u32 = 24;
    if (buffer.len < ENTRY_POINT_OFFSET + 8) {
        return ElfInfo.init(); // Invalid: buffer too small for entry point
    }
    
    // Read entry point (little-endian u64 at offset 24).
    var entry_point: u64 = 0;
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        const byte = buffer[ENTRY_POINT_OFFSET + i];
        entry_point |= (@as(u64, byte) << @as(u6, @intCast(i * 8)));
    }
    
    // Assert: Entry point must be non-zero (valid executable).
    if (entry_point == 0) {
        return ElfInfo.init(); // Invalid: zero entry point
    }
    
    // Assert: Entry point must be within reasonable range (not too high).
    const MAX_ENTRY_POINT: u64 = 0xFFFFFFFFFFFF; // 48-bit address space
    if (entry_point > MAX_ENTRY_POINT) {
        return ElfInfo.init(); // Invalid: entry point too large
    }
    
    // Read program header table offset (little-endian u64 at offset 32).
    // Why: Extract program header location for future segment loading.
    const PHOFF_OFFSET: u32 = 32;
    if (buffer.len < PHOFF_OFFSET + 8) {
        return ElfInfo.init(); // Invalid: buffer too small for phoff
    }
    
    var phoff: u64 = 0;
    i = 0;
    while (i < 8) : (i += 1) {
        const byte = buffer[PHOFF_OFFSET + i];
        phoff |= (@as(u64, byte) << @as(u6, @intCast(i * 8)));
    }
    
    // Read program header entry size (little-endian u16 at offset 54).
    // Why: Size of each program header entry.
    const PHENTSIZE_OFFSET: u32 = 54;
    if (buffer.len < PHENTSIZE_OFFSET + 2) {
        return ElfInfo.init(); // Invalid: buffer too small for phentsize
    }
    
    const phentsize: u16 = @as(u16, buffer[PHENTSIZE_OFFSET]) | (@as(u16, buffer[PHENTSIZE_OFFSET + 1]) << 8);
    
    // Read program header count (little-endian u16 at offset 56).
    // Why: Number of program headers.
    const PHNUM_OFFSET: u32 = 56;
    if (buffer.len < PHNUM_OFFSET + 2) {
        return ElfInfo.init(); // Invalid: buffer too small for phnum
    }
    
    const phnum: u16 = @as(u16, buffer[PHNUM_OFFSET]) | (@as(u16, buffer[PHNUM_OFFSET + 1]) << 8);
    
    // Assert: Program header entry size must be reasonable (56 bytes for ELF64).
    const ELF64_PHDR_SIZE: u16 = 56;
    if (phentsize != 0 and phentsize < ELF64_PHDR_SIZE) {
        return ElfInfo.init(); // Invalid: phentsize too small
    }
    
    // Assert: Program header count must be reasonable (max 128 segments).
    const MAX_PHDR_COUNT: u16 = 128;
    if (phnum > MAX_PHDR_COUNT) {
        return ElfInfo.init(); // Invalid: too many program headers
    }
    
    // Return valid ELF info with program header information.
    const info = ElfInfo{
        .entry_point = entry_point,
        .valid = true,
        .phoff = phoff,
        .phentsize = phentsize,
        .phnum = phnum,
    };
    
    // Assert: ELF info must be valid (postcondition).
    Debug.kassert(info.valid, "ELF info not valid", .{});
    Debug.kassert(info.entry_point != 0, "Entry point is zero", .{});
    
    return info;
}

/// Program segment information.
/// Why: Track segment details for loading into VM memory.
pub const ProgramSegment = struct {
    /// Segment type (1 = PT_LOAD, etc.).
    p_type: u32,
    /// Segment virtual address.
    p_vaddr: u64,
    /// Segment size in file.
    p_filesz: u64,
    /// Segment size in memory.
    p_memsz: u64,
    /// Segment flags (read, write, execute).
    p_flags: u32,
    /// Segment file offset.
    p_offset: u64,
    /// Segment alignment.
    p_align: u64,
    /// Whether segment is valid for loading.
    valid: bool,
    
    /// Initialize empty segment.
    /// Why: Explicit initialization, clear state.
    pub fn init() ProgramSegment {
        return ProgramSegment{
            .p_type = 0,
            .p_vaddr = 0,
            .p_filesz = 0,
            .p_memsz = 0,
            .p_flags = 0,
            .p_offset = 0,
            .p_align = 0,
            .valid = false,
        };
    }
};

/// Parse program header from memory buffer.
/// Why: Extract segment information for loading into VM memory.
/// Contract: buffer must be >= 56 bytes (ELF64 program header size), buffer must be valid program header.
/// Returns: ProgramSegment with segment info if valid, invalid ProgramSegment otherwise.
/// Grain Style: Static allocation, no recursion, explicit types.
pub fn parse_program_header(buffer: []const u8) ProgramSegment {
    // Assert: Buffer must be non-empty (precondition).
    Debug.kassert(buffer.len > 0, "Buffer empty", .{});
    
    // Assert: Buffer must be >= program header size (56 bytes for ELF64).
    const ELF64_PHDR_SIZE: u32 = 56;
    if (buffer.len < ELF64_PHDR_SIZE) {
        return ProgramSegment.init(); // Invalid: too small
    }
    
    // Read program header fields (little-endian).
    // p_type at offset 0 (u32)
    var p_type: u32 = 0;
    var i: u32 = 0;
    while (i < 4) : (i += 1) {
        const byte = buffer[i];
        p_type |= (@as(u32, byte) << @as(u5, @intCast(i * 8)));
    }
    
    // p_flags at offset 4 (u32)
    var p_flags: u32 = 0;
    i = 0;
    while (i < 4) : (i += 1) {
        const byte = buffer[4 + i];
        p_flags |= (@as(u32, byte) << @as(u5, @intCast(i * 8)));
    }
    
    // p_offset at offset 8 (u64)
    var p_offset: u64 = 0;
    i = 0;
    while (i < 8) : (i += 1) {
        const byte = buffer[8 + i];
        p_offset |= (@as(u64, byte) << @as(u6, @intCast(i * 8)));
    }
    
    // p_vaddr at offset 16 (u64)
    var p_vaddr: u64 = 0;
    i = 0;
    while (i < 8) : (i += 1) {
        const byte = buffer[16 + i];
        p_vaddr |= (@as(u64, byte) << @as(u6, @intCast(i * 8)));
    }
    
    // p_paddr at offset 24 (u64) - not used, but read for completeness
    _ = buffer[24..32];
    
    // p_filesz at offset 32 (u64)
    var p_filesz: u64 = 0;
    i = 0;
    while (i < 8) : (i += 1) {
        const byte = buffer[32 + i];
        p_filesz |= (@as(u64, byte) << @as(u6, @intCast(i * 8)));
    }
    
    // p_memsz at offset 40 (u64)
    var p_memsz: u64 = 0;
    i = 0;
    while (i < 8) : (i += 1) {
        const byte = buffer[40 + i];
        p_memsz |= (@as(u64, byte) << @as(u6, @intCast(i * 8)));
    }
    
    // p_align at offset 48 (u64)
    var p_align: u64 = 0;
    i = 0;
    while (i < 8) : (i += 1) {
        const byte = buffer[48 + i];
        p_align |= (@as(u64, byte) << @as(u6, @intCast(i * 8)));
    }
    
    // Validate segment.
    // Why: Ensure segment is valid for loading.
    const PT_LOAD: u32 = 1; // Loadable segment type
    if (p_type != PT_LOAD) {
        return ProgramSegment.init(); // Not a loadable segment
    }
    
    // Assert: Virtual address must be non-zero and reasonable.
    if (p_vaddr == 0) {
        return ProgramSegment.init(); // Invalid: zero virtual address
    }
    
    const MAX_VADDR: u64 = 0xFFFFFFFFFFFF; // 48-bit address space
    if (p_vaddr > MAX_VADDR) {
        return ProgramSegment.init(); // Invalid: virtual address too large
    }
    
    // Assert: Memory size must be >= file size.
    if (p_memsz < p_filesz) {
        return ProgramSegment.init(); // Invalid: memory size < file size
    }
    
    // Assert: Alignment must be power of 2 (if non-zero).
    if (p_align != 0) {
        // Check if p_align is power of 2.
        const is_power_of_2 = (p_align & (p_align - 1)) == 0;
        if (!is_power_of_2) {
            return ProgramSegment.init(); // Invalid: alignment not power of 2
        }
    }
    
    // Return valid program segment.
    const segment = ProgramSegment{
        .p_type = p_type,
        .p_vaddr = p_vaddr,
        .p_filesz = p_filesz,
        .p_memsz = p_memsz,
        .p_flags = p_flags,
        .p_offset = p_offset,
        .p_align = p_align,
        .valid = true,
    };
    
    // Assert: Segment must be valid (postcondition).
    Debug.kassert(segment.valid, "Segment not valid", .{});
    Debug.kassert(segment.p_type == PT_LOAD, "Segment type not PT_LOAD", .{});
    Debug.kassert(segment.p_vaddr != 0, "Virtual address is zero", .{});
    
    return segment;
}

