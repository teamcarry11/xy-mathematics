const std = @import("std");
const root = @import("root");

test "cors middleware" {
    const middleware = root.grain_core.middleware;
    const api_server = root.grain_core.api_server;
    var req = api_server.HttpRequest.init();
    var res = api_server.HttpResponse.init();
    const executed = middleware.cors_middleware(&req, &res);
    std.debug.assert(executed);
    std.debug.assert(res.headers_len > 0);
}

test "logging middleware" {
    const middleware = root.grain_core.middleware;
    const api_server = root.grain_core.api_server;
    var req = api_server.HttpRequest.init();
    req.method = api_server.HttpMethod.post;
    var path = "/api/v1/test";
    var i: u32 = 0;
    while (i < path.len) : (i += 1) {
        req.path[i] = path[i];
    }
    req.path_len = @intCast(path.len);
    var res = api_server.HttpResponse.init();
    const executed = middleware.logging_middleware(&req, &res);
    std.debug.assert(executed);
}

test "rate limit middleware" {
    const middleware = root.grain_core.middleware;
    const api_server = root.grain_core.api_server;
    var req = api_server.HttpRequest.init();
    var res = api_server.HttpResponse.init();
    const executed = middleware.rate_limit_middleware(&req, &res);
    std.debug.assert(executed);
}

test "auth middleware missing header" {
    const middleware = root.grain_core.middleware;
    const api_server = root.grain_core.api_server;
    var req = api_server.HttpRequest.init();
    var res = api_server.HttpResponse.init();
    const executed = middleware.auth_middleware(&req, &res);
    std.debug.assert(!executed);
    std.debug.assert(res.status == api_server.HttpStatus.unauthorized);
}

test "auth middleware with header" {
    const middleware = root.grain_core.middleware;
    const api_server = root.grain_core.api_server;
    var req = api_server.HttpRequest.init();
    _ = req.add_header("Authorization", "Bearer token123");
    var res = api_server.HttpResponse.init();
    const executed = middleware.auth_middleware(&req, &res);
    std.debug.assert(executed);
}

test "content type middleware get request" {
    const middleware = root.grain_core.middleware;
    const api_server = root.grain_core.api_server;
    var req = api_server.HttpRequest.init();
    req.method = api_server.HttpMethod.get;
    var res = api_server.HttpResponse.init();
    const executed = middleware.content_type_middleware(&req, &res);
    std.debug.assert(executed);
}

test "content type middleware post without content type" {
    const middleware = root.grain_core.middleware;
    const api_server = root.grain_core.api_server;
    var req = api_server.HttpRequest.init();
    req.method = api_server.HttpMethod.post;
    var res = api_server.HttpResponse.init();
    const executed = middleware.content_type_middleware(&req, &res);
    std.debug.assert(!executed);
    std.debug.assert(res.status == api_server.HttpStatus.bad_request);
}

test "content type middleware post with json" {
    const middleware = root.grain_core.middleware;
    const api_server = root.grain_core.api_server;
    var req = api_server.HttpRequest.init();
    req.method = api_server.HttpMethod.post;
    _ = req.add_header("Content-Type", "application/json");
    var res = api_server.HttpResponse.init();
    const executed = middleware.content_type_middleware(&req, &res);
    std.debug.assert(executed);
}

