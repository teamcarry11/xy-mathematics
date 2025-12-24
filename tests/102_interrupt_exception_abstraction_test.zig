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

test "interrupt_types_aarch64_conversion" {
    // Test AArch64 to unified conversion.
    const software_unified = interrupt_types.aarch64_to_unified(0);
    Debug.kassert(software_unified == .software, "Software interrupt mismatch", .{});
    
    const timer_unified = interrupt_types.aarch64_to_unified(27);
    Debug.kassert(timer_unified == .timer, "Timer interrupt mismatch", .{});
    
    const external_unified = interrupt_types.aarch64_to_unified(32);
    Debug.kassert(external_unified == .external, "External interrupt mismatch", .{});
    
    // Test unified to AArch64 conversion.
    const software_aarch64 = interrupt_types.unified_to_aarch64(.software);
    try testing.expect(software_aarch64 == 0);
    
    const timer_aarch64 = interrupt_types.unified_to_aarch64(.timer);
    try testing.expect(timer_aarch64 == 27);
    
    const external_aarch64 = interrupt_types.unified_to_aarch64(.external);
    try testing.expect(external_aarch64 == 32);
}

test "interrupt_types_aarch64_arch_conversion" {
    // Test architecture-agnostic conversion for AArch64.
    const software_unified = interrupt_types.arch_to_unified(.aarch64, 0);
    Debug.kassert(software_unified == .software, "Software interrupt mismatch", .{});
    
    const timer_unified = interrupt_types.arch_to_unified(.aarch64, 27);
    Debug.kassert(timer_unified == .timer, "Timer interrupt mismatch", .{});
    
    const external_unified = interrupt_types.arch_to_unified(.aarch64, 32);
    Debug.kassert(external_unified == .external, "External interrupt mismatch", .{});
    
    // Test unified to architecture conversion for AArch64.
    const software_aarch64 = interrupt_types.unified_to_arch(.aarch64, .software);
    try testing.expect(software_aarch64 == 0);
    
    const timer_aarch64 = interrupt_types.unified_to_arch(.aarch64, .timer);
    try testing.expect(timer_aarch64 == 27);
    
    const external_aarch64 = interrupt_types.unified_to_arch(.aarch64, .external);
    try testing.expect(external_aarch64 == 32);
}

test "exception_types_aarch64_conversion" {
    // Test AArch64 to unified conversion (ESR_ELx format).
    // SVC (syscall): EC = 0x15
    const svc_esr: u32 = 0x15 << 26;
    const svc_unified = exception_types.aarch64_to_unified(svc_esr);
    Debug.kassert(svc_unified == .environment_call_from_u_mode, "SVC mismatch", .{});
    
    // Breakpoint: EC = 0x30
    const brk_esr: u32 = 0x30 << 26;
    const brk_unified = exception_types.aarch64_to_unified(brk_esr);
    Debug.kassert(brk_unified == .breakpoint, "Breakpoint mismatch", .{});
    
    // Data abort (read): EC = 0x25, WnR = 0
    const data_abort_read_esr: u32 = 0x25 << 26;
    const data_abort_read_unified = exception_types.aarch64_to_unified(data_abort_read_esr);
    Debug.kassert(data_abort_read_unified == .load_page_fault, "Data abort read mismatch", .{});
    
    // Data abort (write): EC = 0x25, WnR = 1
    const data_abort_write_esr: u32 = (0x25 << 26) | (1 << 6);
    const data_abort_write_unified = exception_types.aarch64_to_unified(data_abort_write_esr);
    Debug.kassert(data_abort_write_unified == .store_page_fault, "Data abort write mismatch", .{});
    
    // Test unified to AArch64 conversion.
    const svc_aarch64 = exception_types.unified_to_aarch64(.environment_call_from_u_mode);
    try testing.expect(svc_aarch64 == (0x15 << 26));
    
    const brk_aarch64 = exception_types.unified_to_aarch64(.breakpoint);
    try testing.expect(brk_aarch64 == (0x30 << 26));
    
    const load_page_fault_aarch64 = exception_types.unified_to_aarch64(.load_page_fault);
    try testing.expect(load_page_fault_aarch64 == (0x25 << 26));
    
    const store_page_fault_aarch64 = exception_types.unified_to_aarch64(.store_page_fault);
    try testing.expect(store_page_fault_aarch64 == ((0x25 << 26) | (1 << 6)));
}

test "exception_types_aarch64_arch_conversion" {
    // Test architecture-agnostic conversion for AArch64.
    const svc_esr: u32 = 0x15 << 26;
    const svc_unified = exception_types.arch_to_unified(.aarch64, svc_esr);
    Debug.kassert(svc_unified == .environment_call_from_u_mode, "SVC mismatch", .{});
    
    const brk_esr: u32 = 0x30 << 26;
    const brk_unified = exception_types.arch_to_unified(.aarch64, brk_esr);
    Debug.kassert(brk_unified == .breakpoint, "Breakpoint mismatch", .{});
    
    // Test unified to architecture conversion for AArch64.
    const svc_aarch64 = exception_types.unified_to_arch(.aarch64, .environment_call_from_u_mode);
    try testing.expect(svc_aarch64 == (0x15 << 26));
    
    const brk_aarch64 = exception_types.unified_to_arch(.aarch64, .breakpoint);
    try testing.expect(brk_aarch64 == (0x30 << 26));
}
