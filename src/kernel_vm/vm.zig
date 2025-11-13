const std = @import("std");

/// Pure Zig RISC-V64 emulator for kernel development.
/// Tiger Style: Static allocation where possible, comprehensive assertions,
/// deterministic execution.
/// ~<~ Glow Earthbend: VM state is explicit, no hidden allocations.

/// RISC-V64 register file (32 general-purpose registers + PC).
/// Why: Static allocation for register state, deterministic execution.
pub const RegisterFile = struct {
    /// General-purpose registers (x0-x31).
    /// x0 is hardwired to zero; x1-x31 are writable.
    /// Why: Array indexing matches RISC-V register encoding.
    regs: [32]u64 = [_]u64{0} ** 32,
    /// Program counter (PC).
    /// Why: Separate from regs for clarity and PC-specific operations.
    pc: u64 = 0,

    /// Get register value (x0 always returns 0).
    /// Tiger Style: Validate register index, ensure x0 behavior.
    pub fn get(self: *const RegisterFile, reg: u5) u64 {
        // Assert: register index must be valid (0-31).
        std.debug.assert(reg < 32);
        
        // x0 is hardwired to zero (RISC-V spec).
        if (reg == 0) {
            return 0;
        }
        
        return self.regs[reg];
    }

    /// Set register value (x0 writes are ignored).
    /// Tiger Style: Validate register index, enforce x0 behavior.
    pub fn set(self: *RegisterFile, reg: u5, value: u64) void {
        // Assert: register index must be valid (0-31).
        std.debug.assert(reg < 32);
        
        // x0 is hardwired to zero (RISC-V spec: writes to x0 are ignored).
        if (reg == 0) {
            return;
        }
        
        self.regs[reg] = value;
        
        // Assert: register value must be set correctly (unless x0).
        std.debug.assert(reg == 0 or self.regs[reg] == value);
    }
};

/// RISC-V64 virtual machine state.
/// Why: Encapsulate all VM state for deterministic execution.
pub const VM = struct {
    /// Register file (32 GP registers + PC).
    regs: RegisterFile = .{},
    /// Physical memory (4MB static allocation).
    /// Why: Static allocation eliminates allocator dependency.
    /// Note: RISC-V64 typically uses 48-bit physical addresses, but we
    /// use 4MB for kernel development (sufficient for early boot).
    memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024),
    /// Memory size in bytes.
    memory_size: usize = 4 * 1024 * 1024,
    /// VM execution state (running, halted, error).
    state: VMState = .halted,
    /// Last error (if state == .errored).
    /// Note: Using optional error set for error tracking.
    last_error: ?VMError = null,

    const Self = @This();
    
    pub const VMState = enum {
        running,
        halted,
        errored,
    };
    
    pub const VMError = error{
        invalid_instruction,
        invalid_memory_access,
        unaligned_instruction,
        unaligned_memory_access,
    };

    /// Initialize VM with kernel image loaded at address.
    /// Why: Explicit initialization ensures deterministic state.
    pub fn init(kernel_image: []const u8, load_address: u64) Self {
        // Assert: kernel image must be non-empty.
        std.debug.assert(kernel_image.len > 0);
        
        // Assert: load address must be aligned (4-byte alignment for RISC-V).
        std.debug.assert(load_address % 4 == 0);
        
        // Assert: kernel image must fit in memory.
        std.debug.assert(load_address + kernel_image.len <= 4 * 1024 * 1024);
        
        var vm = Self{
            .regs = .{},
            .memory = [_]u8{0} ** (4 * 1024 * 1024),
            .memory_size = 4 * 1024 * 1024,
            .state = .halted,
            .last_error = null,
        };
        
        // Load kernel image into memory.
        // Why: Copy kernel bytes to VM memory at load address.
        @memcpy(vm.memory[@intCast(load_address)..][0..kernel_image.len], kernel_image);
        
        // Set PC to load address (kernel entry point).
        vm.regs.pc = load_address;
        
        // Assert: PC must be set correctly.
        std.debug.assert(vm.regs.pc == load_address);
        
        // Assert: kernel image must be loaded correctly.
        std.debug.assert(std.mem.eql(u8, vm.memory[@intCast(load_address)..][0..kernel_image.len], kernel_image));
        
        return vm;
    }

    /// Read memory at address (little-endian, 8 bytes).
    /// Tiger Style: Validate address, bounds checking, alignment.
    pub fn read64(self: *const Self, addr: u64) VMError!u64 {
        // Assert: address must be within memory bounds.
        std.debug.assert(addr + 8 <= self.memory_size);
        
        // Assert: address must be 8-byte aligned (RISC-V64 requirement).
        if (addr % 8 != 0) {
            return VMError.unaligned_memory_access;
        }
        
        // Read 8 bytes (little-endian).
        const bytes = self.memory[@intCast(addr)..][0..8];
        const value = std.mem.readInt(u64, bytes, .little);
        
        return value;
    }

    /// Write memory at address (little-endian, 8 bytes).
    /// Tiger Style: Validate address, bounds checking, alignment.
    pub fn write64(self: *Self, addr: u64, value: u64) VMError!void {
        // Assert: address must be within memory bounds.
        std.debug.assert(addr + 8 <= self.memory_size);
        
        // Assert: address must be 8-byte aligned (RISC-V64 requirement).
        if (addr % 8 != 0) {
            return VMError.unaligned_memory_access;
        }
        
        // Write 8 bytes (little-endian).
        const bytes = self.memory[@intCast(addr)..][0..8];
        std.mem.writeInt(u64, bytes, value, .little);
        
        // Assert: value must be written correctly.
        const read_back = try self.read64(addr);
        std.debug.assert(read_back == value);
    }

    /// Read instruction at PC (32-bit, little-endian).
    /// Tiger Style: Validate PC, bounds checking, alignment.
    pub fn fetchInstruction(self: *const Self) VMError!u32 {
        const pc = self.regs.pc;
        
        // Assert: PC must be within memory bounds.
        std.debug.assert(pc + 4 <= self.memory_size);
        
        // Assert: PC must be 4-byte aligned (RISC-V instruction alignment).
        if (pc % 4 != 0) {
            return VMError.unaligned_instruction;
        }
        
        // Read 32-bit instruction (little-endian).
        const bytes = self.memory[@intCast(pc)..][0..4];
        const inst = std.mem.readInt(u32, bytes, .little);
        
        return inst;
    }

    /// Execute single instruction (decode and execute).
    /// Tiger Style: Comprehensive instruction decoding, assertions.
    pub fn step(self: *Self) VMError!void {
        // Assert: VM must be in running state.
        if (self.state != .running) {
            return;
        }
        
        // Fetch instruction at PC.
        const inst = try self.fetchInstruction();
        
        // Decode instruction opcode (bits [6:0]).
        const opcode = @as(u7, @truncate(inst));
        
        // Execute based on opcode.
        // Why: RISC-V uses opcode-based instruction decoding.
        switch (opcode) {
            // LUI (Load Upper Immediate): U-type instruction.
            0b0110111 => {
                try self.executeLUI(inst);
            },
            // ADDI (Add Immediate): I-type instruction.
            0b0010011 => {
                // ADDI has multiple variants (funct3 field).
                // For now, handle basic ADDI (funct3 = 0b000).
                const funct3 = @as(u3, @truncate(inst >> 12));
                if (funct3 == 0b000) {
                    try self.executeADDI(inst);
                } else {
                    // Unsupported I-type instruction variant.
                    self.state = .errored;
                    self.last_error = VMError.invalid_instruction;
                    return VMError.invalid_instruction;
                }
            },
            // ECALL (Environment Call): I-type instruction (funct3 = 0, funct7 = 0).
            0b1110011 => {
                const funct3 = @as(u3, @truncate(inst >> 12));
                if (funct3 == 0b000) {
                    try self.executeECALL();
                } else {
                    // Unsupported system instruction.
                    self.state = .errored;
                    self.last_error = VMError.invalid_instruction;
                    return VMError.invalid_instruction;
                }
            },
            else => {
                // Unsupported opcode.
                self.state = .errored;
                self.last_error = VMError.invalid_instruction;
                return VMError.invalid_instruction;
            },
        }
        
        // Advance PC to next instruction (4 bytes).
        self.regs.pc += 4;
    }

    /// Execute LUI (Load Upper Immediate) instruction.
    /// Format: LUI rd, imm[31:12]
    /// Why: Separate function for clarity and Tiger Style function length.
    fn executeLUI(self: *Self, inst: u32) !void {
        // Decode: rd = bits [11:7], imm[31:12] = bits [31:12].
        const rd = @as(u5, @truncate(inst >> 7));
        const imm = @as(u32, inst) & 0xFFFFF000; // Extract bits [31:12].
        
        // Sign-extend imm[31:12] to 64 bits.
        const imm64 = @as(i32, @bitCast(imm)) << 12;
        const imm64_unsigned = @as(u64, @intCast(imm64));
        
        // Write result to rd.
        self.regs.set(rd, imm64_unsigned);
    }

    /// Execute ADDI (Add Immediate) instruction.
    /// Format: ADDI rd, rs1, imm[11:0]
    /// Why: Separate function for clarity and Tiger Style function length.
    fn executeADDI(self: *Self, inst: u32) !void {
        // Decode: rd = bits [11:7], rs1 = bits [19:15], imm[11:0] = bits [31:20].
        const rd = @as(u5, @truncate(inst >> 7));
        const rs1 = @as(u5, @truncate(inst >> 15));
        const imm12 = @as(i32, @truncate(@as(i64, inst >> 20)));
        
        // Sign-extend imm[11:0] to 64 bits.
        const imm64 = @as(i64, imm12);
        
        // Read rs1 value.
        const rs1_value = self.regs.get(rs1);
        
        // Add: rd = rs1 + imm (wrapping addition).
        const result = @as(u64, @intCast(@as(i64, @bitCast(rs1_value)) + imm64));
        
        // Write result to rd.
        self.regs.set(rd, result);
    }

    /// Execute ECALL (Environment Call) instruction.
    /// Format: ECALL (no operands, triggers system call).
    /// Why: Handle kernel syscalls via ECALL instruction.
    fn executeECALL(self: *Self) !void {
        // ECALL triggers a system call.
        // For now, halt VM (kernel can implement syscall handler later).
        // Why: Simple implementation for initial VM; kernel will handle syscalls.
        self.state = .halted;
    }

    /// Start VM execution (set state to running).
    /// Tiger Style: Validate state transitions.
    pub fn start(self: *Self) void {
        // Assert: VM must be halted or errored state to start.
        std.debug.assert(self.state == .halted or self.state == .errored);
        
        self.state = .running;
        self.last_error = null;
        
        // Assert: VM must be in running state after start.
        std.debug.assert(self.state == .running);
    }

    /// Stop VM execution (set state to halted).
    /// Tiger Style: Validate state transitions.
    pub fn stop(self: *Self) void {
        self.state = .halted;
        
        // Assert: VM must be in halted state after stop.
        std.debug.assert(self.state == .halted);
    }
};

