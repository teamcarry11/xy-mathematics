//! Tests for Grain Network Tools application.
//!
//! Why: Verify network scanning, port scanning, bandwidth monitoring, and DNS tools.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-102946-pst: Active implementation

const std = @import("std");
const testing = std.testing;
const NetworkToolsApp = @import("../src/grain_workspace/network_tools/app.zig").NetworkToolsApp;
const PortState = @import("../src/grain_workspace/network_tools/app.zig").PortState;
const ConnectionState = @import("../src/grain_workspace/network_tools/app.zig").ConnectionState;
const grain_os = @import("grain_os");

test "network tools app initialization" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);

    try testing.expect(app.devices_len == 0);
    try testing.expect(app.connections_len == 0);
    try testing.expect(app.dns_cache_len == 0);
    try testing.expect(app.bandwidth_bytes_sent == 0);
    try testing.expect(app.bandwidth_bytes_received == 0);
}

test "scan network" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);
    const device_count = app.scan_network("192.168.1.0", "255.255.255.0");

    try testing.expect(device_count > 0);
    try testing.expect(app.devices_len == device_count);
    try testing.expect(app.devices[0] != null);
}

test "scan ports" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);

    var results: [10]NetworkToolsApp.PortScanResult = undefined;
    var results_len: u32 = 0;
    app.scan_ports("192.168.1.1", 20, 25, &results, &results_len);

    try testing.expect(results_len > 0);
    try testing.expect(results[0].port >= 20);
    try testing.expect(results[0].port <= 25);
}

test "update bandwidth" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);
    app.update_bandwidth(1024, 2048);

    var bytes_sent: u64 = 0;
    var bytes_received: u64 = 0;
    app.get_bandwidth(&bytes_sent, &bytes_received);

    try testing.expect(bytes_sent == 1024);
    try testing.expect(bytes_received == 2048);
}

test "get bandwidth" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);
    app.update_bandwidth(512, 1024);

    var bytes_sent: u64 = 0;
    var bytes_received: u64 = 0;
    app.get_bandwidth(&bytes_sent, &bytes_received);

    try testing.expect(bytes_sent == 512);
    try testing.expect(bytes_received == 1024);
}

test "add connection" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);
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
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);
    _ = app.add_dns_cache_entry("example.com", "93.184.216.34", 3600);

    var ip_address: [46]u8 = undefined;
    var ip_address_len: u32 = 0;
    const found = app.dns_lookup("example.com", &ip_address, &ip_address_len);

    try testing.expect(found == true);
    try testing.expect(ip_address_len > 0);
}

test "add dns cache entry" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);
    const result = app.add_dns_cache_entry("test.com", "192.168.1.1", 3600);

    try testing.expect(result == true);
    try testing.expect(app.dns_cache_len == 1);
    try testing.expect(app.dns_cache[0] != null);
    try testing.expect(std.mem.eql(u8, app.dns_cache[0].?.hostname[0..app.dns_cache[0].?.hostname_len], "test.com"));
}

test "clear dns cache" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);
    _ = app.add_dns_cache_entry("test.com", "192.168.1.1", 3600);
    try testing.expect(app.dns_cache_len == 1);

    app.clear_dns_cache();
    try testing.expect(app.dns_cache_len == 0);
}

test "multiple connections" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);
    _ = app.add_connection("127.0.0.1", 8080, "192.168.1.1", 80, .established, 6);
    _ = app.add_connection("127.0.0.1", 8081, "192.168.1.2", 443, .listening, 6);

    try testing.expect(app.connections_len == 2);
    try testing.expect(app.connections[0] != null);
    try testing.expect(app.connections[1] != null);
}

test "multiple dns cache entries" {
    const allocator = testing.allocator;
    var nm = grain_os.network_manager.NetworkManager.init();

    var app = NetworkToolsApp.init(allocator, &nm);
    _ = app.add_dns_cache_entry("test1.com", "192.168.1.1", 3600);
    _ = app.add_dns_cache_entry("test2.com", "192.168.1.2", 3600);

    try testing.expect(app.dns_cache_len == 2);
    try testing.expect(app.dns_cache[0] != null);
    try testing.expect(app.dns_cache[1] != null);
}

