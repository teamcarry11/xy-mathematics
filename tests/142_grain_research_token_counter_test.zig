//! Tests for Grain Research Token Counter.
//!
//! Why: Verify token counting capabilities for ZON format validation.
//! Architecture: Comprehensive test coverage for token counting APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-083221-pst: ZON Format Token Efficiency Validation Phase 1

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const TokenCounter = grain_research.TokenCounter;
const TokenCountResult = grain_research.TokenCountResult;
const LLMProvider = grain_research.LLMProvider;

test "token counter initialization" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    try testing.expect(counter.allocator.ptr != null);
}

test "count tokens for gpt4o" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    const text = "Hello, world!";
    const result = try counter.count_tokens(text, .gpt4o);

    try testing.expect(result.provider == .gpt4o);
    try testing.expect(result.token_count > 0);
    try testing.expect(result.text_len == text.len);
    try testing.expect(result.chars_per_token > 0.0);
}

test "count tokens for claude35" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    const text = "Hello, world!";
    const result = try counter.count_tokens(text, .claude35);

    try testing.expect(result.provider == .claude35);
    try testing.expect(result.token_count > 0);
    try testing.expect(result.text_len == text.len);
}

test "count tokens for llama3" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    const text = "Hello, world!";
    const result = try counter.count_tokens(text, .llama3);

    try testing.expect(result.provider == .llama3);
    try testing.expect(result.token_count > 0);
    try testing.expect(result.text_len == text.len);
}

test "calculate token reduction percent" {
    const allocator = testing.allocator;
    var counter = TokenCounter.init(allocator);

    const json_tokens: u32 = 100;
    const zon_tokens: u32 = 50;
    const reduction = counter.calculate_reduction_percent(json_tokens, zon_tokens);

    try testing.expect(reduction == 50);
}

test "token count result initialization" {
    const result = TokenCountResult.init(.gpt4o, 100, 400);

    try testing.expect(result.provider == .gpt4o);
    try testing.expect(result.token_count == 100);
    try testing.expect(result.text_len == 400);
    try testing.expect(result.chars_per_token == 4.0);
}
