//! UDP Socket Statistics Tracking System
//!
//! Objective: Track UDP socket performance metrics for monitoring and debugging.
//! Why: Monitor socket behavior, identify performance issues, validate network operations.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track bytes sent/received per socket and globally
//! - Track datagrams sent/received per socket and globally
//! - Track bound socket count
//! - Track error counts (send errors, receive errors)
//! - Provide statistics interface for querying socket data
//! - Reset capability for new measurement periods
//!
//! GrainStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded counters: fixed-size counters (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-12-23
//! GrainStyle: Comprehensive UDP socket tracking, deterministic behavior, explicit limits

const std = @import("std");
const Debug = @import("debug.zig");

/// UDP socket statistics tracker.
/// Why: Track UDP socket performance metrics.
/// GrainStyle: Static allocation, bounded counters, explicit types.
pub const UdpSocketStats = struct {
    /// Total bytes sent across all sockets.
    /// Why: Track total data transmitted.
    total_bytes_sent: u64,
    
    /// Total bytes received across all sockets.
    /// Why: Track total data received.
    total_bytes_received: u64,
    
    /// Total datagrams sent across all sockets.
    /// Why: Track total datagrams transmitted.
    total_datagrams_sent: u64,
    
    /// Total datagrams received across all sockets.
    /// Why: Track total datagrams received.
    total_datagrams_received: u64,
    
    /// Total bound sockets.
    /// Why: Track number of bound sockets.
    total_bound_sockets: u32,
    
    /// Total closed sockets.
    /// Why: Track number of closed sockets.
    total_closed_sockets: u64,
    
    /// Total send errors.
    /// Why: Track send operation failures.
    total_send_errors: u64,
    
    /// Total receive errors.
    /// Why: Track receive operation failures.
    total_receive_errors: u64,
    
    /// Total binding operations.
    /// Why: Track how many sockets are bound.
    total_binding_operations: u64,
    
    /// Initialize UDP socket statistics.
    /// Why: Set up statistics tracker with zero counters.
    pub fn init() UdpSocketStats {
        return UdpSocketStats{
            .total_bytes_sent = 0,
            .total_bytes_received = 0,
            .total_datagrams_sent = 0,
            .total_datagrams_received = 0,
            .total_bound_sockets = 0,
            .total_closed_sockets = 0,
            .total_send_errors = 0,
            .total_receive_errors = 0,
            .total_binding_operations = 0,
        };
    }
    
    /// Record bytes sent.
    /// Why: Track data transmission.
    pub fn record_bytes_sent(self: *UdpSocketStats, bytes: u32) void {
        self.total_bytes_sent += bytes;
        self.total_datagrams_sent += 1;
        
        // Assert: Counters must be incremented (postcondition).
        Debug.kassert(self.total_bytes_sent > 0 or bytes == 0, "Bytes sent counter not incremented", .{});
    }
    
    /// Record bytes received.
    /// Why: Track data reception.
    pub fn record_bytes_received(self: *UdpSocketStats, bytes: u32) void {
        self.total_bytes_received += bytes;
        self.total_datagrams_received += 1;
        
        // Assert: Counters must be incremented (postcondition).
        Debug.kassert(self.total_bytes_received > 0 or bytes == 0, "Bytes received counter not incremented", .{});
    }
    
    /// Record bound socket.
    /// Why: Track when a socket is bound.
    pub fn record_bound_socket(self: *UdpSocketStats) void {
        self.total_bound_sockets += 1;
        self.total_binding_operations += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_bound_sockets > 0, "Bound sockets counter not incremented", .{});
    }
    
    /// Record closed socket.
    /// Why: Track when a socket is closed.
    pub fn record_closed_socket(self: *UdpSocketStats) void {
        self.total_closed_sockets += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_closed_sockets > 0, "Closed sockets counter not incremented", .{});
    }
    
    /// Record send error.
    /// Why: Track send operation failures.
    pub fn record_send_error(self: *UdpSocketStats) void {
        self.total_send_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_send_errors > 0, "Send errors counter not incremented", .{});
    }
    
    /// Record receive error.
    /// Why: Track receive operation failures.
    pub fn record_receive_error(self: *UdpSocketStats) void {
        self.total_receive_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_receive_errors > 0, "Receive errors counter not incremented", .{});
    }
    
    /// Reset bound socket count.
    /// Why: Update bound socket count when sockets change.
    pub fn reset_bound_sockets(self: *UdpSocketStats, count: u32) void {
        self.total_bound_sockets = count;
    }
    
    /// Get error rate (errors per operation).
    /// Why: Calculate error rate for monitoring.
    /// Returns: Error rate percentage (0.0 to 100.0).
    pub fn get_error_rate(self: *const UdpSocketStats) f64 {
        const total_operations = self.total_datagrams_sent + self.total_datagrams_received;
        if (total_operations == 0) {
            return 0.0;
        }
        
        const total_errors = self.total_send_errors + self.total_receive_errors;
        const error_rate = (@as(f64, @floatFromInt(total_errors)) * 100.0) / @as(f64, @floatFromInt(total_operations));
        
        // Assert: Error rate must be valid (postcondition).
        Debug.kassert(error_rate >= 0.0, "Error rate negative", .{});
        Debug.kassert(error_rate <= 100.0, "Error rate exceeds 100", .{});
        
        return error_rate;
    }
    
    /// Get average bytes per datagram sent.
    /// Why: Calculate average datagram size for monitoring.
    /// Returns: Average bytes per datagram (0.0 if no datagrams).
    pub fn get_avg_bytes_per_datagram_sent(self: *const UdpSocketStats) f64 {
        if (self.total_datagrams_sent == 0) {
            return 0.0;
        }
        
        const avg = @as(f64, @floatFromInt(self.total_bytes_sent)) / @as(f64, @floatFromInt(self.total_datagrams_sent));
        
        // Assert: Average must be non-negative (postcondition).
        Debug.kassert(avg >= 0.0, "Average bytes per datagram negative", .{});
        
        return avg;
    }
    
    /// Get average bytes per datagram received.
    /// Why: Calculate average datagram size for monitoring.
    /// Returns: Average bytes per datagram (0.0 if no datagrams).
    pub fn get_avg_bytes_per_datagram_received(self: *const UdpSocketStats) f64 {
        if (self.total_datagrams_received == 0) {
            return 0.0;
        }
        
        const avg = @as(f64, @floatFromInt(self.total_bytes_received)) / @as(f64, @floatFromInt(self.total_datagrams_received));
        
        // Assert: Average must be non-negative (postcondition).
        Debug.kassert(avg >= 0.0, "Average bytes per datagram negative", .{});
        
        return avg;
    }
    
    /// Print UDP socket statistics.
    /// Why: Display socket metrics for monitoring.
    pub fn print_stats(self: *const UdpSocketStats) void {
        std.debug.print("\nUDP Socket Statistics:\n", .{});
        std.debug.print("  Total Bytes Sent: {}\n", .{self.total_bytes_sent});
        std.debug.print("  Total Bytes Received: {}\n", .{self.total_bytes_received});
        std.debug.print("  Total Datagrams Sent: {}\n", .{self.total_datagrams_sent});
        std.debug.print("  Total Datagrams Received: {}\n", .{self.total_datagrams_received});
        std.debug.print("  Bound Sockets: {}\n", .{self.total_bound_sockets});
        std.debug.print("  Closed Sockets: {}\n", .{self.total_closed_sockets});
        std.debug.print("  Send Errors: {}\n", .{self.total_send_errors});
        std.debug.print("  Receive Errors: {}\n", .{self.total_receive_errors});
        std.debug.print("  Binding Operations: {}\n", .{self.total_binding_operations});
        
        // Calculate and display metrics.
        const error_rate = self.get_error_rate();
        std.debug.print("  Error Rate: {d:.2}%\n", .{error_rate});
        
        if (self.total_datagrams_sent > 0) {
            const avg_sent = self.get_avg_bytes_per_datagram_sent();
            std.debug.print("  Avg Bytes Per Datagram Sent: {d:.2}\n", .{avg_sent});
        }
        
        if (self.total_datagrams_received > 0) {
            const avg_recv = self.get_avg_bytes_per_datagram_received();
            std.debug.print("  Avg Bytes Per Datagram Received: {d:.2}\n", .{avg_recv});
        }
    }
    
    /// Reset all statistics.
    /// Why: Clear counters for new measurement period.
    pub fn reset(self: *UdpSocketStats) void {
        self.total_bytes_sent = 0;
        self.total_bytes_received = 0;
        self.total_datagrams_sent = 0;
        self.total_datagrams_received = 0;
        self.total_bound_sockets = 0;
        self.total_closed_sockets = 0;
        self.total_send_errors = 0;
        self.total_receive_errors = 0;
        self.total_binding_operations = 0;
        
        // Assert: All counters must be zero (postcondition).
        Debug.kassert(self.total_bytes_sent == 0, "Bytes sent counter not reset", .{});
        Debug.kassert(self.total_bytes_received == 0, "Bytes received counter not reset", .{});
    }
};

// Test: UDP socket statistics initialization.
test "udp socket stats init" {
    const stats = UdpSocketStats.init();
    
    // Assert: All counters must be zero.
    try std.testing.expect(stats.total_bytes_sent == 0);
    try std.testing.expect(stats.total_bytes_received == 0);
    try std.testing.expect(stats.total_datagrams_sent == 0);
    try std.testing.expect(stats.total_bound_sockets == 0);
}

// Test: UDP socket statistics recording.
test "udp socket stats recording" {
    var stats = UdpSocketStats.init();
    
    stats.record_bytes_sent(512);
    try std.testing.expect(stats.total_bytes_sent == 512);
    try std.testing.expect(stats.total_datagrams_sent == 1);
    
    stats.record_bytes_received(256);
    try std.testing.expect(stats.total_bytes_received == 256);
    try std.testing.expect(stats.total_datagrams_received == 1);
    
    stats.record_send_error();
    try std.testing.expect(stats.total_send_errors == 1);
}

// Test: UDP socket statistics reset.
test "udp socket stats reset" {
    var stats = UdpSocketStats.init();
    
    stats.record_bytes_sent(512);
    stats.record_send_error();
    stats.reset();
    
    // Assert: All counters must be zero after reset.
    try std.testing.expect(stats.total_bytes_sent == 0);
    try std.testing.expect(stats.total_send_errors == 0);
}

// Test: UDP socket statistics error rate calculation.
test "udp socket stats error rate" {
    var stats = UdpSocketStats.init();
    
    // No operations: error rate should be 0.
    try std.testing.expect(stats.get_error_rate() == 0.0);
    
    // Add operations and errors.
    stats.record_bytes_sent(512);
    stats.record_bytes_received(256);
    stats.record_send_error();
    
    // Error rate: 1 error / 2 operations = 50%
    const error_rate = stats.get_error_rate();
    try std.testing.expect(error_rate == 50.0);
}

// Test: UDP socket statistics average bytes per datagram.
test "udp socket stats avg bytes per datagram" {
    var stats = UdpSocketStats.init();
    
    // No datagrams: average should be 0.
    try std.testing.expect(stats.get_avg_bytes_per_datagram_sent() == 0.0);
    
    // Add datagrams.
    stats.record_bytes_sent(512); // 1 datagram, 512 bytes
    stats.record_bytes_sent(256); // 1 datagram, 256 bytes
    
    // Average: (512 + 256) / 2 = 384 bytes
    const avg = stats.get_avg_bytes_per_datagram_sent();
    try std.testing.expect(avg == 384.0);
}
