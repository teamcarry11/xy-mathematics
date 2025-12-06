//! Grain OS Process Supervision: Compositor-level process supervision and automatic restart.
//!
//! Why: Provide process supervision for automatic restart and health monitoring at the
//!      compositor/desktop environment level. This manages Grain OS application processes.
//!
//! Architecture: Process supervision, restart policies, health monitoring.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//! Inspired by: s6 process supervision suite (https://github.com/skarnet/s6)
//!
//! Note: This is compositor-level supervision for Grain OS applications.
//!       For kernel-level system service supervision, see src/userspace/z6.zig (z6 daemon).

const std = @import("std");

// Bounded: Max supervised processes.
pub const MAX_SUPERVISED_PROCESSES: u32 = 64;

// Bounded: Max supervision policy name length.
pub const MAX_POLICY_NAME_LEN: u32 = 64;

// Supervision policy: defines restart behavior.
pub const SupervisionPolicy = enum(u8) {
    always, // Always restart when process exits.
    never, // Never restart (one-shot processes).
    on_failure, // Restart only on failure (non-zero exit).
    on_success, // Restart only on success (zero exit).
};

// Supervision state: current supervision state.
pub const SupervisionState = enum(u8) {
    idle, // Not supervised.
    starting, // Process starting.
    running, // Process running.
    crashed, // Process crashed, waiting to restart.
    stopping, // Process stopping.
    stopped, // Process stopped.
};

// Supervised process: represents a supervised process.
pub const SupervisedProcess = struct {
    process_id: u32,
    supervision_id: u32,
    policy: SupervisionPolicy,
    state: SupervisionState,
    restart_count: u32,
    max_restarts: u32, // Max restart attempts (0 = unlimited).
    restart_delay_ms: u32, // Delay before restart (milliseconds).
    last_restart_time: u64, // Last restart timestamp.
    last_exit_code: i32, // Last exit code.
    active: bool,

    pub fn init() SupervisedProcess {
        return SupervisedProcess{
            .process_id = 0,
            .supervision_id = 0,
            .policy = SupervisionPolicy.never,
            .state = SupervisionState.idle,
            .restart_count = 0,
            .max_restarts = 0,
            .restart_delay_ms = 1000,
            .last_restart_time = 0,
            .last_exit_code = 0,
            .active = false,
        };
    }

    // Check if process should restart.
    pub fn should_restart(self: *const SupervisedProcess, exit_code: i32, current_time: u64) bool {
        if (self.policy == SupervisionPolicy.never) {
            return false;
        }
        if (self.max_restarts > 0 and self.restart_count >= self.max_restarts) {
            return false;
        }
        if (self.state == SupervisionState.stopping or self.state == SupervisionState.stopped) {
            return false;
        }
        const time_since_restart = current_time - self.last_restart_time;
        if (time_since_restart < self.restart_delay_ms) {
            return false;
        }
        switch (self.policy) {
            SupervisionPolicy.always => return true,
            SupervisionPolicy.on_failure => return exit_code != 0,
            SupervisionPolicy.on_success => return exit_code == 0,
            SupervisionPolicy.never => return false,
        }
    }
};

// Process supervisor: supervises system processes.
pub const ProcessSupervisor = struct {
    supervised: [MAX_SUPERVISED_PROCESSES]SupervisedProcess,
    supervised_len: u32,
    next_supervision_id: u32,

    pub fn init() ProcessSupervisor {
        var supervisor = ProcessSupervisor{
            .supervised = undefined,
            .supervised_len = 0,
            .next_supervision_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_SUPERVISED_PROCESSES) : (i += 1) {
            supervisor.supervised[i] = SupervisedProcess.init();
        }
        return supervisor;
    }

    // Add supervised process.
    pub fn add_supervised_process(
        self: *ProcessSupervisor,
        process_id: u32,
        policy: SupervisionPolicy,
        max_restarts: u32,
        restart_delay_ms: u32,
    ) ?u32 {
        std.debug.assert(process_id > 0);
        if (self.supervised_len >= MAX_SUPERVISED_PROCESSES) {
            return null;
        }
        const supervision_id = self.next_supervision_id;
        self.next_supervision_id += 1;
        self.supervised[self.supervised_len] = SupervisedProcess.init();
        self.supervised[self.supervised_len].process_id = process_id;
        self.supervised[self.supervised_len].supervision_id = supervision_id;
        self.supervised[self.supervised_len].policy = policy;
        self.supervised[self.supervised_len].max_restarts = max_restarts;
        self.supervised[self.supervised_len].restart_delay_ms = restart_delay_ms;
        self.supervised[self.supervised_len].state = SupervisionState.starting;
        self.supervised[self.supervised_len].active = true;
        self.supervised_len += 1;
        return supervision_id;
    }

    // Find supervised process by process ID.
    pub fn find_by_process_id(
        self: *ProcessSupervisor,
        process_id: u32,
    ) ?*SupervisedProcess {
        std.debug.assert(process_id > 0);
        var i: u32 = 0;
        while (i < self.supervised_len) : (i += 1) {
            if (self.supervised[i].process_id == process_id and self.supervised[i].active) {
                return &self.supervised[i];
            }
        }
        return null;
    }

    // Find supervised process by supervision ID.
    pub fn find_by_supervision_id(
        self: *ProcessSupervisor,
        supervision_id: u32,
    ) ?*SupervisedProcess {
        std.debug.assert(supervision_id > 0);
        var i: u32 = 0;
        while (i < self.supervised_len) : (i += 1) {
            if (self.supervised[i].supervision_id == supervision_id and self.supervised[i].active) {
                return &self.supervised[i];
            }
        }
        return null;
    }

    // Update process state.
    pub fn update_process_state(
        self: *ProcessSupervisor,
        process_id: u32,
        state: SupervisionState,
    ) bool {
        std.debug.assert(process_id > 0);
        if (self.find_by_process_id(process_id)) |supervised| {
            supervised.state = state;
            return true;
        }
        return false;
    }

    // Record process exit.
    pub fn record_process_exit(
        self: *ProcessSupervisor,
        process_id: u32,
        exit_code: i32,
        current_time: u64,
    ) bool {
        std.debug.assert(process_id > 0);
        if (self.find_by_process_id(process_id)) |supervised| {
            supervised.last_exit_code = exit_code;
            supervised.state = SupervisionState.crashed;
            supervised.last_restart_time = current_time;
            if (supervised.should_restart(exit_code, current_time)) {
                supervised.restart_count += 1;
                supervised.state = SupervisionState.starting;
                return true;
            } else {
                supervised.state = SupervisionState.stopped;
                return false;
            }
        }
        return false;
    }

    // Remove supervised process.
    pub fn remove_supervised_process(
        self: *ProcessSupervisor,
        supervision_id: u32,
    ) bool {
        std.debug.assert(supervision_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.supervised_len) : (i += 1) {
            if (self.supervised[i].supervision_id == supervision_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        while (i < self.supervised_len - 1) : (i += 1) {
            self.supervised[i] = self.supervised[i + 1];
        }
        self.supervised_len -= 1;
        return true;
    }

    // Get supervised process count.
    pub fn get_supervised_count(self: *const ProcessSupervisor) u32 {
        return self.supervised_len;
    }

    // Get running supervised count.
    pub fn get_running_count(self: *const ProcessSupervisor) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.supervised_len) : (i += 1) {
            if (self.supervised[i].state == SupervisionState.running) {
                count += 1;
            }
        }
        return count;
    }

    // Get crashed supervised count.
    pub fn get_crashed_count(self: *const ProcessSupervisor) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.supervised_len) : (i += 1) {
            if (self.supervised[i].state == SupervisionState.crashed) {
                count += 1;
            }
        }
        return count;
    }
};

