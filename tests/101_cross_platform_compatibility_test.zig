//! Cross-Platform Compatibility Test
//! Why: Verify platform abstraction works for both RISC-V and AArch64.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions.

const std = @import("std");
const testing = std.testing;
const Debug = @import("src/kernel/debug.zig");
const platform = @import("src/kernel/platform.zig");
const platform_riscv = @import("src/kernel/platform_riscv.zig");
const platform_aarch64 = @import("src/kernel/platform_aarch64.zig");

test "platform_riscv_init" {
    // Initialize RISC-V platform.
    const riscv_platform = platform.Platform.init(
        .riscv64,
        platform_riscv.platform_call_riscv,
        platform_riscv.get_time_ns,
    );
    
    // Assert: Platform must be initialized.
    Debug.kassert(riscv_platform.initialized, "RISC-V platform not initialized", .{});
    
    // Assert: Architecture must be RISC-V64.
    Debug.kassert(
        riscv_platform.arch == .riscv64,
        "Platform architecture mismatch",
        .{},
    );
    
    // Assert: Platform call function must be set.
    Debug.kassert(
        riscv_platform.platform_call_fn != null,
        "Platform call function not set",
        .{},
    );
    
    // Assert: Time source function must be set.
    Debug.kassert(
        riscv_platform.time_source_fn != null,
        "Time source function not set",
        .{},
    );
}

test "platform_aarch64_init" {
    // Initialize AArch64 platform.
    const aarch64_platform = platform.Platform.init(
        .aarch64,
        platform_aarch64.platform_call,
        platform_aarch64.get_time_ns,
    );
    
    // Assert: Platform must be initialized.
    Debug.kassert(
        aarch64_platform.initialized,
        "AArch64 platform not initialized",
        .{},
    );
    
    // Assert: Architecture must be AArch64.
    Debug.kassert(
        aarch64_platform.arch == .aarch64,
        "Platform architecture mismatch",
        .{},
    );
    
    // Assert: Platform call function must be set.
    Debug.kassert(
        aarch64_platform.platform_call_fn != null,
        "Platform call function not set",
        .{},
    );
    
    // Assert: Time source function must be set.
    Debug.kassert(
        aarch64_platform.time_source_fn != null,
        "Time source function not set",
        .{},
    );
}

test "platform_riscv_console_putchar" {
    // Initialize RISC-V platform.
    const riscv_platform = platform.Platform.init(
        .riscv64,
        platform_riscv.platform_call_riscv,
        platform_riscv.get_time_ns,
    );
    
    // Test console putchar (should not crash).
    riscv_platform.console_putchar('A');
    
    // Assert: Platform must remain initialized.
    Debug.kassert(riscv_platform.initialized, "Platform not initialized", .{});
}

test "platform_aarch64_console_putchar" {
    // Initialize AArch64 platform.
    const aarch64_platform = platform.Platform.init(
        .aarch64,
        platform_aarch64.platform_call,
        platform_aarch64.get_time_ns,
    );
    
    // Test console putchar (should not crash).
    aarch64_platform.console_putchar('A');
    
    // Assert: Platform must remain initialized.
    Debug.kassert(aarch64_platform.initialized, "Platform not initialized", .{});
}

/// Test platform time source for RISC-V.
/// Why: Verify RISC-V time source works via platform abstraction.
test "platform_riscv_get_time_ns" {
    // Initialize RISC-V platform.
    const riscv_platform = platform.Platform.init(
        .riscv64,
        platform_riscv.platform_call_riscv,
        platform_riscv.get_time_ns,
    );
    
    // Get time from platform.
    const time_ns = riscv_platform.get_time_ns();
    
    // Assert: Time must be reasonable (not zero, not before year 2000).
    const YEAR_2000_NS: u64 = 946684800 * 1000000000; // Jan 1, 2000
    Debug.kassert(time_ns >= YEAR_2000_NS, "Time before year 2000", .{});
    
    // Assert: Platform must remain initialized.
    Debug.kassert(riscv_platform.initialized, "Platform not initialized", .{});
}

/// Test platform time source for AArch64.
/// Why: Verify AArch64 time source works via platform abstraction.
test "platform_aarch64_get_time_ns" {
    // Initialize AArch64 platform.
    const aarch64_platform = platform.Platform.init(
        .aarch64,
        platform_aarch64.platform_call,
        platform_aarch64.get_time_ns,
    );
    
    // Get time from platform.
    const time_ns = aarch64_platform.get_time_ns();
    
    // Assert: Time must be reasonable (not zero, not before year 2000).
    const YEAR_2000_NS: u64 = 946684800 * 1000000000; // Jan 1, 2000
    Debug.kassert(time_ns >= YEAR_2000_NS, "Time before year 2000", .{});
    
    // Assert: Platform must remain initialized.
    Debug.kassert(aarch64_platform.initialized, "Platform not initialized", .{});
}

/// Test global platform instance.
/// Why: Verify global platform instance works correctly.
test "platform_global_instance" {
    // Initialize RISC-V platform.
    const riscv_platform = platform.Platform.init(
        .riscv64,
        platform_riscv.platform_call_riscv,
        platform_riscv.get_time_ns,
    );
    
    // Set global platform instance.
    platform.set_platform(riscv_platform);
    
    // Get global platform instance.
    const global_platform = platform.get_platform();
    
    // Assert: Global platform must be initialized.
    Debug.kassert(global_platform.initialized, "Global platform not initialized", .{});
    
    // Assert: Architecture must match.
    Debug.kassert(
        global_platform.arch == .riscv64,
        "Global platform architecture mismatch",
        .{},
    );
}
