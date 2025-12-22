//! Interrupt and Exception Abstraction Test
//! Why: Verify unified interrupt and exception types work for both RISC-V and AArch64.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions.

const std = @import("std");
const testing = std.testing;
const Debug = @import("src/kernel/debug.zig");
const interrupt_types = @import("src/kernel/interrupt_types.zig");
const exception_types = @import("src/kernel/exception_types.zig");
const platform = @import("src/kernel/platform.zig");

test "interrupt_types_riscv_conversion" {
    // Test RISC-V to unified conversion.
    const software_unified = interrupt_types.riscv_to_unified(1);
    Debug.kassert(software_unified == .software, "Software interrupt mismatch", .{});
    
    const timer_unified = interrupt_types.riscv_to_unified(5);
    Debug.kassert(timer_unified == .timer, "Timer interrupt mismatch", .{});
    
    const external_unified = interrupt_types.riscv_to_unified(9);
    Debug.kassert(external_unified == .external, "External interrupt mismatch", .{});
    
    // Test unified to RISC-V conversion.
    const software_riscv = interrupt_types.unified_to_riscv(.software);
    try testing.expect(software_riscv == 1);
    
    const timer_riscv = interrupt_types.unified_to_riscv(.timer);
    try testing.expect(timer_riscv == 5);
    
    const external_riscv = interrupt_types.unified_to_riscv(.external);
    try testing.expect(external_riscv == 9);
}

test "interrupt_types_arch_conversion" {
    // Test architecture-agnostic conversion for RISC-V.
    const software_unified = interrupt_types.arch_to_unified(.riscv64, 1);
    Debug.kassert(software_unified == .software, "Software interrupt mismatch", .{});
    
    const timer_unified = interrupt_types.arch_to_unified(.riscv64, 5);
    Debug.kassert(timer_unified == .timer, "Timer interrupt mismatch", .{});
    
    const external_unified = interrupt_types.arch_to_unified(.riscv64, 9);
    Debug.kassert(external_unified == .external, "External interrupt mismatch", .{});
    
    // Test unified to architecture conversion for RISC-V.
    const software_riscv = interrupt_types.unified_to_arch(.riscv64, .software);
    try testing.expect(software_riscv == 1);
    
    const timer_riscv = interrupt_types.unified_to_arch(.riscv64, .timer);
    try testing.expect(timer_riscv == 5);
    
    const external_riscv = interrupt_types.unified_to_arch(.riscv64, .external);
    try testing.expect(external_riscv == 9);
}

test "exception_types_riscv_conversion" {
    // Test RISC-V to unified conversion.
    const illegal_unified = exception_types.riscv_to_unified(2);
    Debug.kassert(illegal_unified == .illegal_instruction, "Illegal instruction mismatch", .{});
    
    const breakpoint_unified = exception_types.riscv_to_unified(3);
    Debug.kassert(breakpoint_unified == .breakpoint, "Breakpoint mismatch", .{});
    
    const load_page_fault_unified = exception_types.riscv_to_unified(13);
    Debug.kassert(load_page_fault_unified == .load_page_fault, "Load page fault mismatch", .{});
    
    // Test unified to RISC-V conversion.
    const illegal_riscv = exception_types.unified_to_riscv(.illegal_instruction);
    try testing.expect(illegal_riscv == 2);
    
    const breakpoint_riscv = exception_types.unified_to_riscv(.breakpoint);
    try testing.expect(breakpoint_riscv == 3);
    
    const load_page_fault_riscv = exception_types.unified_to_riscv(.load_page_fault);
    try testing.expect(load_page_fault_riscv == 13);
}

test "exception_types_arch_conversion" {
    // Test architecture-agnostic conversion for RISC-V.
    const illegal_unified = exception_types.arch_to_unified(.riscv64, 2);
    Debug.kassert(illegal_unified == .illegal_instruction, "Illegal instruction mismatch", .{});
    
    const breakpoint_unified = exception_types.arch_to_unified(.riscv64, 3);
    Debug.kassert(breakpoint_unified == .breakpoint, "Breakpoint mismatch", .{});
    
    const load_page_fault_unified = exception_types.arch_to_unified(.riscv64, 13);
    Debug.kassert(load_page_fault_unified == .load_page_fault, "Load page fault mismatch", .{});
    
    // Test unified to architecture conversion for RISC-V.
    const illegal_riscv = exception_types.unified_to_arch(.riscv64, .illegal_instruction);
    try testing.expect(illegal_riscv == 2);
    
    const breakpoint_riscv = exception_types.unified_to_arch(.riscv64, .breakpoint);
    try testing.expect(breakpoint_riscv == 3);
    
    const load_page_fault_riscv = exception_types.unified_to_arch(.riscv64, .load_page_fault);
    try testing.expect(load_page_fault_riscv == 13);
}

test "interrupt_types_aarch64_placeholder" {
    // Test AArch64 conversion (placeholder).
    const timer_unified = interrupt_types.aarch64_to_unified(0);
    Debug.kassert(timer_unified == .timer, "Timer interrupt mismatch", .{});
    
    const timer_aarch64 = interrupt_types.unified_to_aarch64(.timer);
    try testing.expect(timer_aarch64 == 0);
}

test "exception_types_aarch64_placeholder" {
    // Test AArch64 conversion (placeholder).
    const illegal_unified = exception_types.aarch64_to_unified(0);
    Debug.kassert(illegal_unified == .illegal_instruction, "Illegal instruction mismatch", .{});
    
    const illegal_aarch64 = exception_types.unified_to_aarch64(.illegal_instruction);
    try testing.expect(illegal_aarch64 == 0);
}
