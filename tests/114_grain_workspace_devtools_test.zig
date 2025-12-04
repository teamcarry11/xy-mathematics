//! Tests for Grain DevTools application.
//!
//! Why: Verify code formatting, linting, debugging, profiling, and testing.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-131701-pst: Active implementation

const std = @import("std");
const testing = std.testing;
const DevToolsApp = @import("../src/grain_workspace/devtools/app.zig").DevToolsApp;
const Language = @import("../src/grain_workspace/devtools/app.zig").Language;
const LinterSeverity = @import("../src/grain_workspace/devtools/app.zig").LinterSeverity;

test "devtools app initialization" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);

    try testing.expect(app.breakpoints_len == 0);
    try testing.expect(app.watchpoints_len == 0);
    try testing.expect(app.linter_messages_len == 0);
    try testing.expect(app.test_results_len == 0);
    try testing.expect(app.profiler_samples_len == 0);
}

test "add breakpoint" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);
    const bp_id = app.add_breakpoint("test.zig", 42);

    try testing.expect(bp_id != null);
    try testing.expect(bp_id.? == 1);
    try testing.expect(app.breakpoints_len == 1);
    try testing.expect(app.breakpoints[0] != null);
    try testing.expect(app.breakpoints[0].?.line_number == 42);
    try testing.expect(app.breakpoints[0].?.enabled == true);
}

test "remove breakpoint" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);
    const bp_id = app.add_breakpoint("test.zig", 42);
    try testing.expect(bp_id != null);
    try testing.expect(app.breakpoints_len == 1);

    const result = app.remove_breakpoint(bp_id.?);
    try testing.expect(result == true);
    try testing.expect(app.breakpoints_len == 0);
}

test "add watchpoint" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);
    const wp_id = app.add_watchpoint("x", "x > 10");

    try testing.expect(wp_id != null);
    try testing.expect(wp_id.? == 1);
    try testing.expect(app.watchpoints_len == 1);
    try testing.expect(app.watchpoints[0] != null);
    try testing.expect(std.mem.eql(u8, app.watchpoints[0].?.variable_name[0..app.watchpoints[0].?.variable_name_len], "x"));
    try testing.expect(app.watchpoints[0].?.enabled == true);
}

test "add linter message" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);
    const result = app.add_linter_message("test.zig", 10, 5, .warning, "Unused variable");

    try testing.expect(result == true);
    try testing.expect(app.linter_messages_len == 1);
    try testing.expect(app.linter_messages[0] != null);
    try testing.expect(app.linter_messages[0].?.line_number == 10);
    try testing.expect(app.linter_messages[0].?.severity == .warning);
}

test "add test result" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);
    const result = app.add_test_result("test_function", "test.zig", true, 100, "");

    try testing.expect(result == true);
    try testing.expect(app.test_results_len == 1);
    try testing.expect(app.test_results[0] != null);
    try testing.expect(app.test_results[0].?.passed == true);
    try testing.expect(app.test_results[0].?.execution_time_ms == 100);
}

test "add profiler sample" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);
    const result = app.add_profiler_sample("my_function", "test.zig", 50, 1000, 1024, 5);

    try testing.expect(result == true);
    try testing.expect(app.profiler_samples_len == 1);
    try testing.expect(app.profiler_samples[0] != null);
    try testing.expect(app.profiler_samples[0].?.execution_time_us == 1000);
    try testing.expect(app.profiler_samples[0].?.memory_used_bytes == 1024);
    try testing.expect(app.profiler_samples[0].?.call_count == 5);
}

test "clear breakpoints" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);
    _ = app.add_breakpoint("test.zig", 42);
    _ = app.add_breakpoint("test2.zig", 10);
    try testing.expect(app.breakpoints_len == 2);

    app.clear_breakpoints();
    try testing.expect(app.breakpoints_len == 0);
}

test "clear linter messages" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);
    _ = app.add_linter_message("test.zig", 10, 5, .warning, "Message 1");
    _ = app.add_linter_message("test.zig", 20, 3, .error, "Message 2");
    try testing.expect(app.linter_messages_len == 2);

    app.clear_linter_messages();
    try testing.expect(app.linter_messages_len == 0);
}

test "multiple breakpoints" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);
    _ = app.add_breakpoint("test.zig", 10);
    _ = app.add_breakpoint("test.zig", 20);
    _ = app.add_breakpoint("test.zig", 30);

    try testing.expect(app.breakpoints_len == 3);
    try testing.expect(app.breakpoints[0] != null);
    try testing.expect(app.breakpoints[1] != null);
    try testing.expect(app.breakpoints[2] != null);
}

test "format code" {
    const allocator = testing.allocator;

    var app = DevToolsApp.init(allocator);

    var formatted: [100]u8 = undefined;
    var formatted_len: u32 = 0;
    const result = app.format_code("test.zig", .zig, &formatted, &formatted_len);

    // Format code not yet implemented, should return false
    try testing.expect(result == false);
}

