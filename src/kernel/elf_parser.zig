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

/// ELF parser result.
/// Why: Return parsed ELF information for process setup.
pub const ElfInfo = struct {
    /// Entry point virtual address.
    /// Why: Set process PC to entry point.
    entry_point: u64,
    /// Whether ELF is valid.
    /// Why: Validate ELF format before using.
    valid: bool,
    
    /// Initialize empty ELF info.
    /// Why: Explicit initialization, clear state.
    pub fn init() ElfInfo {
        return ElfInfo{
            .entry_point = 0,
            .valid = false,
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
    
    // Return valid ELF info.
    const info = ElfInfo{
        .entry_point = entry_point,
        .valid = true,
    };
    
    // Assert: ELF info must be valid (postcondition).
    Debug.kassert(info.valid, "ELF info not valid", .{});
    Debug.kassert(info.entry_point != 0, "Entry point is zero", .{});
    
    return info;
}

