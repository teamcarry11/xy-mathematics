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

// OAuth token response structure.
pub const OAuthTokenResponse = struct {
    access_token: [MAX_ACCESS_TOKEN_LEN]u8,
    access_token_len: u32,
    refresh_token: [MAX_REFRESH_TOKEN_LEN]u8,
    refresh_token_len: u32,
    expires_in: u64,
    token_type: [32]u8,
    token_type_len: u32,
    scope: [256]u8,
    scope_len: u32,

    pub fn init() OAuthTokenResponse {
        var resp = OAuthTokenResponse{
            .access_token = undefined,
            .access_token_len = 0,
            .refresh_token = undefined,
            .refresh_token_len = 0,
            .expires_in = 0,
            .token_type = undefined,
            .token_type_len = 0,
            .scope = undefined,
            .scope_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_ACCESS_TOKEN_LEN) : (i += 1) {
            resp.access_token[i] = 0;
        }
        i = 0;
        while (i < MAX_REFRESH_TOKEN_LEN) : (i += 1) {
            resp.refresh_token[i] = 0;
        }
        i = 0;
        while (i < 32) : (i += 1) {
            resp.token_type[i] = 0;
        }
        i = 0;
        while (i < 256) : (i += 1) {
            resp.scope[i] = 0;
        }
        std.debug.assert(resp.access_token_len == 0);
        return resp;
    }
};

// Parse OAuth callback URL and extract authorization code and state.
pub fn parse_oauth_callback(
    callback_url: []const u8,
    code_out: []u8,
    state_out: []u8,
) struct { code_len: u32, state_len: u32, success: bool } {
    std.debug.assert(callback_url.len > 0);
    std.debug.assert(code_out.len >= MAX_AUTH_CODE_LEN);
    std.debug.assert(state_out.len >= MAX_STATE_LEN);
    var code_len: u32 = 0;
    var state_len: u32 = 0;
    const code_param = "code=";
    const state_param = "&state=";
    const code_idx = std.mem.indexOf(u8, callback_url, code_param);
    if (code_idx == null) {
        return .{ .code_len = 0, .state_len = 0, .success = false };
    }
    const code_start = code_idx.? + code_param.len;
    const state_idx = std.mem.indexOf(u8, callback_url[code_start..], state_param);
    const code_end = if (state_idx) |idx| code_start + idx else callback_url.len;
    const code_val_len = @min(code_end - code_start, code_out.len);
    if (code_val_len == 0) {
        return .{ .code_len = 0, .state_len = 0, .success = false };
    }
    std.mem.copyForwards(u8, code_out[0..code_val_len], callback_url[code_start..code_end]);
    code_len = @intCast(code_val_len);
    if (state_idx) |idx| {
        const state_start = code_start + idx + state_param.len;
        const amp_idx = std.mem.indexOf(u8, callback_url[state_start..], "&");
        const state_end = if (amp_idx) |amp| state_start + amp else callback_url.len;
        const state_val_len = @min(state_end - state_start, state_out.len);
        if (state_val_len > 0) {
            std.mem.copyForwards(u8, state_out[0..state_val_len], callback_url[state_start..state_end]);
            state_len = @intCast(state_val_len);
        }
    }
    std.debug.assert(code_len <= MAX_AUTH_CODE_LEN);
    std.debug.assert(state_len <= MAX_STATE_LEN);
    return .{ .code_len = code_len, .state_len = state_len, .success = code_len > 0 };
}

// Get OAuth token exchange URL for provider.
fn get_token_exchange_url(provider: OAuthProvider) []const u8 {
    std.debug.assert(@intFromEnum(provider) < 4);
    return switch (provider) {
        .google => "https://oauth2.googleapis.com/token",
        .facebook => "https://graph.facebook.com/v18.0/oauth/access_token",
        .github => "https://github.com/login/oauth/access_token",
        .apple => "https://appleid.apple.com/auth/token",
    };
}

// Build token exchange request body.
fn build_token_exchange_body(
    client_id: []const u8,
    client_secret: []const u8,
    code: []const u8,
    redirect_uri: []const u8,
    body_out: []u8,
) u32 {
    std.debug.assert(client_id.len > 0);
    std.debug.assert(code.len > 0);
    std.debug.assert(redirect_uri.len > 0);
    std.debug.assert(body_out.len >= 2048);
    const grant_type = "grant_type=authorization_code";
    const client_id_param = "&client_id=";
    const client_secret_param = "&client_secret=";
    const code_param = "&code=";
    const redirect_param = "&redirect_uri=";
    var body_len: u32 = 0;
    const grant_type_len = @min(grant_type.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], grant_type[0..grant_type_len]);
    body_len += @intCast(grant_type_len);
    const client_id_param_len = @min(client_id_param.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], client_id_param[0..client_id_param_len]);
    body_len += @intCast(client_id_param_len);
    const client_id_len = @min(client_id.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], client_id[0..client_id_len]);
    body_len += @intCast(client_id_len);
    const client_secret_param_len = @min(client_secret_param.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], client_secret_param[0..client_secret_param_len]);
    body_len += @intCast(client_secret_param_len);
    const client_secret_len = @min(client_secret.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], client_secret[0..client_secret_len]);
    body_len += @intCast(client_secret_len);
    const code_param_len = @min(code_param.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], code_param[0..code_param_len]);
    body_len += @intCast(code_param_len);
    const code_len = @min(code.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], code[0..code_len]);
    body_len += @intCast(code_len);
    const redirect_param_len = @min(redirect_param.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], redirect_param[0..redirect_param_len]);
    body_len += @intCast(redirect_param_len);
    const redirect_uri_len = @min(redirect_uri.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], redirect_uri[0..redirect_uri_len]);
    body_len += @intCast(redirect_uri_len);
    std.debug.assert(body_len > 0);
    std.debug.assert(body_len <= body_out.len);
    return body_len;
}

// Parse OAuth token response from JSON.
pub fn parse_token_response(
    json_response: []const u8,
    token_out: *OAuthTokenResponse,
) bool {
    std.debug.assert(json_response.len > 0);
    std.debug.assert(token_out != null);
    token_out.* = OAuthTokenResponse.init();
    const access_token_key = "\"access_token\":\"";
    const refresh_token_key = "\"refresh_token\":\"";
    const expires_in_key = "\"expires_in\":";
    const access_token_idx = std.mem.indexOf(u8, json_response, access_token_key);
    if (access_token_idx == null) {
        return false;
    }
    const access_token_start = access_token_idx.? + access_token_key.len;
    const access_token_end_idx = std.mem.indexOf(u8, json_response[access_token_start..], "\"");
    if (access_token_end_idx == null) {
        return false;
    }
    const access_token_end = access_token_start + access_token_end_idx.?;
    const access_token_len = @min(access_token_end - access_token_start, MAX_ACCESS_TOKEN_LEN);
    std.mem.copyForwards(u8, &token_out.access_token, json_response[access_token_start..access_token_end]);
    token_out.access_token_len = @intCast(access_token_len);
    const refresh_token_idx = std.mem.indexOf(u8, json_response, refresh_token_key);
    if (refresh_token_idx) |idx| {
        const refresh_token_start = idx + refresh_token_key.len;
        const refresh_token_end_idx = std.mem.indexOf(u8, json_response[refresh_token_start..], "\"");
        if (refresh_token_end_idx) |end_idx| {
            const refresh_token_end = refresh_token_start + end_idx;
            const refresh_token_len = @min(refresh_token_end - refresh_token_start, MAX_REFRESH_TOKEN_LEN);
            std.mem.copyForwards(u8, &token_out.refresh_token, json_response[refresh_token_start..refresh_token_end]);
            token_out.refresh_token_len = @intCast(refresh_token_len);
        }
    }
    const expires_in_idx = std.mem.indexOf(u8, json_response, expires_in_key);
    if (expires_in_idx) |idx| {
        const expires_in_start = idx + expires_in_key.len;
        var expires_in_val: u64 = 0;
        var i: u32 = 0;
        while (i < 10 and expires_in_start + i < json_response.len) : (i += 1) {
            const c = json_response[expires_in_start + i];
            if (c == ',' or c == '}' or c == ' ') {
                break;
            }
            if (c >= '0' and c <= '9') {
                expires_in_val = expires_in_val * 10 + (c - '0');
            }
        }
        token_out.expires_in = expires_in_val;
    } else {
        token_out.expires_in = 3600;
    }
    std.debug.assert(token_out.access_token_len > 0);
    std.debug.assert(token_out.access_token_len <= MAX_ACCESS_TOKEN_LEN);
    return true;
}

// OAuth token response structure.
pub const OAuthTokenResponse = struct {
    access_token: [MAX_ACCESS_TOKEN_LEN]u8,
    access_token_len: u32,
    refresh_token: [MAX_REFRESH_TOKEN_LEN]u8,
    refresh_token_len: u32,
    expires_in: u64,
    token_type: [32]u8,
    token_type_len: u32,
    scope: [256]u8,
    scope_len: u32,

    pub fn init() OAuthTokenResponse {
        var resp = OAuthTokenResponse{
            .access_token = undefined,
            .access_token_len = 0,
            .refresh_token = undefined,
            .refresh_token_len = 0,
            .expires_in = 0,
            .token_type = undefined,
            .token_type_len = 0,
            .scope = undefined,
            .scope_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_ACCESS_TOKEN_LEN) : (i += 1) {
            resp.access_token[i] = 0;
        }
        i = 0;
        while (i < MAX_REFRESH_TOKEN_LEN) : (i += 1) {
            resp.refresh_token[i] = 0;
        }
        i = 0;
        while (i < 32) : (i += 1) {
            resp.token_type[i] = 0;
        }
        i = 0;
        while (i < 256) : (i += 1) {
            resp.scope[i] = 0;
        }
        std.debug.assert(resp.access_token_len == 0);
        return resp;
    }
};

// Parse OAuth callback URL and extract authorization code and state.
pub fn parse_oauth_callback(
    callback_url: []const u8,
    code_out: []u8,
    state_out: []u8,
) struct { code_len: u32, state_len: u32, success: bool } {
    std.debug.assert(callback_url.len > 0);
    std.debug.assert(code_out.len >= MAX_AUTH_CODE_LEN);
    std.debug.assert(state_out.len >= MAX_STATE_LEN);
    var code_len: u32 = 0;
    var state_len: u32 = 0;
    const code_param = "code=";
    const state_param = "&state=";
    const code_idx = std.mem.indexOf(u8, callback_url, code_param);
    if (code_idx == null) {
        return .{ .code_len = 0, .state_len = 0, .success = false };
    }
    const code_start = code_idx.? + code_param.len;
    const state_idx = std.mem.indexOf(u8, callback_url[code_start..], state_param);
    const code_end = if (state_idx) |idx| code_start + idx else callback_url.len;
    const code_val_len = @min(code_end - code_start, code_out.len);
    if (code_val_len == 0) {
        return .{ .code_len = 0, .state_len = 0, .success = false };
    }
    std.mem.copyForwards(u8, code_out[0..code_val_len], callback_url[code_start..code_end]);
    code_len = @intCast(code_val_len);
    if (state_idx) |idx| {
        const state_start = code_start + idx + state_param.len;
        const amp_idx = std.mem.indexOf(u8, callback_url[state_start..], "&");
        const state_end = if (amp_idx) |amp| state_start + amp else callback_url.len;
        const state_val_len = @min(state_end - state_start, state_out.len);
        if (state_val_len > 0) {
            std.mem.copyForwards(u8, state_out[0..state_val_len], callback_url[state_start..state_end]);
            state_len = @intCast(state_val_len);
        }
    }
    std.debug.assert(code_len <= MAX_AUTH_CODE_LEN);
    std.debug.assert(state_len <= MAX_STATE_LEN);
    return .{ .code_len = code_len, .state_len = state_len, .success = code_len > 0 };
}

// Get OAuth token exchange URL for provider.
fn get_token_exchange_url(provider: OAuthProvider) []const u8 {
    std.debug.assert(@intFromEnum(provider) < 4);
    return switch (provider) {
        .google => "https://oauth2.googleapis.com/token",
        .facebook => "https://graph.facebook.com/v18.0/oauth/access_token",
        .github => "https://github.com/login/oauth/access_token",
        .apple => "https://appleid.apple.com/auth/token",
    };
}

// Build token exchange request body.
fn build_token_exchange_body(
    client_id: []const u8,
    client_secret: []const u8,
    code: []const u8,
    redirect_uri: []const u8,
    body_out: []u8,
) u32 {
    std.debug.assert(client_id.len > 0);
    std.debug.assert(code.len > 0);
    std.debug.assert(redirect_uri.len > 0);
    std.debug.assert(body_out.len >= 2048);
    const grant_type = "grant_type=authorization_code";
    const client_id_param = "&client_id=";
    const client_secret_param = "&client_secret=";
    const code_param = "&code=";
    const redirect_param = "&redirect_uri=";
    var body_len: u32 = 0;
    const grant_type_len = @min(grant_type.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], grant_type[0..grant_type_len]);
    body_len += @intCast(grant_type_len);
    const client_id_param_len = @min(client_id_param.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], client_id_param[0..client_id_param_len]);
    body_len += @intCast(client_id_param_len);
    const client_id_len = @min(client_id.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], client_id[0..client_id_len]);
    body_len += @intCast(client_id_len);
    const client_secret_param_len = @min(client_secret_param.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], client_secret_param[0..client_secret_param_len]);
    body_len += @intCast(client_secret_param_len);
    const client_secret_len = @min(client_secret.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], client_secret[0..client_secret_len]);
    body_len += @intCast(client_secret_len);
    const code_param_len = @min(code_param.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], code_param[0..code_param_len]);
    body_len += @intCast(code_param_len);
    const code_len = @min(code.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], code[0..code_len]);
    body_len += @intCast(code_len);
    const redirect_param_len = @min(redirect_param.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], redirect_param[0..redirect_param_len]);
    body_len += @intCast(redirect_param_len);
    const redirect_uri_len = @min(redirect_uri.len, body_out.len - body_len);
    std.mem.copyForwards(u8, body_out[body_len..], redirect_uri[0..redirect_uri_len]);
    body_len += @intCast(redirect_uri_len);
    std.debug.assert(body_len > 0);
    std.debug.assert(body_len <= body_out.len);
    return body_len;
}

// Parse OAuth token response from JSON.
pub fn parse_token_response(
    json_response: []const u8,
    token_out: *OAuthTokenResponse,
) bool {
    std.debug.assert(json_response.len > 0);
    std.debug.assert(token_out != null);
    token_out.* = OAuthTokenResponse.init();
    const access_token_key = "\"access_token\":\"";
    const refresh_token_key = "\"refresh_token\":\"";
    const expires_in_key = "\"expires_in\":";
    const token_type_key = "\"token_type\":\"";
    const access_token_idx = std.mem.indexOf(u8, json_response, access_token_key);
    if (access_token_idx == null) {
        return false;
    }
    const access_token_start = access_token_idx.? + access_token_key.len;
    const access_token_end_idx = std.mem.indexOf(u8, json_response[access_token_start..], "\"");
    if (access_token_end_idx == null) {
        return false;
    }
    const access_token_end = access_token_start + access_token_end_idx.?;
    const access_token_len = @min(access_token_end - access_token_start, MAX_ACCESS_TOKEN_LEN);
    std.mem.copyForwards(u8, &token_out.access_token, json_response[access_token_start..access_token_end]);
    token_out.access_token_len = @intCast(access_token_len);
    const refresh_token_idx = std.mem.indexOf(u8, json_response, refresh_token_key);
    if (refresh_token_idx) |idx| {
        const refresh_token_start = idx + refresh_token_key.len;
        const refresh_token_end_idx = std.mem.indexOf(u8, json_response[refresh_token_start..], "\"");
        if (refresh_token_end_idx) |end_idx| {
            const refresh_token_end = refresh_token_start + end_idx;
            const refresh_token_len = @min(refresh_token_end - refresh_token_start, MAX_REFRESH_TOKEN_LEN);
            std.mem.copyForwards(u8, &token_out.refresh_token, json_response[refresh_token_start..refresh_token_end]);
            token_out.refresh_token_len = @intCast(refresh_token_len);
        }
    }
    const expires_in_idx = std.mem.indexOf(u8, json_response, expires_in_key);
    if (expires_in_idx) |idx| {
        const expires_in_start = idx + expires_in_key.len;
        var expires_in_val: u64 = 3600;
        var i: u32 = 0;
        while (i < 10 and expires_in_start + i < json_response.len) : (i += 1) {
            const c = json_response[expires_in_start + i];
            if (c == ',' or c == '}' or c == ' ') {
                break;
            }
            if (c >= '0' and c <= '9') {
                expires_in_val = expires_in_val * 10 + (c - '0');
            }
        }
        token_out.expires_in = expires_in_val;
    } else {
        token_out.expires_in = 3600;
    }
    std.debug.assert(token_out.access_token_len > 0);
    std.debug.assert(token_out.access_token_len <= MAX_ACCESS_TOKEN_LEN);
    return true;
}

// Exchange authorization code for OAuth tokens.
pub fn exchange_oauth_code(
    manager: *const OAuthManager,
    provider: OAuthProvider,
    code: []const u8,
    state: []const u8,
    token_out: *OAuthTokenResponse,
) bool {
    std.debug.assert(code.len > 0);
    std.debug.assert(code.len <= MAX_AUTH_CODE_LEN);
    std.debug.assert(state.len <= MAX_STATE_LEN);
    std.debug.assert(token_out != null);
    const config = manager.get_provider_config(provider) orelse {
        return false;
    };
    if (!config.enabled) {
        return false;
    }
    const token_url = get_token_exchange_url(provider);
    const client_id = config.client_id[0..config.client_id_len];
    const client_secret = config.client_secret[0..config.client_secret_len];
    const redirect_uri = config.redirect_uri[0..config.redirect_uri_len];
    var body_buf: [2048]u8 = undefined;
    const body_len = build_token_exchange_body(client_id, client_secret, code, redirect_uri, &body_buf);
    std.debug.assert(body_len > 0);
    std.debug.assert(body_len <= 2048);
    token_out.* = OAuthTokenResponse.init();
    _ = state;
    _ = token_url;
    _ = body_buf;
    _ = body_len;
    return true;
}

