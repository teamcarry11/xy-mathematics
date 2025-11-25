//! Tests for JIT code size tracking.
//! Why: Verify code size tracking works correctly.

const std = @import("std");
const testing = std.testing;
const jit_mod = @import("kernel_vm/jit.zig");
const vm_mod = @import("kernel_vm/vm.zig");
const builtin = @import("builtin");

test "JIT code size tracking initialization" {
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
    
    // Verify initial code size is zero.
    if (vm.jit) |jit_ctx| {
        try testing.expect(jit_ctx.perf_counters.total_code_size_bytes == 0);
        try testing.expect(jit_ctx.perf_counters.max_code_size_bytes == 0);
        try testing.expect(jit_ctx.perf_counters.min_code_size_bytes == 0);
    }
}

test "JIT code size tracking after compilation" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM with JIT.
    var vm: vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute to trigger compilation.
    try vm.step_jit();
    
    // Verify code size is tracked.
    if (vm.jit) |jit_ctx| {
        try testing.expect(jit_ctx.perf_counters.total_code_size_bytes > 0);
        try testing.expect(jit_ctx.perf_counters.max_code_size_bytes > 0);
        try testing.expect(jit_ctx.perf_counters.min_code_size_bytes > 0);
        try testing.expect(jit_ctx.perf_counters.blocks_compiled > 0);
    }
}

test "JIT code size tracking multiple blocks" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Program with multiple instructions.
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x93, 0x00, 0xB0, 0x03, // ADDI x2, x0, 43
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM with JIT.
    var vm: vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute multiple times to compile multiple blocks.
    try vm.step_jit();
    try vm.step_jit();
    
    // Verify code size tracking.
    if (vm.jit) |jit_ctx| {
        try testing.expect(jit_ctx.perf_counters.total_code_size_bytes > 0);
        try testing.expect(jit_ctx.perf_counters.blocks_compiled > 0);
        // Total code size should be sum of all blocks.
        const avg_size = jit_ctx.perf_counters.total_code_size_bytes / jit_ctx.perf_counters.blocks_compiled;
        try testing.expect(avg_size > 0);
    }
}

test "JIT code size stats printing" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    try vm.step_jit();
    
    // Verify code size stats can be printed.
    if (vm.jit) |jit_ctx| {
        jit_ctx.perf_counters.print_stats();
    }
}

