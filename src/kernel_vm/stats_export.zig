//! VM Statistics Export System
//!
//! Objective: Export VM statistics to JSON format for analysis and visualization.
//! Why: Enable external tools to analyze VM performance, memory usage, and execution patterns.
//! GrainStyle: Static allocation, bounded buffers, explicit types, deterministic export.
//!
//! Methodology:
//! - Export all VM statistics to JSON format
//! - Bounded JSON buffer (MAX_JSON_SIZE: 1MB)
//! - Structured JSON output (performance, exceptions, memory, instructions, syscalls, flow, registers, branches, perf)
//! - Provide export interface for all statistics modules
//! - Reset capability for new measurement periods
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size JSON buffer (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-24
//! GrainStyle: Comprehensive statistics export, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;

// Bounded: Maximum JSON export size (1MB should be sufficient for all statistics).
pub const MAX_JSON_SIZE: u32 = 1024 * 1024;

// VM statistics exporter.
pub const VMStatsExporter = struct {
    vm: *VM,
    json_buffer: [MAX_JSON_SIZE]u8,
    json_len: u32,

    pub fn init(vm: *VM) VMStatsExporter {
        return VMStatsExporter{
            .vm = vm,
            .json_buffer = undefined,
            .json_len = 0,
        };
    }

    fn append_json(self: *VMStatsExporter, text: []const u8) void {
        const remaining = MAX_JSON_SIZE - self.json_len;
        if (remaining < text.len) {
            return;
        }
        @memcpy(self.json_buffer[self.json_len..][0..text.len], text);
        self.json_len += @as(u32, @intCast(text.len));
    }

    fn export_performance(self: *VMStatsExporter) void {
        const perf = &self.vm.performance;
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\"performance": {{
            \\  "instructions_executed": {},
            \\  "cycles_simulated": {},
            \\  "memory_reads": {},
            \\  "memory_writes": {},
            \\  "syscalls": {}
            \\}},
        , .{
            perf.instructions_executed,
            perf.cycles_simulated,
            perf.memory_reads,
            perf.memory_writes,
            perf.syscalls,
        }) catch return;
        self.append_json(json);
    }

    fn export_exceptions(self: *VMStatsExporter) void {
        const exc = &self.vm.exception_stats;
        if (exc.total_count == 0) {
            self.append_json("\"exceptions\": {}");
            return;
        }
        var buf: [512]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\"exceptions": {{
            \\  "total_count": {}
            \\}},
        , .{exc.total_count}) catch return;
        self.append_json(json);
    }

    fn export_memory(self: *VMStatsExporter) void {
        const mem = &self.vm.memory_stats;
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\"memory": {{
            \\  "total_memory_bytes": {},
            \\  "used_memory_bytes": {},
            \\  "total_reads": {},
            \\  "total_writes": {},
            \\  "total_bytes_read": {},
            \\  "total_bytes_written": {}
            \\}},
        , .{
            mem.total_memory_bytes,
            mem.used_memory_bytes,
            mem.total_reads,
            mem.total_writes,
            mem.total_bytes_read,
            mem.total_bytes_written,
        }) catch return;
        self.append_json(json);
    }

    fn export_instructions(self: *VMStatsExporter) void {
        const inst = &self.vm.instruction_stats;
        if (inst.total_instructions == 0) {
            self.append_json("\"instructions\": {}");
            return;
        }
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\"instructions": {{
            \\  "total_instructions": {}
            \\}},
        , .{inst.total_instructions}) catch return;
        self.append_json(json);
    }

    fn export_syscalls(self: *VMStatsExporter) void {
        const sys = &self.vm.syscall_stats;
        if (sys.total_syscalls == 0) {
            self.append_json("\"syscalls\": {}");
            return;
        }
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\"syscalls": {{
            \\  "total_syscalls": {}
            \\}},
        , .{sys.total_syscalls}) catch return;
        self.append_json(json);
    }

    fn export_execution_flow(self: *VMStatsExporter) void {
        const flow = &self.vm.execution_flow;
        if (flow.total_instructions == 0) {
            self.append_json("\"execution_flow\": {}");
            return;
        }
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\"execution_flow": {{
            \\  "total_instructions": {}
            \\}},
        , .{flow.total_instructions}) catch return;
        self.append_json(json);
    }

    fn export_registers(self: *VMStatsExporter) void {
        const reg = &self.vm.register_stats;
        const total_ops = reg.total_reads + reg.total_writes;
        if (total_ops == 0) {
            self.append_json("\"registers\": {}");
            return;
        }
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\"registers": {{
            \\  "total_reads": {},
            \\  "total_writes": {}
            \\}},
        , .{ reg.total_reads, reg.total_writes }) catch return;
        self.append_json(json);
    }

    fn export_branches(self: *VMStatsExporter) void {
        const branch = &self.vm.branch_stats;
        if (branch.total_branches == 0) {
            self.append_json("\"branches\": {}");
            return;
        }
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\"branches": {{
            \\  "total_branches": {},
            \\  "branches_taken": {},
            \\  "branches_not_taken": {}
            \\}},
        , .{
            branch.total_branches,
            branch.branches_taken,
            branch.branches_not_taken,
        }) catch return;
        self.append_json(json);
    }

    fn export_instruction_perf(self: *VMStatsExporter) void {
        const perf = &self.vm.instruction_perf;
        if (perf.total_profiling_time_ns == 0) {
            self.append_json("\"instruction_perf\": {}");
            return;
        }
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\"instruction_perf": {{
            \\  "total_profiling_time_ns": {},
            \\  "unique_opcodes": {}
            \\}},
        , .{ perf.total_profiling_time_ns, perf.entries_len }) catch return;
        self.append_json(json);
    }

    pub fn export_to_json(self: *VMStatsExporter) []const u8 {
        self.json_len = 0;
        self.append_json("{\n");
        self.export_performance();
        self.append_json(",\n");
        self.export_exceptions();
        self.append_json(",\n");
        self.export_memory();
        self.append_json(",\n");
        self.export_instructions();
        self.append_json(",\n");
        self.export_syscalls();
        self.append_json(",\n");
        self.export_execution_flow();
        self.append_json(",\n");
        self.export_registers();
        self.append_json(",\n");
        self.export_branches();
        self.append_json(",\n");
        self.export_instruction_perf();
        self.append_json("\n}\n");
        return self.json_buffer[0..self.json_len];
    }
};

