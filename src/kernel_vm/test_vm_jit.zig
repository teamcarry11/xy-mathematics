const std = @import("std");
const vm_mod = @import("vm.zig");
const jit_mod = @import("jit.zig");
const builtin = @import("builtin");

test "VM: JIT Integration" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    
    const allocator = std.testing.allocator;
    
    // Simple RISC-V program: ADDI x1, x0, 42; RET
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
        0x67, 0x80, 0x00, 0x00, // RET (JALR x0, x1, 0)
    };
    
    // Initialize VM with JIT
    var vm: vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    // Verify JIT is enabled
    try std.testing.expect(vm.jit_enabled);
    try std.testing.expect(vm.jit != null);
    
    // Set VM to running state
    vm.state = .running;
    
    // Execute with JIT
    try vm.step_jit();
    
    // Verify result
    try std.testing.expectEqual(@as(u64, 42), vm.regs.get(1));
    
    // Print JIT stats
    if (vm.jit) |jit_ctx| {
        jit_ctx.perf_counters.print_stats();
    }
}

test "VM: JIT Fallback to Interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    
    const allocator = std.testing.allocator;
    
    // Program with invalid instruction
    const program = [_]u8{
        0xFF, 0xFF, 0xFF, 0xFF, // Invalid instruction
        0x67, 0x80, 0x00, 0x00, // RET
    };
    
    // Initialize VM with JIT
    var vm: vm_mod.VM = undefined;
    try vm.init_with_jit(allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    vm.state = .running;
    
    // Execute with JIT (should fall back to interpreter)
    try vm.step_jit();
    
    // Verify fallback counter incremented
    if (vm.jit) |jit_ctx| {
        try std.testing.expect(jit_ctx.perf_counters.interpreter_fallbacks > 0);
    }
}
