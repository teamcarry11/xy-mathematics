const std = @import("std");
const testing = std.testing;
const grain_core = @import("grain_core");

test "http client init" {
    var net_stack = grain_core.network_stack.NetworkStack.init();
    var dns_resolver = grain_core.dns_resolver.DnsResolver.init();
    const client = grain_core.http_client.HttpClient.init(&net_stack, &dns_resolver);
    std.debug.assert(client.requests_len == 0);
    std.debug.assert(client.next_request_id == 1);
}

test "http client request init" {
    const req = grain_core.http_client.HttpClientRequest.init(1);
    std.debug.assert(req.request_id == 1);
    std.debug.assert(req.method == grain_core.api_server.HttpMethod.get);
    std.debug.assert(req.state == grain_core.http_client.RequestState.pending);
    std.debug.assert(req.socket_id == null);
}

test "http client request set url" {
    var req = grain_core.http_client.HttpClientRequest.init(1);
    const url = "https://example.com/api/test";
    const set = req.set_url(url);
    std.debug.assert(set);
    std.debug.assert(req.url_len == url.len);
}

test "http client request add header" {
    var req = grain_core.http_client.HttpClientRequest.init(1);
    const added = req.add_header("Content-Type", "application/json");
    std.debug.assert(added);
    std.debug.assert(req.headers_len == 1);
    std.debug.assert(req.headers[0].name_len == 12);
    std.debug.assert(req.headers[0].value_len == 16);
}

test "http client create request" {
    var net_stack = grain_core.network_stack.NetworkStack.init();
    var dns_resolver = grain_core.dns_resolver.DnsResolver.init();
    var client = grain_core.http_client.HttpClient.init(&net_stack, &dns_resolver);
    const req = client.create_request(
        grain_core.api_server.HttpMethod.get,
        "https://example.com/api",
    );
    std.debug.assert(req != null);
    std.debug.assert(client.requests_len == 1);
    std.debug.assert(req.?.request_id == 1);
}

test "http client find request" {
    var net_stack = grain_core.network_stack.NetworkStack.init();
    var dns_resolver = grain_core.dns_resolver.DnsResolver.init();
    var client = grain_core.http_client.HttpClient.init(&net_stack, &dns_resolver);
    _ = client.create_request(
        grain_core.api_server.HttpMethod.get,
        "https://example.com/api",
    );
    const found = client.find_request(1);
    std.debug.assert(found != null);
    std.debug.assert(found.?.request_id == 1);
}

test "http client remove request" {
    var net_stack = grain_core.network_stack.NetworkStack.init();
    var dns_resolver = grain_core.dns_resolver.DnsResolver.init();
    var client = grain_core.http_client.HttpClient.init(&net_stack, &dns_resolver);
    _ = client.create_request(
        grain_core.api_server.HttpMethod.get,
        "https://example.com/api",
    );
    const removed = client.remove_request(1);
    std.debug.assert(removed);
    std.debug.assert(client.requests_len == 0);
}

test "http client get request count" {
    var net_stack = grain_core.network_stack.NetworkStack.init();
    var dns_resolver = grain_core.dns_resolver.DnsResolver.init();
    var client = grain_core.http_client.HttpClient.init(&net_stack, &dns_resolver);
    std.debug.assert(client.get_request_count() == 0);
    _ = client.create_request(
        grain_core.api_server.HttpMethod.get,
        "https://example.com/api",
    );
    std.debug.assert(client.get_request_count() == 1);
}

