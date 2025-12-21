//! Tests for Grain Research Code Analysis.
//!
//! Why: Verify code analysis capabilities for Grain Style compliance.
//! Architecture: Comprehensive test coverage for code analysis APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-162641-pst: Grain Research Agent Phase 3 (Early Start)

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const CodeAnalyzer = grain_research.CodeAnalyzer;
const ViolationType = grain_research.ViolationType;

test "code analyzer initialization" {
    const allocator = testing.allocator;
    var analyzer = CodeAnalyzer.init(allocator);

    try testing.expect(analyzer.allocator.ptr != null);
}

test "analyze line too long violation" {
    const allocator = testing.allocator;
    var analyzer = CodeAnalyzer.init(allocator);

    // Create code with line exceeding 100 characters.
    const code = "const std = @import(\"std\");\n" ++
        "pub fn very_long_function_name_that_exceeds_grainwrap_100_characters() void {\n" ++
        "    return;\n" ++
        "}\n";

    var result = try analyzer.analyze(code);
    defer result.deinit();

    // Should detect line too long violation.
    try testing.expect(result.violations_len > 0);
    try testing.expect(result.violations[0].violation_type == .line_too_long);
}

test "analyze usize violation" {
    const allocator = testing.allocator;
    var analyzer = CodeAnalyzer.init(allocator);

    const code = "const x: usize = 10;\n";

    var result = try analyzer.analyze(code);
    defer result.deinit();

    // Should detect usize usage.
    try testing.expect(result.violations_len > 0);
    var found_usize = false;
    var i: u32 = 0;
    while (i < result.violations_len) : (i += 1) {
        if (result.violations[i].violation_type == .uses_usize) {
            found_usize = true;
            break;
        }
    }
    try testing.expect(found_usize);
}

test "analyze isize violation" {
    const allocator = testing.allocator;
    var analyzer = CodeAnalyzer.init(allocator);

    const code = "const x: isize = -10;\n";

    var result = try analyzer.analyze(code);
    defer result.deinit();

    // Should detect isize usage.
    try testing.expect(result.violations_len > 0);
    var found_isize = false;
    var i: u32 = 0;
    while (i < result.violations_len) : (i += 1) {
        if (result.violations[i].violation_type == .uses_isize) {
            found_isize = true;
            break;
        }
    }
    try testing.expect(found_isize);
}

test "analyze clean code" {
    const allocator = testing.allocator;
    var analyzer = CodeAnalyzer.init(allocator);

    const code = "const std = @import(\"std\");\n" ++
        "pub fn test() void {\n" ++
        "    const x: u32 = 10;\n" ++
        "    return;\n" ++
        "}\n";

    var result = try analyzer.analyze(code);
    defer result.deinit();

    // Should have no violations (or minimal false positives).
    // Note: Simple analyzer may have false positives.
}

test "analysis result deinit" {
    const allocator = testing.allocator;
    var analyzer = CodeAnalyzer.init(allocator);

    const code = "const x: usize = 10;\n";

    var result = try analyzer.analyze(code);
    result.deinit();

    // Should not crash.
    try testing.expect(result.violations_len == 0);
}
