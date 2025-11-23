//! Trap Handler Loop
//! Why: Main kernel loop for handling interrupts and syscalls.
//! Grain Style: Explicit state tracking, bounded execution.

const Panic = @import("panic.zig");
const InterruptController = @import("interrupt.zig").InterruptController;
const BasinKernel = @import("basin_kernel.zig").BasinKernel;
const Debug = @import("debug.zig");

/// Exception type (RISC-V exception codes).
/// Why: Explicit exception types for type safety.
pub const ExceptionType = enum(u32) {
    /// Instruction address misaligned.
    instruction_address_misaligned = 0,
    /// Instruction access fault.
    instruction_access_fault = 1,
    /// Illegal instruction.
    illegal_instruction = 2,
    /// Breakpoint.
    breakpoint = 3,
    /// Load address misaligned.
    load_address_misaligned = 4,
    /// Load access fault.
    load_access_fault = 5,
    /// Store/AMO address misaligned.
    store_address_misaligned = 6,
    /// Store/AMO access fault.
    store_access_fault = 7,
    /// Environment call from U-mode.
    environment_call_from_u_mode = 8,
    /// Environment call from S-mode.
    environment_call_from_s_mode = 9,
    /// Instruction page fault.
    instruction_page_fault = 12,
    /// Load page fault.
    load_page_fault = 13,
    /// Store/AMO page fault.
    store_page_fault = 15,
};

/// Trap loop (main kernel loop).
/// Why: Process interrupts and handle syscalls in main loop.
/// Contract: Must be called from kernel main, runs indefinitely.
/// Note: In VM, syscalls are handled by VM's syscall handler.
///       This loop processes pending interrupts and exceptions.
/// GrainStyle: Bounded loops, explicit state tracking, no recursion.
pub fn loop_with_kernel(kernel: *BasinKernel) noreturn {
    // Assert: Kernel pointer must be valid (precondition).
    const kernel_ptr = @intFromPtr(kernel);
    Debug.kassert(kernel_ptr != 0, "Kernel ptr is null", .{});
    Debug.kassert(kernel_ptr % @alignOf(BasinKernel) == 0, "Kernel ptr unaligned", .{});
    
    Panic.write("grain kernel: entering trap loop\n");
    
    // Main trap loop (bounded iterations per cycle).
    // Why: Process interrupts and exceptions in main loop.
    // GrainStyle: Bounded execution, no infinite loops without bounds.
    var iteration_count: u32 = 0;
    const MAX_ITERATIONS_PER_CYCLE: u32 = 1000; // Prevent infinite loops.
    
    while (true) {
        // Assert: Iteration count must be bounded (invariant).
        Debug.kassert(iteration_count < MAX_ITERATIONS_PER_CYCLE, "Iteration count overflow", .{});
        
        // Process pending interrupts.
        // Why: Handle deferred interrupts (timer, external, software).
        kernel.interrupt_controller.process_pending();
        
        // Assert: Interrupt controller must be initialized (postcondition).
        Debug.kassert(kernel.interrupt_controller.initialized, "Interrupt controller not initialized", .{});
        
        // Yield CPU if no work (cooperative scheduling).
        // Why: Allow other processes to run if current process yields.
        // Note: In VM, scheduling is handled by VM's step loop.
        // This is a placeholder for future cooperative scheduling.
        
        // Reset iteration count periodically (prevent overflow).
        iteration_count += 1;
        if (iteration_count >= MAX_ITERATIONS_PER_CYCLE) {
            iteration_count = 0;
        }
    }
}

/// Legacy trap loop (backward compatibility).
/// Why: Maintain compatibility with existing code that calls loop().
/// Contract: Must be called from kernel main, runs indefinitely.
/// Note: This version doesn't process interrupts (requires kernel reference).
///       Use loop_with_kernel() for full functionality.
pub fn loop() noreturn {
    Panic.write("grain kernel: entering trap loop (legacy mode)\n");
    
    // Legacy loop (no interrupt processing).
    // Why: Backward compatibility with code that doesn't pass kernel reference.
    // Note: In VM environment, interrupts are processed via VM's interrupt handling.
    while (true) {
        // Empty loop (interrupts handled by VM).
    }
}

/// Handle exception (called from VM on exception).
/// Why: Process exceptions (illegal instruction, misaligned access, etc.).
/// Contract: Exception type must be valid, kernel must be initialized.
/// GrainStyle: Explicit error handling, bounded execution.
pub fn handle_exception(
    kernel: *BasinKernel,
    exception_type: ExceptionType,
    exception_pc: u64,
    exception_value: u64,
) void {
    // Assert: Kernel pointer must be valid (precondition).
    const kernel_ptr = @intFromPtr(kernel);
    Debug.kassert(kernel_ptr != 0, "Kernel ptr is null", .{});
    Debug.kassert(kernel_ptr % @alignOf(BasinKernel) == 0, "Kernel ptr unaligned", .{});
    
    // Assert: Exception type must be valid (precondition).
    const exception_id = @intFromEnum(exception_type);
    Debug.kassert(exception_id < 16, "Invalid exception type", .{});
    
    // Log exception (for debugging).
    // Why: Track exceptions for debugging and error recovery.
    Debug.kprint("kernel: exception {d} at PC=0x{x}, value=0x{x}\n", .{
        exception_id,
        exception_pc,
        exception_value,
    });
    
    // Handle exception based on type.
    // Why: Different exceptions require different handling.
    switch (exception_type) {
        .illegal_instruction => {
            // Illegal instruction: log and continue (or terminate process).
            // Why: Allow kernel to recover from invalid instructions.
            Debug.kprint("kernel: illegal instruction at PC=0x{x}\n", .{exception_pc});
        },
        .load_address_misaligned, .store_address_misaligned => {
            // Misaligned access: log and continue (or terminate process).
            // Why: Allow kernel to recover from misaligned accesses.
            Debug.kprint("kernel: misaligned access at PC=0x{x}, address=0x{x}\n", .{
                exception_pc,
                exception_value,
            });
        },
        .load_access_fault, .store_access_fault => {
            // Access fault: log and continue (or terminate process).
            // Why: Allow kernel to recover from access faults.
            Debug.kprint("kernel: access fault at PC=0x{x}, address=0x{x}\n", .{
                exception_pc,
                exception_value,
            });
        },
        .environment_call_from_u_mode, .environment_call_from_s_mode => {
            // Environment call (syscall): handled by VM's syscall handler.
            // Why: Syscalls are handled by VM, not trap loop.
            // Note: This should not be called from trap loop.
            Debug.kprint("kernel: environment call at PC=0x{x} (handled by VM)\n", .{exception_pc});
        },
        else => {
            // Other exceptions: log and continue.
            // Why: Handle unknown exceptions gracefully.
            Debug.kprint("kernel: unknown exception {d} at PC=0x{x}\n", .{
                exception_id,
                exception_pc,
            });
        },
    }
    
    // Assert: Exception must be handled (postcondition).
    // Note: In production, we might terminate the process or take other action.
}
