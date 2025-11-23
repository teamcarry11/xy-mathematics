// QEMU RISC-V virt machine UART0 address
const UART0_BASE: usize = 0x10000000;

// Global flag to disable RawIO in test mode.
// Why: In tests, hardware addresses don't exist, so we need to avoid writing to them.
// Grain Style: Explicit flag, no magic numbers.
var raw_io_enabled: bool = true;

/// Disable RawIO (for testing).
/// Why: Allow tests to disable hardware access to avoid SIGILL.
pub fn disable() void {
    raw_io_enabled = false;
}

/// Enable RawIO (for production).
/// Why: Allow re-enabling hardware access after tests.
pub fn enable() void {
    raw_io_enabled = true;
}

pub fn write(msg: []const u8) void {
    // Why: In test mode, skip hardware access to avoid SIGILL.
    if (!raw_io_enabled) {
        return; // No-op when disabled
    }
    
    const uart = @as(*volatile u8, @ptrFromInt(UART0_BASE));
    for (msg) |c| {
        // Wait for THR (Transmitter Holding Register) to be empty?
        // For QEMU/Simple UART we can usually just write.
        // In a real driver we'd check LSR (Line Status Register) bit 5.
        // const lsr = @as(*volatile u8, @ptrFromInt(UART0_BASE + 5));
        // while ((lsr.* & 0x20) == 0) {}
        
        uart.* = c;
    }
}

pub fn write_byte(c: u8) void {
    // Why: In test mode, skip hardware access to avoid SIGILL.
    if (!raw_io_enabled) {
        return; // No-op when disabled
    }
    
    const uart = @as(*volatile u8, @ptrFromInt(UART0_BASE));
    uart.* = c;
}
