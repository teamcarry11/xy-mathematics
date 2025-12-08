//! AArch64 Virtual Machine
//! Why: Emulate AArch64 architecture for kernel development and cloud deployment.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const arch = @import("arch.zig");
const SerialOutput = @import("serial.zig").SerialOutput;

/// AArch64 memory configuration.
/// Why: Centralized memory size configuration for AArch64 VM.
/// Note: Default: 8MB (same as RISC-V64 for consistency).
pub const AARCH64_VM_MEMORY_SIZE: u64 = 8 * 1024 * 1024; // 8MB

/// AArch64 register file.
/// Why: Track AArch64 register state (31 GP registers x0-x30 + PC).
/// Grain Style: Static allocation, explicit types.
pub const AArch64RegisterFile = struct {
    /// General-purpose registers (x0-x30).
    /// x0-x30 are writable (x31 is stack pointer, handled separately).
    /// Why: Array indexing matches AArch64 register encoding.
    regs: [31]u64 = [_]u64{0} ** 31,
    
    /// Stack pointer (SP, x31).
    /// Why: Separate from regs for clarity (AArch64 uses SP as x31).
    sp: u64 = 0,
    
    /// Program counter (PC).
    /// Why: Separate from regs for clarity and PC-specific operations.
    pc: u64 = 0,
    
    /// Get register value.
    /// Why: Read register value (x0-x30).
    /// Contract: reg_index must be valid (0-30).
    pub fn get(self: *const AArch64RegisterFile, reg_index: u8) u64 {
        // Assert: register index must be valid (0-30).
        std.debug.assert(reg_index < 31);
        
        return self.regs[reg_index];
    }
    
    /// Set register value.
    /// Why: Write register value (x0-x30).
    /// Contract: reg_index must be valid (0-30).
    pub fn set(self: *AArch64RegisterFile, reg_index: u8, value: u64) void {
        // Assert: register index must be valid (0-30).
        std.debug.assert(reg_index < 31);
        
        self.regs[reg_index] = value;
        
        // Assert: register value must be set correctly.
        std.debug.assert(self.regs[reg_index] == value);
    }
    
    /// Get stack pointer.
    /// Why: Read stack pointer (SP, x31).
    pub fn get_sp(self: *const AArch64RegisterFile) u64 {
        return self.sp;
    }
    
    /// Set stack pointer.
    /// Why: Write stack pointer (SP, x31).
    pub fn set_sp(self: *AArch64RegisterFile, value: u64) void {
        self.sp = value;
        
        // Assert: stack pointer must be set correctly.
        std.debug.assert(self.sp == value);
    }
    
    /// Get program counter.
    /// Why: Read program counter.
    pub fn get_pc(self: *const AArch64RegisterFile) u64 {
        return self.pc;
    }
    
    /// Set program counter.
    /// Why: Write program counter.
    pub fn set_pc(self: *AArch64RegisterFile, value: u64) void {
        self.pc = value;
        
        // Assert: program counter must be set correctly.
        std.debug.assert(self.pc == value);
    }
};

/// AArch64 VM execution state.
/// Why: Track VM execution state (running, halted, errored).
pub const AArch64VMState = enum {
    running,
    halted,
    errored,
};

/// AArch64 VM errors.
/// Why: Explicit error types for AArch64 VM operations.
pub const AArch64VMError = error{
    invalid_instruction,
    invalid_memory_access,
    unaligned_instruction,
    unaligned_memory_access,
    invalid_register,
};

/// AArch64 virtual machine state.
/// Why: Encapsulate all AArch64 VM state for deterministic execution.
/// Grain Style: Static allocation, explicit types, comprehensive assertions.
pub const AArch64VM = struct {
    /// Register file (31 GP registers + SP + PC).
    regs: AArch64RegisterFile = .{},
    
    /// Physical memory (static allocation).
    /// Why: Static allocation eliminates allocator dependency.
    memory: [AARCH64_VM_MEMORY_SIZE]u8 = [_]u8{0} ** AARCH64_VM_MEMORY_SIZE,
    
    /// Memory size in bytes.
    memory_size: u64 = AARCH64_VM_MEMORY_SIZE,
    
    /// VM execution state (running, halted, errored).
    state: AArch64VMState = .halted,
    
    /// Last error (if state == .errored).
    /// Why: Track last error for debugging.
    last_error: ?AArch64VMError = null,
    
    /// Syscall handler callback (optional).
    /// Why: Allow external syscall handling (e.g., Grain Basin kernel).
    /// Note: Type-erased to avoid requiring basin_kernel import at module level.
    syscall_handler: ?*const fn (syscall_num: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64 = null,
    
    /// User data for syscall handler (optional).
    /// Why: Pass context to syscall handler (e.g., Basin Kernel instance).
    syscall_user_data: ?*anyopaque = null,
    
    /// Memory permission check callback (optional).
    /// Why: Enforce memory protection by checking read/write/execute permissions.
    /// Note: Type-erased to avoid requiring basin_kernel import at module level.
    /// Returns: u32 with permission bits (bit 0=read, bit 1=write, bit 2=execute), or 0 if not mapped.
    permission_checker: ?*const fn (addr: u64) u32 = null,
    
    /// User data for permission checker (optional).
    /// Why: Pass context to permission checker (e.g., Basin Kernel instance).
    permission_checker_user_data: ?*anyopaque = null,
    
    /// Serial output handler (for console output).
    /// Why: Capture console output for display.
    serial_output: ?*SerialOutput = null,
    
    /// Initialize AArch64 VM.
    /// Why: Set up VM state with default values.
    pub fn init() AArch64VM {
        var vm = AArch64VM{};
        vm.state = .halted;
        vm.memory_size = AARCH64_VM_MEMORY_SIZE;
        return vm;
    }
    
    /// Read memory at address (little-endian, 8 bytes).
    /// Why: Read memory (AArch64 uses little-endian).
    /// Contract: addr must be valid, aligned.
    /// Grain Style: Validate address, bounds checking, alignment.
    pub fn read64(self: *AArch64VM, addr: u64) AArch64VMError!u64 {
        // Assert: address must be within memory bounds.
        if (addr + 8 > self.memory_size) {
            return AArch64VMError.invalid_memory_access;
        }
        
        // Assert: address must be 8-byte aligned (AArch64 requirement).
        if (addr % 8 != 0) {
            return AArch64VMError.unaligned_memory_access;
        }
        
        // Read 8 bytes (little-endian).
        const bytes = self.memory[@intCast(addr)..][0..8];
        const value = std.mem.readInt(u64, bytes, .little);
        
        return value;
    }
    
    /// Write memory at address (little-endian, 8 bytes).
    /// Why: Write memory (AArch64 uses little-endian).
    /// Contract: addr must be valid, aligned.
    /// Grain Style: Validate address, bounds checking, alignment.
    pub fn write64(self: *AArch64VM, addr: u64, value: u64) AArch64VMError!void {
        // Assert: address must be within memory bounds.
        if (addr + 8 > self.memory_size) {
            return AArch64VMError.invalid_memory_access;
        }
        
        // Assert: address must be 8-byte aligned (AArch64 requirement).
        if (addr % 8 != 0) {
            return AArch64VMError.unaligned_memory_access;
        }
        
        // Write 8 bytes (little-endian).
        const bytes = self.memory[@intCast(addr)..][0..8];
        std.mem.writeInt(u64, bytes, value, .little);
        
        // Assert: value must be written correctly.
        const read_back = try self.read64(addr);
        std.debug.assert(read_back == value);
    }
    
    /// Read instruction at address (4 bytes).
    /// Why: Read instruction for execution.
    /// Contract: addr must be valid, 4-byte aligned.
    pub fn read_instruction(self: *AArch64VM, addr: u64) AArch64VMError!u32 {
        // Assert: address must be within memory bounds.
        if (addr + 4 > self.memory_size) {
            return AArch64VMError.invalid_memory_access;
        }
        
        // Assert: address must be 4-byte aligned (AArch64 requirement).
        if (addr % 4 != 0) {
            return AArch64VMError.unaligned_instruction;
        }
        
        // Read 4 bytes (little-endian).
        const bytes = self.memory[@intCast(addr)..][0..4];
        const instruction = std.mem.readInt(u32, bytes, .little);
        
        return instruction;
    }
    
    /// Execute single instruction (stub implementation).
    /// Why: Execute AArch64 instruction.
    /// Contract: instruction must be valid AArch64 instruction.
    /// Note: This is a stub - full instruction decoding will be implemented later.
    pub fn execute_instruction(self: *AArch64VM, instruction: u32) AArch64VMError!void {
        // Assert: VM must be in running state.
        std.debug.assert(self.state == .running);
        
        // Stub: Decode and execute instruction.
        // For now, just check for invalid instruction pattern.
        _ = instruction;
        
        // Note: Full instruction decoding and execution will be implemented in Phase 6.2.
        // This stub allows the VM structure to compile and be tested.
    }
    
    /// Step VM (execute one instruction).
    /// Why: Execute one instruction and advance PC.
    /// Contract: VM must be in running state.
    pub fn step(self: *AArch64VM) AArch64VMError!void {
        // Assert: VM must be in running state.
        if (self.state != .running) {
            return AArch64VMError.invalid_instruction;
        }
        
        // Read instruction at PC.
        const instruction = try self.read_instruction(self.regs.pc);
        
        // Execute instruction.
        try self.execute_instruction(instruction);
        
        // Advance PC (AArch64 instructions are 4 bytes).
        self.regs.pc += 4;
        
        // Assert: PC must be within memory bounds.
        std.debug.assert(self.regs.pc <= self.memory_size);
    }
    
    /// Start VM execution.
    /// Why: Begin VM execution from current PC.
    pub fn start(self: *AArch64VM) void {
        // Assert: PC must be valid.
        std.debug.assert(self.regs.pc < self.memory_size);
        
        self.state = .running;
        
        // Assert: VM must be in running state.
        std.debug.assert(self.state == .running);
    }
    
    /// Halt VM execution.
    /// Why: Stop VM execution.
    pub fn halt(self: *AArch64VM) void {
        self.state = .halted;
        
        // Assert: VM must be in halted state.
        std.debug.assert(self.state == .halted);
    }
    
    /// Get architecture configuration.
    /// Why: Return architecture configuration for this VM.
    pub fn get_arch_config(self: *const AArch64VM) arch.ArchConfig {
        _ = self;
        return arch.ArchConfig.init(.aarch64);
    }
};

