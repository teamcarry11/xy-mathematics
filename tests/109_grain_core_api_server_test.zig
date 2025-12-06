//! Tests for Grain OS API Server module.
//!
//! Why: Verify API server functionality (routes, requests, responses).
//! Architecture: Test route registration, request/response handling.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const api_server = @import("grain_core").api_server;

test "api server init" {
    const server = api_server.ApiServer.init(8080);
    std.debug.assert(server.port == 8080);
    std.debug.assert(!server.is_running());
    std.debug.assert(server.get_route_count() == 0);
}

test "api server register route" {
    var server = api_server.ApiServer.init(8080);
    const handler: api_server.RouteHandler = &test_handler;
    const registered = server.register_route(
        api_server.HttpMethod.get,
        "/api/v1/test",
        handler,
    );
    std.debug.assert(registered);
    std.debug.assert(server.get_route_count() == 1);
}

test "api server find route" {
    var server = api_server.ApiServer.init(8080);
    const handler: api_server.RouteHandler = &test_handler;
    _ = server.register_route(
        api_server.HttpMethod.get,
        "/api/v1/test",
        handler,
    );
    const route = server.find_route(
        api_server.HttpMethod.get,
        "/api/v1/test",
    );
    std.debug.assert(route != null);
    if (route) |r| {
        std.debug.assert(r.method == api_server.HttpMethod.get);
        std.debug.assert(r.active);
    }
}

test "api server start stop" {
    var server = api_server.ApiServer.init(8080);
    const handler: api_server.RouteHandler = &test_handler;
    _ = server.register_route(
        api_server.HttpMethod.get,
        "/api/v1/test",
        handler,
    );
    const started = server.start();
    std.debug.assert(started);
    std.debug.assert(server.is_running());
    server.stop();
    std.debug.assert(!server.is_running());
}

test "http request init" {
    const req = api_server.HttpRequest.init();
    std.debug.assert(req.method == api_server.HttpMethod.get);
    std.debug.assert(req.path_len == 0);
    std.debug.assert(req.query_len == 0);
    std.debug.assert(req.headers_len == 0);
    std.debug.assert(req.body_len == 0);
}

test "http request get header" {
    var req = api_server.HttpRequest.init();
    req.headers[0] = api_server.HttpHeader.init();
    req.headers[0].name_len = 4;
    req.headers[0].name[0] = 'T';
    req.headers[0].name[1] = 'e';
    req.headers[0].name[2] = 's';
    req.headers[0].name[3] = 't';
    req.headers[0].value_len = 5;
    req.headers[0].value[0] = 'V';
    req.headers[0].value[1] = 'a';
    req.headers[0].value[2] = 'l';
    req.headers[0].value[3] = 'u';
    req.headers[0].value[4] = 'e';
    req.headers_len = 1;
    const header_value = req.get_header("Test");
    std.debug.assert(header_value != null);
    if (header_value) |val| {
        std.debug.assert(val.len == 5);
        std.debug.assert(val[0] == 'V');
    }
}

test "http response init" {
    const res = api_server.HttpResponse.init();
    std.debug.assert(res.status == api_server.HttpStatus.ok);
    std.debug.assert(res.headers_len == 0);
    std.debug.assert(res.body_len == 0);
}

test "http response add header" {
    var res = api_server.HttpResponse.init();
    const added = res.add_header("Content-Type", "application/json");
    std.debug.assert(added);
    std.debug.assert(res.headers_len == 1);
    std.debug.assert(res.headers[0].name_len == 12);
    std.debug.assert(res.headers[0].value_len == 16);
}

test "api server max routes" {
    var server = api_server.ApiServer.init(8080);
    const handler: api_server.RouteHandler = &test_handler;
    var i: u32 = 0;
    while (i < api_server.MAX_ROUTES) : (i += 1) {
        var path_buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(
            &path_buf,
            "/api/v1/test{}",
            .{i},
        ) catch unreachable;
        _ = server.register_route(
            api_server.HttpMethod.get,
            path,
            handler,
        );
    }
    std.debug.assert(server.get_route_count() == api_server.MAX_ROUTES);
    const overflow = server.register_route(
        api_server.HttpMethod.get,
        "/api/v1/overflow",
        handler,
    );
    std.debug.assert(!overflow);
}

test "api server start without routes" {
    var server = api_server.ApiServer.init(8080);
    const started = server.start();
    std.debug.assert(!started);
    std.debug.assert(!server.is_running());
}

test "parse http request" {
    var server = api_server.ApiServer.init(8080);
    var req = api_server.HttpRequest.init();
    const raw_request = "GET /api/v1/test?key=value HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const parsed = server.parse_http_request(raw_request, &req);
    std.debug.assert(parsed);
    std.debug.assert(req.method == api_server.HttpMethod.get);
    std.debug.assert(req.path_len == 13);
    std.debug.assert(req.query_len == 9);
}

test "parse http request with body" {
    var server = api_server.ApiServer.init(8080);
    var req = api_server.HttpRequest.init();
    const raw_request = "POST /api/v1/test HTTP/1.1\r\nContent-Length: 5\r\n\r\nhello";
    const parsed = server.parse_http_request(raw_request, &req);
    std.debug.assert(parsed);
    std.debug.assert(req.method == api_server.HttpMethod.post);
    std.debug.assert(req.body_len == 5);
}

test "generate http response" {
    var server = api_server.ApiServer.init(8080);
    var res = api_server.HttpResponse.init();
    res.status = api_server.HttpStatus.ok;
    _ = res.add_header("Content-Type", "application/json");
    const body = "{\"status\":\"ok\"}";
    var i: u32 = 0;
    while (i < body.len) : (i += 1) {
        res.body[i] = body[i];
    }
    res.body_len = @intCast(body.len);
    var output: [1024]u8 = undefined;
    const generated = server.generate_http_response(&res, &output);
    std.debug.assert(generated != null);
    if (generated) |len| {
        std.debug.assert(len > 0);
    }
}

test "extract path parameters" {
    var server = api_server.ApiServer.init(8080);
    const pattern = "/api/v1/records/{id}";
    const path = "/api/v1/records/123";
    var params: [4][]const u8 = undefined;
    const param_count = server.extract_path_parameters(pattern, path, &params);
    std.debug.assert(param_count != null);
    if (param_count) |count| {
        std.debug.assert(count == 1);
        std.debug.assert(std.mem.eql(u8, params[0], "123"));
    }
}

test "add middleware to route" {
    var server = api_server.ApiServer.init(8080);
    const handler: api_server.RouteHandler = &test_handler;
    const middleware_fn: api_server.Middleware = &test_middleware;
    _ = server.register_route(api_server.HttpMethod.post, "/api/v1/test", handler);
    const added = server.add_middleware_to_route(api_server.HttpMethod.post, "/api/v1/test", middleware_fn);
    std.debug.assert(added);
    if (server.find_route(api_server.HttpMethod.post, "/api/v1/test")) |route| {
        std.debug.assert(route.middleware_len == 1);
    } else {
        std.debug.assert(false);
    }
}

test "execute middleware chain" {
    var server = api_server.ApiServer.init(8080);
    const handler: api_server.RouteHandler = &test_handler;
    const middleware_fn: api_server.Middleware = &test_middleware;
    _ = server.register_route(api_server.HttpMethod.post, "/api/v1/test", handler);
    _ = server.add_middleware_to_route(api_server.HttpMethod.post, "/api/v1/test", middleware_fn);
    if (server.find_route(api_server.HttpMethod.post, "/api/v1/test")) |route| {
        var req = api_server.HttpRequest.init();
        var res = api_server.HttpResponse.init();
        const executed = server.execute_middleware_chain(route, &req, &res);
        std.debug.assert(executed);
    } else {
        std.debug.assert(false);
    }
}

// Test handler function.
fn test_handler(_req: *api_server.HttpRequest, res: *api_server.HttpResponse) void {
    _ = _req;
    res.status = api_server.HttpStatus.ok;
    _ = res.add_header("Content-Type", "application/json");
    const body = "{\"status\":\"ok\"}";
    var i: u32 = 0;
    while (i < body.len) : (i += 1) {
        res.body[i] = body[i];
    }
    res.body_len = @intCast(body.len);
}

// Test middleware function.
fn test_middleware(_req: *api_server.HttpRequest, _res: *api_server.HttpResponse) bool {
    _ = _req;
    _ = _res;
    return true;
}

test "register server process" {
    var server = api_server.ApiServer.init(8080);
    const handler: api_server.RouteHandler = &test_handler;
    _ = server.register_route(api_server.HttpMethod.get, "/api/v1/test", handler);
    _ = server.start();
    const process_manager = @import("root").grain_core.process_manager.ProcessManager.init();
    const process_id = server.register_server_process(
        &process_manager,
        0,
        "api_server",
        "api_server --port 8080",
        1000,
    );
    std.debug.assert(process_id != null);
    if (process_id) |pid| {
        std.debug.assert(server.get_server_process_id() != null);
        if (server.get_server_process_id()) |server_pid| {
            std.debug.assert(server_pid == pid);
        }
    }
}

test "update server process state" {
    var server = api_server.ApiServer.init(8080);
    const handler: api_server.RouteHandler = &test_handler;
    _ = server.register_route(api_server.HttpMethod.get, "/api/v1/test", handler);
    _ = server.start();
    var process_manager = @import("root").grain_core.process_manager.ProcessManager.init();
    if (server.register_server_process(&process_manager, 0, "api_server", "api_server --port 8080", 1000)) |_pid| {
        const updated = server.update_server_process_state(
            &process_manager,
            @import("root").grain_core.process_manager.ProcessState.sleeping,
        );
        std.debug.assert(updated);
    } else {
        std.debug.assert(false);
    }
}

