//! Process Group Resource Limits
//! Why: Enforce resource limits per process group for resource management.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Maximum number of process group limit entries.
/// Why: Bounded allocation for limit tracking.
const MAX_PROCESS_GROUP_LIMITS: u32 = 64;

/// Resource limit entry for a process group.
/// Why: Track and enforce resource limits per process group.
/// Grain Style: Static allocation, explicit types.
pub const ProcessGroupLimits = struct {
    /// Process group ID.
    pgid: u64,
    
    /// Maximum CPU time allowed (nanoseconds, 0 = unlimited).
    max_cpu_time_ns: u64,
    
    /// Maximum memory allowed (bytes, 0 = unlimited).
    max_memory_bytes: u64,
    
    /// Maximum number of processes allowed (0 = unlimited).
    max_process_count: u32,
    
    /// Whether this entry is allocated (in use).
    allocated: bool,
    
    /// Initialize empty process group limits entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() ProcessGroupLimits {
        return ProcessGroupLimits{
            .pgid = 0,
            .max_cpu_time_ns = 0, // Unlimited by default
            .max_memory_bytes = 0, // Unlimited by default
            .max_process_count = 0, // Unlimited by default
            .allocated = false,
        };
    }
    
    /// Check if CPU time limit is exceeded.
    /// Why: Enforce CPU time limits.
    /// Contract: current_cpu_time_ns must be valid.
    pub fn is_cpu_time_exceeded(
        self: *const ProcessGroupLimits,
        current_cpu_time_ns: u64,
    ) bool {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        // If limit is 0 (unlimited), never exceeded.
        if (self.max_cpu_time_ns == 0) {
            return false;
        }
        
        // Check if current usage exceeds limit.
        return current_cpu_time_ns > self.max_cpu_time_ns;
    }
    
    /// Check if memory limit is exceeded.
    /// Why: Enforce memory limits.
    /// Contract: current_memory_bytes must be valid.
    pub fn is_memory_exceeded(
        self: *const ProcessGroupLimits,
        current_memory_bytes: u64,
    ) bool {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        // If limit is 0 (unlimited), never exceeded.
        if (self.max_memory_bytes == 0) {
            return false;
        }
        
        // Check if current usage exceeds limit.
        return current_memory_bytes > self.max_memory_bytes;
    }
    
    /// Check if process count limit is exceeded.
    /// Why: Enforce process count limits.
    /// Contract: current_process_count must be valid.
    pub fn is_process_count_exceeded(
        self: *const ProcessGroupLimits,
        current_process_count: u32,
    ) bool {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        // If limit is 0 (unlimited), never exceeded.
        if (self.max_process_count == 0) {
            return false;
        }
        
        // Check if current count exceeds limit.
        return current_process_count >= self.max_process_count;
    }
};

/// Process group limits manager.
/// Why: Manage resource limits for all process groups.
/// Grain Style: Static allocation, bounded operations.
pub const ProcessGroupLimitsManager = struct {
    /// Limit entries.
    limits: [MAX_PROCESS_GROUP_LIMITS]ProcessGroupLimits,
    
    /// Whether manager is initialized.
    initialized: bool,
    
    /// Initialize process group limits manager.
    /// Why: Set up manager state.
    pub fn init() ProcessGroupLimitsManager {
        const manager = ProcessGroupLimitsManager{
            .limits = [_]ProcessGroupLimits{ProcessGroupLimits.init()} ** MAX_PROCESS_GROUP_LIMITS,
            .initialized = true,
        };
        
        return manager;
    }
    
    /// Get or create limits entry for a process group.
    /// Why: Track limits for a process group.
    /// Contract: pgid must be valid (non-zero).
    /// Returns: Pointer to limits entry, or null if no free slot.
    pub fn get_or_create_limits(
        self: *ProcessGroupLimitsManager,
        pgid: u64,
    ) ?*ProcessGroupLimits {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        // Try to find existing entry for this process group.
        var idx: u32 = 0;
        while (idx < MAX_PROCESS_GROUP_LIMITS) : (idx += 1) {
            if (self.limits[idx].allocated and self.limits[idx].pgid == pgid) {
                return &self.limits[idx];
            }
        }
        
        // No existing entry found, create new one.
        idx = 0;
        while (idx < MAX_PROCESS_GROUP_LIMITS) : (idx += 1) {
            if (!self.limits[idx].allocated) {
                self.limits[idx].pgid = pgid;
                self.limits[idx].max_cpu_time_ns = 0; // Unlimited by default
                self.limits[idx].max_memory_bytes = 0; // Unlimited by default
                self.limits[idx].max_process_count = 0; // Unlimited by default
                self.limits[idx].allocated = true;
                
                return &self.limits[idx];
            }
        }
        
        // No free slot found.
        return null;
    }
    
    /// Get limits entry for a process group.
    /// Why: Retrieve limits for a process group.
    /// Contract: pgid must be valid (non-zero).
    /// Returns: Pointer to limits entry, or null if not found.
    pub fn get_limits(
        self: *const ProcessGroupLimitsManager,
        pgid: u64,
    ) ?*const ProcessGroupLimits {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        // Find existing entry for this process group.
        var idx: u32 = 0;
        while (idx < MAX_PROCESS_GROUP_LIMITS) : (idx += 1) {
            if (self.limits[idx].allocated and self.limits[idx].pgid == pgid) {
                return &self.limits[idx];
            }
        }
        
        // Entry not found.
        return null;
    }
    
    /// Set CPU time limit for a process group.
    /// Why: Configure CPU time limits.
    /// Contract: pgid must be valid (non-zero), max_cpu_time_ns must be valid.
    pub fn set_cpu_time_limit(
        self: *ProcessGroupLimitsManager,
        pgid: u64,
        max_cpu_time_ns: u64,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const limits_entry = self.get_or_create_limits(pgid);
        if (limits_entry) |entry| {
            entry.max_cpu_time_ns = max_cpu_time_ns;
            return true;
        }
        
        return false;
    }
    
    /// Set memory limit for a process group.
    /// Why: Configure memory limits.
    /// Contract: pgid must be valid (non-zero), max_memory_bytes must be valid.
    pub fn set_memory_limit(
        self: *ProcessGroupLimitsManager,
        pgid: u64,
        max_memory_bytes: u64,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const limits_entry = self.get_or_create_limits(pgid);
        if (limits_entry) |entry| {
            entry.max_memory_bytes = max_memory_bytes;
            return true;
        }
        
        return false;
    }
    
    /// Set process count limit for a process group.
    /// Why: Configure process count limits.
    /// Contract: pgid must be valid (non-zero), max_process_count must be valid.
    pub fn set_process_count_limit(
        self: *ProcessGroupLimitsManager,
        pgid: u64,
        max_process_count: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const limits_entry = self.get_or_create_limits(pgid);
        if (limits_entry) |entry| {
            entry.max_process_count = max_process_count;
            return true;
        }
        
        return false;
    }
    
    /// Check if process group can spawn a new process.
    /// Why: Enforce process count limits before spawning.
    /// Contract: pgid and current_process_count must be valid.
    pub fn can_spawn_process(
        self: *const ProcessGroupLimitsManager,
        pgid: u64,
        current_process_count: u32,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // If no process group (pgid == 0), allow spawn.
        if (pgid == 0) {
            return true;
        }
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const limits_entry = self.get_limits(pgid);
        if (limits_entry) |entry| {
            // Check if adding one more process would exceed limit.
            const new_count = current_process_count + 1;
            return !entry.is_process_count_exceeded(new_count);
        }
        
        // No limits set, allow spawn.
        return true;
    }
    
    /// Check if process group can allocate memory.
    /// Why: Enforce memory limits before memory allocation.
    /// Contract: pgid, current_memory_bytes, and requested_bytes must be valid.
    pub fn can_allocate_memory(
        self: *const ProcessGroupLimitsManager,
        pgid: u64,
        current_memory_bytes: u64,
        requested_bytes: u64,
    ) bool {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // If no process group (pgid == 0), allow allocation.
        if (pgid == 0) {
            return true;
        }
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const limits_entry = self.get_limits(pgid);
        if (limits_entry) |entry| {
            // Check if adding requested bytes would exceed limit.
            const new_memory = current_memory_bytes +% requested_bytes; // Saturating add
            return !entry.is_memory_exceeded(new_memory);
        }
        
        // No limits set, allow allocation.
        return true;
    }
};

