//! JIT-Accelerated VM Usage Example
//!
//! Objective: Demonstrate JIT-accelerated VM usage.
//! Why: Show how to use JIT for 10x+ performance improvement.
//! GrainStyle: Explicit types, comprehensive assertions, deterministic behavior.
//!
//! This example demonstrates:
//! - JIT initialization
//! - JIT-accelerated execution
//! - Performance comparison
//! - JIT statistics
//!
//! Date: 2025-01-XX
//! GrainStyle: Complete example, well-documented, follows TigerStyle principles

const std = @import("std");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    std.debug.print("=== Grain Vantage JIT Usage Example ===\n", .{});
    
    // Create program: Loop that increments x1
    const program = [_]u8{
        0x93, 0x80, 0x10, 0x00, // ADDI x1, x1, 1
        0x6F, 0xFF, 0xDF, 0xFF, // JAL x0, -4 (loop back)
    };
    
    // Example 1: Initialize VM with JIT
    std.debug.print("\n1. Initializing VM with JIT...\n", .{});
    var vm: VM = undefined;
    try VM.init_with_jit(&vm, allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    // Assert: JIT must be enabled.
    std.debug.assert(vm.jit_enabled);
    std.debug.print("   JIT enabled: {}\n", .{vm.jit_enabled});
    
    // Example 2: Execute with JIT
    std.debug.print("\n2. Executing with JIT...\n", .{});
    vm.start();
    
    // Execute multiple instructions (JIT will compile hot paths)
    const EXECUTION_STEPS: u32 = 100;
    var step_count: u32 = 0;
    while (step_count < EXECUTION_STEPS and vm.state == .running) : (step_count += 1) {
        vm.step_jit() catch |err| {
            std.debug.print("   Error: {}\n", .{err});
            break;
        };
    }
    
    std.debug.print("   Executed {} steps\n", .{step_count});
    std.debug.print("   Register x1 = {}\n", .{vm.regs.get(1)});
    
    // Example 3: Performance metrics
    std.debug.print("\n3. Performance metrics...\n", .{});
    vm.print_performance();
    
    // Example 4: JIT statistics (if available)
    if (vm.jit) |jit_ctx| {
        std.debug.print("\n4. JIT statistics...\n", .{});
        jit_ctx.perf_counters.print_stats();
    }
    
    std.debug.print("\n=== Example Complete ===\n", .{});
}

