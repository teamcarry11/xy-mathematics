const std = @import("std");
const root = @import("root");

test "network server init" {
    const network = root.grain_core.api_server_network;
    var server = network.NetworkServer.init(8080);
    std.debug.assert(server.port == 8080);
    std.debug.assert(server.state == network.NetworkServerState.stopped);
    std.debug.assert(!server.bound);
    std.debug.assert(!server.listening);
}

test "network server bind to port" {
    const network = root.grain_core.api_server_network;
    var server = network.NetworkServer.init(8080);
    const result = server.bind_to_port();
    std.debug.assert(result == network.BindResult.success);
    std.debug.assert(server.bound);
    std.debug.assert(server.state == network.NetworkServerState.listening);
}

test "network server start listening" {
    const network = root.grain_core.api_server_network;
    var server = network.NetworkServer.init(8080);
    _ = server.bind_to_port();
    const started = server.start_listening();
    std.debug.assert(started);
    std.debug.assert(server.is_listening());
    std.debug.assert(server.state == network.NetworkServerState.accepting);
}

test "network server stop listening" {
    const network = root.grain_core.api_server_network;
    var server = network.NetworkServer.init(8080);
    _ = server.bind_to_port();
    _ = server.start_listening();
    server.stop_listening();
    std.debug.assert(!server.is_listening());
    std.debug.assert(server.state == network.NetworkServerState.stopped);
}

test "process http request" {
    const network = root.grain_core.api_server_network;
    const api_server_mod = root.grain_core.api_server;
    const conn_mgr = root.grain_core.connection_manager;
    var server = api_server_mod.ApiServer.init(8080);
    var conn_manager = conn_mgr.ConnectionManager.init();
    const handler: api_server_mod.RouteHandler = &test_handler;
    _ = server.register_route(api_server_mod.HttpMethod.get, "/api/v1/test", handler);
    const raw_request = "GET /api/v1/test HTTP/1.1\r\n\r\n";
    if (network.process_http_request(&server, &conn_manager, raw_request, null)) |response| {
        std.debug.assert(response.status == api_server_mod.HttpStatus.ok);
    } else {
        std.debug.assert(false);
    }
}

test "process http request not found" {
    const network = root.grain_core.api_server_network;
    const api_server_mod = root.grain_core.api_server;
    const conn_mgr = root.grain_core.connection_manager;
    var server = api_server_mod.ApiServer.init(8080);
    var conn_manager = conn_mgr.ConnectionManager.init();
    const raw_request = "GET /api/v1/notfound HTTP/1.1\r\n\r\n";
    if (network.process_http_request(&server, &conn_manager, raw_request, null)) |response| {
        std.debug.assert(response.status == api_server_mod.HttpStatus.not_found);
    } else {
        std.debug.assert(false);
    }
}

// Test handler function.
fn test_handler(_req: *root.grain_core.api_server.HttpRequest, res: *root.grain_core.api_server.HttpResponse) void {
    _ = _req;
    res.status = root.grain_core.api_server.HttpStatus.ok;
    _ = res.add_header("Content-Type", "application/json");
    const body = "{\"status\":\"ok\"}";
    var i: u32 = 0;
    while (i < body.len) : (i += 1) {
        res.body[i] = body[i];
    }
    res.body_len = @intCast(body.len);
}

