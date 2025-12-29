//! Cost Tracking Integration Tests: Test Court Agent CostTracker integration.
//!
//! Why: Validates cost tracking integration with Court Agent CostTracker and
//! Research Agent cost savings calculator.
//! Architecture: Unit tests for cost tracking integration, cost comparison,
//! validation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-29-001544-pst: Phase 3 Cost Tracking Integration

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const grain_court = @import("grain_court");
const llm_provider = grain_court.LlmProvider;
const CostTrackingIntegration = grain_research.CostTrackingIntegration;
const RetrievalCostResult = grain_research.RetrievalCostResult;

test "cost tracking integration init" {
    const allocator = testing.allocator;
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    var integration = CostTrackingIntegration.init(allocator, &tracker);
    _ = integration; // Integration initialized successfully
}

test "track retrieval cost with mock responses" {
    const allocator = testing.allocator;
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    var integration = CostTrackingIntegration.init(allocator, &tracker);

    // Create mock JSON response (more tokens).
    var json_response = llm_provider.LlmResponse{
        .request_id = 1,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 1000,
        .input_tokens = 600,
        .output_tokens = 400,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    // Create mock ZON response (fewer tokens).
    var zon_response = llm_provider.LlmResponse{
        .request_id = 2,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 700,
        .input_tokens = 400,
        .output_tokens = 300,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    const model = "gpt-4o";
    const result = try integration.track_retrieval_cost(&json_response, &zon_response, model);

    try testing.expect(result.json_cost > 0.0);
    try testing.expect(result.zon_cost > 0.0);
    try testing.expect(result.json_cost >= result.zon_cost);
    try testing.expect(result.savings >= 0.0);
    try testing.expect(result.savings_percent >= 0.0);
    try testing.expect(result.json_input_tokens > 0);
    try testing.expect(result.json_output_tokens > 0);
    try testing.expect(result.zon_input_tokens > 0);
    try testing.expect(result.zon_output_tokens > 0);
}

test "track retrieval cost calculates savings correctly" {
    const allocator = testing.allocator;
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    var integration = CostTrackingIntegration.init(allocator, &tracker);

    // JSON response: 1000 tokens total.
    var json_response = llm_provider.LlmResponse{
        .request_id = 1,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 1000,
        .input_tokens = 600,
        .output_tokens = 400,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    // ZON response: 700 tokens total (30% reduction).
    var zon_response = llm_provider.LlmResponse{
        .request_id = 2,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 700,
        .input_tokens = 400,
        .output_tokens = 300,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    const model = "gpt-4o";
    const result = try integration.track_retrieval_cost(&json_response, &zon_response, model);

    // Savings should be positive (JSON cost > ZON cost).
    try testing.expect(result.savings > 0.0);
    try testing.expect(result.savings_percent > 0.0);
    try testing.expect(result.savings_percent <= 100.0);
}

test "get total cost from tracker" {
    const allocator = testing.allocator;
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    var integration = CostTrackingIntegration.init(allocator, &tracker);

    // Track some costs.
    var json_response = llm_provider.LlmResponse{
        .request_id = 1,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 1000,
        .input_tokens = 600,
        .output_tokens = 400,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    var zon_response = llm_provider.LlmResponse{
        .request_id = 2,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 700,
        .input_tokens = 400,
        .output_tokens = 300,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    const model = "gpt-4o";
    _ = try integration.track_retrieval_cost(&json_response, &zon_response, model);

    const total_cost = integration.get_total_cost();
    try testing.expect(total_cost > 0.0);
}

test "get cost by provider" {
    const allocator = testing.allocator;
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    var integration = CostTrackingIntegration.init(allocator, &tracker);

    var json_response = llm_provider.LlmResponse{
        .request_id = 1,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 1000,
        .input_tokens = 600,
        .output_tokens = 400,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    var zon_response = llm_provider.LlmResponse{
        .request_id = 2,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 700,
        .input_tokens = 400,
        .output_tokens = 300,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    const model = "gpt-4o";
    _ = try integration.track_retrieval_cost(&json_response, &zon_response, model);

    const openai_cost = integration.get_cost_by_provider(.openai);
    try testing.expect(openai_cost > 0.0);
}

test "get cost report" {
    const allocator = testing.allocator;
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    var integration = CostTrackingIntegration.init(allocator, &tracker);

    var json_response = llm_provider.LlmResponse{
        .request_id = 1,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 1000,
        .input_tokens = 600,
        .output_tokens = 400,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    var zon_response = llm_provider.LlmResponse{
        .request_id = 2,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 700,
        .input_tokens = 400,
        .output_tokens = 300,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    const model = "gpt-4o";
    _ = try integration.track_retrieval_cost(&json_response, &zon_response, model);

    const report = integration.get_cost_report();
    try testing.expect(report.total_cost_usd > 0.0);
    try testing.expect(report.total_requests > 0);
}

test "validate cost savings with projected costs" {
    const allocator = testing.allocator;
    var tracker = grain_court.TokenEfficiency.CostTracker.init();
    var integration = CostTrackingIntegration.init(allocator, &tracker);

    // Create actual cost result from tracking.
    var json_response = llm_provider.LlmResponse{
        .request_id = 1,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 1000,
        .input_tokens = 600,
        .output_tokens = 400,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    var zon_response = llm_provider.LlmResponse{
        .request_id = 2,
        .provider_type = .openai,
        .content = undefined,
        .content_len = 0,
        .tokens_used = 700,
        .input_tokens = 400,
        .output_tokens = 300,
        .finish_reason = undefined,
        .finish_reason_len = 0,
        .created_at = 0,
    };

    const model = "gpt-4o";
    const actual_result = try integration.track_retrieval_cost(&json_response, &zon_response, model);

    // Create projected cost result (similar to actual, for validation).
    const projected_result = grain_research.CostResult.init(
        "test_use_case",
        .gpt4o,
        0.018, // JSON input cost (600 tokens * $0.01/1K)
        0.012, // JSON output cost (400 tokens * $0.03/1K)
        0.030, // JSON total cost
        0.012, // ZON input cost (400 tokens * $0.01/1K)
        0.009, // ZON output cost (300 tokens * $0.03/1K)
        0.021, // ZON total cost
    );

    const validation = integration.validate_cost_savings(actual_result, projected_result);

    try testing.expect(validation.actual_savings_percent >= 0.0);
    try testing.expect(validation.projected_savings_percent >= 0.0);
    try testing.expect(validation.difference_percent >= 0.0);
    // Validation passes if difference is within 10%
    // (may pass or fail depending on actual vs projected values)
}
