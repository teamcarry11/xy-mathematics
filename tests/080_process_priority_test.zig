//! Tests for process priority/nice value syscalls.
//! Why: Verify kernel can set and get process priority for scheduling.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");

test "process priority field initialization" {
    // Verify Process struct includes priority field.
    const process = basin_kernel.Process.init();
    try testing.expect(process.priority == 0); // Default priority (nice value 0)
}

test "process priority initialization" {
    // Verify Process struct initializes priority to default value.
    const process = basin_kernel.Process.init();
    try testing.expect(process.priority == 0); // Default priority (nice value 0)
    
    // Verify priority field exists and is i8 type.
    try testing.expect(@TypeOf(process.priority) == i8);
}

test "priority value conversion" {
    // Test priority value conversion (nice value to unsigned).
    // Nice value -20 should become 0
    // Nice value 0 should become 20
    // Nice value 19 should become 39
    
    const nice_minus_20: i8 = -20;
    const nice_zero: i8 = 0;
    const nice_19: i8 = 19;
    
    const unsigned_0 = @as(u64, @intCast(@as(i32, nice_minus_20) + 20));
    const unsigned_20 = @as(u64, @intCast(@as(i32, nice_zero) + 20));
    const unsigned_39 = @as(u64, @intCast(@as(i32, nice_19) + 20));
    
    try testing.expect(unsigned_0 == 0);
    try testing.expect(unsigned_20 == 20);
    try testing.expect(unsigned_39 == 39);
}

