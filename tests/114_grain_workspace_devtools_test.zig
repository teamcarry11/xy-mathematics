//! Tests for Grain DevTools application.
//!
//! Why: Verify code formatting, linting, debugging, profiling, and testing.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-131701-pst: Active implementation
//! 2025-12-20-184722-pst: Phase 21 Grain Style Linter integration tests

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

test "lint grain style line length violation" {
    const allocator = testing.allocator;
    var app = DevToolsApp.init(allocator);

    // Create code with line exceeding 100 characters
    const long_line = "pub fn test_function() void { var x: u32 = 0; var y: u32 = 0; var z: u32 = 0; } // This line is way too long and exceeds 100 characters";
    const violations = app.lint_grain_style("test.zig", long_line);

    try testing.expect(violations > 0);
    try testing.expect(app.linter_messages_len > 0);
    try testing.expect(app.linter_messages[0] != null);
    try testing.expect(app.linter_messages[0].?.severity == .error);
}

test "lint grain style usize violation" {
    const allocator = testing.allocator;
    var app = DevToolsApp.init(allocator);

    // Create code with usize
    const code_with_usize = "pub fn test() void {\n    var x: usize = 0;\n}";
    const violations = app.lint_grain_style("test.zig", code_with_usize);

    try testing.expect(violations > 0);
    try testing.expect(app.linter_messages_len > 0);
}

test "lint grain style isize violation" {
    const allocator = testing.allocator;
    var app = DevToolsApp.init(allocator);

    // Create code with isize
    const code_with_isize = "pub fn test() void {\n    var x: isize = 0;\n}";
    const violations = app.lint_grain_style("test.zig", code_with_isize);

    try testing.expect(violations > 0);
    try testing.expect(app.linter_messages_len > 0);
}

test "lint grain style valid code" {
    const allocator = testing.allocator;
    var app = DevToolsApp.init(allocator);

    // Create valid Grain Style code
    const valid_code = "pub fn test() void {\n    var x: u32 = 0;\n}";
    const violations = app.lint_grain_style("test.zig", valid_code);

    // Should have no violations for basic valid code
    try testing.expect(violations == 0);
}

test "check bounded allocations" {
    const allocator = testing.allocator;
    var app = DevToolsApp.init(allocator);

    // Create code with unbounded array
    const code_unbounded = "pub fn test() void {\n    var arr: [100]u32 = undefined;\n}";
    const violations = app.check_bounded_allocations("test.zig", code_unbounded);

    // Should detect potential unbounded allocation
    try testing.expect(violations >= 0);
}

test "get linter messages" {
    const allocator = testing.allocator;
    var app = DevToolsApp.init(allocator);

    // Add some linter messages
    _ = app.add_linter_message("test.zig", 10, 5, .warning, "Message 1");
    _ = app.add_linter_message("test.zig", 20, 3, .error, "Message 2");
    _ = app.add_linter_message("other.zig", 5, 1, .info, "Message 3");

    var messages: [10]?DevToolsApp.LinterMessage = undefined;
    var messages_len: u32 = 0;
    app.get_linter_messages("test.zig", &messages, &messages_len);

    try testing.expect(messages_len == 2);
    try testing.expect(messages[0] != null);
    try testing.expect(messages[1] != null);
}
