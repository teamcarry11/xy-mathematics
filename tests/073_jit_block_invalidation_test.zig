//! Tests for JIT block invalidation functionality.
//! Why: Verify JIT compiler can invalidate and recompile blocks.

const std = @import("std");
const testing = std.testing;
const kernel_vm_mod = @import("kernel_vm");
const builtin = @import("builtin");

test "JIT block invalidation" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program.
    const program = [_]u8{
        0x93, 0x00, 0x10, 0x00, // ADDI x1, x0, 1
        0x93, 0x00, 0x20, 0x00, // ADDI x2, x0, 2
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute to compile block.
    try vm.step_jit();
    
    // Verify block is compiled.
    if (vm.jit) |jit_ctx| {
        const initial_blocks = jit_ctx.perf_counters.blocks_compiled;
        try testing.expect(initial_blocks > 0);
        
        // Invalidate the block.
        jit_ctx.invalidate_block(0x80000000);
        
        // Verify invalidation counter increased.
        try testing.expect(jit_ctx.perf_counters.blocks_invalidated > 0);
        
        // Execute again - should recompile.
        try vm.step_jit();
        
        // Should have compiled again.
        try testing.expect(jit_ctx.perf_counters.blocks_compiled > initial_blocks);
    }
}

test "JIT invalidate all blocks" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program.
    const program = [_]u8{
        0x93, 0x00, 0x10, 0x00, // ADDI x1, x0, 1
        0x93, 0x00, 0x20, 0x00, // ADDI x2, x0, 2
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute to compile blocks.
    try vm.step_jit();
    try vm.step_jit();
    
    // Verify blocks are compiled.
    if (vm.jit) |jit_ctx| {
        const initial_blocks = jit_ctx.perf_counters.blocks_compiled;
        try testing.expect(initial_blocks > 0);
        
        // Invalidate all blocks.
        jit_ctx.invalidate_all_blocks();
        
        // Verify invalidation counters increased.
        try testing.expect(jit_ctx.perf_counters.cache_invalidations > 0);
        try testing.expect(jit_ctx.perf_counters.blocks_invalidated > 0);
        
        // Execute again - should recompile.
        try vm.step_jit();
        
        // Should have compiled again.
        try testing.expect(jit_ctx.perf_counters.blocks_compiled > initial_blocks);
    }
}

test "JIT invalidation statistics" {
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
    
    // Execute and invalidate.
    try vm.step_jit();
    
    // Verify statistics can be printed without crashing.
    if (vm.jit) |jit_ctx| {
        jit_ctx.invalidate_block(0x80000000);
        jit_ctx.perf_counters.print_stats();
        
        // Statistics should be accessible.
        _ = jit_ctx.perf_counters.blocks_invalidated;
        _ = jit_ctx.perf_counters.cache_invalidations;
    }
}

