//! Grain Basin Timer Driver
//! Why: Provide monotonic clock and time-based syscalls for kernel.
//! Grain Style: Explicit types (u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Timer driver for Grain Basin kernel.
/// Why: Track boot time, provide monotonic clock, enable time-based syscalls.
/// Grain Style: Static allocation, explicit state tracking.
pub const Timer = struct {
    /// Boot time (nanoseconds since epoch, or 0 if not initialized).
    /// Why: Track when kernel booted for uptime calculation.
    boot_time_ns: u64,
    
    /// Last timer value (nanoseconds since boot, or 0 if not set).
    /// Why: Track last SBI timer value for monotonic clock.
    last_timer_ns: u64,
    
    /// Whether timer is initialized.
    /// Why: Track initialization state for safety.
    initialized: bool,
    
    /// Initialize timer driver.
    /// Why: Set boot time and initialize timer state.
    /// Contract: Must be called once at kernel boot.
    pub fn init() Timer {
        // Get current time (nanoseconds since epoch).
        // Note: In VM, we use host system time. On real hardware, use SBI timer.
        const now_ns = get_host_time_ns();
        
        return Timer{
            .boot_time_ns = now_ns,
            .last_timer_ns = 0,
            .initialized = true,
        };
    }
    
    /// Get monotonic clock time (nanoseconds since boot).
    /// Why: Provide monotonic clock for clock_gettime syscall.
    /// Contract: Timer must be initialized.
    pub fn get_monotonic_ns(self: *const Timer) u64 {
        // Assert: Timer must be initialized.
        Debug.kassert(self.initialized, "Timer not initialized", .{});
        
        // Get current time (nanoseconds since epoch).
        const now_ns = get_host_time_ns();
        
        // Calculate monotonic time (nanoseconds since boot).
        const monotonic_ns = if (now_ns >= self.boot_time_ns)
            now_ns - self.boot_time_ns
        else
            0; // Handle clock rollback (shouldn't happen, but safe)
        
        // Assert: Monotonic time must be non-negative.
        Debug.kassert(monotonic_ns >= 0, "Monotonic time negative", .{});
        
        return monotonic_ns;
    }
    
    /// Get realtime clock time (nanoseconds since epoch).
    /// Why: Provide realtime clock for clock_gettime syscall.
    /// Contract: Timer must be initialized.
    pub fn get_realtime_ns(self: *const Timer) u64 {
        // Assert: Timer must be initialized.
        Debug.kassert(self.initialized, "Timer not initialized", .{});
        
        // Get current time (nanoseconds since epoch).
        const now_ns = get_host_time_ns();
        
        // Assert: Realtime must be >= boot time.
        Debug.kassert(now_ns >= self.boot_time_ns, "Realtime < boot time", .{});
        
        return now_ns;
    }
    
    /// Get uptime (nanoseconds since boot).
    /// Why: Provide uptime for sysinfo syscall.
    /// Contract: Timer must be initialized.
    pub fn get_uptime_ns(self: *const Timer) u64 {
        // Assert: Timer must be initialized.
        Debug.kassert(self.initialized, "Timer not initialized", .{});
        
        return self.get_monotonic_ns();
    }
    
    /// Set SBI timer (for timer interrupts).
    /// Why: Set timer interrupt for sleep_until and scheduling.
    /// Contract: Timer must be initialized, time_value must be valid.
    /// Note: In VM, this is handled by VM's handle_sbi_call. On real hardware, use SBI.
    pub fn set_timer(self: *Timer, time_value: u64) void {
        // Assert: Timer must be initialized.
        Debug.kassert(self.initialized, "Timer not initialized", .{});
        
        // Assert: Time value must be reasonable (not too far in future).
        // Max 1 year in future (nanoseconds).
        const MAX_FUTURE_NS: u64 = 365 * 24 * 60 * 60 * 1000000000;
        Debug.kassert(time_value <= MAX_FUTURE_NS, "Time value too large", .{});
        
        // Update last timer value.
        self.last_timer_ns = time_value;
        
        // Assert: Last timer value must be set.
        Debug.kassert(self.last_timer_ns == time_value, "Timer value not set", .{});
    }
    
    /// Get host system time (nanoseconds since epoch).
    /// Why: Get current time from host system (VM) or hardware (real).
    /// Note: In VM, uses std.time. On real hardware, would use SBI timer.
    fn get_host_time_ns() u64 {
        // Get current time (nanoseconds since epoch).
        // Note: std.time.timestamp() returns seconds, we need nanoseconds.
        const now_sec = std.time.timestamp();
        const now_ns = @as(u64, @intCast(now_sec)) * 1000000000;
        
        // Assert: Time must be reasonable (not before year 2000).
        const YEAR_2000_NS: u64 = 946684800 * 1000000000; // Jan 1, 2000
        Debug.kassert(now_ns >= YEAR_2000_NS, "Time before year 2000", .{});
        
        return now_ns;
    }
};

// Test timer initialization.
test "timer init" {
    const timer = Timer.init();
    
    // Assert: Timer must be initialized.
    try std.testing.expect(timer.initialized);
    try std.testing.expect(timer.boot_time_ns > 0);
}

// Test monotonic clock.
test "timer monotonic" {
    var timer = Timer.init();
    
    const t1 = timer.get_monotonic_ns();
    const t2 = timer.get_monotonic_ns();
    
    // Assert: Monotonic time must be non-decreasing.
    try std.testing.expect(t2 >= t1);
    try std.testing.expect(t1 >= 0);
    try std.testing.expect(t2 >= 0);
}

// Test realtime clock.
test "timer realtime" {
    var timer = Timer.init();
    
    const rt = timer.get_realtime_ns();
    
    // Assert: Realtime must be >= boot time.
    try std.testing.expect(rt >= timer.boot_time_ns);
}

// Test uptime.
test "timer uptime" {
    var timer = Timer.init();
    
    const uptime1 = timer.get_uptime_ns();
    const uptime2 = timer.get_uptime_ns();
    
    // Assert: Uptime must be non-decreasing.
    try std.testing.expect(uptime2 >= uptime1);
    try std.testing.expect(uptime1 >= 0);
    try std.testing.expect(uptime2 >= 0);
}

// Test set timer.
test "timer set timer" {
    var timer = Timer.init();
    
    const time_value: u64 = 1000000000; // 1 second
    
    timer.set_timer(time_value);
    
    // Assert: Last timer value must be set.
    try std.testing.expect(timer.last_timer_ns == time_value);
}

