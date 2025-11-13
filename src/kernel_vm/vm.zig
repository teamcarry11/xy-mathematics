const std = @import("std");
const sbi = @import("sbi");
const SerialOutput = @import("serial.zig").SerialOutput;

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
    /// Syscall handler callback (optional).
    /// Why: Allow external syscall handling (e.g., Grain Basin kernel).
    /// Note: Type-erased to avoid requiring basin_kernel import at module level.
    syscall_handler: ?*const fn (syscall_num: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64 = null,
    /// User data for syscall handler (optional).
    /// Why: Pass context to syscall handler (e.g., Basin Kernel instance).
    syscall_user_data: ?*anyopaque = null,
    /// Serial output handler (for SBI console output).
    /// Why: Capture SBI console output (LEGACY_CONSOLE_PUTCHAR) for display.
    serial_output: ?*SerialOutput = null,

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
    pub fn fetch_instruction(self: *const Self) VMError!u32 {
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
        
        // Store PC before instruction execution (for branch detection).
        const pc_before = self.regs.pc;
        
        // Assert: PC must be 4-byte aligned (RISC-V instruction alignment).
        std.debug.assert(pc_before % 4 == 0);
        
        // Assert: PC must be within memory bounds.
        std.debug.assert(pc_before < self.memory_size);
        
        // Fetch instruction at PC.
        const inst = try self.fetch_instruction();
        
        // Assert: instruction must be valid (not all zeros or all ones).
        std.debug.assert(inst != 0x00000000);
        std.debug.assert(inst != 0xFFFFFFFF);
        
        // Decode instruction opcode (bits [6:0]).
        const opcode = @as(u7, @truncate(inst));
        
        // Execute based on opcode.
        // Why: RISC-V uses opcode-based instruction decoding.
        switch (opcode) {
            // LUI (Load Upper Immediate): U-type instruction.
            0b0110111 => {
                try self.execute_lui(inst);
            },
            // ADDI (Add Immediate): I-type instruction.
            0b0010011 => {
                // ADDI has multiple variants (funct3 field).
                // For now, handle basic ADDI (funct3 = 0b000).
                const funct3 = @as(u3, @truncate(inst >> 12));
                if (funct3 == 0b000) {
                    try self.execute_addi(inst);
                } else {
                    // Unsupported I-type instruction variant.
                    self.state = .errored;
                    self.last_error = VMError.invalid_instruction;
                    return VMError.invalid_instruction;
                }
            },
            // Load instructions (LW): I-type instruction.
            0b0000011 => {
                const funct3 = @as(u3, @truncate(inst >> 12));
                if (funct3 == 0b010) {
                    // LW (Load Word): Load 32-bit word from memory.
                    try self.execute_lw(inst);
                } else {
                    // Unsupported load instruction variant.
                    self.state = .errored;
                    self.last_error = VMError.invalid_instruction;
                    return VMError.invalid_instruction;
                }
            },
            // Store instructions (SW): S-type instruction.
            0b0100011 => {
                const funct3 = @as(u3, @truncate(inst >> 12));
                if (funct3 == 0b010) {
                    // SW (Store Word): Store 32-bit word to memory.
                    try self.execute_sw(inst);
                } else {
                    // Unsupported store instruction variant.
                    self.state = .errored;
                    self.last_error = VMError.invalid_instruction;
                    return VMError.invalid_instruction;
                }
            },
            // Branch instructions (BEQ): B-type instruction.
            0b1100011 => {
                const funct3 = @as(u3, @truncate(inst >> 12));
                if (funct3 == 0b000) {
                    // BEQ (Branch if Equal): Branch if rs1 == rs2.
                    try self.execute_beq(inst);
                } else {
                    // Unsupported branch instruction variant.
                    self.state = .errored;
                    self.last_error = VMError.invalid_instruction;
                    return VMError.invalid_instruction;
                }
            },
            // ECALL (Environment Call): I-type instruction (funct3 = 0, funct7 = 0).
            0b1110011 => {
                const funct3 = @as(u3, @truncate(inst >> 12));
                if (funct3 == 0b000) {
                    try self.execute_ecall();
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
        // Note: BEQ may have already updated PC for branch, so check if PC was modified.
        // Branch instructions modify PC directly, so we don't increment again.
        if (self.regs.pc == pc_before) {
            // Normal case: PC unchanged by instruction, advance by 4 bytes.
            self.regs.pc += 4;
        }
        // Else: PC was modified by branch instruction (BEQ), don't increment again.
        
        // Assert: PC must be 4-byte aligned after instruction execution.
        std.debug.assert(self.regs.pc % 4 == 0);
        
        // Assert: PC must be within memory bounds after execution.
        std.debug.assert(self.regs.pc <= self.memory_size);
    }

    /// Execute LUI (Load Upper Immediate) instruction.
    /// Format: LUI rd, imm[31:12]
    /// Why: Separate function for clarity and Tiger Style function length.
    fn execute_lui(self: *Self, inst: u32) !void {
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
    fn execute_addi(self: *Self, inst: u32) !void {
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

    /// Execute LW (Load Word) instruction.
    /// Format: LW rd, offset(rs1)
    /// Encoding: imm[11:0] | rs1 | 010 | rd | 0000011
    /// Why: Load 32-bit word from memory for kernel data access.
    fn execute_lw(self: *Self, inst: u32) !void {
        // Decode: rd = bits [11:7], rs1 = bits [19:15], imm[11:0] = bits [31:20].
        const rd = @as(u5, @truncate(inst >> 7));
        const rs1 = @as(u5, @truncate(inst >> 15));
        const imm12 = @as(i32, @truncate(@as(i64, inst >> 20)));
        
        // Assert: registers must be valid (0-31).
        std.debug.assert(rd < 32);
        std.debug.assert(rs1 < 32);
        
        // Read base address from rs1.
        const base_addr = self.regs.get(rs1);
        
        // Sign-extend immediate to 64 bits.
        const imm64 = @as(i64, imm12);
        const offset = @as(u64, @intCast(imm64));
        
        // Calculate effective address: base_addr + offset.
        const eff_addr = base_addr +% offset;
        
        // Assert: effective address must be 4-byte aligned for word load.
        if (eff_addr % 4 != 0) {
            self.state = .errored;
            self.last_error = VMError.unaligned_memory_access;
            return VMError.unaligned_memory_access;
        }
        
        // Assert: effective address must be within memory bounds.
        if (eff_addr + 4 > self.memory_size) {
            self.state = .errored;
            self.last_error = VMError.invalid_memory_access;
            return VMError.invalid_memory_access;
        }
        
        // Read 32-bit word from memory (sign-extend to 64 bits).
        // Assert: memory access must be within bounds (already checked above).
        std.debug.assert(eff_addr + 4 <= self.memory_size);
        
        const mem_slice = self.memory[@as(usize, @intCast(eff_addr))..][0..4];
        const word = std.mem.readInt(u32, mem_slice, .little);
        const word_signed = @as(i32, @bitCast(word));
        const word64 = @as(u64, @intCast(word_signed));
        
        // Write to destination register.
        self.regs.set(rd, word64);
    }

    /// Execute SW (Store Word) instruction.
    /// Format: SW rs2, offset(rs1)
    /// Encoding: imm[11:5] | rs2 | rs1 | 010 | imm[4:0] | 0100011
    /// Why: Store 32-bit word to memory for kernel data writes.
    fn execute_sw(self: *Self, inst: u32) !void {
        // Decode S-type: rs2 = bits [24:20], rs1 = bits [19:15], imm[11:5] = bits [31:25], imm[4:0] = bits [11:7].
        const rs2 = @as(u5, @truncate(inst >> 20));
        const rs1 = @as(u5, @truncate(inst >> 15));
        const imm_11_5 = @as(u7, @truncate(inst >> 25));
        const imm_4_0 = @as(u5, @truncate(inst >> 7));
        
        // Assert: registers must be valid (0-31).
        std.debug.assert(rs2 < 32);
        std.debug.assert(rs1 < 32);
        
        // Reconstruct 12-bit immediate: imm[11:5] | imm[4:0].
        const imm12_raw = (@as(u12, imm_11_5) << 5) | imm_4_0;
        const imm12 = @as(i32, @truncate(@as(i64, @as(i12, @bitCast(imm12_raw)))));
        
        // Read base address from rs1.
        const base_addr = self.regs.get(rs1);
        
        // Sign-extend immediate to 64 bits.
        const imm64 = @as(i64, imm12);
        const offset = @as(u64, @intCast(imm64));
        
        // Calculate effective address: base_addr + offset.
        const eff_addr = base_addr +% offset;
        
        // Assert: effective address must be 4-byte aligned for word store.
        if (eff_addr % 4 != 0) {
            self.state = .errored;
            self.last_error = VMError.unaligned_memory_access;
            return VMError.unaligned_memory_access;
        }
        
        // Assert: effective address must be within memory bounds.
        if (eff_addr + 4 > self.memory_size) {
            self.state = .errored;
            self.last_error = VMError.invalid_memory_access;
            return VMError.invalid_memory_access;
        }
        
        // Read source value from rs2 (truncate to 32 bits).
        const rs2_value = self.regs.get(rs2);
        const word = @as(u32, @truncate(rs2_value));
        
        // Write 32-bit word to memory.
        @memcpy(self.memory[@as(usize, @intCast(eff_addr))..][0..4], &std.mem.toBytes(word));
    }

    /// Execute BEQ (Branch if Equal) instruction.
    /// Format: BEQ rs1, rs2, offset
    /// Encoding: imm[12] | imm[10:5] | rs2 | rs1 | 000 | imm[4:1] | imm[11] | 1100011
    /// Why: Conditional branch for kernel control flow.
    fn execute_beq(self: *Self, inst: u32) !void {
        // Decode B-type: rs2 = bits [24:20], rs1 = bits [19:15], imm[12] = bit [31], imm[10:5] = bits [30:25],
        // imm[4:1] = bits [11:8], imm[11] = bit [7].
        const rs2 = @as(u5, @truncate(inst >> 20));
        const rs1 = @as(u5, @truncate(inst >> 15));
        const imm_12 = @as(u1, @truncate(inst >> 31));
        const imm_10_5 = @as(u6, @truncate(inst >> 25));
        const imm_4_1 = @as(u4, @truncate(inst >> 8));
        const imm_11 = @as(u1, @truncate(inst >> 7));
        
        // Assert: registers must be valid (0-31).
        std.debug.assert(rs2 < 32);
        std.debug.assert(rs1 < 32);
        
        // Reconstruct 13-bit immediate (sign-extended): imm[12] | imm[11] | imm[10:5] | imm[4:1] | 0.
        const imm13_raw = (@as(u13, imm_12) << 12) | (@as(u13, imm_11) << 11) | (@as(u13, imm_10_5) << 5) | (@as(u13, imm_4_1) << 1);
        const imm13 = @as(i13, @bitCast(imm13_raw));
        
        // Read register values.
        const rs1_value = self.regs.get(rs1);
        const rs2_value = self.regs.get(rs2);
        
        // Compare: if rs1 == rs2, branch.
        if (rs1_value == rs2_value) {
            // Sign-extend immediate to 64 bits and add to PC.
            const imm64 = @as(i64, imm13);
            const offset = @as(u64, @intCast(imm64));
            
            // Calculate branch target: PC + offset.
            const branch_target = self.regs.pc +% offset;
            
            // Assert: branch target must be 4-byte aligned.
            if (branch_target % 4 != 0) {
                self.state = .errored;
                self.last_error = VMError.unaligned_instruction;
                return VMError.unaligned_instruction;
            }
            
            // Assert: branch target must be within memory bounds.
            if (branch_target >= self.memory_size) {
                self.state = .errored;
                self.last_error = VMError.invalid_memory_access;
                return VMError.invalid_memory_access;
            }
            
            // Update PC to branch target (PC update happens before normal +4 increment).
            // Note: We'll skip the normal PC += 4 after this instruction.
            self.regs.pc = branch_target;
            
            // Return early to skip normal PC increment.
            return;
        }
        
        // No branch: PC will be incremented normally by +4 in step().
    }

    /// Execute ECALL (Environment Call) instruction.
    /// Format: ECALL (no operands, triggers system call).
    /// Why: Handle SBI calls (platform services) and Grain Basin kernel syscalls.
    /// RISC-V calling convention: a7 (x17) = syscall/EID number, a0-a5 (x10-x15) = arguments.
    /// SBI vs Kernel: Function ID < 10 → SBI (platform), >= 10 → kernel syscall.
    /// Tiger Style: Comprehensive assertions for ECALL dispatch, arguments, and state transitions.
    fn execute_ecall(self: *Self) !void {
        // Assert: VM must be in valid state (running or halted, not errored).
        std.debug.assert(self.state != .errored);
        
        // Assert: VM must be running (ECALL only valid when running).
        std.debug.assert(self.state == .running);
        
        // RISC-V syscall convention: a7 (x17) contains syscall/EID number.
        const syscall_num = self.regs.get(17); // a7 register
        
        // Assert: syscall number must fit in u32.
        std.debug.assert(syscall_num <= 0xFFFFFFFF);
        
        // Assert: syscall number must be within reasonable range (0-50).
        std.debug.assert(syscall_num <= 50);
        
        // Extract syscall arguments from a0-a5 registers (x10-x15).
        const arg1 = self.regs.get(10); // a0
        const arg2 = self.regs.get(11); // a1
        const arg3 = self.regs.get(12); // a2
        const arg4 = self.regs.get(13); // a3
        
        // Dispatch: SBI calls (function ID < 10) vs kernel syscalls (>= 10).
        // Why: SBI handles platform services (timer, console, reset), kernel handles kernel services.
        if (syscall_num < 10) {
            // Assert: SBI call must have function ID < 10.
            std.debug.assert(syscall_num < 10);
            
            // SBI call: Handle platform services.
            self.handle_sbi_call(@as(u32, @truncate(syscall_num)), arg1, arg2, arg3, arg4);
            
            // Assert: VM state must remain valid after SBI call (unless shutdown).
            if (syscall_num != @intFromEnum(sbi.EID.LEGACY_SHUTDOWN)) {
                std.debug.assert(self.state != .errored);
            }
        } else {
            // Assert: Kernel syscall must have function ID >= 10.
            std.debug.assert(syscall_num >= 10);
            
            // Kernel syscall: Handle via callback if available.
            if (self.syscall_handler) |handler| {
                // Assert: handler pointer must be valid.
                const handler_ptr = @intFromPtr(handler);
                std.debug.assert(handler_ptr != 0);
                
                // Call syscall handler and get result.
                const result = handler(
                    @as(u32, @truncate(syscall_num)),
                    arg1,
                    arg2,
                    arg3,
                    arg4,
                );
                
                // Assert: result must be valid (can be error code if negative when interpreted as i64).
                // Note: Error codes are negative, success values are non-negative.
                
                // Store result in a0 (x10) register (RISC-V convention).
                self.regs.set(10, result);
                
                // Assert: a0 register must be set correctly.
                std.debug.assert(self.regs.get(10) == result);
                
                // Special case: exit syscall (syscall number 2) halts VM.
                // Note: This is kernel syscall 2, not SBI function ID 2.
                // Note: Kernel syscall 2 is exit, which should halt VM.
                if (syscall_num == 2) {
                    // Assert: exit syscall must halt VM.
                    std.debug.assert(syscall_num == 2);
                    self.state = .halted;
                    
                    // Assert: VM state must be halted after exit syscall.
                    std.debug.assert(self.state == .halted);
                } else {
                    // Assert: Non-exit syscalls should not halt VM.
                    std.debug.assert(self.state == .running);
                }
            } else {
                // Assert: No handler should only happen if handler not set.
                std.debug.assert(self.syscall_handler == null);
                
                // No handler: halt VM (simple behavior).
                self.state = .halted;
                
                // Assert: VM state must be halted when no handler.
                std.debug.assert(self.state == .halted);
            }
        }
        
        // Assert: VM state must remain valid after ECALL (unless shutdown/exit).
        if (syscall_num != @intFromEnum(sbi.EID.LEGACY_SHUTDOWN) and syscall_num != 2) {
            std.debug.assert(self.state != .errored);
        }
    }
    
    /// Handle SBI (Supervisor Binary Interface) call.
    /// Why: Implement platform services (timer, console, reset) for RISC-V SBI.
    /// SBI Legacy Functions: 0x0=SET_TIMER, 0x1=CONSOLE_PUTCHAR, 0x2=CONSOLE_GETCHAR, 0x8=SHUTDOWN.
    /// Tiger Style: Comprehensive assertions for all SBI call parameters and state transitions.
    fn handle_sbi_call(self: *Self, eid: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64) void {
        // Mark unused parameters for future SBI functions.
        _ = arg2;
        _ = arg3;
        _ = arg4;
        
        // Assert: VM must be in valid state (running or halted, not errored).
        std.debug.assert(self.state != .errored);
        
        // Assert: EID must be valid SBI legacy function ID (< 10).
        std.debug.assert(eid < 10);
        
        // Assert: EID must match known SBI legacy function IDs.
        std.debug.assert(eid <= @intFromEnum(sbi.EID.LEGACY_SHUTDOWN));
        
        // Dispatch based on SBI Extension ID (EID).
        // Why: Different SBI functions have different calling conventions.
        switch (eid) {
            // LEGACY_CONSOLE_PUTCHAR (0x1): Write character to console.
            // Calling convention: character in a0 (x10), no return value.
            @intFromEnum(sbi.EID.LEGACY_CONSOLE_PUTCHAR) => {
                // Assert: character must fit in u8.
                std.debug.assert(arg1 <= 0xFF);
                
                // Assert: serial_output pointer must be valid if set.
                if (self.serial_output) |serial| {
                    // Assert: serial pointer must be non-null and aligned.
                    const serial_ptr = @intFromPtr(serial);
                    std.debug.assert(serial_ptr != 0);
                    std.debug.assert(serial_ptr % @alignOf(@TypeOf(serial.*)) == 0);
                    
                    // Write character to serial output.
                    serial.writeByte(@as(u8, @truncate(arg1)));
                    
                    // Assert: serial output write position must be valid after write.
                    std.debug.assert(serial.write_pos < serial.buffer.len);
                }
                
                // SBI CONSOLE_PUTCHAR returns 0 (success) in a0.
                self.regs.set(10, 0);
                
                // Assert: a0 register must be set to 0 (success).
                std.debug.assert(self.regs.get(10) == 0);
            },
            // LEGACY_SHUTDOWN (0x8): System shutdown.
            // Calling convention: no arguments, no return value.
            @intFromEnum(sbi.EID.LEGACY_SHUTDOWN) => {
                // Assert: VM state must be valid before shutdown.
                std.debug.assert(self.state != .errored);
                
                // Halt VM on shutdown.
                self.state = .halted;
                
                // Assert: VM state must be halted after shutdown.
                std.debug.assert(self.state == .halted);
                
                // SBI SHUTDOWN doesn't return.
                self.regs.set(10, 0);
            },
            // Other SBI functions: Not implemented yet.
            // TODO: Implement SET_TIMER, CONSOLE_GETCHAR, etc.
            else => {
                // Assert: Unknown SBI function must return error code.
                std.debug.assert(eid != @intFromEnum(sbi.EID.LEGACY_CONSOLE_PUTCHAR));
                std.debug.assert(eid != @intFromEnum(sbi.EID.LEGACY_SHUTDOWN));
                
                // Unknown SBI function: Return error code.
                // SBI error codes: -1 = Failed, -2 = NotSupported.
                const error_code: i64 = -2; // NotSupported
                self.regs.set(10, @as(u64, @bitCast(error_code)));
                
                // Assert: a0 register must contain error code.
                const result = @as(i64, @bitCast(self.regs.get(10)));
                std.debug.assert(result == error_code);
            },
        }
        
        // Assert: VM state must remain valid after SBI call (unless shutdown).
        if (eid != @intFromEnum(sbi.EID.LEGACY_SHUTDOWN)) {
            std.debug.assert(self.state != .errored);
        }
    }
    
    /// Set serial output handler for SBI console.
    /// Why: Allow external serial output handling (e.g., GUI display).
    /// Tiger Style: Validate serial pointer, ensure proper initialization.
    pub fn set_serial_output(self: *Self, serial: ?*SerialOutput) void {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(Self) == 0);
        
        // Assert: serial pointer must be valid if provided.
        if (serial) |s| {
            const serial_ptr = @intFromPtr(s);
            std.debug.assert(serial_ptr != 0);
            std.debug.assert(serial_ptr % @alignOf(SerialOutput) == 0);
            
            // Assert: serial buffer must be initialized (non-null).
            std.debug.assert(s.buffer.len > 0);
        }
        
        self.serial_output = serial;
        
        // Assert: serial_output must be set correctly.
        std.debug.assert(self.serial_output == serial);
    }
    
    /// Set syscall handler callback.
    /// Why: Allow external syscall handling (e.g., Grain Basin kernel).
    pub fn set_syscall_handler(self: *Self, handler: *const fn (syscall_num: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64, user_data: ?*anyopaque) void {
        self.syscall_handler = handler;
        self.syscall_user_data = user_data;
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

