//! Grain Research Codebase Analyzer: Analyze entire codebase for Grain Style.
//!
//! Why: Use Research Agent's Code Analysis module to analyze the codebase
//! and generate insights on code patterns, style compliance, test coverage.
//! Architecture: Iterative file processing, bounded analysis buffers.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-175304-pst: Grain Research Agent Medium-term Enhancement

const std = @import("std");
const code_analysis = @import("code_analysis.zig");
const CodeAnalyzer = code_analysis.CodeAnalyzer;
const AnalysisResult = code_analysis.AnalysisResult;
const ViolationType = code_analysis.ViolationType;

// Bounded: Max files to analyze.
pub const MAX_FILES_TO_ANALYZE: u32 = 10_000;

// Bounded: Max file path length.
pub const MAX_FILE_PATH_LEN: u32 = 1_024;

// File analysis result: Contains violations for a single file.
pub const FileAnalysisResult = struct {
    file_path: []const u8,
    file_path_len: u32,
    analysis_result: AnalysisResult,
    total_lines: u32,
    allocator: std.mem.Allocator,

    // Initialize file analysis result.
    pub fn init(
        allocator: std.mem.Allocator,
        file_path: []const u8,
    ) !FileAnalysisResult {
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);

        const file_path_copy = try allocator.dupe(u8, file_path);
        errdefer allocator.free(file_path_copy);

        return FileAnalysisResult{
            .file_path = file_path_copy,
            .file_path_len = @as(u32, @intCast(file_path_copy.len)),
            .analysis_result = AnalysisResult.init(allocator),
            .total_lines = 0,
            .allocator = allocator,
        };
    }

    // Deinitialize file analysis result and free memory.
    pub fn deinit(self: *FileAnalysisResult) void {
        self.analysis_result.deinit();
        if (self.file_path_len > 0) {
            self.allocator.free(self.file_path);
        }
        self.* = undefined;
    }
};

// Codebase analyzer: Analyzes entire codebase for Grain Style compliance.
pub const CodebaseAnalyzer = struct {
    allocator: std.mem.Allocator,
    code_analyzer: CodeAnalyzer,

    // Initialize codebase analyzer.
    pub fn init(allocator: std.mem.Allocator) CodebaseAnalyzer {
        return CodebaseAnalyzer{
            .allocator = allocator,
            .code_analyzer = CodeAnalyzer.init(allocator),
        };
    }

    // Analyze single file for Grain Style violations.
    fn analyze_file(
        self: *CodebaseAnalyzer,
        file_path: []const u8,
        file_content: []const u8,
    ) !FileAnalysisResult {
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(file_content.len > 0);

        var file_result = try FileAnalysisResult.init(self.allocator, file_path);
        errdefer file_result.deinit();

        const analysis = try self.code_analyzer.analyze(file_content);
        defer analysis.deinit();

        // Store analysis result (copy violations with proper memory management).
        file_result.analysis_result = AnalysisResult.init(self.allocator);
        errdefer file_result.analysis_result.deinit();

        if (analysis.violations_len > 0) {
            const violations_copy = try self.allocator.alloc(
                code_analysis.Violation,
                analysis.violations_len,
            );
            errdefer self.allocator.free(violations_copy);

            var i: u32 = 0;
            while (i < analysis.violations_len) : (i += 1) {
                const src_violation = analysis.violations[i];
                const msg_copy = try self.allocator.dupe(u8, src_violation.message);
                errdefer {
                    var j: u32 = 0;
                    while (j < i) : (j += 1) {
                        violations_copy[j].deinit();
                    }
                    self.allocator.free(violations_copy);
                }
                violations_copy[i] = code_analysis.Violation{
                    .violation_type = src_violation.violation_type,
                    .line_number = src_violation.line_number,
                    .column = src_violation.column,
                    .message = msg_copy,
                    .message_len = src_violation.message_len,
                    .allocator = self.allocator,
                };
            }

            file_result.analysis_result.violations = violations_copy;
            file_result.analysis_result.violations_len = analysis.violations_len;
        }

        file_result.analysis_result.total_lines = analysis.total_lines;
        file_result.analysis_result.total_functions = analysis.total_functions;
        file_result.total_lines = analysis.total_lines;

        return file_result;
    }

    // Generate codebase analysis summary.
    pub fn generate_summary(
        self: *CodebaseAnalyzer,
        file_results: []const FileAnalysisResult,
    ) ![]const u8 {
        std.debug.assert(file_results.len <= MAX_FILES_TO_ANALYZE);

        var total_violations: u32 = 0;
        var total_lines: u32 = 0;
        var line_too_long_count: u32 = 0;
        var function_too_long_count: u32 = 0;
        var uses_usize_count: u32 = 0;
        var uses_isize_count: u32 = 0;

        var i: u32 = 0;
        while (i < file_results.len) : (i += 1) {
            const file_result = file_results[i];
            total_lines += file_result.total_lines;

            const analysis = file_result.analysis_result;
            if (analysis.violations_len > 0) {
                total_violations += analysis.violations_len;

                var j: u32 = 0;
                while (j < analysis.violations_len) : (j += 1) {
                    const violation = analysis.violations[j];
                    switch (violation.violation_type) {
                        .line_too_long => line_too_long_count += 1,
                        .function_too_long => function_too_long_count += 1,
                        .uses_usize => uses_usize_count += 1,
                        .uses_isize => uses_isize_count += 1,
                        else => {},
                    }
                }
            }
        }

        const summary = try std.fmt.allocPrint(
            self.allocator,
            "Codebase Analysis Summary:\n" ++
                "  Files analyzed: {d}\n" ++
                "  Total lines: {d}\n" ++
                "  Total violations: {d}\n" ++
                "  Line too long: {d}\n" ++
                "  Function too long: {d}\n" ++
                "  Uses usize: {d}\n" ++
                "  Uses isize: {d}\n",
            .{
                file_results.len,
                total_lines,
                total_violations,
                line_too_long_count,
                function_too_long_count,
                uses_usize_count,
                uses_isize_count,
            },
        );

        return summary;
    }
};
