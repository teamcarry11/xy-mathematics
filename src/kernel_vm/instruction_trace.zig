//! VM Instruction Trace Logging System
//!
//! Objective: Provide instruction trace logging for debugging (history of executed instructions).
//! Why: Enable debugging tools to see a history of executed instructions for debugging.
//! GrainStyle: Static allocation, bounded circular buffer, explicit types, deterministic logging.
//!
//! Methodology:
//! - Instruction trace logging (record PC, instruction, registers, memory accesses)
//! - Circular buffer (bounded trace history, MAX_TRACE_ENTRIES: 1024)
//! - Trace entry format (PC, instruction, register state, memory access)
//! - Trace filtering (enable/disable tracing, filter by PC range)
//! - Trace export (dump trace to buffer for analysis)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size circular trace buffer
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-25
//! GrainStyle: Comprehensive instruction trace logging, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;

// Bounded: Maximum trace entries in circular buffer (sufficient for debugging).
pub const MAX_TRACE_ENTRIES: u32 = 1024;

// Trace entry: records instruction execution details.
pub const TraceEntry = struct {
    pc: u64,
    instruction: u32,
    regs: [32]u64,
    memory_read_addr: ?u64,
    memory_write_addr: ?u64,
    memory_read_value: ?u64,
    memory_write_value: ?u64,

    pub fn init() TraceEntry {
        return TraceEntry{
            .pc = 0,
            .instruction = 0,
            .regs = [_]u64{0} ** 32,
            .memory_read_addr = null,
            .memory_write_addr = null,
            .memory_read_value = null,
            .memory_write_value = null,
        };
    }
};

// VM instruction trace logger.
pub const VMInstructionTrace = struct {
    trace_buffer: [MAX_TRACE_ENTRIES]TraceEntry,
    trace_index: u32,
    trace_count: u32,
    enabled: bool,
    filter_pc_min: ?u64,
    filter_pc_max: ?u64,

    pub fn init() VMInstructionTrace {
        var trace = VMInstructionTrace{
            .trace_buffer = undefined,
            .trace_index = 0,
            .trace_count = 0,
            .enabled = false,
            .filter_pc_min = null,
            .filter_pc_max = null,
        };
        var i: u32 = 0;
        while (i < MAX_TRACE_ENTRIES) : (i += 1) {
            trace.trace_buffer[i] = TraceEntry.init();
        }
        return trace;
    }

    pub fn enable(self: *VMInstructionTrace) void {
        self.enabled = true;
    }

    pub fn disable(self: *VMInstructionTrace) void {
        self.enabled = false;
    }

    pub fn set_filter(self: *VMInstructionTrace, pc_min: ?u64, pc_max: ?u64) void {
        self.filter_pc_min = pc_min;
        self.filter_pc_max = pc_max;
    }

    pub fn clear_filter(self: *VMInstructionTrace) void {
        self.filter_pc_min = null;
        self.filter_pc_max = null;
    }

    pub fn should_trace(self: *const VMInstructionTrace, pc: u64) bool {
        if (!self.enabled) {
            return false;
        }
        if (self.filter_pc_min) |min| {
            if (pc < min) {
                return false;
            }
        }
        if (self.filter_pc_max) |max| {
            if (pc > max) {
                return false;
            }
        }
        return true;
    }

    pub fn record_instruction(self: *VMInstructionTrace, vm: *VM, pc: u64, instruction: u32) void {
        if (!self.should_trace(pc)) {
            return;
        }
        const idx = self.trace_index;
        var entry = &self.trace_buffer[idx];
        entry.pc = pc;
        entry.instruction = instruction;
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            entry.regs[i] = vm.regs.get(@as(u5, @intCast(i)));
        }
        entry.memory_read_addr = null;
        entry.memory_write_addr = null;
        entry.memory_read_value = null;
        entry.memory_write_value = null;
        self.trace_index = (self.trace_index + 1) % MAX_TRACE_ENTRIES;
        if (self.trace_count < MAX_TRACE_ENTRIES) {
            self.trace_count += 1;
        }
    }

    pub fn record_memory_read(self: *VMInstructionTrace, address: u64, value: u64) void {
        if (!self.enabled) {
            return;
        }
        if (self.trace_count == 0) {
            return;
        }
        const prev_idx = if (self.trace_index == 0) MAX_TRACE_ENTRIES - 1 else self.trace_index - 1;
        var entry = &self.trace_buffer[prev_idx];
        entry.memory_read_addr = address;
        entry.memory_read_value = value;
    }

    pub fn record_memory_write(self: *VMInstructionTrace, address: u64, value: u64) void {
        if (!self.enabled) {
            return;
        }
        if (self.trace_count == 0) {
            return;
        }
        const prev_idx = if (self.trace_index == 0) MAX_TRACE_ENTRIES - 1 else self.trace_index - 1;
        var entry = &self.trace_buffer[prev_idx];
        entry.memory_write_addr = address;
        entry.memory_write_value = value;
    }

    pub fn get_trace_count(self: *const VMInstructionTrace) u32 {
        return self.trace_count;
    }

    pub fn get_trace_entry(self: *const VMInstructionTrace, index: u32) ?*const TraceEntry {
        if (index >= self.trace_count) {
            return null;
        }
        const start_idx = if (self.trace_count < MAX_TRACE_ENTRIES) 0 else self.trace_index;
        const actual_idx = (start_idx + index) % MAX_TRACE_ENTRIES;
        return &self.trace_buffer[actual_idx];
    }

    pub fn clear_trace(self: *VMInstructionTrace) void {
        self.trace_index = 0;
        self.trace_count = 0;
    }

    pub fn print_trace(self: *const VMInstructionTrace, max_entries: u32) void {
        const count = if (max_entries > self.trace_count) self.trace_count else max_entries;
        std.debug.print("\nInstruction Trace ({} entries):\n", .{count});
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            const entry_opt = self.get_trace_entry(i);
            if (entry_opt) |entry| {
                std.debug.print("  [{:4}] PC: 0x{x}, Inst: 0x{x}", .{ i, entry.pc, entry.instruction });
                if (entry.memory_read_addr) |addr| {
                    std.debug.print(", Read: 0x{x} = 0x{x}", .{ addr, entry.memory_read_value.? });
                }
                if (entry.memory_write_addr) |addr| {
                    std.debug.print(", Write: 0x{x} = 0x{x}", .{ addr, entry.memory_write_value.? });
                }
                std.debug.print("\n", .{});
            }
        }
    }
};

