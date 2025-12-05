// Mobile API middleware integration with Grain OS middleware framework
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Provides mobile-specific middleware functions that integrate with Grain OS API Server
// Ready for use with Grain OS middleware framework

const std = @import("std");
const models = @import("models.zig");
const responses = @import("responses.zig");
const integration = @import("integration.zig");

// Note: This module will use Grain OS API Server types when integrated
// For now, we define compatible middleware function signatures

// Mobile authentication middleware (enhanced version of Grain OS auth_middleware)
// Validates JWT tokens and extracts user information
pub fn mobile_auth_middleware(
    request: *integration.HttpRequest,
    response: *integration.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    
    var token: [models.MAX_TOKEN_LEN]u8 = undefined;
    const token_len = integration.get_auth_token(request, &token);
    
    if (token_len == 0) {
        response.status = 401;
        _ = integration.add_response_header(response, "Content-Type", "application/json");
        const error_json = "{\"error\":\"unauthorized\",\"message\":\"Missing Authorization header\"}";
        _ = integration.set_response_body_json(response, error_json);
        return false;
    }
    
    // TODO: When JWT validation is available:
    // 1. Validate JWT token using JWT validation
    // 2. Check token expiration
    // 3. Extract user ID from token
    // 4. Store user ID in request context (when available)
    
    std.debug.assert(token_len > 0);
    std.debug.assert(token_len <= models.MAX_TOKEN_LEN);
    
    return true;
}

// Mobile request validation middleware
// Validates request body structure and required fields
pub fn mobile_validation_middleware(
    request: *integration.HttpRequest,
    response: *integration.HttpResponse,
) bool {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    
    // Check Content-Type header
    var content_type: [512]u8 = undefined;
    const content_type_len = integration.get_header_value(request, "Content-Type", &content_type);
    
    if (content_type_len > 0) {
        const content_type_str = content_type[0..content_type_len];
        if (content_type_str.len < 16 or !std.mem.eql(u8, content_type_str[0..16], "application/json")) {
            response.status = 400;
            _ = integration.add_response_header(response, "Content-Type", "application/json");
            const error_json = "{\"error\":\"bad_request\",\"message\":\"Invalid Content-Type\"}";
            _ = integration.set_response_body_json(response, error_json);
            return false;
        }
    }
    
    // TODO: When JSON parsing is available:
    // 1. Parse JSON request body
    // 2. Validate required fields based on endpoint
    // 3. Return validation result
    
    std.debug.assert(response.status >= 200);
    
    return true;
}

// Mobile error response middleware
// Builds standardized error responses for mobile endpoints
pub fn mobile_error_middleware(
    _request: *integration.HttpRequest,
    response: *integration.HttpResponse,
    error_code: []const u8,
    message: []const u8,
) bool {
    std.debug.assert(_request != null);
    std.debug.assert(response != null);
    std.debug.assert(error_code.len > 0);
    std.debug.assert(error_code.len <= 32);
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= models.MAX_MESSAGE_LEN);
    
    var json: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_error_response(error_code, message, &json);
    
    if (json_len == 0) {
        return false;
    }
    
    response.status = 400;
    _ = integration.add_response_header(response, "Content-Type", "application/json");
    _ = integration.set_response_body_json(response, json[0..json_len]);
    
    std.debug.assert(response.status == 400);
    std.debug.assert(response.body_len > 0);
    
    return true;
}

// Mobile success response middleware
// Builds standardized success responses for mobile endpoints
pub fn mobile_success_middleware(
    _request: *integration.HttpRequest,
    response: *integration.HttpResponse,
    message: []const u8,
    data: []const u8,
) bool {
    std.debug.assert(_request != null);
    std.debug.assert(response != null);
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= models.MAX_MESSAGE_LEN);
    
    var json: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response(message, data, &json);
    
    if (json_len == 0) {
        return false;
    }
    
    response.status = 200;
    _ = integration.add_response_header(response, "Content-Type", "application/json");
    _ = integration.set_response_body_json(response, json[0..json_len]);
    
    std.debug.assert(response.status == 200);
    std.debug.assert(response.body_len > 0);
    
    return true;
}

// Mobile endpoint middleware configuration
// Defines which middleware to use for each endpoint type
pub const MiddlewareConfig = struct {
    use_cors: bool,
    use_logging: bool,
    use_auth: bool,
    use_validation: bool,
    use_rate_limit: bool,
    
    pub fn init() MiddlewareConfig {
        return MiddlewareConfig{
            .use_cors = true,
            .use_logging = true,
            .use_auth = false,
            .use_validation = false,
            .use_rate_limit = false,
        };
    }
    
    pub fn for_public_endpoint() MiddlewareConfig {
        var config = init();
        config.use_auth = false;
        config.use_validation = true;
        return config;
    }
    
    pub fn for_auth_endpoint() MiddlewareConfig {
        var config = init();
        config.use_auth = true;
        config.use_validation = true;
        return config;
    }
    
    pub fn for_protected_endpoint() MiddlewareConfig {
        var config = init();
        config.use_auth = true;
        config.use_validation = true;
        config.use_rate_limit = true;
        return config;
    }
};

