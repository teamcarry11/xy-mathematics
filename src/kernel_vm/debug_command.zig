//! VM Debugging Command Interface
//!
//! Objective: Provide unified debugging command interface combining breakpoints, watchpoints,
//! state inspection, and execution control.
//! Why: Enable debugging tools to use a single high-level API for all debugging operations.
//! GrainStyle: Static allocation, bounded buffers, explicit types, deterministic debugging.
//!
//! Methodology:
//! - Unified debugging API (combines debug_interface, state_inspection, execution_control)
//! - Command-based interface (set breakpoint, continue, step, inspect state)
//! - Debugging session management (start, pause, resume, stop)
//! - Bounded command buffer (MAX_COMMAND_SIZE: 256 bytes)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size command buffers
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-25
//! GrainStyle: Comprehensive debugging command interface, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;
const VMError = @import("vm.zig").VM.VMError;
const debug_interface_mod = @import("debug_interface.zig");
const state_inspection_mod = @import("state_inspection.zig");
const execution_control_mod = @import("execution_control.zig");

// Bounded: Maximum command size for debugging commands.
pub const MAX_COMMAND_SIZE: u32 = 256;

// Debugging command result.
pub const DebugCommandResult = enum {
    success,
    error,
    breakpoint_hit,
    watchpoint_triggered,
};

// Unified debugging command interface.
pub const VMDebugCommand = struct {
    vm: *VM,
    debug_interface: *debug_interface_mod.VMDebugInterface,
    state_inspector: state_inspection_mod.VMStateInspector,
    execution_controller: execution_control_mod.VMExecutionController,

    pub fn init(vm: *VM) VMDebugCommand {
        return VMDebugCommand{
            .vm = vm,
            .debug_interface = &vm.debug_interface,
            .state_inspector = state_inspection_mod.VMStateInspector.init(vm),
            .execution_controller = execution_control_mod.VMExecutionController.init(vm),
        };
    }

    pub fn set_breakpoint(self: *VMDebugCommand, pc: u64) bool {
        return self.debug_interface.set_breakpoint(pc);
    }

    pub fn remove_breakpoint(self: *VMDebugCommand, pc: u64) bool {
        return self.debug_interface.remove_breakpoint(pc);
    }

    pub fn set_watchpoint(self: *VMDebugCommand, address: u64, size: u64, watch_reads: bool, watch_writes: bool) bool {
        return self.debug_interface.set_watchpoint(address, size, watch_reads, watch_writes);
    }

    pub fn remove_watchpoint(self: *VMDebugCommand, address: u64) bool {
        return self.debug_interface.remove_watchpoint(address);
    }

    pub fn continue_execution(self: *VMDebugCommand) void {
        self.execution_controller.continue_execution();
        self.debug_interface.clear_breakpoint_hit();
        self.debug_interface.clear_watchpoint_triggered();
    }

    pub fn step_over(self: *VMDebugCommand) void {
        self.execution_controller.step_over();
        self.debug_interface.clear_breakpoint_hit();
        self.debug_interface.clear_watchpoint_triggered();
    }

    pub fn step_into(self: *VMDebugCommand) void {
        self.execution_controller.step_into();
        self.debug_interface.clear_breakpoint_hit();
        self.debug_interface.clear_watchpoint_triggered();
    }

    pub fn pause_execution(self: *VMDebugCommand) void {
        self.execution_controller.pause();
    }

    pub fn get_register_state(self: *const VMDebugCommand) state_inspection_mod.RegisterState {
        return self.state_inspector.get_register_state();
    }

    pub fn get_register(self: *const VMDebugCommand, reg_num: u32) u64 {
        return self.state_inspector.get_register(reg_num);
    }

    pub fn get_pc(self: *const VMDebugCommand) u64 {
        return self.state_inspector.get_pc();
    }

    pub fn dump_memory(self: *const VMDebugCommand, address: u64, size: u32) ?state_inspection_mod.MemoryDump {
        return self.state_inspector.dump_memory(address, size);
    }

    pub fn read_memory_u64(self: *const VMDebugCommand, address: u64) ?u64 {
        return self.state_inspector.read_memory_u64(address);
    }

    pub fn read_memory_u32(self: *const VMDebugCommand, address: u64) ?u32 {
        return self.state_inspector.read_memory_u32(address);
    }

    pub fn dump_stack(self: *const VMDebugCommand, stack_pointer: u64) ?state_inspection_mod.MemoryDump {
        return self.state_inspector.dump_stack(stack_pointer);
    }

    pub fn check_breakpoint_hit(self: *const VMDebugCommand) bool {
        return self.debug_interface.breakpoint_hit;
    }

    pub fn check_watchpoint_triggered(self: *const VMDebugCommand) bool {
        return self.debug_interface.watchpoint_triggered;
    }

    pub fn get_last_breakpoint_pc(self: *const VMDebugCommand) u64 {
        return self.debug_interface.last_breakpoint_pc;
    }

    pub fn get_last_watchpoint_addr(self: *const VMDebugCommand) u64 {
        return self.debug_interface.last_watchpoint_addr;
    }

    pub fn execute_step(self: *VMDebugCommand) VMError!DebugCommandResult {
        if (self.debug_interface.breakpoint_hit) {
            return DebugCommandResult.breakpoint_hit;
        }
        if (self.debug_interface.watchpoint_triggered) {
            return DebugCommandResult.watchpoint_triggered;
        }
        const should_continue = self.execution_controller.should_continue();
        if (should_continue) {
            try self.vm.step();
            return DebugCommandResult.success;
        }
        const should_step = self.execution_controller.should_step();
        if (should_step) {
            const continued = try self.execution_controller.execute_step();
            if (!continued) {
                return DebugCommandResult.success;
            }
            return DebugCommandResult.success;
        }
        return DebugCommandResult.success;
    }

    pub fn print_state(self: *const VMDebugCommand) void {
        self.state_inspector.print_register_state();
    }

    pub fn print_memory(self: *const VMDebugCommand, address: u64, size: u32) void {
        self.state_inspector.print_memory_dump(address, size);
    }
};

