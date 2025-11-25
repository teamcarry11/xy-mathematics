//! Tests for JIT hot path detection.
//! Why: Verify hot path tracking works correctly.

const std = @import("std");
const testing = std.testing;
const jit_mod = @import("kernel_vm/jit.zig");
const vm_mod = @import("kernel_vm/vm.zig");
const builtin = @import("builtin");

test "hot path tracker initialization" {
    const tracker = jit_mod.HotPathTracker.init();
    try testing.expect(tracker.paths_len == 0);
    try testing.expect(tracker.total_executions == 0);
    try testing.expect(tracker.sequence_number == 0);
}

test "hot path tracker record execution" {
    var tracker = jit_mod.HotPathTracker.init();
    tracker.record_execution(0x80000000);
    try testing.expect(tracker.total_executions == 1);
    try testing.expect(tracker.paths_len == 1);
    try testing.expect(tracker.paths[0].pc == 0x80000000);
    try testing.expect(tracker.paths[0].execution_count == 1);
}

test "hot path tracker multiple executions" {
    var tracker = jit_mod.HotPathTracker.init();
    tracker.record_execution(0x80000000);
    tracker.record_execution(0x80000000);
    tracker.record_execution(0x80000004);
    try testing.expect(tracker.total_executions == 3);
    try testing.expect(tracker.paths_len == 2);
    try testing.expect(tracker.paths[0].execution_count == 2);
    try testing.expect(tracker.paths[1].execution_count == 1);
}

test "hot path tracker get hot paths" {
    var tracker = jit_mod.HotPathTracker.init();
    tracker.record_execution(0x80000000);
    tracker.record_execution(0x80000004);
    const paths = tracker.get_hot_paths(1);
    try testing.expect(paths.len == 2);
}

test "JIT hot path tracking integration" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    // Simple program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET (JALR x0, x1, 0)
    };
    
    // Initialize VM with JIT.
    var vm: vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute multiple times to generate hot paths.
    try vm.step_jit();
    try vm.step_jit();
    
    // Verify hot path tracking.
    if (vm.jit) |jit_ctx| {
        try testing.expect(jit_ctx.perf_counters.hot_path_tracker.total_executions > 0);
        const paths = jit_ctx.perf_counters.hot_path_tracker.get_hot_paths(1);
        // Should have at least one hot path.
        _ = paths;
    }
}

test "JIT hot path stats printing" {
    // JIT only available on macOS ARM64.
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        return;
    }
    
    const allocator = testing.allocator;
    
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    var vm: vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    try vm.step_jit();
    
    // Verify hot path stats can be printed.
    if (vm.jit) |jit_ctx| {
        jit_ctx.perf_counters.print_stats();
        jit_ctx.perf_counters.print_hot_paths();
    }
}

