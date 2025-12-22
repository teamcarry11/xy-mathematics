//! Unified Exception Types
//! Why: Abstract exception types for RISC-V and AArch64 kernels.
//! Grain Style: Minimal, type-safe, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const platform = @import("platform.zig");

/// Unified exception type (architecture-agnostic).
/// Why: Abstract exception types across RISC-V and AArch64.
pub const ExceptionType = enum(u32) {
    /// Instruction address misaligned.
    instruction_address_misaligned = 0,
    /// Instruction access fault.
    instruction_access_fault = 1,
    /// Illegal instruction.
    illegal_instruction = 2,
    /// Breakpoint.
    breakpoint = 3,
    /// Load address misaligned.
    load_address_misaligned = 4,
    /// Load access fault.
    load_access_fault = 5,
    /// Store/AMO address misaligned.
    store_address_misaligned = 6,
    /// Store/AMO access fault.
    store_access_fault = 7,
    /// Environment call from U-mode (syscall).
    environment_call_from_u_mode = 8,
    /// Environment call from S-mode (syscall).
    environment_call_from_s_mode = 9,
    /// Instruction page fault.
    instruction_page_fault = 12,
    /// Load page fault.
    load_page_fault = 13,
    /// Store/AMO page fault.
    store_page_fault = 15,
};

/// RISC-V exception code to unified exception type conversion.
/// Why: Map RISC-V-specific exception codes to unified types.
/// Contract: riscv_code must be valid RISC-V exception code.
pub fn riscv_to_unified(riscv_code: u32) ExceptionType {
    // Assert: RISC-V exception code must be valid.
    Debug.kassert(riscv_code < 16, "Invalid RISC-V exception code", .{});
    
    // Map RISC-V exception codes to unified types.
    return switch (riscv_code) {
        0 => .instruction_address_misaligned,
        1 => .instruction_access_fault,
        2 => .illegal_instruction,
        3 => .breakpoint,
        4 => .load_address_misaligned,
        5 => .load_access_fault,
        6 => .store_address_misaligned,
        7 => .store_access_fault,
        8 => .environment_call_from_u_mode,
        9 => .environment_call_from_s_mode,
        12 => .instruction_page_fault,
        13 => .load_page_fault,
        15 => .store_page_fault,
        else => {
            // Unknown RISC-V exception code: map to illegal instruction.
            Debug.kprint("kernel: unknown RISC-V exception code {d}, mapping to illegal_instruction\n", .{riscv_code});
            return .illegal_instruction;
        },
    };
}

/// Unified exception type to RISC-V exception code conversion.
/// Why: Map unified types to RISC-V-specific exception codes.
/// Contract: exception_type must be valid.
pub fn unified_to_riscv(exception_type: ExceptionType) u32 {
    // Map unified types to RISC-V exception codes.
    return switch (exception_type) {
        .instruction_address_misaligned => 0,
        .instruction_access_fault => 1,
        .illegal_instruction => 2,
        .breakpoint => 3,
        .load_address_misaligned => 4,
        .load_access_fault => 5,
        .store_address_misaligned => 6,
        .store_access_fault => 7,
        .environment_call_from_u_mode => 8,
        .environment_call_from_s_mode => 9,
        .instruction_page_fault => 12,
        .load_page_fault => 13,
        .store_page_fault => 15,
    };
}

/// AArch64 exception code to unified exception type conversion.
/// Why: Map AArch64-specific exception codes to unified types.
/// Contract: aarch64_code must be valid AArch64 exception code.
/// Note: AArch64 exception codes are architecture-specific (ESR_ELx, etc.).
///       This is a placeholder for future AArch64 exception support.
pub fn aarch64_to_unified(aarch64_code: u32) ExceptionType {
    // Assert: AArch64 exception code must be valid (placeholder).
    // Note: Actual AArch64 exception codes will be defined when AArch64
    //       exception handling is implemented.
    _ = aarch64_code;
    
    // Placeholder: Return illegal instruction for now.
    // TODO: Implement proper AArch64 exception code mapping.
    return .illegal_instruction;
}

/// Unified exception type to AArch64 exception code conversion.
/// Why: Map unified types to AArch64-specific exception codes.
/// Contract: exception_type must be valid.
/// Note: This is a placeholder for future AArch64 exception support.
pub fn unified_to_aarch64(exception_type: ExceptionType) u32 {
    // Placeholder: Return 0 for now.
    // TODO: Implement proper AArch64 exception code mapping.
    _ = exception_type;
    return 0;
}

/// Convert architecture-specific exception code to unified type.
/// Why: Platform-agnostic exception code conversion.
/// Contract: arch must be valid, exception_code must be valid for architecture.
pub fn arch_to_unified(arch: platform.PlatformArch, exception_code: u32) ExceptionType {
    // Assert: Architecture must be valid.
    Debug.kassert(
        arch == .riscv64 or arch == .aarch64,
        "Invalid platform architecture",
        .{},
    );
    
    // Convert based on architecture.
    return switch (arch) {
        .riscv64 => riscv_to_unified(exception_code),
        .aarch64 => aarch64_to_unified(exception_code),
    };
}

/// Convert unified exception type to architecture-specific code.
/// Why: Platform-agnostic exception code conversion.
/// Contract: arch must be valid, exception_type must be valid.
pub fn unified_to_arch(arch: platform.PlatformArch, exception_type: ExceptionType) u32 {
    // Assert: Architecture must be valid.
    Debug.kassert(
        arch == .riscv64 or arch == .aarch64,
        "Invalid platform architecture",
        .{},
    );
    
    // Convert based on architecture.
    return switch (arch) {
        .riscv64 => unified_to_riscv(exception_type),
        .aarch64 => unified_to_aarch64(exception_type),
    };
}
