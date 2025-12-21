//! Tests for Grain Research Codebase Analyzer.
//!
//! Why: Verify codebase analysis capabilities for analyzing entire codebase.
//! Architecture: Comprehensive test coverage for codebase analysis APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-175304-pst: Grain Research Agent Medium-term Enhancement

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const CodebaseAnalyzer = grain_research.CodebaseAnalyzer;
const FileAnalysisResult = grain_research.FileAnalysisResult;

test "codebase analyzer initialization" {
    const allocator = testing.allocator;
    var analyzer = CodebaseAnalyzer.init(allocator);

    try testing.expect(analyzer.allocator.ptr != null);
}

test "generate summary with no files" {
    const allocator = testing.allocator;
    var analyzer = CodebaseAnalyzer.init(allocator);

    const file_results = [_]FileAnalysisResult{};

    const summary = try analyzer.generate_summary(&file_results);
    defer allocator.free(summary);

    try testing.expect(summary.len > 0);
}

test "file analysis result init and deinit" {
    const allocator = testing.allocator;
    const file_path = "test.zig";

    var file_result = try FileAnalysisResult.init(allocator, file_path);
    file_result.deinit();

    // Should not crash.
    try testing.expect(file_result.file_path_len == 0);
}
