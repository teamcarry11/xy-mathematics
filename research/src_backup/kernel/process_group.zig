//! Process Group and Session Management
//! Why: Organize processes into groups and sessions for better management.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const Process = @import("basin_kernel.zig").Process;

/// Maximum number of process groups.
/// Why: Bounded allocation for process group tracking.
const MAX_PROCESS_GROUPS: u32 = 64;

/// Maximum number of sessions.
/// Why: Bounded allocation for session tracking.
const MAX_SESSIONS: u32 = 32;

/// Process group entry.
/// Why: Track process group membership and leader.
/// Grain Style: Static allocation, explicit types.
pub const ProcessGroup = struct {
    /// Process group ID (non-zero if allocated).
    pgid: u64,
    
    /// Session ID this group belongs to.
    sid: u64,
    
    /// Leader process ID (process that created the group).
    leader_pid: u64,
    
    /// Number of processes in this group.
    process_count: u32,
    
    /// Whether this entry is allocated (in use).
    allocated: bool,
    
    /// Initialize empty process group entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() ProcessGroup {
        return ProcessGroup{
            .pgid = 0,
            .sid = 0,
            .leader_pid = 0,
            .process_count = 0,
            .allocated = false,
        };
    }
};

/// Session entry.
/// Why: Track session membership and leader.
/// Grain Style: Static allocation, explicit types.
pub const Session = struct {
    /// Session ID (non-zero if allocated).
    sid: u64,
    
    /// Leader process ID (process that created the session).
    leader_pid: u64,
    
    /// Number of process groups in this session.
    group_count: u32,
    
    /// Whether this entry is allocated (in use).
    allocated: bool,
    
    /// Initialize empty session entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() Session {
        return Session{
            .sid = 0,
            .leader_pid = 0,
            .group_count = 0,
            .allocated = false,
        };
    }
};

/// Process group manager.
/// Why: Manage process groups and sessions.
/// Grain Style: Static allocation, bounded operations.
pub const ProcessGroupManager = struct {
    /// Process group table.
    groups: [MAX_PROCESS_GROUPS]ProcessGroup,
    
    /// Session table.
    sessions: [MAX_SESSIONS]Session,
    
    /// Next process group ID (simple allocator, starts at 1).
    next_pgid: u64,
    
    /// Next session ID (simple allocator, starts at 1).
    next_sid: u64,
    
    /// Whether manager is initialized.
    initialized: bool,
    
    /// Initialize process group manager.
    /// Why: Set up manager state.
    pub fn init() ProcessGroupManager {
        const manager = ProcessGroupManager{
            .groups = [_]ProcessGroup{ProcessGroup.init()} ** MAX_PROCESS_GROUPS,
            .sessions = [_]Session{Session.init()} ** MAX_SESSIONS,
            .next_pgid = 1,
            .next_sid = 1,
            .initialized = true,
        };
        
        return manager;
    }
    
    /// Create a new process group.
    /// Why: Create a process group for organizing processes.
    /// Contract: pid must be valid (non-zero), processes array must be valid.
    /// Returns: Process group ID if successful, 0 if failed.
    pub fn create_group(
        self: *ProcessGroupManager,
        pid: u64,
        sid: u64,
        processes: []Process,
        max_processes: u32,
    ) u64 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process ID must be valid (non-zero).
        Debug.kassert(pid != 0, "Process ID is 0", .{});
        
        // Assert: Session ID must be valid (non-zero).
        Debug.kassert(sid != 0, "Session ID is 0", .{});
        
        // Find empty slot in groups table.
        var idx: u32 = 0;
        while (idx < MAX_PROCESS_GROUPS) : (idx += 1) {
            if (!self.groups[idx].allocated) {
                const pgid = self.next_pgid;
                self.next_pgid += 1;
                
                // Initialize group entry.
                self.groups[idx].pgid = pgid;
                self.groups[idx].sid = sid;
                self.groups[idx].leader_pid = pid;
                self.groups[idx].process_count = 1;
                self.groups[idx].allocated = true;
                
                // Update process to belong to this group.
                self.set_process_group(pid, pgid, processes, max_processes);
                
                // Update session group count.
                self.increment_session_group_count(sid);
                
                return pgid;
            }
        }
        
        // No free slot found.
        return 0;
    }
    
    /// Set process group for a process.
    /// Why: Assign process to a process group.
    /// Contract: pid and pgid must be valid (non-zero).
    fn set_process_group(
        _: *ProcessGroupManager,
        pid: u64,
        pgid: u64,
        processes: []Process,
        max_processes: u32,
    ) void {
        // Find process in process table.
        var idx: u32 = 0;
        while (idx < max_processes) : (idx += 1) {
            if (processes[idx].allocated and processes[idx].id == pid) {
                // Update process group ID.
                processes[idx].pgid = pgid;
                break;
            }
        }
    }
    
    /// Increment session group count.
    /// Why: Track number of groups in a session.
    /// Contract: sid must be valid (non-zero).
    fn increment_session_group_count(self: *ProcessGroupManager, sid: u64) void {
        // Find session in sessions table.
        var idx: u32 = 0;
        while (idx < MAX_SESSIONS) : (idx += 1) {
            if (self.sessions[idx].allocated and self.sessions[idx].sid == sid) {
                self.sessions[idx].group_count += 1;
                break;
            }
        }
    }
    
    /// Create a new session.
    /// Why: Create a session for organizing process groups.
    /// Contract: pid must be valid (non-zero).
    /// Returns: Session ID if successful, 0 if failed.
    pub fn create_session(self: *ProcessGroupManager, pid: u64) u64 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process ID must be valid (non-zero).
        Debug.kassert(pid != 0, "Process ID is 0", .{});
        
        // Find empty slot in sessions table.
        var idx: u32 = 0;
        while (idx < MAX_SESSIONS) : (idx += 1) {
            if (!self.sessions[idx].allocated) {
                const sid = self.next_sid;
                self.next_sid += 1;
                
                // Initialize session entry.
                self.sessions[idx].sid = sid;
                self.sessions[idx].leader_pid = pid;
                self.sessions[idx].group_count = 0;
                self.sessions[idx].allocated = true;
                
                return sid;
            }
        }
        
        // No free slot found.
        return 0;
    }
    
    /// Get process group ID for a process.
    /// Why: Query which process group a process belongs to.
    /// Contract: pid must be valid (non-zero).
    /// Returns: Process group ID if found, 0 if not found.
    pub fn get_process_group(
        self: *const ProcessGroupManager,
        pid: u64,
        processes: []const Process,
        max_processes: u32,
    ) u64 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Find process in process table.
        var idx: u32 = 0;
        while (idx < max_processes) : (idx += 1) {
            if (processes[idx].allocated and processes[idx].id == pid) {
                // Return process group ID from process struct.
                return processes[idx].pgid;
            }
        }
        
        return 0; // Process not found.
    }
    
    /// Get session ID for a process.
    /// Why: Query which session a process belongs to.
    /// Contract: pid must be valid (non-zero).
    /// Returns: Session ID if found, 0 if not found.
    pub fn get_session(
        self: *const ProcessGroupManager,
        pid: u64,
        processes: []const Process,
        max_processes: u32,
    ) u64 {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Find process in process table.
        var idx: u32 = 0;
        while (idx < max_processes) : (idx += 1) {
            if (processes[idx].allocated and processes[idx].id == pid) {
                // Return session ID from process struct.
                return processes[idx].sid;
            }
        }
        
        return 0; // Process not found.
    }
    
    /// Reset manager state.
    /// Why: Clear manager state (for testing or reinitialization).
    pub fn reset(self: *ProcessGroupManager) void {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Reset all groups.
        var idx: u32 = 0;
        while (idx < MAX_PROCESS_GROUPS) : (idx += 1) {
            self.groups[idx] = ProcessGroup.init();
        }
        
        // Reset all sessions.
        idx = 0;
        while (idx < MAX_SESSIONS) : (idx += 1) {
            self.sessions[idx] = Session.init();
        }
        
        self.next_pgid = 1;
        self.next_sid = 1;
    }
};

// Test: process group manager initialization.
test "process group manager init" {
    const manager = ProcessGroupManager.init();
    
    // Assert: Manager must be initialized.
    try std.testing.expect(manager.initialized);
    try std.testing.expect(manager.next_pgid == 1);
    try std.testing.expect(manager.next_sid == 1);
}

// Test: create session.
test "process group manager create session" {
    var manager = ProcessGroupManager.init();
    
    const sid = manager.create_session(1);
    
    // Assert: Session must be created.
    try std.testing.expect(sid != 0);
    try std.testing.expect(sid == 1);
}

// Test: create process group.
test "process group manager create group" {
    var manager = ProcessGroupManager.init();
    
    const sid = manager.create_session(1);
    const pgid = manager.create_group(1, sid, &[_]Process{}, 0);
    
    // Assert: Process group must be created.
    try std.testing.expect(pgid != 0);
    try std.testing.expect(pgid == 1);
}

