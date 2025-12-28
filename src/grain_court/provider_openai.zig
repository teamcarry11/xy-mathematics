//! Grain Court OpenAI Provider: OpenAI API provider implementation.
//!
//! Why: Enable agents to use OpenAI API (GPT-4o, GPT-5-nano) via provider abstraction.
//! Architecture: OpenAI API client, request encoding, response decoding.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const llm_provider = @import("llm_provider.zig");
const grain_core = @import("grain_core");

// Bounded: Max JSON body size for OpenAI requests.
const MAX_JSON_BODY_SIZE: u32 = 65536;

// Build OpenAI JSON request body.
fn build_openai_json_body(
    request: *const llm_provider.LlmRequest,
    output: []u8,
) !u32 {
    std.debug.assert(request != null);
    std.debug.assert(output.len > 0);
    std.debug.assert(request.prompt_len > 0);
    const prompt_str = request.prompt[0..request.prompt_len];
    const model_str = request.model[0..request.model_len];
    const json_body = try std.fmt.bufPrint(
        output,
        \\{{"model":"{s}","messages":[{{"role":"user","content":"{s}"}}],"max_tokens":{d},"temperature":{d:.2}}}
    ,
        .{ model_str, prompt_str, request.max_tokens, request.temperature },
    );
    std.debug.assert(json_body.len <= MAX_JSON_BODY_SIZE);
    return @intCast(json_body.len);
}

// Parse OpenAI JSON response (simplified - handles basic structure).
fn parse_openai_response(
    json: []const u8,
    response: *llm_provider.LlmResponse,
) !void {
    std.debug.assert(json.len > 0);
    std.debug.assert(response != null);
    var i: u32 = 0;
    while (i < llm_provider.MAX_RESPONSE_SIZE) : (i += 1) {
        response.content[i] = 0;
    }
    if (grain_core.json_helpers.find_json_key(json, "choices")) |_| {
        if (grain_core.json_helpers.find_json_key(json, "message")) |msg_result| {
            var msg_json = json[msg_result.value_start..msg_result.value_start + msg_result.value_len];
            if (grain_core.json_helpers.find_json_key(msg_json, "content")) |content_result| {
                var content_buffer: [llm_provider.MAX_RESPONSE_SIZE]u8 = undefined;
                if (grain_core.json_helpers.extract_json_string_value(
                    msg_json,
                    &content_result,
                    &content_buffer,
                )) |content_len| {
                    const copy_len = @min(content_len, llm_provider.MAX_RESPONSE_SIZE);
                    i = 0;
                    while (i < copy_len) : (i += 1) {
                        response.content[i] = content_buffer[i];
                    }
                    response.content_len = copy_len;
                }
            }
        }
    }
    if (grain_core.json_helpers.find_json_key(json, "usage")) |usage_result| {
        var usage_json = json[usage_result.value_start..usage_result.value_start + usage_result.value_len];
        if (grain_core.json_helpers.find_json_key(usage_json, "prompt_tokens")) |prompt_result| {
            if (grain_core.json_helpers.extract_json_number_value(
                usage_json,
                &prompt_result,
            )) |tokens| {
                if (tokens > 0) {
                    response.input_tokens = @intCast(tokens);
                }
            }
        }
        if (grain_core.json_helpers.find_json_key(usage_json, "completion_tokens")) |completion_result| {
            if (grain_core.json_helpers.extract_json_number_value(
                usage_json,
                &completion_result,
            )) |tokens| {
                if (tokens > 0) {
                    response.output_tokens = @intCast(tokens);
                }
            }
        }
        if (grain_core.json_helpers.find_json_key(usage_json, "total_tokens")) |tokens_result| {
            if (grain_core.json_helpers.extract_json_number_value(
                usage_json,
                &tokens_result,
            )) |tokens| {
                if (tokens > 0) {
                    response.tokens_used = @intCast(tokens);
                }
            }
        }
    }
    std.debug.assert(response.content_len <= llm_provider.MAX_RESPONSE_SIZE);
}

// OpenAI provider implementation.
pub const OpenAIProvider = struct {
    trait: llm_provider.ProviderTrait,
    allocator: std.mem.Allocator,

    // Initialize OpenAI provider.
    pub fn init(
        allocator: std.mem.Allocator,
        api_key: []const u8,
        http_client_ptr: ?*grain_core.http_client.HttpClient,
    ) !OpenAIProvider {
        std.debug.assert(allocator != null);
        std.debug.assert(api_key.len > 0);
        std.debug.assert(api_key.len <= 256);
        var provider = OpenAIProvider{
            .trait = undefined,
            .allocator = allocator,
        };
        provider.trait.provider_type = .openai;
        provider.trait.state = .idle;
        provider.trait.http_client = http_client_ptr;
        var i: u32 = 0;
        while (i < 256) : (i += 1) {
            provider.trait.api_key[i] = 0;
        }
        const key_len = @min(api_key.len, 256);
        i = 0;
        while (i < key_len) : (i += 1) {
            provider.trait.api_key[i] = api_key[i];
        }
        provider.trait.api_key_len = @intCast(key_len);
        const base_url = "https://api.openai.com/v1";
        i = 0;
        while (i < 512) : (i += 1) {
            provider.trait.base_url[i] = 0;
        }
        const url_len = @min(base_url.len, 512);
        i = 0;
        while (i < url_len) : (i += 1) {
            provider.trait.base_url[i] = base_url[i];
        }
        provider.trait.base_url_len = @intCast(url_len);
        provider.trait.send_request = send_request_impl;
        provider.trait.check_health = check_health_impl;
        provider.trait.get_name = get_name_impl;
        std.debug.assert(provider.trait.api_key_len > 0);
        return provider;
    }

    // Send request implementation.
    fn send_request_impl(
        self: *llm_provider.ProviderTrait,
        request: *const llm_provider.LlmRequest,
        allocator: std.mem.Allocator,
    ) anyerror!llm_provider.LlmResponse {
        std.debug.assert(self != null);
        std.debug.assert(request != null);
        std.debug.assert(request.prompt_len > 0);
        std.debug.assert(request.prompt_len <= llm_provider.MAX_REQUEST_SIZE);
        if (self.http_client == null) {
            return llm_provider.LlmProviderError.HttpClientNotAvailable;
        }
        const start_time = std.time.nanoTimestamp();
        const client = self.http_client.?;
        const url = "https://api.openai.com/v1/chat/completions";
        const http_req = client.create_request(
            grain_core.api_server.HttpMethod.post,
            url,
        ) orelse {
            return llm_provider.LlmProviderError.RequestCreationFailed;
        };
        const auth_header = try std.fmt.allocPrint(
            allocator,
            "Bearer {s}",
            .{self.api_key[0..self.api_key_len]},
        );
        defer allocator.free(auth_header);
        _ = http_req.add_header("Content-Type", "application/json");
        _ = http_req.add_header("Authorization", auth_header);
        var json_body: [MAX_JSON_BODY_SIZE]u8 = undefined;
        const body_len = try build_openai_json_body(request, &json_body);
        var i: u32 = 0;
        while (i < grain_core.api_server.MAX_REQUEST_SIZE) : (i += 1) {
            http_req.body[i] = 0;
        }
        i = 0;
        const copy_len = @min(body_len, grain_core.api_server.MAX_REQUEST_SIZE);
        while (i < copy_len) : (i += 1) {
            http_req.body[i] = json_body[i];
        }
        http_req.body_len = copy_len;
        var response = llm_provider.LlmResponse{
            .request_id = request.request_id,
            .provider_type = .openai,
            .content = undefined,
            .content_len = 0,
            .tokens_used = 0,
            .input_tokens = 0,
            .output_tokens = 0,
            .finish_reason = undefined,
            .finish_reason_len = 0,
            .created_at = 0,
        };
        i = 0;
        while (i < llm_provider.MAX_RESPONSE_SIZE) : (i += 1) {
            response.content[i] = 0;
        }
        if (http_req.response) |http_resp| {
            const current_time_ns = std.time.nanoTimestamp();
            const start_time_u64 = @as(u64, @intCast(start_time));
            const current_time_u64 = @as(u64, @intCast(current_time_ns));
            if (llm_provider.check_request_timeout(request, start_time_u64, current_time_u64)) {
                return llm_provider.LlmProviderError.Timeout;
            }
            if (llm_provider.check_rate_limit_response(http_resp)) |retry_after_ms| {
                _ = retry_after_ms;
                return llm_provider.LlmProviderError.RateLimit;
            }
            const status_code = @intFromEnum(http_resp.status);
            if (status_code >= 500) {
                return llm_provider.LlmProviderError.ProviderError;
            }
            if (status_code == 401) {
                return llm_provider.LlmProviderError.AuthenticationError;
            }
            if (status_code >= 400) {
                return llm_provider.LlmProviderError.InvalidRequest;
            }
            const resp_body = http_resp.body[0..http_resp.body_len];
            try parse_openai_response(resp_body, &response);
        } else {
            const current_time_ns = std.time.nanoTimestamp();
            const start_time_u64 = @as(u64, @intCast(start_time));
            const current_time_u64 = @as(u64, @intCast(current_time_ns));
            if (llm_provider.check_request_timeout(request, start_time_u64, current_time_u64)) {
                return llm_provider.LlmProviderError.Timeout;
            }
            return llm_provider.LlmProviderError.NetworkError;
        }
        std.debug.assert(response.request_id == request.request_id);
        return response;
    }

    // Check health implementation.
    fn check_health_impl(self: *llm_provider.ProviderTrait) bool {
        std.debug.assert(self != null);
        if (self.http_client == null) {
            return false;
        }
        if (self.api_key_len == 0) {
            return false;
        }
        return self.state != .error_state and
            self.state != .disabled;
    }

    // Get name implementation.
    fn get_name_impl(self: *const llm_provider.ProviderTrait) []const u8 {
        std.debug.assert(self != null);
        return "OpenAI";
    }
};
