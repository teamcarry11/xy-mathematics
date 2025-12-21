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

    // Check line length violation (grainwrap-100).
    fn check_line_length(
        self: *CodeAnalyzer,
        violations: *std.ArrayListUnmanaged(Violation),
        line_number: u32,
        line_len: u32,
    ) !void {
        std.debug.assert(line_number > 0);
        std.debug.assert(line_len <= MAX_LINE_LEN);

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
    }

    // Check for usize/isize usage violations.
    fn check_type_violations(
        self: *CodeAnalyzer,
        violations: *std.ArrayListUnmanaged(Violation),
        code: []const u8,
        i: u32,
        line_number: u32,
        column: u32,
    ) !void {
        std.debug.assert(i < code.len);
        std.debug.assert(line_number > 0);
        std.debug.assert(column > 0);

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

    // Copy violations to analysis result.
    fn copy_violations_to_result(
        self: *CodeAnalyzer,
        result: *AnalysisResult,
        violations: *std.ArrayListUnmanaged(Violation),
    ) !void {
        std.debug.assert(violations.items.len <= MAX_VIOLATIONS_PER_FILE);

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
    }

    // Scan code for violations (iterative processing).
    fn scan_code_for_violations(
        self: *CodeAnalyzer,
        violations: *std.ArrayListUnmanaged(Violation),
        code: []const u8,
    ) !struct { line_number: u32, line_start: u32 } {
        std.debug.assert(code.len > 0);
        std.debug.assert(code.len <= 10_000_000);

        var line_number: u32 = 1;
        var line_start: u32 = 0;
        var column: u32 = 1;

        var i: u32 = 0;
        while (i < code.len) : (i += 1) {
            const ch = code[i];

            // Check for newline.
            if (ch == '\n') {
                const line_len = i - line_start;
                try self.check_line_length(violations, line_number, line_len);

                line_number += 1;
                line_start = i + 1;
                column = 1;
                continue;
            }

            column += 1;
            try self.check_type_violations(violations, code, i, line_number, column);
        }

        return .{ .line_number = line_number, .line_start = line_start };
    }

    // Analyze code for Grain Style violations.
    pub fn analyze(
        self: *CodeAnalyzer,
        code: []const u8,
    ) !AnalysisResult {
        std.debug.assert(code.len > 0);
        std.debug.assert(code.len <= 10_000_000);

        var result = AnalysisResult.init(self.allocator);
        errdefer result.deinit();

        var violations = std.ArrayListUnmanaged(Violation){};
        defer violations.deinit(self.allocator);
        violations.ensureTotalCapacity(self.allocator, MAX_VIOLATIONS_PER_FILE) catch |err| {
            std.debug.assert(err == error.OutOfMemory);
            return err;
        };

        const scan_result = try self.scan_code_for_violations(&violations, code);

        // Check final line length if code doesn't end with newline.
        if (scan_result.line_start < code.len) {
            const final_line_len = code.len - scan_result.line_start;
            try self.check_line_length(&violations, scan_result.line_number, final_line_len);
        }

        try self.copy_violations_to_result(&result, &violations);

        result.total_lines = scan_result.line_number;
        // Note: Function counting would require full AST parsing.
        result.total_functions = 0;

        return result;
    }
};
