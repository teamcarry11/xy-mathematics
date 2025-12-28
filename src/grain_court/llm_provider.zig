//! Grain Court LLM Provider: Multi-provider LLM API abstraction.
//!
//! Why: Enable agents to use multiple LLM providers (OpenAI, Anthropic, Mistral, self-hosted)
//! with a unified interface.
//! Architecture: Provider abstraction, request/response handling, provider switching.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const grain_core = @import("grain_core");
const zon_format = @import("zon_format.zig");

// LLM provider errors (structured error types with retryability).
pub const LlmProviderError = error{
    TooManyProviders,
    ProviderPoolFull,
    HttpClientNotAvailable,
    RequestCreationFailed,
    NoHealthyProvider,
    InvalidRequest,
    InvalidResponse,
    Timeout,
    NetworkError,
    RateLimit,
    AuthenticationError,
    ProviderError,
    DnsError,
    ConnectionRefused,
};

// LLM error context (for detailed error information).
pub const LlmErrorContext = struct {
    error_type: LlmProviderError,
    operation: [64]u8,
    operation_len: u32,
    status_code: ?u32,
    retry_after_ms: ?u64,
    message: [256]u8,
    message_len: u32,

    // Initialize error context.
    pub fn init(
        err: LlmProviderError,
        operation_name: []const u8,
        status: ?u32,
        retry_after: ?u64,
        err_message: []const u8,
    ) LlmErrorContext {
        std.debug.assert(operation_name.len > 0);
        std.debug.assert(operation_name.len <= 64);
        std.debug.assert(err_message.len <= 256);
        var ctx = LlmErrorContext{
            .error_type = err,
            .operation = undefined,
            .operation_len = 0,
            .status_code = status,
            .retry_after_ms = retry_after,
            .message = undefined,
            .message_len = 0,
        };
        var i: u32 = 0;
        while (i < 64) : (i += 1) {
            ctx.operation[i] = 0;
        }
        i = 0;
        const op_len = @min(operation_name.len, 64);
        while (i < op_len) : (i += 1) {
            ctx.operation[i] = operation_name[i];
        }
        ctx.operation_len = op_len;
        i = 0;
        while (i < 256) : (i += 1) {
            ctx.message[i] = 0;
        }
        i = 0;
        const msg_len = @min(err_message.len, 256);
        while (i < msg_len) : (i += 1) {
            ctx.message[i] = err_message[i];
        }
        ctx.message_len = msg_len;
        std.debug.assert(ctx.operation_len > 0);
        return ctx;
    }
};

// Check if LLM error is retryable.
pub fn is_llm_error_retryable(err: LlmProviderError) bool {
    std.debug.assert(@intFromEnum(err) < 15);
    switch (err) {
        .Timeout => return true,
        .NetworkError => return true,
        .RateLimit => return true,
        .ProviderError => return true,
        .TooManyProviders => return false,
        .ProviderPoolFull => return false,
        .HttpClientNotAvailable => return false,
        .RequestCreationFailed => return false,
        .NoHealthyProvider => return false,
        .InvalidRequest => return false,
        .InvalidResponse => return false,
        .AuthenticationError => return false,
        .DnsError => return false,
        .ConnectionRefused => return false,
    }
}

// Parse Retry-After header value (seconds or HTTP date).
pub fn parse_retry_after_header(value: []const u8) ?u64 {
    std.debug.assert(value.len > 0);
    if (value.len == 0) {
        return null;
    }
    var i: u32 = 0;
    while (i < value.len and value[i] == ' ') : (i += 1) {}
    if (i >= value.len) {
        return null;
    }
    var num: u64 = 0;
    while (i < value.len and value[i] >= '0' and value[i] <= '9') : (i += 1) {
        num = num * 10 + (value[i] - '0');
    }
    if (num > 0) {
        return num * 1000;
    }
    return null;
}

// Check HTTP response for rate limiting (429 status).
pub fn check_rate_limit_response(
    http_resp: *const grain_core.api_server.HttpResponse,
) ?u64 {
    std.debug.assert(http_resp != null);
    const status_code = @intFromEnum(http_resp.status);
    if (status_code == 429) {
        var i: u32 = 0;
        while (i < http_resp.headers_len) : (i += 1) {
            const header = http_resp.headers[i];
            const header_name = header.name[0..header.name_len];
            if (std.mem.eql(u8, header_name, "Retry-After")) {
                const header_value = header.value[0..header.value_len];
                return parse_retry_after_header(header_value);
            }
        }
        return 60000;
    }
    return null;
}

// Check if request timed out.
pub fn check_request_timeout(
    request: *const LlmRequest,
    start_time: u64,
    current_time: u64,
) bool {
    std.debug.assert(request != null);
    const timeout_ms = request.timeout_ms orelse DEFAULT_LLM_TIMEOUT_MS;
    const elapsed_ms = (current_time - start_time) / 1_000_000;
    return elapsed_ms >= timeout_ms;
}

// Bounded: Max providers in pool.
pub const MAX_PROVIDERS: u32 = 10;

// Bounded: Max requests per provider.
pub const MAX_REQUESTS_PER_PROVIDER: u32 = 1000;

// Bounded: Max response size (1MB).
pub const MAX_RESPONSE_SIZE: u64 = 1_048_576;

// Bounded: Max request size (1MB).
pub const MAX_REQUEST_SIZE: u64 = 1_048_576;

// Provider type enumeration.
pub const ProviderType = enum(u8) {
    openai,
    anthropic,
    mistral,
    self_hosted,
};

// Provider state enumeration.
pub const ProviderState = enum(u8) {
    idle,
    active,
    error_state,
    disabled,
};

// Bounded: Default timeout for LLM operations (60 seconds).
pub const DEFAULT_LLM_TIMEOUT_MS: u32 = 60000;

// LLM request structure.
pub const LlmRequest = struct {
    request_id: u32,
    provider_type: ProviderType,
    model: [128]u8,
    model_len: u32,
    prompt: [MAX_REQUEST_SIZE]u8,
    prompt_len: u32,
    max_tokens: u32,
    temperature: f32,
    created_at: u64,
    use_zon_format: bool,
    zon_data: ?[]const u8,
    timeout_ms: ?u32,
};

// LLM response structure.
pub const LlmResponse = struct {
    request_id: u32,
    provider_type: ProviderType,
    content: [MAX_RESPONSE_SIZE]u8,
    content_len: u32,
    tokens_used: u32,
    input_tokens: u32,
    output_tokens: u32,
    finish_reason: [32]u8,
    finish_reason_len: u32,
    created_at: u64,
};

// Provider trait interface.
pub const ProviderTrait = struct {
    provider_type: ProviderType,
    state: ProviderState,
    api_key: [256]u8,
    api_key_len: u32,
    base_url: [512]u8,
    base_url_len: u32,
    http_client: ?*grain_core.http_client.HttpClient,

    // Send LLM request.
    send_request: *const fn (
        self: *ProviderTrait,
        request: *const LlmRequest,
        allocator: std.mem.Allocator,
    ) anyerror!LlmResponse,

    // Check provider health.
    check_health: *const fn (self: *ProviderTrait) bool,

    // Get provider name.
    get_name: *const fn (self: *const ProviderTrait) []const u8,
};

// Provider pool structure.
pub const ProviderPool = struct {
    providers: [MAX_PROVIDERS]?*ProviderTrait,
    providers_len: u32,
    default_provider: ?*ProviderTrait,
    allocator: std.mem.Allocator,

    // Initialize provider pool.
    pub fn init(allocator: std.mem.Allocator) ProviderPool {
        std.debug.assert(allocator != null);
        var pool = ProviderPool{
            .providers = undefined,
            .providers_len = 0,
            .default_provider = null,
            .allocator = allocator,
        };
        var i: u32 = 0;
        while (i < MAX_PROVIDERS) : (i += 1) {
            pool.providers[i] = null;
        }
        std.debug.assert(pool.providers_len == 0);
        return pool;
    }

    // Add provider to pool.
    pub fn add_provider(
        self: *ProviderPool,
        provider: *ProviderTrait,
    ) !void {
        std.debug.assert(provider != null);
        std.debug.assert(self.providers_len < MAX_PROVIDERS);
        if (self.providers_len >= MAX_PROVIDERS) {
            return error.TooManyProviders;
        }
        var i: u32 = 0;
        while (i < MAX_PROVIDERS) : (i += 1) {
            if (self.providers[i] == null) {
                self.providers[i] = provider;
                self.providers_len += 1;
                if (self.default_provider == null) {
                    self.default_provider = provider;
                }
                std.debug.assert(self.providers_len <= MAX_PROVIDERS);
                return;
            }
        }
        return LlmProviderError.ProviderPoolFull;
    }

    // Get provider by type.
    pub fn get_provider_by_type(
        self: *const ProviderPool,
        provider_type: ProviderType,
    ) ?*ProviderTrait {
        std.debug.assert(self.providers_len <= MAX_PROVIDERS);
        var i: u32 = 0;
        while (i < MAX_PROVIDERS) : (i += 1) {
            if (self.providers[i]) |provider| {
                if (provider.provider_type == provider_type) {
                    return provider;
                }
            }
        }
        return null;
    }

    // Get default provider.
    pub fn get_default_provider(self: *const ProviderPool) ?*ProviderTrait {
        std.debug.assert(self.providers_len <= MAX_PROVIDERS);
        return self.default_provider;
    }

    // Set default provider.
    pub fn set_default_provider(
        self: *ProviderPool,
        provider: *ProviderTrait,
    ) bool {
        std.debug.assert(provider != null);
        std.debug.assert(self.providers_len <= MAX_PROVIDERS);
        var i: u32 = 0;
        while (i < MAX_PROVIDERS) : (i += 1) {
            if (self.providers[i]) |p| {
                if (p == provider) {
                    self.default_provider = provider;
                    return true;
                }
            }
        }
        return false;
    }

    // Send request with fallback.
    pub fn send_request_with_fallback(
        self: *ProviderPool,
        request: *const LlmRequest,
        allocator: std.mem.Allocator,
    ) !LlmResponse {
        std.debug.assert(request != null);
        std.debug.assert(self.providers_len <= MAX_PROVIDERS);
        if (self.default_provider) |provider| {
            if (provider.check_health(provider)) {
                return provider.send_request(provider, request, allocator) catch |err| {
                    return try self.try_fallback(request, allocator, provider, err);
                };
            }
        }
        return try self.try_fallback(request, allocator, null, LlmProviderError.NoHealthyProvider);
    }

    // Try fallback providers.
    fn try_fallback(
        self: *ProviderPool,
        request: *const LlmRequest,
        allocator: std.mem.Allocator,
        failed_provider: ?*ProviderTrait,
        original_error: anyerror,
    ) !LlmResponse {
        std.debug.assert(request != null);
        std.debug.assert(self.providers_len <= MAX_PROVIDERS);
        var i: u32 = 0;
        while (i < MAX_PROVIDERS) : (i += 1) {
            if (self.providers[i]) |provider| {
                if (failed_provider == null or provider != failed_provider.?) {
                    if (provider.check_health(provider)) {
                        return provider.send_request(provider, request, allocator);
                    }
                }
            }
        }
        return original_error;
    }
};

// Encode structured data to ZON format for LLM request.
pub fn encode_data_to_zon(
    data: []const struct { key: []const u8, value: zon_format.ZonValue },
    allocator: std.mem.Allocator,
) ![]u8 {
    std.debug.assert(data.len > 0);
    std.debug.assert(allocator != null);
    const zon_result = try zon_format.encode_zon(data, allocator);
    defer zon_result.deinit();
    const result = try allocator.alloc(u8, zon_result.len);
    @memcpy(result, zon_result.data[0..zon_result.len]);
    std.debug.assert(result.len == zon_result.len);
    return result;
}

// Check if provider supports ZON format.
pub fn provider_supports_zon(provider_type: ProviderType) bool {
    std.debug.assert(@intFromEnum(provider_type) < 4);
    switch (provider_type) {
        .openai => return false,
        .anthropic => return false,
        .mistral => return false,
        .self_hosted => return true,
    }
}

// Convert ZON format to JSON for providers that don't support ZON.
pub fn convert_zon_to_json(
    zon_data: []const u8,
    allocator: std.mem.Allocator,
) ![]u8 {
    std.debug.assert(zon_data.len > 0);
    std.debug.assert(allocator != null);
    const decode_result = try zon_format.decode_zon(zon_data, allocator);
    defer decode_result.deinit();
    var json_buffer: [MAX_REQUEST_SIZE]u8 = undefined;
    var json_pos: u32 = 0;
    json_buffer[json_pos] = '{';
    json_pos += 1;
    var i: u32 = 0;
    while (i < decode_result.pairs.len) : (i += 1) {
        if (i > 0) {
            json_buffer[json_pos] = ',';
            json_pos += 1;
        }
        const pair = decode_result.pairs[i];
        json_buffer[json_pos] = '"';
        json_pos += 1;
        var j: u32 = 0;
        while (j < pair.key.len and json_pos < MAX_REQUEST_SIZE) : (j += 1) {
            json_buffer[json_pos] = pair.key[j];
            json_pos += 1;
        }
        json_buffer[json_pos] = '"';
        json_pos += 1;
        json_buffer[json_pos] = ':';
        json_pos += 1;
        switch (pair.value.value_type) {
            .bool_value => {
                if (pair.value.bool_val) {
                    const true_str = "true";
                    var k: u32 = 0;
                    while (k < true_str.len and json_pos < MAX_REQUEST_SIZE) : (k += 1) {
                        json_buffer[json_pos] = true_str[k];
                        json_pos += 1;
                    }
                } else {
                    const false_str = "false";
                    var k: u32 = 0;
                    while (k < false_str.len and json_pos < MAX_REQUEST_SIZE) : (k += 1) {
                        json_buffer[json_pos] = false_str[k];
                        json_pos += 1;
                    }
                }
            },
            .u32_value => {
                const num_str = try std.fmt.bufPrint(
                    json_buffer[json_pos..],
                    "{d}",
                    .{pair.value.u32_val},
                );
                json_pos += @intCast(num_str.len);
            },
            .string_value => {
                json_buffer[json_pos] = '"';
                json_pos += 1;
                const str_val = pair.value.string_val[0..pair.value.string_val_len];
                var k: u32 = 0;
                while (k < str_val.len and json_pos < MAX_REQUEST_SIZE) : (k += 1) {
                    json_buffer[json_pos] = str_val[k];
                    json_pos += 1;
                }
                json_buffer[json_pos] = '"';
                json_pos += 1;
            },
            else => {
                const null_str = "null";
                var k: u32 = 0;
                while (k < null_str.len and json_pos < MAX_REQUEST_SIZE) : (k += 1) {
                    json_buffer[json_pos] = null_str[k];
                    json_pos += 1;
                }
            },
        }
        if (json_pos >= MAX_REQUEST_SIZE) {
            break;
        }
    }
    json_buffer[json_pos] = '}';
    json_pos += 1;
    std.debug.assert(json_pos <= MAX_REQUEST_SIZE);
    const result = try allocator.alloc(u8, json_pos);
    @memcpy(result, json_buffer[0..json_pos]);
    return result;
}
