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

    std.debug.print("\n🚀 Grain VM Benchmark: JIT vs Interpreter\n", .{});
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

    const n_iterations = 100;
    
    // 1. Run Interpreter
    {
        std.debug.print("Starting Interpreter...\n", .{});
        const vm = try allocator.create(vm_mod.VM);
        defer allocator.destroy(vm);
        
        std.debug.print("Initializing VM...\n", .{});
        try vm.init_with_jit(allocator, &sum_program, 0x80000000);
        std.debug.print("VM Initialized.\n", .{});
        defer vm.deinit_jit(allocator);
        
        // Disable JIT for interpreter run
        vm.jit_enabled = false;
        
        // Set input a0 = n_iterations
        vm.regs.set(10, n_iterations);
        vm.state = .running;
        
        const start = std.time.nanoTimestamp();
        
        // Run until halted (ret will jump to 0 which is likely 0 instruction -> loop or invalid)
        // Actually RET jumps to RA. We need to set RA to a magic exit address.
        vm.regs.set(1, 0x90000000); // RA = Magic exit
        
        // We need a way to stop.
        // Let's just run for a fixed number of steps or until PC hits magic exit.
        var steps: usize = 0;
        std.debug.print("Starting loop...\n", .{});
        while (vm.regs.pc != 0x90000000 and vm.state == .running) {
            // std.debug.print("Step {}\n", .{steps}); // Too noisy
            vm.step() catch |err| {
                std.debug.print("Interpreter error at PC=0x{x}: {}\n", .{vm.regs.pc, err});
                break;
            };
            steps += 1;
            if (steps > 10000) {
                std.debug.print("Interpreter timeout! PC=0x{x}\n", .{vm.regs.pc});
                break;
            }
        }
        
        const end = std.time.nanoTimestamp();
        const duration = end - start;
        
        std.debug.print("Interpreter: {d} ms (Result: {})\n", .{ @divTrunc(duration, 1_000_000), vm.regs.get(10) });
    }

    // 2. Run JIT
    {
        std.debug.print("Starting JIT...\n", .{});
        const vm = try allocator.create(vm_mod.VM);
        defer allocator.destroy(vm);
        
        try vm.init_with_jit(allocator, &sum_program, 0x80000000);
        defer vm.deinit_jit(allocator);
        
        // Enable JIT
        vm.jit_enabled = true;
        
        // Set input a0 = n_iterations
        vm.regs.set(10, n_iterations);
        vm.state = .running;
        vm.regs.set(1, 0x90000000); // RA = Magic exit
        
        const start = std.time.nanoTimestamp();
        
        var steps: usize = 0;
        while (vm.regs.pc != 0x90000000 and vm.state == .running) {
            vm.step_jit() catch |err| {
                std.debug.print("JIT error at PC=0x{x}: {}\n", .{vm.regs.pc, err});
                break;
            };
            steps += 1;
            if (steps > 10000) {
                std.debug.print("JIT timeout! PC=0x{x}\n", .{vm.regs.pc});
                break;
            }
        }
        
        const end = std.time.nanoTimestamp();
        const duration = end - start;
        
        std.debug.print("JIT:         {d} ms (Result: {})\n", .{ @divTrunc(duration, 1_000_000), vm.regs.get(10) });
        
        if (vm.jit) |jit| {
            jit.perf_counters.print_stats();
        }
    }
}
