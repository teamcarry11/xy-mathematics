//! Grain Mobile Core OS Integration: Register endpoints with Grain OS API Server.
//!
//! Why: Integrate mobile endpoints with Grain OS API Server route registration.
//! Architecture: Route registration, handler adapter setup, middleware integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-05-104028-pst: Grain Mobile Agent

const std = @import("std");
const grain_os_api = @import("../../grain_os/api_server.zig");
const grain_os_compositor = @import("../../grain_os/compositor.zig");
const handler_adapters = @import("handler_adapters.zig");
const route_registration = @import("route_registration.zig");
const endpoints = @import("endpoints.zig");
const handlers = @import("handlers.zig");

// Register all mobile endpoints with Grain OS API Server.
pub fn register_mobile_endpoints_with_compositor(
    compositor: *grain_os_compositor.Compositor,
    handler_context: *handlers.HandlerContext,
) u32 {
    std.debug.assert(compositor != null);
    std.debug.assert(handler_context != null);
    handler_adapters.set_handler_context(handler_context);
    var api_server_ptr = &compositor.api_server;
    handler_adapters.set_api_server(api_server_ptr);
    var count: u32 = 0;
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.post,
        endpoints.AUTH_REGISTER_PATH,
        handler_adapters.handle_register_adapter,
    )) {
        count += 1;
    }
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.post,
        endpoints.AUTH_LOGIN_PATH,
        handler_adapters.handle_login_adapter,
    )) {
        count += 1;
    }
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.post,
        endpoints.AUTH_LOGOUT_PATH,
        handler_adapters.handle_logout_adapter,
    )) {
        count += 1;
    }
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.post,
        endpoints.AUTH_REFRESH_PATH,
        handler_adapters.handle_refresh_adapter,
    )) {
        count += 1;
    }
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.post,
        endpoints.AUTH_OTP_SEND_PATH,
        handler_adapters.handle_otp_send_adapter,
    )) {
        count += 1;
    }
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.post,
        endpoints.AUTH_OTP_VERIFY_PATH,
        handler_adapters.handle_otp_verify_adapter,
    )) {
        count += 1;
    }
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.post,
        endpoints.AUTH_2FA_ENABLE_PATH,
        handler_adapters.handle_2fa_enable_adapter,
    )) {
        count += 1;
    }
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.post,
        endpoints.AUTH_2FA_VERIFY_PATH,
        handler_adapters.handle_2fa_verify_adapter,
    )) {
        count += 1;
    }
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.get,
        endpoints.USERS_PROFILE_PATH,
        handler_adapters.handle_users_profile_adapter,
    )) {
        count += 1;
    }
    if (compositor.register_api_route(
        grain_os_api.HttpMethod.get,
        endpoints.USERS_SETTINGS_PATH,
        handler_adapters.handle_users_settings_adapter,
    )) {
        count += 1;
    }
    std.debug.assert(count <= 10);
    return count;
}

