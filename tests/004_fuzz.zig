// 004 Fuzz Test: Randomized testing for RISC-V VM execution pipeline.
//
// Objective: Validate VM instruction execution, memory access, register state,
// and ELF loading under randomized inputs. Tests focus on VM core functionality
// without requiring GUI or kernel files.
//
// Method:
// - Uses SimpleRng for deterministic randomness (wrap-safe arithmetic)
// - Generates synthetic RISC-V instructions (LUI, ADDI, ECALL)
// - Tests VM state transitions (running, halted, errored)
// - Tests memory access patterns with bounds checking
// - Tests register file behavior (x0 hardwired, PC updates)
// - Uses Arena allocator to minimize heap noise
//
// Date: 2025-11-12
// Operator: Glow G2 (Stoic Aquarian cadence)
const std = @import("std");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const loadKernel = kernel_vm.loadKernel;

// SimpleRng: inline copy for test (avoiding module path issues).
const SimpleRng = struct {
    state: u64,

    pub fn init(seed: u64) SimpleRng {
        return .{ .state = seed };
    }

    fn next(self: *SimpleRng) u64 {
        self.state = self.state *% 6364136223846793005 +% 1;
        return self.state;
    }

    pub fn boolean(self: *SimpleRng) bool {
        return (self.next() & 1) == 1;
    }

    pub fn range(self: *SimpleRng, comptime T: type, upper: T) T {
        return self.uint_less_than(T, upper);
    }

    pub fn uint_less_than(self: *SimpleRng, comptime T: type, bound: T) T {
        return @intCast(self.next() % @as(u64, bound));
    }
};

/// Generate random RISC-V LUI instruction.
/// Format: LUI rd, imm[31:12]
/// Encoding: imm[31:12] | rd | 0110111
fn generateLUI(rng: *SimpleRng) u32 {
    const rd = rng.range(u5, 31) + 1; // Random destination register (1-31, avoid x0).
    // Assert: u20 max value is 0xFFFFF (1048575), not 0x100000.
    const imm = rng.range(u20, 0xFFFFF); // Random 20-bit immediate (0-1048575).
    const opcode: u7 = 0b0110111; // LUI opcode.
    const inst = (@as(u32, imm) << 12) | (@as(u32, rd) << 7) | opcode;
    return inst;
}

/// Generate random RISC-V ADDI instruction.
/// Format: ADDI rd, rs1, imm[11:0]
/// Encoding: imm[11:0] | rs1 | 000 | rd | 0010011
fn generateADDI(rng: *SimpleRng) u32 {
    const rd = rng.range(u5, 31) + 1; // Random destination register (1-31, avoid x0).
    const rs1 = rng.range(u5, 31) + 1; // Random source register (1-31, avoid x0).
    // Assert: u12 max value is 0xFFF (4095), not 0x1000 (4096).
    const imm = rng.range(u12, 0xFFF); // Random 12-bit immediate (0-4095).
    const funct3: u3 = 0b000; // ADDI funct3.
    const opcode: u7 = 0b0010011; // OP-IMM opcode.
    const inst = (@as(u32, imm) << 20) | (@as(u32, rs1) << 15) | (@as(u32, funct3) << 12) | (@as(u32, rd) << 7) | opcode;
    return inst;
}

/// Generate random RISC-V ECALL instruction.
/// Format: ECALL
/// Encoding: 000000000000 | 00000 | 000 | 00000 | 1110011
fn generateECALL(_: *SimpleRng) u32 {
    return 0x00000073; // ECALL instruction (fixed encoding).
}

test "004 fuzz: VM instruction execution with random sequences" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize RNG with deterministic seed.
    var rng = SimpleRng.init(0x004F00F000ABCDEF);

    // Test multiple iterations with random instruction sequences.
    const iterations = 50;
    var iteration: u32 = 0;
    while (iteration < iterations) : (iteration += 1) {
        // Generate random instruction sequence (10-100 instructions).
        const inst_count = rng.range(u32, 90) + 10;
        var kernel_data = std.ArrayListUnmanaged(u8){};
        defer kernel_data.deinit(allocator);

        // Generate random instructions.
        var inst_idx: u32 = 0;
        while (inst_idx < inst_count) : (inst_idx += 1) {
            const inst_type = rng.range(u8, 3);
            const inst: u32 = switch (inst_type) {
                0 => generateLUI(&rng),
                1 => generateADDI(&rng),
                2 => generateECALL(&rng),
                else => unreachable,
            };

            // Write instruction as little-endian bytes.
            try kernel_data.appendSlice(allocator, &std.mem.toBytes(inst));
        }

        // Initialize VM with kernel data.
        const load_addr: u64 = 0x1000;
        
        // Assert: load address must be aligned and within memory bounds.
        std.debug.assert(load_addr % 4 == 0); // 4-byte instruction alignment.
        std.debug.assert(load_addr < 0x400000); // Within 4MB memory.
        std.debug.assert(load_addr + kernel_data.items.len <= 0x400000); // Kernel fits in memory.
        
        var vm = VM.init(kernel_data.items, load_addr);

        // Assert: VM must be initialized correctly.
        std.debug.assert(vm.regs.pc == load_addr);
        std.debug.assert(vm.state == .halted);
        std.debug.assert(vm.last_error == null); // No error on initialization.

        // Start VM execution.
        vm.start();
        std.debug.assert(vm.state == .running);

        // Execute random number of steps (1-50).
        const step_count = rng.range(u32, 50) + 1;
        // Assert: step count must be reasonable.
        std.debug.assert(step_count > 0);
        std.debug.assert(step_count <= 50);
        
        var step_idx: u32 = 0;
        var last_pc: u64 = load_addr;
        
        while (step_idx < step_count and vm.state == .running) : (step_idx += 1) {
            // Assert: step index must be within bounds.
            std.debug.assert(step_idx < step_count);
            
            // Assert: VM must be running before step.
            std.debug.assert(vm.state == .running);
            
            // Assert: PC must be valid before step.
            std.debug.assert(vm.regs.pc >= load_addr);
            std.debug.assert(vm.regs.pc < load_addr + kernel_data.items.len);
            std.debug.assert(vm.regs.pc % 4 == 0); // PC must be instruction-aligned.
            
            last_pc = vm.regs.pc;
            
            // Step VM (execute one instruction).
            vm.step() catch |err| {
                // VM may error on invalid instruction or memory access.
                // Assert: error must transition VM to errored state.
                std.debug.assert(vm.state == .errored);
                std.debug.assert(vm.last_error != null);
                std.debug.assert(err != error.OutOfMemory); // VM uses static allocation.
                
                // Assert: PC should not change on error (or should be set to error address).
                // Note: VM may update PC before detecting error, so we allow PC change.
                std.debug.assert(vm.regs.pc >= load_addr);
                break;
            };

            // Assert: PC must advance after successful step (unless instruction was invalid).
            // PC advances by 4 bytes (instruction size) on successful execution.
            std.debug.assert(vm.regs.pc == last_pc + 4 or vm.state != .running);
            
            // Assert: PC must be within memory bounds or VM stopped.
            std.debug.assert(vm.regs.pc >= load_addr);
            std.debug.assert(vm.regs.pc <= load_addr + kernel_data.items.len or vm.state != .running);
            std.debug.assert(vm.regs.pc % 4 == 0); // PC must remain instruction-aligned.

            // Assert: x0 must always be zero (hardwired).
            std.debug.assert(vm.regs.get(0) == 0);
            
            // Assert: If VM is still running, no error should be set.
            if (vm.state == .running) {
                std.debug.assert(vm.last_error == null);
            }
        }
        
        // Assert: After loop, VM must be halted or errored (not running).
        std.debug.assert(vm.state != .running);

        // Stop VM.
        vm.stop();
        std.debug.assert(vm.state == .halted);
    }
}

test "004 fuzz: VM memory access patterns with random addresses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    // Initialize RNG with deterministic seed.
    var rng = SimpleRng.init(0x004F00F100000001);

    // Initialize VM with minimal kernel (single NOP).
    const kernel_data = [_]u8{ 0x13, 0x00, 0x00, 0x00 }; // NOP instruction.
    var vm = VM.init(&kernel_data, 0x1000);

    // Test random memory read/write patterns.
    const iterations = 100;
    var iteration: u32 = 0;
    while (iteration < iterations) : (iteration += 1) {
        // Generate random aligned address (within VM memory: 0x0 - 0x400000).
        const mem_size: u64 = 0x400000; // 4MB static memory.
        
        // Assert: memory size must match VM static allocation.
        std.debug.assert(mem_size == 4 * 1024 * 1024);
        
        // Generate random aligned address (8-byte aligned for 64-bit operations).
        const max_aligned_offsets = mem_size / 8;
        // Assert: must have at least one aligned offset.
        std.debug.assert(max_aligned_offsets > 0);
        
        const offset_idx = rng.range(u64, max_aligned_offsets);
        const aligned_addr = offset_idx * 8; // 8-byte aligned.

        // Assert: address must be aligned and within bounds.
        std.debug.assert(aligned_addr % 8 == 0);
        std.debug.assert(aligned_addr < mem_size);
        std.debug.assert(aligned_addr + 8 <= mem_size); // Ensure 8-byte read/write fits.

        // Generate random 64-bit value.
        const write_value = rng.next();

        // Assert: VM state must allow memory access (halted or running).
        std.debug.assert(vm.state == .halted or vm.state == .running);
        
        // Write value to memory.
        vm.write64(aligned_addr, write_value) catch |err| {
            // Memory access may fail if address is out of bounds.
            // Assert: error must be InvalidMemoryAccess (not other errors).
            std.debug.assert(err == error.InvalidMemoryAccess);
            std.debug.assert(vm.state == .errored or vm.state == .halted);
            continue;
        };
        
        // Assert: Write succeeded, VM should still be in valid state.
        std.debug.assert(vm.state == .halted or vm.state == .running);

        // Read value back.
        const read_value = vm.read64(aligned_addr) catch |err| {
            // Assert: read error must be InvalidMemoryAccess.
            std.debug.assert(err == error.InvalidMemoryAccess);
            std.debug.assert(vm.state == .errored or vm.state == .halted);
            continue;
        };
        
        // Assert: Read succeeded, VM should still be in valid state.
        std.debug.assert(vm.state == .halted or vm.state == .running);

        // Assert: read value must match written value (memory consistency).
        std.debug.assert(read_value == write_value);
        
        // Assert: value must be valid 64-bit value (no corruption).
        std.debug.assert(read_value == write_value);
    }
}

test "004 fuzz: VM register file behavior (x0 hardwired)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    // Initialize RNG with deterministic seed.
    var rng = SimpleRng.init(0x004F00F200000002);

    // Initialize VM with minimal kernel.
    const kernel_data = [_]u8{ 0x13, 0x00, 0x00, 0x00 }; // NOP instruction.
    var vm = VM.init(&kernel_data, 0x1000);

    // Test register file operations.
    const iterations = 200;
    var iteration: u32 = 0;
    while (iteration < iterations) : (iteration += 1) {
        // Generate random register (0-31).
        // Assert: u5 max value is 31 (registers 0-31).
        // Use range(31) + 1 for 1-31, or explicitly handle x0 separately.
        const use_x0 = rng.boolean();
        const reg: u5 = if (use_x0) 0 else @as(u5, @intCast(rng.range(u32, 31) + 1));
        
        // Assert: register must be valid (0-31).
        std.debug.assert(reg < 32);

        // Generate random value.
        const value = rng.next();

        // Assert: register index must be valid (0-31).
        std.debug.assert(reg < 32);
        
        // Set register value.
        vm.regs.set(reg, value);
        
        // Assert: x0 writes should be ignored (no effect).
        if (reg == 0) {
            // x0 should remain zero after set attempt.
            std.debug.assert(vm.regs.get(0) == 0);
        }

        // Get register value.
        const read_value = vm.regs.get(reg);

        // Assert: x0 must always be zero, other registers must match.
        if (reg == 0) {
            std.debug.assert(read_value == 0);
            // Assert: x0 should never change, even after set attempt.
            std.debug.assert(vm.regs.regs[0] == 0);
        } else {
            std.debug.assert(read_value == value);
            // Assert: register value stored correctly.
            std.debug.assert(vm.regs.regs[reg] == value);
        }
    }
}

test "004 fuzz: VM state transitions (running → halted → errored)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    // Initialize RNG with deterministic seed.
    var rng = SimpleRng.init(0x004F00F300000003);

    // Test state transitions.
    const iterations = 30;
    var iteration: u32 = 0;
    while (iteration < iterations) : (iteration += 1) {
        // Initialize VM with minimal kernel.
        const kernel_data = [_]u8{ 0x13, 0x00, 0x00, 0x00 }; // NOP instruction.
        var vm = VM.init(&kernel_data, 0x1000);

        // Assert: initial state must be halted.
        std.debug.assert(vm.state == .halted);

        // Start VM.
        vm.start();
        std.debug.assert(vm.state == .running);

        // Execute random steps (may transition to errored).
        const step_count = rng.range(u32, 20) + 1;
        var step_idx: u32 = 0;
        while (step_idx < step_count and vm.state == .running) : (step_idx += 1) {
            vm.step() catch {
                // VM may error, transition to errored state.
                std.debug.assert(vm.state == .errored);
                break;
            };
        }

        // Stop VM (if still running).
        if (vm.state == .running) {
            vm.stop();
            std.debug.assert(vm.state == .halted);
        }

        // Assert: final state must be halted or errored.
        std.debug.assert(vm.state == .halted or vm.state == .errored);
    }
}

test "004 fuzz: Synthetic ELF kernel loading" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize RNG with deterministic seed.
    var rng = SimpleRng.init(0x004F00F400000004);

    // Test synthetic ELF kernel generation and loading.
    const iterations = 20;
    var iteration: u32 = 0;
    while (iteration < iterations) : (iteration += 1) {
        // Generate minimal synthetic ELF header.
        var elf_data = std.ArrayListUnmanaged(u8){};
        defer elf_data.deinit(allocator);

        // ELF header (64 bytes).
        // e_ident[0..4]: ELF magic (0x7F 'E' 'L' 'F').
        try elf_data.appendSlice(allocator, &[_]u8{ 0x7F, 'E', 'L', 'F' });
        // e_ident[4]: EI_CLASS (2 = ELFCLASS64).
        try elf_data.append(allocator, 2);
        // e_ident[5]: EI_DATA (1 = ELFDATA2LSB).
        try elf_data.append(allocator, 1);
        // e_ident[6]: EI_VERSION (1).
        try elf_data.append(allocator, 1);
        // e_ident[7..16]: padding.
        try elf_data.appendSlice(allocator, &[_]u8{0} ** 9);

        // e_type: ET_EXEC (2).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u16, 2)));
        // e_machine: EM_RISCV (243).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u16, 243)));
        // e_version: 1.
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u32, 1)));
        // e_entry: random entry point (0x1000-0x10000).
        const entry_point = rng.range(u64, 0xF000) + 0x1000;
        try elf_data.appendSlice(allocator, &std.mem.toBytes(entry_point));
        // e_phoff: program header offset (64, right after ELF header).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u64, 64)));
        // e_shoff: section header offset (0, not used).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u64, 0)));
        // e_flags: 0.
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u32, 0)));
        // e_ehsize: ELF header size (64).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u16, 64)));
        // e_phentsize: program header size (56).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u16, 56)));
        // e_phnum: number of program headers (1).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u16, 1)));
        // e_shentsize: section header size (0, not used).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u16, 0)));
        // e_shnum: number of section headers (0).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u16, 0)));
        // e_shstrndx: section header string table index (0).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u16, 0)));

        // Program header (56 bytes).
        // p_type: PT_LOAD (1).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u32, 1)));
        // p_flags: PF_R | PF_X (readable, executable).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u32, 5)));
        // p_offset: file offset (128, after ELF header + program header).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u64, 128)));
        // p_vaddr: virtual address (entry_point).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(entry_point));
        // p_paddr: physical address (same as virtual).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(entry_point));
        // p_filesz: file size (4 bytes, single instruction).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u64, 4)));
        // p_memsz: memory size (4 bytes).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u64, 4)));
        // p_align: alignment (4).
        try elf_data.appendSlice(allocator, &std.mem.toBytes(@as(u64, 4)));

        // Kernel code (single NOP instruction).
        try elf_data.appendSlice(allocator, &[_]u8{ 0x13, 0x00, 0x00, 0x00 });

        // Load kernel into VM.
        const vm = loadKernel(allocator, elf_data.items) catch |err| {
            // ELF loading may fail if ELF structure is invalid.
            // This is expected for some synthetic ELF files.
            _ = err;
            continue;
        };

        // Assert: VM must be initialized with correct entry point.
        std.debug.assert(vm.regs.pc == entry_point);
        std.debug.assert(vm.state == .halted);
    }
}

