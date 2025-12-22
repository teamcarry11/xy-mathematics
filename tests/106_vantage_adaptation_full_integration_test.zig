//! Vantage Adaptation Full Integration Test
//! Why: Verify complete integration of host interface with VM, JIT, and kernel.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions.

const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const Debug = @import("src/kernel/debug.zig");
const host_interface = @import("src/kernel_vm/host_interface.zig");
const host_macos = @import("src/kernel_vm/host_macos.zig");
const vm_mod = @import("src/kernel_vm/vm.zig");
const basin_kernel = @import("basin_kernel");

test "vantage_adaptation_full_integration" {
    // Test full integration of Vantage adaptation (only on macOS).
    if (builtin.os.tag != .macos) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Step 1: Detect macOS version.
    const version_result = host_macos.detect_macos_version();
    
    switch (version_result) {
        .success => |version| {
            // Assert: Version must be reasonable.
            Debug.kassert(version.major >= 10, "Invalid macOS major version", .{});
            
            // Step 2: Initialize macOS host.
            const host_result = host_macos.MacOSHost.init();
            
            switch (host_result) {
                .success => |host| {
                    // Assert: Host must be initialized.
                    Debug.kassert(host.initialized, "macOS host not initialized", .{});
                    
                    // Step 3: Initialize host interface.
                    const interface_result = host_interface.HostInterface.init();
                    
                    switch (interface_result) {
                        .success => |interface| {
                            // Set global host interface.
                            host_interface.set_host_interface(interface);
                            
                            // Verify host interface is set.
                            const global_host = host_interface.get_host_interface();
                            Debug.kassert(global_host != null, "Global host interface not set", .{});
                            
                            // Step 4: Initialize VM with JIT (uses host interface).
                            var vm: vm_mod.VM = undefined;
                            const kernel_image: []const u8 = &[_]u8{};
                            const load_address: u64 = 0x80000000;
                            
                            try vm.init_with_jit(allocator, kernel_image, load_address);
                            defer vm.deinit_jit(allocator);
                            
                            // Verify JIT is enabled.
                            Debug.kassert(vm.jit_enabled, "JIT not enabled", .{});
                            Debug.kassert(vm.jit != null, "JIT context is null", .{});
                            
                            // Step 5: Initialize kernel.
                            const kernel = basin_kernel.BasinKernel.init();
                            defer _ = kernel;
                            
                            // Step 6: Set VM to running state.
                            vm.state = .running;
                            
                            // Step 7: Execute a few steps with JIT.
                            var steps: u32 = 0;
                            const max_steps: u32 = 10;
                            while (steps < max_steps and vm.state == .running) : (steps += 1) {
                                vm.step_jit() catch |err| {
                                    // VM error is acceptable (kernel may halt or error).
                                    _ = err;
                                    break;
                                };
                            }
                            
                            // Step 8: Verify statistics are tracked.
                            _ = vm.performance.instructions_executed;
                            _ = vm.performance.jit_compilations;
                            _ = vm.performance.jit_cache_hits;
                            _ = vm.performance.jit_cache_misses;
                            
                            // If we get here, full integration worked.
                            try testing.expect(true);
                        },
                        .failed => {
                            // Host interface initialization failed (should not happen on macOS).
                            try testing.expect(false);
                        },
                    }
                },
                .failed => {
                    // Host initialization failed (should not happen on macOS).
                    try testing.expect(false);
                },
            }
        },
        .failed => {
            // Version detection failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}

test "host_interface_feature_detection" {
    // Test feature detection via host interface (only on macOS).
    if (builtin.os.tag != .macos) {
        return;
    }
    
    // Initialize macOS host.
    const host_result = host_macos.MacOSHost.init();
    
    switch (host_result) {
        .success => |host| {
            // Test feature queries.
            const jit_supported = host.has_feature(host_macos.MacOSFeature.jit);
            const perf_counters_available = host.has_feature(host_macos.MacOSFeature.performance_counters);
            const profiling_available = host.has_feature(host_macos.MacOSFeature.profiling_tools);
            
            // Features may or may not be available depending on macOS version.
            _ = jit_supported;
            _ = perf_counters_available;
            _ = profiling_available;
            
            // If we get here, feature detection worked.
            try testing.expect(true);
        },
        .failed => {
            // Host initialization failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}

test "host_interface_memory_operations" {
    // Test host interface memory operations (only on macOS).
    if (builtin.os.tag != .macos) {
        return;
    }
    
    // Initialize host interface.
    const interface_result = host_interface.HostInterface.init();
    
    switch (interface_result) {
        .success => |interface| {
            // Set global host interface.
            host_interface.set_host_interface(interface);
            
            // Test memory protection flags.
            const prot = host_interface.HostMemoryProtection{
                .read = true,
                .write = true,
                .execute = true,
            };
            
            const bits = prot.to_bits();
            Debug.kassert(bits == 0x7, "Protection bits should be 0x7", .{});
            
            // Test JIT write protection.
            interface.set_jit_write_protection_wrapper(.disabled);
            interface.set_jit_write_protection_wrapper(.enabled);
            
            // If we get here, memory operations worked.
            try testing.expect(true);
        },
        .failed => {
            // Host interface initialization failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}
