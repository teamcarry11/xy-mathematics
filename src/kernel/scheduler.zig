//! Grain Basin Process Scheduler
//! Why: Manage process execution, scheduling, and state transitions.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const ProcessState = @import("basin_kernel.zig").ProcessState;
const Process = @import("basin_kernel.zig").Process;

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
    
    /// Time slice remaining for current process (instruction steps).
    /// Why: Track remaining time before preemption.
    time_slice_remaining: u64,
    
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
            .time_slice_remaining = 0,
            .initialized = true,
        };
    }
    
    /// Set current running process with time slice.
    /// Why: Update scheduler state when process starts.
    /// Contract: pid must be valid (non-zero), time_slice must be > 0.
    pub fn set_current(self: *Scheduler, pid: u64, time_slice: u64) void {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        // Assert: Process ID must be valid (non-zero).
        Debug.kassert(pid != 0, "Process ID is 0", .{});
        
        // Assert: Time slice must be positive.
        Debug.kassert(time_slice > 0, "Time slice must be > 0", .{});
        
        self.current_pid = pid;
        self.time_slice_remaining = time_slice;
        
        // Assert: Current PID must be set.
        Debug.kassert(self.current_pid == pid, "Current PID not set", .{});
        
        // Assert: Time slice must be set.
        Debug.kassert(self.time_slice_remaining == time_slice, "Time slice not set", .{});
    }
    
    /// Decrement time slice for current process.
    /// Why: Track time slice usage during execution.
    /// Contract: Must be called during process execution.
    /// Returns: true if time slice expired, false otherwise.
    pub fn decrement_time_slice(self: *Scheduler, steps: u64) bool {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        // Assert: Current PID must be set.
        Debug.kassert(self.current_pid != 0, "Current PID is 0", .{});
        
        // Decrement time slice (saturating subtract to prevent underflow).
        if (self.time_slice_remaining > steps) {
            self.time_slice_remaining -= steps;
            return false;
        } else {
            // Time slice expired.
            self.time_slice_remaining = 0;
            return true;
        }
    }
    
    /// Check if current process time slice expired.
    /// Why: Determine if process should be preempted.
    /// Contract: Must be called during process execution.
    /// Returns: true if time slice expired, false otherwise.
    pub fn is_time_slice_expired(self: *const Scheduler) bool {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        return self.time_slice_remaining == 0;
    }
    
    /// Get remaining time slice for current process.
    /// Why: Query remaining time before preemption.
    /// Contract: Returns 0 if no process running or time slice expired.
    pub fn get_time_slice_remaining(self: *const Scheduler) u64 {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        return self.time_slice_remaining;
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
        self.time_slice_remaining = 0;
        
        // Assert: Current PID must be cleared.
        Debug.kassert(self.current_pid == 0, "Current PID not cleared", .{});
        
        // Assert: Time slice must be cleared.
        Debug.kassert(self.time_slice_remaining == 0, "Time slice not cleared", .{});
    }
    
    /// Find next runnable process (priority-based with round-robin fallback).
    /// Why: Select highest priority process, using round-robin for same priority.
    /// Contract: processes array must be valid, max_processes must be <= array length.
    /// Returns: Process ID if found, 0 if no runnable process.
    pub fn find_next_runnable(
        self: *Scheduler,
        processes: []const Process,
        max_processes: u32,
    ) u64 {
        // Assert: Scheduler must be initialized.
        Debug.kassert(self.initialized, "Scheduler not initialized", .{});
        
        // Assert: max_processes must be <= array length.
        Debug.kassert(max_processes <= processes.len, "Max processes > array length", .{});
        
        // Find highest priority runnable process.
        var best_priority: i8 = 20; // Start with lowest priority (highest nice value).
        var best_pid: u64 = 0;
        var best_idx: u32 = 0;
        var found_count: u32 = 0;
        
        // First pass: find highest priority (lowest nice value).
        var idx: u32 = 0;
        while (idx < max_processes) : (idx += 1) {
            const process = processes[idx];
            
            // Check if process is runnable (allocated and running).
            if (process.id != 0 and process.state == .running) {
                const priority = process.priority;
                
                // Lower nice value = higher priority.
                if (priority < best_priority) {
                    best_priority = priority;
                    best_pid = process.id;
                    best_idx = idx;
                    found_count = 1;
                } else if (priority == best_priority) {
                    found_count += 1;
                }
            }
        }
        
        // If no runnable process found, return 0.
        if (best_pid == 0) {
            return 0;
        }
        
        // If only one process with best priority, return it.
        if (found_count == 1) {
            self.next_index = (best_idx + 1) % max_processes;
            return best_pid;
        }
        
        // Multiple processes with same priority: use round-robin.
        return self.find_next_runnable_round_robin(processes, max_processes, best_priority);
    }
    
    /// Find next runnable process with specific priority (round-robin).
    /// Why: Round-robin among processes with same priority.
    /// Contract: processes array must be valid, max_processes must be <= array length.
    /// Returns: Process ID if found, 0 if no runnable process.
    fn find_next_runnable_round_robin(
        self: *Scheduler,
        processes: []const Process,
        max_processes: u32,
        target_priority: i8,
    ) u64 {
        // Round-robin: start from next_index, wrap around.
        var checked: u32 = 0;
        var idx: u32 = self.next_index;
        
        while (checked < max_processes) : (checked += 1) {
            // Assert: Index must be within bounds.
            Debug.kassert(idx < max_processes, "Index >= max_processes", .{});
            
            const process = processes[idx];
            
            // Check if process is runnable with target priority.
            if (process.id != 0 and process.state == .running and process.priority == target_priority) {
                // Update next_index for next round-robin.
                self.next_index = (idx + 1) % max_processes;
                
                // Assert: Process ID must be non-zero.
                Debug.kassert(process.id != 0, "Process ID is 0", .{});
                
                return process.id;
            }
            
            // Move to next index (wrap around).
            idx = (idx + 1) % max_processes;
        }
        
        // No runnable process found with target priority.
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
        self.time_slice_remaining = 0;
        
        // Assert: Scheduler must be reset.
        Debug.kassert(self.current_pid == 0, "Current PID not reset", .{});
        Debug.kassert(self.next_index == 0, "Next index not reset", .{});
        Debug.kassert(self.time_slice_remaining == 0, "Time slice not reset", .{});
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
    const time_slice: u64 = 1000;
    scheduler.set_current(pid, time_slice);
    
    // Assert: Current PID must be set.
    try std.testing.expect(scheduler.get_current() == pid);
    try std.testing.expect(scheduler.is_current(pid));
    try std.testing.expect(scheduler.get_time_slice_remaining() == time_slice);
}

// Test clear current process.
test "scheduler clear current" {
    var scheduler = Scheduler.init();
    
    scheduler.set_current(1, 1000);
    scheduler.clear_current();
    
    // Assert: Current PID must be cleared.
    try std.testing.expect(scheduler.get_current() == 0);
    try std.testing.expect(!scheduler.is_current(1));
    try std.testing.expect(scheduler.get_time_slice_remaining() == 0);
}

// Test find next runnable process (priority-based).
test "scheduler find next runnable priority" {
    var scheduler = Scheduler.init();
    
    // Create processes with different priorities.
    var processes = [_]Process{
        Process.init(),
        Process.init(),
        Process.init(),
        Process.init(),
    };
    
    // Process 1: priority -10 (high priority).
    processes[0].id = 1;
    processes[0].state = .running;
    processes[0].allocated = true;
    processes[0].priority = -10;
    
    // Process 2: priority 0 (normal priority).
    processes[1].id = 2;
    processes[1].state = .running;
    processes[1].allocated = true;
    processes[1].priority = 0;
    
    // Process 3: priority 10 (low priority).
    processes[2].id = 3;
    processes[2].state = .running;
    processes[2].allocated = true;
    processes[2].priority = 10;
    
    // Process 4: not allocated.
    processes[3].id = 0;
    processes[3].state = .free;
    
    // Should select process 1 (highest priority, -10).
    const pid1 = scheduler.find_next_runnable(&processes, 4);
    try std.testing.expect(pid1 == 1);
    
    // Process 1 exits, should select process 2 (priority 0).
    processes[0].state = .exited;
    const pid2 = scheduler.find_next_runnable(&processes, 4);
    try std.testing.expect(pid2 == 2);
}

// Test find next runnable process (round-robin for same priority).
test "scheduler find next runnable round robin" {
    var scheduler = Scheduler.init();
    
    // Create processes with same priority.
    var processes = [_]Process{
        Process.init(),
        Process.init(),
        Process.init(),
    };
    
    // All processes have priority 0.
    processes[0].id = 1;
    processes[0].state = .running;
    processes[0].allocated = true;
    processes[0].priority = 0;
    
    processes[1].id = 2;
    processes[1].state = .running;
    processes[1].allocated = true;
    processes[1].priority = 0;
    
    processes[2].id = 3;
    processes[2].state = .running;
    processes[2].allocated = true;
    processes[2].priority = 0;
    
    // Should round-robin through processes with same priority.
    const pid1 = scheduler.find_next_runnable(&processes, 3);
    try std.testing.expect(pid1 == 1 or pid1 == 2 or pid1 == 3);
    
    const pid2 = scheduler.find_next_runnable(&processes, 3);
    try std.testing.expect(pid2 == 1 or pid2 == 2 or pid2 == 3);
    try std.testing.expect(pid2 != pid1); // Should be different.
}

// Test reset scheduler.
test "scheduler reset" {
    var scheduler = Scheduler.init();
    
    scheduler.set_current(1, 1000);
    scheduler.reset();
    
    // Assert: Scheduler must be reset.
    try std.testing.expect(scheduler.get_current() == 0);
    try std.testing.expect(scheduler.next_index == 0);
    try std.testing.expect(scheduler.time_slice_remaining == 0);
}

// Test time slice decrement.
test "scheduler decrement time slice" {
    var scheduler = Scheduler.init();
    
    scheduler.set_current(1, 1000);
    
    // Decrement by 100 steps.
    const expired1 = scheduler.decrement_time_slice(100);
    try std.testing.expect(!expired1);
    try std.testing.expect(scheduler.get_time_slice_remaining() == 900);
    
    // Decrement by 900 steps (should expire).
    const expired2 = scheduler.decrement_time_slice(900);
    try std.testing.expect(expired2);
    try std.testing.expect(scheduler.get_time_slice_remaining() == 0);
    try std.testing.expect(scheduler.is_time_slice_expired());
    
    // Test saturating subtract (decrement beyond 0).
    const expired3 = scheduler.decrement_time_slice(100);
    try std.testing.expect(expired3);
    try std.testing.expect(scheduler.get_time_slice_remaining() == 0);
}

// Test time slice expiration check.
test "scheduler time slice expiration" {
    var scheduler = Scheduler.init();
    
    scheduler.set_current(1, 1000);
    try std.testing.expect(!scheduler.is_time_slice_expired());
    
    const expired = scheduler.decrement_time_slice(1000);
    try std.testing.expect(expired);
    try std.testing.expect(scheduler.is_time_slice_expired());
}

