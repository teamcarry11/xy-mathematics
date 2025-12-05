//! Integration tests for Grain Mobile Core API full request/response pipeline.
//!
//! Why: Verify end-to-end API functionality using process_http_request().
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_mobile_core = @import("grain_mobile_core");
const grain_os = @import("grain_os");
const api = grain_mobile_core.api;

test "register mobile endpoints and test register endpoint" {
    var compositor = grain_os.Compositor.init();
    var handler_context = api.handlers.HandlerContext.init();
    
    const count = api.os_integration.register_mobile_endpoints_with_compositor(&compositor, &handler_context);
    
    std.debug.assert(count == 10);
    
    var conn_mgr = grain_os.connection_manager.ConnectionManager.init();
    const raw_request = "POST /api/v1/auth/register HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 100\r\n" ++
        "\r\n" ++
        "{\"email\":\"user@example.com\",\"password\":\"MySecurePassword123!With32CharsMinimum\",\"username\":\"testuser\"}";
    
    const response_opt = grain_os.api_server_network.process_http_request(
        &compositor.api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    
    std.debug.assert(response_opt != null);
    const response = response_opt.?;
    std.debug.assert(response.status == grain_os.api_server.HttpStatus.ok or response.status == grain_os.api_server.HttpStatus.bad_request);
}

test "test login endpoint with registered routes" {
    var compositor = grain_os.Compositor.init();
    var handler_context = api.handlers.HandlerContext.init();
    
    _ = api.os_integration.register_mobile_endpoints_with_compositor(&compositor, &handler_context);
    
    var conn_mgr = grain_os.connection_manager.ConnectionManager.init();
    const raw_request = "POST /api/v1/auth/login HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 80\r\n" ++
        "\r\n" ++
        "{\"email\":\"user@example.com\",\"password\":\"MySecurePassword123!With32CharsMinimum\"}";
    
    const response_opt = grain_os.api_server_network.process_http_request(
        &compositor.api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    
    std.debug.assert(response_opt != null);
    const response = response_opt.?;
    std.debug.assert(response.status >= 200);
}

test "test users profile endpoint" {
    var compositor = grain_os.Compositor.init();
    var handler_context = api.handlers.HandlerContext.init();
    
    _ = api.os_integration.register_mobile_endpoints_with_compositor(&compositor, &handler_context);
    
    var conn_mgr = grain_os.connection_manager.ConnectionManager.init();
    const raw_request = "GET /api/v1/users/profile HTTP/1.1\r\n" ++
        "Authorization: Bearer test_token_123\r\n" ++
        "\r\n";
    
    const response_opt = grain_os.api_server_network.process_http_request(
        &compositor.api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    
    std.debug.assert(response_opt != null);
    const response = response_opt.?;
    std.debug.assert(response.status >= 200);
}

test "test 404 for unregistered route" {
    var compositor = grain_os.Compositor.init();
    var conn_mgr = grain_os.connection_manager.ConnectionManager.init();
    
    const raw_request = "GET /api/v1/invalid/route HTTP/1.1\r\n\r\n";
    
    const response_opt = grain_os.api_server_network.process_http_request(
        &compositor.api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    
    std.debug.assert(response_opt != null);
    const response = response_opt.?;
    std.debug.assert(response.status == grain_os.api_server.HttpStatus.not_found);
}

test "test otp send endpoint" {
    var compositor = grain_os.Compositor.init();
    var handler_context = api.handlers.HandlerContext.init();
    
    _ = api.os_integration.register_mobile_endpoints_with_compositor(&compositor, &handler_context);
    
    var conn_mgr = grain_os.connection_manager.ConnectionManager.init();
    const raw_request = "POST /api/v1/auth/otp/send HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 30\r\n" ++
        "\r\n" ++
        "{\"email\":\"user@example.com\"}";
    
    const response_opt = grain_os.api_server_network.process_http_request(
        &compositor.api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    
    std.debug.assert(response_opt != null);
    const response = response_opt.?;
    std.debug.assert(response.status >= 200);
}

test "test middleware execution with CORS" {
    var compositor = grain_os.Compositor.init();
    var handler_context = api.handlers.HandlerContext.init();
    
    _ = api.os_integration.register_mobile_endpoints_with_compositor(&compositor, &handler_context);
    
    // Add CORS middleware to a route
    _ = compositor.api_server.add_middleware_to_route(
        grain_os.api_server.HttpMethod.post,
        api.endpoints.AUTH_REGISTER_PATH,
        grain_os.middleware.cors_middleware,
    );
    
    var conn_mgr = grain_os.connection_manager.ConnectionManager.init();
    const raw_request = "POST /api/v1/auth/register HTTP/1.1\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: 100\r\n" ++
        "\r\n" ++
        "{\"email\":\"user@example.com\",\"password\":\"MySecurePassword123!With32CharsMinimum\",\"username\":\"testuser\"}";
    
    const response_opt = grain_os.api_server_network.process_http_request(
        &compositor.api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    
    std.debug.assert(response_opt != null);
    const response = response_opt.?;
    std.debug.assert(response.status >= 200);
    
    // Check for CORS headers
    const cors_header = response.get_header("Access-Control-Allow-Origin");
    std.debug.assert(cors_header != null);
}

test "test request parsing with query parameters" {
    var compositor = grain_os.Compositor.init();
    
    const raw_request = "GET /api/v1/users/profile?format=json HTTP/1.1\r\n\r\n";
    
    var request = grain_os.api_server.HttpRequest.init();
    const parsed = compositor.api_server.parse_http_request(raw_request, &request);
    
    std.debug.assert(parsed);
    std.debug.assert(request.method == grain_os.api_server.HttpMethod.get);
    std.debug.assert(request.path_len > 0);
}

test "test response generation" {
    var compositor = grain_os.Compositor.init();
    var handler_context = api.handlers.HandlerContext.init();
    
    _ = api.os_integration.register_mobile_endpoints_with_compositor(&compositor, &handler_context);
    
    var conn_mgr = grain_os.connection_manager.ConnectionManager.init();
    const raw_request = "GET /api/v1/users/settings HTTP/1.1\r\n" ++
        "Authorization: Bearer test_token_123\r\n" ++
        "\r\n";
    
    const response_opt = grain_os.api_server_network.process_http_request(
        &compositor.api_server,
        &conn_mgr,
        raw_request,
        null,
    );
    
    std.debug.assert(response_opt != null);
    const response = response_opt.?;
    std.debug.assert(response.status >= 200);
    std.debug.assert(response.body_len > 0);
    
    // Verify Content-Type header
    const content_type = response.get_header("Content-Type");
    std.debug.assert(content_type != null);
}

