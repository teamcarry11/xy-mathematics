//! Grain Research Retrieval LLM Integration: Execute retrieval accuracy tests with LLM.
//!
//! Why: Integrates LLM integration helper with retrieval accuracy framework to enable
//! actual LLM queries comparing JSON vs ZON format retrieval accuracy. Supports Phase 2
//! validation with real LLM providers.
//! Architecture: LLM integration, retrieval accuracy testing, format comparison.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-28-224000-pst: Phase 2 LLM Integration (Court Agent integration)

const std = @import("std");
const retrieval_accuracy = @import("retrieval_accuracy.zig");
const retrieval_serialization = @import("retrieval_serialization.zig");
const llm_integration = @import("llm_integration.zig");
const grain_court = @import("grain_court");
const llm_provider = grain_court.LlmProvider;

const TestDataset = retrieval_accuracy.TestDataset;
const Query = retrieval_accuracy.Query;
const RetrievalResult = retrieval_accuracy.RetrievalResult;
const RetrievalAccuracyAnalyzer = retrieval_accuracy.RetrievalAccuracyAnalyzer;
const Serializer = retrieval_serialization.Serializer;
const LlmIntegration = llm_integration.LlmIntegration;
const SerializationFormat = llm_integration.SerializationFormat;

// Bounded: Max queries to test per run.
pub const MAX_QUERIES_PER_RUN: u32 = 100;

// Retrieval test result for a single query.
pub const QueryTestResult = struct {
    query_id: u32,
    json_result: RetrievalResult,
    zon_result: RetrievalResult,
    json_accuracy: bool,
    zon_accuracy: bool,
    json_tokens: u32,
    zon_tokens: u32,
    token_savings_percent: f32,

    pub fn init(
        query_id: u32,
        json_result: RetrievalResult,
        zon_result: RetrievalResult,
        json_accuracy: bool,
        zon_accuracy: bool,
        json_tokens: u32,
        zon_tokens: u32,
    ) QueryTestResult {
        std.debug.assert(json_tokens <= 1_000_000);
        std.debug.assert(zon_tokens <= 1_000_000);

        const token_savings = if (json_tokens > 0)
            (@as(f32, @floatFromInt(json_tokens - zon_tokens)) /
                @as(f32, @floatFromInt(json_tokens))) * 100.0
        else
            0.0;

        return QueryTestResult{
            .query_id = query_id,
            .json_result = json_result,
            .zon_result = zon_result,
            .json_accuracy = json_accuracy,
            .zon_accuracy = zon_accuracy,
            .json_tokens = json_tokens,
            .zon_tokens = zon_tokens,
            .token_savings_percent = token_savings,
        };
    }
};

// Execute retrieval accuracy test for a single query.
pub fn execute_query_test(
    llm: *LlmIntegration,
    dataset: *const TestDataset,
    query: *const Query,
    json_data: []const u8,
    zon_data: []const u8,
    model: []const u8,
    provider_type: llm_provider.ProviderType,
) !QueryTestResult {
    std.debug.assert(query.text.len > 0);
    std.debug.assert(json_data.len > 0);
    std.debug.assert(zon_data.len > 0);
    std.debug.assert(model.len > 0);

    // Build prompt with context data and query.
    const json_prompt = try build_retrieval_prompt(
        llm.allocator,
        json_data,
        query.text,
        "JSON",
    );
    defer llm.allocator.free(json_prompt);

    const zon_prompt = try build_retrieval_prompt(
        llm.allocator,
        zon_data,
        query.text,
        "ZON",
    );
    defer llm.allocator.free(zon_prompt);

    // Send JSON format query.
    const json_response = try llm.send_retrieval_query(
        json_prompt,
        .json,
        model,
        provider_type,
    );

    // Send ZON format query.
    const zon_response = try llm.send_retrieval_query(
        zon_prompt,
        .zon,
        model,
        provider_type,
    );

    // Parse responses and check accuracy.
    const json_retrieved = try parse_retrieved_facts(
        llm.allocator,
        json_response.content,
    );
    defer llm.allocator.free(json_retrieved);

    const zon_retrieved = try parse_retrieved_facts(
        llm.allocator,
        zon_response.content,
    );
    defer llm.allocator.free(zon_retrieved);

    const json_accuracy = check_accuracy(json_retrieved, query.expected_fact_ids);
    const zon_accuracy = check_accuracy(zon_retrieved, query.expected_fact_ids);

    const json_result = RetrievalResult.init(
        query.id,
        json_retrieved,
        json_response.content,
        json_accuracy,
    );

    const zon_result = RetrievalResult.init(
        query.id,
        zon_retrieved,
        zon_response.content,
        zon_accuracy,
    );

    return QueryTestResult.init(
        query.id,
        json_result,
        zon_result,
        json_accuracy,
        zon_accuracy,
        json_response.tokens_used,
        zon_response.tokens_used,
    );
}

// Build retrieval prompt with context and query.
fn build_retrieval_prompt(
    allocator: std.mem.Allocator,
    context_data: []const u8,
    query_text: []const u8,
    format_name: []const u8,
) ![]u8 {
    std.debug.assert(context_data.len > 0);
    std.debug.assert(query_text.len > 0);
    std.debug.assert(format_name.len > 0);

    var prompt = std.ArrayList(u8).init(allocator);
    errdefer prompt.deinit();

    try prompt.writer().print(
        "Context data ({s} format):\n{s}\n\nQuery: {s}\n\nAnswer the query using information from the context data. List the fact IDs you found.",
        .{ format_name, context_data, query_text },
    );

    return try prompt.toOwnedSlice();
}

// Parse retrieved fact IDs from LLM response.
fn parse_retrieved_facts(
    allocator: std.mem.Allocator,
    response_text: []const u8,
) ![]const u32 {
    std.debug.assert(response_text.len > 0);

    var facts = std.ArrayList(u32).init(allocator);
    errdefer facts.deinit();

    // Simple parsing: look for numbers in response.
    var i: u32 = 0;
    while (i < response_text.len) : (i += 1) {
        if (std.ascii.isDigit(response_text[i])) {
            var num: u32 = 0;
            var j: u32 = i;
            while (j < response_text.len and std.ascii.isDigit(response_text[j])) : (j += 1) {
                num = num * 10 + (response_text[j] - '0');
            }
            if (num > 0) {
                try facts.append(num);
            }
            i = j;
        }
    }

    return try facts.toOwnedSlice();
}

// Check if retrieved facts match expected facts.
fn check_accuracy(
    retrieved: []const u32,
    expected: []const u32,
) bool {
    std.debug.assert(expected.len > 0);
    std.debug.assert(retrieved.len <= 10);
    std.debug.assert(expected.len <= 10);

    if (retrieved.len != expected.len) {
        return false;
    }

    var i: u32 = 0;
    while (i < expected.len) : (i += 1) {
        var found: bool = false;
        var j: u32 = 0;
        while (j < retrieved.len) : (j += 1) {
            if (retrieved[j] == expected[i]) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
    }

    return true;
}
