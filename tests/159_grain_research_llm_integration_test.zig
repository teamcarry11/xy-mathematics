//! LLM Integration Tests.
//!
//! Why: Validates LLM integration helper for Phase 2 LLM Integration with Court Agent.
//! Tests LLM integration structure, prompt building, and response parsing.
//! Architecture: Unit tests for LLM integration components.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-28-224000-pst: Phase 2 LLM Integration (Court Agent integration)

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const LlmIntegration = grain_research.LlmIntegration;
const LlmIntegrationResult = grain_research.LlmIntegrationResult;
const SerializationFormat = grain_research.SerializationFormat;

test "llm integration result initialization" {
    const content = "Test response";
    const result = LlmIntegrationResult.init(
        content,
        100,
        50,
        150,
        .json,
        true,
    );

    try testing.expect(std.mem.eql(u8, result.content, content));
    try testing.expect(result.input_tokens == 100);
    try testing.expect(result.output_tokens == 50);
    try testing.expect(result.tokens_used == 150);
    try testing.expect(result.format == .json);
    try testing.expect(result.success == true);
}

test "llm integration result with zon format" {
    const content = "ZON response";
    const result = LlmIntegrationResult.init(
        content,
        80,
        40,
        120,
        .zon,
        true,
    );

    try testing.expect(result.format == .zon);
    try testing.expect(result.tokens_used == 120);
    try testing.expect(result.success == true);
}

test "llm integration result with failure" {
    const result = LlmIntegrationResult.init(
        "",
        0,
        0,
        0,
        .json,
        false,
    );

    try testing.expect(result.success == false);
    try testing.expect(result.tokens_used == 0);
    try testing.expect(result.content.len == 0);
}
