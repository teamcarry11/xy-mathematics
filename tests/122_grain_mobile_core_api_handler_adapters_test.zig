//! Tests for Grain Mobile Core Handler Adapters.
//!
//! Why: Verify handler adapters work correctly with Grain OS API Server.
//! Architecture: Comprehensive test coverage for handler adapters.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-05-122910-pst: Grain Mobile Agent

const std = @import("std");
const testing = std.testing;
const grain_mobile = @import("grain_carry_core");
const grain_core = @import("grain_core");
const handler_adapters = grain_mobile.api.handler_adapters;
const os_integration = grain_mobile.api.os_integration;
const handlers = grain_mobile.api.handlers;
const endpoints = grain_mobile.api.endpoints;

test "handler adapter register endpoint" {
    const allocator = testing.allocator;
    var api_server = grain_core.api_server.ApiServer.init(8080);
    var conn_mgr = grain_core.connection_manager.ConnectionManager.init();
    var handler_context = handlers.HandlerContext.init();
    handler_adapters.set_handler_context(&handler_context);
    handler_adapters.set_api_server(&api_server);
    _ = api_server.register_route(
        grain_core.api_server.HttpMethod.post,
        endpoints.AUTH_REGISTER_PATH,
        handler_adapters.handle_register_adapter,
    );
    const raw_request = "POST /api/v1/auth/register HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 60\r\n" ++
        "\r\n" ++
        "{\"email\":\"test@example.com\",\"password\":\"password123456789012345678901234\",\"username\":\"testuser\"}";
    const response_opt = grain_core.api_server_network.process_http_request(
        &api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    try testing.expect(response_opt != null);
    const response = response_opt.?;
    try testing.expect(response.status == grain_core.api_server.HttpStatus.ok);
    try testing.expect(response.body_len > 0);
}

test "handler adapter login endpoint" {
    const allocator = testing.allocator;
    var api_server = grain_core.api_server.ApiServer.init(8080);
    var conn_mgr = grain_core.connection_manager.ConnectionManager.init();
    var handler_context = handlers.HandlerContext.init();
    handler_adapters.set_handler_context(&handler_context);
    handler_adapters.set_api_server(&api_server);
    _ = api_server.register_route(
        grain_core.api_server.HttpMethod.post,
        endpoints.AUTH_LOGIN_PATH,
        handler_adapters.handle_login_adapter,
    );
    const raw_request = "POST /api/v1/auth/login HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 60\r\n" ++
        "\r\n" ++
        "{\"email\":\"test@example.com\",\"password\":\"password123456789012345678901234\"}";
    const response_opt = grain_core.api_server_network.process_http_request(
        &api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    try testing.expect(response_opt != null);
    const response = response_opt.?;
    try testing.expect(response.status == grain_core.api_server.HttpStatus.ok);
    try testing.expect(response.body_len > 0);
}

test "handler adapter logout endpoint" {
    const allocator = testing.allocator;
    var api_server = grain_core.api_server.ApiServer.init(8080);
    var conn_mgr = grain_core.connection_manager.ConnectionManager.init();
    var handler_context = handlers.HandlerContext.init();
    handler_adapters.set_handler_context(&handler_context);
    handler_adapters.set_api_server(&api_server);
    _ = api_server.register_route(
        grain_core.api_server.HttpMethod.post,
        endpoints.AUTH_LOGOUT_PATH,
        handler_adapters.handle_logout_adapter,
    );
    const raw_request = "POST /api/v1/auth/logout HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 2\r\n" ++
        "\r\n" ++
        "{}";
    const response_opt = grain_core.api_server_network.process_http_request(
        &api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    try testing.expect(response_opt != null);
    const response = response_opt.?;
    try testing.expect(response.status == grain_core.api_server.HttpStatus.ok);
    try testing.expect(response.body_len > 0);
}

test "handler adapter otp send endpoint" {
    const allocator = testing.allocator;
    var api_server = grain_core.api_server.ApiServer.init(8080);
    var conn_mgr = grain_core.connection_manager.ConnectionManager.init();
    var handler_context = handlers.HandlerContext.init();
    handler_adapters.set_handler_context(&handler_context);
    handler_adapters.set_api_server(&api_server);
    _ = api_server.register_route(
        grain_core.api_server.HttpMethod.post,
        endpoints.AUTH_OTP_SEND_PATH,
        handler_adapters.handle_otp_send_adapter,
    );
    const raw_request = "POST /api/v1/auth/otp/send HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 25\r\n" ++
        "\r\n" ++
        "{\"email\":\"test@example.com\"}";
    const response_opt = grain_core.api_server_network.process_http_request(
        &api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    try testing.expect(response_opt != null);
    const response = response_opt.?;
    try testing.expect(response.status == grain_core.api_server.HttpStatus.ok);
    try testing.expect(response.body_len > 0);
}

test "handler adapter otp verify endpoint" {
    const allocator = testing.allocator;
    var api_server = grain_core.api_server.ApiServer.init(8080);
    var conn_mgr = grain_core.connection_manager.ConnectionManager.init();
    var handler_context = handlers.HandlerContext.init();
    handler_adapters.set_handler_context(&handler_context);
    handler_adapters.set_api_server(&api_server);
    _ = api_server.register_route(
        grain_core.api_server.HttpMethod.post,
        endpoints.AUTH_OTP_VERIFY_PATH,
        handler_adapters.handle_otp_verify_adapter,
    );
    const raw_request = "POST /api/v1/auth/otp/verify HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 40\r\n" ++
        "\r\n" ++
        "{\"email\":\"test@example.com\",\"code\":\"123456\"}";
    const response_opt = grain_core.api_server_network.process_http_request(
        &api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    try testing.expect(response_opt != null);
    const response = response_opt.?;
    try testing.expect(response.status == grain_core.api_server.HttpStatus.ok);
    try testing.expect(response.body_len > 0);
}

test "handler adapter users profile endpoint" {
    const allocator = testing.allocator;
    var api_server = grain_core.api_server.ApiServer.init(8080);
    var conn_mgr = grain_core.connection_manager.ConnectionManager.init();
    var handler_context = handlers.HandlerContext.init();
    handler_adapters.set_handler_context(&handler_context);
    handler_adapters.set_api_server(&api_server);
    _ = api_server.register_route(
        grain_core.api_server.HttpMethod.get,
        endpoints.USERS_PROFILE_PATH,
        handler_adapters.handle_users_profile_adapter,
    );
    const raw_request = "GET /api/v1/users/profile HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "\r\n";
    const response_opt = grain_core.api_server_network.process_http_request(
        &api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    try testing.expect(response_opt != null);
    const response = response_opt.?;
    try testing.expect(response.status == grain_core.api_server.HttpStatus.ok);
    try testing.expect(response.body_len > 0);
}

test "handler adapter bad request handling" {
    const allocator = testing.allocator;
    var api_server = grain_core.api_server.ApiServer.init(8080);
    var conn_mgr = grain_core.connection_manager.ConnectionManager.init();
    var handler_context = handlers.HandlerContext.init();
    handler_adapters.set_handler_context(&handler_context);
    handler_adapters.set_api_server(&api_server);
    _ = api_server.register_route(
        grain_core.api_server.HttpMethod.post,
        endpoints.AUTH_REGISTER_PATH,
        handler_adapters.handle_register_adapter,
    );
    const raw_request = "POST /api/v1/auth/register HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 10\r\n" ++
        "\r\n" ++
        "{\"invalid\"}";
    const response_opt = grain_core.api_server_network.process_http_request(
        &api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    try testing.expect(response_opt != null);
    const response = response_opt.?;
    try testing.expect(response.status == grain_core.api_server.HttpStatus.bad_request);
}

test "os integration register all endpoints" {
    const allocator = testing.allocator;
    var compositor = grain_core.compositor.Compositor.init(allocator);
    defer compositor.deinit();
    var handler_context = handlers.HandlerContext.init();
    const secret = "test-secret-key-for-jwt-token-generation";
    var auth_service = grain_core.auth_service.AuthService.init(secret);
    const count = os_integration.register_mobile_endpoints_with_compositor(
        &compositor,
        &handler_context,
        &auth_service,
    );
    try testing.expect(count == 10);
    try testing.expect(compositor.get_api_server_route_count() == 10);
}
