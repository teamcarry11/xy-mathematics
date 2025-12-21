//! Grain Research Code Analysis: Detect Grain Style compliance patterns.
//!
//! Why: Provides code analysis capabilities for Grain Style Linter and
//! research insights. Detects violations of Grain Style rules.
//! Architecture: Bounded analysis buffers, iterative algorithms.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-162641-pst: Grain Research Agent Phase 3 (Early Start)

const std = @import("std");

// Bounded: Max violations per file.
pub const MAX_VIOLATIONS_PER_FILE: u32 = 10_000;

// Bounded: Max line length for analysis.
pub const MAX_LINE_LEN: u32 = 200;

// Bounded: Max function lines for analysis.
pub const MAX_FUNCTION_LINES: u32 = 200;

// Violation type: Type of Grain Style violation.
pub const ViolationType = enum(u8) {
    line_too_long, // Line exceeds grainwrap-100 (100 chars)
    function_too_long, // Function exceeds grain validate-70 (70 lines)
    uses_usize, // Uses usize instead of u32/u64
    uses_isize, // Uses isize instead of i32/i64
    missing_bounded_allocation, // Missing MAX_ constant
    insufficient_assertions, // Less than 2 assertions per function
};

// Violation: Represents a single Grain Style violation.
pub const Violation = struct {
    violation_type: ViolationType,
    line_number: u32,
    column: u32,
    message: []const u8,
    message_len: u32,
    allocator: std.mem.Allocator,

    // Initialize violation.
    pub fn init(
        allocator: std.mem.Allocator,
        violation_type: ViolationType,
        line_number: u32,
        column: u32,
        message: []const u8,
    ) !Violation {
        std.debug.assert(line_number > 0);
        std.debug.assert(message.len > 0);
        std.debug.assert(message.len <= 512);

        const message_copy = try allocator.dupe(u8, message);
        errdefer allocator.free(message_copy);

        return Violation{
            .violation_type = violation_type,
            .line_number = line_number,
            .column = column,
            .message = message_copy,
            .message_len = @as(u32, @intCast(message_copy.len)),
            .allocator = allocator,
        };
    }

    // Deinitialize violation and free memory.
    pub fn deinit(self: *Violation) void {
        if (self.message_len > 0) {
            self.allocator.free(self.message);
        }
        self.* = undefined;
    }
};

// Analysis result: Contains violations found in code.
pub const AnalysisResult = struct {
    violations: []Violation,
    violations_len: u32,
    total_lines: u32,
    total_functions: u32,
    allocator: std.mem.Allocator,

    // Initialize analysis result.
    pub fn init(allocator: std.mem.Allocator) AnalysisResult {
        return AnalysisResult{
            .violations = &.{},
            .violations_len = 0,
            .total_lines = 0,
            .total_functions = 0,
            .allocator = allocator,
        };
    }

    // Deinitialize analysis result and free memory.
    pub fn deinit(self: *AnalysisResult) void {
        var i: u32 = 0;
        while (i < self.violations_len) : (i += 1) {
            self.violations[i].deinit();
        }
        if (self.violations_len > 0) {
            self.allocator.free(self.violations);
        }
        self.* = undefined;
    }
};

// Code analyzer: Analyzes Zig code for Grain Style compliance.
pub const CodeAnalyzer = struct {
    allocator: std.mem.Allocator,

    // Initialize code analyzer.
    pub fn init(allocator: std.mem.Allocator) CodeAnalyzer {
        return CodeAnalyzer{
            .allocator = allocator,
        };
    }

    // Analyze code for Grain Style violations.
    pub fn analyze(
        self: *CodeAnalyzer,
        code: []const u8,
    ) !AnalysisResult {
        std.debug.assert(code.len > 0);
        std.debug.assert(code.len <= 10_000_000); // 10 MB max

        var result = AnalysisResult.init(self.allocator);
        errdefer result.deinit();

        var violations = std.ArrayListUnmanaged(Violation){};
        defer violations.deinit(self.allocator);

        var line_number: u32 = 1;
        var line_start: u32 = 0;
        var column: u32 = 1;
        var function_start_line: u32 = 0;
        var function_line_count: u32 = 0;
        var in_function: bool = false;
        var assertion_count: u32 = 0;

        var i: u32 = 0;
        while (i < code.len) : (i += 1) {
            const ch = code[i];

            // Check for newline.
            if (ch == '\n') {
                // Check line length (grainwrap-100).
                const line_len = i - line_start;
                if (line_len > 100) {
                    const msg = try std.fmt.allocPrint(
                        self.allocator,
                        "Line {d} exceeds grainwrap-100: {d} chars",
                        .{ line_number, line_len },
                    );
                    defer self.allocator.free(msg);
                    const violation = try Violation.init(
                        self.allocator,
                        .line_too_long,
                        line_number,
                        100,
                        msg,
                    );
                    try violations.append(self.allocator, violation);
                }

                line_number += 1;
                line_start = i + 1;
                column = 1;
                if (in_function) {
                    function_line_count += 1;
                }
                continue;
            }

            column += 1;

            // Simple pattern matching for common violations.
            // Note: This is a simplified analyzer. Full AST parsing
            // would be needed for complete analysis.
            if (i + 5 < code.len) {
                const slice = code[i..@min(i + 10, code.len)];
                // Check for usize usage.
                if (std.mem.indexOf(u8, slice, "usize") != null) {
                    const msg = try std.fmt.allocPrint(
                        self.allocator,
                        "Line {d}: Uses usize, should use u32/u64",
                        .{line_number},
                    );
                    defer self.allocator.free(msg);
                    const violation = try Violation.init(
                        self.allocator,
                        .uses_usize,
                        line_number,
                        column,
                        msg,
                    );
                    try violations.append(self.allocator, violation);
                }
                // Check for isize usage.
                if (std.mem.indexOf(u8, slice, "isize") != null) {
                    const msg = try std.fmt.allocPrint(
                        self.allocator,
                        "Line {d}: Uses isize, should use i32/i64",
                        .{line_number},
                    );
                    defer self.allocator.free(msg);
                    const violation = try Violation.init(
                        self.allocator,
                        .uses_isize,
                        line_number,
                        column,
                        msg,
                    );
                    try violations.append(self.allocator, violation);
                }
            }
        }

        // Check function length (grain validate-70).
        if (in_function and function_line_count > 70) {
            const msg = try std.fmt.allocPrint(
                self.allocator,
                "Function starting at line {d} exceeds grain validate-70: {d} lines",
                .{ function_start_line, function_line_count },
            );
            defer self.allocator.free(msg);
            const violation = try Violation.init(
                self.allocator,
                .function_too_long,
                function_start_line,
                1,
                msg,
            );
            try violations.append(self.allocator, violation);
        }

        // Copy violations to result.
        if (violations.items.len > 0) {
            const violations_copy = try self.allocator.alloc(
                Violation,
                violations.items.len,
            );
            errdefer self.allocator.free(violations_copy);

            var j: u32 = 0;
            while (j < violations.items.len) : (j += 1) {
                violations_copy[j] = violations.items[j];
            }

            result.violations = violations_copy;
            result.violations_len = @as(u32, @intCast(violations.items.len));
        }

        result.total_lines = line_number;
        // Note: Function counting would require full AST parsing.
        result.total_functions = 0;

        // Check final line length if code doesn't end with newline.
        if (line_start < code.len) {
            const final_line_len = code.len - line_start;
            if (final_line_len > 100) {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "Line {d} exceeds grainwrap-100: {d} chars",
                    .{ line_number, final_line_len },
                );
                defer self.allocator.free(msg);
                const violation = try Violation.init(
                    self.allocator,
                    .line_too_long,
                    line_number,
                    100,
                    msg,
                );
                try violations.append(self.allocator, violation);
            }
        }

        return result;
    }
};
