//! Token Counting Adapter Tests: Test unified token counting interface.
//!
//! Why: Validates token counting adapter integration with Court Agent and
//! Research Agent token counting approaches.
//! Architecture: Unit tests for adapter functionality, approach comparison.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-28-224000-pst: Phase 2 Token Counting Integration

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const TokenCountingAdapter = grain_research.TokenCountingAdapter;
const TokenCountingApproach = grain_research.TokenCountingApproach;
const LLMProvider = grain_research.LLMProvider;

test "token counting adapter init" {
    const allocator = testing.allocator;
    var adapter = TokenCountingAdapter.init(allocator);
    _ = adapter; // Adapter initialized successfully
}

test "estimate tokens with research provider specific approach" {
    const allocator = testing.allocator;
    var adapter = TokenCountingAdapter.init(allocator);

    const text = "Hello, world! This is a test.";
    const result = try adapter.estimate_tokens_unified(
        text,
        .gpt4o,
        .research_provider_specific,
    );

    try testing.expect(result.token_count > 0);
    try testing.expect(result.approach_used == .research_provider_specific);
    try testing.expect(result.provider == .gpt4o);
    try testing.expect(result.text_len == text.len);
    try testing.expect(result.chars_per_token > 0);
}

test "estimate tokens with court character based approach" {
    const allocator = testing.allocator;
    var adapter = TokenCountingAdapter.init(allocator);

    const text = "Hello, world! This is a test.";
    const result = adapter.estimate_tokens_unified(
        text,
        .gpt4o,
        .court_character_based,
    );

    try testing.expect(result.token_count > 0);
    try testing.expect(result.approach_used == .court_character_based);
    try testing.expect(result.provider == .gpt4o);
    try testing.expect(result.text_len == text.len);
    try testing.expect(result.chars_per_token > 0);
}

test "estimate tokens with auto fallback approach" {
    const allocator = testing.allocator;
    var adapter = TokenCountingAdapter.init(allocator);

    const text = "Hello, world! This is a test.";
    const result = try adapter.estimate_tokens_unified(
        text,
        .gpt4o,
        .auto_fallback,
    );

    try testing.expect(result.token_count > 0);
    try testing.expect(result.provider == .gpt4o);
    try testing.expect(result.text_len == text.len);
    try testing.expect(result.chars_per_token > 0);
}

test "compare approaches for same text" {
    const allocator = testing.allocator;
    var adapter = TokenCountingAdapter.init(allocator);

    const text = "Hello, world! This is a test.";
    const comparison = try adapter.compare_approaches(text, .gpt4o);

    try testing.expect(comparison.research_count > 0);
    try testing.expect(comparison.court_count > 0);
    try testing.expect(comparison.difference_percent >= 0);
}

test "compare approaches for different providers" {
    const allocator = testing.allocator;
    var adapter = TokenCountingAdapter.init(allocator);

    const text = "Hello, world! This is a test.";

    const gpt4o_comparison = try adapter.compare_approaches(text, .gpt4o);
    const claude35_comparison = try adapter.compare_approaches(text, .claude35);

    try testing.expect(gpt4o_comparison.research_count > 0);
    try testing.expect(claude35_comparison.research_count > 0);
    try testing.expect(gpt4o_comparison.court_count > 0);
    try testing.expect(claude35_comparison.court_count > 0);
}

test "estimate tokens for empty text fails" {
    const allocator = testing.allocator;
    var adapter = TokenCountingAdapter.init(allocator);

    const text = "";
    const result = adapter.estimate_tokens_unified(
        text,
        .gpt4o,
        .court_character_based,
    );

    // Court Agent's estimate_token_count returns 0 for empty text
    // (handled by assertion in adapter)
    _ = result;
}

test "estimate tokens for long text" {
    const allocator = testing.allocator;
    var adapter = TokenCountingAdapter.init(allocator);

    // Create a long text (within bounds)
    var text_buf: [1000]u8 = undefined;
    @memset(&text_buf, 'a');
    const text = text_buf[0..];

    const result = try adapter.estimate_tokens_unified(
        text,
        .gpt4o,
        .research_provider_specific,
    );

    try testing.expect(result.token_count > 0);
    try testing.expect(result.text_len == text.len);
}
