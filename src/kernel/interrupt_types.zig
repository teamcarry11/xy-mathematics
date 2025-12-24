//! Unified Interrupt Types
//! Why: Abstract interrupt types for RISC-V and AArch64 kernels.
//! Grain Style: Minimal, type-safe, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const platform = @import("platform.zig");

/// Unified interrupt type (architecture-agnostic).
/// Why: Abstract interrupt types across RISC-V and AArch64.
pub const InterruptType = enum(u32) {
    /// Software interrupt (from other cores or software).
    software = 0,
    /// Timer interrupt (from platform timer or hardware timer).
    timer = 1,
    /// External interrupt (from devices, keyboard, mouse, etc.).
    external = 2,
};

/// RISC-V interrupt ID to unified interrupt type conversion.
/// Why: Map RISC-V-specific interrupt IDs to unified types.
/// Contract: riscv_id must be valid RISC-V interrupt ID.
pub fn riscv_to_unified(riscv_id: u32) InterruptType {
    // Assert: RISC-V interrupt ID must be valid.
    Debug.kassert(
        riscv_id == 1 or riscv_id == 5 or riscv_id == 9,
        "Invalid RISC-V interrupt ID",
        .{},
    );
    
    // Map RISC-V interrupt IDs to unified types.
    return switch (riscv_id) {
        1 => .software,  // RISC-V software interrupt
        5 => .timer,     // RISC-V timer interrupt
        9 => .external,  // RISC-V external interrupt
        else => unreachable,
    };
}

/// Unified interrupt type to RISC-V interrupt ID conversion.
/// Why: Map unified types to RISC-V-specific interrupt IDs.
/// Contract: interrupt_type must be valid.
pub fn unified_to_riscv(interrupt_type: InterruptType) u32 {
    // Map unified types to RISC-V interrupt IDs.
    return switch (interrupt_type) {
        .software => 1,  // RISC-V software interrupt
        .timer => 5,     // RISC-V timer interrupt
        .external => 9,  // RISC-V external interrupt
    };
}

/// AArch64 interrupt ID to unified interrupt type conversion.
/// Why: Map AArch64-specific interrupt IDs to unified types.
/// Contract: aarch64_id must be valid AArch64 interrupt ID.
/// Note: AArch64 uses GIC (Generic Interrupt Controller):
///       - SGI (Software Generated Interrupt): 0-15
///       - PPI (Private Peripheral Interrupt): 16-31 (timer: 27-30)
///       - SPI (Shared Peripheral Interrupt): 32-1019
pub fn aarch64_to_unified(aarch64_id: u32) InterruptType {
    // Assert: AArch64 interrupt ID must be valid (within GIC range).
    // Note: GIC supports up to 1020 interrupts (0-1019).
    if (aarch64_id > 1019) {
        Debug.kprint("kernel: invalid AArch64 interrupt ID {d}, mapping to external\n", .{aarch64_id});
        return .external;
    }
    
    // Map AArch64 interrupt IDs to unified types.
    return if (aarch64_id < 16) {
        // SGI (Software Generated Interrupt): 0-15
        .software
    } else if (aarch64_id >= 27 and aarch64_id <= 30) {
        // PPI Timer interrupts: 27-30
        .timer
    } else {
        // PPI/SPI External interrupts: 16-26, 31, 32-1019
        .external
    };
}

/// Unified interrupt type to AArch64 interrupt ID conversion.
/// Why: Map unified types to AArch64-specific interrupt IDs.
/// Contract: interrupt_type must be valid.
/// Note: Returns canonical AArch64 interrupt IDs:
///       - Software: 0 (SGI)
///       - Timer: 27 (PPI timer)
///       - External: 32 (SPI base)
pub fn unified_to_aarch64(interrupt_type: InterruptType) u32 {
    // Map unified types to canonical AArch64 interrupt IDs.
    return switch (interrupt_type) {
        .software => 0,   // SGI base
        .timer => 27,     // PPI timer
        .external => 32,  // SPI base
    };
}

/// Convert architecture-specific interrupt ID to unified type.
/// Why: Platform-agnostic interrupt ID conversion.
/// Contract: arch must be valid, interrupt_id must be valid for architecture.
pub fn arch_to_unified(arch: platform.PlatformArch, interrupt_id: u32) InterruptType {
    // Assert: Architecture must be valid.
    Debug.kassert(
        arch == .riscv64 or arch == .aarch64,
        "Invalid platform architecture",
        .{},
    );
    
    // Convert based on architecture.
    return switch (arch) {
        .riscv64 => riscv_to_unified(interrupt_id),
        .aarch64 => aarch64_to_unified(interrupt_id),
    };
}

/// Convert unified interrupt type to architecture-specific ID.
/// Why: Platform-agnostic interrupt ID conversion.
/// Contract: arch must be valid, interrupt_type must be valid.
pub fn unified_to_arch(arch: platform.PlatformArch, interrupt_type: InterruptType) u32 {
    // Assert: Architecture must be valid.
    Debug.kassert(
        arch == .riscv64 or arch == .aarch64,
        "Invalid platform architecture",
        .{},
    );
    
    // Convert based on architecture.
    return switch (arch) {
        .riscv64 => unified_to_riscv(interrupt_type),
        .aarch64 => unified_to_aarch64(interrupt_type),
    };
}
