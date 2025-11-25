//! VM Debugging Interface System
//!
//! Objective: Provide debugging capabilities (breakpoints, watchpoints, step debugging).
//! Why: Enable debugging of kernel code running in the VM, set breakpoints, watch memory/registers.
//! GrainStyle: Static allocation, bounded arrays, explicit types, deterministic debugging.
//!
//! Methodology:
//! - Breakpoint management (set/remove breakpoints at PC addresses)
//! - Watchpoint management (watch memory addresses for read/write)
//! - Step debugging (execute one instruction at a time)
//! - Register watch (monitor register changes)
//! - Debug state tracking (breakpoint hit, watchpoint triggered)
//! - Bounded breakpoint/watchpoint arrays
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded arrays: fixed-size breakpoint/watchpoint arrays
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-24
//! GrainStyle: Comprehensive debugging interface, deterministic behavior, explicit limits

const std = @import("std");

// Bounded: Maximum number of breakpoints (sufficient for kernel debugging).
pub const MAX_BREAKPOINTS: u32 = 32;
// Bounded: Maximum number of watchpoints (sufficient for memory debugging).
pub const MAX_WATCHPOINTS: u32 = 32;

// Breakpoint entry: tracks breakpoint at PC address.
pub const Breakpoint = struct {
    pc: u64,
    enabled: bool,

    pub fn init(pc: u64) Breakpoint {
        return Breakpoint{
            .pc = pc,
            .enabled = true,
        };
    }
};

// Watchpoint entry: tracks watchpoint at memory address.
pub const Watchpoint = struct {
    address: u64,
    size: u64,
    watch_reads: bool,
    watch_writes: bool,
    enabled: bool,

    pub fn init(address: u64, size: u64, watch_reads: bool, watch_writes: bool) Watchpoint {
        std.debug.assert(size > 0);
        std.debug.assert(size <= 8);
        return Watchpoint{
            .address = address,
            .size = size,
            .watch_reads = watch_reads,
            .watch_writes = watch_writes,
            .enabled = true,
        };
    }
};

// VM debugging interface.
pub const VMDebugInterface = struct {
    breakpoints: [MAX_BREAKPOINTS]Breakpoint,
    breakpoints_len: u32,
    watchpoints: [MAX_WATCHPOINTS]Watchpoint,
    watchpoints_len: u32,
    step_mode: bool,
    breakpoint_hit: bool,
    watchpoint_triggered: bool,
    last_breakpoint_pc: u64,
    last_watchpoint_addr: u64,

    pub fn init() VMDebugInterface {
        var debug = VMDebugInterface{
            .breakpoints = undefined,
            .breakpoints_len = 0,
            .watchpoints = undefined,
            .watchpoints_len = 0,
            .step_mode = false,
            .breakpoint_hit = false,
            .watchpoint_triggered = false,
            .last_breakpoint_pc = 0,
            .last_watchpoint_addr = 0,
        };
        var i: u32 = 0;
        while (i < MAX_BREAKPOINTS) : (i += 1) {
            debug.breakpoints[i] = Breakpoint.init(0);
        }
        i = 0;
        while (i < MAX_WATCHPOINTS) : (i += 1) {
            debug.watchpoints[i] = Watchpoint.init(0, 1, false, false);
        }
        return debug;
    }

    pub fn set_breakpoint(self: *VMDebugInterface, pc: u64) bool {
        if (self.breakpoints_len >= MAX_BREAKPOINTS) {
            return false;
        }
        var i: u32 = 0;
        while (i < self.breakpoints_len) : (i += 1) {
            if (self.breakpoints[i].pc == pc) {
                self.breakpoints[i].enabled = true;
                return true;
            }
        }
        const idx = self.breakpoints_len;
        self.breakpoints[idx] = Breakpoint.init(pc);
        self.breakpoints_len += 1;
        return true;
    }

    pub fn remove_breakpoint(self: *VMDebugInterface, pc: u64) bool {
        var i: u32 = 0;
        while (i < self.breakpoints_len) : (i += 1) {
            if (self.breakpoints[i].pc == pc) {
                self.breakpoints[i].enabled = false;
                return true;
            }
        }
        return false;
    }

    pub fn check_breakpoint(self: *VMDebugInterface, pc: u64) bool {
        var i: u32 = 0;
        while (i < self.breakpoints_len) : (i += 1) {
            const bp = &self.breakpoints[i];
            if (bp.enabled and bp.pc == pc) {
                self.breakpoint_hit = true;
                self.last_breakpoint_pc = pc;
                return true;
            }
        }
        return false;
    }

    pub fn set_watchpoint(self: *VMDebugInterface, address: u64, size: u64, watch_reads: bool, watch_writes: bool) bool {
        if (self.watchpoints_len >= MAX_WATCHPOINTS) {
            return false;
        }
        const idx = self.watchpoints_len;
        self.watchpoints[idx] = Watchpoint.init(address, size, watch_reads, watch_writes);
        self.watchpoints_len += 1;
        return true;
    }

    pub fn remove_watchpoint(self: *VMDebugInterface, address: u64) bool {
        var i: u32 = 0;
        while (i < self.watchpoints_len) : (i += 1) {
            if (self.watchpoints[i].address == address) {
                self.watchpoints[i].enabled = false;
                return true;
            }
        }
        return false;
    }

    pub fn check_watchpoint_read(self: *VMDebugInterface, address: u64, size: u64) bool {
        var i: u32 = 0;
        while (i < self.watchpoints_len) : (i += 1) {
            const wp = &self.watchpoints[i];
            if (wp.enabled and wp.watch_reads) {
                if (address >= wp.address and address + size <= wp.address + wp.size) {
                    self.watchpoint_triggered = true;
                    self.last_watchpoint_addr = address;
                    return true;
                }
            }
        }
        return false;
    }

    pub fn check_watchpoint_write(self: *VMDebugInterface, address: u64, size: u64) bool {
        var i: u32 = 0;
        while (i < self.watchpoints_len) : (i += 1) {
            const wp = &self.watchpoints[i];
            if (wp.enabled and wp.watch_writes) {
                if (address >= wp.address and address + size <= wp.address + wp.size) {
                    self.watchpoint_triggered = true;
                    self.last_watchpoint_addr = address;
                    return true;
                }
            }
        }
        return false;
    }

    pub fn enable_step_mode(self: *VMDebugInterface) void {
        self.step_mode = true;
    }

    pub fn disable_step_mode(self: *VMDebugInterface) void {
        self.step_mode = false;
    }

    pub fn clear_breakpoint_hit(self: *VMDebugInterface) void {
        self.breakpoint_hit = false;
    }

    pub fn clear_watchpoint_triggered(self: *VMDebugInterface) void {
        self.watchpoint_triggered = false;
    }
};

