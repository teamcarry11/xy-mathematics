//! Tests for VM Debugging Interface System
//!
//! Objective: Verify debugging interface (breakpoints, watchpoints, step mode) works correctly.
//! Why: Ensure debugging capabilities accurately track breakpoints and watchpoints.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM debug interface initialization" {
    const debug = kernel_vm.debug_interface.VMDebugInterface.init();
    try testing.expect(debug.breakpoints_len == 0);
    try testing.expect(debug.watchpoints_len == 0);
    try testing.expect(debug.step_mode == false);
    try testing.expect(debug.breakpoint_hit == false);
    try testing.expect(debug.watchpoint_triggered == false);
}

test "VM debug interface set breakpoint" {
    var debug = kernel_vm.debug_interface.VMDebugInterface.init();
    const set = debug.set_breakpoint(0x80000000);
    try testing.expect(set == true);
    try testing.expect(debug.breakpoints_len == 1);
    try testing.expect(debug.breakpoints[0].pc == 0x80000000);
    try testing.expect(debug.breakpoints[0].enabled == true);
}

test "VM debug interface check breakpoint" {
    var debug = kernel_vm.debug_interface.VMDebugInterface.init();
    _ = debug.set_breakpoint(0x80000000);
    const hit = debug.check_breakpoint(0x80000000);
    try testing.expect(hit == true);
    try testing.expect(debug.breakpoint_hit == true);
    try testing.expect(debug.last_breakpoint_pc == 0x80000000);
}

test "VM debug interface remove breakpoint" {
    var debug = kernel_vm.debug_interface.VMDebugInterface.init();
    _ = debug.set_breakpoint(0x80000000);
    const removed = debug.remove_breakpoint(0x80000000);
    try testing.expect(removed == true);
    try testing.expect(debug.breakpoints[0].enabled == false);
    const hit = debug.check_breakpoint(0x80000000);
    try testing.expect(hit == false);
}

test "VM debug interface set watchpoint" {
    var debug = kernel_vm.debug_interface.VMDebugInterface.init();
    const set = debug.set_watchpoint(0x90000000, 8, true, true);
    try testing.expect(set == true);
    try testing.expect(debug.watchpoints_len == 1);
    try testing.expect(debug.watchpoints[0].address == 0x90000000);
    try testing.expect(debug.watchpoints[0].watch_reads == true);
    try testing.expect(debug.watchpoints[0].watch_writes == true);
}

test "VM debug interface check watchpoint read" {
    var debug = kernel_vm.debug_interface.VMDebugInterface.init();
    _ = debug.set_watchpoint(0x90000000, 8, true, false);
    const triggered = debug.check_watchpoint_read(0x90000000, 8);
    try testing.expect(triggered == true);
    try testing.expect(debug.watchpoint_triggered == true);
    try testing.expect(debug.last_watchpoint_addr == 0x90000000);
}

test "VM debug interface check watchpoint write" {
    var debug = kernel_vm.debug_interface.VMDebugInterface.init();
    _ = debug.set_watchpoint(0x90000000, 8, false, true);
    const triggered = debug.check_watchpoint_write(0x90000000, 8);
    try testing.expect(triggered == true);
    try testing.expect(debug.watchpoint_triggered == true);
}

test "VM debug interface step mode" {
    var debug = kernel_vm.debug_interface.VMDebugInterface.init();
    try testing.expect(debug.step_mode == false);
    debug.enable_step_mode();
    try testing.expect(debug.step_mode == true);
    debug.disable_step_mode();
    try testing.expect(debug.step_mode == false);
}

test "VM debug interface integration" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    try testing.expect(vm.debug_interface.breakpoints_len == 0);
    const set = vm.debug_interface.set_breakpoint(0x80000000);
    try testing.expect(set == true);
}

