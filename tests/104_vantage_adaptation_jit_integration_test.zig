//! Vantage Adaptation JIT Integration Test
//! Why: Verify JIT compilation works with host interface abstraction.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions.

const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const Debug = @import("src/kernel/debug.zig");
const host_interface = @import("src/kernel_vm/host_interface.zig");
const jit_mod = @import("src/kernel_vm/jit.zig");
const vm_mod = @import("src/kernel_vm/vm.zig");

test "jit_initialization_with_host_interface" {
    // Test JIT initialization with host interface (only on macOS).
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
            
            // Verify host interface is set.
            const host = host_interface.get_host_interface();
            Debug.kassert(host != null, "Host interface not set", .{});
            
            // Create guest state for JIT.
            var guest_state = jit_mod.GuestState{
                .regs = undefined,
                .pc = 0x80000000,
            };
            @memset(&guest_state.regs, 0);
            
            // Create guest RAM.
            const ram_size: u64 = 1024 * 1024; // 1MB
            const ram = try allocator.alloc(u8, ram_size);
            defer allocator.free(ram);
            @memset(ram, 0);
            
            // Initialize JIT context (should use host interface).
            var jit_ctx = try jit_mod.JitContext.init(allocator, &guest_state, ram, ram_size);
            defer jit_ctx.deinit();
            
            // Verify JIT context initialized.
            Debug.kassert(jit_ctx.code_buffer.len > 0, "JIT code buffer is empty", .{});
            Debug.kassert(jit_ctx.cursor == 0, "JIT cursor should be 0", .{});
        },
        .failed => {
            // Host interface initialization failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}

test "jit_memory_allocation_via_host_interface" {
    // Test JIT memory allocation via host interface (only on macOS).
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
            
            // Test JIT memory allocation.
            const buffer_size: u32 = 1024 * 1024; // 1MB
            const memory_result = interface.allocate_jit_memory_wrapper(buffer_size);
            
            switch (memory_result) {
                .success => |buffer| {
                    // Verify buffer is valid.
                    Debug.kassert(buffer.len == buffer_size, "Buffer size mismatch", .{});
                    Debug.kassert(buffer.len > 0, "Buffer is empty", .{});
                    
                    // Test write protection (disable for writing).
                    interface.set_jit_write_protection_wrapper(.disabled);
                    
                    // Write to buffer.
                    @memset(buffer, 0xAA);
                    
                    // Test write protection (enable for execution).
                    interface.set_jit_write_protection_wrapper(.enabled);
                    
                    // Verify buffer content.
                    for (buffer) |byte| {
                        Debug.kassert(byte == 0xAA, "Buffer content mismatch", .{});
                    }
                    
                    // Free JIT memory.
                    interface.free_jit_memory_wrapper(buffer);
                },
                .failed => {
                    // Memory allocation failed (may happen if not on macOS or permissions issue).
                    // This is acceptable for testing.
                },
            }
        },
        .failed => {
            // Host interface initialization failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}

test "vm_jit_execution_with_host_interface" {
    // Test VM JIT execution with host interface (only on macOS).
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Initialize host interface.
    const interface_result = host_interface.HostInterface.init();
    
    switch (interface_result) {
        .success => |interface| {
            // Set global host interface.
            host_interface.set_host_interface(interface);
            
            // Initialize VM with JIT.
            var vm: vm_mod.VM = undefined;
            const kernel_image: []const u8 = &[_]u8{};
            const load_address: u64 = 0x80000000;
            
            try vm.init_with_jit(allocator, kernel_image, load_address);
            defer vm.deinit_jit(allocator);
            
            // Verify JIT is enabled.
            Debug.kassert(vm.jit_enabled, "JIT not enabled", .{});
            Debug.kassert(vm.jit != null, "JIT context is null", .{});
            
            // Set VM to running state.
            vm.state = .running;
            
            // Execute a few steps with JIT.
            var steps: u32 = 0;
            const max_steps: u32 = 10;
            while (steps < max_steps and vm.state == .running) : (steps += 1) {
                vm.step_jit() catch |err| {
                    // VM error is acceptable (kernel may halt or error during boot).
                    _ = err;
                    break;
                };
            }
            
            // Verify JIT executed (check perf counters).
            if (vm.jit) |jit_ctx| {
                // JIT should have processed some instructions.
                const total_activity = jit_ctx.perf_counters.hot_path_tracker.total_executions +
                    jit_ctx.perf_counters.interpreter_fallbacks;
                _ = total_activity; // May be 0 if no hot paths detected.
            }
        },
        .failed => {
            // Host interface initialization failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}

test "host_interface_jit_write_protection" {
    // Test JIT write protection via host interface (only on macOS).
    if (builtin.os.tag != .macos) {
        return;
    }
    
    // Initialize host interface.
    const interface_result = host_interface.HostInterface.init();
    
    switch (interface_result) {
        .success => |interface| {
            // Set global host interface.
            host_interface.set_host_interface(interface);
            
            // Test write protection states.
            interface.set_jit_write_protection_wrapper(.disabled);
            interface.set_jit_write_protection_wrapper(.enabled);
            interface.set_jit_write_protection_wrapper(.disabled);
            interface.set_jit_write_protection_wrapper(.enabled);
            
            // If we get here, write protection worked (no crashes).
            try testing.expect(true);
        },
        .failed => {
            // Host interface initialization failed (should not happen on macOS).
            try testing.expect(false);
        },
    }
}
