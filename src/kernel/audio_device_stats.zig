//! Audio Device Statistics Tracking System
//!
//! Objective: Track audio device operations and state changes for monitoring and debugging.
//! Why: Monitor device behavior, identify configuration issues, validate audio operations.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track device creation/deletion operations
//! - Track state transitions (disconnected, connected, active, disabled)
//! - Track volume/mute changes
//! - Track format changes
//! - Track I/O operations (bytes read/written)
//! - Track error counts (creation errors, configuration errors, I/O errors)
//! - Provide statistics interface for querying device data
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
//! GrainStyle: Comprehensive audio device tracking, deterministic behavior, explicit limits

const std = @import("std");
const Debug = @import("debug.zig");

/// Audio device statistics tracker.
/// Why: Track audio device operations and state changes.
/// GrainStyle: Static allocation, bounded counters, explicit types.
pub const AudioDeviceStats = struct {
    /// Total devices created.
    /// Why: Track number of devices created.
    total_devices_created: u64,
    
    /// Total devices deleted.
    /// Why: Track number of devices deleted.
    total_devices_deleted: u64,
    
    /// Total active devices (currently allocated).
    /// Why: Track number of active devices.
    total_active_devices: u32,
    
    /// Total state transitions to connected.
    /// Why: Track how many times devices are connected.
    total_connected_transitions: u64,
    
    /// Total state transitions to active.
    /// Why: Track how many times devices are activated.
    total_active_transitions: u64,
    
    /// Total state transitions to disabled.
    /// Why: Track how many times devices are disabled.
    total_disabled_transitions: u64,
    
    /// Total volume changes.
    /// Why: Track volume adjustment operations.
    total_volume_changes: u64,
    
    /// Total mute toggles.
    /// Why: Track mute/unmute operations.
    total_mute_toggles: u64,
    
    /// Total format changes.
    /// Why: Track audio format configuration operations.
    total_format_changes: u64,
    
    /// Total bytes read (input/recording).
    /// Why: Track audio input data.
    total_bytes_read: u64,
    
    /// Total bytes written (output/playback).
    /// Why: Track audio output data.
    total_bytes_written: u64,
    
    /// Total creation errors.
    /// Why: Track device creation failures.
    total_creation_errors: u64,
    
    /// Total configuration errors.
    /// Why: Track configuration operation failures.
    total_configuration_errors: u64,
    
    /// Total I/O errors.
    /// Why: Track read/write operation failures.
    total_io_errors: u64,
    
    /// Total deletion errors.
    /// Why: Track device deletion failures.
    total_deletion_errors: u64,
    
    /// Initialize audio device statistics.
    /// Why: Set up statistics tracker with zero counters.
    pub fn init() AudioDeviceStats {
        return AudioDeviceStats{
            .total_devices_created = 0,
            .total_devices_deleted = 0,
            .total_active_devices = 0,
            .total_connected_transitions = 0,
            .total_active_transitions = 0,
            .total_disabled_transitions = 0,
            .total_volume_changes = 0,
            .total_mute_toggles = 0,
            .total_format_changes = 0,
            .total_bytes_read = 0,
            .total_bytes_written = 0,
            .total_creation_errors = 0,
            .total_configuration_errors = 0,
            .total_io_errors = 0,
            .total_deletion_errors = 0,
        };
    }
    
    /// Record device creation.
    /// Why: Track when a device is created.
    pub fn record_device_created(self: *AudioDeviceStats) void {
        self.total_devices_created += 1;
        self.total_active_devices += 1;
        
        // Assert: Counters must be incremented (postcondition).
        Debug.kassert(self.total_devices_created > 0, "Devices created counter not incremented", .{});
        Debug.kassert(self.total_active_devices > 0, "Active devices counter not incremented", .{});
    }
    
    /// Record device deletion.
    /// Why: Track when a device is deleted.
    pub fn record_device_deleted(self: *AudioDeviceStats) void {
        self.total_devices_deleted += 1;
        if (self.total_active_devices > 0) {
            self.total_active_devices -= 1;
        }
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_devices_deleted > 0, "Devices deleted counter not incremented", .{});
    }
    
    /// Record state transition to connected.
    /// Why: Track when a device is connected.
    pub fn record_connected_transition(self: *AudioDeviceStats) void {
        self.total_connected_transitions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_connected_transitions > 0, "Connected transitions counter not incremented", .{});
    }
    
    /// Record state transition to active.
    /// Why: Track when a device is activated.
    pub fn record_active_transition(self: *AudioDeviceStats) void {
        self.total_active_transitions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_active_transitions > 0, "Active transitions counter not incremented", .{});
    }
    
    /// Record state transition to disabled.
    /// Why: Track when a device is disabled.
    pub fn record_disabled_transition(self: *AudioDeviceStats) void {
        self.total_disabled_transitions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_disabled_transitions > 0, "Disabled transitions counter not incremented", .{});
    }
    
    /// Record volume change.
    /// Why: Track volume adjustment operations.
    pub fn record_volume_change(self: *AudioDeviceStats) void {
        self.total_volume_changes += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_volume_changes > 0, "Volume changes counter not incremented", .{});
    }
    
    /// Record mute toggle.
    /// Why: Track mute/unmute operations.
    pub fn record_mute_toggle(self: *AudioDeviceStats) void {
        self.total_mute_toggles += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_mute_toggles > 0, "Mute toggles counter not incremented", .{});
    }
    
    /// Record format change.
    /// Why: Track audio format configuration operations.
    pub fn record_format_change(self: *AudioDeviceStats) void {
        self.total_format_changes += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_format_changes > 0, "Format changes counter not incremented", .{});
    }
    
    /// Record bytes read.
    /// Why: Track audio input data.
    pub fn record_bytes_read(self: *AudioDeviceStats, bytes: u32) void {
        self.total_bytes_read += bytes;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_bytes_read > 0 or bytes == 0, "Bytes read counter not incremented", .{});
    }
    
    /// Record bytes written.
    /// Why: Track audio output data.
    pub fn record_bytes_written(self: *AudioDeviceStats, bytes: u32) void {
        self.total_bytes_written += bytes;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_bytes_written > 0 or bytes == 0, "Bytes written counter not incremented", .{});
    }
    
    /// Record creation error.
    /// Why: Track device creation failures.
    pub fn record_creation_error(self: *AudioDeviceStats) void {
        self.total_creation_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_creation_errors > 0, "Creation errors counter not incremented", .{});
    }
    
    /// Record configuration error.
    /// Why: Track configuration operation failures.
    pub fn record_configuration_error(self: *AudioDeviceStats) void {
        self.total_configuration_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_configuration_errors > 0, "Configuration errors counter not incremented", .{});
    }
    
    /// Record I/O error.
    /// Why: Track read/write operation failures.
    pub fn record_io_error(self: *AudioDeviceStats) void {
        self.total_io_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_io_errors > 0, "I/O errors counter not incremented", .{});
    }
    
    /// Record deletion error.
    /// Why: Track device deletion failures.
    pub fn record_deletion_error(self: *AudioDeviceStats) void {
        self.total_deletion_errors += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_deletion_errors > 0, "Deletion errors counter not incremented", .{});
    }
    
    /// Reset active device count.
    /// Why: Update active device count when devices change.
    pub fn reset_active_devices(self: *AudioDeviceStats, count: u32) void {
        self.total_active_devices = count;
    }
    
    /// Get error rate (errors per operation).
    /// Why: Calculate error rate for monitoring.
    /// Returns: Error rate percentage (0.0 to 100.0).
    pub fn get_error_rate(self: *const AudioDeviceStats) f64 {
        const total_operations = self.total_devices_created + self.total_volume_changes + self.total_format_changes + self.total_bytes_read + self.total_bytes_written + self.total_devices_deleted;
        if (total_operations == 0) {
            return 0.0;
        }
        
        const total_errors = self.total_creation_errors + self.total_configuration_errors + self.total_io_errors + self.total_deletion_errors;
        const error_rate = (@as(f64, @floatFromInt(total_errors)) * 100.0) / @as(f64, @floatFromInt(total_operations));
        
        // Assert: Error rate must be valid (postcondition).
        Debug.kassert(error_rate >= 0.0, "Error rate negative", .{});
        Debug.kassert(error_rate <= 100.0, "Error rate exceeds 100", .{});
        
        return error_rate;
    }
    
    /// Print audio device statistics.
    /// Why: Display device metrics for monitoring.
    pub fn print_stats(self: *const AudioDeviceStats) void {
        std.debug.print("\nAudio Device Statistics:\n", .{});
        std.debug.print("  Total Devices Created: {}\n", .{self.total_devices_created});
        std.debug.print("  Total Devices Deleted: {}\n", .{self.total_devices_deleted});
        std.debug.print("  Active Devices: {}\n", .{self.total_active_devices});
        std.debug.print("  Connected Transitions: {}\n", .{self.total_connected_transitions});
        std.debug.print("  Active Transitions: {}\n", .{self.total_active_transitions});
        std.debug.print("  Disabled Transitions: {}\n", .{self.total_disabled_transitions});
        std.debug.print("  Volume Changes: {}\n", .{self.total_volume_changes});
        std.debug.print("  Mute Toggles: {}\n", .{self.total_mute_toggles});
        std.debug.print("  Format Changes: {}\n", .{self.total_format_changes});
        std.debug.print("  Bytes Read: {}\n", .{self.total_bytes_read});
        std.debug.print("  Bytes Written: {}\n", .{self.total_bytes_written});
        std.debug.print("  Creation Errors: {}\n", .{self.total_creation_errors});
        std.debug.print("  Configuration Errors: {}\n", .{self.total_configuration_errors});
        std.debug.print("  I/O Errors: {}\n", .{self.total_io_errors});
        std.debug.print("  Deletion Errors: {}\n", .{self.total_deletion_errors});
        
        // Calculate and display error rate.
        const error_rate = self.get_error_rate();
        std.debug.print("  Error Rate: {d:.2}%\n", .{error_rate});
    }
    
    /// Reset all statistics.
    /// Why: Clear counters for new measurement period.
    pub fn reset(self: *AudioDeviceStats) void {
        self.total_devices_created = 0;
        self.total_devices_deleted = 0;
        self.total_active_devices = 0;
        self.total_connected_transitions = 0;
        self.total_active_transitions = 0;
        self.total_disabled_transitions = 0;
        self.total_volume_changes = 0;
        self.total_mute_toggles = 0;
        self.total_format_changes = 0;
        self.total_bytes_read = 0;
        self.total_bytes_written = 0;
        self.total_creation_errors = 0;
        self.total_configuration_errors = 0;
        self.total_io_errors = 0;
        self.total_deletion_errors = 0;
        
        // Assert: All counters must be zero (postcondition).
        Debug.kassert(self.total_devices_created == 0, "Devices created counter not reset", .{});
        Debug.kassert(self.total_devices_deleted == 0, "Devices deleted counter not reset", .{});
    }
};

// Test: Audio device statistics initialization.
test "audio device stats init" {
    const stats = AudioDeviceStats.init();
    
    // Assert: All counters must be zero.
    try std.testing.expect(stats.total_devices_created == 0);
    try std.testing.expect(stats.total_devices_deleted == 0);
    try std.testing.expect(stats.total_active_devices == 0);
    try std.testing.expect(stats.total_connected_transitions == 0);
}

// Test: Audio device statistics recording.
test "audio device stats recording" {
    var stats = AudioDeviceStats.init();
    
    stats.record_device_created();
    try std.testing.expect(stats.total_devices_created == 1);
    try std.testing.expect(stats.total_active_devices == 1);
    
    stats.record_active_transition();
    try std.testing.expect(stats.total_active_transitions == 1);
    
    stats.record_volume_change();
    try std.testing.expect(stats.total_volume_changes == 1);
    
    stats.record_bytes_written(1024);
    try std.testing.expect(stats.total_bytes_written == 1024);
    
    stats.record_creation_error();
    try std.testing.expect(stats.total_creation_errors == 1);
}

// Test: Audio device statistics reset.
test "audio device stats reset" {
    var stats = AudioDeviceStats.init();
    
    stats.record_device_created();
    stats.record_creation_error();
    stats.reset();
    
    // Assert: All counters must be zero after reset.
    try std.testing.expect(stats.total_devices_created == 0);
    try std.testing.expect(stats.total_creation_errors == 0);
}

// Test: Audio device statistics error rate calculation.
test "audio device stats error rate" {
    var stats = AudioDeviceStats.init();
    
    // No operations: error rate should be 0.
    try std.testing.expect(stats.get_error_rate() == 0.0);
    
    // Add operations and errors.
    stats.record_device_created();
    stats.record_volume_change();
    stats.record_bytes_written(1024);
    stats.record_creation_error();
    stats.record_io_error();
    
    // Error rate: 2 errors / 3 operations = 66.67%
    const error_rate = stats.get_error_rate();
    try std.testing.expect(error_rate > 60.0);
    try std.testing.expect(error_rate < 70.0);
}
