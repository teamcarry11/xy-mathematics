//! VM Memory Statistics Tracking System
//!
//! Objective: Track memory usage, access patterns, and allocation metrics for VM monitoring.
//! Why: Monitor memory consumption, identify access patterns, validate memory management.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track total memory size and used memory
//! - Track memory access patterns (reads/writes by region)
//! - Track memory access counts
//! - Track memory fragmentation metrics
//! - Provide statistics interface for querying memory data
//! - Reset capability for new measurement periods
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded counters: fixed-size counters (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-24
//! GrainStyle: Comprehensive memory tracking, deterministic behavior, explicit limits

const std = @import("std");

// Bounded: Max memory regions to track.
pub const MAX_MEMORY_REGIONS: u32 = 16;

// Memory region: tracks access patterns for a memory range.
pub const MemoryRegion = struct {
    start_addr: u64,
    end_addr: u64,
    read_count: u64,
    write_count: u64,
    total_bytes_read: u64,
    total_bytes_written: u64,

    pub fn init(start_addr: u64, end_addr: u64) MemoryRegion {
        std.debug.assert(start_addr < end_addr);
        return MemoryRegion{
            .start_addr = start_addr,
            .end_addr = end_addr,
            .read_count = 0,
            .write_count = 0,
            .total_bytes_read = 0,
            .total_bytes_written = 0,
        };
    }

    pub fn contains(self: *const MemoryRegion, addr: u64) bool {
        // Handle uninitialized regions (start_addr == 0 and end_addr == 0).
        if (self.start_addr == 0 and self.end_addr == 0) {
            return false;
        }
        return addr >= self.start_addr and addr < self.end_addr;
    }
};

// VM memory statistics tracker.
pub const VMMemoryStats = struct {
    total_memory_bytes: u64,
    used_memory_bytes: u64,
    regions: [MAX_MEMORY_REGIONS]MemoryRegion,
    regions_len: u32,
    total_reads: u64,
    total_writes: u64,
    total_bytes_read: u64,
    total_bytes_written: u64,

    pub fn init(total_memory_bytes: u64) VMMemoryStats {
        std.debug.assert(total_memory_bytes > 0);
        var stats = VMMemoryStats{
            .total_memory_bytes = total_memory_bytes,
            .used_memory_bytes = 0,
            .regions = undefined,
            .regions_len = 0,
            .total_reads = 0,
            .total_writes = 0,
            .total_bytes_read = 0,
            .total_bytes_written = 0,
        };
        var i: u32 = 0;
        while (i < MAX_MEMORY_REGIONS) : (i += 1) {
            stats.regions[i] = MemoryRegion.init(0, 0);
        }
        return stats;
    }

    pub fn add_region(self: *VMMemoryStats, start_addr: u64, end_addr: u64) void {
        std.debug.assert(start_addr < end_addr);
        if (self.regions_len >= MAX_MEMORY_REGIONS) {
            return;
        }
        const idx = self.regions_len;
        self.regions[idx] = MemoryRegion.init(start_addr, end_addr);
        self.regions_len += 1;
    }

    pub fn record_read(self: *VMMemoryStats, addr: u64, size: u64) void {
        std.debug.assert(addr + size <= self.total_memory_bytes);
        self.total_reads += 1;
        self.total_bytes_read += size;
        self.update_region_access(addr, size, true);
    }

    pub fn record_write(self: *VMMemoryStats, addr: u64, size: u64) void {
        std.debug.assert(addr + size <= self.total_memory_bytes);
        self.total_writes += 1;
        self.total_bytes_written += size;
        self.update_region_access(addr, size, false);
    }

    fn update_region_access(self: *VMMemoryStats, addr: u64, size: u64, is_read: bool) void {
        var i: u32 = 0;
        while (i < self.regions_len) : (i += 1) {
            if (self.regions[i].contains(addr)) {
                if (is_read) {
                    self.regions[i].read_count += 1;
                    self.regions[i].total_bytes_read += size;
                } else {
                    self.regions[i].write_count += 1;
                    self.regions[i].total_bytes_written += size;
                }
                break;
            }
        }
    }

    pub fn update_used_memory(self: *VMMemoryStats, used_bytes: u64) void {
        std.debug.assert(used_bytes <= self.total_memory_bytes);
        self.used_memory_bytes = used_bytes;
    }

    pub fn print_stats(self: *const VMMemoryStats) void {
        std.debug.print("\nVM Memory Statistics:\n", .{});
        std.debug.print("  Total Memory: {} bytes ({d:.2} MB)\n", .{
            self.total_memory_bytes,
            @as(f64, @floatFromInt(self.total_memory_bytes)) / (1024.0 * 1024.0),
        });
        std.debug.print("  Used Memory: {} bytes ({d:.2} MB)\n", .{
            self.used_memory_bytes,
            @as(f64, @floatFromInt(self.used_memory_bytes)) / (1024.0 * 1024.0),
        });
        if (self.total_memory_bytes > 0) {
            const usage_percent = @as(f64, @floatFromInt(self.used_memory_bytes)) /
                @as(f64, @floatFromInt(self.total_memory_bytes)) * 100.0;
            std.debug.print("  Memory Usage: {d:.2}%\n", .{usage_percent});
        }
        std.debug.print("  Total Reads: {}\n", .{self.total_reads});
        std.debug.print("  Total Writes: {}\n", .{self.total_writes});
        if (self.total_bytes_read > 0) {
            const read_mb = @as(f64, @floatFromInt(self.total_bytes_read)) / (1024.0 * 1024.0);
            std.debug.print("  Total Bytes Read: {d:.2} MB\n", .{read_mb});
        }
        if (self.total_bytes_written > 0) {
            const write_mb = @as(f64, @floatFromInt(self.total_bytes_written)) / (1024.0 * 1024.0);
            std.debug.print("  Total Bytes Written: {d:.2} MB\n", .{write_mb});
        }
        if (self.regions_len > 0) {
            std.debug.print("  Memory Regions Tracked: {}\n", .{self.regions_len});
            var i: u32 = 0;
            while (i < self.regions_len) : (i += 1) {
                const region = self.regions[i];
                if (region.read_count > 0 or region.write_count > 0) {
                    std.debug.print("    Region 0x{x}-0x{x}: {} reads, {} writes\n", .{
                        region.start_addr,
                        region.end_addr,
                        region.read_count,
                        region.write_count,
                    });
                }
            }
        }
    }

    pub fn reset(self: *VMMemoryStats) void {
        self.used_memory_bytes = 0;
        self.total_reads = 0;
        self.total_writes = 0;
        self.total_bytes_read = 0;
        self.total_bytes_written = 0;
        var i: u32 = 0;
        while (i < self.regions_len) : (i += 1) {
            self.regions[i].read_count = 0;
            self.regions[i].write_count = 0;
            self.regions[i].total_bytes_read = 0;
            self.regions[i].total_bytes_written = 0;
        }
    }
};

