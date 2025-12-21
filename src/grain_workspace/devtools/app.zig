//! Grain DevTools: Development utilities suite.
//!
//! Why: Provide development tools for code formatting, linting, debugging.
//! Architecture: Code formatter, linter, debugger, profiler, test runner.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-131701-pst: Active implementation
//! 2025-12-20-184722-pst: Phase 21 Grain Style Linter integration

const std = @import("std");
const grain_core = @import("grain_core");

// Bounded: Max breakpoints (explicit limit)
// 2025-12-04-131701-pst: Active constant
pub const MAX_BREAKPOINTS: u32 = 256;

// Bounded: Max watchpoints (explicit limit)
// 2025-12-04-131701-pst: Active constant
pub const MAX_WATCHPOINTS: u32 = 128;

// Bounded: Max test files (explicit limit)
// 2025-12-04-131701-pst: Active constant
pub const MAX_TEST_FILES: u32 = 512;

// Bounded: Max file path length (explicit limit, in bytes)
// 2025-12-04-131701-pst: Active constant
pub const MAX_FILE_PATH_LEN: u32 = 512;

// Bounded: Max lint violations (explicit limit)
// 2025-12-20-184722-pst: Phase 21 Grain Style Linter
pub const MAX_LINT_VIOLATIONS: u32 = 1000;

// Language enumeration for formatter.
// 2025-12-04-131701-pst: Active enum
pub const Language = enum(u8) {
    zig, // Zig language
    c, // C language
    cpp, // C++ language
    rust, // Rust language
    python, // Python language
    javascript, // JavaScript language
    typescript, // TypeScript language
    other, // Other languages
};

// Linter severity level.
// 2025-12-04-131701-pst: Active enum
pub const LinterSeverity = enum(u8) {
    info, // Informational message
    warning, // Warning message
    error, // Error message
    critical, // Critical error
};

// Breakpoint structure.
// 2025-12-04-131701-pst: Active struct
pub const Breakpoint = struct {
    breakpoint_id: u32,
    file_path: [MAX_FILE_PATH_LEN]u8,
    file_path_len: u32,
    line_number: u32,
    enabled: bool,
    hit_count: u32,
};

// Watchpoint structure.
// 2025-12-04-131701-pst: Active struct
pub const Watchpoint = struct {
    watchpoint_id: u32,
    variable_name: [64]u8,
    variable_name_len: u32,
    expression: [256]u8,
    expression_len: u32,
    enabled: bool,
};

// Linter message structure.
// 2025-12-04-131701-pst: Active struct
pub const LinterMessage = struct {
    file_path: [MAX_FILE_PATH_LEN]u8,
    file_path_len: u32,
    line_number: u32,
    column_number: u32,
    severity: LinterSeverity,
    message: [256]u8,
    message_len: u32,
};

// Test result structure.
// 2025-12-04-131701-pst: Active struct
pub const TestResult = struct {
    test_name: [128]u8,
    test_name_len: u32,
    file_path: [MAX_FILE_PATH_LEN]u8,
    file_path_len: u32,
    passed: bool,
    execution_time_ms: u64,
    error_message: [256]u8,
    error_message_len: u32,
};

// Profiler sample structure.
// 2025-12-04-131701-pst: Active struct
pub const ProfilerSample = struct {
    function_name: [128]u8,
    function_name_len: u32,
    file_path: [MAX_FILE_PATH_LEN]u8,
    file_path_len: u32,
    line_number: u32,
    execution_time_us: u64,
    memory_used_bytes: u64,
    call_count: u32,
};

// DevTools application state.
// 2025-12-04-131701-pst: Active struct
pub const DevToolsApp = struct {
    breakpoints: [MAX_BREAKPOINTS]?Breakpoint,
    breakpoints_len: u32,
    watchpoints: [MAX_WATCHPOINTS]?Watchpoint,
    watchpoints_len: u32,
    linter_messages: [256]?LinterMessage,
    linter_messages_len: u32,
    test_results: [MAX_TEST_FILES]?TestResult,
    test_results_len: u32,
    profiler_samples: [256]?ProfilerSample,
    profiler_samples_len: u32,
    allocator: std.mem.Allocator,

    /// Initialize DevTools application.
    // 2025-12-04-131701-pst: Active function
    pub fn init(allocator: std.mem.Allocator) DevToolsApp {
        // Precondition: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        var app = DevToolsApp{
            .breakpoints = undefined,
            .breakpoints_len = 0,
            .watchpoints = undefined,
            .watchpoints_len = 0,
            .linter_messages = undefined,
            .linter_messages_len = 0,
            .test_results = undefined,
            .test_results_len = 0,
            .profiler_samples = undefined,
            .profiler_samples_len = 0,
            .allocator = allocator,
        };

        // Initialize breakpoints array
        var i: u32 = 0;
        while (i < MAX_BREAKPOINTS) : (i += 1) {
            app.breakpoints[i] = null;
        }

        // Initialize watchpoints array
        i = 0;
        while (i < MAX_WATCHPOINTS) : (i += 1) {
            app.watchpoints[i] = null;
        }

        // Initialize linter messages array
        i = 0;
        while (i < 256) : (i += 1) {
            app.linter_messages[i] = null;
        }

        // Initialize test results array
        i = 0;
        while (i < MAX_TEST_FILES) : (i += 1) {
            app.test_results[i] = null;
        }

        // Initialize profiler samples array
        i = 0;
        while (i < 256) : (i += 1) {
            app.profiler_samples[i] = null;
        }

        // Postcondition: App must be valid
        std.debug.assert(app.breakpoints_len == 0);
        std.debug.assert(app.watchpoints_len == 0);

        return app;
    }

    /// Format code file.
    // 2025-12-04-131701-pst: Active function
    pub fn format_code(
        self: *DevToolsApp,
        file_path: []const u8,
        language: Language,
        formatted: []u8,
        formatted_len: *u32,
    ) bool {
        // Precondition: File path and buffer must be valid
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(formatted.len > 0);
        std.debug.assert(formatted_len != null);

        formatted_len.* = 0;

        // In full implementation, would perform actual code formatting
        // For now, return false (not implemented)
        _ = self;
        _ = language;

        return false;
    }

    /// Add breakpoint.
    // 2025-12-04-131701-pst: Active function
    pub fn add_breakpoint(
        self: *DevToolsApp,
        file_path: []const u8,
        line_number: u32,
    ) ?u32 {
        // Precondition: Must have space for breakpoint
        std.debug.assert(self.breakpoints_len < MAX_BREAKPOINTS);
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(line_number > 0);

        const breakpoint_id = self.breakpoints_len + 1;
        var bp = Breakpoint{
            .breakpoint_id = breakpoint_id,
            .file_path = undefined,
            .file_path_len = @as(u32, @intCast(file_path.len)),
            .line_number = line_number,
            .enabled = true,
            .hit_count = 0,
        };

        // Set file path
        @memset(&bp.file_path, 0);
        const path_len = @min(file_path.len, MAX_FILE_PATH_LEN);
        @memcpy(bp.file_path[0..path_len], file_path[0..path_len]);
        bp.file_path_len = @as(u32, @intCast(path_len));

        self.breakpoints[self.breakpoints_len] = bp;
        self.breakpoints_len += 1;

        // Postcondition: Breakpoint count increased
        std.debug.assert(self.breakpoints_len > 0);
        std.debug.assert(self.breakpoints_len <= MAX_BREAKPOINTS);

        return breakpoint_id;
    }

    /// Remove breakpoint.
    // 2025-12-04-131701-pst: Active function
    pub fn remove_breakpoint(
        self: *DevToolsApp,
        breakpoint_id: u32,
    ) bool {
        // Precondition: Breakpoint ID must be valid
        std.debug.assert(breakpoint_id > 0);

        var i: u32 = 0;
        while (i < self.breakpoints_len) : (i += 1) {
            if (self.breakpoints[i]) |bp| {
                if (bp.breakpoint_id == breakpoint_id) {
                    // Shift remaining breakpoints left
                    var j: u32 = i;
                    while (j + 1 < self.breakpoints_len) : (j += 1) {
                        self.breakpoints[j] = self.breakpoints[j + 1];
                    }
                    self.breakpoints_len -= 1;
                    self.breakpoints[self.breakpoints_len] = null;
                    return true;
                }
            }
        }

        return false;
    }

    /// Add watchpoint.
    // 2025-12-04-131701-pst: Active function
    pub fn add_watchpoint(
        self: *DevToolsApp,
        variable_name: []const u8,
        expression: []const u8,
    ) ?u32 {
        // Precondition: Must have space for watchpoint
        std.debug.assert(self.watchpoints_len < MAX_WATCHPOINTS);
        std.debug.assert(variable_name.len > 0);
        std.debug.assert(variable_name.len <= 64);
        std.debug.assert(expression.len <= 256);

        const watchpoint_id = self.watchpoints_len + 1;
        var wp = Watchpoint{
            .watchpoint_id = watchpoint_id,
            .variable_name = undefined,
            .variable_name_len = @as(u32, @intCast(variable_name.len)),
            .expression = undefined,
            .expression_len = @as(u32, @intCast(expression.len)),
            .enabled = true,
        };

        // Set variable name
        @memset(&wp.variable_name, 0);
        const var_len = @min(variable_name.len, 64);
        @memcpy(wp.variable_name[0..var_len], variable_name[0..var_len]);
        wp.variable_name_len = @as(u32, @intCast(var_len));

        // Set expression
        @memset(&wp.expression, 0);
        const expr_len = @min(expression.len, 256);
        if (expr_len > 0) {
            @memcpy(wp.expression[0..expr_len], expression[0..expr_len]);
        }
        wp.expression_len = @as(u32, @intCast(expr_len));

        self.watchpoints[self.watchpoints_len] = wp;
        self.watchpoints_len += 1;

        // Postcondition: Watchpoint count increased
        std.debug.assert(self.watchpoints_len > 0);
        std.debug.assert(self.watchpoints_len <= MAX_WATCHPOINTS);

        return watchpoint_id;
    }

    /// Add linter message.
    // 2025-12-04-131701-pst: Active function
    pub fn add_linter_message(
        self: *DevToolsApp,
        file_path: []const u8,
        line_number: u32,
        column_number: u32,
        severity: LinterSeverity,
        message: []const u8,
    ) bool {
        // Precondition: Must have space for message
        std.debug.assert(self.linter_messages_len < 256);
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(message.len > 0);
        std.debug.assert(message.len <= 256);

        var msg = LinterMessage{
            .file_path = undefined,
            .file_path_len = @as(u32, @intCast(file_path.len)),
            .line_number = line_number,
            .column_number = column_number,
            .severity = severity,
            .message = undefined,
            .message_len = @as(u32, @intCast(message.len)),
        };

        // Set file path
        @memset(&msg.file_path, 0);
        const path_len = @min(file_path.len, MAX_FILE_PATH_LEN);
        @memcpy(msg.file_path[0..path_len], file_path[0..path_len]);
        msg.file_path_len = @as(u32, @intCast(path_len));

        // Set message
        @memset(&msg.message, 0);
        const msg_len = @min(message.len, 256);
        @memcpy(msg.message[0..msg_len], message[0..msg_len]);
        msg.message_len = @as(u32, @intCast(msg_len));

        self.linter_messages[self.linter_messages_len] = msg;
        self.linter_messages_len += 1;

        // Postcondition: Message count increased
        std.debug.assert(self.linter_messages_len > 0);
        std.debug.assert(self.linter_messages_len <= 256);

        return true;
    }

    /// Add test result.
    // 2025-12-04-131701-pst: Active function
    pub fn add_test_result(
        self: *DevToolsApp,
        test_name: []const u8,
        file_path: []const u8,
        passed: bool,
        execution_time_ms: u64,
        error_message: []const u8,
    ) bool {
        // Precondition: Must have space for test result
        std.debug.assert(self.test_results_len < MAX_TEST_FILES);
        std.debug.assert(test_name.len > 0);
        std.debug.assert(test_name.len <= 128);
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(error_message.len <= 256);

        var result = TestResult{
            .test_name = undefined,
            .test_name_len = @as(u32, @intCast(test_name.len)),
            .file_path = undefined,
            .file_path_len = @as(u32, @intCast(file_path.len)),
            .passed = passed,
            .execution_time_ms = execution_time_ms,
            .error_message = undefined,
            .error_message_len = @as(u32, @intCast(error_message.len)),
        };

        // Set test name
        @memset(&result.test_name, 0);
        const name_len = @min(test_name.len, 128);
        @memcpy(result.test_name[0..name_len], test_name[0..name_len]);
        result.test_name_len = @as(u32, @intCast(name_len));

        // Set file path
        @memset(&result.file_path, 0);
        const path_len = @min(file_path.len, MAX_FILE_PATH_LEN);
        @memcpy(result.file_path[0..path_len], file_path[0..path_len]);
        result.file_path_len = @as(u32, @intCast(path_len));

        // Set error message
        @memset(&result.error_message, 0);
        const err_len = @min(error_message.len, 256);
        if (err_len > 0) {
            @memcpy(result.error_message[0..err_len], error_message[0..err_len]);
        }
        result.error_message_len = @as(u32, @intCast(err_len));

        self.test_results[self.test_results_len] = result;
        self.test_results_len += 1;

        // Postcondition: Test result count increased
        std.debug.assert(self.test_results_len > 0);
        std.debug.assert(self.test_results_len <= MAX_TEST_FILES);

        return true;
    }

    /// Add profiler sample.
    // 2025-12-04-131701-pst: Active function
    pub fn add_profiler_sample(
        self: *DevToolsApp,
        function_name: []const u8,
        file_path: []const u8,
        line_number: u32,
        execution_time_us: u64,
        memory_used_bytes: u64,
        call_count: u32,
    ) bool {
        // Precondition: Must have space for sample
        std.debug.assert(self.profiler_samples_len < 256);
        std.debug.assert(function_name.len > 0);
        std.debug.assert(function_name.len <= 128);
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);

        var sample = ProfilerSample{
            .function_name = undefined,
            .function_name_len = @as(u32, @intCast(function_name.len)),
            .file_path = undefined,
            .file_path_len = @as(u32, @intCast(file_path.len)),
            .line_number = line_number,
            .execution_time_us = execution_time_us,
            .memory_used_bytes = memory_used_bytes,
            .call_count = call_count,
        };

        // Set function name
        @memset(&sample.function_name, 0);
        const func_len = @min(function_name.len, 128);
        @memcpy(sample.function_name[0..func_len], function_name[0..func_len]);
        sample.function_name_len = @as(u32, @intCast(func_len));

        // Set file path
        @memset(&sample.file_path, 0);
        const path_len = @min(file_path.len, MAX_FILE_PATH_LEN);
        @memcpy(sample.file_path[0..path_len], file_path[0..path_len]);
        sample.file_path_len = @as(u32, @intCast(path_len));

        self.profiler_samples[self.profiler_samples_len] = sample;
        self.profiler_samples_len += 1;

        // Postcondition: Sample count increased
        std.debug.assert(self.profiler_samples_len > 0);
        std.debug.assert(self.profiler_samples_len <= 256);

        return true;
    }

    /// Clear all breakpoints.
    // 2025-12-04-131701-pst: Active function
    pub fn clear_breakpoints(self: *DevToolsApp) void {
        // Precondition: App must be valid
        std.debug.assert(@intFromPtr(self) != 0);

        self.breakpoints_len = 0;
        var i: u32 = 0;
        while (i < MAX_BREAKPOINTS) : (i += 1) {
            self.breakpoints[i] = null;
        }

        // Postcondition: Breakpoints must be cleared
        std.debug.assert(self.breakpoints_len == 0);
    }

    /// Clear all linter messages.
    // 2025-12-04-131701-pst: Active function
    pub fn clear_linter_messages(self: *DevToolsApp) void {
        // Precondition: App must be valid
        std.debug.assert(@intFromPtr(self) != 0);

        self.linter_messages_len = 0;
        var i: u32 = 0;
        while (i < 256) : (i += 1) {
            self.linter_messages[i] = null;
        }

        // Postcondition: Messages must be cleared
        std.debug.assert(self.linter_messages_len == 0);
    }

    /// Lint Zig code for Grain Style compliance.
    // 2025-12-20-184722-pst: Phase 21 Grain Style Linter
    pub fn lint_grain_style(
        self: *DevToolsApp,
        file_path: []const u8,
        source_code: []const u8,
    ) u32 {
        // Precondition: File path and source code must be valid
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(source_code.len > 0);

        // Clear previous messages for this file
        self.clear_linter_messages();

        var violation_count: u32 = 0;
        var line_number: u32 = 1;
        var line_start: u32 = 0;
        var function_start_line: u32 = 0;
        var function_line_count: u32 = 0;
        var in_function: bool = false;

        var i: u32 = 0;
        while (i < source_code.len and violation_count < MAX_LINT_VIOLATIONS) : (i += 1) {
            const c = source_code[i];

            // Check for newline
            if (c == '\n') {
                // Check line length (grainwrap-100)
                const line_len = i - line_start;
                if (line_len > 100) {
                    const msg = "Line exceeds 100 characters (grainwrap-100)";
                    _ = self.add_linter_message(
                        file_path,
                        line_number,
                        101,
                        .error,
                        msg,
                    );
                    violation_count += 1;
                }

                // Check for usize/isize usage in line
                var j: u32 = line_start;
                while (j < i and j + 5 < source_code.len) : (j += 1) {
                    // Check for "usize"
                    if (j + 5 <= source_code.len) {
                        if (std.mem.eql(u8, source_code[j..j+5], "usize")) {
                            const msg = "Use explicit u32/u64 instead of usize";
                            _ = self.add_linter_message(
                                file_path,
                                line_number,
                                j - line_start + 1,
                                .error,
                                msg,
                            );
                            violation_count += 1;
                        }
                    }
                    // Check for "isize"
                    if (j + 5 <= source_code.len) {
                        if (std.mem.eql(u8, source_code[j..j+5], "isize")) {
                            const msg = "Use explicit i32/i64 instead of isize";
                            _ = self.add_linter_message(
                                file_path,
                                line_number,
                                j - line_start + 1,
                                .error,
                                msg,
                            );
                            violation_count += 1;
                        }
                    }
                }

                line_number += 1;
                line_start = i + 1;

                // Update function line count
                if (in_function) {
                    function_line_count += 1;
                }
            }

            // Detect function start (simplified: look for "pub fn" or "fn")
            if (i + 3 < source_code.len) {
                if (std.mem.eql(u8, source_code[i..i+3], "fn ")) {
                    in_function = true;
                    function_start_line = line_number;
                    function_line_count = 0;
                }
            }

            // Detect function end (simplified: look for closing brace at start of line)
            if (c == '}' and in_function) {
                // Check if this is likely end of function
                var check_pos: u32 = i;
                while (check_pos > 0 and check_pos > line_start) : (check_pos -= 1) {
                    if (source_code[check_pos] == '\n') {
                        break;
                    }
                }
                // Simple heuristic: if brace is at start of line or after whitespace
                if (check_pos == line_start or (check_pos < i and source_code[check_pos + 1] == '}')) {
                    // Check function length (grain validate-70)
                    if (function_line_count > 70) {
                        const msg = "Function exceeds 70 lines (grain validate-70)";
                        _ = self.add_linter_message(
                            file_path,
                            function_start_line,
                            1,
                            .error,
                            msg,
                        );
                        violation_count += 1;
                    }
                    in_function = false;
                }
            }
        }

        // Check last line if no newline at end
        if (line_start < source_code.len) {
            const line_len = source_code.len - line_start;
            if (line_len > 100) {
                const msg = "Line exceeds 100 characters (grainwrap-100)";
                _ = self.add_linter_message(
                    file_path,
                    line_number,
                    101,
                    .error,
                    msg,
                );
                violation_count += 1;
            }
        }

        // Postcondition: Violation count must be valid
        std.debug.assert(violation_count <= MAX_LINT_VIOLATIONS);

        return violation_count;
    }

    /// Check for bounded allocations (MAX_* constants).
    // 2025-12-20-184722-pst: Phase 21 Grain Style Linter
    pub fn check_bounded_allocations(
        self: *DevToolsApp,
        file_path: []const u8,
        source_code: []const u8,
    ) u32 {
        // Precondition: File path and source code must be valid
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(source_code.len > 0);

        var violation_count: u32 = 0;
        var line_number: u32 = 1;
        var line_start: u32 = 0;

        // Look for array allocations without MAX_ constants
        var i: u32 = 0;
        while (i < source_code.len and violation_count < MAX_LINT_VIOLATIONS) : (i += 1) {
            const c = source_code[i];

            if (c == '\n') {
                line_number += 1;
                line_start = i + 1;
            }

            // Check for array declarations that might not be bounded
            if (i + 4 < source_code.len and std.mem.eql(u8, source_code[i..i+4], "var ")) {
                // Look ahead for array syntax
                var j: u32 = i + 4;
                while (j < source_code.len and j < i + 100) : (j += 1) {
                    if (source_code[j] == '[') {
                        // Found array declaration, check if it has MAX_ constant
                        var has_max: bool = false;
                        var k: u32 = i;
                        while (k < j) : (k += 1) {
                            if (k + 4 < source_code.len and std.mem.eql(u8, source_code[k..k+4], "MAX_")) {
                                has_max = true;
                                break;
                            }
                        }
                        if (!has_max) {
                            const msg = "Array allocation should use MAX_ constant";
                            _ = self.add_linter_message(
                                file_path,
                                line_number,
                                i - line_start + 1,
                                .warning,
                                msg,
                            );
                            violation_count += 1;
                        }
                        break;
                    }
                    if (source_code[j] == '\n' or source_code[j] == ';') {
                        break;
                    }
                }
            }
        }

        // Postcondition: Violation count must be valid
        std.debug.assert(violation_count <= MAX_LINT_VIOLATIONS);

        return violation_count;
    }

    /// Get linter messages for a file.
    // 2025-12-20-184722-pst: Phase 21 Grain Style Linter
    pub fn get_linter_messages(
        self: *const DevToolsApp,
        file_path: []const u8,
        messages: []?LinterMessage,
        messages_len: *u32,
    ) void {
        // Precondition: Messages buffer must be valid
        std.debug.assert(file_path.len > 0);
        std.debug.assert(messages.len >= 256);

        messages_len.* = 0;
        var i: u32 = 0;
        while (i < self.linter_messages_len and messages_len.* < messages.len) : (i += 1) {
            if (self.linter_messages[i]) |msg| {
                // Check if message is for this file
                if (msg.file_path_len == file_path.len) {
                    var match: bool = true;
                    var j: u32 = 0;
                    while (j < file_path.len) : (j += 1) {
                        if (msg.file_path[j] != file_path[j]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        messages[messages_len.*] = msg;
                        messages_len.* += 1;
                    }
                }
            }
        }
    }
};

