//! Grain Basin Process Scheduler
//! Why: Manage process execution, scheduling, and state transitions.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const ProcessState = @import("basin_kernel.zig").ProcessState;

/// Process scheduler for Grain Basin kernel.
/// Why: Manage process execution order and state management.
/// Grain Style: Static allocation, explicit state tracking.
pub const Scheduler = struct {
    /// Current running process ID (0 = no process running).
    /// Why: Track which process is currently executing.
    current_pid: u64,
    
    /// Next process to schedule (round-robin index).
    /// Why: Track position in round-robin scheduling.
    next_index: u32,
    
    /// Whether scheduler is initialized.
    /// Why: Track initialization state for safety.
    initialized: bool,
    
    /// Initialize scheduler.
    /// Why: Set up scheduler state.
    /// Contract: Must be called once at kernel boot.
    pub fn init() Scheduler {
        return Scheduler{
            .current_pid = 0,
            .next_index = 0,
            .initialized = true,
        };
    }
    
    /// Set current running process.
    /// Why: Update scheduler state when process starts.
    /// Contract: pid must be valid (non-zero).
    pub fn set_current(self: *Scheduler, pid: u64) void {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        // Assert: Process ID must be valid (non-zero).
        Debug.kassert(pid != 0, "Process ID is 0", .{});
        
        self.current_pid = pid;
        
        // Assert: Current PID must be set.
        Debug.kassert(self.current_pid == pid, "Current PID not set", .{});
    }
    
    /// Get current running process ID.
    /// Why: Query which process is currently executing.
    /// Contract: Returns 0 if no process running.
    pub fn get_current(self: *const Scheduler) u64 {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        return self.current_pid;
    }
    
    /// Clear current running process.
    /// Why: Update scheduler when process exits.
    /// Contract: Must be called when process terminates.
    pub fn clear_current(self: *Scheduler) void {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        // Assert: Current PID must be non-zero before clearing.
        Debug.kassert(self.current_pid != 0, "Current PID already 0", .{});
        
        self.current_pid = 0;
        
        // Assert: Current PID must be cleared.
        Debug.kassert(self.current_pid == 0, "Current PID not cleared", .{});
    }
    
    /// Find next runnable process (round-robin).
    /// Why: Select next process to execute in round-robin fashion.
    /// Contract: processes array must be valid, max_processes must be <= array length.
    /// Returns: Process ID if found, 0 if no runnable process.
    pub fn find_next_runnable(
        self: *Scheduler,
        processes: []const struct {
            id: u64,
            state: ProcessState,
            allocated: bool,
        },
        max_processes: u32,
    ) u64 {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        // Assert: max_processes must be <= array length.
        Debug.kassert(max_processes <= processes.len, "Max processes > array length", .{});
        
        // Round-robin: start from next_index, wrap around.
        var checked: u32 = 0;
        var idx: u32 = self.next_index;
        
        while (checked < max_processes) : (checked += 1) {
            // Assert: Index must be within bounds.
            Debug.kassert(idx < max_processes, "Index >= max_processes", .{});
            
            const process = processes[idx];
            
            // Check if process is runnable (allocated and running).
            if (process.allocated and process.state == .running) {
                // Update next_index for next round-robin.
                self.next_index = (idx + 1) % max_processes;
                
                // Assert: Process ID must be non-zero.
                Debug.kassert(process.id != 0, "Process ID is 0", .{});
                
                return process.id;
            }
            
            // Move to next index (wrap around).
            idx = (idx + 1) % max_processes;
        }
        
        // No runnable process found.
        return 0;
    }
    
    /// Check if process is current running process.
    /// Why: Validate process state for operations.
    /// Contract: pid must be valid (non-zero).
    pub fn is_current(self: *const Scheduler, pid: u64) bool {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        // Assert: Process ID must be valid (non-zero).
        Debug.kassert(pid != 0, "Process ID is 0", .{});
        
        return self.current_pid == pid;
    }
    
    /// Reset scheduler state.
    /// Why: Clear scheduler state (for testing or reinitialization).
    /// Contract: Must be called when all processes are terminated.
    pub fn reset(self: *Scheduler) void {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        self.current_pid = 0;
        self.next_index = 0;
        
        // Assert: Scheduler must be reset.
        Debug.kassert(self.current_pid == 0, "Current PID not reset", .{});
        Debug.kassert(self.next_index == 0, "Next index not reset", .{});
    }
};

// Test scheduler initialization.
test "scheduler init" {
    const scheduler = Scheduler.init();
    
    // Assert: Scheduler must be initialized.
    try std.testing.expect(scheduler.initialized);
    try std.testing.expect(scheduler.current_pid == 0);
    try std.testing.expect(scheduler.next_index == 0);
}

// Test set current process.
test "scheduler set current" {
    var scheduler = Scheduler.init();
    
    const pid: u64 = 1;
    scheduler.set_current(pid);
    
    // Assert: Current PID must be set.
    try std.testing.expect(scheduler.get_current() == pid);
    try std.testing.expect(scheduler.is_current(pid));
}

// Test clear current process.
test "scheduler clear current" {
    var scheduler = Scheduler.init();
    
    scheduler.set_current(1);
    scheduler.clear_current();
    
    // Assert: Current PID must be cleared.
    try std.testing.expect(scheduler.get_current() == 0);
    try std.testing.expect(!scheduler.is_current(1));
}

// Test find next runnable process.
test "scheduler find next runnable" {
    var scheduler = Scheduler.init();
    
    const Process = struct {
        id: u64,
        state: ProcessState,
        allocated: bool,
    };
    
    var processes = [_]Process{
        Process{ .id = 0, .state = .free, .allocated = false },
        Process{ .id = 1, .state = .running, .allocated = true },
        Process{ .id = 0, .state = .free, .allocated = false },
        Process{ .id = 2, .state = .running, .allocated = true },
    };
    
    const pid1 = scheduler.find_next_runnable(&processes, 4);
    
    // Assert: Must find first runnable process.
    try std.testing.expect(pid1 == 1);
    
    const pid2 = scheduler.find_next_runnable(&processes, 4);
    
    // Assert: Must find next runnable process (round-robin).
    try std.testing.expect(pid2 == 2);
}

// Test reset scheduler.
test "scheduler reset" {
    var scheduler = Scheduler.init();
    
    scheduler.set_current(1);
    scheduler.reset();
    
    // Assert: Scheduler must be reset.
    try std.testing.expect(scheduler.get_current() == 0);
    try std.testing.expect(scheduler.next_index == 0);
}

