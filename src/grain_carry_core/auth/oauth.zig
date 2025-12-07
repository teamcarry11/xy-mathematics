//! Grain Carry Core OAuth Integration: OAuth 2.0 provider integration.
//!
//! Why: Enable OAuth authentication for mobile apps (Google, Facebook, GitHub, Apple).
//! Architecture: OAuth provider configuration, authorization flow, token management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-07-060952-pst: Grain Carry Agent

const std = @import("std");
const grain_core_auth = @import("../../grain_core/auth_service.zig");

// Bounded: Max OAuth provider name length.
pub const MAX_PROVIDER_NAME_LEN: u32 = 32;

// Bounded: Max OAuth client ID length.
pub const MAX_CLIENT_ID_LEN: u32 = 512;

// Bounded: Max OAuth client secret length.
pub const MAX_CLIENT_SECRET_LEN: u32 = 512;

// Bounded: Max OAuth redirect URI length.
pub const MAX_REDIRECT_URI_LEN: u32 = 512;

// Bounded: Max OAuth authorization code length.
pub const MAX_AUTH_CODE_LEN: u32 = 512;

// Bounded: Max OAuth access token length.
pub const MAX_ACCESS_TOKEN_LEN: u32 = 2048;

// Bounded: Max OAuth refresh token length.
pub const MAX_REFRESH_TOKEN_LEN: u32 = 2048;

// Bounded: Max OAuth state parameter length.
pub const MAX_STATE_LEN: u32 = 256;

// OAuth provider type.
pub const OAuthProvider = enum(u8) {
    google,
    facebook,
    github,
    apple,
};

// OAuth provider configuration.
pub const OAuthProviderConfig = struct {
    provider: OAuthProvider,
    client_id: [MAX_CLIENT_ID_LEN]u8,
    client_id_len: u32,
    client_secret: [MAX_CLIENT_SECRET_LEN]u8,
    client_secret_len: u32,
    redirect_uri: [MAX_REDIRECT_URI_LEN]u8,
    redirect_uri_len: u32,
    enabled: bool,

    pub fn init(provider: OAuthProvider) OAuthProviderConfig {
        var config = OAuthProviderConfig{
            .provider = provider,
            .client_id = undefined,
            .client_id_len = 0,
            .client_secret = undefined,
            .client_secret_len = 0,
            .redirect_uri = undefined,
            .redirect_uri_len = 0,
            .enabled = false,
        };
        var i: u32 = 0;
        while (i < MAX_CLIENT_ID_LEN) : (i += 1) {
            config.client_id[i] = 0;
        }
        i = 0;
        while (i < MAX_CLIENT_SECRET_LEN) : (i += 1) {
            config.client_secret[i] = 0;
        }
        i = 0;
        while (i < MAX_REDIRECT_URI_LEN) : (i += 1) {
            config.redirect_uri[i] = 0;
        }
        std.debug.assert(config.client_id_len == 0);
        std.debug.assert(config.client_secret_len == 0);
        return config;
    }
};

// OAuth manager.
pub const OAuthManager = struct {
    providers: [4]OAuthProviderConfig,
    providers_len: u32,

    pub fn init() OAuthManager {
        var manager = OAuthManager{
            .providers = undefined,
            .providers_len = 0,
        };
        manager.providers[0] = OAuthProviderConfig.init(.google);
        manager.providers[1] = OAuthProviderConfig.init(.facebook);
        manager.providers[2] = OAuthProviderConfig.init(.github);
        manager.providers[3] = OAuthProviderConfig.init(.apple);
        manager.providers_len = 4;
        std.debug.assert(manager.providers_len <= 4);
        return manager;
    }

    // Configure OAuth provider.
    pub fn configure_provider(
        self: *OAuthManager,
        provider: OAuthProvider,
        client_id: []const u8,
        client_secret: []const u8,
        redirect_uri: []const u8,
    ) bool {
        std.debug.assert(client_id.len > 0);
        std.debug.assert(client_id.len <= MAX_CLIENT_ID_LEN);
        std.debug.assert(client_secret.len <= MAX_CLIENT_SECRET_LEN);
        std.debug.assert(redirect_uri.len > 0);
        std.debug.assert(redirect_uri.len <= MAX_REDIRECT_URI_LEN);
        var i: u32 = 0;
        while (i < self.providers_len) : (i += 1) {
            if (self.providers[i].provider == provider) {
                std.mem.copyForwards(u8, &self.providers[i].client_id, client_id);
                self.providers[i].client_id_len = @intCast(client_id.len);
                std.mem.copyForwards(u8, &self.providers[i].client_secret, client_secret);
                self.providers[i].client_secret_len = @intCast(client_secret.len);
                std.mem.copyForwards(u8, &self.providers[i].redirect_uri, redirect_uri);
                self.providers[i].redirect_uri_len = @intCast(redirect_uri.len);
                self.providers[i].enabled = true;
                std.debug.assert(self.providers[i].client_id_len > 0);
                std.debug.assert(self.providers[i].redirect_uri_len > 0);
                return true;
            }
        }
        return false;
    }

    // Get provider configuration.
    pub fn get_provider_config(
        self: *const OAuthManager,
        provider: OAuthProvider,
    ) ?*const OAuthProviderConfig {
        std.debug.assert(self.providers_len <= 4);
        var i: u32 = 0;
        while (i < self.providers_len) : (i += 1) {
            if (self.providers[i].provider == provider) {
                return &self.providers[i];
            }
        }
        return null;
    }
};

// Get OAuth authorization URL for provider.
pub fn get_authorization_url(
    manager: *const OAuthManager,
    provider: OAuthProvider,
    state: []const u8,
    url_out: []u8,
) u32 {
    std.debug.assert(state.len > 0);
    std.debug.assert(state.len <= MAX_STATE_LEN);
    std.debug.assert(url_out.len >= 1024);
    const config = manager.get_provider_config(provider) orelse {
        return 0;
    };
    if (!config.enabled) {
        return 0;
    }
    const base_url = get_provider_base_url(provider);
    var url_len: u32 = 0;
    const base_len = @min(base_url.len, url_out.len);
    std.mem.copyForwards(u8, url_out[url_len..], base_url[0..base_len]);
    url_len += @intCast(base_len);
    const client_id_str = config.client_id[0..config.client_id_len];
    const redirect_str = config.redirect_uri[0..config.redirect_uri_len];
    var params_buf: [2048]u8 = undefined;
    const params_len = build_auth_params(client_id_str, redirect_str, state, &params_buf);
    const params_copy_len = @min(params_len, url_out.len - url_len);
    std.mem.copyForwards(u8, url_out[url_len..], params_buf[0..params_copy_len]);
    url_len += @intCast(params_copy_len);
    std.debug.assert(url_len > 0);
    std.debug.assert(url_len <= url_out.len);
    return url_len;
}

// Get provider base URL.
fn get_provider_base_url(provider: OAuthProvider) []const u8 {
    std.debug.assert(@intFromEnum(provider) < 4);
    return switch (provider) {
        .google => "https://accounts.google.com/o/oauth2/v2/auth?",
        .facebook => "https://www.facebook.com/v18.0/dialog/oauth?",
        .github => "https://github.com/login/oauth/authorize?",
        .apple => "https://appleid.apple.com/auth/authorize?",
    };
}

// Build authorization parameters.
fn build_auth_params(
    client_id: []const u8,
    redirect_uri: []const u8,
    state: []const u8,
    params_out: []u8,
) u32 {
    std.debug.assert(client_id.len > 0);
    std.debug.assert(redirect_uri.len > 0);
    std.debug.assert(state.len > 0);
    std.debug.assert(params_out.len >= 2048);
    const response_type = "response_type=code";
    const client_id_param = "&client_id=";
    const redirect_param = "&redirect_uri=";
    const state_param = "&state=";
    const scope = "&scope=openid%20email%20profile";
    var params_len: u32 = 0;
    const response_type_len = @min(response_type.len, params_out.len - params_len);
    std.mem.copyForwards(u8, params_out[params_len..], response_type[0..response_type_len]);
    params_len += @intCast(response_type_len);
    const client_id_param_len = @min(client_id_param.len, params_out.len - params_len);
    std.mem.copyForwards(u8, params_out[params_len..], client_id_param[0..client_id_param_len]);
    params_len += @intCast(client_id_param_len);
    const client_id_len = @min(client_id.len, params_out.len - params_len);
    std.mem.copyForwards(u8, params_out[params_len..], client_id[0..client_id_len]);
    params_len += @intCast(client_id_len);
    const redirect_param_len = @min(redirect_param.len, params_out.len - params_len);
    std.mem.copyForwards(u8, params_out[params_len..], redirect_param[0..redirect_param_len]);
    params_len += @intCast(redirect_param_len);
    const redirect_uri_len = @min(redirect_uri.len, params_out.len - params_len);
    std.mem.copyForwards(u8, params_out[params_len..], redirect_uri[0..redirect_uri_len]);
    params_len += @intCast(redirect_uri_len);
    const state_param_len = @min(state_param.len, params_out.len - params_len);
    std.mem.copyForwards(u8, params_out[params_len..], state_param[0..state_param_len]);
    params_len += @intCast(state_param_len);
    const state_len = @min(state.len, params_out.len - params_len);
    std.mem.copyForwards(u8, params_out[params_len..], state[0..state_len]);
    params_len += @intCast(state_len);
    const scope_len = @min(scope.len, params_out.len - params_len);
    std.mem.copyForwards(u8, params_out[params_len..], scope[0..scope_len]);
    params_len += @intCast(scope_len);
    std.debug.assert(params_len > 0);
    std.debug.assert(params_len <= params_out.len);
    return params_len;
}

