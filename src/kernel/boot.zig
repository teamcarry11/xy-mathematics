//! Kernel Boot Sequence
//! Why: Ensure all kernel subsystems initialize in correct order with validation.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions, static allocation.

const std = @import("std");
const Debug = @import("debug.zig");
const BasinKernel = @import("basin_kernel.zig").BasinKernel;

/// Boot phase enumeration.
/// Why: Explicit boot phases for clear initialization order.
pub const BootPhase = enum(u32) {
    /// Early initialization (before subsystems).
    early = 0,
    /// Timer initialization (needed for time-based operations).
    timer = 1,
    /// Interrupt controller initialization (needed for interrupt handling).
    interrupt = 2,
    /// Memory pool initialization (needed for kernel allocations).
    memory = 3,
    /// Storage initialization (needed for file I/O).
    storage = 4,
    /// Scheduler initialization (needed for process management).
    scheduler = 5,
    /// IPC channels initialization (needed for inter-process communication).
    channels = 6,
    /// Input devices initialization (keyboard, mouse).
    input = 7,
    /// User management initialization.
    users = 8,
    /// Complete (all subsystems initialized).
    complete = 9,
};

/// Boot sequence state.
/// Why: Track boot progress and validate initialization order.
pub const BootSequence = struct {
    /// Current boot phase.
    /// Why: Track which phase we're in.
    current_phase: BootPhase = .early,
    
    /// Boot start timestamp (monotonic nanoseconds).
    /// Why: Measure boot time for diagnostics.
    boot_start_ns: u64 = 0,
    
    /// Boot complete timestamp (monotonic nanoseconds).
    /// Why: Measure boot time for diagnostics.
    boot_complete_ns: u64 = 0,
    
    /// Initialize boot sequence.
    /// Why: Start boot sequence tracking.
    pub fn init() BootSequence {
        return BootSequence{
            .current_phase = .early,
            .boot_start_ns = 0,
            .boot_complete_ns = 0,
        };
    }
    
    /// Start boot sequence.
    /// Why: Record boot start time and validate initial state.
    pub fn start(self: *BootSequence, timer: *const @import("timer.zig").Timer) void {
        // Assert: Boot sequence must be in early phase (precondition).
        Debug.kassert(self.current_phase == .early, "Boot not in early phase", .{});
        
        // Record boot start time.
        self.boot_start_ns = timer.get_monotonic_ns();
        
        // Assert: Boot start time must be valid (postcondition).
        Debug.kassert(self.boot_start_ns > 0, "Boot start time is zero", .{});
    }
    
    /// Advance to next boot phase.
    /// Why: Ensure phases are executed in correct order.
    pub fn advance(self: *BootSequence, next_phase: BootPhase) void {
        // Assert: Next phase must be after current phase (precondition).
        const current_val = @intFromEnum(self.current_phase);
        const next_val = @intFromEnum(next_phase);
        Debug.kassert(next_val > current_val, "Boot phase regression", .{});
        Debug.kassert(next_val <= @intFromEnum(BootPhase.complete), "Boot phase out of range", .{});
        
        self.current_phase = next_phase;
        
        // Assert: Phase must be updated (postcondition).
        Debug.kassert(self.current_phase == next_phase, "Phase not updated", .{});
    }
    
    /// Complete boot sequence.
    /// Why: Mark boot as complete and record completion time.
    pub fn complete(self: *BootSequence, timer: *const @import("timer.zig").Timer) void {
        // Assert: Boot must be in final phase before complete (precondition).
        Debug.kassert(self.current_phase == .users, "Boot not in users phase", .{});
        
        // Record boot completion time.
        self.boot_complete_ns = timer.get_monotonic_ns();
        
        // Advance to complete phase.
        self.current_phase = .complete;
        
        // Assert: Boot must be complete (postcondition).
        Debug.kassert(self.current_phase == .complete, "Boot not complete", .{});
        Debug.kassert(self.boot_complete_ns > self.boot_start_ns, "Boot time invalid", .{});
    }
    
    /// Get boot duration (nanoseconds).
    /// Why: Measure boot performance.
    pub fn get_boot_duration_ns(self: *const BootSequence) u64 {
        // Assert: Boot must be complete (precondition).
        Debug.kassert(self.current_phase == .complete, "Boot not complete", .{});
        Debug.kassert(self.boot_complete_ns > self.boot_start_ns, "Boot time invalid", .{});
        
        const duration = self.boot_complete_ns - self.boot_start_ns;
        
        // Assert: Duration must be positive (postcondition).
        Debug.kassert(duration > 0, "Boot duration is zero", .{});
        
        return duration;
    }
    
    /// Check if boot is complete.
    /// Why: Validate boot state for operations that require full initialization.
    pub fn is_complete(self: *const BootSequence) bool {
        return self.current_phase == .complete;
    }
};

/// Execute kernel boot sequence.
/// Why: Initialize all kernel subsystems in correct order with validation.
/// Contract: kernel must be uninitialized (all subsystems at default state).
/// Postcondition: All subsystems initialized, boot sequence complete.
pub fn boot_kernel(kernel: *BasinKernel) void {
    // Assert: Kernel timer must be initialized (precondition).
    Debug.kassert(kernel.timer.initialized, "Timer not initialized", .{});
    
    // Create boot sequence tracker.
    var boot = BootSequence.init();
    
    // Start boot sequence.
    boot.start(&kernel.timer);
    Debug.log(.info, "Boot sequence started", .{});
    
    // Phase 1: Timer (already initialized in BasinKernel.init()).
    // Why: Timer is needed for all time-based operations.
    Debug.kassert(kernel.timer.initialized, "Timer not initialized", .{});
    boot.advance(.timer);
    Debug.log(.info, "Boot phase: Timer initialized", .{});
    
    // Phase 2: Interrupt controller (already initialized).
    // Why: Interrupt controller is needed for interrupt handling.
    Debug.kassert(kernel.interrupt_controller.initialized, "Interrupt controller not initialized", .{});
    boot.advance(.interrupt);
    Debug.log(.info, "Boot phase: Interrupt controller initialized", .{});
    
    // Phase 3: Memory pool (already initialized).
    // Why: Memory pool is needed for kernel allocations.
    const MAX_PAGES: u32 = 1024; // From memory.zig
    Debug.kassert(kernel.memory_pool.allocated_pages <= MAX_PAGES, "Memory pool invalid", .{});
    boot.advance(.memory);
    Debug.log(.info, "Boot phase: Memory pool initialized", .{});
    
    // Phase 4: Storage (already initialized).
    // Why: Storage is needed for file I/O operations.
    const MAX_FILES: u32 = 128; // From storage.zig
    Debug.kassert(kernel.storage.file_count <= MAX_FILES, "Storage invalid", .{});
    boot.advance(.storage);
    Debug.log(.info, "Boot phase: Storage initialized", .{});
    
    // Phase 5: Scheduler (already initialized).
    // Why: Scheduler is needed for process management.
    Debug.kassert(kernel.scheduler.initialized, "Scheduler not initialized", .{});
    boot.advance(.scheduler);
    Debug.log(.info, "Boot phase: Scheduler initialized", .{});
    
    // Phase 6: IPC channels (already initialized).
    // Why: IPC channels are needed for inter-process communication.
    const MAX_CHANNELS: u32 = 64; // From channel.zig
    Debug.kassert(kernel.channels.channel_count <= MAX_CHANNELS, "Channels invalid", .{});
    boot.advance(.channels);
    Debug.log(.info, "Boot phase: IPC channels initialized", .{});
    
    // Phase 7: Input devices (already initialized).
    // Why: Input devices are needed for keyboard/mouse input.
    Debug.kassert(kernel.keyboard.last_key_code == 0, "Keyboard not initialized", .{});
    Debug.kassert(kernel.mouse.x == 0 and kernel.mouse.y == 0, "Mouse not initialized", .{});
    boot.advance(.input);
    Debug.log(.info, "Boot phase: Input devices initialized", .{});
    
    // Phase 8: Users (already initialized).
    // Why: Users are needed for permission checks.
    Debug.kassert(kernel.user_count >= 1, "No users initialized", .{});
    Debug.kassert(kernel.users[0].uid == 0, "Root user not initialized", .{});
    boot.advance(.users);
    Debug.log(.info, "Boot phase: Users initialized ({d} users)", .{kernel.user_count});
    
    // Complete boot sequence.
    boot.complete(&kernel.timer);
    const boot_duration_ns = boot.get_boot_duration_ns();
    const boot_duration_ms = boot_duration_ns / 1000000;
    Debug.log(.info, "Boot sequence complete ({d} ms)", .{boot_duration_ms});
    
    // Assert: Boot must be complete (postcondition).
    Debug.kassert(boot.is_complete(), "Boot not complete", .{});
    
    // Assert: All subsystems must be initialized (postcondition).
    Debug.kassert(kernel.timer.initialized, "Timer not initialized", .{});
    Debug.kassert(kernel.interrupt_controller.initialized, "Interrupt controller not initialized", .{});
    Debug.kassert(kernel.scheduler.initialized, "Scheduler not initialized", .{});
    Debug.kassert(kernel.user_count >= 1, "No users initialized", .{});
}

