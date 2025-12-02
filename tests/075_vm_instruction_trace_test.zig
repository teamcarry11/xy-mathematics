//! Tests for VM Instruction Trace Logging System
//!
//! Objective: Verify instruction trace logging works correctly.
//! Why: Ensure instruction trace accurately records instruction execution history.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM instruction trace initialization" {
    const trace = kernel_vm.instruction_trace.VMInstructionTrace.init();
    try testing.expect(trace.enabled == false);
    try testing.expect(trace.trace_count == 0);
    try testing.expect(trace.trace_index == 0);
}

test "VM instruction trace enable/disable" {
    var trace = kernel_vm.instruction_trace.VMInstructionTrace.init();
    try testing.expect(trace.enabled == false);
    trace.enable();
    try testing.expect(trace.enabled == true);
    trace.disable();
    try testing.expect(trace.enabled == false);
}

test "VM instruction trace filter" {
    var trace = kernel_vm.instruction_trace.VMInstructionTrace.init();
    trace.enable();
    trace.set_filter(0x80000000, 0x80001000);
    try testing.expect(trace.should_trace(0x80000000) == true);
    try testing.expect(trace.should_trace(0x80000500) == true);
    try testing.expect(trace.should_trace(0x80001000) == true);
    try testing.expect(trace.should_trace(0x7FFFFFFF) == false);
    try testing.expect(trace.should_trace(0x80001001) == false);
    trace.clear_filter();
    try testing.expect(trace.should_trace(0x80000000) == true);
}

test "VM instruction trace record instruction" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var trace = kernel_vm_mod.instruction_trace.VMInstructionTrace.init();
    trace.enable();
    trace.record_instruction(&vm, 0x80000000, 0x00000013);
    try testing.expect(trace.trace_count == 1);
    const entry_opt = trace.get_trace_entry(0);
    try testing.expect(entry_opt != null);
    if (entry_opt) |entry| {
        try testing.expect(entry.pc == 0x80000000);
        try testing.expect(entry.instruction == 0x00000013);
    }
}

test "VM instruction trace record memory read" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var trace = kernel_vm_mod.instruction_trace.VMInstructionTrace.init();
    trace.enable();
    trace.record_instruction(&vm, 0x80000000, 0x00000013);
    trace.record_memory_read(0x90000000, 0x12345678);
    const entry_opt = trace.get_trace_entry(0);
    try testing.expect(entry_opt != null);
    if (entry_opt) |entry| {
        try testing.expect(entry.memory_read_addr != null);
        if (entry.memory_read_addr) |addr| {
            try testing.expect(addr == 0x90000000);
            try testing.expect(entry.memory_read_value.? == 0x12345678);
        }
    }
}

test "VM instruction trace record memory write" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var trace = kernel_vm_mod.instruction_trace.VMInstructionTrace.init();
    trace.enable();
    trace.record_instruction(&vm, 0x80000000, 0x00000013);
    trace.record_memory_write(0x90000000, 0x12345678);
    const entry_opt = trace.get_trace_entry(0);
    try testing.expect(entry_opt != null);
    if (entry_opt) |entry| {
        try testing.expect(entry.memory_write_addr != null);
        if (entry.memory_write_addr) |addr| {
            try testing.expect(addr == 0x90000000);
            try testing.expect(entry.memory_write_value.? == 0x12345678);
        }
    }
}

test "VM instruction trace circular buffer" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var trace = kernel_vm_mod.instruction_trace.VMInstructionTrace.init();
    trace.enable();
    var i: u32 = 0;
    while (i < 1500) : (i += 1) {
        trace.record_instruction(&vm, 0x80000000 + i * 4, 0x00000013);
    }
    try testing.expect(trace.trace_count == kernel_vm_mod.instruction_trace.MAX_TRACE_ENTRIES);
}

test "VM instruction trace clear" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var trace = kernel_vm_mod.instruction_trace.VMInstructionTrace.init();
    trace.enable();
    trace.record_instruction(&vm, 0x80000000, 0x00000013);
    try testing.expect(trace.trace_count == 1);
    trace.clear_trace();
    try testing.expect(trace.trace_count == 0);
}

