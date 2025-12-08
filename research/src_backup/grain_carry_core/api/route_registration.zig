// Route registration helpers for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Provides helpers to register mobile endpoints with Grain OS API Server
// Ready for use when HTTP server is available

const std = @import("std");
const endpoints = @import("endpoints.zig");
const handlers = @import("handlers.zig");
const middleware_integration = @import("middleware_integration.zig");
const integration = @import("integration.zig");

// Note: This module will use Grain OS API Server types when integrated
// For now, we define compatible structures and functions

// HTTP method enum (matches Grain OS API Server HttpMethod)
pub const HttpMethod = enum(u8) {
    get = 0,
    post = 1,
    put = 2,
    delete = 3,
    patch = 4,
    head = 5,
    options = 6,
};

// Route registration result
pub const RegistrationResult = enum(u8) {
    success,
    route_exists,
    invalid_path,
    invalid_method,
    middleware_failed,
    handler_failed,
};

// Endpoint configuration
pub const EndpointConfig = struct {
    path: []const u8,
    method: HttpMethod,
    requires_auth: bool,
    is_public: bool,
    
    pub fn init(
        path: []const u8,
        method: HttpMethod,
        requires_auth: bool,
        is_public: bool,
    ) EndpointConfig {
        std.debug.assert(path.len > 0);
        return EndpointConfig{
            .path = path,
            .method = method,
            .requires_auth = requires_auth,
            .is_public = is_public,
        };
    }
};

// Mobile endpoint configurations
pub const MOBILE_ENDPOINTS: [10]EndpointConfig = .{
    EndpointConfig.init(endpoints.AUTH_REGISTER_PATH, HttpMethod.post, false, true),
    EndpointConfig.init(endpoints.AUTH_LOGIN_PATH, HttpMethod.post, false, true),
    EndpointConfig.init(endpoints.AUTH_LOGOUT_PATH, HttpMethod.post, true, false),
    EndpointConfig.init(endpoints.AUTH_REFRESH_PATH, HttpMethod.post, true, false),
    EndpointConfig.init(endpoints.AUTH_OTP_SEND_PATH, HttpMethod.post, false, true),
    EndpointConfig.init(endpoints.AUTH_OTP_VERIFY_PATH, HttpMethod.post, false, true),
    EndpointConfig.init(endpoints.AUTH_2FA_ENABLE_PATH, HttpMethod.post, true, false),
    EndpointConfig.init(endpoints.AUTH_2FA_VERIFY_PATH, HttpMethod.post, true, false),
    EndpointConfig.init(endpoints.USERS_PROFILE_PATH, HttpMethod.get, true, false),
    EndpointConfig.init(endpoints.USERS_SETTINGS_PATH, HttpMethod.get, true, false),
};

// Route handler adapter (converts mobile handler to Grain OS RouteHandler signature)
// Note: This will be implemented when Grain OS API Server types are available
pub fn create_handler_adapter(
    handler_fn: handlers.HandlerFn,
) *const fn (*integration.HttpRequest, *integration.HttpResponse) void {
    _ = handler_fn;
    // TODO: When Grain OS API Server types are available:
    // 1. Create adapter function that matches RouteHandler signature
    // 2. Extract request data from HttpRequest
    // 3. Call mobile handler function
    // 4. Convert handler result to HttpResponse
    // 5. Return adapter function pointer
    
    // Placeholder adapter
    return struct {
        fn adapter(request: *integration.HttpRequest, response: *integration.HttpResponse) void {
            _ = request;
            _ = response;
            // TODO: Implement handler adapter logic
        }
    }.adapter;
}

// Register single mobile endpoint
pub fn register_mobile_endpoint(
    // api_server: *ApiServer,  // Grain OS API Server (when available)
    config: *const EndpointConfig,
    handler_fn: handlers.HandlerFn,
) RegistrationResult {
    std.debug.assert(config != null);
    std.debug.assert(config.path.len > 0);
    
    // TODO: When Grain OS API Server is available:
    // 1. Create handler adapter from handler_fn
    // 2. Register route with api_server.register_route()
    // 3. Apply middleware based on config (CORS, auth, validation)
    // 4. Return registration result
    
    std.debug.assert(config.path.len > 0);
    std.debug.assert(@intFromEnum(config.method) <= 6);
    
    _ = handler_fn;
    
    return RegistrationResult.success;
}

// Register all mobile endpoints
pub fn register_all_mobile_endpoints(
    // api_server: *ApiServer,  // Grain OS API Server (when available)
) u32 {
    // TODO: When Grain OS API Server is available:
    // 1. Register AUTH_REGISTER_PATH with handle_register
    // 2. Register AUTH_LOGIN_PATH with handle_login
    // 3. Register AUTH_LOGOUT_PATH with handle_logout
    // 4. Register AUTH_REFRESH_PATH with handle_refresh
    // 5. Register AUTH_OTP_SEND_PATH with handle_otp_send
    // 6. Register AUTH_OTP_VERIFY_PATH with handle_otp_verify
    // 7. Register AUTH_2FA_ENABLE_PATH with handle_2fa_enable
    // 8. Register AUTH_2FA_VERIFY_PATH with handle_2fa_verify
    // 9. Register USERS_PROFILE_PATH with handle_users_profile
    // 10. Register USERS_SETTINGS_PATH with handle_users_settings
    // 11. Apply appropriate middleware to each route
    // 12. Return count of registered routes
    
    std.debug.assert(MOBILE_ENDPOINTS.len == 10);
    
    return 10;
}

// Get endpoint configuration by path
pub fn get_endpoint_config(
    path: []const u8,
) ?*const EndpointConfig {
    std.debug.assert(path.len > 0);
    
    var i: u32 = 0;
    while (i < MOBILE_ENDPOINTS.len) : (i += 1) {
        if (std.mem.eql(u8, MOBILE_ENDPOINTS[i].path, path)) {
            return &MOBILE_ENDPOINTS[i];
        }
    }
    
    return null;
}

// Get middleware configuration for endpoint
pub fn get_middleware_config_for_endpoint(
    config: *const EndpointConfig,
) middleware_integration.MiddlewareConfig {
    std.debug.assert(config != null);
    
    if (config.is_public) {
        return middleware_integration.MiddlewareConfig.for_public_endpoint();
    } else if (config.requires_auth) {
        return middleware_integration.MiddlewareConfig.for_protected_endpoint();
    } else {
        return middleware_integration.MiddlewareConfig.for_auth_endpoint();
    }
}

