const std = @import("std");
const testing = std.testing;
const grain_field = @import("grain_field");
const Compute = grain_field.Compute;

test "field compute init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sram_capacity: u64 = 47_185_920_000; // 44GB
    const core_count: u32 = 1000; // Smaller for testing
    var field = try Compute.FieldCompute.init(allocator, sram_capacity, core_count);
    defer field.deinit();

    try testing.expect(field.cores_len == core_count);
    try testing.expect(field.sram_capacity == sram_capacity);
    try testing.expect(field.sram_used == 0);
}

test "field sram allocation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sram_capacity: u64 = 1_073_741_824; // 1GB for testing
    const core_count: u32 = 100;
    var field = try Compute.FieldCompute.init(allocator, sram_capacity, core_count);
    defer field.deinit();

    const size: u64 = 1024 * 1024; // 1MB
    const offset = try field.allocate_sram(0, size);

    try testing.expect(offset == 0);
    try testing.expect(field.sram_used == size);

    const core = field.get_core(0);
    try testing.expect(core != null);
    try testing.expect(core.?.sram_offset == 0);
    try testing.expect(core.?.sram_size == size);
}

test "field parallel operation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sram_capacity: u64 = 1_073_741_824; // 1GB for testing
    const core_count: u32 = 100;
    var field = try Compute.FieldCompute.init(allocator, sram_capacity, core_count);
    defer field.deinit();

    const core_ids = [_]u32{ 0, 1, 2, 3 };
    const op_id = try field.execute_parallel(.vector_search, &core_ids, 0, 1024);

    try testing.expect(op_id == 0);
    try testing.expect(field.parallel_ops_len == 1);

    const status = field.get_op_status(op_id);
    try testing.expect(status != null);
    try testing.expect(status.? == .pending);
}

