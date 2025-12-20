//! AArch64 Platform Interface Tests
//! Why: Test AArch64 platform interface functions.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions.

const std = @import("std");
const testing = std.testing;
const platform = @import("src/kernel/platform_aarch64.zig");

test "platform call returns success" {
    const result = platform.platform_call(
        .console_putchar,
        71, // 'G'
        0,
        0,
        0,
    );
    try testing.expect(result.is_success());
    try testing.expect(result.error_code == 0);
}

test "platform call error code extraction" {
    const result = platform.platform_call(
        .console_putchar,
        0,
        0,
        0,
        0,
    );
    const err_code = result.get_error();
    try testing.expect(err_code == .success);
}

test "console putchar" {
    // Note: This is a stub implementation, so it should not crash.
    platform.console_putchar(71); // 'G'
}

test "console getchar" {
    // Note: This is a stub implementation, so it should not crash.
    const char = platform.console_getchar();
    // Stub returns -1 if no character available.
    _ = char;
}

test "set timer" {
    // Note: This is a stub implementation, so it should not crash.
    platform.set_timer(1000000); // 1ms in nanoseconds
}

test "shutdown" {
    // Note: This is a stub implementation, so it should not crash.
    platform.shutdown(0); // Shutdown
}

