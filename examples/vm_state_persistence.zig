//! VM State Persistence Example
//!
//! Objective: Demonstrate VM state save and restore functionality.
//! Why: Show how to use state persistence for debugging and testing.
//! GrainStyle: Explicit types, comprehensive assertions, deterministic behavior.
//!
//! This example demonstrates:
//! - Saving VM state
//! - Restoring VM state
//! - Resuming execution from checkpoint
//!
//! Date: 2025-01-XX
//! GrainStyle: Complete example, well-documented, follows TigerStyle principles

const std = @import("std");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;

// VM memory size constant.
const VM_MEMORY_SIZE: u64 = 8 * 1024 * 1024; // 8MB

pub fn main() !void {
    std.debug.print("=== Grain Vantage State Persistence Example ===\n", .{});
    
    // Create program
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x93, 0x80, 0x10, 0x00, // ADDI x1, x1, 1
        0x13, 0x00, 0x00, 0x00, // ADDI x0, x0, 0 (NOP)
    };
    
    // Example 1: Initialize VM and execute some instructions
    std.debug.print("\n1. Initializing VM and executing...\n", .{});
    var vm: VM = undefined;
    VM.init(&vm, &program, 0x80000000);
    
    vm.start();
    vm.step() catch |err| {
        std.debug.print("   Error: {}\n", .{err});
        return;
    }
    
    std.debug.print("   After first instruction, x1 = {}\n", .{vm.regs.get(1)});
    
    // Example 2: Save VM state
    std.debug.print("\n2. Saving VM state...\n", .{});
    var memory_buffer: [VM_MEMORY_SIZE]u8 = undefined;
    const snapshot = try vm.save_state(&memory_buffer);
    
    // Assert: Snapshot must be valid.
    std.debug.assert(snapshot.is_valid());
    std.debug.print("   Snapshot saved, PC = 0x{x}, x1 = {}\n", .{ snapshot.regs[32], snapshot.regs[1] });
    
    // Example 3: Continue execution
    std.debug.print("\n3. Continuing execution...\n", .{});
    vm.step() catch |err| {
        std.debug.print("   Error: {}\n", .{err});
        return;
    }
    
    std.debug.print("   After second instruction, x1 = {}\n", .{vm.regs.get(1)});
    
    // Example 4: Restore state
    std.debug.print("\n4. Restoring VM state...\n", .{});
    try vm.restore_state(&snapshot);
    
    std.debug.print("   State restored, PC = 0x{x}, x1 = {}\n", .{ vm.regs.pc, vm.regs.get(1) });
    
    // Assert: State must be restored correctly.
    std.debug.assert(vm.regs.get(1) == snapshot.regs[1]);
    std.debug.assert(vm.regs.pc == snapshot.regs[32]);
    
    // Example 5: Resume execution from checkpoint
    std.debug.print("\n5. Resuming execution from checkpoint...\n", .{});
    vm.step() catch |err| {
        std.debug.print("   Error: {}\n", .{err});
        return;
    }
    
    std.debug.print("   After resume, x1 = {}\n", .{vm.regs.get(1)});
    
    std.debug.print("\n=== Example Complete ===\n", .{});
}

