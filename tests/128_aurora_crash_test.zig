//! Tests for Aurora Crash Handler module.
//!
//! Why: Verify crash handler functionality (panic capture, stack traces,
//! crash log formatting).
//! Architecture: Comprehensive test coverage for error handling and crash reporting.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-180551-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const CrashHandler = @import("aurora_crash").CrashHandler;

test "crash handler initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    // Assert: Handler initialized
    std.debug.assert(handler.allocator.ptr != null);
    std.debug.assert(handler.log_buffer.items.len == 0);
}

test "crash handler deinitialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    handler.deinit();
    
    // Assert: Handler deinitialized (no crash)
}

test "crash handler install" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    // Assert: Install does not crash
    handler.install();
}

test "crash handler format log without trace" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log = try handler.formatCrashLog("test panic message", null);
    
    // Assert: Log contains expected sections
    std.debug.assert(std.mem.indexOf(u8, log, "AURORA IDE CRASH REPORT") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "PANIC MESSAGE") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "test panic message") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "STACK TRACE") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "SYSTEM CONTEXT") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "END CRASH REPORT") != null);
}

test "crash handler format log with trace" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    // Create a mock stack trace
    var trace: std.builtin.StackTrace = undefined;
    trace.instruction_addresses = [_]usize{ 0x1000, 0x2000, 0x3000 };
    trace.index = 3;
    
    const log = try handler.formatCrashLog("test panic with trace", &trace);
    
    // Assert: Log contains expected sections
    std.debug.assert(std.mem.indexOf(u8, log, "AURORA IDE CRASH REPORT") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "test panic with trace") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "STACK TRACE") != null);
}

test "crash handler format log empty message" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log = try handler.formatCrashLog("", null);
    
    // Assert: Log contains header even with empty message
    std.debug.assert(std.mem.indexOf(u8, log, "AURORA IDE CRASH REPORT") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "PANIC MESSAGE") != null);
}

test "crash handler format log long message" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const long_message = "A" ** 1000;
    const log = try handler.formatCrashLog(long_message, null);
    
    // Assert: Log contains long message
    std.debug.assert(std.mem.indexOf(u8, log, long_message) != null);
    std.debug.assert(std.mem.indexOf(u8, log, "AURORA IDE CRASH REPORT") != null);
}

test "crash handler format log multiple calls" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log1 = try handler.formatCrashLog("first panic", null);
    const log2 = try handler.formatCrashLog("second panic", null);
    
    // Assert: Both logs formatted correctly
    std.debug.assert(std.mem.indexOf(u8, log1, "first panic") != null);
    std.debug.assert(std.mem.indexOf(u8, log2, "second panic") != null);
    std.debug.assert(std.mem.indexOf(u8, log1, "AURORA IDE CRASH REPORT") != null);
    std.debug.assert(std.mem.indexOf(u8, log2, "AURORA IDE CRASH REPORT") != null);
}

test "crash handler format log contains timestamp" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log = try handler.formatCrashLog("test panic", null);
    
    // Assert: Log contains timestamp section
    std.debug.assert(std.mem.indexOf(u8, log, "Timestamp:") != null);
}

test "crash handler format log contains platform info" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log = try handler.formatCrashLog("test panic", null);
    
    // Assert: Log contains platform information
    std.debug.assert(std.mem.indexOf(u8, log, "Platform:") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "Zig Version:") != null);
}

test "crash handler format log contains system context" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log = try handler.formatCrashLog("test panic", null);
    
    // Assert: Log contains system context section
    std.debug.assert(std.mem.indexOf(u8, log, "SYSTEM CONTEXT") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "OS:") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "Arch:") != null);
}

test "crash handler format log stack trace unavailable" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log = try handler.formatCrashLog("test panic", null);
    
    // Assert: Log indicates stack trace unavailable
    std.debug.assert(std.mem.indexOf(u8, log, "STACK TRACE") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "unavailable") != null);
}

test "crash handler format log stack trace available" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    var trace: std.builtin.StackTrace = undefined;
    trace.instruction_addresses = [_]usize{ 0x1000 };
    trace.index = 1;
    
    const log = try handler.formatCrashLog("test panic", &trace);
    
    // Assert: Log contains stack trace addresses
    std.debug.assert(std.mem.indexOf(u8, log, "STACK TRACE") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "0x") != null);
}

test "crash handler format log multiple stack frames" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    var trace: std.builtin.StackTrace = undefined;
    trace.instruction_addresses = [_]usize{ 0x1000, 0x2000, 0x3000, 0x4000 };
    trace.index = 4;
    
    const log = try handler.formatCrashLog("test panic", &trace);
    
    // Assert: Log contains multiple frame addresses
    std.debug.assert(std.mem.indexOf(u8, log, "0x1000") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "0x2000") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "0x3000") != null);
    std.debug.assert(std.mem.indexOf(u8, log, "0x4000") != null);
}

test "crash handler format log cocoa context on macos" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log = try handler.formatCrashLog("test panic", null);
    
    // Assert: Log may contain Cocoa context (platform-dependent)
    // On macOS, should contain Cocoa context section
    const builtin = @import("builtin");
    if (builtin.os.tag == .macos) {
        std.debug.assert(std.mem.indexOf(u8, log, "COCOA CONTEXT") != null);
    }
}

test "crash handler format log structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log = try handler.formatCrashLog("test panic", null);
    
    // Assert: Log has proper structure (starts and ends with separators)
    std.debug.assert(std.mem.startsWith(u8, log, "========================================"));
    std.debug.assert(std.mem.endsWith(u8, log, "========================================\n"));
}

test "crash handler format log sections order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const log = try handler.formatCrashLog("test panic", null);
    
    // Assert: Sections appear in correct order
    const report_pos = std.mem.indexOf(u8, log, "AURORA IDE CRASH REPORT").?;
    const panic_pos = std.mem.indexOf(u8, log, "PANIC MESSAGE").?;
    const trace_pos = std.mem.indexOf(u8, log, "STACK TRACE").?;
    const context_pos = std.mem.indexOf(u8, log, "SYSTEM CONTEXT").?;
    const end_pos = std.mem.indexOf(u8, log, "END CRASH REPORT").?;
    
    std.debug.assert(report_pos < panic_pos);
    std.debug.assert(panic_pos < trace_pos);
    std.debug.assert(trace_pos < context_pos);
    std.debug.assert(context_pos < end_pos);
}

test "crash handler log buffer reuse" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    // Format multiple logs
    _ = try handler.formatCrashLog("first", null);
    _ = try handler.formatCrashLog("second", null);
    _ = try handler.formatCrashLog("third", null);
    
    // Assert: Handler still functional after multiple uses
    const log = try handler.formatCrashLog("fourth", null);
    std.debug.assert(std.mem.indexOf(u8, log, "fourth") != null);
}

test "crash handler format log special characters" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const special_msg = "Panic: null pointer at 0x0\nLine 42: assertion failed";
    const log = try handler.formatCrashLog(special_msg, null);
    
    // Assert: Special characters handled correctly
    std.debug.assert(std.mem.indexOf(u8, log, special_msg) != null);
    std.debug.assert(std.mem.indexOf(u8, log, "AURORA IDE CRASH REPORT") != null);
}

test "crash handler format log unicode characters" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    const unicode_msg = "Panic: 错误发生在行 42";
    const log = try handler.formatCrashLog(unicode_msg, null);
    
    // Assert: Unicode characters handled correctly
    std.debug.assert(std.mem.indexOf(u8, log, unicode_msg) != null);
}

test "crash handler bounds checking" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();
    
    // Assert: Handler can format logs without exceeding bounds
    const log = try handler.formatCrashLog("test", null);
    std.debug.assert(log.len > 0);
    std.debug.assert(log.len < 100_000); // Reasonable upper bound
}
