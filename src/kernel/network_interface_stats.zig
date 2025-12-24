//! Network Interface Statistics Tracking System
//!
//! Objective: Track network interface operations and state changes for monitoring and debugging.
//! Why: Monitor interface behavior, identify configuration issues, validate network operations.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track interface creation/deletion operations
//! - Track state transitions (up/down)
//! - Track configuration operations (IPv4/IPv6 address changes)
//! - Track error counts (creation errors, configuration errors)
//! - Provide statistics interface for querying interface data
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
//! GrainStyle: Comprehensive network interface tracking, deterministic behavior, explicit limits

const std = @import("std");
const Debug = @import("debug.zig");

/// Network interface statistics tracker.
/// Why: Track network interface operations and state changes.
/// GrainStyle: Static allocation, bounded counters, explicit types.
pub const NetworkInterfaceStats = struct {
    /// Total interfaces created.
    /// Why: Track number of interfaces created.
    total_interfaces_created: u64,
    
    /// Total interfaces deleted.
    /// Why: Track number of interfaces deleted.
    total_interfaces_deleted: u64,
    
    /// Total active interfaces (currently allocated).
    /// Why: Track number of active interfaces.
    total_active_interfaces: u32,
    
    /// Total state transitions to up.
    /// Why: Track how many times interfaces are brought up.
    total_up_transitions: u64,
    
    /// Total state transitions to down.
    /// Why: Track how many times interfaces are brought down.
    total_down_transitions: u64,
    
    /// Total IPv4 address configurations.
    /// Why: Track IPv4 address configuration operations.
    total_ipv4_configurations: u64,
    
    /// Total IPv6 address configurations.
    /// Why: Track IPv6 address configuration operations.
    total_ipv6_configurations: u64,
    
    /// Total creation errors.
    /// Why: Track interface creation failures.
    total_creation_errors: u64,
    
    /// Total configuration errors.
    /// Why: Track configuration operation failures.
    total_configuration_errors: u64,
    
    /// Total deletion errors.
    /// Why: Track interface deletion failures.
    total_deletion_errors: u64,
    
    /// Initialize network interface statistics.
    /// Why: Set up statistics tracker with zero counters.
    pub fn init() NetworkInterfaceStats {
        return NetworkInterfaceStats{
            .total_interfaces_created = 0,
            .total_interfaces_deleted = 0,
            .total_active_interfaces = 0,
            .total_up_transitions = 0,
            .total_down_transitions = 0,
            .total_ipv4_configurations = 0,
            .total_ipv6_configurations = 0,
            .total_creation_errors = 0,
            .total_configuration_errors = 0,
            .total_deletion_errors = 0,
        };
    }
    
    /// Record interface creation.
    /// Why: Track when an interface is created.
    pub fn record_interface_created(self: *NetworkInterfaceStats) void {
        self.total_interfaces_created += 1;
        self.total_active_interfaces += 1;
        
        // Assert: Counters must be incremented (postcondition).
        Debug.kassert(self.total_interfaces_created > 0, "Interfaces created counter not incremented", .{});
        Debug.kassert(self.total_active_interfaces > 0, "Active interfaces counter not incremented", .{});
    }
    
    /// Record interface deletion.
    /// Why: Track when an interface is deleted.
    pub fn record_interface_deleted(self: *NetworkInterfaceStats) void {
        self.total_interfaces_deleted += 1;
        if (self.total_active_interfaces > 0) {
            self.total_active_interfaces -= 1;
        }
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_interfaces_deleted > 0, "Interfaces deleted counter not incremented", .{});
    }
    
    /// Record state transition to up.
    /// Why: Track when an interface is brought up.
    pub fn record_up_transition(self: *NetworkInterfaceStats) void {
        self.total_up_transitions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_up_transitions > 0, "Up transitions counter not incremented", .{});
    }
    
    /// Record state transition to down.
    /// Why: Track when an interface is brought down.
    pub fn record_down_transition(self: *NetworkInterfaceStats) void {
        self.total_down_transitions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_down_transitions > 0, "Down transitions counter not incremented", .{});
    }
    
    /// Record IPv4 configuration.
    /// Why: Track IPv4 address configuration operations.
    pub fn record_ipv4_configuration(self: *NetworkInterfaceStats) void {
        self.total_ipv4_configurations += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_ipv4_configurations > 0, "IPv4 configurations counter not incremented", .{});
    }
    
    /// Record IPv6 configuration.
    /// Why: Track IPv6 address configuration operations.
    pub fn record_ipv6_configuration(self: *NetworkInterfaceStats) void {
        self.total_ipv6_configurations += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_ipv6_configurations > 0, "IPv6 configurations counter not incremented", .{});
    }
    
    /// Record creation error.
    /// Why: Track interface creation failures.
    pub fn record_creation_error(self: *NetworkInterfaceStats) void {
        self.total_creation_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_creation_errors > 0, "Creation errors counter not incremented", .{});
    }
    
    /// Record configuration error.
    /// Why: Track configuration operation failures.
    pub fn record_configuration_error(self: *NetworkInterfaceStats) void {
        self.total_configuration_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_configuration_errors > 0, "Configuration errors counter not incremented", .{});
    }
    
    /// Record deletion error.
    /// Why: Track interface deletion failures.
    pub fn record_deletion_error(self: *NetworkInterfaceStats) void {
        self.total_deletion_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_deletion_errors > 0, "Deletion errors counter not incremented", .{});
    }
    
    /// Reset active interface count.
    /// Why: Update active interface count when interfaces change.
    pub fn reset_active_interfaces(self: *NetworkInterfaceStats, count: u32) void {
        self.total_active_interfaces = count;
    }
    
    /// Get error rate (errors per operation).
    /// Why: Calculate error rate for monitoring.
    /// Returns: Error rate percentage (0.0 to 100.0).
    pub fn get_error_rate(self: *const NetworkInterfaceStats) f64 {
        const total_operations = self.total_interfaces_created + self.total_ipv4_configurations + self.total_ipv6_configurations + self.total_interfaces_deleted;
        if (total_operations == 0) {
            return 0.0;
        }
        
        const total_errors = self.total_creation_errors + self.total_configuration_errors + self.total_deletion_errors;
        const error_rate = (@as(f64, @floatFromInt(total_errors)) * 100.0) / @as(f64, @floatFromInt(total_operations));
        
        // Assert: Error rate must be valid (postcondition).
        Debug.kassert(error_rate >= 0.0, "Error rate negative", .{});
        Debug.kassert(error_rate <= 100.0, "Error rate exceeds 100", .{});
        
        return error_rate;
    }
    
    /// Print network interface statistics.
    /// Why: Display interface metrics for monitoring.
    pub fn print_stats(self: *const NetworkInterfaceStats) void {
        std.debug.print("\nNetwork Interface Statistics:\n", .{});
        std.debug.print("  Total Interfaces Created: {}\n", .{self.total_interfaces_created});
        std.debug.print("  Total Interfaces Deleted: {}\n", .{self.total_interfaces_deleted});
        std.debug.print("  Active Interfaces: {}\n", .{self.total_active_interfaces});
        std.debug.print("  Up Transitions: {}\n", .{self.total_up_transitions});
        std.debug.print("  Down Transitions: {}\n", .{self.total_down_transitions});
        std.debug.print("  IPv4 Configurations: {}\n", .{self.total_ipv4_configurations});
        std.debug.print("  IPv6 Configurations: {}\n", .{self.total_ipv6_configurations});
        std.debug.print("  Creation Errors: {}\n", .{self.total_creation_errors});
        std.debug.print("  Configuration Errors: {}\n", .{self.total_configuration_errors});
        std.debug.print("  Deletion Errors: {}\n", .{self.total_deletion_errors});
        
        // Calculate and display error rate.
        const error_rate = self.get_error_rate();
        std.debug.print("  Error Rate: {d:.2}%\n", .{error_rate});
    }
    
    /// Reset all statistics.
    /// Why: Clear counters for new measurement period.
    pub fn reset(self: *NetworkInterfaceStats) void {
        self.total_interfaces_created = 0;
        self.total_interfaces_deleted = 0;
        self.total_active_interfaces = 0;
        self.total_up_transitions = 0;
        self.total_down_transitions = 0;
        self.total_ipv4_configurations = 0;
        self.total_ipv6_configurations = 0;
        self.total_creation_errors = 0;
        self.total_configuration_errors = 0;
        self.total_deletion_errors = 0;
        
        // Assert: All counters must be zero (postcondition).
        Debug.kassert(self.total_interfaces_created == 0, "Interfaces created counter not reset", .{});
        Debug.kassert(self.total_interfaces_deleted == 0, "Interfaces deleted counter not reset", .{});
    }
};

// Test: Network interface statistics initialization.
test "network interface stats init" {
    const stats = NetworkInterfaceStats.init();
    
    // Assert: All counters must be zero.
    try std.testing.expect(stats.total_interfaces_created == 0);
    try std.testing.expect(stats.total_interfaces_deleted == 0);
    try std.testing.expect(stats.total_active_interfaces == 0);
    try std.testing.expect(stats.total_up_transitions == 0);
}

// Test: Network interface statistics recording.
test "network interface stats recording" {
    var stats = NetworkInterfaceStats.init();
    
    stats.record_interface_created();
    try std.testing.expect(stats.total_interfaces_created == 1);
    try std.testing.expect(stats.total_active_interfaces == 1);
    
    stats.record_up_transition();
    try std.testing.expect(stats.total_up_transitions == 1);
    
    stats.record_ipv4_configuration();
    try std.testing.expect(stats.total_ipv4_configurations == 1);
    
    stats.record_creation_error();
    try std.testing.expect(stats.total_creation_errors == 1);
}

// Test: Network interface statistics reset.
test "network interface stats reset" {
    var stats = NetworkInterfaceStats.init();
    
    stats.record_interface_created();
    stats.record_creation_error();
    stats.reset();
    
    // Assert: All counters must be zero after reset.
    try std.testing.expect(stats.total_interfaces_created == 0);
    try std.testing.expect(stats.total_creation_errors == 0);
}

// Test: Network interface statistics error rate calculation.
test "network interface stats error rate" {
    var stats = NetworkInterfaceStats.init();
    
    // No operations: error rate should be 0.
    try std.testing.expect(stats.get_error_rate() == 0.0);
    
    // Add operations and errors.
    stats.record_interface_created();
    stats.record_ipv4_configuration();
    stats.record_creation_error();
    stats.record_configuration_error();
    
    // Error rate: 2 errors / 2 operations = 100%
    const error_rate = stats.get_error_rate();
    try std.testing.expect(error_rate == 100.0);
}
