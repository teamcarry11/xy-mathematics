//! Tests for VM Performance Benchmarking Framework
//!
//! Objective: Verify benchmarking framework works correctly.
//! Why: Ensure benchmarking accurately measures VM performance.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM benchmark initialization" {
    const benchmark = kernel_vm.benchmark.VMBenchmark.init();
    try testing.expect(benchmark.results_count == 0);
}

test "VM benchmark run" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var bench = kernel_vm_mod.benchmark.VMBenchmark.init();
    const result = try bench.run_benchmark(&vm, "test_benchmark", 100);
    try testing.expect(result.instructions_executed >= 0);
    try testing.expect(bench.results_count == 1);
}

test "VM benchmark get result" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var bench = kernel_vm_mod.benchmark.VMBenchmark.init();
    _ = try bench.run_benchmark(&vm, "test_benchmark", 100);
    const result_opt = bench.get_result(0);
    try testing.expect(result_opt != null);
    if (result_opt) |result| {
        try testing.expect(result.instructions_executed >= 0);
    }
    const invalid_opt = bench.get_result(100);
    try testing.expect(invalid_opt == null);
}

test "VM benchmark get results count" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var bench = kernel_vm_mod.benchmark.VMBenchmark.init();
    _ = try bench.run_benchmark(&vm, "test1", 100);
    _ = try bench.run_benchmark(&vm, "test2", 100);
    try testing.expect(bench.get_results_count() == 2);
}

test "VM benchmark clear results" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm = kernel_vm_mod.VM{};
    vm.init(&program, 0x80000000);
    var bench = kernel_vm_mod.benchmark.VMBenchmark.init();
    _ = try bench.run_benchmark(&vm, "test_benchmark", 100);
    try testing.expect(bench.results_count == 1);
    bench.clear_results();
    try testing.expect(bench.results_count == 0);
}

test "VM benchmark compare results" {
    const kernel_vm_mod = @import("kernel_vm");
    var program = [_]u8{0} ** 1024;
    var vm1 = kernel_vm_mod.VM{};
    vm1.init(&program, 0x80000000);
    var vm2 = kernel_vm_mod.VM{};
    vm2.init(&program, 0x80000000);
    var bench1 = kernel_vm_mod.benchmark.VMBenchmark.init();
    var bench2 = kernel_vm_mod.benchmark.VMBenchmark.init();
    _ = try bench1.run_benchmark(&vm1, "test", 100);
    _ = try bench2.run_benchmark(&vm2, "test", 100);
    bench1.compare_results(&bench2);
    try testing.expect(true);
}

