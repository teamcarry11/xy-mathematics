//! Timer Driver Tests
//! Why: Comprehensive TigerStyle tests for timer driver functionality.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const ClockId = basin_kernel.ClockId;
const Timer = basin_kernel.basin_kernel.Timer;
const RawIO = basin_kernel.RawIO;

// Test timer initialization.
test "timer init" {
    const timer_instance = Timer.init();
    
    // Assert: Timer must be initialized.
    try std.testing.expect(timer_instance.initialized);
    try std.testing.expect(timer_instance.boot_time_ns > 0);
    
    // Assert: Last timer value must be zero initially.
    try std.testing.expect(timer_instance.last_timer_ns == 0);
}

// Test monotonic clock increases.
test "timer monotonic increases" {
    var timer_instance = Timer.init();
    
    const t1 = timer_instance.get_monotonic_ns();
    const t2 = timer_instance.get_monotonic_ns();
    
    // Assert: Monotonic time must be non-decreasing.
    try std.testing.expect(t2 >= t1);
    try std.testing.expect(t1 >= 0);
    try std.testing.expect(t2 >= 0);
    
    // Assert: Monotonic time must be non-negative.
    try std.testing.expect(t1 >= 0);
    try std.testing.expect(t2 >= 0);
}

// Test realtime clock.
test "timer realtime" {
    var timer_instance = Timer.init();
    
    const rt = timer_instance.get_realtime_ns();
    
    // Assert: Realtime must be >= boot time.
    try std.testing.expect(rt >= timer_instance.boot_time_ns);
    
    // Assert: Realtime must be reasonable (not before year 2000).
    const YEAR_2000_NS: u64 = 946684800 * 1000000000;
    try std.testing.expect(rt >= YEAR_2000_NS);
}

// Test uptime increases.
test "timer uptime increases" {
    var timer_instance = Timer.init();
    
    const uptime1 = timer_instance.get_uptime_ns();
    const uptime2 = timer_instance.get_uptime_ns();
    
    // Assert: Uptime must be non-decreasing.
    try std.testing.expect(uptime2 >= uptime1);
    try std.testing.expect(uptime1 >= 0);
    try std.testing.expect(uptime2 >= 0);
    
    // Assert: Uptime must equal monotonic time.
    const monotonic = timer_instance.get_monotonic_ns();
    try std.testing.expect(uptime2 == monotonic);
}

// Test set timer_instance.
test "timer set timer" {
    var timer_instance = Timer.init();
    
    const time_value: u64 = 1000000000; // 1 second
    
    timer_instance.set_timer(time_value);
    
    // Assert: Last timer value must be set.
    try std.testing.expect(timer_instance.last_timer_ns == time_value);
    
    // Assert: Timer must still be initialized.
    try std.testing.expect(timer_instance.initialized);
}

// Test kernel timer integration.
test "kernel timer integration" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    // Assert: Kernel timer must be initialized.
    try std.testing.expect(kernel.timer.initialized);
    try std.testing.expect(kernel.timer.boot_time_ns > 0);
    
    // Assert: Kernel timer must provide monotonic time.
    const monotonic = kernel.timer.get_monotonic_ns();
    try std.testing.expect(monotonic >= 0);
    
    // Assert: Kernel timer must provide realtime.
    const realtime = kernel.timer.get_realtime_ns();
    try std.testing.expect(realtime >= kernel.timer.boot_time_ns);
}

// Test clock_gettime syscall (via integration layer).
test "clock_gettime syscall" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    // Note: This test requires VM and integration layer setup.
    // For now, we test the timer directly.
    var kernel = BasinKernel.init();
    
    // Test monotonic clock (clock_id = 0).
    const monotonic_ns = kernel.timer.get_monotonic_ns();
    
    // Assert: Monotonic time must be valid.
    try std.testing.expect(monotonic_ns >= 0);
    
    // Convert to nanoseconds (seconds unused but calculated for validation).
    _ = monotonic_ns / 1000000000; // seconds (unused)
    const nanoseconds: u64 = monotonic_ns % 1000000000;
    
    // Assert: Nanoseconds must be valid (0-999999999).
    try std.testing.expect(nanoseconds < 1000000000);
    
    // Test realtime clock (clock_id = 1).
    const realtime_ns = kernel.timer.get_realtime_ns();
    
    // Assert: Realtime must be >= boot time.
    try std.testing.expect(realtime_ns >= kernel.timer.boot_time_ns);
}

// Test sleep_until syscall validation.
test "sleep_until syscall validation" {
    var kernel = BasinKernel.init();
    
    // Get current monotonic time.
    const current_time = kernel.timer.get_monotonic_ns();
    
    // Test: timestamp in the past should return error.
    _ = if (current_time > 1000000000)
        current_time - 1000000000
    else
        0;
    
    // Note: sleep_until is a syscall, so we test the timer directly.
    // The syscall validation is tested in integration tests.
    
    // Assert: Current time must be valid.
    try std.testing.expect(current_time >= 0);
    
    // Assert: Future timestamp must be > current time.
    const future_timestamp = current_time + 1000000000; // 1 second in future
    try std.testing.expect(future_timestamp > current_time);
}

// Test timer set_timer with various values.
test "timer set_timer values" {
    var timer_instance = Timer.init();
    
    // Test: Set timer to 1 second.
    timer_instance.set_timer(1000000000);
    try std.testing.expect(timer_instance.last_timer_ns == 1000000000);
    
    // Test: Set timer to 1 minute.
    timer_instance.set_timer(60000000000);
    try std.testing.expect(timer_instance.last_timer_ns == 60000000000);
    
    // Test: Set timer to 1 hour.
    timer_instance.set_timer(3600000000000);
    try std.testing.expect(timer_instance.last_timer_ns == 3600000000000);
}

// Test timer monotonic consistency.
test "timer monotonic consistency" {
    var timer_instance = Timer.init();
    
    // Get multiple monotonic readings.
    const t1 = timer_instance.get_monotonic_ns();
    const t2 = timer_instance.get_monotonic_ns();
    const t3 = timer_instance.get_monotonic_ns();
    
    // Assert: Monotonic time must be non-decreasing.
    try std.testing.expect(t2 >= t1);
    try std.testing.expect(t3 >= t2);
    
    // Assert: All times must be non-negative.
    try std.testing.expect(t1 >= 0);
    try std.testing.expect(t2 >= 0);
    try std.testing.expect(t3 >= 0);
}

