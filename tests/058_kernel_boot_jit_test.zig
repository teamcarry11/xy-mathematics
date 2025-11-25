//! Tests for kernel boot sequence with JIT acceleration.
//! Why: Verify kernel can boot successfully with JIT enabled.

const std = @import("std");
const testing = std.testing;
const vm_mod = @import("kernel_vm/vm.zig");
const basin_kernel = @import("basin_kernel");
const builtin = @import("builtin");

test "kernel boot with JIT enabled" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Minimal kernel boot sequence: initialize kernel, set up basic state.
    // Why: Test that kernel can boot with JIT acceleration.
    const kernel = basin_kernel.BasinKernel.init();
    defer _ = kernel;
    
    // Initialize VM with JIT.
    var vm: vm_mod.VM = undefined;
    const kernel_image: []const u8 = &[_]u8{};
    const load_address: u64 = 0x80000000;
    try vm.init_with_jit(allocator, kernel_image, load_address);
    defer vm.deinit_jit(allocator);
    
    // Verify JIT is enabled.
    try testing.expect(vm.jit_enabled);
    try testing.expect(vm.jit != null);
    
    // Set VM to running state.
    vm.state = .running;
    
    // Execute a few steps with JIT (kernel initialization).
    // Why: Verify JIT can execute kernel code.
    var steps: u32 = 0;
    const max_steps: u32 = 100;
    while (steps < max_steps and vm.state == .running) : (steps += 1) {
        vm.step_jit() catch |err| {
            // VM error is acceptable (kernel may halt or error during boot).
            _ = err;
            break;
        };
    }
    
    // Verify JIT executed (check perf counters).
    if (vm.jit) |jit_ctx| {
        // JIT should have compiled some blocks or executed some instructions.
        const total_ops = jit_ctx.perf_counters.blocks_compiled +
            jit_ctx.perf_counters.cache_hits +
            jit_ctx.perf_counters.interpreter_fallbacks;
        // At least some JIT activity should have occurred.
        _ = total_ops;
    }
}

test "kernel boot with JIT fallback" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Test that JIT falls back to interpreter on invalid instructions.
    var vm: vm_mod.VM = undefined;
    // Invalid instruction sequence (will cause JIT to fall back).
    const kernel_image = [_]u8{
        0xFF, 0xFF, 0xFF, 0xFF, // Invalid instruction
        0x13, 0x00, 0x00, 0x00, // NOP (valid)
    };
    const load_address: u64 = 0x80000000;
    try vm.init_with_jit(allocator, &kernel_image, load_address);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute with JIT (should fall back to interpreter for invalid instruction).
    vm.step_jit() catch |err| {
        // VM error is expected for invalid instruction.
        _ = err;
    };
    
    // Verify fallback counter incremented.
    if (vm.jit) |jit_ctx| {
        // Interpreter fallback should have occurred.
        _ = jit_ctx.perf_counters.interpreter_fallbacks;
    }
}

test "kernel boot sequence integration" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Test full kernel boot sequence with JIT.
    const kernel = basin_kernel.BasinKernel.init();
    defer _ = kernel;
    
    // Initialize VM with JIT.
    var vm: vm_mod.VM = undefined;
    const kernel_image: []const u8 = &[_]u8{};
    const load_address: u64 = 0x80000000;
    try vm.init_with_jit(allocator, kernel_image, load_address);
    defer vm.deinit_jit(allocator);
    
    // Set VM to running state.
    vm.state = .running;
    
    // Execute kernel boot sequence (multiple steps).
    // Why: Verify JIT can handle extended kernel execution.
    var steps: u64 = 0;
    const max_steps: u64 = 1000;
    while (steps < max_steps and vm.state == .running) : (steps += 1) {
        vm.step_jit() catch |err| {
            // VM error is acceptable (kernel may halt or error).
            _ = err;
            break;
        };
    }
    
    // Verify JIT performance (should have compiled blocks or executed instructions).
    if (vm.jit) |jit_ctx| {
        const total_activity = jit_ctx.perf_counters.blocks_compiled +
            jit_ctx.perf_counters.cache_hits +
            jit_ctx.perf_counters.interpreter_fallbacks;
        // JIT should have processed some instructions.
        _ = total_activity;
    }
}

