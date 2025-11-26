//! Tests for VM Debugging Command Interface
//!
//! Objective: Verify unified debugging command interface works correctly.
//! Why: Ensure debugging command interface accurately combines all debugging features.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM debug command initialization" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var debug_cmd = kernel_vm_mod.debug_command.VMDebugCommand.init(&vm);
    const pc = debug_cmd.get_pc();
    try testing.expect(pc == 0x80000000);
}

test "VM debug command set breakpoint" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var debug_cmd = kernel_vm_mod.debug_command.VMDebugCommand.init(&vm);
    const set = debug_cmd.set_breakpoint(0x80000000);
    try testing.expect(set == true);
}

test "VM debug command set watchpoint" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var debug_cmd = kernel_vm_mod.debug_command.VMDebugCommand.init(&vm);
    const set = debug_cmd.set_watchpoint(0x90000000, 8, true, true);
    try testing.expect(set == true);
}

test "VM debug command continue execution" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var debug_cmd = kernel_vm_mod.debug_command.VMDebugCommand.init(&vm);
    debug_cmd.continue_execution();
    try testing.expect(debug_cmd.execution_controller.state == .running);
}

test "VM debug command step over" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var debug_cmd = kernel_vm_mod.debug_command.VMDebugCommand.init(&vm);
    debug_cmd.step_over();
    try testing.expect(debug_cmd.execution_controller.state == .stepping_over);
}

test "VM debug command step into" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var debug_cmd = kernel_vm_mod.debug_command.VMDebugCommand.init(&vm);
    debug_cmd.step_into();
    try testing.expect(debug_cmd.execution_controller.state == .stepping_into);
}

test "VM debug command get register" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    vm.regs.set(5, 0x12345678);
    var debug_cmd = kernel_vm_mod.debug_command.VMDebugCommand.init(&vm);
    const reg5 = debug_cmd.get_register(5);
    try testing.expect(reg5 == 0x12345678);
}

test "VM debug command dump memory" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    program[0] = 0x12;
    program[1] = 0x34;
    program[2] = 0x56;
    program[3] = 0x78;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var debug_cmd = kernel_vm_mod.debug_command.VMDebugCommand.init(&vm);
    const dump = debug_cmd.dump_memory(0, 4);
    try testing.expect(dump != null);
    if (dump) |d| {
        try testing.expect(d.data[0] == 0x12);
        try testing.expect(d.data[1] == 0x34);
        try testing.expect(d.data[2] == 0x56);
        try testing.expect(d.data[3] == 0x78);
    }
}

test "VM debug command read memory" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    program[0] = 0x78;
    program[1] = 0x56;
    program[2] = 0x34;
    program[3] = 0x12;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var debug_cmd = kernel_vm_mod.debug_command.VMDebugCommand.init(&vm);
    const value = debug_cmd.read_memory_u32(0);
    try testing.expect(value != null);
    if (value) |v| {
        try testing.expect(v == 0x12345678);
    }
}

