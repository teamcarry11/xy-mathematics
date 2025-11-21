//! Basic VM Usage Example
//!
//! Objective: Demonstrate basic VM usage patterns.
//! Why: Provide reference implementation for common VM operations.
//! GrainStyle: Explicit types, comprehensive assertions, deterministic behavior.
//!
//! This example demonstrates:
//! - VM initialization
//! - Instruction execution
//! - Memory access
//! - Performance monitoring
//! - Error handling
//!
//! Date: 2025-01-XX
//! GrainStyle: Complete example, well-documented, follows TigerStyle principles

const std = @import("std");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    std.debug.print("=== Grain Vantage Basic Usage Example ===\n", .{});
    
    // Example 1: Initialize VM with simple program
    std.debug.print("\n1. Initializing VM...\n", .{});
    var vm: VM = undefined;
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x13, 0x00, 0x00, 0x00, // ADDI x0, x0, 0 (NOP)
    };
    VM.init(&vm, &program, 0x80000000);
    
    // Assert: VM must be in halted state after initialization.
    std.debug.assert(vm.state == .halted);
    std.debug.print("   VM initialized, PC = 0x{x}\n", .{vm.regs.pc});
    
    // Example 2: Start VM and execute instructions
    std.debug.print("\n2. Executing instructions...\n", .{});
    vm.start();
    
    // Execute first instruction (ADDI x1, x0, 42)
    vm.step() catch |err| {
        std.debug.print("   Error: {}\n", .{err});
        return;
    };
    
    // Assert: Register x1 must be set to 42.
    std.debug.assert(vm.regs.get(1) == 42);
    std.debug.print("   Executed ADDI x1, x0, 42, x1 = {}\n", .{vm.regs.get(1)});
    
    // Execute second instruction (NOP)
    vm.step() catch |err| {
        std.debug.print("   Error: {}\n", .{err});
        return;
    };
    
    std.debug.print("   Executed NOP, PC = 0x{x}\n", .{vm.regs.pc});
    
    // Example 3: Memory access
    std.debug.print("\n3. Memory access...\n", .{});
    const test_addr: u64 = 0x80000000;
    const test_value: u64 = 0x1234567890ABCDEF;
    
    // Write to memory
    vm.write64(test_addr, test_value) catch |err| {
        std.debug.print("   Write error: {}\n", .{err});
        return;
    };
    std.debug.print("   Wrote 0x{x} to address 0x{x}\n", .{ test_value, test_addr });
    
    // Read from memory
    const read_value = vm.read64(test_addr) catch |err| {
        std.debug.print("   Read error: {}\n", .{err});
        return;
    };
    std.debug.print("   Read 0x{x} from address 0x{x}\n", .{ read_value, test_addr });
    
    // Assert: Read value must match written value.
    std.debug.assert(read_value == test_value);
    
    // Example 4: Performance monitoring
    std.debug.print("\n4. Performance metrics...\n", .{});
    vm.print_performance();
    
    // Example 5: Diagnostics
    std.debug.print("\n5. Diagnostics snapshot...\n", .{});
    const diagnostics = vm.get_diagnostics();
    diagnostics.print();
    
    std.debug.print("\n=== Example Complete ===\n", .{});
}

