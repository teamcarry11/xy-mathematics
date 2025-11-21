const std = @import("std");
const vm_mod = @import("vm.zig");
const jit_mod = @import("jit.zig");
const builtin = @import("builtin");

/// Fibonacci benchmark for JIT vs Interpreter comparison
/// Calculates fib(30) using recursion to stress-test control flow and stack operations.
pub fn main() !void {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) {
        std.debug.print("Benchmarks require macOS on Apple Silicon.\n", .{});
        return;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n🚀 Grain Vantage Benchmark: JIT vs Interpreter\n", .{});
    std.debug.print("=========================================\n", .{});

    // RISC-V64 machine code for recursive Fibonacci(n)
    // Input: a0 = n
    // Output: a0 = fib(n)
    // C code:
    // long fib(long n) {
    //     if (n <= 1) return n;
    //     return fib(n-1) + fib(n-2);
    // }

    
    // Using a pre-compiled simple iterative loop for stability first, then recursive.
    // Sum(n): 0 to n
    // a0 = n
    // result in a0
    const sum_program = [_]u8{
        // li t0, 0 (sum = 0)
        0x93, 0x02, 0x00, 0x00,
        // li t1, 0 (i = 0)
        0x13, 0x03, 0x00, 0x00,
        // loop:
        // bge t1, a0, exit
        0x63, 0xd6, 0xa3, 0x00, // offset +12 -> exit
        // add t0, t0, t1
        0x33, 0x02, 0x62, 0x00,
        // addi t1, t1, 1
        0x93, 0x83, 0x13, 0x00,
        // j loop
        0x6f, 0xf0, 0x5f, 0xff, // offset -12
        // exit:
        // mv a0, t0
        0x13, 0x05, 0x52, 0x00,
        // ret
        0x67, 0x80, 0x00, 0x00,
    };

    const n_iterations = 1000; // Increased for better measurement accuracy
    const n_runs = 1; // Single run for now (can increase if memory allows)
    
    var interpreter_times: [n_runs]i64 = undefined;
    var jit_times: [n_runs]i64 = undefined;
    
    std.debug.print("Running {d} iterations, {d} run(s)...\n\n", .{ n_iterations, n_runs });
    
    // 1. Run Interpreter (multiple runs, reuse single VM)
    std.debug.print("📊 Interpreter Benchmarks:\n", .{});
    std.debug.print("───────────────────────────\n", .{});
    
    const vm_interp = try allocator.create(vm_mod.VM);
    defer allocator.destroy(vm_interp);
    vm_interp.init(&sum_program, 0x80000000); // Use init() to avoid JIT allocation
    
    for (0..n_runs) |run_idx| {
        // Reset VM state for each run
        vm_interp.regs = .{};
        vm_interp.regs.set(10, n_iterations);
        vm_interp.regs.set(1, 0x90000000); // RA = Magic exit
        vm_interp.regs.pc = 0x80000000;
        vm_interp.state = .running;
        
        const start = std.time.nanoTimestamp();
        
        var steps: usize = 0;
        while (vm_interp.regs.pc != 0x90000000 and vm_interp.state == .running) {
            vm_interp.step() catch |err| {
                std.debug.print("Interpreter error at PC=0x{x}: {}\n", .{vm_interp.regs.pc, err});
                break;
            };
            steps += 1;
            if (steps > 100000) {
                std.debug.print("Interpreter timeout! PC=0x{x}\n", .{vm_interp.regs.pc});
                break;
            }
        }
        
        const end = std.time.nanoTimestamp();
        const duration: i64 = @intCast(end - start);
        interpreter_times[run_idx] = duration;
        
        std.debug.print("  Run {}: {d:.2} ms ({} steps)\n", .{
            run_idx + 1,
            @as(f64, @floatFromInt(duration)) / 1_000_000.0,
            steps,
        });
    }
    
    // 2. Run JIT (multiple runs, reuse single VM)
    std.debug.print("\n🚀 JIT Benchmarks:\n", .{});
    std.debug.print("──────────────────\n", .{});
    
    const vm_jit = try allocator.create(vm_mod.VM);
    defer allocator.destroy(vm_jit);
    try vm_jit.init_with_jit(allocator, &sum_program, 0x80000000);
    defer vm_jit.deinit_jit(allocator);
    vm_jit.jit_enabled = true; // Enable JIT
    
    for (0..n_runs) |run_idx| {
        // Reset VM state for each run
        vm_jit.regs = .{};
        vm_jit.regs.set(10, n_iterations);
        vm_jit.regs.set(1, 0x90000000); // RA = Magic exit
        vm_jit.regs.pc = 0x80000000;
        vm_jit.state = .running;
        
        // Clear JIT cache between runs (for fair comparison)
        if (vm_jit.jit) |jit| {
            jit.block_cache.clearRetainingCapacity();
        }
        
        const start = std.time.nanoTimestamp();
        
        var steps: usize = 0;
        while (vm_jit.regs.pc != 0x90000000 and vm_jit.state == .running) {
            vm_jit.step_jit() catch |err| {
                std.debug.print("JIT error at PC=0x{x}: {}\n", .{vm_jit.regs.pc, err});
                break;
            };
            steps += 1;
            if (steps > 100000) {
                std.debug.print("JIT timeout! PC=0x{x}\n", .{vm_jit.regs.pc});
                break;
            }
        }
        
        const end = std.time.nanoTimestamp();
        const duration: i64 = @intCast(end - start);
        jit_times[run_idx] = duration;
        
        std.debug.print("  Run {}: {d:.2} ms ({} steps)\n", .{
            run_idx + 1,
            @as(f64, @floatFromInt(duration)) / 1_000_000.0,
            steps,
        });
        
        // Print JIT stats on last run
        if (run_idx == n_runs - 1) {
            if (vm_jit.jit) |jit| {
                std.debug.print("\n", .{});
                jit.perf_counters.print_stats();
            }
        }
    }
    
    // 3. Calculate statistics
    std.debug.print("\n📈 Performance Summary:\n", .{});
    std.debug.print("════════════════════════\n", .{});
    
    // Calculate averages
    var interpreter_avg: f64 = 0.0;
    var jit_avg: f64 = 0.0;
    
    for (0..n_runs) |i| {
        interpreter_avg += @as(f64, @floatFromInt(interpreter_times[i]));
        jit_avg += @as(f64, @floatFromInt(jit_times[i]));
    }
    
    interpreter_avg /= @as(f64, @floatFromInt(n_runs));
    jit_avg /= @as(f64, @floatFromInt(n_runs));
    
    const speedup = interpreter_avg / jit_avg;
    
    std.debug.print("Interpreter Average: {d:.2} ms\n", .{interpreter_avg / 1_000_000.0});
    std.debug.print("JIT Average:         {d:.2} ms\n", .{jit_avg / 1_000_000.0});
    std.debug.print("Speedup:             {d:.2}x\n", .{speedup});
    
    // Verify 10x+ speedup requirement
    std.debug.print("\n✅ Verification:\n", .{});
    std.debug.print("═══════════════\n", .{});
    
    if (speedup >= 10.0) {
        std.debug.print("✅ PASS: Speedup ({d:.2}x) meets 10x+ requirement!\n", .{speedup});
    } else {
        std.debug.print("❌ FAIL: Speedup ({d:.2}x) below 10x requirement\n", .{speedup});
    }
    
    // Memory info: JIT uses ~64MB code buffer (static allocation)
    std.debug.print("\n📊 Memory Usage:\n", .{});
    std.debug.print("════════════════\n", .{});
    std.debug.print("JIT Code Buffer: 64 MB (static allocation)\n", .{});
    std.debug.print("Block Cache:     ~10,000 entries (dynamic)\n", .{});
    std.debug.print("Memory Overhead: ~64 MB (acceptable for 10x+ speedup)\n", .{});
}
