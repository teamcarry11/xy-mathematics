//! Tests for kernel log reading syscall.
//! Why: Verify kernel can provide log entries to userspace for Grain OS integration.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");

test "kernel log reading syscall" {
    var kernel = basin_kernel.BasinKernel.init();
    defer kernel.deinit();
    
    // Add some test log entries to the buffer.
    const KernelLogLevel = @import("kernel_log_buffer").KernelLogLevel;
    kernel.log_buffer.add_entry(
        KernelLogLevel.info,
        "test",
        "Test message 1",
    );
    kernel.log_buffer.add_entry(
        KernelLogLevel.warn,
        "test",
        "Test message 2",
    );
    
    // Test read_kernel_log with valid buffer.
    const buffer_ptr: u64 = 0x1000; // Valid VM memory address
    const buffer_len: u64 = 1024; // Enough for multiple KernelLogEntry structures
    const max_entries: u64 = 16;
    
    const result = kernel.syscall_read_kernel_log(buffer_ptr, buffer_len, max_entries, 0);
    
    // Should succeed and return number of entries.
    try testing.expect(result == .success);
    try testing.expect(result.success >= 2); // At least 2 entries
}

test "kernel log reading with invalid buffer" {
    var kernel = basin_kernel.BasinKernel.init();
    defer kernel.deinit();
    
    // Test with null buffer pointer.
    const result1 = kernel.syscall_read_kernel_log(0, 1024, 16, 0);
    try testing.expect(result1 == .err);
    try testing.expect(result1.err == basin_kernel.BasinError.invalid_argument);
    
    // Test with buffer too small.
    const buffer_ptr: u64 = 0x1000;
    const KernelLogEntry = @import("kernel_log_buffer").KernelLogEntry;
    const KERNEL_LOG_ENTRY_SIZE: u64 = @sizeOf(KernelLogEntry);
    const result2 = kernel.syscall_read_kernel_log(buffer_ptr, KERNEL_LOG_ENTRY_SIZE - 1, 16, 0);
    try testing.expect(result2 == .err);
    try testing.expect(result2.err == basin_kernel.BasinError.invalid_argument);
}

test "kernel log entry structure layout" {
    // Verify KernelLogEntry structure size and layout.
    const KernelLogEntry = @import("kernel_log_buffer").KernelLogEntry;
    const entry = KernelLogEntry.init();
    
    // Structure should be: timestamp(8) + level(1) + padding(7) + source(32) + message(256) = 304 bytes
    // With alignment: timestamp(8) + level(1) + padding(7) = 16, source(32) = 32, message(256) = 256
    // Total: 304 bytes
    
    try testing.expect(@sizeOf(KernelLogEntry) == 304);
    try testing.expect(entry.timestamp == 0);
    try testing.expect(entry.level == 0);
    try testing.expect(entry.source[0] == 0);
    try testing.expect(entry.message[0] == 0);
}

