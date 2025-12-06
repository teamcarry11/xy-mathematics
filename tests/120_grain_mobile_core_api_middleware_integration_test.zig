//! Tests for Grain Mobile Core API middleware integration.
//!
//! Why: Verify middleware integration with Grain OS middleware framework.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_carry_core = @import("grain_carry_core");
const api = grain_carry_core.api;

test "mobile auth middleware missing token" {
    var request = api.integration.HttpRequest{
        .method = 1,
        .path = undefined,
        .path_len = 0,
        .query = undefined,
        .query_len = 0,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const result = api.middleware_integration.mobile_auth_middleware(&request, &response);
    
    std.debug.assert(!result);
    std.debug.assert(response.status == 401);
}

test "mobile auth middleware with token" {
    var request = api.integration.HttpRequest{
        .method = 1,
        .path = undefined,
        .path_len = 0,
        .query = undefined,
        .query_len = 0,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    request.headers[0].name_len = 13;
    std.mem.copyForwards(u8, &request.headers[0].name, "Authorization");
    request.headers[0].value_len = 20;
    std.mem.copyForwards(u8, &request.headers[0].value, "Bearer test_token_123");
    request.headers_len = 1;
    
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const result = api.middleware_integration.mobile_auth_middleware(&request, &response);
    
    std.debug.assert(result);
}

test "mobile validation middleware invalid content type" {
    var request = api.integration.HttpRequest{
        .method = 1,
        .path = undefined,
        .path_len = 0,
        .query = undefined,
        .query_len = 0,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    request.headers[0].name_len = 12;
    std.mem.copyForwards(u8, &request.headers[0].name, "Content-Type");
    request.headers[0].value_len = 10;
    std.mem.copyForwards(u8, &request.headers[0].value, "text/plain");
    request.headers_len = 1;
    
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const result = api.middleware_integration.mobile_validation_middleware(&request, &response);
    
    std.debug.assert(!result);
    std.debug.assert(response.status == 400);
}

test "mobile error middleware" {
    var request = api.integration.HttpRequest{
        .method = 1,
        .path = undefined,
        .path_len = 0,
        .query = undefined,
        .query_len = 0,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const result = api.middleware_integration.mobile_error_middleware(
        &request,
        &response,
        "INVALID_INPUT",
        "Invalid input provided",
    );
    
    std.debug.assert(result);
    std.debug.assert(response.status == 400);
    std.debug.assert(response.body_len > 0);
}

test "mobile success middleware" {
    var request = api.integration.HttpRequest{
        .method = 1,
        .path = undefined,
        .path_len = 0,
        .query = undefined,
        .query_len = 0,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    var response = api.integration.HttpResponse{
        .status = 200,
        .headers = undefined,
        .headers_len = 0,
        .body = undefined,
        .body_len = 0,
    };
    
    const result = api.middleware_integration.mobile_success_middleware(
        &request,
        &response,
        "Operation successful",
        "{\"id\":123}",
    );
    
    std.debug.assert(result);
    std.debug.assert(response.status == 200);
    std.debug.assert(response.body_len > 0);
}

test "middleware config initialization" {
    const config = api.middleware_integration.MiddlewareConfig.init();
    
    std.debug.assert(config.use_cors);
    std.debug.assert(config.use_logging);
    std.debug.assert(!config.use_auth);
}

test "middleware config for public endpoint" {
    const config = api.middleware_integration.MiddlewareConfig.for_public_endpoint();
    
    std.debug.assert(config.use_cors);
    std.debug.assert(config.use_validation);
    std.debug.assert(!config.use_auth);
}

test "middleware config for auth endpoint" {
    const config = api.middleware_integration.MiddlewareConfig.for_auth_endpoint();
    
    std.debug.assert(config.use_auth);
    std.debug.assert(config.use_validation);
}

test "middleware config for protected endpoint" {
    const config = api.middleware_integration.MiddlewareConfig.for_protected_endpoint();
    
    std.debug.assert(config.use_auth);
    std.debug.assert(config.use_validation);
    std.debug.assert(config.use_rate_limit);
}

