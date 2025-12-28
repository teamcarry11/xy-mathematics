//! Retrieval LLM Integration Tests.
//!
//! Why: Validates retrieval LLM integration for Phase 2 LLM Integration.
//! Tests query test execution, fact parsing, and accuracy checking.
//! Architecture: Unit tests for retrieval LLM integration components.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-28-224000-pst: Phase 2 LLM Integration (Court Agent integration)

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const QueryTestResult = grain_research.QueryTestResult;
const RetrievalResult = grain_research.RetrievalResult;
const retrieval_llm_integration = grain_research.retrieval_llm_integration;

test "query test result initialization" {
    const json_result = RetrievalResult.init(1, &[_]u32{1, 2}, "JSON answer", true);
    const zon_result = RetrievalResult.init(1, &[_]u32{1, 2}, "ZON answer", true);

    const test_result = QueryTestResult.init(
        1,
        json_result,
        zon_result,
        true,
        true,
        100,
        70,
    );

    try testing.expect(test_result.query_id == 1);
    try testing.expect(test_result.json_accuracy == true);
    try testing.expect(test_result.zon_accuracy == true);
    try testing.expect(test_result.json_tokens == 100);
    try testing.expect(test_result.zon_tokens == 70);
    try testing.expect(test_result.token_savings_percent == 30.0);
}

test "query test result with token savings calculation" {
    const json_result = RetrievalResult.init(1, &[_]u32{1}, "JSON", true);
    const zon_result = RetrievalResult.init(1, &[_]u32{1}, "ZON", true);

    const test_result = QueryTestResult.init(
        1,
        json_result,
        zon_result,
        true,
        true,
        200,
        150,
    );

    try testing.expect(test_result.token_savings_percent == 25.0);
    try testing.expect(test_result.json_tokens == 200);
    try testing.expect(test_result.zon_tokens == 150);
}

test "query test result with zero token savings" {
    const json_result = RetrievalResult.init(1, &[_]u32{1}, "JSON", true);
    const zon_result = RetrievalResult.init(1, &[_]u32{1}, "ZON", true);

    const test_result = QueryTestResult.init(
        1,
        json_result,
        zon_result,
        true,
        true,
        100,
        100,
    );

    try testing.expect(test_result.token_savings_percent == 0.0);
}

test "query test result with accuracy mismatch" {
    const json_result = RetrievalResult.init(1, &[_]u32{1, 2}, "JSON", true);
    const zon_result = RetrievalResult.init(1, &[_]u32{1}, "ZON", false);

    const test_result = QueryTestResult.init(
        1,
        json_result,
        zon_result,
        true,
        false,
        100,
        80,
    );

    try testing.expect(test_result.json_accuracy == true);
    try testing.expect(test_result.zon_accuracy == false);
}
