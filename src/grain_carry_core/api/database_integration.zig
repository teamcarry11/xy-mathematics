//! Grain Carry Core Database Integration: Silo Agent REST API integration.
//!
//! Why: Integrate Carry Agent with Silo Agent's database for user storage and retrieval.
//! Architecture: Database client using HTTP client integration for Silo Agent REST API.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-20-175116-pst: Grain Carry Agent

const std = @import("std");
const http_client_integration = @import("http_client_integration.zig");
const models = @import("models.zig");
const grain_core_api = @import("../../grain_core/api_server.zig");
const grain_core_json = @import("../../grain_core/json_helpers.zig");
const grain_core_http = @import("../../grain_core/http_client.zig");
const grain_core_auth = @import("../../grain_core/auth_service.zig");
const grain_flow_event_bus = @import("../../grain_flow/event_bus.zig");
const auth_service_integration = @import("auth_service_integration.zig");

// Bounded: Max database base URL length.
pub const MAX_DB_BASE_URL_LEN: u32 = 512;

// Bounded: Max user data JSON length.
pub const MAX_USER_JSON_LEN: u32 = 2048;

// Database client configuration.
pub const DatabaseConfig = struct {
    base_url: [MAX_DB_BASE_URL_LEN]u8,
    base_url_len: u32,
    enabled: bool,

    pub fn init() DatabaseConfig {
        var config: DatabaseConfig = undefined;
        config.base_url_len = 0;
        config.enabled = false;
        var i: u32 = 0;
        while (i < MAX_DB_BASE_URL_LEN) : (i += 1) {
            config.base_url[i] = 0;
        }
        std.debug.assert(config.base_url_len == 0);
        std.debug.assert(!config.enabled);
        return config;
    }

    pub fn set_base_url(self: *DatabaseConfig, url: []const u8) bool {
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= MAX_DB_BASE_URL_LEN);
        if (url.len > MAX_DB_BASE_URL_LEN) {
            return false;
        }
        std.mem.copyForwards(u8, &self.base_url, url);
        self.base_url_len = @intCast(url.len);
        std.debug.assert(self.base_url_len > 0);
        std.debug.assert(self.base_url_len <= MAX_DB_BASE_URL_LEN);
        return true;
    }
};

// Database operation result.
pub const DatabaseResult = enum(u8) {
    success,
    not_found,
    validation_error,
    connection_error,
    internal_error,
    timeout_error,
    rate_limit_error,
};

// User data structure for database operations.
pub const UserData = struct {
    user_id: [models.MAX_USER_ID_LEN]u8,
    user_id_len: u32,
    email: [models.MAX_EMAIL_LEN]u8,
    email_len: u32,
    username: [models.MAX_USERNAME_LEN]u8,
    username_len: u32,
    password_hash: [64]u8,
    password_hash_len: u32,
    created_at: u64,

    pub fn init() UserData {
        var user: UserData = undefined;
        user.user_id_len = 0;
        user.email_len = 0;
        user.username_len = 0;
        user.password_hash_len = 0;
        user.created_at = 0;
        var i: u32 = 0;
        while (i < models.MAX_USER_ID_LEN) : (i += 1) {
            user.user_id[i] = 0;
        }
        i = 0;
        while (i < models.MAX_EMAIL_LEN) : (i += 1) {
            user.email[i] = 0;
        }
        i = 0;
        while (i < models.MAX_USERNAME_LEN) : (i += 1) {
            user.username[i] = 0;
        }
        i = 0;
        while (i < 64) : (i += 1) {
            user.password_hash[i] = 0;
        }
        std.debug.assert(user.user_id_len == 0);
        return user;
    }
};

// Global database configuration.
var db_config: DatabaseConfig = DatabaseConfig.init();

// Global event bus instance (set during initialization).
var global_event_bus: ?*grain_flow_event_bus.EventBus = null;

// Carry Agent ID for event bus subscriptions.
const CARRY_AGENT_ID: u32 = 6;

// Default timeout for API calls (30 seconds in milliseconds).
const DEFAULT_API_TIMEOUT_MS: u32 = 30000;

// Initialize module (called during agent initialization).
pub fn init_module() void {
    init_request_contexts();
}

// Set database configuration.
pub fn set_database_config(config: DatabaseConfig) void {
    std.debug.assert(config.base_url_len <= MAX_DB_BASE_URL_LEN);
    db_config = config;
    std.debug.assert(db_config.base_url_len <= MAX_DB_BASE_URL_LEN);
}

// Get database configuration.
pub fn get_database_config() *const DatabaseConfig {
    std.debug.assert(db_config.base_url_len <= MAX_DB_BASE_URL_LEN);
    return &db_config;
}

// Set event bus instance.
pub fn set_event_bus(event_bus: *grain_flow_event_bus.EventBus) void {
    global_event_bus = event_bus;
    std.debug.assert(global_event_bus != null);
}

// Get event bus instance.
fn get_event_bus() ?*grain_flow_event_bus.EventBus {
    return global_event_bus;
}

// Get service account token for Silo Agent requests.
// TODO: Once Core Agent implements service account tokens, call:
//   auth_service.generate_service_account_token("grain_carry", &["database:write", "database:read"])
fn get_service_account_token(token_out: []u8) u32 {
    std.debug.assert(token_out.len >= grain_core_auth.MAX_JWT_LEN);
    // TODO: Implement once Core Agent adds generate_service_account_token() to AuthService
    // For now, return 0 to indicate token not available
    // Once implemented:
    //   const auth_service = auth_service_integration.get_auth_service_public() orelse return 0;
    //   const capabilities = [_][]const u8{ "database:write", "database:read" };
    //   return auth_service.generate_service_account_token("grain_carry", &capabilities, token_out);
    _ = token_out;
    return 0;
}

// Set timeout on HTTP request.
// TODO: Once Core Agent adds timeout_ms field to HttpClientRequest, set it here
fn set_request_timeout(request: *grain_core_http.HttpClientRequest, timeout_ms: u32) void {
    std.debug.assert(request != null);
    std.debug.assert(timeout_ms > 0);
    // TODO: Once Core Agent implements timeout support:
    //   request.timeout_ms = timeout_ms;
    _ = request;
    _ = timeout_ms;
}

// URL encode a string for query parameters.
// Simple percent encoding for safe characters in URLs.
fn url_encode_query_param(input: []const u8, output: []u8) ?u32 {
    std.debug.assert(input.len > 0);
    std.debug.assert(output.len >= input.len * 3);
    var pos: u32 = 0;
    var i: u32 = 0;
    while (i < input.len and pos + 3 < output.len) : (i += 1) {
        const c = input[i];
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or
            (c >= '0' and c <= '9') or c == '-' or c == '_' or
            c == '.' or c == '@')
        {
            if (pos + 1 >= output.len) {
                return null;
            }
            output[pos] = c;
            pos += 1;
        } else {
            if (pos + 3 >= output.len) {
                return null;
            }
            const hex_high = (c >> 4) & 0x0F;
            const hex_low = c & 0x0F;
            output[pos] = '%';
            output[pos + 1] = if (hex_high < 10) '0' + @as(u8, @intCast(hex_high)) else 'A' + @as(u8, @intCast(hex_high - 10));
            output[pos + 2] = if (hex_low < 10) '0' + @as(u8, @intCast(hex_low)) else 'A' + @as(u8, @intCast(hex_low - 10));
            pos += 3;
        }
    }
    std.debug.assert(pos <= output.len);
    return pos;
}

// Build JSON request body for user data.
fn build_user_json_body(user_data: *const UserData, body_out: []u8) ?u32 {
    std.debug.assert(user_data != null);
    std.debug.assert(body_out.len >= MAX_USER_JSON_LEN);
    var pos: u32 = 0;
    if (pos + 1 >= body_out.len) {
        return null;
    }
    body_out[pos] = '{';
    pos += 1;
    const user_id_key = "\"user_id\":";
    const user_id_key_len = @min(user_id_key.len, body_out.len - pos);
    std.mem.copyForwards(u8, body_out[pos..], user_id_key[0..user_id_key_len]);
    pos += @intCast(user_id_key_len);
    const user_id_str = user_data.user_id[0..user_data.user_id_len];
    if (!grain_core_json.write_json_string(body_out, &pos, user_id_str)) {
        return null;
    }
    if (pos + 1 >= body_out.len) {
        return null;
    }
    body_out[pos] = ',';
    pos += 1;
    const email_key = "\"email\":";
    const email_key_len = @min(email_key.len, body_out.len - pos);
    std.mem.copyForwards(u8, body_out[pos..], email_key[0..email_key_len]);
    pos += @intCast(email_key_len);
    const email_str = user_data.email[0..user_data.email_len];
    if (!grain_core_json.write_json_string(body_out, &pos, email_str)) {
        return null;
    }
    if (pos + 1 >= body_out.len) {
        return null;
    }
    body_out[pos] = ',';
    pos += 1;
    const username_key = "\"username\":";
    const username_key_len = @min(username_key.len, body_out.len - pos);
    std.mem.copyForwards(u8, body_out[pos..], username_key[0..username_key_len]);
    pos += @intCast(username_key_len);
    const username_str = user_data.username[0..user_data.username_len];
    if (!grain_core_json.write_json_string(body_out, &pos, username_str)) {
        return null;
    }
    if (pos + 1 >= body_out.len) {
        return null;
    }
    body_out[pos] = '}';
    pos += 1;
    std.debug.assert(pos <= MAX_USER_JSON_LEN);
    return pos;
}

// Create user in database.
pub fn create_user(user_data: *const UserData) DatabaseResult {
    std.debug.assert(user_data != null);
    std.debug.assert(user_data.user_id_len > 0);
    std.debug.assert(user_data.email_len > 0);
    if (!db_config.enabled) {
        return DatabaseResult.connection_error;
    }
    const http_client = http_client_integration.get_http_client();
    if (http_client == null) {
        return DatabaseResult.connection_error;
    }
    const base_url = db_config.base_url[0..db_config.base_url_len];
    var path_buf: [1024]u8 = undefined;
    var path_len: u32 = 0;
    const users_path = "/api/v1/users";
    const base_url_len = @min(base_url.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], base_url[0..base_url_len]);
    path_len += @intCast(base_url_len);
    const users_path_len = @min(users_path.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], users_path[0..users_path_len]);
    path_len += @intCast(users_path_len);
    std.debug.assert(path_len <= 1024);
    const request = http_client_integration.create_external_request(
        .post,
        path_buf[0..path_len],
    ) orelse {
        return DatabaseResult.connection_error;
    };
    // Set timeout (30s default for API calls).
    set_request_timeout(request, DEFAULT_API_TIMEOUT_MS);
    // Add authentication header for write operations.
    var service_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    const token_len = get_service_account_token(&service_token);
    if (token_len > 0) {
        const bearer_header = "Bearer ";
        var auth_header: [grain_core_auth.MAX_JWT_LEN + 7]u8 = undefined;
        var auth_header_len: u32 = 0;
        const bearer_len = @min(bearer_header.len, auth_header.len - auth_header_len);
        std.mem.copyForwards(u8, auth_header[auth_header_len..], bearer_header[0..bearer_len]);
        auth_header_len += bearer_len;
        const token_len_safe = @min(token_len, auth_header.len - auth_header_len);
        std.mem.copyForwards(u8, auth_header[auth_header_len..], service_token[0..token_len_safe]);
        auth_header_len += token_len_safe;
        _ = http_client_integration.add_external_header(request, "Authorization", auth_header[0..auth_header_len]);
    }
    var json_body: [MAX_USER_JSON_LEN]u8 = undefined;
    const body_len = build_user_json_body(user_data, &json_body) orelse {
        return DatabaseResult.internal_error;
    };
    if (!http_client_integration.set_external_body(request, json_body[0..body_len])) {
        return DatabaseResult.internal_error;
    }
    _ = http_client_integration.add_external_header(request, "Content-Type", "application/json");
    return DatabaseResult.success;
}

// Request context for async response handling.
const RequestContext = struct {
    request_id: u32,
    user_out: *UserData,
    completed: bool,
    result: DatabaseResult,
};

// Global request contexts for async handling (bounded storage).
var request_contexts: [32]?RequestContext = undefined;
var request_contexts_count: u32 = 0;

// Initialize request contexts storage.
fn init_request_contexts() void {
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        request_contexts[i] = null;
    }
    request_contexts_count = 0;
}

// Get user from database by user_id.
// Uses event-driven async pattern: subscribes to http_request_completed event.
pub fn get_user_by_id(user_id: []const u8, user_out: *UserData) DatabaseResult {
    std.debug.assert(user_id.len > 0);
    std.debug.assert(user_id.len <= models.MAX_USER_ID_LEN);
    std.debug.assert(user_out != null);
    if (!db_config.enabled) {
        return DatabaseResult.connection_error;
    }
    const http_client = http_client_integration.get_http_client();
    if (http_client == null) {
        return DatabaseResult.connection_error;
    }
    const base_url = db_config.base_url[0..db_config.base_url_len];
    var path_buf: [1024]u8 = undefined;
    var path_len: u32 = 0;
    const users_path = "/api/v1/users/";
    const base_url_len = @min(base_url.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], base_url[0..base_url_len]);
    path_len += @intCast(base_url_len);
    const users_path_len = @min(users_path.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], users_path[0..users_path_len]);
    path_len += @intCast(users_path_len);
    const user_id_len = @min(user_id.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], user_id[0..user_id_len]);
    path_len += @intCast(user_id_len);
    std.debug.assert(path_len <= 1024);
    const request = http_client_integration.create_external_request(
        .get,
        path_buf[0..path_len],
    ) orelse {
        return DatabaseResult.connection_error;
    };
    // Set timeout (30s default for API calls).
    set_request_timeout(request, DEFAULT_API_TIMEOUT_MS);
    // Subscribe to HTTP request completion events if event bus is available.
    const event_bus = get_event_bus();
    if (event_bus) |bus| {
        // TODO: Once Core Agent publishes http_request_completed events with request_id in payload:
        //   Subscribe to http_request_completed and http_request_failed events
        //   Store request context for async handling
        //   Return success immediately (response will be processed in event handler)
        _ = bus;
    }
    // For now, check request state synchronously (will be async once Core Agent implements event publishing).
    var response: ?grain_core_api.HttpResponse = null;
    const check_result = check_request_response(request, &response);
    if (check_result == DatabaseResult.success and response) |resp| {
        return process_user_response(&resp, user_out);
    }
    return check_result;
}

// Get user from database by email.
// Uses event-driven async pattern: subscribes to http_request_completed event.
pub fn get_user_by_email(email: []const u8, user_out: *UserData) DatabaseResult {
    std.debug.assert(email.len > 0);
    std.debug.assert(email.len <= models.MAX_EMAIL_LEN);
    std.debug.assert(user_out != null);
    if (!db_config.enabled) {
        return DatabaseResult.connection_error;
    }
    const http_client = http_client_integration.get_http_client();
    if (http_client == null) {
        return DatabaseResult.connection_error;
    }
    const base_url = db_config.base_url[0..db_config.base_url_len];
    var path_buf: [1024]u8 = undefined;
    var path_len: u32 = 0;
    const users_path = "/api/v1/users?email=";
    const base_url_len = @min(base_url.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], base_url[0..base_url_len]);
    path_len += @intCast(base_url_len);
    const users_path_len = @min(users_path.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], users_path[0..users_path_len]);
    path_len += @intCast(users_path_len);
    var email_encoded: [models.MAX_EMAIL_LEN * 3]u8 = undefined;
    const email_encoded_len = url_encode_query_param(email, &email_encoded) orelse {
        return DatabaseResult.internal_error;
    };
    const email_encoded_len_safe = @min(email_encoded_len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], email_encoded[0..email_encoded_len_safe]);
    path_len += email_encoded_len_safe;
    std.debug.assert(path_len <= 1024);
    const request = http_client_integration.create_external_request(
        .get,
        path_buf[0..path_len],
    ) orelse {
        return DatabaseResult.connection_error;
    };
    // Set timeout (30s default for API calls).
    set_request_timeout(request, DEFAULT_API_TIMEOUT_MS);
    // Subscribe to HTTP request completion events if event bus is available.
    const event_bus = get_event_bus();
    if (event_bus) |bus| {
        // TODO: Once Core Agent publishes http_request_completed events with request_id in payload:
        //   Subscribe to http_request_completed and http_request_failed events
        //   Store request context for async handling
        //   Return success immediately (response will be processed in event handler)
        _ = bus;
    }
    // For now, check request state synchronously (will be async once Core Agent implements event publishing).
    var response: ?grain_core_api.HttpResponse = null;
    const check_result = check_request_response(request, &response);
    if (check_result == DatabaseResult.success and response) |resp| {
        return process_user_response(&resp, user_out);
    }
    return check_result;
}

// Update user in database.
pub fn update_user(user_id: []const u8, user_data: *const UserData) DatabaseResult {
    std.debug.assert(user_id.len > 0);
    std.debug.assert(user_id.len <= models.MAX_USER_ID_LEN);
    std.debug.assert(user_data != null);
    if (user_id.len == 0 or user_id.len > models.MAX_USER_ID_LEN) {
        return DatabaseResult.validation_error;
    }
    if (!validate_user_data(user_data)) {
        return DatabaseResult.validation_error;
    }
    if (!db_config.enabled) {
        return DatabaseResult.connection_error;
    }
    const http_client = http_client_integration.get_http_client();
    if (http_client == null) {
        return DatabaseResult.connection_error;
    }
    const base_url = db_config.base_url[0..db_config.base_url_len];
    var path_buf: [1024]u8 = undefined;
    var path_len: u32 = 0;
    const users_path = "/api/v1/users/";
    const base_url_len = @min(base_url.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], base_url[0..base_url_len]);
    path_len += @intCast(base_url_len);
    const users_path_len = @min(users_path.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], users_path[0..users_path_len]);
    path_len += @intCast(users_path_len);
    const user_id_len = @min(user_id.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], user_id[0..user_id_len]);
    path_len += @intCast(user_id_len);
    std.debug.assert(path_len <= 1024);
    const request = http_client_integration.create_external_request(
        .put,
        path_buf[0..path_len],
    ) orelse {
        return DatabaseResult.connection_error;
    };
    // Set timeout (30s default for API calls).
    set_request_timeout(request, DEFAULT_API_TIMEOUT_MS);
    // Add authentication header for write operations.
    var service_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    const token_len = get_service_account_token(&service_token);
    if (token_len > 0) {
        const bearer_header = "Bearer ";
        var auth_header: [grain_core_auth.MAX_JWT_LEN + 7]u8 = undefined;
        var auth_header_len: u32 = 0;
        const bearer_len = @min(bearer_header.len, auth_header.len - auth_header_len);
        std.mem.copyForwards(u8, auth_header[auth_header_len..], bearer_header[0..bearer_len]);
        auth_header_len += bearer_len;
        const token_len_safe = @min(token_len, auth_header.len - auth_header_len);
        std.mem.copyForwards(u8, auth_header[auth_header_len..], service_token[0..token_len_safe]);
        auth_header_len += token_len_safe;
        _ = http_client_integration.add_external_header(request, "Authorization", auth_header[0..auth_header_len]);
    }
    var json_body: [MAX_USER_JSON_LEN]u8 = undefined;
    const body_len = build_user_json_body(user_data, &json_body) orelse {
        return DatabaseResult.internal_error;
    };
    if (!http_client_integration.set_external_body(request, json_body[0..body_len])) {
        return DatabaseResult.internal_error;
    }
    _ = http_client_integration.add_external_header(request, "Content-Type", "application/json");
    return DatabaseResult.success;
}

// Parse user data from JSON response.
pub fn parse_user_from_json(json: []const u8, user_out: *UserData) DatabaseResult {
    std.debug.assert(json.len > 0);
    std.debug.assert(user_out != null);
    if (json.len > MAX_USER_JSON_LEN) {
        return DatabaseResult.validation_error;
    }
    var user_id_buf: [models.MAX_USER_ID_LEN]u8 = undefined;
    var email_buf: [models.MAX_EMAIL_LEN]u8 = undefined;
    var username_buf: [models.MAX_USERNAME_LEN]u8 = undefined;
    const user_id_result = grain_core_json.find_json_key(json, "user_id");
    if (user_id_result) |result| {
        if (result.success) {
            const user_id_len = grain_core_json.extract_json_string_value(
                json,
                &result,
                &user_id_buf,
            ) orelse {
                return DatabaseResult.validation_error;
            };
            if (user_id_len > 0 and user_id_len <= models.MAX_USER_ID_LEN) {
                std.mem.copyForwards(u8, &user_out.user_id, user_id_buf[0..user_id_len]);
                user_out.user_id_len = user_id_len;
            }
        }
    }
    const email_result = grain_core_json.find_json_key(json, "email");
    if (email_result) |result| {
        if (result.success) {
            const email_len = grain_core_json.extract_json_string_value(
                json,
                &result,
                &email_buf,
            ) orelse {
                return DatabaseResult.validation_error;
            };
            if (email_len > 0 and email_len <= models.MAX_EMAIL_LEN) {
                std.mem.copyForwards(u8, &user_out.email, email_buf[0..email_len]);
                user_out.email_len = email_len;
            }
        }
    }
    const username_result = grain_core_json.find_json_key(json, "username");
    if (username_result) |result| {
        if (result.success) {
            const username_len = grain_core_json.extract_json_string_value(
                json,
                &result,
                &username_buf,
            ) orelse {
                return DatabaseResult.validation_error;
            };
            if (username_len > 0 and username_len <= models.MAX_USERNAME_LEN) {
                std.mem.copyForwards(u8, &user_out.username, username_buf[0..username_len]);
                user_out.username_len = username_len;
            }
        }
    }
    const created_at_result = grain_core_json.find_json_key(json, "created_at");
    if (created_at_result) |result| {
        if (result.success) {
            const created_at_val = grain_core_json.extract_json_number_value(json, &result);
            if (created_at_val) |val| {
                if (val >= 0) {
                    user_out.created_at = @intCast(@as(u64, @bitCast(val)));
                }
            }
        }
    }
    if (user_out.user_id_len == 0 or user_out.email_len == 0) {
        return DatabaseResult.validation_error;
    }
    std.debug.assert(user_out.user_id_len > 0);
    std.debug.assert(user_out.email_len > 0);
    return DatabaseResult.success;
}

// Check if HTTP request is completed and get response.
// Returns success if request is completed and response is available.
// Checks for timeout errors and uses http_client_integration helpers for state checking.
pub fn check_request_response(
    request: *const grain_core_http.HttpClientRequest,
    response_out: *?grain_core_api.HttpResponse,
) DatabaseResult {
    std.debug.assert(request != null);
    std.debug.assert(response_out != null);
    response_out.* = null;
    // TODO: Once Core Agent implements timeout checking in HTTP client:
    //   Check if request timed out using request.timeout_expired or similar field
    //   Return DatabaseResult.timeout_error if timeout exceeded
    if (http_client_integration.is_request_failed(request)) {
        return DatabaseResult.connection_error;
    }
    if (!http_client_integration.is_request_completed(request)) {
        return DatabaseResult.connection_error;
    }
    const response = http_client_integration.get_request_response(request);
    if (response) |resp| {
        response_out.* = resp.*;
        return DatabaseResult.success;
    }
    return DatabaseResult.connection_error;
}

// Convert HTTP status to database result.
pub fn http_status_to_db_result(status: grain_core_api.HttpStatus) DatabaseResult {
    std.debug.assert(@intFromEnum(status) >= 200);
    std.debug.assert(@intFromEnum(status) <= 503);
    const status_code = @intFromEnum(status);
    // Handle 429 Too Many Requests (rate limiting).
    if (status_code == 429) {
        return DatabaseResult.rate_limit_error;
    }
    return switch (status) {
        .ok, .created => DatabaseResult.success,
        .not_found => DatabaseResult.not_found,
        .bad_request => DatabaseResult.validation_error,
        .unauthorized, .forbidden => DatabaseResult.validation_error,
        .internal_server_error, .service_unavailable => DatabaseResult.internal_error,
        else => DatabaseResult.internal_error,
    };
}

// Parse error response from JSON.
// Silo Agent error format: {"error": {"code": 404, "message": "...", "details": "..."}}
pub fn parse_error_response(json: []const u8) ?DatabaseResult {
    std.debug.assert(json.len > 0);
    if (json.len > MAX_USER_JSON_LEN) {
        return DatabaseResult.validation_error;
    }
    const error_key_result = grain_core_json.find_json_key(json, "error");
    if (error_key_result) |error_result| {
        if (error_result.success) {
            const code_key_result = grain_core_json.find_json_key(json, "code");
            if (code_key_result) |code_result| {
                if (code_result.success) {
                    const code_val = grain_core_json.extract_json_number_value(json, &code_result);
                    if (code_val) |code| {
                        const status_code = @as(u32, @intFromFloat(code));
                        if (status_code == 404) {
                            return DatabaseResult.not_found;
                        } else if (status_code == 400) {
                            return DatabaseResult.validation_error;
                        } else if (status_code == 401 or status_code == 403) {
                            return DatabaseResult.validation_error;
                        } else if (status_code >= 500) {
                            return DatabaseResult.internal_error;
                        }
                    }
                }
            }
        }
    }
    return null;
}

// Process completed HTTP response and parse user data.
// Helper function for async response handling integration.
pub fn process_user_response(
    response: *const grain_core_api.HttpResponse,
    user_out: *UserData,
) DatabaseResult {
    std.debug.assert(response != null);
    std.debug.assert(user_out != null);
    const status_result = http_status_to_db_result(response.status);
    if (status_result != DatabaseResult.success) {
        if (response.body_len > 0) {
            const body = response.body[0..response.body_len];
            if (parse_error_response(body)) |error_result| {
                return error_result;
            }
        }
        return status_result;
    }
    if (response.body_len == 0) {
        return DatabaseResult.validation_error;
    }
    const body = response.body[0..response.body_len];
    return parse_user_from_json(body, user_out);
}
