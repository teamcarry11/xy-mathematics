//! TCP Socket Statistics Tracking System
//!
//! Objective: Track TCP socket performance metrics for monitoring and debugging.
//! Why: Monitor socket behavior, identify performance issues, validate network operations.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track bytes sent/received per socket and globally
//! - Track packets sent/received per socket and globally
//! - Track connection counts (active, established, closed)
//! - Track error counts (connection errors, send errors, receive errors)
//! - Track state transitions (listening, connecting, connected, closing)
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
//! GrainStyle: Comprehensive TCP socket tracking, deterministic behavior, explicit limits

const std = @import("std");
const Debug = @import("debug.zig");

/// TCP socket statistics tracker.
/// Why: Track TCP socket performance metrics.
/// GrainStyle: Static allocation, bounded counters, explicit types.
pub const TcpSocketStats = struct {
    /// Total bytes sent across all sockets.
    /// Why: Track total data transmitted.
    total_bytes_sent: u64,
    
    /// Total bytes received across all sockets.
    /// Why: Track total data received.
    total_bytes_received: u64,
    
    /// Total packets sent across all sockets.
    /// Why: Track total packets transmitted.
    total_packets_sent: u64,
    
    /// Total packets received across all sockets.
    /// Why: Track total packets received.
    total_packets_received: u64,
    
    /// Total active connections (listening + connecting + connected).
    /// Why: Track number of active connections.
    total_active_connections: u32,
    
    /// Total established connections (connected state).
    /// Why: Track number of fully established connections.
    total_established_connections: u32,
    
    /// Total closed connections.
    /// Why: Track number of closed connections.
    total_closed_connections: u64,
    
    /// Total connection errors.
    /// Why: Track connection failures.
    total_connection_errors: u64,
    
    /// Total send errors.
    /// Why: Track send operation failures.
    total_send_errors: u64,
    
    /// Total receive errors.
    /// Why: Track receive operation failures.
    total_receive_errors: u64,
    
    /// Total state transitions to listening.
    /// Why: Track how many sockets enter listening state.
    total_listening_transitions: u64,
    
    /// Total state transitions to connecting.
    /// Why: Track how many sockets enter connecting state.
    total_connecting_transitions: u64,
    
    /// Total state transitions to connected.
    /// Why: Track how many sockets enter connected state.
    total_connected_transitions: u64,
    
    /// Total state transitions to closing.
    /// Why: Track how many sockets enter closing state.
    total_closing_transitions: u64,
    
    /// Initialize TCP socket statistics.
    /// Why: Set up statistics tracker with zero counters.
    pub fn init() TcpSocketStats {
        return TcpSocketStats{
            .total_bytes_sent = 0,
            .total_bytes_received = 0,
            .total_packets_sent = 0,
            .total_packets_received = 0,
            .total_active_connections = 0,
            .total_established_connections = 0,
            .total_closed_connections = 0,
            .total_connection_errors = 0,
            .total_send_errors = 0,
            .total_receive_errors = 0,
            .total_listening_transitions = 0,
            .total_connecting_transitions = 0,
            .total_connected_transitions = 0,
            .total_closing_transitions = 0,
        };
    }
    
    /// Record bytes sent.
    /// Why: Track data transmission.
    pub fn record_bytes_sent(self: *TcpSocketStats, bytes: u32) void {
        self.total_bytes_sent += bytes;
        self.total_packets_sent += 1;
        
        // Assert: Counters must be incremented (postcondition).
        Debug.kassert(self.total_bytes_sent > 0 or bytes == 0, "Bytes sent counter not incremented", .{});
    }
    
    /// Record bytes received.
    /// Why: Track data reception.
    pub fn record_bytes_received(self: *TcpSocketStats, bytes: u32) void {
        self.total_bytes_received += bytes;
        self.total_packets_received += 1;
        
        // Assert: Counters must be incremented (postcondition).
        Debug.kassert(self.total_bytes_received > 0 or bytes == 0, "Bytes received counter not incremented", .{});
    }
    
    /// Record active connection.
    /// Why: Track when a connection becomes active.
    pub fn record_active_connection(self: *TcpSocketStats) void {
        self.total_active_connections += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_active_connections > 0, "Active connections counter not incremented", .{});
    }
    
    /// Record established connection.
    /// Why: Track when a connection is fully established.
    pub fn record_established_connection(self: *TcpSocketStats) void {
        self.total_established_connections += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_established_connections > 0, "Established connections counter not incremented", .{});
    }
    
    /// Record closed connection.
    /// Why: Track when a connection is closed.
    pub fn record_closed_connection(self: *TcpSocketStats) void {
        self.total_closed_connections += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_closed_connections > 0, "Closed connections counter not incremented", .{});
    }
    
    /// Record connection error.
    /// Why: Track connection failures.
    pub fn record_connection_error(self: *TcpSocketStats) void {
        self.total_connection_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_connection_errors > 0, "Connection errors counter not incremented", .{});
    }
    
    /// Record send error.
    /// Why: Track send operation failures.
    pub fn record_send_error(self: *TcpSocketStats) void {
        self.total_send_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_send_errors > 0, "Send errors counter not incremented", .{});
    }
    
    /// Record receive error.
    /// Why: Track receive operation failures.
    pub fn record_receive_error(self: *TcpSocketStats) void {
        self.total_receive_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_receive_errors > 0, "Receive errors counter not incremented", .{});
    }
    
    /// Record listening state transition.
    /// Why: Track when a socket enters listening state.
    pub fn record_listening_transition(self: *TcpSocketStats) void {
        self.total_listening_transitions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_listening_transitions > 0, "Listening transitions counter not incremented", .{});
    }
    
    /// Record connecting state transition.
    /// Why: Track when a socket enters connecting state.
    pub fn record_connecting_transition(self: *TcpSocketStats) void {
        self.total_connecting_transitions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_connecting_transitions > 0, "Connecting transitions counter not incremented", .{});
    }
    
    /// Record connected state transition.
    /// Why: Track when a socket enters connected state.
    pub fn record_connected_transition(self: *TcpSocketStats) void {
        self.total_connected_transitions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_connected_transitions > 0, "Connected transitions counter not incremented", .{});
    }
    
    /// Record closing state transition.
    /// Why: Track when a socket enters closing state.
    pub fn record_closing_transition(self: *TcpSocketStats) void {
        self.total_closing_transitions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_closing_transitions > 0, "Closing transitions counter not incremented", .{});
    }
    
    /// Reset active connection count.
    /// Why: Update active connection count when connections change.
    pub fn reset_active_connections(self: *TcpSocketStats, count: u32) void {
        self.total_active_connections = count;
    }
    
    /// Reset established connection count.
    /// Why: Update established connection count when connections change.
    pub fn reset_established_connections(self: *TcpSocketStats, count: u32) void {
        self.total_established_connections = count;
    }
    
    /// Get error rate (errors per operation).
    /// Why: Calculate error rate for monitoring.
    /// Returns: Error rate percentage (0.0 to 100.0).
    pub fn get_error_rate(self: *const TcpSocketStats) f64 {
        const total_operations = self.total_packets_sent + self.total_packets_received + self.total_connected_transitions;
        if (total_operations == 0) {
            return 0.0;
        }
        
        const total_errors = self.total_connection_errors + self.total_send_errors + self.total_receive_errors;
        const error_rate = (@as(f64, @floatFromInt(total_errors)) * 100.0) / @as(f64, @floatFromInt(total_operations));
        
        // Assert: Error rate must be valid (postcondition).
        Debug.kassert(error_rate >= 0.0, "Error rate negative", .{});
        Debug.kassert(error_rate <= 100.0, "Error rate exceeds 100", .{});
        
        return error_rate;
    }
    
    /// Get average bytes per packet.
    /// Why: Calculate average packet size for monitoring.
    /// Returns: Average bytes per packet (0.0 if no packets).
    pub fn get_avg_bytes_per_packet_sent(self: *const TcpSocketStats) f64 {
        if (self.total_packets_sent == 0) {
            return 0.0;
        }
        
        const avg = @as(f64, @floatFromInt(self.total_bytes_sent)) / @as(f64, @floatFromInt(self.total_packets_sent));
        
        // Assert: Average must be non-negative (postcondition).
        Debug.kassert(avg >= 0.0, "Average bytes per packet negative", .{});
        
        return avg;
    }
    
    /// Get average bytes per packet received.
    /// Why: Calculate average packet size for monitoring.
    /// Returns: Average bytes per packet (0.0 if no packets).
    pub fn get_avg_bytes_per_packet_received(self: *const TcpSocketStats) f64 {
        if (self.total_packets_received == 0) {
            return 0.0;
        }
        
        const avg = @as(f64, @floatFromInt(self.total_bytes_received)) / @as(f64, @floatFromInt(self.total_packets_received));
        
        // Assert: Average must be non-negative (postcondition).
        Debug.kassert(avg >= 0.0, "Average bytes per packet negative", .{});
        
        return avg;
    }
    
    /// Print TCP socket statistics.
    /// Why: Display socket metrics for monitoring.
    pub fn print_stats(self: *const TcpSocketStats) void {
        std.debug.print("\nTCP Socket Statistics:\n", .{});
        std.debug.print("  Total Bytes Sent: {}\n", .{self.total_bytes_sent});
        std.debug.print("  Total Bytes Received: {}\n", .{self.total_bytes_received});
        std.debug.print("  Total Packets Sent: {}\n", .{self.total_packets_sent});
        std.debug.print("  Total Packets Received: {}\n", .{self.total_packets_received});
        std.debug.print("  Active Connections: {}\n", .{self.total_active_connections});
        std.debug.print("  Established Connections: {}\n", .{self.total_established_connections});
        std.debug.print("  Closed Connections: {}\n", .{self.total_closed_connections});
        std.debug.print("  Connection Errors: {}\n", .{self.total_connection_errors});
        std.debug.print("  Send Errors: {}\n", .{self.total_send_errors});
        std.debug.print("  Receive Errors: {}\n", .{self.total_receive_errors});
        std.debug.print("  Listening Transitions: {}\n", .{self.total_listening_transitions});
        std.debug.print("  Connecting Transitions: {}\n", .{self.total_connecting_transitions});
        std.debug.print("  Connected Transitions: {}\n", .{self.total_connected_transitions});
        std.debug.print("  Closing Transitions: {}\n", .{self.total_closing_transitions});
        
        // Calculate and display metrics.
        const error_rate = self.get_error_rate();
        std.debug.print("  Error Rate: {d:.2}%\n", .{error_rate});
        
        if (self.total_packets_sent > 0) {
            const avg_sent = self.get_avg_bytes_per_packet_sent();
            std.debug.print("  Avg Bytes Per Packet Sent: {d:.2}\n", .{avg_sent});
        }
        
        if (self.total_packets_received > 0) {
            const avg_recv = self.get_avg_bytes_per_packet_received();
            std.debug.print("  Avg Bytes Per Packet Received: {d:.2}\n", .{avg_recv});
        }
    }
    
    /// Reset all statistics.
    /// Why: Clear counters for new measurement period.
    pub fn reset(self: *TcpSocketStats) void {
        self.total_bytes_sent = 0;
        self.total_bytes_received = 0;
        self.total_packets_sent = 0;
        self.total_packets_received = 0;
        self.total_active_connections = 0;
        self.total_established_connections = 0;
        self.total_closed_connections = 0;
        self.total_connection_errors = 0;
        self.total_send_errors = 0;
        self.total_receive_errors = 0;
        self.total_listening_transitions = 0;
        self.total_connecting_transitions = 0;
        self.total_connected_transitions = 0;
        self.total_closing_transitions = 0;
        
        // Assert: All counters must be zero (postcondition).
        Debug.kassert(self.total_bytes_sent == 0, "Bytes sent counter not reset", .{});
        Debug.kassert(self.total_bytes_received == 0, "Bytes received counter not reset", .{});
    }
};

// Test: TCP socket statistics initialization.
test "tcp socket stats init" {
    const stats = TcpSocketStats.init();
    
    // Assert: All counters must be zero.
    try std.testing.expect(stats.total_bytes_sent == 0);
    try std.testing.expect(stats.total_bytes_received == 0);
    try std.testing.expect(stats.total_packets_sent == 0);
    try std.testing.expect(stats.total_active_connections == 0);
}

// Test: TCP socket statistics recording.
test "tcp socket stats recording" {
    var stats = TcpSocketStats.init();
    
    stats.record_bytes_sent(1024);
    try std.testing.expect(stats.total_bytes_sent == 1024);
    try std.testing.expect(stats.total_packets_sent == 1);
    
    stats.record_bytes_received(2048);
    try std.testing.expect(stats.total_bytes_received == 2048);
    try std.testing.expect(stats.total_packets_received == 1);
    
    stats.record_connection_error();
    try std.testing.expect(stats.total_connection_errors == 1);
}

// Test: TCP socket statistics reset.
test "tcp socket stats reset" {
    var stats = TcpSocketStats.init();
    
    stats.record_bytes_sent(1024);
    stats.record_connection_error();
    stats.reset();
    
    // Assert: All counters must be zero after reset.
    try std.testing.expect(stats.total_bytes_sent == 0);
    try std.testing.expect(stats.total_connection_errors == 0);
}

// Test: TCP socket statistics error rate calculation.
test "tcp socket stats error rate" {
    var stats = TcpSocketStats.init();
    
    // No operations: error rate should be 0.
    try std.testing.expect(stats.get_error_rate() == 0.0);
    
    // Add operations and errors.
    stats.record_bytes_sent(1024);
    stats.record_bytes_received(2048);
    stats.record_connected_transition();
    stats.record_connection_error();
    stats.record_send_error();
    
    // Error rate: 2 errors / 3 operations = 66.67%
    const error_rate = stats.get_error_rate();
    try std.testing.expect(error_rate > 60.0);
    try std.testing.expect(error_rate < 70.0);
}

// Test: TCP socket statistics average bytes per packet.
test "tcp socket stats avg bytes per packet" {
    var stats = TcpSocketStats.init();
    
    // No packets: average should be 0.
    try std.testing.expect(stats.get_avg_bytes_per_packet_sent() == 0.0);
    
    // Add packets.
    stats.record_bytes_sent(1024); // 1 packet, 1024 bytes
    stats.record_bytes_sent(2048); // 1 packet, 2048 bytes
    
    // Average: (1024 + 2048) / 2 = 1536 bytes
    const avg = stats.get_avg_bytes_per_packet_sent();
    try std.testing.expect(avg == 1536.0);
}
