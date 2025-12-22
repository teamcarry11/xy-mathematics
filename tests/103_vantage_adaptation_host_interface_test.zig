//! Vantage Adaptation Host Interface Test
//! Why: Verify host interface abstraction works for macOS adaptation.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions.

const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const Debug = @import("src/kernel/debug.zig");
const host_macos = @import("src/kernel_vm/host_macos.zig");
const host_interface = @import("src/kernel_vm/host_interface.zig");

test "macos_version_detection" {
    // Test macOS version detection (only on macOS).
    if (builtin.os.tag != .macos) {
        return;
    }
    
    const version_result = host_macos.detect_macos_version();
    
    switch (version_result) {
        .success => |version| {
            // Assert: Version must be reasonable.
            Debug.kassert(version.major >= 10, "Invalid macOS major version", .{});
            Debug.kassert(version.minor >= 0, "Invalid macOS minor version", .{});
            Debug.kassert(version.patch >= 0, "Invalid macOS patch version", .{});
        },
        .failed => {
            // Detection failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}

test "macos_host_initialization" {
    // Test macOS host initialization (only on macOS).
    if (builtin.os.tag != .macos) {
        return;
    }
    
    const host_result = host_macos.MacOSHost.init();
    
    switch (host_result) {
        .success => |host| {
            // Assert: Host must be initialized.
            Debug.kassert(host.initialized, "macOS host not initialized", .{});
            
            // Assert: Version must be reasonable.
            Debug.kassert(host.version.major >= 10, "Invalid macOS major version", .{});
            
            // Test feature flags.
            const jit_supported = host.has_feature(.jit);
            _ = jit_supported; // Feature may or may not be available.
        },
        .failed => {
            // Initialization failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}

test "host_interface_initialization" {
    // Test host interface initialization (only on macOS).
    if (builtin.os.tag != .macos) {
        return;
    }
    
    const interface_result = host_interface.HostInterface.init();
    
    switch (interface_result) {
        .success => |interface| {
            // Assert: Interface must be initialized.
            Debug.kassert(interface.initialized, "Host interface not initialized", .{});
        },
        .failed => {
            // Initialization failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}

test "host_memory_protection_flags" {
    // Test memory protection flags conversion.
    const prot = host_interface.HostMemoryProtection{
        .read = true,
        .write = true,
        .execute = true,
    };
    
    const bits = prot.to_bits();
    try testing.expect(bits == 0x7); // 0x1 | 0x2 | 0x4
    
    const prot2 = host_interface.HostMemoryProtection.from_bits(0x7);
    try testing.expect(prot2.read == true);
    try testing.expect(prot2.write == true);
    try testing.expect(prot2.execute == true);
}

test "host_jit_write_protection" {
    // Test JIT write protection enum.
    const enabled = host_interface.HostJitWriteProtection.enabled;
    const disabled = host_interface.HostJitWriteProtection.disabled;
    
    try testing.expect(@intFromEnum(enabled) == 0);
    try testing.expect(@intFromEnum(disabled) == 1);
}
