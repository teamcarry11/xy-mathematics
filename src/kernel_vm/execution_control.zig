//! VM Execution Control System
//!
//! Objective: Provide execution control capabilities (continue, step over, step into).
//! Why: Enable debugging tools to control VM execution flow when breakpoints are hit.
//! GrainStyle: Static allocation, bounded tracking, explicit types, deterministic control.
//!
//! Methodology:
//! - Continue execution (resume until next breakpoint)
//! - Step over (execute one instruction, skip function calls)
//! - Step into (execute one instruction, enter function calls)
//! - Execution state tracking (paused, running, stepping)
//! - Bounded call stack tracking (MAX_CALL_STACK: 64)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded arrays: fixed-size call stack
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-24
//! GrainStyle: Comprehensive execution control, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;
const VMError = @import("vm.zig").VM.VMError;

// Bounded: Maximum call stack depth for step over/into tracking.
pub const MAX_CALL_STACK: u32 = 64;

// Execution control state.
pub const ExecutionState = enum {
    running,
    paused,
    stepping_over,
    stepping_into,
};

// Call stack entry (for step over/into tracking).
pub const CallStackEntry = struct {
    pc: u64,
    return_pc: u64,

    pub fn init(pc: u64, return_pc: u64) CallStackEntry {
        return CallStackEntry{
            .pc = pc,
            .return_pc = return_pc,
        };
    }
};

// VM execution controller.
pub const VMExecutionController = struct {
    vm: *VM,
    state: ExecutionState,
    call_stack: [MAX_CALL_STACK]CallStackEntry,
    call_stack_len: u32,
    step_over_target_pc: u64,
    step_into_depth: u32,

    pub fn init(vm: *VM) VMExecutionController {
        var controller = VMExecutionController{
            .vm = vm,
            .state = .paused,
            .call_stack = undefined,
            .call_stack_len = 0,
            .step_over_target_pc = 0,
            .step_into_depth = 0,
        };
        var i: u32 = 0;
        while (i < MAX_CALL_STACK) : (i += 1) {
            controller.call_stack[i] = CallStackEntry.init(0, 0);
        }
        return controller;
    }

    pub fn continue_execution(self: *VMExecutionController) void {
        self.state = .running;
        self.call_stack_len = 0;
        self.step_over_target_pc = 0;
        self.step_into_depth = 0;
    }

    pub fn step_over(self: *VMExecutionController) void {
        self.state = .stepping_over;
        self.step_over_target_pc = self.vm.regs.pc;
        self.call_stack_len = 0;
        self.step_into_depth = 0;
    }

    pub fn step_into(self: *VMExecutionController) void {
        self.state = .stepping_into;
        self.step_into_depth = self.call_stack_len;
        self.step_over_target_pc = 0;
    }

    pub fn pause(self: *VMExecutionController) void {
        self.state = .paused;
    }

    pub fn should_continue(self: *const VMExecutionController) bool {
        return self.state == .running;
    }

    pub fn should_step(self: *const VMExecutionController) bool {
        return self.state == .stepping_over or self.state == .stepping_into;
    }

    pub fn execute_step(self: *VMExecutionController) VMError!bool {
        if (self.state == .paused) {
            return false;
        }
        if (self.state == .running) {
            try self.vm.step();
            return true;
        }
        if (self.state == .stepping_over) {
            const pc_before = self.vm.regs.pc;
            try self.vm.step();
            const pc_after = self.vm.regs.pc;
            if (pc_after == self.step_over_target_pc + 4) {
                self.state = .paused;
                return false;
            }
            return true;
        }
        if (self.state == .stepping_into) {
            try self.vm.step();
            if (self.call_stack_len <= self.step_into_depth) {
                self.state = .paused;
                return false;
            }
            return true;
        }
        return false;
    }

    pub fn push_call_stack(self: *VMExecutionController, pc: u64, return_pc: u64) bool {
        if (self.call_stack_len >= MAX_CALL_STACK) {
            return false;
        }
        const idx = self.call_stack_len;
        self.call_stack[idx] = CallStackEntry.init(pc, return_pc);
        self.call_stack_len += 1;
        return true;
    }

    pub fn pop_call_stack(self: *VMExecutionController) ?CallStackEntry {
        if (self.call_stack_len == 0) {
            return null;
        }
        self.call_stack_len -= 1;
        return self.call_stack[self.call_stack_len];
    }

    pub fn get_call_stack_depth(self: *const VMExecutionController) u32 {
        return self.call_stack_len;
    }
};

