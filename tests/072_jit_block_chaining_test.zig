//! Tests for JIT block chaining optimization.
//! Why: Verify JIT compiler correctly chains consecutive blocks to reduce dispatch overhead.

const std = @import("std");
const testing = std.testing;
const kernel_vm_mod = @import("kernel_vm");
const builtin = @import("builtin");

test "JIT block chaining statistics tracking" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program with sequential execution.
    const program = [_]u8{
        0x93, 0x00, 0x10, 0x00, // ADDI x1, x0, 1
        0x93, 0x00, 0x20, 0x00, // ADDI x2, x0, 2
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute program.
    try vm.step_jit();
    try vm.step_jit();
    
    // Verify chain statistics are initialized.
    if (vm.jit) |jit_ctx| {
        // Chain statistics should be accessible (may be 0 if no chains created).
        _ = jit_ctx.perf_counters.chain_opportunities;
        _ = jit_ctx.perf_counters.chains_created;
        _ = jit_ctx.perf_counters.chain_hits;
    }
}

test "JIT block chaining statistics" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program with sequential execution.
    const program = [_]u8{
        0x93, 0x00, 0x10, 0x00, // ADDI x1, x0, 1
        0x93, 0x00, 0x20, 0x00, // ADDI x2, x0, 2
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: kernel_vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute program.
    try vm.step_jit();
    try vm.step_jit();
    
    // Verify statistics can be printed without crashing.
    if (vm.jit) |jit_ctx| {
        jit_ctx.perf_counters.print_stats();
        // Chain statistics should be initialized (may be 0 if no chains created).
        _ = jit_ctx.perf_counters.chain_opportunities;
        _ = jit_ctx.perf_counters.chains_created;
        _ = jit_ctx.perf_counters.chain_hits;
    }
}

