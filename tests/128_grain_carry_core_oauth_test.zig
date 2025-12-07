//! Tests for Grain Carry Core OAuth Integration.
//!
//! Why: Verify OAuth integration functionality for OAuth providers.
//! Architecture: Comprehensive test coverage for OAuth module.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-060952-pst: Grain Carry Agent

const std = @import("std");
const testing = std.testing;
const grain_carry_core = @import("grain_carry_core");
const oauth = grain_carry_core.oauth;

test "oauth manager initialization" {
    const manager = oauth.OAuthManager.init();
    try testing.expect(manager.providers_len == 4);
    try testing.expect(manager.providers[0].provider == oauth.OAuthProvider.google);
    try testing.expect(manager.providers[1].provider == oauth.OAuthProvider.facebook);
    try testing.expect(manager.providers[2].provider == oauth.OAuthProvider.github);
    try testing.expect(manager.providers[3].provider == oauth.OAuthProvider.apple);
}

test "oauth manager configure provider" {
    var manager = oauth.OAuthManager.init();
    const client_id = "test_client_id";
    const client_secret = "test_client_secret";
    const redirect_uri = "https://example.com/callback";
    const success = manager.configure_provider(
        oauth.OAuthProvider.google,
        client_id,
        client_secret,
        redirect_uri,
    );
    try testing.expect(success);
    const config = manager.get_provider_config(oauth.OAuthProvider.google);
    try testing.expect(config != null);
    try testing.expect(config.?.enabled);
    try testing.expect(std.mem.eql(u8, config.?.client_id[0..config.?.client_id_len], client_id));
    try testing.expect(std.mem.eql(u8, config.?.redirect_uri[0..config.?.redirect_uri_len], redirect_uri));
}

test "oauth manager get provider config" {
    var manager = oauth.OAuthManager.init();
    const client_id = "test_client_id";
    const client_secret = "test_client_secret";
    const redirect_uri = "https://example.com/callback";
    _ = manager.configure_provider(
        oauth.OAuthProvider.github,
        client_id,
        client_secret,
        redirect_uri,
    );
    const config = manager.get_provider_config(oauth.OAuthProvider.github);
    try testing.expect(config != null);
    try testing.expect(config.?.provider == oauth.OAuthProvider.github);
    try testing.expect(config.?.enabled);
}

test "oauth get authorization url google" {
    var manager = oauth.OAuthManager.init();
    const client_id = "test_client_id";
    const client_secret = "test_client_secret";
    const redirect_uri = "https://example.com/callback";
    _ = manager.configure_provider(
        oauth.OAuthProvider.google,
        client_id,
        client_secret,
        redirect_uri,
    );
    const state = "test_state_123";
    var url_buf: [2048]u8 = undefined;
    const url_len = oauth.get_authorization_url(&manager, oauth.OAuthProvider.google, state, &url_buf);
    try testing.expect(url_len > 0);
    try testing.expect(std.mem.startsWith(u8, url_buf[0..url_len], "https://accounts.google.com/o/oauth2/v2/auth?"));
}

test "oauth get authorization url github" {
    var manager = oauth.OAuthManager.init();
    const client_id = "test_client_id";
    const client_secret = "test_client_secret";
    const redirect_uri = "https://example.com/callback";
    _ = manager.configure_provider(
        oauth.OAuthProvider.github,
        client_id,
        client_secret,
        redirect_uri,
    );
    const state = "test_state_456";
    var url_buf: [2048]u8 = undefined;
    const url_len = oauth.get_authorization_url(&manager, oauth.OAuthProvider.github, state, &url_buf);
    try testing.expect(url_len > 0);
    try testing.expect(std.mem.startsWith(u8, url_buf[0..url_len], "https://github.com/login/oauth/authorize?"));
}

test "oauth get authorization url disabled provider" {
    var manager = oauth.OAuthManager.init();
    const state = "test_state";
    var url_buf: [2048]u8 = undefined;
    const url_len = oauth.get_authorization_url(&manager, oauth.OAuthProvider.google, state, &url_buf);
    try testing.expect(url_len == 0);
}

test "oauth get authorization url facebook" {
    var manager = oauth.OAuthManager.init();
    const client_id = "test_client_id";
    const client_secret = "test_client_secret";
    const redirect_uri = "https://example.com/callback";
    _ = manager.configure_provider(
        oauth.OAuthProvider.facebook,
        client_id,
        client_secret,
        redirect_uri,
    );
    const state = "test_state_789";
    var url_buf: [2048]u8 = undefined;
    const url_len = oauth.get_authorization_url(&manager, oauth.OAuthProvider.facebook, state, &url_buf);
    try testing.expect(url_len > 0);
    try testing.expect(std.mem.startsWith(u8, url_buf[0..url_len], "https://www.facebook.com/v18.0/dialog/oauth?"));
}

test "oauth get authorization url apple" {
    var manager = oauth.OAuthManager.init();
    const client_id = "test_client_id";
    const client_secret = "test_client_secret";
    const redirect_uri = "https://example.com/callback";
    _ = manager.configure_provider(
        oauth.OAuthProvider.apple,
        client_id,
        client_secret,
        redirect_uri,
    );
    const state = "test_state_apple";
    var url_buf: [2048]u8 = undefined;
    const url_len = oauth.get_authorization_url(&manager, oauth.OAuthProvider.apple, state, &url_buf);
    try testing.expect(url_len > 0);
    try testing.expect(std.mem.startsWith(u8, url_buf[0..url_len], "https://appleid.apple.com/auth/authorize?"));
}

