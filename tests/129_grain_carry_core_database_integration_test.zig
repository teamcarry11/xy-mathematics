//! Tests for Grain Carry Core Database Integration.
//!
//! Why: Verify database integration functionality for Silo Agent REST API.
//! Architecture: Comprehensive test coverage for database integration module.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-175116-pst: Grain Carry Agent

const std = @import("std");
const testing = std.testing;
const grain_carry_core = @import("grain_carry_core");
const db_integration = grain_carry_core.api.database_integration;

test "database config initialization" {
    const config = db_integration.DatabaseConfig.init();
    try testing.expect(config.base_url_len == 0);
    try testing.expect(!config.enabled);
}

test "database config set base url" {
    var config = db_integration.DatabaseConfig.init();
    const base_url = "https://api.example.com";
    const success = config.set_base_url(base_url);
    try testing.expect(success);
    try testing.expect(config.base_url_len > 0);
    try testing.expect(std.mem.eql(u8, config.base_url[0..config.base_url_len], base_url));
}

test "database config set base url too long" {
    var config = db_integration.DatabaseConfig.init();
    var long_url: [600]u8 = undefined;
    var i: u32 = 0;
    while (i < 600) : (i += 1) {
        long_url[i] = 'a';
    }
    const success = config.set_base_url(&long_url);
    try testing.expect(!success);
}

test "database config set and get" {
    var config = db_integration.DatabaseConfig.init();
    const base_url = "https://api.example.com";
    _ = config.set_base_url(base_url);
    config.enabled = true;
    db_integration.set_database_config(config);
    const retrieved_config = db_integration.get_database_config();
    try testing.expect(retrieved_config.enabled);
    try testing.expect(retrieved_config.base_url_len > 0);
}

test "user data initialization" {
    const user = db_integration.UserData.init();
    try testing.expect(user.user_id_len == 0);
    try testing.expect(user.email_len == 0);
    try testing.expect(user.username_len == 0);
    try testing.expect(user.password_hash_len == 0);
    try testing.expect(user.created_at == 0);
}

test "create user disabled database" {
    var user = db_integration.UserData.init();
    user.user_id_len = 10;
    user.email_len = 10;
    const result = db_integration.create_user(&user);
    try testing.expect(result == db_integration.DatabaseResult.connection_error);
}

test "get user by id disabled database" {
    var user = db_integration.UserData.init();
    const user_id = "test_user_id";
    const result = db_integration.get_user_by_id(user_id, &user);
    try testing.expect(result == db_integration.DatabaseResult.connection_error);
}

test "get user by email disabled database" {
    var user = db_integration.UserData.init();
    const email = "test@example.com";
    const result = db_integration.get_user_by_email(email, &user);
    try testing.expect(result == db_integration.DatabaseResult.connection_error);
}

test "update user disabled database" {
    var user = db_integration.UserData.init();
    const user_id = "test_user_id";
    const result = db_integration.update_user(user_id, &user);
    try testing.expect(result == db_integration.DatabaseResult.connection_error);
}

test "parse user from json with all fields" {
    const json = "{\"user_id\":\"abc123\",\"email\":\"test@example.com\",\"username\":\"testuser\",\"created_at\":1234567890}";
    var user = db_integration.UserData.init();
    const result = db_integration.parse_user_from_json(json, &user);
    try testing.expect(result == db_integration.DatabaseResult.success);
    try testing.expect(user.user_id_len > 0);
    try testing.expect(user.email_len > 0);
    try testing.expect(user.username_len > 0);
    try testing.expect(user.created_at > 0);
    try testing.expect(std.mem.eql(u8, user.user_id[0..user.user_id_len], "abc123"));
    try testing.expect(std.mem.eql(u8, user.email[0..user.email_len], "test@example.com"));
    try testing.expect(std.mem.eql(u8, user.username[0..user.username_len], "testuser"));
}

test "parse user from json with minimal fields" {
    const json = "{\"user_id\":\"abc123\",\"email\":\"test@example.com\"}";
    var user = db_integration.UserData.init();
    const result = db_integration.parse_user_from_json(json, &user);
    try testing.expect(result == db_integration.DatabaseResult.success);
    try testing.expect(user.user_id_len > 0);
    try testing.expect(user.email_len > 0);
    try testing.expect(std.mem.eql(u8, user.user_id[0..user.user_id_len], "abc123"));
    try testing.expect(std.mem.eql(u8, user.email[0..user.email_len], "test@example.com"));
}

test "parse user from json missing required fields" {
    const json = "{\"user_id\":\"abc123\"}";
    var user = db_integration.UserData.init();
    const result = db_integration.parse_user_from_json(json, &user);
    try testing.expect(result == db_integration.DatabaseResult.validation_error);
}

test "parse user from json invalid json" {
    const json = "{invalid json}";
    var user = db_integration.UserData.init();
    const result = db_integration.parse_user_from_json(json, &user);
    try testing.expect(result == db_integration.DatabaseResult.validation_error);
}

test "parse user from json empty json" {
    const json = "{}";
    var user = db_integration.UserData.init();
    const result = db_integration.parse_user_from_json(json, &user);
    try testing.expect(result == db_integration.DatabaseResult.validation_error);
}

test "http status to db result success" {
    const grain_core_api = @import("grain_core").api_server;
    const status_ok = grain_core_api.HttpStatus.ok;
    const status_created = grain_core_api.HttpStatus.created;
    const result_ok = db_integration.http_status_to_db_result(status_ok);
    const result_created = db_integration.http_status_to_db_result(status_created);
    try testing.expect(result_ok == db_integration.DatabaseResult.success);
    try testing.expect(result_created == db_integration.DatabaseResult.success);
}

test "http status to db result not found" {
    const grain_core_api = @import("grain_core").api_server;
    const status = grain_core_api.HttpStatus.not_found;
    const result = db_integration.http_status_to_db_result(status);
    try testing.expect(result == db_integration.DatabaseResult.not_found);
}

test "http status to db result validation error" {
    const grain_core_api = @import("grain_core").api_server;
    const status = grain_core_api.HttpStatus.bad_request;
    const result = db_integration.http_status_to_db_result(status);
    try testing.expect(result == db_integration.DatabaseResult.validation_error);
}

test "process user response success" {
    const grain_core_api = @import("grain_core").api_server;
    var response = grain_core_api.HttpResponse.init();
    response.status = grain_core_api.HttpStatus.ok;
    const json_body = "{\"user_id\":\"test123\",\"email\":\"test@example.com\"}";
    const body_len = @min(json_body.len, grain_core_api.MAX_RESPONSE_SIZE);
    std.mem.copyForwards(u8, &response.body, json_body[0..body_len]);
    response.body_len = @intCast(body_len);
    var user = db_integration.UserData.init();
    const result = db_integration.process_user_response(&response, &user);
    try testing.expect(result == db_integration.DatabaseResult.success);
    try testing.expect(user.user_id_len > 0);
    try testing.expect(user.email_len > 0);
}

test "process user response not found" {
    const grain_core_api = @import("grain_core").api_server;
    var response = grain_core_api.HttpResponse.init();
    response.status = grain_core_api.HttpStatus.not_found;
    var user = db_integration.UserData.init();
    const result = db_integration.process_user_response(&response, &user);
    try testing.expect(result == db_integration.DatabaseResult.not_found);
}

test "process user response validation error" {
    const grain_core_api = @import("grain_core").api_server;
    var response = grain_core_api.HttpResponse.init();
    response.status = grain_core_api.HttpStatus.ok;
    response.body_len = 0;
    var user = db_integration.UserData.init();
    const result = db_integration.process_user_response(&response, &user);
    try testing.expect(result == db_integration.DatabaseResult.validation_error);
}

test "parse error response not found" {
    const json = "{\"error\":{\"code\":404,\"message\":\"Record not found\",\"details\":\"Record with ID 123 does not exist\"}}";
    const result = db_integration.parse_error_response(json);
    try testing.expect(result != null);
    try testing.expect(result.? == db_integration.DatabaseResult.not_found);
}

test "parse error response validation error" {
    const json = "{\"error\":{\"code\":400,\"message\":\"Bad request\",\"details\":\"Invalid request body\"}}";
    const result = db_integration.parse_error_response(json);
    try testing.expect(result != null);
    try testing.expect(result.? == db_integration.DatabaseResult.validation_error);
}

test "parse error response internal error" {
    const json = "{\"error\":{\"code\":500,\"message\":\"Internal server error\",\"details\":\"Database connection failed\"}}";
    const result = db_integration.parse_error_response(json);
    try testing.expect(result != null);
    try testing.expect(result.? == db_integration.DatabaseResult.internal_error);
}

test "parse error response invalid json" {
    const json = "{invalid json}";
    const result = db_integration.parse_error_response(json);
    try testing.expect(result == null);
}

test "process user response with error json" {
    const grain_core_api = @import("grain_core").api_server;
    var response = grain_core_api.HttpResponse.init();
    response.status = grain_core_api.HttpStatus.not_found;
    const error_json = "{\"error\":{\"code\":404,\"message\":\"Record not found\"}}";
    const body_len = @min(error_json.len, grain_core_api.MAX_RESPONSE_SIZE);
    std.mem.copyForwards(u8, &response.body, error_json[0..body_len]);
    response.body_len = @intCast(body_len);
    var user = db_integration.UserData.init();
    const result = db_integration.process_user_response(&response, &user);
    try testing.expect(result == db_integration.DatabaseResult.not_found);
}
