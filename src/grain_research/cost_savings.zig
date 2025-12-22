//! Grain Research Cost Savings: Calculate cost savings from ZON format token reduction.
//!
//! Why: Estimates cost savings from ZON format token reduction for LLM API usage.
//! Enables cost-benefit analysis and ROI calculations for ZON format adoption.
//! Architecture: Usage pattern estimation, cost calculation, savings projection.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-154500-pst: ZON Format Token Efficiency Validation Phase 3

const std = @import("std");
const token_counter = @import("token_counter.zig");
const LLMProvider = token_counter.LLMProvider;

// Bounded: Max use cases.
pub const MAX_USE_CASES: u32 = 100;

// Bounded: Max requests per month.
pub const MAX_REQUESTS_PER_MONTH: u32 = 10_000_000;

// Bounded: Max tokens per request.
pub const MAX_TOKENS_PER_REQUEST: u32 = 1_000_000;

// Use case: Represents a use case for cost savings calculation.
pub const UseCase = struct {
    name: []const u8,
    requests_per_month: u32,
    tokens_per_request_json: u32,
    tokens_per_request_zon: u32,
    provider: LLMProvider,

    pub fn init(
        name: []const u8,
        requests_per_month: u32,
        tokens_per_request_json: u32,
        tokens_per_request_zon: u32,
        provider: LLMProvider,
    ) UseCase {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= 128);
        std.debug.assert(requests_per_month > 0);
        std.debug.assert(requests_per_month <= MAX_REQUESTS_PER_MONTH);
        std.debug.assert(tokens_per_request_json > 0);
        std.debug.assert(tokens_per_request_json <= MAX_TOKENS_PER_REQUEST);
        std.debug.assert(tokens_per_request_zon > 0);
        std.debug.assert(tokens_per_request_zon <= MAX_TOKENS_PER_REQUEST);
        // Note: ZON tokens should be <= JSON tokens (reduction), but allow equal for testing.

        return UseCase{
            .name = name,
            .requests_per_month = requests_per_month,
            .tokens_per_request_json = tokens_per_request_json,
            .tokens_per_request_zon = tokens_per_request_zon,
            .provider = provider,
        };
    }
};

// Pricing: LLM provider pricing per 1K tokens.
pub const Pricing = struct {
    provider: LLMProvider,
    input_price_per_1k: f32,  // Price per 1K input tokens
    output_price_per_1k: f32, // Price per 1K output tokens

    pub fn init(
        provider: LLMProvider,
        input_price_per_1k: f32,
        output_price_per_1k: f32,
    ) Pricing {
        std.debug.assert(input_price_per_1k >= 0.0);
        std.debug.assert(output_price_per_1k >= 0.0);

        return Pricing{
            .provider = provider,
            .input_price_per_1k = input_price_per_1k,
            .output_price_per_1k = output_price_per_1k,
        };
    }

    // Get default pricing for provider.
    pub fn get_default(provider: LLMProvider) Pricing {
        return switch (provider) {
            .gpt4o => Pricing.init(provider, 0.01, 0.03), // $0.01/1K input, $0.03/1K output
            .claude35 => Pricing.init(provider, 0.003, 0.015), // $0.003/1K input, $0.015/1K output
            .llama3 => Pricing.init(provider, 0.0002, 0.0002), // $0.0002/1K input, $0.0002/1K output
            .custom => Pricing.init(provider, 0.01, 0.03), // Default pricing
        };
    }
};

// Cost calculation result.
pub const CostResult = struct {
    use_case_name: []const u8,
    provider: LLMProvider,
    json_cost_input: f32,
    json_cost_output: f32,
    json_cost_total: f32,
    zon_cost_input: f32,
    zon_cost_output: f32,
    zon_cost_total: f32,
    savings_input: f32,
    savings_output: f32,
    savings_total: f32,
    savings_percent: f32,

    pub fn init(
        use_case_name: []const u8,
        provider: LLMProvider,
        json_cost_input: f32,
        json_cost_output: f32,
        json_cost_total: f32,
        zon_cost_input: f32,
        zon_cost_output: f32,
        zon_cost_total: f32,
    ) CostResult {
        const savings_input = json_cost_input - zon_cost_input;
        const savings_output = json_cost_output - zon_cost_output;
        const savings_total = json_cost_total - zon_cost_total;
        const savings_percent = if (json_cost_total > 0.0)
            (savings_total / json_cost_total) * 100.0
        else
            0.0;

        return CostResult{
            .use_case_name = use_case_name,
            .provider = provider,
            .json_cost_input = json_cost_input,
            .json_cost_output = json_cost_output,
            .json_cost_total = json_cost_total,
            .zon_cost_input = zon_cost_input,
            .zon_cost_output = zon_cost_output,
            .zon_cost_total = zon_cost_total,
            .savings_input = savings_input,
            .savings_output = savings_output,
            .savings_total = savings_total,
            .savings_percent = savings_percent,
        };
    }
};

// Cost savings calculator: Calculates cost savings for use cases.
pub const CostSavingsCalculator = struct {
    allocator: std.mem.Allocator,
    use_cases: std.ArrayList(UseCase),
    results: std.ArrayList(CostResult),

    // Initialize calculator.
    pub fn init(allocator: std.mem.Allocator) CostSavingsCalculator {
        return CostSavingsCalculator{
            .allocator = allocator,
            .use_cases = std.ArrayList(UseCase).init(allocator),
            .results = std.ArrayList(CostResult).init(allocator),
        };
    }

    // Deinitialize calculator.
    pub fn deinit(self: *CostSavingsCalculator) void {
        self.use_cases.deinit();
        self.results.deinit();
    }

    // Add use case.
    pub fn add_use_case(self: *CostSavingsCalculator, use_case: UseCase) !void {
        std.debug.assert(self.use_cases.items.len < MAX_USE_CASES);
        try self.use_cases.append(self.allocator, use_case);
    }

    // Calculate cost savings for use case.
    pub fn calculate_cost_savings(
        self: *CostSavingsCalculator,
        use_case: UseCase,
        pricing: Pricing,
        output_tokens_per_request: u32,
    ) !CostResult {
        std.debug.assert(output_tokens_per_request > 0);
        std.debug.assert(output_tokens_per_request <= MAX_TOKENS_PER_REQUEST);

        // Calculate JSON costs.
        const json_input_tokens = use_case.requests_per_month * use_case.tokens_per_request_json;
        const json_output_tokens = use_case.requests_per_month * output_tokens_per_request;
        const json_cost_input = (@as(f32, @floatFromInt(json_input_tokens)) / 1000.0) * pricing.input_price_per_1k;
        const json_cost_output = (@as(f32, @floatFromInt(json_output_tokens)) / 1000.0) * pricing.output_price_per_1k;
        const json_cost_total = json_cost_input + json_cost_output;

        // Calculate ZON costs.
        const zon_input_tokens = use_case.requests_per_month * use_case.tokens_per_request_zon;
        const zon_output_tokens = use_case.requests_per_month * output_tokens_per_request;
        const zon_cost_input = (@as(f32, @floatFromInt(zon_input_tokens)) / 1000.0) * pricing.input_price_per_1k;
        const zon_cost_output = (@as(f32, @floatFromInt(zon_output_tokens)) / 1000.0) * pricing.output_price_per_1k;
        const zon_cost_total = zon_cost_input + zon_cost_output;

        // Create result.
        const result = CostResult.init(
            use_case.name,
            use_case.provider,
            json_cost_input,
            json_cost_output,
            json_cost_total,
            zon_cost_input,
            zon_cost_output,
            zon_cost_total,
        );

        try self.results.append(self.allocator, result);
        return result;
    }

    // Calculate total savings across all use cases.
    pub fn calculate_total_savings(self: *const CostSavingsCalculator) f32 {
        var total_savings: f32 = 0.0;
        for (self.results.items) |result| {
            total_savings += result.savings_total;
        }
        return total_savings;
    }

    // Get all results.
    pub fn get_results(self: *const CostSavingsCalculator) []const CostResult {
        return self.results.items;
    }
};
