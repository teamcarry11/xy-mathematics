//! Grain Court Token Efficiency: Token counting and cost tracking for LLM operations.
//!
//! Why: Enable token efficiency optimization and cost tracking per provider.
//! Architecture: Token counting utilities, cost tracking, efficiency metrics.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! Provider Pricing (as of 2025-12-28):
//! - OpenAI GPT-4o: $2.50/1k input, $10.00/1k output
//! - Anthropic Claude 3.5 Sonnet: $3.00/1k input, $15.00/1k output
//! - Mistral Large: $2.00/1k input, $6.00/1k output
//! - Cerebras GLM-4.6: $1.875/1k input, $7.50/1k output (Developer tier, ~25% cheaper)

const std = @import("std");
const llm_provider = @import("llm_provider.zig");

// Bounded: Max tokens per request.
pub const MAX_TOKENS_PER_REQUEST: u32 = 1_000_000;

// Bounded: Max cost tracking entries.
pub const MAX_COST_ENTRIES: u32 = 10_000;

// Bounded: Max provider name length.
pub const MAX_PROVIDER_NAME_LEN: u32 = 64;

// Bounded: Max model name length.
pub const MAX_MODEL_NAME_LEN: u32 = 128;

// Token count result.
pub const TokenCountResult = struct {
    input_tokens: u32,
    output_tokens: u32,
    total_tokens: u32,
};

// Cost entry for tracking.
pub const CostEntry = struct {
    provider_type: llm_provider.ProviderType,
    model: [MAX_MODEL_NAME_LEN]u8,
    model_len: u32,
    input_tokens: u32,
    output_tokens: u32,
    cost_usd: f64,
    timestamp: u64,
};

// Cost tracker.
pub const CostTracker = struct {
    entries: [MAX_COST_ENTRIES]?CostEntry,
    entries_len: u32,
    total_cost_usd: f64,

    pub fn init() CostTracker {
        var tracker = CostTracker{
            .entries = undefined,
            .entries_len = 0,
            .total_cost_usd = 0.0,
        };
        var i: u32 = 0;
        while (i < MAX_COST_ENTRIES) : (i += 1) {
            tracker.entries[i] = null;
        }
        std.debug.assert(tracker.entries_len == 0);
        std.debug.assert(tracker.total_cost_usd == 0.0);
        return tracker;
    }

    pub fn add_cost_entry(
        self: *CostTracker,
        provider_type: llm_provider.ProviderType,
        model: []const u8,
        input_tokens: u32,
        output_tokens: u32,
        cost_usd: f64,
    ) bool {
        std.debug.assert(model.len > 0);
        std.debug.assert(model.len <= MAX_MODEL_NAME_LEN);
        std.debug.assert(input_tokens <= MAX_TOKENS_PER_REQUEST);
        std.debug.assert(output_tokens <= MAX_TOKENS_PER_REQUEST);
        if (self.entries_len >= MAX_COST_ENTRIES) {
            return false;
        }
        const timestamp = std.time.nanoTimestamp();
        var entry = CostEntry{
            .provider_type = provider_type,
            .model = undefined,
            .model_len = 0,
            .input_tokens = input_tokens,
            .output_tokens = output_tokens,
            .cost_usd = cost_usd,
            .timestamp = @as(u64, @intCast(timestamp)),
        };
        var i: u32 = 0;
        while (i < MAX_MODEL_NAME_LEN) : (i += 1) {
            entry.model[i] = 0;
        }
        i = 0;
        const model_len = @min(model.len, MAX_MODEL_NAME_LEN);
        while (i < model_len) : (i += 1) {
            entry.model[i] = model[i];
        }
        entry.model_len = model_len;
        i = 0;
        while (i < MAX_COST_ENTRIES) : (i += 1) {
            if (self.entries[i] == null) {
                self.entries[i] = entry;
                self.entries_len += 1;
                self.total_cost_usd += cost_usd;
                std.debug.assert(self.entries_len <= MAX_COST_ENTRIES);
                return true;
            }
        }
        return false;
    }

    pub fn get_total_cost(self: *const CostTracker) f64 {
        std.debug.assert(self.total_cost_usd >= 0.0);
        return self.total_cost_usd;
    }

    pub fn get_cost_by_provider(
        self: *const CostTracker,
        provider_type: llm_provider.ProviderType,
    ) f64 {
        std.debug.assert(@intFromEnum(provider_type) < 4);
        var total: f64 = 0.0;
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i]) |entry| {
                if (entry.provider_type == provider_type) {
                    total += entry.cost_usd;
                }
            }
        }
        std.debug.assert(total >= 0.0);
        return total;
    }
};

// Estimate token count for text (rough approximation).
pub fn estimate_token_count(text: []const u8) u32 {
    std.debug.assert(text.len > 0);
    if (text.len == 0) {
        return 0;
    }
    const chars = text.len;
    const estimated = (chars / 4) + 1;
    if (estimated > MAX_TOKENS_PER_REQUEST) {
        return MAX_TOKENS_PER_REQUEST;
    }
    std.debug.assert(estimated <= MAX_TOKENS_PER_REQUEST);
    return @intCast(estimated);
}

// Calculate cost for OpenAI (GPT-4o pricing).
pub fn calculate_openai_cost(
    input_tokens: u32,
    output_tokens: u32,
) f64 {
    std.debug.assert(input_tokens <= MAX_TOKENS_PER_REQUEST);
    std.debug.assert(output_tokens <= MAX_TOKENS_PER_REQUEST);
    const input_cost_per_1k: f64 = 2.50;
    const output_cost_per_1k: f64 = 10.00;
    const input_cost = (@as(f64, @floatFromInt(input_tokens)) / 1000.0) * input_cost_per_1k;
    const output_cost = (@as(f64, @floatFromInt(output_tokens)) / 1000.0) * output_cost_per_1k;
    const total = input_cost + output_cost;
    std.debug.assert(total >= 0.0);
    return total;
}

// Calculate cost for Anthropic (Claude 3.5 Sonnet pricing).
pub fn calculate_anthropic_cost(
    input_tokens: u32,
    output_tokens: u32,
) f64 {
    std.debug.assert(input_tokens <= MAX_TOKENS_PER_REQUEST);
    std.debug.assert(output_tokens <= MAX_TOKENS_PER_REQUEST);
    const input_cost_per_1k: f64 = 3.00;
    const output_cost_per_1k: f64 = 15.00;
    const input_cost = (@as(f64, @floatFromInt(input_tokens)) / 1000.0) * input_cost_per_1k;
    const output_cost = (@as(f64, @floatFromInt(output_tokens)) / 1000.0) * output_cost_per_1k;
    const total = input_cost + output_cost;
    std.debug.assert(total >= 0.0);
    return total;
}

// Calculate cost for Mistral (Mistral Large pricing).
pub fn calculate_mistral_cost(
    input_tokens: u32,
    output_tokens: u32,
) f64 {
    std.debug.assert(input_tokens <= MAX_TOKENS_PER_REQUEST);
    std.debug.assert(output_tokens <= MAX_TOKENS_PER_REQUEST);
    const input_cost_per_1k: f64 = 2.00;
    const output_cost_per_1k: f64 = 6.00;
    const input_cost = (@as(f64, @floatFromInt(input_tokens)) / 1000.0) * input_cost_per_1k;
    const output_cost = (@as(f64, @floatFromInt(output_tokens)) / 1000.0) * output_cost_per_1k;
    const total = input_cost + output_cost;
    std.debug.assert(total >= 0.0);
    return total;
}

// Calculate cost for Cerebras GLM-4.6 (Developer tier pricing, ~25% cheaper than comparable models).
pub fn calculate_cerebras_cost(
    input_tokens: u32,
    output_tokens: u32,
) f64 {
    std.debug.assert(input_tokens <= MAX_TOKENS_PER_REQUEST);
    std.debug.assert(output_tokens <= MAX_TOKENS_PER_REQUEST);
    const input_cost_per_1k: f64 = 1.875;
    const output_cost_per_1k: f64 = 7.50;
    const input_cost = (@as(f64, @floatFromInt(input_tokens)) / 1000.0) * input_cost_per_1k;
    const output_cost = (@as(f64, @floatFromInt(output_tokens)) / 1000.0) * output_cost_per_1k;
    const total = input_cost + output_cost;
    std.debug.assert(total >= 0.0);
    return total;
}

// Calculate cost for provider.
pub fn calculate_provider_cost(
    provider_type: llm_provider.ProviderType,
    input_tokens: u32,
    output_tokens: u32,
) f64 {
    std.debug.assert(input_tokens <= MAX_TOKENS_PER_REQUEST);
    std.debug.assert(output_tokens <= MAX_TOKENS_PER_REQUEST);
    std.debug.assert(@intFromEnum(provider_type) < 4);
    switch (provider_type) {
        .openai => return calculate_openai_cost(input_tokens, output_tokens),
        .anthropic => return calculate_anthropic_cost(input_tokens, output_tokens),
        .mistral => return calculate_mistral_cost(input_tokens, output_tokens),
        .self_hosted => return calculate_cerebras_cost(input_tokens, output_tokens),
    }
}

// Calculate token efficiency (tokens per character).
pub fn calculate_token_efficiency(
    text: []const u8,
    token_count: u32,
) f64 {
    std.debug.assert(text.len > 0);
    std.debug.assert(token_count > 0);
    if (text.len == 0) {
        return 0.0;
    }
    const efficiency = @as(f64, @floatFromInt(token_count)) / @as(f64, @floatFromInt(text.len));
    std.debug.assert(efficiency >= 0.0);
    return efficiency;
}

// Calculate cost from LLM response.
pub fn calculate_response_cost(
    response: *const llm_provider.LlmResponse,
) f64 {
    std.debug.assert(response != null);
    const input_tokens = if (response.input_tokens > 0) response.input_tokens else response.tokens_used / 2;
    const output_tokens = if (response.output_tokens > 0) response.output_tokens else response.tokens_used / 2;
    return calculate_provider_cost(response.provider_type, input_tokens, output_tokens);
}

// Track cost from LLM response.
pub fn track_response_cost(
    tracker: *CostTracker,
    response: *const llm_provider.LlmResponse,
    model: []const u8,
) bool {
    std.debug.assert(tracker != null);
    std.debug.assert(response != null);
    std.debug.assert(model.len > 0);
    const input_tokens = if (response.input_tokens > 0) response.input_tokens else response.tokens_used / 2;
    const output_tokens = if (response.output_tokens > 0) response.output_tokens else response.tokens_used / 2;
    const cost = calculate_response_cost(response);
    return tracker.add_cost_entry(
        response.provider_type,
        model,
        input_tokens,
        output_tokens,
        cost,
    );
}
