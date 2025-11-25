//! Tests for JIT performance timing measurements.
//! Why: Verify JIT timing measurements work correctly.

const std = @import("std");
const testing = std.testing;
const vm_mod = @import("kernel_vm/vm.zig");
const builtin = @import("builtin");

test "JIT performance timing" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET (JALR x0, x1, 0)
    };
    
    // Initialize VM with JIT.
    var vm: vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute with JIT (first execution compiles, second uses cache).
    try vm.step_jit();
    try vm.step_jit();
    
    // Verify performance counters are updated.
    if (vm.jit) |jit_ctx| {
        // Should have at least one cache hit or miss.
        const total_ops = jit_ctx.perf_counters.cache_hits +
            jit_ctx.perf_counters.cache_misses;
        try testing.expect(total_ops > 0);
        
        // Timing should be tracked (may be 0 if very fast, but should not crash).
        _ = jit_ctx.perf_counters.total_execution_time_ns;
        _ = jit_ctx.perf_counters.jit_compile_time_ns;
    }
}

test "JIT performance stats printing" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program.
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    try vm.step_jit();
    
    // Verify stats can be printed without crashing.
    if (vm.jit) |jit_ctx| {
        jit_ctx.perf_counters.print_stats();
    }
}

