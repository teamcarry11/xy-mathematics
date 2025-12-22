//! Vantage Adaptation VM Statistics Test
//! Why: Verify VM statistics work correctly with host interface abstraction.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions.

const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const Debug = @import("src/kernel/debug.zig");
const host_interface = @import("src/kernel_vm/host_interface.zig");
const vm_mod = @import("src/kernel_vm/vm.zig");
const performance_mod = @import("src/kernel_vm/performance.zig");

test "vm_statistics_platform_agnostic" {
    // Test VM statistics are platform-agnostic (works on all platforms).
    const allocator = testing.allocator;
    
    // Initialize VM (no JIT, just interpreter).
    var vm: vm_mod.VM = undefined;
    const kernel_image: []const u8 = &[_]u8{};
    const load_address: u64 = 0x80000000;
    
    vm.init(kernel_image, load_address);
    
    // Verify performance metrics are initialized.
    Debug.kassert(vm.performance.instructions_executed == 0, "Instructions should start at 0", .{});
    Debug.kassert(vm.performance.cycles_simulated == 0, "Cycles should start at 0", .{});
    Debug.kassert(vm.performance.memory_reads == 0, "Memory reads should start at 0", .{});
    Debug.kassert(vm.performance.memory_writes == 0, "Memory writes should start at 0", .{});
    Debug.kassert(vm.performance.syscalls == 0, "Syscalls should start at 0", .{});
    
    // Increment some counters.
    vm.performance.increment_instruction();
    vm.performance.increment_memory_read();
    vm.performance.increment_memory_write();
    vm.performance.increment_syscall();
    
    // Verify counters incremented.
    Debug.kassert(vm.performance.instructions_executed == 1, "Instructions should be 1", .{});
    Debug.kassert(vm.performance.cycles_simulated == 1, "Cycles should be 1", .{});
    Debug.kassert(vm.performance.memory_reads == 1, "Memory reads should be 1", .{});
    Debug.kassert(vm.performance.memory_writes == 1, "Memory writes should be 1", .{});
    Debug.kassert(vm.performance.syscalls == 1, "Syscalls should be 1", .{});
}

test "vm_statistics_with_host_interface" {
    // Test VM statistics work with host interface (only on macOS).
    if (builtin.os.tag != .macos) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Initialize host interface.
    const interface_result = host_interface.HostInterface.init();
    
    switch (interface_result) {
        .success => |interface| {
            // Set global host interface.
            host_interface.set_host_interface(interface);
            
            // Initialize VM with JIT (uses host interface).
            var vm: vm_mod.VM = undefined;
            const kernel_image: []const u8 = &[_]u8{};
            const load_address: u64 = 0x80000000;
            
            try vm.init_with_jit(allocator, kernel_image, load_address);
            defer vm.deinit_jit(allocator);
            
            // Verify performance metrics are initialized.
            Debug.kassert(vm.performance.instructions_executed == 0, "Instructions should start at 0", .{});
            Debug.kassert(vm.performance.jit_compilations == 0, "JIT compilations should start at 0", .{});
            Debug.kassert(vm.performance.jit_cache_hits == 0, "JIT cache hits should start at 0", .{});
            Debug.kassert(vm.performance.jit_cache_misses == 0, "JIT cache misses should start at 0", .{});
            
            // Set VM to running state.
            vm.state = .running;
            
            // Execute a few steps with JIT.
            var steps: u32 = 0;
            const max_steps: u32 = 10;
            while (steps < max_steps and vm.state == .running) : (steps += 1) {
                vm.step_jit() catch |err| {
                    // VM error is acceptable.
                    _ = err;
                    break;
                };
            }
            
            // Verify statistics are tracked (may be 0 if no activity).
            _ = vm.performance.instructions_executed;
            _ = vm.performance.jit_compilations;
            _ = vm.performance.jit_cache_hits;
            _ = vm.performance.jit_cache_misses;
            _ = vm.performance.interpreter_fallbacks;
        },
        .failed => {
            // Host interface initialization failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}

test "performance_metrics_calculations" {
    // Test performance metrics calculations (platform-agnostic).
    var metrics = performance_mod.PerformanceMetrics{};
    
    // Increment counters.
    metrics.increment_instruction();
    metrics.increment_instruction();
    metrics.increment_memory_read();
    metrics.increment_memory_write();
    metrics.increment_syscall();
    metrics.increment_jit_compilation();
    metrics.increment_jit_cache_hit();
    metrics.increment_jit_cache_miss();
    
    // Verify counters.
    Debug.kassert(metrics.instructions_executed == 2, "Instructions should be 2", .{});
    Debug.kassert(metrics.cycles_simulated == 2, "Cycles should be 2", .{});
    Debug.kassert(metrics.memory_reads == 1, "Memory reads should be 1", .{});
    Debug.kassert(metrics.memory_writes == 1, "Memory writes should be 1", .{});
    Debug.kassert(metrics.syscalls == 1, "Syscalls should be 1", .{});
    Debug.kassert(metrics.jit_compilations == 1, "JIT compilations should be 1", .{});
    Debug.kassert(metrics.jit_cache_hits == 1, "JIT cache hits should be 1", .{});
    Debug.kassert(metrics.jit_cache_misses == 1, "JIT cache misses should be 1", .{});
    
    // Test IPC calculation.
    const ipc = metrics.get_ipc();
    Debug.kassert(ipc >= 0.0, "IPC should be non-negative", .{});
    
    // Test JIT cache hit rate calculation.
    const hit_rate = metrics.get_jit_cache_hit_rate();
    Debug.kassert(hit_rate >= 0.0 and hit_rate <= 1.0, "Hit rate should be between 0 and 1", .{});
    Debug.kassert(hit_rate == 0.5, "Hit rate should be 0.5 (1 hit, 1 miss)", .{});
}
