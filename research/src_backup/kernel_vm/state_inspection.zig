//! VM State Inspection System
//!
//! Objective: Provide state inspection capabilities (registers, memory, stack).
//! Why: Enable debugging tools to inspect VM state when breakpoints are hit.
//! GrainStyle: Static allocation, bounded buffers, explicit types, deterministic inspection.
//!
//! Methodology:
//! - Register inspection (read all 32 registers + PC)
//! - Memory inspection (read memory at specific addresses)
//! - Stack inspection (read stack region)
//! - State snapshot (capture complete VM state)
//! - Bounded memory dumps (MAX_DUMP_SIZE: 1KB per dump)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size memory dump buffers
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-24
//! GrainStyle: Comprehensive state inspection, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;

// Bounded: Maximum dump size for memory inspection (1KB per dump).
pub const MAX_DUMP_SIZE: u32 = 1024;
// Bounded: Maximum stack inspection size (1KB stack region).
pub const MAX_STACK_SIZE: u32 = 1024;

// Register state snapshot (all 32 registers + PC).
pub const RegisterState = struct {
    regs: [32]u64,
    pc: u64,

    pub fn init() RegisterState {
        return RegisterState{
            .regs = [_]u64{0} ** 32,
            .pc = 0,
        };
    }
};

// Memory dump (bounded buffer for memory inspection).
pub const MemoryDump = struct {
    address: u64,
    data: [MAX_DUMP_SIZE]u8,
    size: u32,

    pub fn init() MemoryDump {
        return MemoryDump{
            .address = 0,
            .data = [_]u8{0} ** MAX_DUMP_SIZE,
            .size = 0,
        };
    }
};

// VM state inspector.
pub const VMStateInspector = struct {
    vm: *VM,

    pub fn init(vm: *VM) VMStateInspector {
        return VMStateInspector{
            .vm = vm,
        };
    }

    pub fn get_register_state(self: *const VMStateInspector) RegisterState {
        var state = RegisterState.init();
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            state.regs[i] = self.vm.regs.get(@as(u5, @intCast(i)));
        }
        state.pc = self.vm.regs.pc;
        return state;
    }

    pub fn get_register(self: *const VMStateInspector, reg_num: u32) u64 {
        std.debug.assert(reg_num < 32);
        return self.vm.regs.get(@as(u5, @intCast(reg_num)));
    }

    pub fn get_pc(self: *const VMStateInspector) u64 {
        return self.vm.regs.pc;
    }

    pub fn dump_memory(self: *const VMStateInspector, address: u64, size: u32) ?MemoryDump {
        if (size > MAX_DUMP_SIZE) {
            return null;
        }
        const addr_u32 = @as(u32, @intCast(address));
        if (addr_u32 + size > self.vm.memory_size) {
            return null;
        }
        var dump = MemoryDump.init();
        dump.address = address;
        dump.size = size;
        const start = @as(usize, @intCast(addr_u32));
        @memcpy(dump.data[0..size], self.vm.memory[start..][0..size]);
        return dump;
    }

    pub fn read_memory_u64(self: *const VMStateInspector, address: u64) ?u64 {
        const addr_u32 = @as(u32, @intCast(address));
        if (addr_u32 + 8 > self.vm.memory_size) {
            return null;
        }
        const start = @as(usize, @intCast(addr_u32));
        const bytes = self.vm.memory[start..][0..8];
        return std.mem.readInt(u64, bytes, .little);
    }

    pub fn read_memory_u32(self: *const VMStateInspector, address: u64) ?u32 {
        const addr_u32 = @as(u32, @intCast(address));
        if (addr_u32 + 4 > self.vm.memory_size) {
            return null;
        }
        const start = @as(usize, @intCast(addr_u32));
        const bytes = self.vm.memory[start..][0..4];
        return std.mem.readInt(u32, bytes, .little);
    }

    pub fn dump_stack(self: *const VMStateInspector, stack_pointer: u64) ?MemoryDump {
        const sp_u32 = @as(u32, @intCast(stack_pointer));
        if (sp_u32 >= self.vm.memory_size) {
            return null;
        }
        const dump_size = if (sp_u32 + MAX_STACK_SIZE > self.vm.memory_size)
            self.vm.memory_size - sp_u32
        else
            MAX_STACK_SIZE;
        return self.dump_memory(stack_pointer, @as(u32, @intCast(dump_size)));
    }

    pub fn print_register_state(self: *const VMStateInspector) void {
        const state = self.get_register_state();
        std.debug.print("\nVM Register State:\n", .{});
        std.debug.print("  PC: 0x{x}\n", .{state.pc});
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            if (state.regs[i] != 0 or i == 0) {
                std.debug.print("  x{}: 0x{x}\n", .{ i, state.regs[i] });
            }
        }
    }

    pub fn print_memory_dump(self: *const VMStateInspector, address: u64, size: u32) void {
        const dump = self.dump_memory(address, size) orelse {
            std.debug.print("Memory dump failed: invalid address or size\n", .{});
            return;
        };
        std.debug.print("\nMemory Dump at 0x{x} ({} bytes):\n", .{ dump.address, dump.size });
        var i: u32 = 0;
        while (i < dump.size) : (i += 16) {
            const line_size = if (i + 16 > dump.size) dump.size - i else 16;
            std.debug.print("  {:08x}: ", .{dump.address + i});
            var j: u32 = 0;
            while (j < line_size) : (j += 1) {
                std.debug.print("{:02x} ", .{dump.data[i + j]});
            }
            std.debug.print("\n", .{});
        }
    }
};

