//! Tests for Grain Mobile Core API endpoint definitions.
//!
//! Why: Verify endpoint path definitions and registry.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_mobile_core = @import("grain_mobile_core");
const api = grain_mobile_core.api.endpoints;

test "endpoint path constants" {
    std.debug.assert(api.AUTH_REGISTER_PATH.len > 0);
    std.debug.assert(api.AUTH_LOGIN_PATH.len > 0);
    std.debug.assert(api.AUTH_LOGOUT_PATH.len > 0);
    std.debug.assert(api.AUTH_REFRESH_PATH.len > 0);
    std.debug.assert(api.USERS_PROFILE_PATH.len > 0);
}

test "endpoint registry initialization" {
    const registry = api.init_endpoint_registry();
    
    std.debug.assert(registry.paths_len > 0);
    std.debug.assert(registry.paths_len <= api.MAX_ENDPOINT_PATHS);
}

test "endpoint registry get all paths" {
    const registry = api.init_endpoint_registry();
    const paths = registry.get_all_paths();
    
    std.debug.assert(paths.len == registry.paths_len);
    std.debug.assert(paths.len > 0);
}

test "endpoint paths are valid" {
    const registry = api.init_endpoint_registry();
    const paths = registry.get_all_paths();
    
    var i: u32 = 0;
    while (i < paths.len) : (i += 1) {
        std.debug.assert(paths[i].len > 0);
        std.debug.assert(paths[i][0] == '/');
    }
}

