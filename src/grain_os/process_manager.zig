//! Grain OS Process Manager: Process tracking and lifecycle management.
//!
//! Why: Provide process management for tracking and controlling processes.
//! Architecture: Process tracking, lifecycle management, process information.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const basin_kernel = @import("basin_kernel");

// Bounded: Max processes.
pub const MAX_PROCESSES: u32 = 256;

// Bounded: Max process name length.
pub const MAX_PROCESS_NAME_LEN: u32 = 128;

// Bounded: Max command line length.
pub const MAX_CMD_LINE_LEN: u32 = 512;

// Process state.
pub const ProcessState = enum(u8) {
    unknown,
    running,
    sleeping,
    stopped,
    zombie,
    dead,
};

// Process priority.
pub const ProcessPriority = enum(u8) {
    low,
    normal,
    high,
    realtime,
};

// Process: represents a system process.
pub const Process = struct {
    process_id: u32,
    parent_process_id: u32,
    name: [MAX_PROCESS_NAME_LEN]u8,
    name_len: u32,
    cmd_line: [MAX_CMD_LINE_LEN]u8,
    cmd_line_len: u32,
    state: ProcessState,
    priority: ProcessPriority,
    cpu_usage: f64, // CPU usage percentage.
    memory_usage: u64, // Memory usage in bytes.
    start_time: u64, // Process start timestamp.
    active: bool,

    pub fn init() Process {
        var proc = Process{
            .process_id = 0,
            .parent_process_id = 0,
            .name = undefined,
            .name_len = 0,
            .cmd_line = undefined,
            .cmd_line_len = 0,
            .state = ProcessState.unknown,
            .priority = ProcessPriority.normal,
            .cpu_usage = 0.0,
            .memory_usage = 0,
            .start_time = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_PROCESS_NAME_LEN) : (i += 1) {
            proc.name[i] = 0;
        }
        i = 0;
        while (i < MAX_CMD_LINE_LEN) : (i += 1) {
            proc.cmd_line[i] = 0;
        }
        return proc;
    }
};

// Syscall function type.
const SyscallFn = *const fn (u32, u64, u64, u64, u64) i64;

// Process manager: manages system processes.
pub const ProcessManager = struct {
    processes: [MAX_PROCESSES]Process,
    processes_len: u32,
    next_process_id: u32,
    syscall_fn: ?SyscallFn,

    pub fn init() ProcessManager {
        var manager = ProcessManager{
            .processes = undefined,
            .processes_len = 0,
            .next_process_id = 1,
            .syscall_fn = null,
        };
        var i: u32 = 0;
        while (i < MAX_PROCESSES) : (i += 1) {
            manager.processes[i] = Process.init();
        }
        return manager;
    }

    // Add process.
    pub fn add_process(
        self: *ProcessManager,
        parent_process_id: u32,
        name: []const u8,
        cmd_line: []const u8,
        start_time: u64,
    ) ?u32 {
        if (self.processes_len >= MAX_PROCESSES) {
            return null;
        }
        if (name.len > MAX_PROCESS_NAME_LEN) {
            return null;
        }
        if (cmd_line.len > MAX_CMD_LINE_LEN) {
            return null;
        }
        const process_id = self.next_process_id;
        self.next_process_id += 1;
        self.processes[self.processes_len] = Process.init();
        self.processes[self.processes_len].process_id = process_id;
        self.processes[self.processes_len].parent_process_id = parent_process_id;
        self.processes[self.processes_len].state = ProcessState.running;
        self.processes[self.processes_len].active = true;
        var i: u32 = 0;
        while (i < MAX_PROCESS_NAME_LEN) : (i += 1) {
            self.processes[self.processes_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_PROCESS_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.processes[self.processes_len].name[i] = name[i];
        }
        self.processes[self.processes_len].name_len = @intCast(name_len);
        i = 0;
        while (i < MAX_CMD_LINE_LEN) : (i += 1) {
            self.processes[self.processes_len].cmd_line[i] = 0;
        }
        const cmd_line_len = @min(cmd_line.len, MAX_CMD_LINE_LEN);
        i = 0;
        while (i < cmd_line_len) : (i += 1) {
            self.processes[self.processes_len].cmd_line[i] = cmd_line[i];
        }
        self.processes[self.processes_len].cmd_line_len = @intCast(cmd_line_len);
        self.processes[self.processes_len].start_time = start_time;
        self.processes_len += 1;
        return process_id;
    }

    // Find process by ID.
    pub fn find_process(
        self: *ProcessManager,
        process_id: u32,
    ) ?*Process {
        std.debug.assert(process_id > 0);
        var i: u32 = 0;
        while (i < self.processes_len) : (i += 1) {
            if (self.processes[i].process_id == process_id and self.processes[i].active) {
                return &self.processes[i];
            }
        }
        return null;
    }

    // Set process state.
    pub fn set_process_state(
        self: *ProcessManager,
        process_id: u32,
        state: ProcessState,
    ) bool {
        std.debug.assert(process_id > 0);
        if (self.find_process(process_id)) |proc| {
            proc.state = state;
            return true;
        }
        return false;
    }

    // Set process priority.
    pub fn set_process_priority(
        self: *ProcessManager,
        process_id: u32,
        priority: ProcessPriority,
    ) bool {
        std.debug.assert(process_id > 0);
        if (self.find_process(process_id)) |proc| {
            proc.priority = priority;
            return true;
        }
        return false;
    }

    // Update process CPU usage.
    pub fn update_process_cpu_usage(
        self: *ProcessManager,
        process_id: u32,
        cpu_usage: f64,
    ) bool {
        std.debug.assert(process_id > 0);
        std.debug.assert(cpu_usage >= 0.0);
        std.debug.assert(cpu_usage <= 100.0);
        if (self.find_process(process_id)) |proc| {
            proc.cpu_usage = cpu_usage;
            return true;
        }
        return false;
    }

    // Update process memory usage.
    pub fn update_process_memory_usage(
        self: *ProcessManager,
        process_id: u32,
        memory_usage: u64,
    ) bool {
        std.debug.assert(process_id > 0);
        if (self.find_process(process_id)) |proc| {
            proc.memory_usage = memory_usage;
            return true;
        }
        return false;
    }

    // Remove process.
    pub fn remove_process(self: *ProcessManager, process_id: u32) bool {
        std.debug.assert(process_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.processes_len) : (i += 1) {
            if (self.processes[i].process_id == process_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining processes left.
        while (i < self.processes_len - 1) : (i += 1) {
            self.processes[i] = self.processes[i + 1];
        }
        self.processes_len -= 1;
        return true;
    }

    // Get process count.
    pub fn get_process_count(self: *const ProcessManager) u32 {
        return self.processes_len;
    }

    // Get running process count.
    pub fn get_running_process_count(self: *const ProcessManager) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.processes_len) : (i += 1) {
            if (self.processes[i].state == ProcessState.running) {
                count += 1;
            }
        }
        return count;
    }

    // Set syscall function.
    pub fn set_syscall_fn(self: *ProcessManager, fn_ptr: SyscallFn) void {
        std.debug.assert(@intFromPtr(fn_ptr) != 0);
        self.syscall_fn = fn_ptr;
    }

    // Spawn process using kernel spawn syscall.
    pub fn spawn_process(
        self: *ProcessManager,
        parent_process_id: u32,
        name: []const u8,
        cmd_line: []const u8,
        start_time: u64,
    ) ?u32 {
        if (self.syscall_fn == null) {
            return null;
        }
        if (name.len > MAX_PROCESS_NAME_LEN) {
            return null;
        }
        if (cmd_line.len > MAX_CMD_LINE_LEN) {
            return null;
        }
        var path_buf: [MAX_CMD_LINE_LEN]u8 = undefined;
        var i: u32 = 0;
        while (i < MAX_CMD_LINE_LEN) : (i += 1) {
            path_buf[i] = 0;
        }
        const path_len = @min(cmd_line.len, MAX_CMD_LINE_LEN);
        i = 0;
        while (i < path_len) : (i += 1) {
            path_buf[i] = cmd_line[i];
        }
        const path_ptr = @intFromPtr(&path_buf);
        const path_len_u64: u64 = path_len;
        const result = self.syscall_fn.?(@intFromEnum(basin_kernel.Syscall.spawn), path_ptr, path_len_u64, 0, 0);
        if (result < 0) {
            return null;
        }
        const kernel_pid = @as(u32, @intCast(result));
        if (self.processes_len >= MAX_PROCESSES) {
            return null;
        }
        self.processes[self.processes_len] = Process.init();
        self.processes[self.processes_len].process_id = kernel_pid;
        self.processes[self.processes_len].parent_process_id = parent_process_id;
        self.processes[self.processes_len].state = ProcessState.running;
        self.processes[self.processes_len].active = true;
        i = 0;
        while (i < MAX_PROCESS_NAME_LEN) : (i += 1) {
            self.processes[self.processes_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_PROCESS_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.processes[self.processes_len].name[i] = name[i];
        }
        self.processes[self.processes_len].name_len = @intCast(name_len);
        i = 0;
        while (i < MAX_CMD_LINE_LEN) : (i += 1) {
            self.processes[self.processes_len].cmd_line[i] = 0;
        }
        i = 0;
        while (i < path_len) : (i += 1) {
            self.processes[self.processes_len].cmd_line[i] = cmd_line[i];
        }
        self.processes[self.processes_len].cmd_line_len = @intCast(path_len);
        self.processes[self.processes_len].start_time = start_time;
        self.processes_len += 1;
        return kernel_pid;
    }

    // Kill process using kernel kill syscall.
    pub fn kill_process(self: *ProcessManager, process_id: u32) bool {
        if (self.syscall_fn == null) {
            return false;
        }
        std.debug.assert(process_id > 0);
        const signal: u64 = 15;
        const result = self.syscall_fn.?(@intFromEnum(basin_kernel.Syscall.kill), process_id, signal, 0, 0);
        if (result < 0) {
            return false;
        }
        if (self.find_process(process_id)) |proc| {
            proc.state = ProcessState.dead;
        }
        return true;
    }
};

