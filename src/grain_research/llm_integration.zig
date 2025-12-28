//! Grain Research LLM Integration: Integrate with Court Agent LLM providers.
//!
//! Why: Enables Research Agent to send LLM queries for retrieval accuracy testing
//! comparing JSON vs ZON format. Uses Court Agent's ProviderPool for LLM access.
//! Architecture: ProviderPool integration, timeout/error handling, format support.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-28-224000-pst: Phase 2 LLM Integration (Court Agent integration)

const std = @import("std");
const grain_court = @import("grain_court");

// Bounded: Max prompt length.
pub const MAX_PROMPT_LEN: u32 = 100_000; // 100KB

// Bounded: Max response length.
pub const MAX_RESPONSE_LEN: u32 = 100_000; // 100KB

// Bounded: Max model name length.
pub const MAX_MODEL_LEN: u32 = 128;

// Serialization format for LLM queries.
pub const SerializationFormat = enum(u8) {
    json = 0,
    zon = 1,
};

// LLM integration result.
pub const LlmIntegrationResult = struct {
    content: []const u8,
    input_tokens: u32,
    output_tokens: u32,
    tokens_used: u32,
    format: SerializationFormat,
    success: bool,

    pub fn init(
        content: []const u8,
        input_tokens: u32,
        output_tokens: u32,
        tokens_used: u32,
        format: SerializationFormat,
        success: bool,
    ) LlmIntegrationResult {
        std.debug.assert(content.len <= MAX_RESPONSE_LEN);
        std.debug.assert(input_tokens <= 1_000_000);
        std.debug.assert(output_tokens <= 1_000_000);
        std.debug.assert(tokens_used <= 1_000_000);

        return LlmIntegrationResult{
            .content = content,
            .input_tokens = input_tokens,
            .output_tokens = output_tokens,
            .tokens_used = tokens_used,
            .format = format,
            .success = success,
        };
    }
};

// LLM integration helper.
pub const LlmIntegration = struct {
    allocator: std.mem.Allocator,
    pool: *llm_provider.ProviderPool,

    // Initialize LLM integration helper.
    pub fn init(
        allocator: std.mem.Allocator,
        pool: *llm_provider.ProviderPool,
    ) LlmIntegration {
        std.debug.assert(allocator.ptr != null);
        std.debug.assert(pool.ptr != null);

        return LlmIntegration{
            .allocator = allocator,
            .pool = pool,
        };
    }

    // Send retrieval query to LLM provider.
    pub fn send_retrieval_query(
        self: *LlmIntegration,
        prompt: []const u8,
        format: SerializationFormat,
        model: []const u8,
        provider_type: llm_provider.ProviderType,
    ) !LlmIntegrationResult {
        std.debug.assert(prompt.len > 0);
        std.debug.assert(prompt.len <= MAX_PROMPT_LEN);
        std.debug.assert(model.len > 0);
        std.debug.assert(model.len <= MAX_MODEL_LEN);

        var request = llm_provider.LlmRequest{
            .request_id = 1,
            .provider_type = provider_type,
            .model = undefined,
            .model_len = 0,
            .prompt = undefined,
            .prompt_len = 0,
            .max_tokens = 1000,
            .temperature = 0.7,
            .created_at = std.time.nanoTimestamp(),
            .use_zon_format = (format == .zon),
            .zon_data = if (format == .zon) prompt else null,
            .timeout_ms = 60000, // 60 seconds default
        };

        // Copy model name.
        if (model.len > request.model.len) {
            return error.ModelNameTooLong;
        }
        @memset(request.model[0..], 0);
        @memcpy(request.model[0..model.len], model);
        request.model_len = @intCast(model.len);

        // Copy prompt.
        const max_prompt_len = @as(u32, @intCast(request.prompt.len));
        if (prompt.len > max_prompt_len) {
            return error.PromptTooLong;
        }
        @memset(request.prompt[0..], 0);
        @memcpy(request.prompt[0..prompt.len], prompt);
        request.prompt_len = @intCast(prompt.len);

        const response = self.pool.send_request_with_fallback(&request, self.allocator) catch |err| {
            // Return error result.
            return LlmIntegrationResult.init(
                "",
                0,
                0,
                0,
                format,
                false,
            );
        };

        return LlmIntegrationResult.init(
            response.content[0..response.content_len],
            response.input_tokens,
            response.output_tokens,
            response.tokens_used,
            format,
            true,
        );
    }
};
