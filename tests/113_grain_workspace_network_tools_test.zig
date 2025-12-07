//! Tests for Grain Network Tools application.
//!
//! Why: Verify network scanning, port scanning, bandwidth monitoring, and DNS tools.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-011616-pst: Active implementation
//! 2025-12-07-020824-pst: Phase 10.3 WebSocket integration tests
//! 2025-12-07-054458-pst: Phase 11 HTTP Client integration tests

const std = @import("std");
const testing = std.testing;
const NetworkToolsApp = @import("../src/grain_workspace/network_tools/app.zig").NetworkToolsApp;
const PortState = @import("../src/grain_workspace/network_tools/app.zig").PortState;
const ConnectionState = @import("../src/grain_workspace/network_tools/app.zig").ConnectionState;
const grain_core = @import("grain_core");

test "network tools app initialization" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);

    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);

    try testing.expect(app.devices_len == 0);
    try testing.expect(app.connections_len == 0);
    try testing.expect(app.bandwidth_bytes_sent == 0);
    try testing.expect(app.bandwidth_bytes_received == 0);
    try testing.expect(app.websocket_clients_len == 0);
    try testing.expect(app.http_test_results_len == 0);
}

test "scan network" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);
    const device_count = app.scan_network("192.168.1.0", "255.255.255.0");

    try testing.expect(device_count > 0);
    try testing.expect(app.devices_len == device_count);
    try testing.expect(app.devices[0] != null);
}

test "scan ports" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);

    var results: [10]NetworkToolsApp.PortScanResult = undefined;
    var results_len: u32 = 0;
    app.scan_ports("192.168.1.1", 20, 25, &results, &results_len);

    try testing.expect(results_len > 0);
    try testing.expect(results[0].port >= 20);
    try testing.expect(results[0].port <= 25);
}

test "update bandwidth" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);
    app.update_bandwidth(1024, 2048);

    var bytes_sent: u64 = 0;
    var bytes_received: u64 = 0;
    app.get_bandwidth(&bytes_sent, &bytes_received);

    try testing.expect(bytes_sent == 1024);
    try testing.expect(bytes_received == 2048);
}

test "get bandwidth" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);
    app.update_bandwidth(512, 1024);

    var bytes_sent: u64 = 0;
    var bytes_received: u64 = 0;
    app.get_bandwidth(&bytes_sent, &bytes_received);

    try testing.expect(bytes_sent == 512);
    try testing.expect(bytes_received == 1024);
}

test "add connection" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);
    const result = app.add_connection("127.0.0.1", 8080, "192.168.1.1", 80, .established, 6);

    try testing.expect(result == true);
    try testing.expect(app.connections_len == 1);
    try testing.expect(app.connections[0] != null);
    try testing.expect(app.connections[0].?.local_port == 8080);
    try testing.expect(app.connections[0].?.remote_port == 80);
    try testing.expect(app.connections[0].?.state == .established);
}

test "dns lookup" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);
    _ = app.add_dns_cache_entry("example.com", .a, "93.184.216.34");

    var ip_address: [16]u8 = undefined;
    var ip_address_len: u32 = 0;
    const found = app.dns_lookup("example.com", .a, &ip_address, &ip_address_len);

    try testing.expect(found == true);
    try testing.expect(ip_address_len > 0);
}

test "add dns cache entry" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);
    const result = app.add_dns_cache_entry("test.com", .a, "192.168.1.1");

    try testing.expect(result == true);
    try testing.expect(dns_res.cache_len == 1);
    try testing.expect(dns_res.cache[0].active == true);
    try testing.expect(std.mem.eql(u8, dns_res.cache[0].hostname[0..dns_res.cache[0].hostname_len], "test.com"));
}

test "clear expired dns cache" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(1); // 1 second TTL
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);
    _ = app.add_dns_cache_entry("test.com", .a, "192.168.1.1");
    try testing.expect(dns_res.cache_len == 1);

    // Wait for cache to expire
    std.time.sleep(2000000000); // 2 seconds

    const cleared = app.clear_expired_dns_cache();
    try testing.expect(cleared == 1);
}

test "multiple connections" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);
    _ = app.add_connection("127.0.0.1", 8080, "192.168.1.1", 80, .established, 6);
    _ = app.add_connection("127.0.0.1", 8081, "192.168.1.2", 443, .listening, 6);

    try testing.expect(app.connections_len == 2);
    try testing.expect(app.connections[0] != null);
    try testing.expect(app.connections[1] != null);
}

test "multiple dns cache entries" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);
    _ = app.add_dns_cache_entry("test1.com", .a, "192.168.1.1");
    _ = app.add_dns_cache_entry("test2.com", .a, "192.168.1.2");

    try testing.expect(dns_res.cache_len == 2);
    try testing.expect(dns_res.cache[0].active == true);
    try testing.expect(dns_res.cache[1].active == true);
}

test "websocket client management" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);
    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);

    // Add WebSocket client
    const conn1 = ws_manager.add_connection(1);
    try testing.expect(conn1 != null);
    if (conn1) |conn| {
        conn.state = grain_core.websocket.ConnectionState.open;
        const added = app.add_websocket_client(conn.connection_id);
        try testing.expect(added == true);
        try testing.expect(app.websocket_clients_len == 1);
    }

    // Add another client
    const conn2 = ws_manager.add_connection(2);
    try testing.expect(conn2 != null);
    if (conn2) |conn| {
        conn.state = grain_core.websocket.ConnectionState.open;
        const added = app.add_websocket_client(conn.connection_id);
        try testing.expect(added == true);
        try testing.expect(app.websocket_clients_len == 2);
    }

    // Remove client
    if (conn1) |conn| {
        const removed = app.remove_websocket_client(conn.connection_id);
        try testing.expect(removed == true);
        try testing.expect(app.websocket_clients_len == 1);
    }
}

test "http endpoint testing" {
    const allocator = testing.allocator;
    var nm = grain_core.network_manager.NetworkManager.init();
    var dns_res = grain_core.dns_resolver.DnsResolver.init(3600);
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var net_stack = grain_core.network_stack.NetworkStack.init();
    var http_client = grain_core.http_client.HttpClient.init(&net_stack, &dns_res);

    var app = NetworkToolsApp.init(allocator, &nm, &dns_res, &ws_manager, &http_client);

    // Test HTTP endpoint (GET request)
    const test_id = app.test_http_endpoint(.get, "http://example.com/api/test");
    try testing.expect(test_id != null);
    try testing.expect(app.http_test_results_len == 1);

    // Get test result
    const result = app.get_http_test_result(test_id.?);
    try testing.expect(result != null);
    try testing.expect(result.?.test_id == test_id.?);
    try testing.expect(result.?.method == .get);

    // Test another endpoint (POST request)
    const test_id2 = app.test_http_endpoint(.post, "http://example.com/api/data");
    try testing.expect(test_id2 != null);
    try testing.expect(app.http_test_results_len == 2);

    // Get all test results
    var results: [10]?*const NetworkToolsApp.HttpTestResult = undefined;
    var results_len: u32 = 0;
    app.get_all_http_test_results(&results, &results_len);
    try testing.expect(results_len == 2);

    // Clear test results
    const cleared = app.clear_http_test_results();
    try testing.expect(cleared == 2);
    try testing.expect(app.http_test_results_len == 0);
}
