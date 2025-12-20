// Mobile app API endpoint definitions for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Defines endpoint paths and prepares for handler registration
// Handler functions will be implemented when JSON support is available
// Note: Handler functions will use Grain OS API Server types when integrated

const std = @import("std");

// Endpoint path constants
pub const AUTH_REGISTER_PATH: []const u8 = "/api/v1/auth/register";
pub const AUTH_LOGIN_PATH: []const u8 = "/api/v1/auth/login";
pub const AUTH_LOGOUT_PATH: []const u8 = "/api/v1/auth/logout";
pub const AUTH_REFRESH_PATH: []const u8 = "/api/v1/auth/refresh";
pub const AUTH_OTP_SEND_PATH: []const u8 = "/api/v1/auth/otp/send";
pub const AUTH_OTP_VERIFY_PATH: []const u8 = "/api/v1/auth/otp/verify";
pub const AUTH_2FA_ENABLE_PATH: []const u8 = "/api/v1/auth/2fa/enable";
pub const AUTH_2FA_VERIFY_PATH: []const u8 = "/api/v1/auth/2fa/verify";
pub const AUTH_OAUTH_CALLBACK_PATH: []const u8 = "/api/v1/auth/oauth/callback";
pub const USERS_PROFILE_PATH: []const u8 = "/api/v1/users/profile";
pub const USERS_SETTINGS_PATH: []const u8 = "/api/v1/users/settings";

pub const MAX_ENDPOINT_PATHS: u32 = 32;

// Endpoint path registry
pub const EndpointRegistry = struct {
    paths: [MAX_ENDPOINT_PATHS][]const u8,
    paths_len: u32,

    pub fn init() EndpointRegistry {
        return EndpointRegistry{
            .paths = undefined,
            .paths_len = 0,
        };
    }

    pub fn get_all_paths(self: *const EndpointRegistry) []const []const u8 {
        std.debug.assert(self.paths_len <= MAX_ENDPOINT_PATHS);
        return self.paths[0..self.paths_len];
    }
};

pub fn init_endpoint_registry() EndpointRegistry {
    var registry = EndpointRegistry.init();
    registry.paths[0] = AUTH_REGISTER_PATH;
    registry.paths[1] = AUTH_LOGIN_PATH;
    registry.paths[2] = AUTH_LOGOUT_PATH;
    registry.paths[3] = AUTH_REFRESH_PATH;
    registry.paths[4] = AUTH_OTP_SEND_PATH;
    registry.paths[5] = AUTH_OTP_VERIFY_PATH;
    registry.paths[6] = AUTH_2FA_ENABLE_PATH;
    registry.paths[7] = AUTH_2FA_VERIFY_PATH;
    registry.paths[8] = AUTH_OAUTH_CALLBACK_PATH;
    registry.paths[9] = USERS_PROFILE_PATH;
    registry.paths[10] = USERS_SETTINGS_PATH;
    registry.paths_len = 11;
    
    std.debug.assert(registry.paths_len <= MAX_ENDPOINT_PATHS);
    
    return registry;
}

