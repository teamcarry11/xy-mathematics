//! Kernel Statistics Aggregator
//!
//! Objective: Aggregate statistics from all kernel subsystems for unified monitoring.
//! Why: Provide a single interface to query all kernel statistics for system monitoring and debugging.
//! GrainStyle: Static allocation, bounded operations, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Collect statistics from all subsystems (sockets, network, audio, scheduler, memory, page faults)
//! - Provide unified statistics snapshot
//! - Calculate aggregate metrics (total errors, total operations, overall health)
//! - Enable comprehensive system monitoring
//!
//! GrainStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded operations: fixed-size aggregations
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-12-23
//! GrainStyle: Comprehensive statistics aggregation, deterministic behavior, explicit limits

const std = @import("std");
const Debug = @import("debug.zig");
const TcpSocketStats = @import("tcp_socket_stats.zig").TcpSocketStats;
const UdpSocketStats = @import("udp_socket_stats.zig").UdpSocketStats;
const NetworkInterfaceStats = @import("network_interface_stats.zig").NetworkInterfaceStats;
const AudioDeviceStats = @import("audio_device_stats.zig").AudioDeviceStats;
const SchedulerStats = @import("scheduler_stats.zig").SchedulerStats;
const MemoryStats = @import("memory_stats.zig").MemoryStats;
const PageFaultStats = @import("page_fault_stats.zig").PageFaultStats;

/// Kernel statistics snapshot.
/// Why: Capture statistics from all subsystems at a point in time.
/// GrainStyle: Static allocation, explicit types.
pub const KernelStatsSnapshot = struct {
    /// TCP socket statistics.
    tcp_stats: *const TcpSocketStats,
    
    /// UDP socket statistics.
    udp_stats: *const UdpSocketStats,
    
    /// Network interface statistics.
    network_stats: *const NetworkInterfaceStats,
    
    /// Audio device statistics.
    audio_stats: *const AudioDeviceStats,
    
    /// Scheduler statistics.
    scheduler_stats: *const SchedulerStats,
    
    /// Memory statistics.
    memory_stats: *const MemoryStats,
    
    /// Page fault statistics.
    page_fault_stats: *const PageFaultStats,
    
    /// Total errors across all subsystems.
    /// Why: Aggregate error count for system health monitoring.
    total_errors: u64,
    
    /// Total operations across all subsystems.
    /// Why: Aggregate operation count for system activity monitoring.
    total_operations: u64,
    
    /// Overall system health score (0.0 to 100.0, higher is better).
    /// Why: Single metric for system health assessment.
    health_score: f64,
    
    /// Create kernel statistics snapshot.
    /// Why: Capture current statistics state from all subsystems.
    /// Contract: All statistics pointers must be valid.
    pub fn create(
        tcp_stats: *const TcpSocketStats,
        udp_stats: *const UdpSocketStats,
        network_stats: *const NetworkInterfaceStats,
        audio_stats: *const AudioDeviceStats,
        scheduler_stats: *const SchedulerStats,
        memory_stats: *const MemoryStats,
        page_fault_stats: *const PageFaultStats,
    ) KernelStatsSnapshot {
        // Assert: All statistics pointers must be valid (precondition).
        Debug.kassert(@intFromPtr(tcp_stats) != 0, "TCP stats ptr is null", .{});
        Debug.kassert(@intFromPtr(udp_stats) != 0, "UDP stats ptr is null", .{});
        Debug.kassert(@intFromPtr(network_stats) != 0, "Network stats ptr is null", .{});
        Debug.kassert(@intFromPtr(audio_stats) != 0, "Audio stats ptr is null", .{});
        Debug.kassert(@intFromPtr(scheduler_stats) != 0, "Scheduler stats ptr is null", .{});
        Debug.kassert(@intFromPtr(memory_stats) != 0, "Memory stats ptr is null", .{});
        Debug.kassert(@intFromPtr(page_fault_stats) != 0, "Page fault stats ptr is null", .{});
        
        // Calculate total errors.
        const total_errors = tcp_stats.total_connection_errors + tcp_stats.total_send_errors + tcp_stats.total_receive_errors +
            udp_stats.total_send_errors + udp_stats.total_receive_errors +
            network_stats.total_creation_errors + network_stats.total_configuration_errors + network_stats.total_deletion_errors +
            audio_stats.total_creation_errors + audio_stats.total_configuration_errors + audio_stats.total_io_errors + audio_stats.total_deletion_errors;
        
        // Calculate total operations.
        const total_operations = tcp_stats.total_packets_sent + tcp_stats.total_packets_received + tcp_stats.total_connected_transitions +
            udp_stats.total_datagrams_sent + udp_stats.total_datagrams_received +
            network_stats.total_interfaces_created + network_stats.total_ipv4_configurations + network_stats.total_ipv6_configurations +
            audio_stats.total_devices_created + audio_stats.total_volume_changes + audio_stats.total_format_changes +
            scheduler_stats.total_scheduling_decisions +
            page_fault_stats.total_count;
        
        // Calculate health score (100.0 - error_rate).
        var health_score: f64 = 100.0;
        if (total_operations > 0) {
            const error_rate = (@as(f64, @floatFromInt(total_errors)) * 100.0) / @as(f64, @floatFromInt(total_operations));
            health_score = 100.0 - error_rate;
            if (health_score < 0.0) {
                health_score = 0.0;
            }
        }
        
        // Assert: Health score must be valid (postcondition).
        Debug.kassert(health_score >= 0.0, "Health score negative", .{});
        Debug.kassert(health_score <= 100.0, "Health score exceeds 100", .{});
        
        return KernelStatsSnapshot{
            .tcp_stats = tcp_stats,
            .udp_stats = udp_stats,
            .network_stats = network_stats,
            .audio_stats = audio_stats,
            .scheduler_stats = scheduler_stats,
            .memory_stats = memory_stats,
            .page_fault_stats = page_fault_stats,
            .total_errors = total_errors,
            .total_operations = total_operations,
            .health_score = health_score,
        };
    }
    
    /// Print kernel statistics snapshot.
    /// Why: Display comprehensive system statistics for monitoring.
    pub fn print(self: *const KernelStatsSnapshot) void {
        // Assert: Snapshot must be valid (precondition).
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Snapshot ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(KernelStatsSnapshot) == 0, "Snapshot ptr unaligned", .{});
        
        std.debug.print("\n=== Kernel Statistics Summary ===\n", .{});
        std.debug.print("Total Errors: {}\n", .{self.total_errors});
        std.debug.print("Total Operations: {}\n", .{self.total_operations});
        std.debug.print("System Health Score: {d:.2}%\n", .{self.health_score});
        
        std.debug.print("\n--- TCP Socket Statistics ---\n", .{});
        self.tcp_stats.print_stats();
        
        std.debug.print("\n--- UDP Socket Statistics ---\n", .{});
        self.udp_stats.print_stats();
        
        std.debug.print("\n--- Network Interface Statistics ---\n", .{});
        self.network_stats.print_stats();
        
        std.debug.print("\n--- Audio Device Statistics ---\n", .{});
        self.audio_stats.print_stats();
        
        std.debug.print("\n--- Scheduler Statistics ---\n", .{});
        self.scheduler_stats.print_stats();
        
        std.debug.print("\n--- Memory Statistics ---\n", .{});
        if (self.memory_stats.initialized) {
            std.debug.print("  Mapped Pages: {}\n", .{self.memory_stats.mapped_pages});
            std.debug.print("  Unmapped Pages: {}\n", .{self.memory_stats.unmapped_pages});
            std.debug.print("  Total Mappings: {}\n", .{self.memory_stats.total_mappings});
            const usage_pct = self.memory_stats.get_usage_percentage();
            std.debug.print("  Usage Percentage: {d:.2}%\n", .{usage_pct});
        }
        
        std.debug.print("\n--- Page Fault Statistics ---\n", .{});
        if (self.page_fault_stats.initialized) {
            std.debug.print("  Total Page Faults: {}\n", .{self.page_fault_stats.total_count});
            const inst_count = self.page_fault_stats.get_count(.instruction);
            const load_count = self.page_fault_stats.get_count(.load);
            const store_count = self.page_fault_stats.get_count(.store);
            std.debug.print("  Instruction Faults: {}\n", .{inst_count});
            std.debug.print("  Load Faults: {}\n", .{load_count});
            std.debug.print("  Store Faults: {}\n", .{store_count});
        }
        
        std.debug.print("\n=== End Kernel Statistics Summary ===\n", .{});
    }
};

// Test: Kernel statistics snapshot creation.
test "kernel stats snapshot create" {
    const tcp_stats = TcpSocketStats.init();
    const udp_stats = UdpSocketStats.init();
    const network_stats = NetworkInterfaceStats.init();
    const audio_stats = AudioDeviceStats.init();
    const scheduler_stats = SchedulerStats.init();
    const memory_stats = MemoryStats.init();
    const page_fault_stats = PageFaultStats.init();
    
    const snapshot = KernelStatsSnapshot.create(
        &tcp_stats,
        &udp_stats,
        &network_stats,
        &audio_stats,
        &scheduler_stats,
        &memory_stats,
        &page_fault_stats,
    );
    
    // Assert: Snapshot must be valid.
    try std.testing.expect(snapshot.total_errors == 0);
    try std.testing.expect(snapshot.total_operations == 0);
    try std.testing.expect(snapshot.health_score == 100.0);
}

// Test: Kernel statistics snapshot with errors.
test "kernel stats snapshot with errors" {
    var tcp_stats = TcpSocketStats.init();
    var udp_stats = UdpSocketStats.init();
    var network_stats = NetworkInterfaceStats.init();
    var audio_stats = AudioDeviceStats.init();
    const scheduler_stats = SchedulerStats.init();
    const memory_stats = MemoryStats.init();
    const page_fault_stats = PageFaultStats.init();
    
    // Add some operations and errors.
    tcp_stats.record_bytes_sent(1024);
    tcp_stats.record_connection_error();
    udp_stats.record_bytes_sent(512);
    network_stats.record_interface_created();
    audio_stats.record_device_created();
    
    const snapshot = KernelStatsSnapshot.create(
        &tcp_stats,
        &udp_stats,
        &network_stats,
        &audio_stats,
        &scheduler_stats,
        &memory_stats,
        &page_fault_stats,
    );
    
    // Assert: Snapshot must reflect errors.
    try std.testing.expect(snapshot.total_errors > 0);
    try std.testing.expect(snapshot.total_operations > 0);
    try std.testing.expect(snapshot.health_score < 100.0);
}
