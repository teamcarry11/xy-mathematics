//! Trap Handler Loop
//! Why: Main kernel loop for handling interrupts and syscalls.
//! Grain Style: Explicit state tracking, bounded execution.

const Panic = @import("panic.zig");
const InterruptController = @import("interrupt.zig").InterruptController;

/// Trap loop (main kernel loop).
/// Why: Process interrupts and handle syscalls in main loop.
/// Contract: Must be called from kernel main, runs indefinitely.
/// Note: In VM, syscalls are handled by VM's syscall handler.
///       This loop processes pending interrupts.
pub fn loop() noreturn {
    Panic.write("grain kernel: entering trap loop\n");
    
    // Note: In VM environment, interrupt controller is part of kernel.
    // Interrupts are processed via kernel.interrupt_controller.process_pending().
    // This loop is a placeholder for future interrupt processing.
    
    while (true) {
        // TODO: Process pending interrupts when kernel reference is available.
        // For now, this is a simple infinite loop.
        // In full implementation, we would:
        // - Get kernel reference (from global or parameter)
        // - Call kernel.interrupt_controller.process_pending()
        // - Handle syscalls (via VM's syscall handler)
        // - Yield CPU if no work (cooperative scheduling)
    }
}
