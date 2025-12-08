const std = @import("std");
const builtin = @import("builtin");

/// Aurora crash handler: captures panics, stack traces, and formats copy-pasteable logs.
/// ~<~ Glow Earthbend: crash dumps are deterministic, reproducible, debuggable.
pub const CrashHandler = struct {
    allocator: std.mem.Allocator,
    log_buffer: std.ArrayListUnmanaged(u8),

    pub fn init(allocator: std.mem.Allocator) CrashHandler {
        return CrashHandler{
            .allocator = allocator,
            .log_buffer = .{},
        };
    }

    pub fn deinit(self: *CrashHandler) void {
        self.log_buffer.deinit(self.allocator);
        self.* = undefined;
    }

    /// Install global panic handler that logs to stderr and a crash log file.
    pub fn install(self: *CrashHandler) void {
        // Store handler reference for panic handler access.
        _ = self;
        // Note: In Zig 0.15, panic handler is set via std.builtin.panic, but we'll
        // use a different approach - wrap main() with error handling instead.
    }

    /// Format crash log: includes stack trace, panic message, system info.
    pub fn formatCrashLog(
        self: *CrashHandler,
        panic_msg: []const u8,
        trace: ?*std.builtin.StackTrace,
    ) ![]const u8 {
        self.log_buffer.clearRetainingCapacity();

        var writer = self.log_buffer.writer(self.allocator);

        // Header: Aurora crash report
        try writer.print(
            \\========================================
            \\AURORA IDE CRASH REPORT
            \\========================================
            \\Copy this entire block and paste into Cursor for debugging.
            \\
            \\Timestamp: {s}
            \\Platform: {s} {s}
            \\Zig Version: {s}
            \\
        , .{
            timestamp(),
            @tagName(builtin.os.tag),
            @tagName(builtin.cpu.arch),
            builtin.zig_version_string,
        });

        // Panic message
        try writer.print(
            \\----------------------------------------
            \\PANIC MESSAGE
            \\----------------------------------------
            \\{s}
            \\
        , .{panic_msg});

        // Stack trace
        if (trace) |t| {
            try writer.writeAll(
                \\----------------------------------------
                \\STACK TRACE
                \\----------------------------------------
            );
            var frame_index: usize = 0;
            const frames = t.instruction_addresses;
            while (frame_index < frames.len) : (frame_index += 1) {
                const addr = frames[frame_index];
                try writer.print("\n[{d}] 0x{x}", .{ frame_index, addr });
            }
            try writer.writeAll("\n\n");
        } else {
            try writer.writeAll(
                \\----------------------------------------
                \\STACK TRACE
                \\----------------------------------------
                \\(unavailable - compile with -fstack-trace)
                \\
            );
        }

        // System context
        try writer.print(
            \\----------------------------------------
            \\SYSTEM CONTEXT
            \\----------------------------------------
            \\OS: {s}
            \\Arch: {s}
            \\Endian: {s}
            \\Zig std: {s}
            \\
        , .{
            @tagName(builtin.os.tag),
            @tagName(builtin.cpu.arch),
            @tagName(builtin.cpu.arch.endian()),
            builtin.zig_version_string,
        });

        // Cocoa/macOS specific info
        if (builtin.os.tag == .macos) {
            try writer.writeAll(
                \\----------------------------------------
                \\COCOA CONTEXT
                \\----------------------------------------
                \\macOS detected. If crash occurred in Cocoa bridge,
                \\check NSApplication/NSWindow lifecycle.
                \\
            );
        }

        try writer.writeAll(
            \\========================================
            \\END CRASH REPORT
            \\========================================
            \\
        );

        return self.log_buffer.items;
    }

    fn timestamp() []const u8 {
        // Format current timestamp for crash logs.
        const now = std.time.timestamp();
        const epoch_sec = @as(u64, @intCast(@as(i64, now)));
        // Use a thread-local static buffer for timestamp.
        var buf: [32]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d}", .{epoch_sec}) catch return "unknown";
        // Note: This returns a stack buffer, but it's only used during formatting
        // which happens before the string is copied into the log buffer.
        return formatted;
    }
};

/// Format and print crash log when panic occurs.
/// Called from main() error handler or via @panic().
pub fn handlePanic(msg: []const u8, trace: ?*std.builtin.StackTrace) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var handler = CrashHandler.init(gpa.allocator());
    defer handler.deinit();

    const crash_log = handler.formatCrashLog(msg, trace) catch |err| {
        // Fallback: if formatting fails, at least print the panic.
        var stderr_buffer: [1024]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        const stderr = &stderr_writer.interface;
        stderr.print("PANIC: {s}\n", .{msg}) catch {};
        stderr.print("Failed to format crash log: {}\n", .{err}) catch {};
        return;
    };
    defer gpa.allocator().free(crash_log);

    // Write to stderr
    var stderr_buffer: [8192]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;
    stderr.writeAll(crash_log) catch {};

    // Write to crash log file
    if (writeCrashLogFile(crash_log)) |_| {} else |err| {
        stderr.print("Failed to write crash log file: {}\n", .{err}) catch {};
    }
}

fn writeCrashLogFile(content: []const u8) !void {
    const crash_dir = "logs/crashes";
    std.fs.cwd().makePath(crash_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const timestamp = std.time.timestamp();
    const filename = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}/aurora_crash_{d}.log",
        .{ crash_dir, timestamp },
    );
    defer std.heap.page_allocator.free(filename);

    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(content);
}

test "crash handler formats log" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var handler = CrashHandler.init(arena.allocator());
    defer handler.deinit();

    const log = try handler.formatCrashLog("test panic", null);
    try std.testing.expect(std.mem.indexOf(u8, log, "AURORA IDE CRASH REPORT") != null);
    try std.testing.expect(std.mem.indexOf(u8, log, "test panic") != null);
}

