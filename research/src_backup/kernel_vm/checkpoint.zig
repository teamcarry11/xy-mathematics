//! VM Checkpoint/Restore System
//!
//! Objective: Provide checkpoint/restore capabilities for VM state management.
//! Why: Enable saving and restoring complete VM state for debugging and state management.
//! GrainStyle: Static allocation, bounded buffers, explicit types, deterministic checkpointing.
//!
//! Methodology:
//! - Checkpoint creation (save complete VM state to buffer)
//! - Checkpoint restoration (restore VM state from buffer)
//! - Bounded checkpoint buffer (MAX_CHECKPOINT_SIZE: 1MB)
//! - State validation (verify checkpoint integrity)
//! - Multiple checkpoints (support multiple saved states)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size checkpoint buffer
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-26
//! GrainStyle: Comprehensive checkpoint/restore, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;
const VMError = @import("vm.zig").VM.VMError;

// Bounded: Maximum checkpoint size (1MB per checkpoint).
pub const MAX_CHECKPOINT_SIZE: u32 = 1024 * 1024;
// Bounded: Maximum number of checkpoints (sufficient for debugging).
pub const MAX_CHECKPOINTS: u32 = 16;
// Bounded: Maximum VM memory size for checkpointing (8MB).
pub const MAX_VM_MEMORY_SIZE: u32 = 8 * 1024 * 1024;

// Checkpoint header (metadata for checkpoint).
pub const CheckpointHeader = struct {
    magic: u32,
    version: u32,
    vm_memory_size: u32,
    pc: u64,
    state: u32,
    checksum: u32,

    pub fn init() CheckpointHeader {
        return CheckpointHeader{
            .magic = 0x564D4350,
            .version = 1,
            .vm_memory_size = 0,
            .pc = 0,
            .state = 0,
            .checksum = 0,
        };
    }
};

// VM checkpoint manager.
pub const VMCheckpoint = struct {
    checkpoints: [MAX_CHECKPOINTS]?CheckpointData,
    checkpoint_count: u32,

    const CheckpointData = struct {
        header: CheckpointHeader,
        memory: [MAX_VM_MEMORY_SIZE]u8,
        memory_size: u32,
        registers: [32]u64,
    };

    pub fn init() VMCheckpoint {
        return VMCheckpoint{
            .checkpoints = [_]?CheckpointData{null} ** MAX_CHECKPOINTS,
            .checkpoint_count = 0,
        };
    }

    pub fn create_checkpoint(self: *VMCheckpoint, vm: *VM, checkpoint_id: u32) VMError!bool {
        if (checkpoint_id >= MAX_CHECKPOINTS) {
            return VMError.invalid_memory_access;
        }
        if (self.checkpoint_count >= MAX_CHECKPOINTS) {
            return VMError.invalid_memory_access;
        }
        var header = CheckpointHeader.init();
        header.vm_memory_size = vm.memory_size;
        header.pc = vm.regs.pc;
        header.state = @intFromEnum(vm.state);
        var registers: [32]u64 = undefined;
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            registers[i] = vm.regs.get(@as(u5, @intCast(i)));
        }
        const memory_size = vm.memory_size;
        if (memory_size > MAX_VM_MEMORY_SIZE) {
            return VMError.invalid_memory_access;
        }
        var checkpoint = CheckpointData{
            .header = header,
            .memory = [_]u8{0} ** MAX_VM_MEMORY_SIZE,
            .memory_size = @as(u32, @intCast(memory_size)),
            .registers = registers,
        };
        @memcpy(checkpoint.memory[0..memory_size], vm.memory[0..memory_size]);
        checkpoint.header.checksum = self.calculate_checksum(&checkpoint);
        if (self.checkpoints[checkpoint_id]) |_| {
            self.checkpoint_count -= 1;
        }
        self.checkpoints[checkpoint_id] = checkpoint;
        self.checkpoint_count += 1;
        return true;
    }

    pub fn restore_checkpoint(self: *VMCheckpoint, vm: *VM, checkpoint_id: u32) VMError!bool {
        if (checkpoint_id >= MAX_CHECKPOINTS) {
            return VMError.invalid_memory_access;
        }
        const checkpoint_opt = self.checkpoints[checkpoint_id];
        if (checkpoint_opt == null) {
            return VMError.invalid_memory_access;
        }
        const checkpoint = checkpoint_opt.?;
        if (checkpoint.header.magic != 0x564D4350) {
            return VMError.invalid_memory_access;
        }
        if (checkpoint.header.version != 1) {
            return VMError.invalid_memory_access;
        }
        const checksum = self.calculate_checksum(&checkpoint);
        if (checksum != checkpoint.header.checksum) {
            return VMError.invalid_memory_access;
        }
        if (checkpoint.header.vm_memory_size != vm.memory_size) {
            return VMError.invalid_memory_access;
        }
        @memcpy(vm.memory[0..checkpoint.memory_size], checkpoint.memory[0..checkpoint.memory_size]);
        vm.regs.pc = checkpoint.header.pc;
        vm.state = @enumFromInt(checkpoint.header.state);
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            vm.regs.set(@as(u5, @intCast(i)), checkpoint.registers[i]);
        }
        return true;
    }

    pub fn delete_checkpoint(self: *VMCheckpoint, checkpoint_id: u32) bool {
        if (checkpoint_id >= MAX_CHECKPOINTS) {
            return false;
        }
        if (self.checkpoints[checkpoint_id] == null) {
            return false;
        }
        self.checkpoints[checkpoint_id] = null;
        self.checkpoint_count -= 1;
        return true;
    }

    pub fn has_checkpoint(self: *const VMCheckpoint, checkpoint_id: u32) bool {
        if (checkpoint_id >= MAX_CHECKPOINTS) {
            return false;
        }
        return self.checkpoints[checkpoint_id] != null;
    }

    pub fn get_checkpoint_count(self: *const VMCheckpoint) u32 {
        return self.checkpoint_count;
    }

    fn calculate_checksum(self: *const VMCheckpoint, checkpoint: *const CheckpointData) u32 {
        _ = self;
        var sum: u32 = 0;
        sum +%= checkpoint.header.magic;
        sum +%= checkpoint.header.version;
        sum +%= checkpoint.header.vm_memory_size;
        sum +%= @as(u32, @truncate(checkpoint.header.pc));
        sum +%= @as(u32, @truncate(checkpoint.header.pc >> 32));
        sum +%= checkpoint.header.state;
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            sum +%= @as(u32, @truncate(checkpoint.registers[i]));
            sum +%= @as(u32, @truncate(checkpoint.registers[i] >> 32));
        }
        const memory_size = checkpoint.memory_size;
        i = 0;
        while (i < memory_size) : (i += 1) {
            sum +%= checkpoint.memory[i];
        }
        return sum;
    }
};

