//! Tests for VM Statistics Export System
//!
//! Objective: Verify statistics export to JSON works correctly.
//! Why: Ensure JSON export accurately represents all VM statistics.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM stats export initialization" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var exporter = kernel_vm_mod.stats_export.VMStatsExporter.init(&vm);
    const json = exporter.export_to_json();
    try testing.expect(json.len > 0);
    try testing.expect(json[0] == '{');
}

test "VM stats export contains performance" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    vm.performance.instructions_executed = 100;
    var exporter = kernel_vm_mod.stats_export.VMStatsExporter.init(&vm);
    const json = exporter.export_to_json();
    try testing.expect(std.mem.indexOf(u8, json, "performance") != null);
    try testing.expect(std.mem.indexOf(u8, json, "instructions_executed") != null);
}

test "VM stats export contains memory" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    vm.memory_stats.total_reads = 50;
    var exporter = kernel_vm_mod.stats_export.VMStatsExporter.init(&vm);
    const json = exporter.export_to_json();
    try testing.expect(std.mem.indexOf(u8, json, "memory") != null);
    try testing.expect(std.mem.indexOf(u8, json, "total_reads") != null);
}

test "VM stats export aggregator integration" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var aggregator = kernel_vm_mod.stats_aggregator.VMStatsAggregator.init(&vm);
    const json = aggregator.export_to_json();
    try testing.expect(json.len > 0);
    try testing.expect(json[0] == '{');
}

