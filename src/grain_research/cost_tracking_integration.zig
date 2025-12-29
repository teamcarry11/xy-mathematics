//! Grain Research Cost Tracking Integration: Integrate Court Agent CostTracker
//! with Research Agent cost savings calculator.
//!
//! Why: Integrates Court Agent's actual cost tracking from LLM requests with
//! Research Agent's cost savings calculator for validation. Enables comparison
//! of JSON vs ZON format costs and validation of cost savings claims with actual
//! cost data.
//! Architecture: Integration layer between Court Agent CostTracker and Research
//! Agent cost savings calculator, cost comparison, validation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-29-001544-pst: Phase 3 Cost Tracking Integration

const std = @import("std");
const grain_court = @import("grain_court");
const llm_provider = grain_court.LlmProvider;
const cost_savings = @import("cost_savings.zig");

// Bounded: Max model name length.
pub const MAX_MODEL_LEN: u32 = 128;

// Retrieval cost tracking result.
pub const RetrievalCostResult = struct {
    json_cost: f64,
    zon_cost: f64,
    savings: f64,
    savings_percent: f32,
    json_input_tokens: u32,
    json_output_tokens: u32,
    zon_input_tokens: u32,
    zon_output_tokens: u32,

    pub fn init(
        json_cost: f64,
        zon_cost: f64,
        json_input_tokens: u32,
        json_output_tokens: u32,
        zon_input_tokens: u32,
        zon_output_tokens: u32,
    ) RetrievalCostResult {
        std.debug.assert(json_cost >= 0.0);
        std.debug.assert(zon_cost >= 0.0);
        std.debug.assert(json_cost >= zon_cost); // ZON should cost less or equal

        const savings = json_cost - zon_cost;
        const savings_percent = if (json_cost > 0.0)
            @as(f32, @floatCast((savings / json_cost) * 100.0))
        else
            0.0;

        return RetrievalCostResult{
            .json_cost = json_cost,
            .zon_cost = zon_cost,
            .savings = savings,
            .savings_percent = savings_percent,
            .json_input_tokens = json_input_tokens,
            .json_output_tokens = json_output_tokens,
            .zon_input_tokens = zon_input_tokens,
            .zon_output_tokens = zon_output_tokens,
        };
    }
};

// Cost tracking integration: Integrates Court Agent CostTracker with Research
// Agent cost savings calculator.
pub const CostTrackingIntegration = struct {
    allocator: std.mem.Allocator,
    tracker: *grain_court.TokenEfficiency.CostTracker,

    // Initialize cost tracking integration.
    pub fn init(
        allocator: std.mem.Allocator,
        tracker: *grain_court.TokenEfficiency.CostTracker,
    ) CostTrackingIntegration {
        std.debug.assert(tracker != null);

        return CostTrackingIntegration{
            .allocator = allocator,
            .tracker = tracker,
        };
    }

    // Track retrieval cost for JSON and ZON formats.
    // Calculates costs, tracks them in CostTracker, and returns comparison.
    pub fn track_retrieval_cost(
        self: *const CostTrackingIntegration,
        json_response: *const llm_provider.LlmResponse,
        zon_response: *const llm_provider.LlmResponse,
        model: []const u8,
    ) !RetrievalCostResult {
        std.debug.assert(json_response != null);
        std.debug.assert(zon_response != null);
        std.debug.assert(model.len > 0);
        std.debug.assert(model.len <= MAX_MODEL_LEN);

        // Calculate JSON format cost.
        const json_cost = grain_court.TokenEfficiency.calculate_response_cost(json_response);
        _ = grain_court.TokenEfficiency.track_response_cost(self.tracker, json_response, model);

        // Calculate ZON format cost.
        const zon_cost = grain_court.TokenEfficiency.calculate_response_cost(zon_response);
        _ = grain_court.TokenEfficiency.track_response_cost(self.tracker, zon_response, model);

        // Get token counts from responses.
        const json_input_tokens = if (json_response.input_tokens > 0)
            json_response.input_tokens
        else
            json_response.tokens_used / 2;
        const json_output_tokens = if (json_response.output_tokens > 0)
            json_response.output_tokens
        else
            json_response.tokens_used / 2;
        const zon_input_tokens = if (zon_response.input_tokens > 0)
            zon_response.input_tokens
        else
            zon_response.tokens_used / 2;
        const zon_output_tokens = if (zon_response.output_tokens > 0)
            zon_response.output_tokens
        else
            zon_response.tokens_used / 2;

        return RetrievalCostResult.init(
            json_cost,
            zon_cost,
            json_input_tokens,
            json_output_tokens,
            zon_input_tokens,
            zon_output_tokens,
        );
    }

    // Compare actual costs with cost savings calculator projections.
    // Validates cost savings claims with actual cost data.
    pub fn validate_cost_savings(
        self: *const CostTrackingIntegration,
        actual_result: RetrievalCostResult,
        projected_result: cost_savings.CostResult,
    ) struct {
        actual_savings_percent: f32,
        projected_savings_percent: f32,
        difference_percent: f32,
        validation_passed: bool,
    } {
        std.debug.assert(actual_result.json_cost > 0.0);
        std.debug.assert(projected_result.json_cost_total > 0.0);

        const actual_savings_percent = actual_result.savings_percent;
        const projected_savings_percent = projected_result.savings_percent;

        // Calculate difference between actual and projected savings.
        const difference_percent = if (projected_savings_percent > 0.0)
            @abs(actual_savings_percent - projected_savings_percent)
        else
            0.0;

        // Validation passes if actual savings is within 10% of projected savings.
        const validation_passed = difference_percent <= 10.0;

        return .{
            .actual_savings_percent = actual_savings_percent,
            .projected_savings_percent = projected_savings_percent,
            .difference_percent = difference_percent,
            .validation_passed = validation_passed,
        };
    }

    // Get total cost tracked by CostTracker.
    pub fn get_total_cost(self: *const CostTrackingIntegration) f64 {
        return self.tracker.get_total_cost();
    }

    // Get cost by provider from CostTracker.
    pub fn get_cost_by_provider(
        self: *const CostTrackingIntegration,
        provider_type: llm_provider.ProviderType,
    ) f64 {
        return self.tracker.get_cost_by_provider(provider_type);
    }

    // Get cost report from CostTracker.
    pub fn get_cost_report(
        self: *const CostTrackingIntegration,
    ) grain_court.TokenEfficiency.CostReport {
        return grain_court.TokenEfficiency.generate_cost_report(self.tracker);
    }
};
