//! Tests for JIT compilation threshold functionality.
//! Why: Verify JIT compiler only compiles blocks that meet execution threshold.

const std = @import("std");
const testing = std.testing;
const kernel_vm_mod = @import("kernel_vm");
const builtin = @import("builtin");

test "JIT compilation threshold disabled (compile immediately)" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program.
    const program = [_]u8{
        0x93, 0x00, 0x10, 0x00, // ADDI x1, x0, 1
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // With threshold 0 (default), should compile immediately.
    if (vm.jit) |jit_ctx| {
        try testing.expect(jit_ctx.compilation_threshold == 0);
        
        // Execute - should compile immediately.
        try vm.step_jit();
        
        // Should have compiled.
        try testing.expect(jit_ctx.perf_counters.blocks_compiled > 0);
    }
}

test "JIT compilation threshold enabled" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program.
    const program = [_]u8{
        0x93, 0x00, 0x10, 0x00, // ADDI x1, x0, 1
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Set threshold to 3 executions.
    if (vm.jit) |jit_ctx| {
        jit_ctx.set_compilation_threshold(3);
        try testing.expect(jit_ctx.compilation_threshold == 3);
        
        // Execute first time - should not compile (threshold not met).
        try vm.step_jit();
        const blocks_before = jit_ctx.perf_counters.blocks_compiled;
        try testing.expect(blocks_before == 0);
        try testing.expect(jit_ctx.perf_counters.threshold_deferred > 0);
        
        // Execute second time - should not compile yet.
        try vm.step_jit();
        try testing.expect(jit_ctx.perf_counters.blocks_compiled == blocks_before);
        
        // Execute third time - should compile now (threshold met).
        try vm.step_jit();
        try testing.expect(jit_ctx.perf_counters.blocks_compiled > blocks_before);
    }
}

test "JIT compilation threshold statistics" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program.
    const program = [_]u8{
        0x93, 0x00, 0x10, 0x00, // ADDI x1, x0, 1
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Set threshold and execute.
    if (vm.jit) |jit_ctx| {
        jit_ctx.set_compilation_threshold(2);
        try vm.step_jit();
        
        // Verify statistics can be printed without crashing.
        jit_ctx.perf_counters.print_stats();
        
        // Statistics should be accessible.
        _ = jit_ctx.perf_counters.threshold_deferred;
    }
}

