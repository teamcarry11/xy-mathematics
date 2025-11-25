//! Tests for VM branch statistics tracking.
//! Why: Verify branch statistics tracking works correctly.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const vm_mod = kernel_vm;
const branch_stats_mod = kernel_vm.branch_stats;

test "VM branch stats initialization" {
    const stats = branch_stats_mod.VMBranchStats.init();
    try testing.expect(stats.total_branches == 0);
    try testing.expect(stats.total_taken == 0);
    try testing.expect(stats.total_not_taken == 0);
    try testing.expect(stats.entries_len == 0);
}

test "VM branch stats record branch" {
    var stats = branch_stats_mod.VMBranchStats.init();
    stats.record_branch(0x80000000, true); // Taken
    try testing.expect(stats.total_branches == 1);
    try testing.expect(stats.total_taken == 1);
    try testing.expect(stats.total_not_taken == 0);
    try testing.expect(stats.entries_len == 1);
    try testing.expect(stats.entries[0].pc == 0x80000000);
    try testing.expect(stats.entries[0].taken_count == 1);
}

test "VM branch stats multiple branches" {
    var stats = branch_stats_mod.VMBranchStats.init();
    stats.record_branch(0x80000000, true); // Taken
    stats.record_branch(0x80000000, false); // Not taken
    stats.record_branch(0x80000004, true); // Taken
    try testing.expect(stats.total_branches == 3);
    try testing.expect(stats.total_taken == 2);
    try testing.expect(stats.total_not_taken == 1);
    try testing.expect(stats.entries_len == 2);
    try testing.expect(stats.entries[0].total_branches == 2);
    try testing.expect(stats.entries[0].taken_count == 1);
    try testing.expect(stats.entries[0].not_taken_count == 1);
}

test "VM branch stats print" {
    var stats = branch_stats_mod.VMBranchStats.init();
    stats.record_branch(0x80000000, true);
    stats.record_branch(0x80000004, false);
    
    // Verify stats can be printed.
    stats.print_stats();
}

test "VM branch stats reset" {
    var stats = branch_stats_mod.VMBranchStats.init();
    stats.record_branch(0x80000000, true);
    stats.record_branch(0x80000004, false);
    
    stats.reset();
    
    try testing.expect(stats.total_branches == 0);
    try testing.expect(stats.total_taken == 0);
    try testing.expect(stats.total_not_taken == 0);
    try testing.expect(stats.entries_len == 0);
}

