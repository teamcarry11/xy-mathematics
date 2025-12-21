//! Grain Court LLM Provider: Multi-provider LLM API abstraction.
//!
//! Why: Enable agents to use multiple LLM providers (OpenAI, Anthropic, Mistral, self-hosted)
//! with a unified interface.
//! Architecture: Provider abstraction, request/response handling, provider switching.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const grain_core = @import("grain_core");

// LLM provider errors.
pub const LlmProviderError = error{
    TooManyProviders,
    ProviderPoolFull,
    HttpClientNotAvailable,
    RequestCreationFailed,
    NoHealthyProvider,
    InvalidRequest,
    InvalidResponse,
};

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
};

// LLM response structure.
pub const LlmResponse = struct {
    request_id: u32,
    provider_type: ProviderType,
    content: [MAX_RESPONSE_SIZE]u8,
    content_len: u32,
    tokens_used: u32,
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
