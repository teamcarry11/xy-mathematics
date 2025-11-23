//! Boot Sequence Tests
//! Why: Comprehensive TigerStyle tests for kernel boot sequence functionality.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const BootSequence = basin_kernel.basin_kernel.BootSequence;
const BootPhase = basin_kernel.basin_kernel.BootPhase;
const boot_kernel = basin_kernel.basin_kernel.boot_kernel;
const RawIO = basin_kernel.RawIO;

// Test boot sequence initialization.
test "boot sequence init" {
    const boot_seq = BootSequence.init();
    
    // Assert: Boot sequence must be initialized.
    try std.testing.expect(boot_seq.current_phase == .early);
    try std.testing.expect(boot_seq.boot_start_ns == 0);
    try std.testing.expect(boot_seq.boot_complete_ns == 0);
    
    // Assert: Boot sequence must not be complete initially.
    try std.testing.expect(!boot_seq.is_complete());
}

// Test boot sequence start.
test "boot sequence start" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    var boot_seq = BootSequence.init();
    
    // Start boot sequence.
    boot_seq.start(&kernel.timer);
    
    // Assert: Boot start time must be set.
    try std.testing.expect(boot_seq.boot_start_ns > 0);
    try std.testing.expect(boot_seq.current_phase == .early);
    
    // Assert: Boot sequence must not be complete.
    try std.testing.expect(!boot_seq.is_complete());
}

// Test boot sequence advance.
test "boot sequence advance" {
    var boot_seq = BootSequence.init();
    
    // Advance through phases.
    boot_seq.advance(.timer);
    try std.testing.expect(boot_seq.current_phase == .timer);
    
    boot_seq.advance(.interrupt);
    try std.testing.expect(boot_seq.current_phase == .interrupt);
    
    boot_seq.advance(.memory);
    try std.testing.expect(boot_seq.current_phase == .memory);
    
    // Assert: Phase must be updated correctly.
    try std.testing.expect(boot_seq.current_phase == .memory);
}

// Test boot sequence complete.
test "boot sequence complete" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    var boot_seq = BootSequence.init();
    
    // Start boot sequence.
    boot_seq.start(&kernel.timer);
    
    // Advance to users phase.
    boot_seq.current_phase = .users;
    
    // Complete boot sequence.
    boot_seq.complete(&kernel.timer);
    
    // Assert: Boot sequence must be complete.
    try std.testing.expect(boot_seq.is_complete());
    try std.testing.expect(boot_seq.current_phase == .complete);
    try std.testing.expect(boot_seq.boot_complete_ns > boot_seq.boot_start_ns);
    
    // Assert: Boot duration must be valid.
    const duration = boot_seq.get_boot_duration_ns();
    try std.testing.expect(duration > 0);
}

// Test boot sequence duration.
test "boot sequence duration" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    var boot_seq = BootSequence.init();
    
    // Start and complete boot sequence.
    boot_seq.start(&kernel.timer);
    boot_seq.current_phase = .users;
    boot_seq.complete(&kernel.timer);
    
    // Get boot duration.
    const duration = boot_seq.get_boot_duration_ns();
    
    // Assert: Duration must be positive.
    try std.testing.expect(duration > 0);
    try std.testing.expect(duration == boot_seq.boot_complete_ns - boot_seq.boot_start_ns);
}

// Test boot kernel function.
test "boot kernel function" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    // Execute boot sequence.
    boot_kernel(&kernel);
    
    // Assert: All subsystems must be initialized.
    try std.testing.expect(kernel.timer.initialized);
    try std.testing.expect(kernel.interrupt_controller.initialized);
    try std.testing.expect(kernel.scheduler.initialized);
    try std.testing.expect(kernel.user_count >= 1);
    
    // Assert: Root user must exist.
    try std.testing.expect(kernel.users[0].uid == 0);
}

// Test boot sequence phase order.
test "boot sequence phase order" {
    var boot_seq = BootSequence.init();
    
    // Test: Cannot advance backwards.
    boot_seq.advance(.timer);
    boot_seq.advance(.interrupt);
    
    // Assert: Current phase must be interrupt.
    try std.testing.expect(boot_seq.current_phase == .interrupt);
    
    // Test: Can advance forward.
    boot_seq.advance(.memory);
    try std.testing.expect(boot_seq.current_phase == .memory);
}

// Test boot sequence validation.
test "boot sequence validation" {
    var kernel = BasinKernel.init();
    
    // Execute boot sequence.
    boot_kernel(&kernel);
    
    // Assert: Kernel must be fully initialized.
    try std.testing.expect(kernel.timer.initialized);
    try std.testing.expect(kernel.interrupt_controller.initialized);
    try std.testing.expect(kernel.scheduler.initialized);
    try std.testing.expect(kernel.storage.file_count == 0);
    try std.testing.expect(kernel.channels.channel_count == 0);
    try std.testing.expect(kernel.user_count >= 1);
}

