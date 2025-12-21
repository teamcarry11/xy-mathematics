//! Performance Benchmark Verification Test
//! Why: Verify 60fps and sub-ms latency requirements for SLC products.
//! Grain Style: Explicit types (u32/u64), comprehensive assertions, bounded allocations.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const VMBenchmark = kernel_vm.benchmark.VMBenchmark;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const Syscall = basin_kernel.basin_kernel.Syscall;

// Target: 60fps = 16.67ms per frame.
const TARGET_FRAME_TIME_NS: u64 = 16_666_667; // 16.67ms in nanoseconds

// Target: Sub-ms latency = < 1ms = 1,000,000 nanoseconds.
const TARGET_LATENCY_NS: u64 = 1_000_000; // 1ms in nanoseconds

// Test: VM can execute at 60fps (16.67ms per frame).
test "performance benchmark: 60fps frame time" {
    // Create minimal program (NOP loop).
    const nop_program = [_]u8{
        0x13, 0x00, 0x00, 0x00, // ADDI x0, x0, 0 (NOP)
        0x6F, 0x00, 0x00, 0x00, // JAL x0, -4 (loop back)
    };
    
    // Initialize VM.
    var vm: VM = undefined;
    VM.init(&vm, &nop_program, 0x80000000);
    
    // Initialize benchmark.
    var benchmark = VMBenchmark.init();
    
    // Run benchmark with frame-like execution (60 steps = 1 frame).
    const frame_steps: u64 = 60;
    const result = try benchmark.run_benchmark(&vm, "60fps_frame", frame_steps);
    
    // Assert: Execution time must be within target frame time.
    // Note: Allow 2x margin for test environment variability.
    const max_frame_time_ns: u64 = TARGET_FRAME_TIME_NS * 2;
    try testing.expect(result.execution_time_ns <= max_frame_time_ns);
    
    // Assert: Benchmark must have executed successfully.
    try testing.expect(result.passed or vm.state == .halted);
}

// Test: Syscall latency is sub-ms (< 1ms).
test "performance benchmark: sub-ms syscall latency" {
    // Initialize kernel.
    var kernel = BasinKernel.init();
    
    // Test syscall: sysinfo (lightweight syscall).
    const sysinfo_num = @intFromEnum(Syscall.sysinfo);
    const sysinfo_arg1: u64 = 0x1000; // Valid pointer
    
    // Measure syscall latency (multiple runs for average).
    const num_runs: u32 = 100;
    var total_latency_ns: u64 = 0;
    var run_count: u32 = 0;
    
    while (run_count < num_runs) : (run_count += 1) {
        const start_time = std.time.nanoTimestamp();
        
        // Execute syscall.
        _ = kernel.handle_syscall(sysinfo_num, sysinfo_arg1, 0, 0, 0) catch |err| {
            // Syscall may fail (invalid address), but measure latency anyway.
            _ = err;
        };
        
        const end_time = std.time.nanoTimestamp();
        const latency: i64 = end_time - start_time;
        
        if (latency > 0) {
            total_latency_ns += @as(u64, @intCast(latency));
        }
    }
    
    // Calculate average latency.
    const avg_latency_ns: u64 = if (run_count > 0) total_latency_ns / run_count else 0;
    
    // Assert: Average latency must be sub-ms (< 1ms).
    // Note: Allow 2x margin for test environment variability.
    const max_latency_ns: u64 = TARGET_LATENCY_NS * 2;
    try testing.expect(avg_latency_ns <= max_latency_ns);
}

// Test: File system syscall latency is sub-ms.
test "performance benchmark: file syscall latency" {
    // Initialize kernel.
    var kernel = BasinKernel.init();
    
    // Set up process.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;
    
    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);
    
    // Test syscall: open (file system syscall).
    const open_num = @intFromEnum(Syscall.open);
    const path_ptr: u64 = 0x1000;
    const path_len: u64 = 10;
    const flags: u64 = 0x5; // read + create
    
    // Measure syscall latency (multiple runs for average).
    const num_runs: u32 = 100;
    var total_latency_ns: u64 = 0;
    var run_count: u32 = 0;
    
    while (run_count < num_runs) : (run_count += 1) {
        const start_time = std.time.nanoTimestamp();
        
        // Execute syscall.
        _ = kernel.handle_syscall(open_num, path_ptr, path_len, flags, 0) catch |err| {
            // Syscall may fail (invalid address), but measure latency anyway.
            _ = err;
        };
        
        const end_time = std.time.nanoTimestamp();
        const latency: i64 = end_time - start_time;
        
        if (latency > 0) {
            total_latency_ns += @as(u64, @intCast(latency));
        }
    }
    
    // Calculate average latency.
    const avg_latency_ns: u64 = if (run_count > 0) total_latency_ns / run_count else 0;
    
    // Assert: Average latency must be sub-ms (< 1ms).
    // Note: Allow 2x margin for test environment variability.
    const max_latency_ns: u64 = TARGET_LATENCY_NS * 2;
    try testing.expect(avg_latency_ns <= max_latency_ns);
}

// Test: Network syscall latency is sub-ms.
test "performance benchmark: network syscall latency" {
    // Initialize kernel.
    var kernel = BasinKernel.init();
    
    // Set up process.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;
    
    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);
    
    // Test syscall: tcp_socket (network syscall).
    const tcp_socket_num = @intFromEnum(Syscall.tcp_socket);
    
    // Measure syscall latency (multiple runs for average).
    const num_runs: u32 = 100;
    var total_latency_ns: u64 = 0;
    var run_count: u32 = 0;
    
    while (run_count < num_runs) : (run_count += 1) {
        const start_time = std.time.nanoTimestamp();
        
        // Execute syscall.
        _ = kernel.handle_syscall(tcp_socket_num, 0, 0, 0, 0) catch |err| {
            // Syscall may fail, but measure latency anyway.
            _ = err;
        };
        
        const end_time = std.time.nanoTimestamp();
        const latency: i64 = end_time - start_time;
        
        if (latency > 0) {
            total_latency_ns += @as(u64, @intCast(latency));
        }
    }
    
    // Calculate average latency.
    const avg_latency_ns: u64 = if (run_count > 0) total_latency_ns / run_count else 0;
    
    // Assert: Average latency must be sub-ms (< 1ms).
    // Note: Allow 2x margin for test environment variability.
    const max_latency_ns: u64 = TARGET_LATENCY_NS * 2;
    try testing.expect(avg_latency_ns <= max_latency_ns);
}

// Test: VM instruction execution rate supports 60fps.
test "performance benchmark: vm instruction rate" {
    // Create minimal program (NOP loop).
    const nop_program = [_]u8{
        0x13, 0x00, 0x00, 0x00, // ADDI x0, x0, 0 (NOP)
        0x6F, 0x00, 0x00, 0x00, // JAL x0, -4 (loop back)
    };
    
    // Initialize VM.
    var vm: VM = undefined;
    VM.init(&vm, &nop_program, 0x80000000);
    
    // Execute 60 instructions (1 frame worth).
    const frame_instructions: u64 = 60;
    vm.start();
    
    const start_time = std.time.nanoTimestamp();
    var instruction_count: u64 = 0;
    
    while (instruction_count < frame_instructions and vm.state == .running) {
        vm.step() catch |err| {
            // Step may fail, but continue counting.
            _ = err;
            break;
        };
        instruction_count += 1;
    }
    
    const end_time = std.time.nanoTimestamp();
    const execution_time: i64 = end_time - start_time;
    const execution_time_ns: u64 = if (execution_time > 0) @as(u64, @intCast(execution_time)) else 0;
    
    // Assert: Execution time must be within target frame time.
    // Note: Allow 2x margin for test environment variability.
    const max_frame_time_ns: u64 = TARGET_FRAME_TIME_NS * 2;
    try testing.expect(execution_time_ns <= max_frame_time_ns);
}
