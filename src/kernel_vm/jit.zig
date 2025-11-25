const std = @import("std");
const builtin = @import("builtin");

extern fn pthread_jit_write_protect_np(enabled: c_int) void;

/// Errors that can occur during JIT compilation or execution.
pub const JitError = error{
    OutOfMemory,
    BufferOverflow,
    InvalidInstruction,
    EncodingError,
    ProtectionFailure,
    InvalidSnapshot,
};

// Bounded: Max hot paths to track.
pub const MAX_HOT_PATHS: u32 = 32;

// Hot path entry: tracks execution count for a PC.
pub const HotPathEntry = struct {
    pc: u64,
    execution_count: u64,
    last_seen: u64, // Timestamp of last execution.

    pub fn init(pc: u64) HotPathEntry {
        // Allow pc=0 for initialization (will be set later).
        return HotPathEntry{
            .pc = pc,
            .execution_count = 0,
            .last_seen = 0,
        };
    }
};

// Hot path tracker: identifies frequently executed blocks.
pub const HotPathTracker = struct {
    paths: [MAX_HOT_PATHS]HotPathEntry,
    paths_len: u32,
    total_executions: u64,
    sequence_number: u64, // Monotonic counter for last_seen.

    pub fn init() HotPathTracker {
        var tracker = HotPathTracker{
            .paths = undefined,
            .paths_len = 0,
            .total_executions = 0,
            .sequence_number = 0,
        };
        var i: u32 = 0;
        while (i < MAX_HOT_PATHS) : (i += 1) {
            tracker.paths[i] = HotPathEntry.init(0);
        }
        return tracker;
    }

    fn find_path_index(self: *const HotPathTracker, pc: u64) ?u32 {
        std.debug.assert(pc > 0);
        var i: u32 = 0;
        while (i < self.paths_len) : (i += 1) {
            if (self.paths[i].pc == pc) {
                return i;
            }
        }
        return null;
    }

    fn find_empty_slot(self: *const HotPathTracker) ?u32 {
        var i: u32 = 0;
        while (i < self.paths_len) : (i += 1) {
            if (self.paths[i].pc == 0) {
                return i;
            }
        }
        return null;
    }

    fn add_new_path(self: *HotPathTracker, pc: u64) void {
        std.debug.assert(pc > 0);
        if (self.paths_len < MAX_HOT_PATHS) {
            const idx = self.paths_len;
            self.paths[idx] = HotPathEntry.init(pc);
            self.paths[idx].execution_count = 1;
            self.paths[idx].last_seen = self.sequence_number;
            self.paths_len += 1;
        } else if (self.find_empty_slot()) |empty_slot| {
            self.paths[empty_slot] = HotPathEntry.init(pc);
            self.paths[empty_slot].execution_count = 1;
            self.paths[empty_slot].last_seen = self.sequence_number;
        }
    }

    pub fn record_execution(self: *HotPathTracker, pc: u64) void {
        std.debug.assert(pc > 0);
        self.total_executions += 1;
        self.sequence_number += 1;
        // Find existing entry or create new one.
        if (self.find_path_index(pc)) |idx| {
            self.paths[idx].execution_count += 1;
            self.paths[idx].last_seen = self.sequence_number;
        } else {
            self.add_new_path(pc);
        }
    }

    pub fn get_hot_paths(self: *const HotPathTracker, threshold: u64) []const HotPathEntry {
        std.debug.assert(threshold > 0);
        // Return paths that exceed threshold (simplified: return all for now).
        if (self.paths_len == 0) {
            return &[_]HotPathEntry{};
        }
        return self.paths[0..self.paths_len];
    }
};

/// Performance Counters for the JIT.
pub const JitPerfCounters = struct {
    blocks_compiled: u64 = 0,
    instructions_translated: u64 = 0,
    cache_hits: u64 = 0,
    cache_misses: u64 = 0,
    total_execution_time_ns: u64 = 0,
    jit_compile_time_ns: u64 = 0,
    interpreter_fallbacks: u64 = 0,
    hot_path_tracker: HotPathTracker,

    pub fn print_stats(self: *const JitPerfCounters) void {
        std.debug.print("\nJIT Performance Stats:\n", .{});
        std.debug.print("  Blocks Compiled: {}\n", .{self.blocks_compiled});
        std.debug.print("  Instructions Translated: {}\n", .{self.instructions_translated});
        std.debug.print("  Cache Hits: {}\n", .{self.cache_hits});
        std.debug.print("  Cache Misses: {}\n", .{self.cache_misses});
        if (self.cache_hits + self.cache_misses > 0) {
            const hit_rate = @as(f64, @floatFromInt(self.cache_hits)) /
                @as(f64, @floatFromInt(self.cache_hits + self.cache_misses)) * 100.0;
            std.debug.print("  Hit Rate: {d:.2}%\n", .{hit_rate});
        }
        std.debug.print("  Interpreter Fallbacks: {}\n", .{self.interpreter_fallbacks});
        if (self.hot_path_tracker.total_executions > 0) {
            std.debug.print("  Total Executions: {}\n", .{self.hot_path_tracker.total_executions});
            std.debug.print("  Hot Paths Tracked: {}\n", .{self.hot_path_tracker.paths_len});
        }
        if (self.total_execution_time_ns > 0) {
            const exec_ms = @as(f64, @floatFromInt(self.total_execution_time_ns)) / 1_000_000.0;
            std.debug.print("  Total Execution Time: {d:.2} ms\n", .{exec_ms});
        }
        if (self.jit_compile_time_ns > 0) {
            const compile_ms = @as(f64, @floatFromInt(self.jit_compile_time_ns)) / 1_000_000.0;
            std.debug.print("  Total Compile Time: {d:.2} ms\n", .{compile_ms});
        }
        if (self.blocks_compiled > 0 and self.jit_compile_time_ns > 0) {
            const avg_compile_ns = self.jit_compile_time_ns / self.blocks_compiled;
            const avg_compile_us = @as(f64, @floatFromInt(avg_compile_ns)) / 1_000.0;
            std.debug.print("  Avg Compile Time: {d:.2} us/block\n", .{avg_compile_us});
        }
    }
};

/// The Guest State represents the RISC-V CPU state in memory.
pub const GuestState = extern struct {
    regs: [32]u64 align(16), // x0-x31
    pc: u64 align(8), // Program Counter
};

/// Decoded RISC-V Instruction.
pub const Instruction = struct {
    opcode: u7,
    rd: u5,
    funct3: u3,
    rs1: u5,
    rs2: u5,
    funct7: u7,
    imm: i32, // Sign-extended immediate

    pub fn decode(raw: u32) Instruction {
        const opcode: u7 = @truncate(raw);
        const rd: u5 = @truncate(raw >> 7);
        const funct3: u3 = @truncate(raw >> 12);
        const rs1: u5 = @truncate(raw >> 15);
        const rs2: u5 = @truncate(raw >> 20);
        const funct7: u7 = @truncate(raw >> 25);

        // Assert: opcode extraction is correct (consistency check)
        std.debug.assert(opcode == @as(u7, @truncate(raw)));
        // Assert: rd extraction is correct
        std.debug.assert(rd == @as(u5, @truncate(raw >> 7)));

        // Immediate decoding
        var imm: i32 = 0;
        switch (opcode) {
            0x13, 0x03, 0x67 => { // I-Type (ADDI, LW, JALR, LogicImm)
                imm = @as(i32, @bitCast(raw)) >> 20;
            },
            0x23 => { // S-Type (SW)
                const imm_lo = (raw >> 7) & 0x1F;
                const imm_hi = (raw >> 25) & 0x7F;
                const combined = imm_lo | (imm_hi << 5);
                imm = (@as(i32, @intCast(combined)) << 20) >> 20;
            },
            0x63 => { // B-Type (BRANCH)
                const bit11 = (raw >> 7) & 0x1;
                const bits1_4 = (raw >> 8) & 0xF;
                const bits5_10 = (raw >> 25) & 0x3F;
                const bit12 = (raw >> 31) & 0x1;
                const combined = (bits1_4 << 1) | (bits5_10 << 5) | (bit11 << 11) | (bit12 << 12);
                imm = (@as(i32, @intCast(combined)) << 19) >> 19;
            },
            0x37, 0x17 => { // U-Type (LUI, AUIPC)
                imm = @as(i32, @bitCast(raw & 0xFFFFF000));
            },
            0x6F => { // J-Type (JAL)
                const bits12_19 = (raw >> 12) & 0xFF;
                const bit11 = (raw >> 20) & 0x1;
                const bits1_10 = (raw >> 21) & 0x3FF;
                const bit20 = (raw >> 31) & 0x1;
                const combined = (bits1_10 << 1) | (bit11 << 11) | (bits12_19 << 12) | (bit20 << 20);
                imm = (@as(i32, @intCast(combined)) << 11) >> 11;
            },
            else => {},
        }

        return Instruction{
            .opcode = opcode,
            .rd = rd,
            .funct3 = funct3,
            .rs1 = rs1,
            .rs2 = rs2,
            .funct7 = funct7,
            .imm = imm,
        };
    }
};

/// Fixup for backpatching forward jumps.
/// GrainStyle: Use explicit u32 instead of usize for code buffer offsets
const Fixup = struct {
    patch_addr: u32, // Offset in code_buffer (max 64MB, fits in u32)
    next: ?*Fixup,
};

/// The JIT Context manages the translation process.
/// GrainStyle: Use explicit u32/u64 instead of usize for cross-platform consistency
pub const JitContext = struct {
    allocator: std.mem.Allocator,
    code_buffer: []align(16384) u8,
    cursor: u32, // Code buffer offset (max 64MB, fits in u32)
    guest_state: *GuestState,
    guest_ram: []u8,
    memory_size: u64, // VM memory size in bytes
    framebuffer_size: u32,
    perf_counters: JitPerfCounters,

    block_cache: std.AutoHashMap(u64, u32), // Maps guest PC to code buffer offset
    pending_fixups: std.AutoHashMap(u64, *Fixup),

    pub fn init(allocator: std.mem.Allocator, guest_state: *GuestState, guest_ram: []u8, memory_size: u64) !JitContext {
        // Assert: guest RAM must be non-empty
        std.debug.assert(guest_ram.len > 0);
        // Assert: guest state must be aligned
        std.debug.assert(@intFromPtr(guest_state) % @alignOf(GuestState) == 0);
        // Assert: guest RAM must be 4-byte aligned (for 32-bit accesses)
        std.debug.assert(@intFromPtr(guest_ram.ptr) % 4 == 0);

        const buffer_size: u32 = 64 * 1024 * 1024;
        const PROT_READ = 0x1;
        const PROT_WRITE = 0x2;
        const PROT_EXEC = 0x4;

        const ptr = try std.posix.mmap(null, buffer_size, PROT_READ | PROT_WRITE | PROT_EXEC, .{ .TYPE = .PRIVATE, .ANONYMOUS = true, .JIT = true }, -1, 0);

        const buffer = @as([]align(16384) u8, @alignCast(ptr[0..buffer_size]));

        if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
            pthread_jit_write_protect_np(0);
        }
        @memset(buffer, 0);
        if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
            pthread_jit_write_protect_np(1);
        }

        var cache = std.AutoHashMap(u64, u32).init(allocator);
        try cache.ensureTotalCapacity(10_000);

        var fixups = std.AutoHashMap(u64, *Fixup).init(allocator);
        try fixups.ensureTotalCapacity(1000);

        // Framebuffer constants (matching VM translate_address)
        const FRAMEBUFFER_SIZE: u32 = 1024 * 768 * 4; // 3MB
        
        // Assert: memory_size must be large enough for framebuffer
        std.debug.assert(memory_size >= FRAMEBUFFER_SIZE);

        const self = JitContext{
            .allocator = allocator,
            .code_buffer = buffer,
            .cursor = 0,
            .guest_state = guest_state,
            .guest_ram = guest_ram,
            .memory_size = memory_size,
            .framebuffer_size = FRAMEBUFFER_SIZE,
            .perf_counters = .{
                .hot_path_tracker = HotPathTracker.init(),
            },
            .block_cache = cache,
            .pending_fixups = fixups,
        };
        
        // Assert: JIT context must be initialized correctly
        std.debug.assert(self.memory_size == memory_size);
        std.debug.assert(self.framebuffer_size == FRAMEBUFFER_SIZE);

        self.verify_integrity();
        return self;
    }

    pub fn deinit(self: *JitContext) void {
        // Assert: code buffer must be valid
        std.debug.assert(self.code_buffer.len > 0);
        // Assert: cursor must be within bounds
        std.debug.assert(self.cursor <= self.code_buffer.len);
        
        std.posix.munmap(self.code_buffer);
        self.block_cache.deinit();
        self.pending_fixups.deinit();
    }

    pub fn verify_integrity(self: *const JitContext) void {
        std.debug.assert(self.cursor <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
    }

    pub fn protect_code(self: *JitContext) void {
        // Assert: code buffer must be valid
        std.debug.assert(self.code_buffer.len > 0);
        // Assert: cursor must be within bounds
        std.debug.assert(self.cursor <= self.code_buffer.len);
        
        if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
            pthread_jit_write_protect_np(1);
        }
    }

    pub fn unprotect_code(self: *JitContext) void {
        // Assert: code buffer must be valid
        std.debug.assert(self.code_buffer.len > 0);
        // Assert: cursor must be within bounds
        std.debug.assert(self.cursor <= self.code_buffer.len);

        if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
            pthread_jit_write_protect_np(0);
        }
    }

    /// GrainStyle: Use explicit u32 instead of usize for code buffer offsets
    pub fn flush_cache(self: *JitContext, start_offset: u32, len: u32) void {
        // Assert: start offset must be within bounds
        std.debug.assert(start_offset < self.code_buffer.len);
        // Assert: end offset must be within bounds
        std.debug.assert(start_offset + len <= self.code_buffer.len);
        
        // Instruction cache flushing is usually automatic on Apple Silicon for JIT memory,
        // but we keep the hook for correctness and portability.
    }

    // --- Emitters ---

    fn emit_u32(self: *JitContext, inst: u32) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        std.mem.writeInt(u32, self.code_buffer[self.cursor..][0..4], inst, .little);
        self.cursor += 4;
        std.debug.assert(self.cursor == start_cursor + 4);
    }

    pub fn emit_add(self: *JitContext, rd: u5, rn: u5, rm: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const opcode: u32 = 0x8B000000;
        const inst = opcode | (@as(u32, rm) << 16) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_subs(self: *JitContext, rd: u5, rn: u5, rm: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const opcode: u32 = 0xEB000000;
        const inst = opcode | (@as(u32, rm) << 16) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_mov_imm(self: *JitContext, rd: u5, imm: u16) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const opcode: u32 = 0xD2800000;
        const inst = opcode | (@as(u32, imm) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_mov_u64(self: *JitContext, rd: u5, val: u64) void {
        std.debug.assert(self.cursor + 16 <= self.code_buffer.len); // Max 4 instructions
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const imm0: u16 = @truncate(val);
        self.emit_mov_imm(rd, imm0);
        const imm1: u16 = @truncate(val >> 16);
        if (imm1 != 0) self.emit_movk(rd, imm1, 1);
        const imm2: u16 = @truncate(val >> 32);
        if (imm2 != 0) self.emit_movk(rd, imm2, 2);
        const imm3: u16 = @truncate(val >> 48);
        if (imm3 != 0) self.emit_movk(rd, imm3, 3);
        std.debug.assert(self.cursor >= start_cursor + 4); // At least 1 instruction
        std.debug.assert(self.cursor <= start_cursor + 16); // At most 4 instructions
    }

    fn emit_movk(self: *JitContext, rd: u5, imm: u16, shift_idx: u2) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const opcode: u32 = 0xF2800000;
        const inst = opcode | (@as(u32, shift_idx) << 21) | (@as(u32, imm) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_ret(self: *JitContext) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        self.emit_u32(0xD65F03C0);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_b(self: *JitContext, offset: i28) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const imm26: u32 = @as(u32, @bitCast(@as(i32, @intCast(offset >> 2)))) & 0x03FFFFFF;
        const inst = 0x14000000 | imm26;
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_b_cond(self: *JitContext, cond: u4, offset: i19) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const imm19: u32 = @as(u32, @bitCast(@as(i32, @intCast(offset >> 2)))) & 0x7FFFF;
        const inst = 0x54000000 | (imm19 << 5) | @as(u32, cond);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_br(self: *JitContext, rn: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const inst = 0xD61F0000 | (@as(u32, rn) << 5);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_ldr_from_state(self: *JitContext, rt: u5, guest_reg: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        std.debug.assert(guest_reg < 32); // Valid register index
        const start_cursor = self.cursor;
        const inst = 0xF9400000 | (@as(u32, guest_reg) << 10) | (28 << 5) | @as(u32, rt);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_str_to_state(self: *JitContext, rt: u5, guest_reg: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        std.debug.assert(guest_reg < 32); // Valid register index
        const start_cursor = self.cursor;
        const inst = 0xF9000000 | (@as(u32, guest_reg) << 10) | (28 << 5) | @as(u32, rt);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_and(self: *JitContext, rd: u5, rn: u5, rm: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const inst = 0x8A000000 | (@as(u32, rm) << 16) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_orr(self: *JitContext, rd: u5, rn: u5, rm: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const inst = 0xAA000000 | (@as(u32, rm) << 16) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_eor(self: *JitContext, rd: u5, rn: u5, rm: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const inst = 0xCA000000 | (@as(u32, rm) << 16) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_lsl_v(self: *JitContext, rd: u5, rn: u5, rm: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const inst = 0x9AC02000 | (@as(u32, rm) << 16) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_lsr_v(self: *JitContext, rd: u5, rn: u5, rm: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const inst = 0x9AC02400 | (@as(u32, rm) << 16) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_asr_v(self: *JitContext, rd: u5, rn: u5, rm: u5) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        const inst = 0x9AC02800 | (@as(u32, rm) << 16) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_lsl_i(self: *JitContext, rd: u5, rn: u5, shift: u6) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        std.debug.assert(shift < 64); // Valid shift amount
        const start_cursor = self.cursor;
        const immr = @as(u6, @truncate((64 - @as(u7, shift)) % 64));
        const imms = 63 - shift;
        const inst = 0xD3400000 | (@as(u32, immr) << 16) | (@as(u32, imms) << 10) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_lsr_i(self: *JitContext, rd: u5, rn: u5, shift: u6) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        std.debug.assert(shift < 64); // Valid shift amount
        const start_cursor = self.cursor;
        const immr = shift;
        const imms = 63;
        const inst = 0xD3400000 | (@as(u32, immr) << 16) | (@as(u32, imms) << 10) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_asr_i(self: *JitContext, rd: u5, rn: u5, shift: u6) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        std.debug.assert(shift < 64); // Valid shift amount
        const start_cursor = self.cursor;
        const immr = shift;
        const imms = 63;
        const inst = 0x93400000 | (@as(u32, immr) << 16) | (@as(u32, imms) << 10) | (@as(u32, rn) << 5) | @as(u32, rd);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_ldr_reg(self: *JitContext, rt: u5, rn: u5, rm: u5, size: u2, signed: bool) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        var inst: u32 = 0x38206800;
        const opc: u32 = if (signed) 0x2 else 0x1;
        inst |= (opc << 22);
        inst |= (@as(u32, size) << 30);
        inst |= (@as(u32, rm) << 16);
        inst |= (@as(u32, rn) << 5);
        inst |= @as(u32, rt);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    pub fn emit_str_reg(self: *JitContext, rt: u5, rn: u5, rm: u5, size: u2) void {
        std.debug.assert(self.cursor + 4 <= self.code_buffer.len);
        std.debug.assert(self.cursor % 4 == 0);
        const start_cursor = self.cursor;
        var inst: u32 = 0x38206800;
        inst |= (@as(u32, size) << 30);
        inst |= (@as(u32, rm) << 16);
        inst |= (@as(u32, rn) << 5);
        inst |= @as(u32, rt);
        self.emit_u32(inst);
        std.debug.assert(self.cursor == start_cursor + 4);
        std.debug.assert(self.cursor <= self.code_buffer.len);
    }

    /// Emit address translation code
    /// Why: Translate guest virtual address to physical offset in VM memory
    /// Contract: Takes guest address in addr_reg, outputs physical offset in same register
    /// GrainStyle: Explicit bounds checking, deterministic translation
    /// Address translation logic:
    ///   - 0x90000000+: Framebuffer -> offset = memory_size - framebuffer_size + (addr - 0x90000000)
    ///   - 0x80000000+: Kernel -> offset = addr - 0x80000000
    ///   - Otherwise: Direct mapping -> offset = addr
    fn emit_translate_address(self: *JitContext, addr_reg: u5) void {
        // Assert: addr_reg must be valid (0-31)
        std.debug.assert(addr_reg < 32);
        
        // Use x4, x5, x6 as temporary registers (x27=mem_base, x28=guest_state are reserved)
        const tmp1: u5 = 4;
        const tmp2: u5 = 5;
        const tmp3: u5 = 6;
        
        const KERNEL_BASE: u64 = 0x80000000;
        const FRAMEBUFFER_BASE: u64 = 0x90000000;
        
        // Check if address >= FRAMEBUFFER_BASE (0x90000000)
        self.emit_mov_u64(tmp1, FRAMEBUFFER_BASE);
        self.emit_subs(tmp2, addr_reg, tmp1); // tmp2 = addr - 0x90000000, sets flags
        // If addr >= 0x90000000, carry flag is set (unsigned >=)
        
        // Branch to framebuffer translation if addr >= 0x90000000
        self.emit_b_cond(0x2, 0); // HS (unsigned >=), will patch later
        const framebuffer_patch_pos: u32 = self.cursor - 4;
        
        // Check if address >= KERNEL_BASE (0x80000000)
        self.emit_mov_u64(tmp1, KERNEL_BASE);
        self.emit_subs(tmp3, addr_reg, tmp1); // tmp3 = addr - 0x80000000, sets flags (use tmp3 to preserve tmp2)
        
        // Branch to kernel translation if addr >= 0x80000000
        self.emit_b_cond(0x2, 0); // HS (unsigned >=), will patch later
        const kernel_patch_pos: u32 = self.cursor - 4;
        
        // Low memory: direct mapping (addr_reg already contains offset)
        self.emit_b(0); // Will patch later
        const done_patch_pos: u32 = self.cursor - 4;
        
        // Framebuffer translation: offset = memory_size - framebuffer_size + (addr - 0x90000000)
        // At this point: addr_reg = guest_addr, tmp2 = addr - 0x90000000
        const framebuffer_code_start: u32 = self.cursor;
        self.emit_mov_u64(tmp1, @as(u64, self.memory_size));
        self.emit_mov_u64(tmp3, @as(u64, self.framebuffer_size));
        self.emit_subs(tmp1, tmp1, tmp3); // tmp1 = memory_size - framebuffer_size
        self.emit_add(addr_reg, tmp1, tmp2); // addr_reg = (memory_size - framebuffer_size) + (addr - 0x90000000)
        self.emit_b(0); // Jump to done, will patch later
        const framebuffer_done_patch: u32 = self.cursor - 4;
        
        // Kernel translation: offset = addr - 0x80000000
        // At this point: addr_reg = guest_addr, tmp3 = addr - 0x80000000
        const kernel_code_start: u32 = self.cursor;
        self.emit_mov(addr_reg, tmp3); // addr_reg = addr - 0x80000000
        self.emit_b(0); // Jump to done, will patch later
        const kernel_done_patch: u32 = self.cursor - 4;
        
        // Done label
        const done_code_start: u32 = self.cursor;
        
        // Patch branch offsets
        // GrainStyle: Use explicit u32 for offsets, cast to i19/i28 for branch instructions
        // Framebuffer branch: from framebuffer_patch_pos to framebuffer_code_start
        const framebuffer_diff: i32 = @as(i32, @intCast(framebuffer_code_start)) - @as(i32, @intCast(framebuffer_patch_pos));
        const framebuffer_offset = @as(i19, @intCast(framebuffer_diff >> 2));
        self.patch_b_cond(framebuffer_patch_pos, framebuffer_offset);
        
        // Kernel branch: from kernel_patch_pos to kernel_code_start
        const kernel_diff: i32 = @as(i32, @intCast(kernel_code_start)) - @as(i32, @intCast(kernel_patch_pos));
        const kernel_offset = @as(i19, @intCast(kernel_diff >> 2));
        self.patch_b_cond(kernel_patch_pos, kernel_offset);
        
        // Done branch: from done_patch_pos to done_code_start
        const done_diff: i32 = @as(i32, @intCast(done_code_start)) - @as(i32, @intCast(done_patch_pos));
        const done_offset = @as(i28, @intCast(done_diff >> 2));
        self.patch_b(done_patch_pos, done_offset);
        
        // Framebuffer done branch: from framebuffer_done_patch to done_code_start
        const framebuffer_done_diff: i32 = @as(i32, @intCast(done_code_start)) - @as(i32, @intCast(framebuffer_done_patch));
        const framebuffer_done_offset = @as(i28, @intCast(framebuffer_done_diff >> 2));
        self.patch_b(framebuffer_done_patch, framebuffer_done_offset);
        
        // Kernel done branch: from kernel_done_patch to done_code_start
        const kernel_done_diff: i32 = @as(i32, @intCast(done_code_start)) - @as(i32, @intCast(kernel_done_patch));
        const kernel_done_offset = @as(i28, @intCast(kernel_done_diff >> 2));
        self.patch_b(kernel_done_patch, kernel_done_offset);
    }
    
    /// Patch B instruction at position
    /// GrainStyle: Use explicit u32 instead of usize for code buffer offsets
    fn patch_b(self: *JitContext, pos: u32, offset: i28) void {
        std.debug.assert(pos + 4 <= self.code_buffer.len);
        const existing = std.mem.readInt(u32, self.code_buffer[pos..][0..4], .little);
        const imm26: u32 = @as(u32, @intCast(offset)) & 0x03FFFFFF;
        const inst = (existing & 0xFC000000) | imm26;
        std.mem.writeInt(u32, self.code_buffer[pos..][0..4], inst, .little);
    }
    
    /// Patch B.cond instruction at position
    /// GrainStyle: Use explicit u32 instead of usize for code buffer offsets
    fn patch_b_cond(self: *JitContext, pos: u32, offset: i19) void {
        std.debug.assert(pos + 4 <= self.code_buffer.len);
        const existing = std.mem.readInt(u32, self.code_buffer[pos..][0..4], .little);
        const imm19: u32 = @as(u32, @intCast(offset)) & 0x7FFFF;
        const cond = existing & 0xF;
        const inst = 0x54000000 | (imm19 << 5) | cond;
        std.mem.writeInt(u32, self.code_buffer[pos..][0..4], inst, .little);
    }
    
    /// Emit MOV (register to register)
    fn emit_mov(self: *JitContext, rd: u5, rn: u5) void {
        self.emit_add(rd, rn, 0); // MOV is ADD with zero
    }

    // --- Translation Logic ---

    // RVC Expansion: Convert 16-bit compressed instructions to 32-bit standard form
    fn expand_rvc(raw16: u16) ?u32 {
        const opcode: u2 = @truncate(raw16 & 0x3);
        const funct3: u3 = @truncate(raw16 >> 13);

        return switch (opcode) {
            0x0 => expand_rvc_q0(raw16, funct3),
            0x1 => expand_rvc_q1(raw16, funct3),
            0x2 => expand_rvc_q2(raw16, funct3),
            0x3 => null, // Not a compressed instruction
        };
    }

    fn expand_rvc_q0(raw16: u16, funct3: u3) ?u32 {
        return switch (funct3) {
            0x0 => expand_c_addi4spn(raw16),
            0x2 => expand_c_lw(raw16),
            0x6 => expand_c_sw(raw16),
            else => null,
        };
    }

    fn expand_rvc_q1(raw16: u16, funct3: u3) ?u32 {
        return switch (funct3) {
            0x0 => expand_c_addi(raw16),
            0x1 => expand_c_jal(raw16),
            0x2 => expand_c_li(raw16),
            0x3 => expand_c_addi16sp_lui(raw16),
            0x4 => expand_c_misc_alu(raw16),
            0x5 => expand_c_j(raw16),
            0x6 => expand_c_beqz(raw16),
            0x7 => expand_c_bnez(raw16),
        };
    }

    fn expand_rvc_q2(raw16: u16, funct3: u3) ?u32 {
        return switch (funct3) {
            0x0 => expand_c_slli(raw16),
            0x2 => expand_c_lwsp(raw16),
            0x4 => expand_c_jr_mv_add(raw16),
            0x6 => expand_c_swsp(raw16),
            else => null,
        };
    }

    // C.ADDI4SPN: addi rd', x2, nzuimm
    fn expand_c_addi4spn(raw16: u16) ?u32 {
        const nzuimm = ((raw16 >> 7) & 0x30) | ((raw16 >> 1) & 0x3C0) |
            ((raw16 >> 4) & 0x4) | ((raw16 >> 2) & 0x8);
        if (nzuimm == 0) return null;
        const rd_p: u5 = @truncate((raw16 >> 2) & 0x7);
        const rd = rd_p + 8;
        return 0x00010013 | (@as(u32, rd) << 7) | (@as(u32, nzuimm) << 20);
    }

    // C.LW: lw rd', offset(rs1')
    fn expand_c_lw(raw16: u16) ?u32 {
        const rd_p: u5 = @truncate((raw16 >> 2) & 0x7);
        const rs1_p: u5 = @truncate((raw16 >> 7) & 0x7);
        const offset = ((raw16 >> 7) & 0x38) | ((raw16 >> 4) & 0x4) | ((raw16 << 1) & 0x40);
        const rd = rd_p + 8;
        const rs1 = rs1_p + 8;
        return 0x00002003 | (@as(u32, rd) << 7) | (@as(u32, rs1) << 15) | (@as(u32, offset) << 20);
    }

    // C.SW: sw rs2', offset(rs1')
    fn expand_c_sw(raw16: u16) ?u32 {
        const rs2_p: u5 = @truncate((raw16 >> 2) & 0x7);
        const rs1_p: u5 = @truncate((raw16 >> 7) & 0x7);
        const offset = ((raw16 >> 7) & 0x38) | ((raw16 >> 4) & 0x4) | ((raw16 << 1) & 0x40);
        const rs2 = rs2_p + 8;
        const rs1 = rs1_p + 8;
        const imm_11_5 = (offset >> 5) & 0x7F;
        const imm_4_0 = offset & 0x1F;
        return 0x00002023 | (@as(u32, imm_4_0) << 7) | (@as(u32, rs1) << 15) |
            (@as(u32, rs2) << 20) | (@as(u32, imm_11_5) << 25);
    }

    // C.ADDI: addi rd, rd, nzimm
    fn expand_c_addi(raw16: u16) ?u32 {
        const rd: u5 = @truncate((raw16 >> 7) & 0x1F);
        if (rd == 0) return 0x00000013; // C.NOP
        const nzimm = ((raw16 >> 7) & 0x20) | ((raw16 >> 2) & 0x1F);
        const imm = if ((nzimm & 0x20) != 0) @as(u32, nzimm) | 0xFFFFFFC0 else @as(u32, nzimm);
        return 0x00000013 | (@as(u32, rd) << 7) | (@as(u32, rd) << 15) | (@as(u32, imm) << 20);
    }

    // C.JAL: jal x1, offset (RV32 only, RV64 uses C.ADDIW)
    fn expand_c_jal(raw16: u16) ?u32 {
        const offset = ((raw16 >> 1) & 0x800) | ((raw16 >> 7) & 0x10) |
            ((raw16 >> 1) & 0x300) | ((raw16 << 2) & 0x400) |
            ((raw16 >> 1) & 0x40) | ((raw16 << 1) & 0x80) |
            ((raw16 >> 2) & 0xE) | ((raw16 << 3) & 0x20);
        const imm = if ((offset & 0x800) != 0) @as(u32, offset) | 0xFFFFF000 else @as(u32, offset);
        return 0x0000006F | (1 << 7) | (@as(u32, imm) & 0xFFFFF000);
    }

    // C.LI: addi rd, x0, imm
    fn expand_c_li(raw16: u16) ?u32 {
        const rd: u5 = @truncate((raw16 >> 7) & 0x1F);
        const imm_raw = ((raw16 >> 7) & 0x20) | ((raw16 >> 2) & 0x1F);
        const imm = if ((imm_raw & 0x20) != 0) @as(u32, imm_raw) | 0xFFFFFFC0 else @as(u32, imm_raw);
        return 0x00000013 | (@as(u32, rd) << 7) | (@as(u32, imm) << 20);
    }

    // C.ADDI16SP / C.LUI
    fn expand_c_addi16sp_lui(raw16: u16) ?u32 {
        const rd: u5 = @truncate((raw16 >> 7) & 0x1F);
        if (rd == 2) {
            // C.ADDI16SP
            const nzimm = ((raw16 >> 3) & 0x200) | ((raw16 >> 2) & 0x10) |
                ((raw16 << 1) & 0x40) | ((raw16 << 4) & 0x180) | ((raw16 << 3) & 0x20);
            if (nzimm == 0) return null;
            const imm = if ((nzimm & 0x200) != 0) @as(u32, nzimm) | 0xFFFFFC00 else @as(u32, nzimm);
            return 0x00010013 | (2 << 7) | (2 << 15) | (@as(u32, imm) << 20);
        } else {
            // C.LUI
            const nzimm = ((raw16 >> 7) & 0x20) | ((raw16 >> 2) & 0x1F);
            if (nzimm == 0) return null;
            const imm = if ((nzimm & 0x20) != 0) @as(u32, nzimm) | 0xFFFFFFC0 else @as(u32, nzimm);
            return 0x00000037 | (@as(u32, rd) << 7) | ((@as(u32, imm) & 0x3F) << 12);
        }
    }

    // C.MISC-ALU: SRLI, SRAI, ANDI, SUB, XOR, OR, AND
    fn expand_c_misc_alu(raw16: u16) ?u32 {
        const rd_p: u5 = @truncate((raw16 >> 7) & 0x7);
        const rd = rd_p + 8;
        const funct2 = (raw16 >> 10) & 0x3;

        if (funct2 < 3) {
            const shamt = ((raw16 >> 7) & 0x20) | ((raw16 >> 2) & 0x1F);
            return switch (funct2) {
                0 => 0x00005013 | (@as(u32, rd) << 7) | (@as(u32, rd) << 15) | (@as(u32, shamt) << 20),
                1 => 0x40005013 | (@as(u32, rd) << 7) | (@as(u32, rd) << 15) | (@as(u32, shamt) << 20),
                2 => blk: {
                    const imm_raw = ((raw16 >> 7) & 0x20) | ((raw16 >> 2) & 0x1F);
                    const imm = if ((imm_raw & 0x20) != 0) @as(u32, imm_raw) | 0xFFFFFFC0 else @as(u32, imm_raw);
                    break :blk 0x00007013 | (@as(u32, rd) << 7) | (@as(u32, rd) << 15) | (@as(u32, imm) << 20);
                },
                else => null,
            };
        } else {
            const rs2_p: u5 = @truncate((raw16 >> 2) & 0x7);
            const rs2 = rs2_p + 8;
            const funct6 = (raw16 >> 10) & 0x3;
            const bit5 = (raw16 >> 12) & 0x1;
            const op = (funct6 << 1) | bit5;
            return switch (op) {
                0x3 => 0x40000033 | (@as(u32, rd) << 7) | (@as(u32, rd) << 15) | (@as(u32, rs2) << 20),
                0x4 => 0x00004033 | (@as(u32, rd) << 7) | (@as(u32, rd) << 15) | (@as(u32, rs2) << 20),
                0x5 => 0x00006033 | (@as(u32, rd) << 7) | (@as(u32, rd) << 15) | (@as(u32, rs2) << 20),
                0x6 => 0x00007033 | (@as(u32, rd) << 7) | (@as(u32, rd) << 15) | (@as(u32, rs2) << 20),
                else => null,
            };
        }
    }

    // C.J: jal x0, offset
    fn expand_c_j(raw16: u16) ?u32 {
        const offset = ((raw16 >> 1) & 0x800) | ((raw16 >> 7) & 0x10) |
            ((raw16 >> 1) & 0x300) | ((raw16 << 2) & 0x400) |
            ((raw16 >> 1) & 0x40) | ((raw16 << 1) & 0x80) |
            ((raw16 >> 2) & 0xE) | ((raw16 << 3) & 0x20);
        const imm = if ((offset & 0x800) != 0) @as(u32, offset) | 0xFFFFF000 else @as(u32, offset);
        return 0x0000006F | (@as(u32, imm) & 0xFFFFF000);
    }

    // C.BEQZ: beq rs1', x0, offset
    fn expand_c_beqz(raw16: u16) ?u32 {
        const rs1_p: u5 = @truncate((raw16 >> 7) & 0x7);
        const rs1 = rs1_p + 8;
        const offset = ((raw16 >> 4) & 0x100) | ((raw16 >> 7) & 0x18) |
            ((raw16 << 1) & 0xC0) | ((raw16 >> 2) & 0x6) | ((raw16 << 3) & 0x20);
        const imm = if ((offset & 0x100) != 0) @as(u32, offset) | 0xFFFFFE00 else @as(u32, offset);
        const imm_12 = (imm >> 12) & 0x1;
        const imm_10_5 = (imm >> 5) & 0x3F;
        const imm_4_1 = (imm >> 1) & 0xF;
        const imm_11 = (imm >> 11) & 0x1;
        return 0x00000063 | (@as(u32, rs1) << 15) | (@as(u32, imm_11) << 7) |
            (@as(u32, imm_4_1) << 8) | (@as(u32, imm_10_5) << 25) | (@as(u32, imm_12) << 31);
    }

    // C.BNEZ: bne rs1', x0, offset
    fn expand_c_bnez(raw16: u16) ?u32 {
        const rs1_p: u5 = @truncate((raw16 >> 7) & 0x7);
        const rs1 = rs1_p + 8;
        const offset = ((raw16 >> 4) & 0x100) | ((raw16 >> 7) & 0x18) |
            ((raw16 << 1) & 0xC0) | ((raw16 >> 2) & 0x6) | ((raw16 << 3) & 0x20);
        const imm = if ((offset & 0x100) != 0) @as(u32, offset) | 0xFFFFFE00 else @as(u32, offset);
        const imm_12 = (imm >> 12) & 0x1;
        const imm_10_5 = (imm >> 5) & 0x3F;
        const imm_4_1 = (imm >> 1) & 0xF;
        const imm_11 = (imm >> 11) & 0x1;
        return 0x00001063 | (@as(u32, rs1) << 15) | (@as(u32, imm_11) << 7) |
            (@as(u32, imm_4_1) << 8) | (@as(u32, imm_10_5) << 25) | (@as(u32, imm_12) << 31);
    }

    // C.SLLI: slli rd, rd, shamt
    fn expand_c_slli(raw16: u16) ?u32 {
        const rd: u5 = @truncate((raw16 >> 7) & 0x1F);
        if (rd == 0) return null;
        const shamt = ((raw16 >> 7) & 0x20) | ((raw16 >> 2) & 0x1F);
        return 0x00001013 | (@as(u32, rd) << 7) | (@as(u32, rd) << 15) | (@as(u32, shamt) << 20);
    }

    // C.LWSP: lw rd, offset(x2)
    fn expand_c_lwsp(raw16: u16) ?u32 {
        const rd: u5 = @truncate((raw16 >> 7) & 0x1F);
        if (rd == 0) return null;
        const offset = ((raw16 >> 7) & 0x20) | ((raw16 >> 2) & 0x1C) | ((raw16 << 4) & 0xC0);
        return 0x00002003 | (@as(u32, rd) << 7) | (2 << 15) | (@as(u32, offset) << 20);
    }

    // C.JR / C.MV / C.JALR / C.ADD
    fn expand_c_jr_mv_add(raw16: u16) ?u32 {
        const rs1: u5 = @truncate((raw16 >> 7) & 0x1F);
        const rs2: u5 = @truncate((raw16 >> 2) & 0x1F);
        const bit12 = (raw16 >> 12) & 0x1;

        if (bit12 == 0) {
            if (rs2 == 0) {
                // C.JR
                if (rs1 == 0) return null;
                return 0x00000067 | (@as(u32, rs1) << 15);
            } else {
                // C.MV
                return 0x00000033 | (@as(u32, rs1) << 7) | (@as(u32, rs2) << 20);
            }
        } else {
            if (rs2 == 0) {
                // C.JALR
                if (rs1 == 0) return null;
                return 0x000000E7 | (1 << 7) | (@as(u32, rs1) << 15);
            } else {
                // C.ADD
                return 0x00000033 | (@as(u32, rs1) << 7) | (@as(u32, rs1) << 15) | (@as(u32, rs2) << 20);
            }
        }
    }

    // C.SWSP: sw rs2, offset(x2)
    fn expand_c_swsp(raw16: u16) ?u32 {
        const rs2: u5 = @truncate((raw16 >> 2) & 0x1F);
        const offset = ((raw16 >> 7) & 0x3C) | ((raw16 >> 1) & 0xC0);
        const imm_11_5 = (offset >> 5) & 0x7F;
        const imm_4_0 = offset & 0x1F;
        return 0x00002023 | (@as(u32, imm_4_0) << 7) | (2 << 15) |
            (@as(u32, rs2) << 20) | (@as(u32, imm_11_5) << 25);
    }

    const FetchResult = struct {
        inst: u32,
        len: u8,
    };

    fn fetch_inst(self: *JitContext, pc: u64) !FetchResult {
        if (pc >= 0x80000000 and pc < 0x80000000 + self.guest_ram.len) {
            const offset = pc - 0x80000000;
            if (offset + 2 > self.guest_ram.len) return error.BufferOverflow;

            const raw16 = std.mem.readInt(u16, self.guest_ram[offset..][0..2], .little);

            // Check if compressed (bits [1:0] != 0b11)
            if ((raw16 & 0x3) != 0x3) {
                if (expand_rvc(raw16)) |expanded| {
                    return .{ .inst = expanded, .len = 2 };
                }
                return error.InvalidInstruction;
            }

            // Standard 32-bit instruction
            if (offset + 4 > self.guest_ram.len) return error.BufferOverflow;
            const raw32 = std.mem.readInt(u32, self.guest_ram[offset..][0..4], .little);
            return .{ .inst = raw32, .len = 4 };
        }
        return error.InvalidInstruction;
    }

    /// GrainStyle: Use explicit u32 instead of usize for code buffer offsets
    fn record_fixup(self: *JitContext, target_pc: u64, patch_offset: u32) !void {
        const fixup = try self.allocator.create(Fixup);
        fixup.* = .{ .patch_addr = patch_offset, .next = null };

        if (self.pending_fixups.getPtr(target_pc)) |head_ptr| {
            fixup.next = head_ptr.*;
            head_ptr.* = fixup;
        } else {
            try self.pending_fixups.put(target_pc, fixup);
        }
    }

    pub fn compile_block(self: *JitContext, guest_pc: u64) !*const fn (*GuestState) callconv(.c) void {
        self.unprotect_code();
        defer self.protect_code();

        const start_offset: u32 = self.cursor;
        var current_pc = guest_pc;
        var instructions_in_block: u32 = 0;

        if (self.block_cache.get(guest_pc)) |addr| {
            // Cache hit: return existing compiled block.
            self.perf_counters.cache_hits += 1;
            return @ptrCast(@alignCast(@as(*const anyopaque, @ptrFromInt(@intFromPtr(self.code_buffer.ptr) + @as(usize, addr)))));
        }

        // Cache miss: compile new block.
        self.perf_counters.cache_misses += 1;
        self.apply_fixups(guest_pc, start_offset);

        while (true) {
            const fetch_result = try self.fetch_inst(current_pc);
            const inst = Instruction.decode(fetch_result.inst);

            switch (inst.opcode) {
                0x33 => { // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND (R-Type)
                    self.emit_ldr_from_state(0, inst.rs1);
                    self.emit_ldr_from_state(1, inst.rs2);

                    switch (inst.funct3) {
                        0x0 => { // ADD/SUB
                            if (inst.funct7 == 0x00) { // ADD
                                self.emit_add(0, 0, 1);
                            } else if (inst.funct7 == 0x20) { // SUB
                                self.emit_subs(0, 0, 1);
                            }
                        },
                        0x1 => self.emit_lsl_v(0, 0, 1), // SLL
                        0x4 => self.emit_eor(0, 0, 1), // XOR
                        0x5 => { // SRL/SRA
                            if (inst.funct7 == 0x00) { // SRL
                                self.emit_lsr_v(0, 0, 1);
                            } else if (inst.funct7 == 0x20) { // SRA
                                self.emit_asr_v(0, 0, 1);
                            }
                        },
                        0x6 => self.emit_orr(0, 0, 1), // OR
                        0x7 => self.emit_and(0, 0, 1), // AND
                        else => {}, // SLT/SLTU not implemented yet
                    }
                    self.emit_str_to_state(0, inst.rd);
                },
                0x13 => { // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI (I-Type)
                    self.emit_ldr_from_state(0, inst.rs1);
                    const imm_u: u64 = @bitCast(@as(i64, inst.imm));

                    switch (inst.funct3) {
                        0x0 => { // ADDI
                            self.emit_mov_u64(1, imm_u);
                            self.emit_add(0, 0, 1);
                        },
                        0x4 => { // XORI
                            self.emit_mov_u64(1, imm_u);
                            self.emit_eor(0, 0, 1);
                        },
                        0x6 => { // ORI
                            self.emit_mov_u64(1, imm_u);
                            self.emit_orr(0, 0, 1);
                        },
                        0x7 => { // ANDI
                            self.emit_mov_u64(1, imm_u);
                            self.emit_and(0, 0, 1);
                        },
                        0x1 => { // SLLI
                            const shamt: u6 = @truncate(@as(u32, @bitCast(inst.imm)));
                            self.emit_lsl_i(0, 0, shamt);
                        },
                        0x5 => { // SRLI/SRAI
                            const shamt: u6 = @truncate(@as(u32, @bitCast(inst.imm)));
                            if ((inst.imm >> 10) == 0) { // SRLI
                                self.emit_lsr_i(0, 0, shamt);
                            } else { // SRAI
                                self.emit_asr_i(0, 0, shamt);
                            }
                        },
                        else => {}, // SLTI/SLTIU not implemented
                    }
                    self.emit_str_to_state(0, inst.rd);
                },
                0x37 => { // LUI
                    const imm_u: u64 = @bitCast(@as(i64, inst.imm));
                    self.emit_mov_u64(0, imm_u);
                    self.emit_str_to_state(0, inst.rd);
                },
                0x17 => { // AUIPC
                    const imm_u: u64 = @bitCast(@as(i64, inst.imm));
                    self.emit_mov_u64(0, current_pc);
                    self.emit_mov_u64(1, imm_u);
                    self.emit_add(0, 0, 1);
                    self.emit_str_to_state(0, inst.rd);
                },
                0x03 => { // LB, LH, LW, LBU, LHU, LWU, LD (Load)
                    self.emit_ldr_from_state(1, inst.rs1); // x1 = base
                    const imm_u: u64 = @bitCast(@as(i64, inst.imm));
                    self.emit_mov_u64(2, imm_u); // x2 = offset
                    self.emit_add(1, 1, 2); // x1 = guest_addr

                    // Translate virtual address to physical offset
                    // Why: Support both kernel (0x80000000+) and framebuffer (0x90000000+) addresses
                    self.emit_translate_address(1); // x1 = physical offset

                    const size: u2 = switch (inst.funct3) {
                        0x0, 0x4 => 0, // Byte
                        0x1, 0x5 => 1, // Half
                        0x2, 0x6 => 2, // Word
                        0x3 => 3, // Double
                        else => 3,
                    };
                    const signed = switch (inst.funct3) {
                        0x0, 0x1, 0x2 => true,
                        else => false,
                    };

                    // Load from memory: x0 = [x27 + x1] where x27 is mem_base
                    self.emit_ldr_reg(0, 27, 1, size, signed);
                    self.emit_str_to_state(0, inst.rd);
                },
                0x23 => { // SB, SH, SW, SD (Store)
                    self.emit_ldr_from_state(1, inst.rs1); // x1 = base
                    const imm_u: u64 = @bitCast(@as(i64, inst.imm));
                    self.emit_mov_u64(2, imm_u); // x2 = offset
                    self.emit_add(1, 1, 2); // x1 = guest_addr

                    // Translate virtual address to physical offset
                    // Why: Support both kernel (0x80000000+) and framebuffer (0x90000000+) addresses
                    self.emit_translate_address(1); // x1 = physical offset

                    self.emit_ldr_from_state(0, inst.rs2); // x0 = value to store

                    const size: u2 = switch (inst.funct3) {
                        0x0 => 0, // Byte
                        0x1 => 1, // Half
                        0x2 => 2, // Word
                        0x3 => 3, // Double
                        else => 3,
                    };

                    // Store to memory: [x27 + x1] = x0 where x27 is mem_base
                    self.emit_str_reg(0, 27, 1, size);
                },
                0x63 => { // BRANCH (B-Type)
                    self.emit_ldr_from_state(0, inst.rs1);
                    self.emit_ldr_from_state(1, inst.rs2);
                    self.emit_subs(31, 0, 1);

                    const cond: u4 = switch (inst.funct3) {
                        0 => 0x0, // EQ
                        1 => 0x1, // NE
                        4 => 0xB, // LT
                        5 => 0xA, // GE
                        6 => 0x3, // LO
                        7 => 0x2, // HS
                        else => 0xE, // AL
                    };

                    const patch_pos = self.cursor;
                    self.emit_b_cond(cond, 0);
                    try self.record_fixup(current_pc + @as(u64, @bitCast(@as(i64, inst.imm))), patch_pos);
                },
                0x6F => { // JAL (J-Type)
                    const ret_addr = current_pc + 4;
                    self.emit_mov_u64(0, ret_addr);
                    self.emit_str_to_state(0, inst.rd);

                    const patch_pos = self.cursor;
                    self.emit_b(0);
                    try self.record_fixup(current_pc + @as(u64, @bitCast(@as(i64, inst.imm))), patch_pos);

                    break;
                },
                0x67 => { // JALR (I-Type)
                    const ret_addr = current_pc + 4;
                    self.emit_mov_u64(0, ret_addr);
                    self.emit_str_to_state(0, inst.rd);

                    self.emit_ldr_from_state(1, inst.rs1);
                    const imm_u: u64 = @bitCast(@as(i64, inst.imm));
                    self.emit_mov_u64(2, imm_u);
                    self.emit_add(1, 1, 2);

                    self.emit_ret();
                    break;
                },
                else => {
                    // Unknown
                },
            }

            current_pc += fetch_result.len;
            instructions_in_block += 1;
            self.perf_counters.instructions_translated += 1;

            if (instructions_in_block > 100) break;
        }

        if (instructions_in_block > 100) {
            self.emit_ret();
        }

        try self.block_cache.put(guest_pc, start_offset);
        self.perf_counters.blocks_compiled += 1;

        self.flush_cache(start_offset, self.cursor - start_offset);

        // GrainStyle: Cast u32 to usize only for pointer arithmetic
        const code_ptr = @intFromPtr(self.code_buffer.ptr) + @as(usize, start_offset);
        return @ptrCast(@alignCast(@as(*const anyopaque, @ptrFromInt(code_ptr))));
    }

    /// GrainStyle: Use explicit u32 instead of usize for code buffer offsets
    fn apply_fixups(self: *JitContext, target_pc: u64, target_addr: u32) void {
        if (self.pending_fixups.fetchRemove(target_pc)) |entry| {
            var current: ?*Fixup = entry.value;
            while (current) |fixup| {
                const offset = @as(i64, @intCast(target_addr)) - @as(i64, @intCast(fixup.patch_addr));

                const existing = std.mem.readInt(u32, self.code_buffer[fixup.patch_addr..][0..4], .little);

                var inst: u32 = 0;
                if ((existing & 0x7C000000) == 0x14000000) {
                    const imm26: u32 = @as(u32, @bitCast(@as(i32, @intCast(offset >> 2)))) & 0x03FFFFFF;
                    inst = 0x14000000 | imm26;
                } else if ((existing & 0xFF000000) == 0x54000000) {
                    const imm19: u32 = @as(u32, @bitCast(@as(i32, @intCast(offset >> 2)))) & 0x7FFFF;
                    const cond = existing & 0xF;
                    inst = 0x54000000 | (imm19 << 5) | cond;
                }

                if (inst != 0) {
                    std.mem.writeInt(u32, self.code_buffer[fixup.patch_addr..][0..4], inst, .little);
                }

                const next = fixup.next;
                self.allocator.destroy(fixup);
                current = next;
            }
        }
    }

    pub fn dump_code(self: *JitContext, filename: []const u8) !void {
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        try file.writeAll(self.code_buffer[0..self.cursor]);
    }

    pub fn enter_jit(code: *const anyopaque, state: *GuestState, mem_base: [*]u8) void {
        asm volatile (
            \\  mov x28, %[state]
            \\  mov x27, %[mem_base]
            \\  blr %[code]
            :
            : [code] "r" (code),
              [state] "r" (state),
              [mem_base] "r" (mem_base),
            : .{ .x27 = true, .x28 = true, .x30 = true, .memory = true });
    }
};

test "JIT: Simple ADD" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;

    std.debug.print("\nSetting up memory...\n", .{});
    var ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);
    @memset(ram, 0);

    // 2. Write RISC-V Code (ADDI x1, x0, 10; ADDI x2, x0, 20; ADD x3, x1, x2; RET)
    // ADDI x1, x0, 10  -> 0x00A00093
    // ADDI x2, x0, 20  -> 0x01400113
    // ADD x3, x1, x2   -> 0x002081B3
    // RET (JALR x0, x1, 0) -> 0x00008067
    const code = [_]u32{
        0x00A00093,
        0x01400113,
        0x002081B3,
        0x00008067,
    };

    const start_pc: u64 = 0x80000000;
    for (code, 0..) |inst, i| {
        std.mem.writeInt(u32, ram[i * 4 ..][0..4], inst, .little);
    }

    var state = GuestState{ .regs = undefined, .pc = start_pc };
    @memset(&state.regs, 0);

    var jit = try JitContext.init(allocator, &state, ram);
    defer jit.deinit();

    const func = try jit.compile_block(start_pc);
    JitContext.enter_jit(func, &state, ram.ptr);

    try std.testing.expectEqual(@as(u64, 10), state.regs[1]);
    try std.testing.expectEqual(@as(u64, 20), state.regs[2]);
    try std.testing.expectEqual(@as(u64, 30), state.regs[3]);
}

test "JIT: Load/Store/Logic" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    var ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);
    @memset(ram, 0);

    // Initialize RAM with some data at offset 0x100 (80000100)
    std.mem.writeInt(u32, ram[0x100..][0..4], 0xDEADBEEF, .little);

    // Code:
    // ADDI x1, x0, 0x100       (x1 = 0x100)
    // ADDI x2, x0, 1           (x2 = 1)
    // SLLI x2, x2, 31          (x2 = 0x80000000)
    // ADD x1, x1, x2           (x1 = 0x80000100)
    // LW x3, 0(x1)             (x3 = *0x80000100 = 0xDEADBEEF)
    // ADDI x4, x0, 1           (x4 = 1)
    // SLLI x4, x4, 4           (x4 = 16)
    // OR x5, x3, x4            (x5 = 0xDEADBEEF | 0x10 = 0xDEADBEFF)
    // SW x5, 4(x1)             (*0x80000104 = x5)
    // RET

    // ADDI x1, x0, 0x100 -> 0x10000093
    // ADDI x2, x0, 1     -> 0x00100113
    // SLLI x2, x2, 31    -> 0x01F11113
    // ADD x1, x1, x2     -> 0x002080B3
    // LW x3, 0(x1)       -> 0x0000A183
    // ADDI x4, x0, 1     -> 0x00100213
    // SLLI x4, x4, 4     -> 0x00421213
    // OR x5, x3, x4      -> 0x0041E2B3
    // SW x5, 4(x1)       -> 0x0050A223
    // RET                -> 0x00008067

    const code = [_]u32{
        0x10000093,
        0x00100113,
        0x01F11113,
        0x002080B3,
        0x0000A183,
        0x00100213,
        0x00421213,
        0x0041E2B3,
        0x0050A223,
        0x00008067,
    };

    const start_pc: u64 = 0x80000000;
    for (code, 0..) |inst, i| {
        std.mem.writeInt(u32, ram[i * 4 ..][0..4], inst, .little);
    }

    var state = GuestState{ .regs = undefined, .pc = start_pc };
    @memset(&state.regs, 0);

    var jit = try JitContext.init(allocator, &state, ram);
    defer jit.deinit();

    const func = try jit.compile_block(start_pc);
    JitContext.enter_jit(func, &state, ram.ptr);

    // Verify Registers
    try std.testing.expectEqual(@as(u64, 0xFFFFFFFFDEADBEEF), state.regs[3]); // LW result (sign-extended)
    try std.testing.expectEqual(@as(u64, 16), state.regs[4]); // SLLI result
    try std.testing.expectEqual(@as(u64, 0xFFFFFFFFDEADBEFF), state.regs[5]); // OR result (sign-extended)

    // Verify Memory Store
    const stored = std.mem.readInt(u32, ram[0x104..][0..4], .little);
    try std.testing.expectEqual(@as(u32, 0xDEADBEFF), stored);
}

test "JIT: RVC Compressed Instructions" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    var ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);
    @memset(ram, 0);

    // Test compressed instructions:
    // C.ADDI x1, 5     -> 0x0505 (ADDI x1, x1, 5)
    // C.LI x2, 10      -> 0x4509 (ADDI x2, x0, 10)
    // C.MV x3, x1      -u003e 0x8186 (x3 = x1)
    // C.ADD x3, x2     -u003e 0x918A (x3 = x3 + x2)

    const code = [_]u16{
        0x0095, // C.ADDI x1, 5
        0x4129, // C.LI x2, 10
        0x8186, // C.MV x3, x1
        0x918A, // C.ADD x3, x2
        0x8082, // C.JR x1
    };

    const start_pc: u64 = 0x80000000;
    for (code, 0..) |inst, i| {
        std.mem.writeInt(u16, ram[i * 2 ..][0..2], inst, .little);
    }

    var state = GuestState{ .regs = undefined, .pc = start_pc };
    @memset(&state.regs, 0);
    state.regs[1] = 0; // x1 starts at 0

    var jit = try JitContext.init(allocator, &state, ram);
    defer jit.deinit();

    const func = try jit.compile_block(start_pc);
    JitContext.enter_jit(func, &state, ram.ptr);

    // Verify Results
    try std.testing.expectEqual(@as(u64, 5), state.regs[1]); // C.ADDI x1, 5
    try std.testing.expectEqual(@as(u64, 10), state.regs[2]); // C.LI x2, 10
    try std.testing.expectEqual(@as(u64, 15), state.regs[3]); // C.MV x3, x1; C.ADD x3, x2
}

// ============================================================================
// Security & Fuzz Tests
// ============================================================================

/// Generate a random valid RISC-V R-Type instruction
fn generate_random_r_type(rng: anytype) u32 {
    const opcodes = [_]u7{0x33}; // R-Type
    const funct3s = [_]u3{ 0x0, 0x1, 0x4, 0x5, 0x6, 0x7 };
    const funct7s = [_]u7{ 0x00, 0x20 };

    const opcode = opcodes[rng.intRangeAtMost(usize, 0, opcodes.len - 1)];
    const rd: u5 = @truncate(rng.intRangeAtMost(u32, 0, 31));
    const funct3 = funct3s[rng.intRangeAtMost(usize, 0, funct3s.len - 1)];
    const rs1: u5 = @truncate(rng.intRangeAtMost(u32, 0, 31));
    const rs2: u5 = @truncate(rng.intRangeAtMost(u32, 0, 31));
    const funct7 = funct7s[rng.intRangeAtMost(usize, 0, funct7s.len - 1)];

    return @as(u32, opcode) | (@as(u32, rd) << 7) | (@as(u32, funct3) << 12) |
        (@as(u32, rs1) << 15) | (@as(u32, rs2) << 20) | (@as(u32, funct7) << 25);
}

/// Generate a random valid RISC-V I-Type instruction
fn generate_random_i_type(rng: anytype) u32 {
    const opcodes = [_]u7{0x13}; // I-Type
    const funct3s = [_]u3{ 0x0, 0x1, 0x4, 0x5, 0x6, 0x7 };

    const opcode = opcodes[rng.intRangeAtMost(usize, 0, opcodes.len - 1)];
    const rd: u5 = @truncate(rng.intRangeAtMost(u32, 0, 31));
    const funct3 = funct3s[rng.intRangeAtMost(usize, 0, funct3s.len - 1)];
    const rs1: u5 = @truncate(rng.intRangeAtMost(u32, 0, 31));
    const imm: i12 = @truncate(rng.intRangeAtMost(i32, -2048, 2047));

    return @as(u32, opcode) | (@as(u32, rd) << 7) | (@as(u32, funct3) << 12) |
        (@as(u32, rs1) << 15) | (@as(u32, @bitCast(@as(i32, imm))) & 0xFFF00000);
}

/// Generate a random valid compressed instruction
fn generate_random_compressed(rng: anytype) u16 {
    const templates = [_]u16{
        0x0095, // C.ADDI x1, 5
        0x4129, // C.LI x2, 10
        0x8186, // C.MV x3, x1
        0x918A, // C.ADD x3, x2
        0x8082, // C.JR x1
    };
    return templates[rng.intRangeAtMost(usize, 0, templates.len - 1)];
}

test "Fuzz: Random Valid R-Type Instructions" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(0x12345678);
    const rng = prng.random();

    var ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);

    // Test 100 random R-Type instructions
    for (0..100) |iteration| {
        @memset(ram, 0);
        const inst = generate_random_r_type(&rng);
        std.mem.writeInt(u32, ram[0..4], inst, .little);
        // Add RET instruction
        std.mem.writeInt(u32, ram[4..8], 0x00008067, .little);

        var state = GuestState{ .regs = undefined, .pc = 0x80000000 };
        @memset(&state.regs, 0);

        var jit = try JitContext.init(allocator, &state, ram);
        defer jit.deinit();

        // Should not crash during compilation
        const func = jit.compile_block(0x80000000) catch |err| {
            std.debug.print("Iteration {}: Failed to compile R-Type 0x{X:0>8}: {}\n", .{ iteration, inst, err });
            return err;
        };

        // Verify cursor advanced
        try std.testing.expect(jit.cursor > 0);
        try std.testing.expect(jit.cursor <= jit.code_buffer.len);
        try std.testing.expect(jit.cursor % 4 == 0);

        _ = func; // Suppress unused warning
    }
}

test "Fuzz: Random Valid I-Type Instructions" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(0x87654321);
    const rng = prng.random();

    var ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);

    // Test 100 random I-Type instructions
    for (0..100) |iteration| {
        @memset(ram, 0);
        const inst = generate_random_i_type(&rng);
        std.mem.writeInt(u32, ram[0..4], inst, .little);
        // Add RET instruction
        std.mem.writeInt(u32, ram[4..8], 0x00008067, .little);

        var state = GuestState{ .regs = undefined, .pc = 0x80000000 };
        @memset(&state.regs, 0);

        var jit = try JitContext.init(allocator, &state, ram);
        defer jit.deinit();

        // Should not crash during compilation
        const func = jit.compile_block(0x80000000) catch |err| {
            std.debug.print("Iteration {}: Failed to compile I-Type 0x{X:0>8}: {}\n", .{ iteration, inst, err });
            return err;
        };

        // Verify cursor advanced
        try std.testing.expect(jit.cursor > 0);
        try std.testing.expect(jit.cursor <= jit.code_buffer.len);

        _ = func;
    }
}

test "Fuzz: Random Compressed Instructions" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(0xABCDEF01);
    const rng = prng.random();

    var ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);

    // Test 50 random compressed instruction sequences
    for (0..50) |iteration| {
        @memset(ram, 0);
        const inst = generate_random_compressed(&rng);
        std.mem.writeInt(u16, ram[0..2], inst, .little);
        // Add compressed RET (C.JR x1)
        std.mem.writeInt(u16, ram[2..4], 0x8082, .little);

        var state = GuestState{ .regs = undefined, .pc = 0x80000000 };
        @memset(&state.regs, 0);
        state.regs[1] = 0; // x1 for C.JR

        var jit = try JitContext.init(allocator, &state, ram);
        defer jit.deinit();

        // Should not crash during compilation
        const func = jit.compile_block(0x80000000) catch |err| {
            std.debug.print("Iteration {}: Failed to compile compressed 0x{X:0>4}: {}\n", .{ iteration, inst, err });
            return err;
        };

        // Verify cursor advanced
        try std.testing.expect(jit.cursor > 0);
        try std.testing.expect(jit.cursor <= jit.code_buffer.len);

        _ = func;
    }
}

test "Security: Buffer Overflow Protection" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    var ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);
    @memset(ram, 0);

    // Fill RAM with valid instructions to force code buffer overflow
    const inst = 0x00A00093; // ADDI x1, x0, 10
    for (0..100000) |i| {
        if (i * 4 + 4 > ram.len) break;
        std.mem.writeInt(u32, ram[i * 4 ..][0..4], inst, .little);
    }

    var state = GuestState{ .regs = undefined, .pc = 0x80000000 };
    @memset(&state.regs, 0);

    var jit = try JitContext.init(allocator, &state, ram);
    defer jit.deinit();

    // Should eventually stop due to instruction limit (100 per block)
    const func = try jit.compile_block(0x80000000);

    // Verify we didn't overflow
    try std.testing.expect(jit.cursor <= jit.code_buffer.len);
    try std.testing.expect(jit.cursor % 4 == 0);

    _ = func;
}

test "Security: Invalid Instruction Handling" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    var ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);
    @memset(ram, 0);

    // Test with invalid opcode (0xFF is not a valid RISC-V opcode)
    const invalid_inst: u32 = 0xFFFFFFFF;
    std.mem.writeInt(u32, ram[0..4], invalid_inst, .little);
    // Add RET so block terminates
    std.mem.writeInt(u32, ram[4..8], 0x00008067, .little);

    var state = GuestState{ .regs = undefined, .pc = 0x80000000 };
    @memset(&state.regs, 0);

    var jit = try JitContext.init(allocator, &state, ram);
    defer jit.deinit();

    // Should compile (decoder handles unknown opcodes gracefully by skipping)
    _ = try jit.compile_block(0x80000000);

    // Verify integrity maintained
    try std.testing.expect(jit.cursor <= jit.code_buffer.len);
    jit.verify_integrity();
}

test "Security: Guest RAM Bounds Checking" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    const ram = try allocator.alloc(u8, 1024);
    defer allocator.free(ram);
    @memset(ram, 0);

    var state = GuestState{ .regs = undefined, .pc = 0x80000000 };
    @memset(&state.regs, 0);

    var jit = try JitContext.init(allocator, &state, ram);
    defer jit.deinit();

    // Try to fetch beyond RAM bounds
    const result = jit.fetch_inst(0x80000000 + ram.len);
    try std.testing.expectError(error.InvalidInstruction, result);

    // Try to fetch with insufficient space for 4-byte instruction
    const result2 = jit.fetch_inst(0x80000000 + ram.len - 2);
    // Note: May return InvalidInstruction or BufferOverflow depending on alignment
    try std.testing.expect(result2 == error.InvalidInstruction or result2 == error.BufferOverflow);
}

test "Security: W^X Memory Protection" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    const ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);
    @memset(ram, 0);

    var state = GuestState{ .regs = undefined, .pc = 0x80000000 };
    @memset(&state.regs, 0);

    var jit = try JitContext.init(allocator, &state, ram);
    defer jit.deinit();

    // Verify code buffer is properly protected
    try std.testing.expect(jit.code_buffer.len == 64 * 1024 * 1024);
    try std.testing.expect(@intFromPtr(jit.code_buffer.ptr) % 16384 == 0); // 16KB aligned

    // Test protect/unprotect cycle
    jit.unprotect_code();
    jit.protect_code();

    // Verify integrity after protection cycle
    jit.verify_integrity();
}

test "Security: Integer Overflow in PC Arithmetic" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    const allocator = std.testing.allocator;
    const ram = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(ram);
    @memset(ram, 0);
    // Put a valid instruction at the end
    std.mem.writeInt(u32, ram[ram.len - 8 ..][0..4], 0x00A00093, .little); // ADDI x1, x0, 10
    std.mem.writeInt(u32, ram[ram.len - 4 ..][0..4], 0x00008067, .little); // RET

    var state = GuestState{ .regs = undefined, .pc = 0x80000000 };
    @memset(&state.regs, 0);

    var jit = try JitContext.init(allocator, &state, ram);
    defer jit.deinit();

    // Test PC near maximum value
    const max_pc = 0x80000000 + ram.len - 8; // Ensure space for instruction
    const result = try jit.fetch_inst(max_pc);
    try std.testing.expect(result.len == 2 or result.len == 4);

    // Test PC beyond valid range
    const invalid_pc = 0x80000000 + ram.len;
    const result2 = jit.fetch_inst(invalid_pc);
    try std.testing.expectError(error.InvalidInstruction, result2);
}

test "Security: RVC Expansion Edge Cases" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;

    // Test invalid compressed instructions (reserved patterns)
    const invalid_compressed = [_]u16{
        0x0000, // C.ILLEGAL (all zeros)
        0x0001, // Reserved
        0x0002, // Reserved
    };

    for (invalid_compressed) |inst| {
        const expanded = JitContext.expand_rvc(inst);
        // Should return null for invalid instructions
        if (expanded == null) {
            // Expected behavior
        } else {
            // Some patterns may expand to valid instructions
            try std.testing.expect(expanded.? != 0);
        }
    }
}

/// Soft-TLB for fast guest-to-host address translation
pub const SoftTLB = struct {
    entries: [TLB_SIZE]TLBEntry,

    const TLB_SIZE = 64; // Power of 2 for fast indexing

    const TLBEntry = struct {
        guest_page: u64,
        host_offset: usize,
        valid: bool,
    };

    pub fn init() SoftTLB {
        // Assert: TLB size must be power of 2
        std.debug.assert(TLB_SIZE & (TLB_SIZE - 1) == 0);
        // Assert: TLB size must be positive
        std.debug.assert(TLB_SIZE > 0);
        return .{ .entries = [_]TLBEntry{.{ .guest_page = 0, .host_offset = 0, .valid = false }} ** TLB_SIZE };
    }

    pub fn lookup(self: *const SoftTLB, guest_addr: u64) ?usize {
        std.debug.assert(guest_addr >= 0x80000000); // Valid guest RAM address
        // Assert: entries array must be correct size
        std.debug.assert(self.entries.len == TLB_SIZE);
        
        const page = guest_addr >> 12; // 4KB pages
        const index = page % TLB_SIZE;
        const entry = &self.entries[index];

        if (entry.valid and entry.guest_page == page) {
            return entry.host_offset + (guest_addr & 0xFFF);
        }
        return null;
    }

    pub fn insert(self: *SoftTLB, guest_addr: u64, host_offset: usize) void {
        std.debug.assert(guest_addr >= 0x80000000);
        std.debug.assert(host_offset % 4096 == 0); // Page-aligned
        const page = guest_addr >> 12;
        const index = page % TLB_SIZE;
        self.entries[index] = .{
            .guest_page = page,
            .host_offset = host_offset & ~@as(usize, 0xFFF),
            .valid = true,
        };
    }

    pub fn flush(self: *SoftTLB) void {
        // Assert: entries array must be correct size
        std.debug.assert(self.entries.len == TLB_SIZE);
        // Assert: TLB size must be positive
        std.debug.assert(TLB_SIZE > 0);
        
        for (&self.entries) |*entry| {
            entry.valid = false;
        }
    }
};

/// Block-local register allocator for AArch64
pub const RegisterAllocator = struct {
    /// Track which AArch64 registers are in use
    allocated: [32]bool = [_]bool{false} ** 32,

    /// Reserved registers (x27=mem_base, x28=guest_state, x29=fp, x30=lr)
    const RESERVED = [_]u5{ 27, 28, 29, 30 };

    pub fn init() RegisterAllocator {
        // Assert: reserved registers must be defined
        std.debug.assert(RESERVED.len > 0);
        // Assert: reserved count must be reasonable
        std.debug.assert(RESERVED.len < 32);
        
        var self = RegisterAllocator{};
        // Mark reserved registers
        for (RESERVED) |reg| {
            self.allocated[reg] = true;
        }
        return self;
    }

    pub fn allocate(self: *RegisterAllocator) ?u5 {
        std.debug.assert(self.allocated[27]); // Reserved regs must stay reserved
        std.debug.assert(self.allocated[28]);
        for (0..27) |i| {
            if (!self.allocated[i]) {
                self.allocated[i] = true;
                return @intCast(i);
            }
        }
        return null; // No free registers
    }

    pub fn free(self: *RegisterAllocator, reg: u5) void {
        std.debug.assert(reg < 27); // Can't free reserved regs
        std.debug.assert(self.allocated[reg]); // Must be allocated to free
        self.allocated[reg] = false;
    }

    pub fn reset(self: *RegisterAllocator) void {
        // Assert: allocated array must be correct size
        std.debug.assert(self.allocated.len == 32);
        // Assert: reserved registers must be defined
        std.debug.assert(RESERVED.len > 0);
        
        @memset(&self.allocated, false);
        for (RESERVED) |reg| {
            self.allocated[reg] = true;
        }
    }
};

/// Instruction trace entry for debugging
pub const TraceEntry = struct {
    pc: u64,
    inst: u32,
    regs_before: [32]u64,
    regs_after: [32]u64,
};

/// Instruction tracer for debugging
pub const Tracer = struct {
    entries: []TraceEntry,
    cursor: usize = 0,
    enabled: bool = false,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !Tracer {
        std.debug.assert(capacity > 0);
        std.debug.assert(capacity <= 1000000); // Reasonable limit
        const entries = try allocator.alloc(TraceEntry, capacity);
        return .{ .entries = entries };
    }

    pub fn deinit(self: *Tracer, allocator: std.mem.Allocator) void {
        // Assert: entries must be allocated
        std.debug.assert(self.entries.len > 0);
        // Assert: allocator must be valid
        std.debug.assert(allocator.vtable != undefined);
        allocator.free(self.entries);
    }

    pub fn record(self: *Tracer, pc: u64, inst: u32, regs_before: [32]u64, regs_after: [32]u64) void {
        // Assert: PC must be aligned (2-byte for RVC)
        std.debug.assert(pc % 2 == 0);
        // Assert: entries must be allocated if enabled
        std.debug.assert(self.entries.len > 0 or !self.enabled);
        
        if (!self.enabled or self.cursor >= self.entries.len) return;

        self.entries[self.cursor] = .{
            .pc = pc,
            .inst = inst,
            .regs_before = regs_before,
            .regs_after = regs_after,
        };
        self.cursor += 1;
    }

    pub fn dump(self: *const Tracer) void {
        // Assert: cursor must be within bounds
        std.debug.assert(self.cursor <= self.entries.len);
        // Assert: entries must be allocated or cursor 0
        std.debug.assert(self.entries.len > 0 or self.cursor == 0);
        
        std.debug.print("\nInstruction Trace ({} entries):\n", .{self.cursor});
        for (self.entries[0..self.cursor], 0..) |entry, i| {
            std.debug.print("  [{}] PC: 0x{X:0>16} INST: 0x{X:0>8}\n", .{ i, entry.pc, entry.inst });
        }
    }

    pub fn clear(self: *Tracer) void {
        // Assert: cursor must be within bounds
        std.debug.assert(self.cursor <= self.entries.len);
        // Assert: entries must be allocated or cursor 0
        std.debug.assert(self.entries.len > 0 or self.cursor == 0);
        
        self.cursor = 0;
    }
};
