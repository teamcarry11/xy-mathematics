//! Grain Research Token Counting Adapter: Unified token counting interface.
//!
//! Why: Integrates Court Agent's character-based token estimation with Research
//! Agent's provider-specific token estimation. Enables comparison and fallback
//! between approaches for validation.
//! Architecture: Adapter pattern, unified interface, fallback support.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-28-224000-pst: Phase 2 Token Counting Integration

const std = @import("std");
const token_counter = @import("token_counter.zig");
const grain_court = @import("grain_court");

// Token counting approach selection.
pub const TokenCountingApproach = enum(u8) {
    research_provider_specific = 0, // Research Agent's provider-specific estimation
    court_character_based = 1, // Court Agent's character-based approximation
    auto_fallback = 2, // Auto: Try Research Agent, fallback to Court Agent
};

// Unified token count result.
pub const UnifiedTokenCountResult = struct {
    token_count: u32,
    approach_used: TokenCountingApproach,
    provider: token_counter.LLMProvider,
    text_len: u32,
    chars_per_token: f32,

    pub fn init(
        token_count: u32,
        approach_used: TokenCountingApproach,
        provider: token_counter.LLMProvider,
        text_len: u32,
    ) UnifiedTokenCountResult {
        std.debug.assert(token_count <= token_counter.MAX_TOKEN_COUNT);
        std.debug.assert(text_len <= token_counter.MAX_TEXT_LEN);
        std.debug.assert(text_len > 0);

        const chars_per_token = if (token_count > 0)
            @as(f32, @floatFromInt(text_len)) / @as(f32, @floatFromInt(token_count))
        else
            0.0;

        return UnifiedTokenCountResult{
            .token_count = token_count,
            .approach_used = approach_used,
            .provider = provider,
            .text_len = text_len,
            .chars_per_token = chars_per_token,
        };
    }
};

// Token counting adapter: Unified interface for token counting.
pub const TokenCountingAdapter = struct {
    allocator: std.mem.Allocator,
    research_counter: token_counter.TokenCounter,

    // Initialize token counting adapter.
    pub fn init(allocator: std.mem.Allocator) TokenCountingAdapter {
        return TokenCountingAdapter{
            .allocator = allocator,
            .research_counter = token_counter.TokenCounter.init(allocator),
        };
    }

    // Estimate tokens using unified interface.
    // Uses Research Agent's provider-specific estimation by default,
    // with fallback to Court Agent's character-based estimation.
    pub fn estimate_tokens_unified(
        self: *const TokenCountingAdapter,
        text: []const u8,
        provider: token_counter.LLMProvider,
        approach: TokenCountingApproach,
    ) !UnifiedTokenCountResult {
        std.debug.assert(text.len > 0);
        std.debug.assert(text.len <= token_counter.MAX_TEXT_LEN);

        const text_len = @as(u32, @intCast(text.len));

        const result = switch (approach) {
            .research_provider_specific => try self.estimate_with_research(text, provider, text_len),
            .court_character_based => self.estimate_with_court(text, provider, text_len),
            .auto_fallback => try self.estimate_with_fallback(text, provider, text_len),
        };

        return result;
    }

    // Estimate using Research Agent's provider-specific estimation.
    fn estimate_with_research(
        self: *const TokenCountingAdapter,
        text: []const u8,
        provider: token_counter.LLMProvider,
        text_len: u32,
    ) !UnifiedTokenCountResult {
        const result = try self.research_counter.count_tokens(text, provider);
        return UnifiedTokenCountResult.init(
            result.token_count,
            .research_provider_specific,
            provider,
            text_len,
        );
    }

    // Estimate using Court Agent's character-based approximation.
    fn estimate_with_court(
        self: *const TokenCountingAdapter,
        text: []const u8,
        provider: token_counter.LLMProvider,
        text_len: u32,
    ) UnifiedTokenCountResult {
        const token_count = grain_court.TokenEfficiency.estimate_token_count(text);
        return UnifiedTokenCountResult.init(
            token_count,
            .court_character_based,
            provider,
            text_len,
        );
    }

    // Estimate with auto-fallback: Try Research Agent, fallback to Court Agent.
    fn estimate_with_fallback(
        self: *const TokenCountingAdapter,
        text: []const u8,
        provider: token_counter.LLMProvider,
        text_len: u32,
    ) !UnifiedTokenCountResult {
        // Try Research Agent's provider-specific estimation first.
        const research_result = self.estimate_with_research(text, provider, text_len) catch |err| {
            // Fallback to Court Agent's character-based estimation.
            return self.estimate_with_court(text, provider, text_len);
        };
        return research_result;
    }

    // Compare token counts from both approaches.
    pub fn compare_approaches(
        self: *const TokenCountingAdapter,
        text: []const u8,
        provider: token_counter.LLMProvider,
    ) !struct {
        research_count: u32,
        court_count: u32,
        difference: i32,
        difference_percent: f32,
    } {
        std.debug.assert(text.len > 0);
        std.debug.assert(text.len <= token_counter.MAX_TEXT_LEN);

        const research_result = try self.estimate_with_research(text, provider, @as(u32, @intCast(text.len)));
        const court_result = self.estimate_with_court(text, provider, @as(u32, @intCast(text.len)));

        const research_count = research_result.token_count;
        const court_count = court_result.token_count;
        const difference = @as(i32, @intCast(research_count)) - @as(i32, @intCast(court_count));

        const difference_percent = if (research_count > 0)
            (@as(f32, @floatFromInt(@abs(difference))) / @as(f32, @floatFromInt(research_count))) * 100.0
        else
            0.0;

        return .{
            .research_count = research_count,
            .court_count = court_count,
            .difference = difference,
            .difference_percent = difference_percent,
        };
    }
};
