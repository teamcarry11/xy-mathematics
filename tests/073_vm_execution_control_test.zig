//! Tests for VM Execution Control System
//!
//! Objective: Verify execution control (continue, step over, step into) works correctly.
//! Why: Ensure execution control accurately manages VM execution flow for debugging.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM execution control initialization" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    const controller = kernel_vm_mod.execution_control.VMExecutionController.init(&vm);
    try testing.expect(controller.state == .paused);
    try testing.expect(controller.call_stack_len == 0);
}

test "VM execution control continue" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var controller = kernel_vm_mod.execution_control.VMExecutionController.init(&vm);
    controller.continue_execution();
    try testing.expect(controller.state == .running);
    try testing.expect(controller.should_continue() == true);
}

test "VM execution control step over" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var controller = kernel_vm_mod.execution_control.VMExecutionController.init(&vm);
    controller.step_over();
    try testing.expect(controller.state == .stepping_over);
    try testing.expect(controller.should_step() == true);
}

test "VM execution control step into" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var controller = kernel_vm_mod.execution_control.VMExecutionController.init(&vm);
    controller.step_into();
    try testing.expect(controller.state == .stepping_into);
    try testing.expect(controller.should_step() == true);
}

test "VM execution control pause" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var controller = kernel_vm_mod.execution_control.VMExecutionController.init(&vm);
    controller.continue_execution();
    controller.pause();
    try testing.expect(controller.state == .paused);
    try testing.expect(controller.should_continue() == false);
}

test "VM execution control call stack" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var controller = kernel_vm_mod.execution_control.VMExecutionController.init(&vm);
    const pushed = controller.push_call_stack(0x80000000, 0x80000004);
    try testing.expect(pushed == true);
    try testing.expect(controller.call_stack_len == 1);
    const entry = controller.pop_call_stack();
    try testing.expect(entry != null);
    if (entry) |e| {
        try testing.expect(e.pc == 0x80000000);
        try testing.expect(e.return_pc == 0x80000004);
    }
    try testing.expect(controller.call_stack_len == 0);
}

test "VM execution control call stack depth" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var controller = kernel_vm_mod.execution_control.VMExecutionController.init(&vm);
    _ = controller.push_call_stack(0x80000000, 0x80000004);
    _ = controller.push_call_stack(0x80000010, 0x80000014);
    try testing.expect(controller.get_call_stack_depth() == 2);
}

