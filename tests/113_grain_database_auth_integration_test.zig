//! Tests for Grain Database Authentication Integration.
//!
//! Why: Verify AuthService integration for database authentication.
//! Architecture: Comprehensive test coverage for auth integration module.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-013750-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const grain_core = @import("grain_core");
const auth_integration = grain_database.auth_integration;
const set_auth_service = auth_integration.set_auth_service;
const get_auth_service = auth_integration.get_auth_service;
const database_auth_middleware_enhanced = auth_integration.database_auth_middleware_enhanced;
const validate_session = auth_integration.validate_session;
const get_user_id_from_request = auth_integration.get_user_id_from_request;
const AuthService = grain_core.auth_service.AuthService;
const HttpRequest = grain_core.api_server.HttpRequest;
const HttpResponse = grain_core.api_server.HttpResponse;
const HttpStatus = grain_core.api_server.HttpStatus;

test "auth service set and get" {
    var auth_service = AuthService.init("test_secret_key_123");
    set_auth_service(&auth_service);
    const retrieved_service = get_auth_service();
    try testing.expect(retrieved_service != null);
    try testing.expect(retrieved_service.? == &auth_service);
}

test "enhanced auth middleware with valid token" {
    var auth_service = AuthService.init("test_secret_key_123");
    set_auth_service(&auth_service);
    const user_id = "test_user_123";
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    var token_buf: [grain_core.auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = auth_service.generate_access_token(
        user_id,
        current_time,
        &token_buf,
    );
    try testing.expect(token_len > 0);
    var request = HttpRequest.init();
    const auth_header = try std.fmt.allocPrint(
        testing.allocator,
        "Bearer {s}",
        .{token_buf[0..token_len]},
    );
    defer testing.allocator.free(auth_header);
    _ = request.add_header("Authorization", auth_header);
    var response = HttpResponse.init();
    const is_valid = database_auth_middleware_enhanced(&request, &response);
    try testing.expect(is_valid);
    try testing.expect(response.status == HttpStatus.ok);
}

test "enhanced auth middleware with missing token" {
    var auth_service = AuthService.init("test_secret_key_123");
    set_auth_service(&auth_service);
    var request = HttpRequest.init();
    var response = HttpResponse.init();
    const is_valid = database_auth_middleware_enhanced(&request, &response);
    try testing.expect(!is_valid);
    try testing.expect(response.status == HttpStatus.unauthorized);
}

test "enhanced auth middleware with invalid token" {
    var auth_service = AuthService.init("test_secret_key_123");
    set_auth_service(&auth_service);
    var request = HttpRequest.init();
    _ = request.add_header("Authorization", "Bearer invalid_token_123");
    var response = HttpResponse.init();
    const is_valid = database_auth_middleware_enhanced(&request, &response);
    try testing.expect(!is_valid);
    try testing.expect(response.status == HttpStatus.unauthorized);
}

test "validate session with valid session" {
    var auth_service = AuthService.init("test_secret_key_123");
    set_auth_service(&auth_service);
    const user_id = "test_user_123";
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    var session: grain_core.auth_service.Session = undefined;
    const created = auth_service.create_session(user_id, current_time, &session);
    try testing.expect(created);
    var request = HttpRequest.init();
    const session_id = session.session_id[0..session.session_id_len];
    var session_header_buf: [grain_core.auth_service.MAX_SESSION_ID_LEN]u8 = undefined;
    std.mem.copyForwards(u8, &session_header_buf, session_id);
    _ = request.add_header("X-Session-ID", session_header_buf[0..session.session_id_len]);
    var session_id_out: [grain_core.auth_service.MAX_SESSION_ID_LEN]u8 = undefined;
    const is_valid = validate_session(&request, &session_id_out);
    try testing.expect(is_valid);
}

test "validate session with missing session" {
    var auth_service = AuthService.init("test_secret_key_123");
    set_auth_service(&auth_service);
    var request = HttpRequest.init();
    var session_id_out: [grain_core.auth_service.MAX_SESSION_ID_LEN]u8 = undefined;
    const is_valid = validate_session(&request, &session_id_out);
    try testing.expect(!is_valid);
}

test "get user id from request with valid token" {
    var auth_service = AuthService.init("test_secret_key_123");
    set_auth_service(&auth_service);
    const user_id = "test_user_123";
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    var token_buf: [grain_core.auth_service.MAX_JWT_LEN]u8 = undefined;
    const token_len = auth_service.generate_access_token(
        user_id,
        current_time,
        &token_buf,
    );
    try testing.expect(token_len > 0);
    var request = HttpRequest.init();
    const auth_header = try std.fmt.allocPrint(
        testing.allocator,
        "Bearer {s}",
        .{token_buf[0..token_len]},
    );
    defer testing.allocator.free(auth_header);
    _ = request.add_header("Authorization", auth_header);
    var user_id_out: [grain_core.auth_service.MAX_USER_ID_LEN]u8 = undefined;
    const user_id_len = get_user_id_from_request(&request, &user_id_out);
    try testing.expect(user_id_len > 0);
    try testing.expect(std.mem.eql(u8, user_id_out[0..user_id_len], user_id));
}

test "get user id from request with missing token" {
    var auth_service = AuthService.init("test_secret_key_123");
    set_auth_service(&auth_service);
    var request = HttpRequest.init();
    var user_id_out: [grain_core.auth_service.MAX_USER_ID_LEN]u8 = undefined;
    const user_id_len = get_user_id_from_request(&request, &user_id_out);
    try testing.expect(user_id_len == 0);
}

