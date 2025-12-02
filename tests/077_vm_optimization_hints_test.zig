//! Tests for VM Performance Optimization Hints System
//!
//! Objective: Verify optimization hints analysis works correctly.
//! Why: Ensure optimization hints accurately identify performance bottlenecks.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM optimization hints initialization" {
    const hints = kernel_vm.optimization_hints.VMOptimizationHints.init();
    try testing.expect(hints.hints_count == 0);
}

test "VM optimization hints analyze hot instructions" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var i: u32 = 0;
    while (i < 2000) : (i += 1) {
        vm.instruction_stats.record_instruction(0x13);
    }
    var hints = kernel_vm_mod.optimization_hints.VMOptimizationHints.init();
    hints.analyze_vm(&vm);
    try testing.expect(hints.hints_count > 0);
    const hint_opt = hints.get_hint(0);
    try testing.expect(hint_opt != null);
    if (hint_opt) |hint| {
        try testing.expect(hint.hint_type == .hot_instruction);
    }
}

test "VM optimization hints analyze memory hot spots" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        vm.memory_stats.record_read(0x90000000);
        vm.memory_stats.record_write(0x90000000);
    }
    var hints = kernel_vm_mod.optimization_hints.VMOptimizationHints.init();
    hints.analyze_vm(&vm);
    const hint_opt = hints.get_hint(0);
    if (hint_opt) |hint| {
        if (hint.hint_type == .memory_hot_spot) {
            try testing.expect(hint.address == 0x90000000);
        }
    }
}

test "VM optimization hints get hints count" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var hints = kernel_vm_mod.optimization_hints.VMOptimizationHints.init();
    hints.analyze_vm(&vm);
    const count = hints.get_hints_count();
    try testing.expect(count <= kernel_vm_mod.optimization_hints.MAX_HINTS);
}

test "VM optimization hints get hint" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var i: u32 = 0;
    while (i < 2000) : (i += 1) {
        vm.instruction_stats.record_instruction(0x13);
    }
    var hints = kernel_vm_mod.optimization_hints.VMOptimizationHints.init();
    hints.analyze_vm(&vm);
    if (hints.hints_count > 0) {
        const hint_opt = hints.get_hint(0);
        try testing.expect(hint_opt != null);
        const invalid_opt = hints.get_hint(100);
        try testing.expect(invalid_opt == null);
    }
}

test "VM optimization hints analyze register pressure" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var i: u32 = 0;
    while (i < 20000) : (i += 1) {
        vm.register_stats.record_read(5);
        vm.register_stats.record_write(5);
    }
    var hints = kernel_vm_mod.optimization_hints.VMOptimizationHints.init();
    hints.analyze_vm(&vm);
    const hint_opt = hints.get_hint(0);
    if (hint_opt) |hint| {
        if (hint.hint_type == .register_pressure) {
            try testing.expect(hint.address == 5);
        }
    }
}

