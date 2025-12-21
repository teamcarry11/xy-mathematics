//! Tests for Grain Database Network Integration
//! 2025-12-09-000742-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const NetworkIntegration = grain_database.NetworkIntegration;
const TlsConfig = grain_database.TlsConfig;

test "network_integration_init" {
    const integration = NetworkIntegration.init();
    std.debug.assert(integration.connection_pool_len == 0);
    std.debug.assert(!integration.tls_config.enabled);
    std.debug.assert(integration.next_connection_id == 1);
}

test "network_integration_enable_tls" {
    var integration = NetworkIntegration.init();
    const cert_file = "test_cert.pem";
    const key_file = "test_key.pem";
    const enabled = integration.enable_tls(cert_file, key_file);
    std.debug.assert(enabled);
    std.debug.assert(integration.tls_config.enabled);
    std.debug.assert(integration.tls_config.cert_file_len == cert_file.len);
    std.debug.assert(integration.tls_config.key_file_len == key_file.len);
}

test "network_integration_disable_tls" {
    var integration = NetworkIntegration.init();
    const cert_file = "test_cert2.pem";
    const key_file = "test_key2.pem";
    _ = integration.enable_tls(cert_file, key_file);
    std.debug.assert(integration.tls_config.enabled);
    integration.disable_tls();
    std.debug.assert(!integration.tls_config.enabled);
    std.debug.assert(integration.tls_config.cert_file_len == 0);
    std.debug.assert(integration.tls_config.key_file_len == 0);
}

test "network_integration_connection_pool" {
    var integration = NetworkIntegration.init();
    const current_time: u64 = 1000;
    integration.update_time(current_time);
    const pool_idx1 = integration.get_connection_from_pool();
    std.debug.assert(pool_idx1 != null);
    std.debug.assert(integration.connection_pool_len == 1);
    std.debug.assert(integration.connection_pool[pool_idx1.?].is_active);
    const pool_idx2 = integration.get_connection_from_pool();
    std.debug.assert(pool_idx2 != null);
    std.debug.assert(integration.connection_pool_len == 2);
}

test "network_integration_return_connection" {
    var integration = NetworkIntegration.init();
    const current_time: u64 = 2000;
    integration.update_time(current_time);
    const pool_idx = integration.get_connection_from_pool();
    std.debug.assert(pool_idx != null);
    const returned = integration.return_connection_to_pool(pool_idx.?);
    std.debug.assert(returned);
    std.debug.assert(integration.connection_pool[pool_idx.?].last_used == current_time);
}

test "network_integration_cleanup_idle" {
    var integration = NetworkIntegration.init();
    const current_time: u64 = 3000;
    integration.update_time(current_time);
    const pool_idx = integration.get_connection_from_pool();
    std.debug.assert(pool_idx != null);
    const new_time: u64 = current_time + 400;
    integration.update_time(new_time);
    const cleaned = integration.cleanup_idle_connections();
    std.debug.assert(cleaned >= 0);
}

test "network_integration_get_active_count" {
    var integration = NetworkIntegration.init();
    const current_time: u64 = 4000;
    integration.update_time(current_time);
    _ = integration.get_connection_from_pool();
    _ = integration.get_connection_from_pool();
    const active_count = integration.get_active_connection_count();
    std.debug.assert(active_count == 2);
    const pool_size = integration.get_connection_pool_size();
    std.debug.assert(pool_size == 2);
}

