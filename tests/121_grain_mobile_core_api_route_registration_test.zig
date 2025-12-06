//! Tests for Grain Mobile Core API route registration.
//!
//! Why: Verify route registration functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_carry_core = @import("grain_carry_core");
const api = grain_carry_core.api;

test "endpoint config initialization" {
    const config = api.route_registration.EndpointConfig.init(
        api.endpoints.AUTH_REGISTER_PATH,
        api.route_registration.HttpMethod.post,
        false,
        true,
    );
    
    std.debug.assert(config.path.len > 0);
    std.debug.assert(config.method == api.route_registration.HttpMethod.post);
    std.debug.assert(!config.requires_auth);
    std.debug.assert(config.is_public);
}

test "mobile endpoints array" {
    std.debug.assert(api.route_registration.MOBILE_ENDPOINTS.len == 10);
    
    const first = api.route_registration.MOBILE_ENDPOINTS[0];
    std.debug.assert(std.mem.eql(u8, first.path, api.endpoints.AUTH_REGISTER_PATH));
    std.debug.assert(first.method == api.route_registration.HttpMethod.post);
}

test "get endpoint config by path" {
    const config = api.route_registration.get_endpoint_config(api.endpoints.AUTH_LOGIN_PATH);
    
    std.debug.assert(config != null);
    std.debug.assert(config.?.path.len > 0);
    std.debug.assert(config.?.method == api.route_registration.HttpMethod.post);
}

test "get endpoint config invalid path" {
    const config = api.route_registration.get_endpoint_config("/api/v1/invalid");
    
    std.debug.assert(config == null);
}

test "get middleware config for public endpoint" {
    const endpoint_config = api.route_registration.EndpointConfig.init(
        api.endpoints.AUTH_REGISTER_PATH,
        api.route_registration.HttpMethod.post,
        false,
        true,
    );
    
    const middleware_config = api.route_registration.get_middleware_config_for_endpoint(&endpoint_config);
    
    std.debug.assert(middleware_config.use_cors);
    std.debug.assert(middleware_config.use_validation);
    std.debug.assert(!middleware_config.use_auth);
}

test "get middleware config for protected endpoint" {
    const endpoint_config = api.route_registration.EndpointConfig.init(
        api.endpoints.USERS_PROFILE_PATH,
        api.route_registration.HttpMethod.get,
        true,
        false,
    );
    
    const middleware_config = api.route_registration.get_middleware_config_for_endpoint(&endpoint_config);
    
    std.debug.assert(middleware_config.use_auth);
    std.debug.assert(middleware_config.use_validation);
    std.debug.assert(middleware_config.use_rate_limit);
}

test "register mobile endpoint" {
    const config = api.route_registration.EndpointConfig.init(
        api.endpoints.AUTH_REGISTER_PATH,
        api.route_registration.HttpMethod.post,
        false,
        true,
    );
    
    const result = api.route_registration.register_mobile_endpoint(&config, api.handlers.handle_register);
    
    std.debug.assert(result == api.route_registration.RegistrationResult.success);
}

test "register all mobile endpoints" {
    const count = api.route_registration.register_all_mobile_endpoints();
    
    std.debug.assert(count == 10);
}

test "registration result enum values" {
    std.debug.assert(@intFromEnum(api.route_registration.RegistrationResult.success) == 0);
    std.debug.assert(@intFromEnum(api.route_registration.RegistrationResult.route_exists) == 1);
    std.debug.assert(@intFromEnum(api.route_registration.RegistrationResult.invalid_path) == 2);
}

