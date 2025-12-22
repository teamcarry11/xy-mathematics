//! ZON Format Cost Savings Tests.
//!
//! Why: Validates cost savings calculations for ZON format token reduction.
//! Tests cost savings estimation across use cases and providers.
//! Architecture: Usage pattern estimation, cost calculation, savings projection.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-154500-pst: ZON Format Token Efficiency Validation Phase 3

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const CostSavingsCalculator = grain_research.CostSavingsCalculator;
const UseCase = grain_research.UseCase;
const Pricing = grain_research.Pricing;
const LLMProvider = grain_research.LLMProvider;

test "calculate cost savings for workflow metrics use case" {
    const allocator = testing.allocator;
    var calculator = CostSavingsCalculator.init(allocator);
    defer calculator.deinit();

    // Create use case: Workflow metrics export.
    // JSON: 1000 tokens/request, ZON: 600 tokens/request (40% reduction).
    const use_case = UseCase.init(
        "Workflow Metrics Export",
        1000,  // 1000 requests/month
        1000,  // 1000 tokens/request (JSON)
        600,   // 600 tokens/request (ZON, 40% reduction)
        .gpt4o,
    );
    try calculator.add_use_case(use_case);

    // Calculate cost savings.
    const pricing = Pricing.get_default(.gpt4o);
    const output_tokens_per_request: u32 = 500; // 500 output tokens/request
    const result = try calculator.calculate_cost_savings(use_case, pricing, output_tokens_per_request);

    // Verify cost savings.
    try testing.expect(result.json_cost_total > result.zon_cost_total);
    try testing.expect(result.savings_total > 0.0);
    try testing.expect(result.savings_percent > 0.0);
    try testing.expect(result.savings_percent < 50.0); // Should be ~40% reduction on input
}

test "calculate cost savings for multiple use cases" {
    const allocator = testing.allocator;
    var calculator = CostSavingsCalculator.init(allocator);
    defer calculator.deinit();

    // Add multiple use cases.
    const use_case1 = UseCase.init("Workflow Metrics", 1000, 1000, 600, .gpt4o);
    const use_case2 = UseCase.init("AI Graph Insights", 500, 2000, 1200, .gpt4o);
    const use_case3 = UseCase.init("Code Context", 200, 5000, 3000, .gpt4o);

    try calculator.add_use_case(use_case1);
    try calculator.add_use_case(use_case2);
    try calculator.add_use_case(use_case3);

    // Calculate cost savings for each.
    const pricing = Pricing.get_default(.gpt4o);
    const output_tokens_per_request: u32 = 500;

    const result1 = try calculator.calculate_cost_savings(use_case1, pricing, output_tokens_per_request);
    const result2 = try calculator.calculate_cost_savings(use_case2, pricing, output_tokens_per_request);
    const result3 = try calculator.calculate_cost_savings(use_case3, pricing, output_tokens_per_request);

    // Verify all have savings.
    try testing.expect(result1.savings_total > 0.0);
    try testing.expect(result2.savings_total > 0.0);
    try testing.expect(result3.savings_total > 0.0);

    // Calculate total savings.
    const total_savings = calculator.calculate_total_savings();
    try testing.expect(total_savings > 0.0);
    try testing.expect(total_savings == result1.savings_total + result2.savings_total + result3.savings_total);
}

test "calculate cost savings for different providers" {
    const allocator = testing.allocator;
    var calculator = CostSavingsCalculator.init(allocator);
    defer calculator.deinit();

    // Create use case for GPT-4o.
    const use_case_gpt4o = UseCase.init("GPT-4o Use Case", 1000, 1000, 600, .gpt4o);
    try calculator.add_use_case(use_case_gpt4o);

    // Create use case for Claude 3.5.
    const use_case_claude = UseCase.init("Claude 3.5 Use Case", 1000, 1000, 600, .claude35);
    try calculator.add_use_case(use_case_claude);

    // Calculate cost savings for each provider.
    const pricing_gpt4o = Pricing.get_default(.gpt4o);
    const pricing_claude = Pricing.get_default(.claude35);
    const output_tokens_per_request: u32 = 500;

    const result_gpt4o = try calculator.calculate_cost_savings(use_case_gpt4o, pricing_gpt4o, output_tokens_per_request);
    const result_claude = try calculator.calculate_cost_savings(use_case_claude, pricing_claude, output_tokens_per_request);

    // Verify both have savings.
    try testing.expect(result_gpt4o.savings_total > 0.0);
    try testing.expect(result_claude.savings_total > 0.0);

    // Verify savings percentages are similar (same token reduction).
    try testing.expect(result_gpt4o.savings_percent > 0.0);
    try testing.expect(result_claude.savings_percent > 0.0);
}

test "calculate cost savings with zero output tokens" {
    const allocator = testing.allocator;
    var calculator = CostSavingsCalculator.init(allocator);
    defer calculator.deinit();

    // Create use case.
    const use_case = UseCase.init("Zero Output Use Case", 1000, 1000, 600, .gpt4o);
    try calculator.add_use_case(use_case);

    // Calculate with zero output tokens.
    const pricing = Pricing.get_default(.gpt4o);
    const output_tokens_per_request: u32 = 0;
    const result = try calculator.calculate_cost_savings(use_case, pricing, output_tokens_per_request);

    // Verify savings come only from input tokens.
    try testing.expect(result.json_cost_output == 0.0);
    try testing.expect(result.zon_cost_output == 0.0);
    try testing.expect(result.savings_output == 0.0);
    try testing.expect(result.savings_input > 0.0);
    try testing.expect(result.savings_total > 0.0);
}

test "calculate cost savings with high token reduction" {
    const allocator = testing.allocator;
    var calculator = CostSavingsCalculator.init(allocator);
    defer calculator.deinit();

    // Create use case with 50% token reduction.
    const use_case = UseCase.init(
        "High Reduction Use Case",
        1000,  // 1000 requests/month
        2000,  // 2000 tokens/request (JSON)
        1000,  // 1000 tokens/request (ZON, 50% reduction)
        .gpt4o,
    );
    try calculator.add_use_case(use_case);

    // Calculate cost savings.
    const pricing = Pricing.get_default(.gpt4o);
    const output_tokens_per_request: u32 = 500;
    const result = try calculator.calculate_cost_savings(use_case, pricing, output_tokens_per_request);

    // Verify high savings percentage.
    try testing.expect(result.savings_percent > 40.0); // Should be ~50% on input
    try testing.expect(result.savings_total > 0.0);
}
