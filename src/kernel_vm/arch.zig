//! Architecture Abstraction Layer
//! Why: Support multiple architectures (RISC-V64, AArch64) with unified interface.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");

/// Target architecture.
/// Why: Specify which architecture to emulate.
pub const Architecture = enum(u8) {
    riscv64 = 0,
    aarch64 = 1,
};

/// Architecture-specific register file interface.
/// Why: Abstract register operations across architectures.
pub const RegisterFileInterface = struct {
    /// Get register value.
    /// Why: Read register value (architecture-specific).
    /// Contract: reg_index must be valid for architecture.
    get: *const fn (self: *anyopaque, reg_index: u8) u64,
    
    /// Set register value.
    /// Why: Write register value (architecture-specific).
    /// Contract: reg_index must be valid for architecture.
    set: *const fn (self: *anyopaque, reg_index: u8, value: u64) void,
    
    /// Get program counter.
    /// Why: Read program counter (architecture-specific).
    get_pc: *const fn (self: *anyopaque) u64,
    
    /// Set program counter.
    /// Why: Write program counter (architecture-specific).
    set_pc: *const fn (self: *anyopaque, value: u64) void,
    
    /// Get number of registers.
    /// Why: Query register count (architecture-specific).
    get_register_count: *const fn (self: *anyopaque) u8,
};

/// Architecture-specific memory interface.
/// Why: Abstract memory operations across architectures.
pub const MemoryInterface = struct {
    /// Read memory at address (8 bytes).
    /// Why: Read memory (architecture-specific endianness/alignment).
    /// Contract: addr must be valid, aligned.
    read64: *const fn (self: *anyopaque, addr: u64) anyerror!u64,
    
    /// Write memory at address (8 bytes).
    /// Why: Write memory (architecture-specific endianness/alignment).
    /// Contract: addr must be valid, aligned.
    write64: *const fn (self: *anyopaque, addr: u64, value: u64) anyerror!void,
    
    /// Get memory size.
    /// Why: Query memory size (architecture-specific).
    get_memory_size: *const fn (self: *anyopaque) u64,
};

/// Architecture-specific instruction decoder interface.
/// Why: Abstract instruction decoding across architectures.
pub const InstructionDecoderInterface = struct {
    /// Decode instruction.
    /// Why: Decode instruction (architecture-specific).
    /// Contract: instruction must be valid for architecture.
    decode: *const fn (self: *anyopaque, instruction: u32) anyerror!void,
    
    /// Get instruction length.
    /// Why: Query instruction length (architecture-specific).
    /// Contract: Returns instruction length in bytes (4 for RISC-V, 4 for AArch64).
    get_instruction_length: *const fn (self: *anyopaque) u32,
};

/// Architecture configuration.
/// Why: Store architecture-specific configuration.
pub const ArchConfig = struct {
    /// Target architecture.
    arch: Architecture,
    
    /// Memory size in bytes.
    memory_size: u64,
    
    /// Instruction length in bytes (4 for RISC-V, 4 for AArch64).
    instruction_length: u32,
    
    /// Register count (32 for RISC-V, 31 for AArch64).
    register_count: u8,
    
    /// Initialize architecture configuration.
    /// Why: Set up architecture-specific defaults.
    pub fn init(arch: Architecture) ArchConfig {
        return switch (arch) {
            .riscv64 => ArchConfig{
                .arch = .riscv64,
                .memory_size = 8 * 1024 * 1024, // 8MB default
                .instruction_length = 4,
                .register_count = 32,
            },
            .aarch64 => ArchConfig{
                .arch = .aarch64,
                .memory_size = 8 * 1024 * 1024, // 8MB default
                .instruction_length = 4,
                .register_count = 31, // AArch64 has 31 general-purpose registers (x0-x30)
            },
        };
    }
    
    /// Validate architecture configuration.
    /// Why: Ensure configuration is valid.
    pub fn is_valid(self: *const ArchConfig) bool {
        // Assert: Memory size must be reasonable (1MB to 1GB).
        if (self.memory_size < 1024 * 1024 or self.memory_size > 1024 * 1024 * 1024) {
            return false;
        }
        
        // Assert: Instruction length must be valid (4 bytes for both architectures).
        if (self.instruction_length != 4) {
            return false;
        }
        
        // Assert: Register count must be valid.
        if (self.register_count == 0 or self.register_count > 32) {
            return false;
        }
        
        return true;
    }
};

/// Get architecture name.
/// Why: Human-readable architecture name.
pub fn get_arch_name(arch: Architecture) []const u8 {
    return switch (arch) {
        .riscv64 => "RISC-V64",
        .aarch64 => "AArch64",
    };
}

/// Check if architecture is supported.
/// Why: Validate architecture support.
pub fn is_arch_supported(arch: Architecture) bool {
    _ = arch;
    // Both architectures are supported.
    return true;
}

