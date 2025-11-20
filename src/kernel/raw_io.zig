// QEMU RISC-V virt machine UART0 address
const UART0_BASE: usize = 0x10000000;

pub fn write(msg: []const u8) void {
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
    const uart = @as(*volatile u8, @ptrFromInt(UART0_BASE));
    uart.* = c;
}
