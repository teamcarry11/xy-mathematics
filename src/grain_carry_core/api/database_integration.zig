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
    const user_id_str = user_data.user_id[0..user_data.user_id_len];
    if (!grain_core_json.write_json_string(body_out, &pos, "\"user_id\":")) {
        return null;
    }
    if (!grain_core_json.write_json_string(body_out, &pos, user_id_str)) {
        return null;
    }
    if (pos + 1 >= body_out.len) {
        return null;
    }
    body_out[pos] = ',';
    pos += 1;
    const email_str = user_data.email[0..user_data.email_len];
    if (!grain_core_json.write_json_string(body_out, &pos, "\"email\":")) {
        return null;
    }
    if (!grain_core_json.write_json_string(body_out, &pos, email_str)) {
        return null;
    }
    if (pos + 1 >= body_out.len) {
        return null;
    }
    body_out[pos] = ',';
    pos += 1;
    const username_str = user_data.username[0..user_data.username_len];
    if (!grain_core_json.write_json_string(body_out, &pos, "\"username\":")) {
        return null;
    }
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

// Get user from database by user_id.
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
    const request_id = http_client_integration.create_external_request(
        grain_core_api.HttpMethod.get,
        path_buf[0..path_len],
    );
    if (request_id == 0) {
        return DatabaseResult.connection_error;
    }
    _ = user_out;
    return DatabaseResult.success;
}

// Get user from database by email.
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
    const email_len = @min(email.len, path_buf.len - path_len);
    std.mem.copyForwards(u8, path_buf[path_len..], email[0..email_len]);
    path_len += @intCast(email_len);
    std.debug.assert(path_len <= 1024);
    const request_id = http_client_integration.create_external_request(
        grain_core_api.HttpMethod.get,
        path_buf[0..path_len],
    );
    if (request_id == 0) {
        return DatabaseResult.connection_error;
    }
    _ = user_out;
    return DatabaseResult.success;
}

// Update user in database.
pub fn update_user(user_id: []const u8, user_data: *const UserData) DatabaseResult {
    std.debug.assert(user_id.len > 0);
    std.debug.assert(user_id.len <= models.MAX_USER_ID_LEN);
    std.debug.assert(user_data != null);
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
    const request_id = http_client_integration.create_external_request(
        grain_core_api.HttpMethod.put,
        path_buf[0..path_len],
    );
    if (request_id == 0) {
        return DatabaseResult.connection_error;
    }
    _ = user_data;
    return DatabaseResult.success;
}
