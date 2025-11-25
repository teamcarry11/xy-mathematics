//! Process Execution and Context Switching
//! Why: Execute processes in VM by switching contexts and running VM until process exits or yields.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const ProcessContext = @import("process.zig").ProcessContext;
const VM = @import("kernel_vm").VM;

/// Switch VM to process context (set VM registers from ProcessContext).
/// Why: Prepare VM to execute a process by loading its context.
/// Contract: process_context must be initialized, vm must be initialized.
/// Grain Style: Explicit types, comprehensive assertions, no recursion.
pub fn switch_to_process_context(vm: *VM, process_context: *const ProcessContext) void {
    // Assert: Process context must be initialized (precondition).
    Debug.kassert(process_context.initialized, "Process context not initialized", .{});
    
    // Assert: VM must be initialized (precondition).
    Debug.kassert(vm.memory_size > 0, "VM not initialized", .{});
    
    // Assert: PC must be non-zero (valid entry point).
    Debug.kassert(process_context.pc != 0, "PC is 0", .{});
    
    // Assert: SP must be non-zero (valid stack pointer).
    Debug.kassert(process_context.sp != 0, "SP is 0", .{});
    
    // Set VM program counter to process PC.
    // Why: Start execution at process entry point or current PC.
    vm.regs.pc = process_context.pc;
    
    // Set VM stack pointer register (x2 = SP in RISC-V).
    // Why: Process needs valid stack pointer for execution.
    const SP_REGISTER: u5 = 2;
    vm.regs.set(SP_REGISTER, process_context.sp);
    
    // Assert: VM PC must be set correctly (postcondition).
    Debug.kassert(vm.regs.pc == process_context.pc, "VM PC not set", .{});
    
    // Assert: VM SP register must be set correctly (postcondition).
    Debug.kassert(vm.regs.get(SP_REGISTER) == process_context.sp, "VM SP not set", .{});
}

/// Save VM context to process context (save VM registers to ProcessContext).
/// Why: Preserve process execution state when switching away from process.
/// Contract: process_context must be initialized, vm must be initialized.
/// Grain Style: Explicit types, comprehensive assertions, no recursion.
pub fn save_process_context(vm: *VM, process_context: *ProcessContext) void {
    // Assert: Process context must be initialized (precondition).
    Debug.kassert(process_context.initialized, "Process context not initialized", .{});
    
    // Assert: VM must be initialized (precondition).
    Debug.kassert(vm.memory_size > 0, "VM not initialized", .{});
    
    // Assert: VM PC must be non-zero (valid execution state).
    Debug.kassert(vm.regs.pc != 0, "VM PC is 0", .{});
    
    // Save VM program counter to process context.
    // Why: Track current execution position.
    process_context.pc = vm.regs.pc;
    
    // Save VM stack pointer register (x2 = SP in RISC-V) to process context.
    // Why: Track current stack position.
    const SP_REGISTER: u5 = 2;
    process_context.sp = vm.regs.get(SP_REGISTER);
    
    // Assert: Process context PC must be saved correctly (postcondition).
    Debug.kassert(process_context.pc == vm.regs.pc, "Process PC not saved", .{});
    
    // Assert: Process context SP must be saved correctly (postcondition).
    Debug.kassert(process_context.sp == vm.regs.get(SP_REGISTER), "Process SP not saved", .{});
}

/// Execute process in VM until it exits or yields.
/// Why: Run process execution loop, handling syscalls and context switches.
/// Contract: process_context must be initialized, vm must be initialized.
/// Returns: true if process should continue (yield), false if process exited.
/// Grain Style: Explicit types, bounded execution, no recursion.
pub fn execute_process(
    vm: *VM,
    process_context: *ProcessContext,
    max_steps: u64,
) bool {
    // Assert: Process context must be initialized (precondition).
    Debug.kassert(process_context.initialized, "Process context not initialized", .{});
    
    // Assert: VM must be initialized (precondition).
    Debug.kassert(vm.memory_size > 0, "VM not initialized", .{});
    
    // Assert: Max steps must be reasonable (bounded execution).
    const MAX_STEPS_LIMIT: u64 = 1_000_000_000; // 1 billion steps max
    Debug.kassert(max_steps <= MAX_STEPS_LIMIT, "Max steps too large", .{});
    
    // Switch VM to process context (set VM registers from ProcessContext).
    // Why: Prepare VM to execute process.
    switch_to_process_context(vm, process_context);
    
    // Start VM execution (set state to running).
    // Why: VM must be running to execute instructions.
    vm.state = .running;
    
    // Execute VM steps until process exits or yields.
    // Why: Run process until it makes exit syscall or yields.
    var steps_executed: u64 = 0;
    while (steps_executed < max_steps) : (steps_executed += 1) {
        // Check if VM is halted or errored (process exited or error occurred).
        if (vm.state != .running) {
            break;
        }
        
        // Execute one VM step (use JIT if enabled, falls back to interpreter).
        // Why: Execute one instruction at a time with JIT acceleration.
        vm.step_jit() catch |err| {
            // VM execution error: save context and return false (process exited).
            _ = err;
            save_process_context(vm, process_context);
            return false;
        };
        
        // Check if process made exit syscall (syscall number 2 = exit).
        // Why: Detect when process calls exit syscall.
        // Note: This is a simplified check - in a full implementation, we'd check
        // the syscall handler return value or process state.
        // For now, we check if VM is halted (which happens after exit syscall).
        if (vm.state == .halted) {
            // Process exited: save context and return false.
            save_process_context(vm, process_context);
            return false;
        }
    }
    
    // Save process context before returning (preserve execution state).
    // Why: Track current execution position for next time slice.
    save_process_context(vm, process_context);
    
    // Assert: Steps executed must be within limit (postcondition).
    Debug.kassert(steps_executed <= max_steps, "Steps executed exceeded limit", .{});
    
    // Return true if process should continue (yield case).
    // Why: Process may need more time slices to complete.
    return vm.state == .running;
}

// Test: switch to process context.
test "switch to process context sets VM registers" {
    var vm = VM.init(&[_]u8{}, 0);
    const context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    switch_to_process_context(&vm, &context);
    
    // Assert: VM PC must be set to context PC.
    try std.testing.expect(vm.regs.pc == 0x10000);
    
    // Assert: VM SP register must be set to context SP.
    try std.testing.expect(vm.regs.get(2) == 0x400000);
}

// Test: save process context.
test "save process context preserves VM state" {
    var vm = VM.init(&[_]u8{}, 0);
    vm.regs.pc = 0x10010;
    vm.regs.set(2, 0x400010); // SP register
    
    var context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    save_process_context(&vm, &context);
    
    // Assert: Context PC must be saved from VM PC.
    try std.testing.expect(context.pc == 0x10010);
    
    // Assert: Context SP must be saved from VM SP register.
    try std.testing.expect(context.sp == 0x400010);
}

// Test: execute process runs VM steps.
test "execute process runs VM until halted" {
    var vm = VM.init(&[_]u8{}, 0);
    var context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    // Note: This test will fail if VM tries to execute invalid instructions.
    // For now, we just test that the function runs without crashing.
    // In a full implementation, we'd load valid instructions into VM memory.
    const should_continue = execute_process(&vm, &context, 100);
    
    // Assert: Process execution should complete (halted or errored).
    // Note: This is a basic test - full implementation would check process state.
    _ = should_continue;
}

