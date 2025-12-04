//! Tests for Grain Database Integration Layer.
//!
//! Why: Verify API Server integration interfaces and endpoint contracts.
//! Architecture: Comprehensive test coverage for integration layer.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-104041-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const EndpointRegistry = grain_database.EndpointRegistry;
const DatabaseEndpoint = grain_database.DatabaseEndpoint;
const register_database_endpoints = grain_database.register_database_endpoints;
const HttpMethod = grain_database.HttpMethod;
const ApiContext = grain_database.ApiContext;
const StorageEngine = grain_database.StorageEngine;
const Schema = grain_database.Schema;
const Graph = grain_database.Graph;
const InvertedIndex = grain_database.InvertedIndex;
const RateLimiter = grain_database.RateLimiter;

test "endpoint registry initialization" {
    const allocator = testing.allocator;
    var registry = try EndpointRegistry.init(allocator);
    defer registry.deinit();

    try testing.expect(registry.endpoints_len == 0);
}

test "register endpoint" {
    const allocator = testing.allocator;
    var registry = try EndpointRegistry.init(allocator);
    defer registry.deinit();

    const handler = struct {
        fn handle(
            request: *grain_database.ApiRequest,
            response: *grain_database.ApiResponse,
            context: *ApiContext,
        ) void {
            _ = request;
            _ = response;
            _ = context;
        }
    }.handle;

    try registry.register_endpoint(
        HttpMethod.get,
        "/api/v1/test",
        handler,
        false,
    );
    try testing.expect(registry.endpoints_len == 1);
}

test "get endpoint" {
    const allocator = testing.allocator;
    var registry = try EndpointRegistry.init(allocator);
    defer registry.deinit();

    const handler = struct {
        fn handle(
            request: *grain_database.ApiRequest,
            response: *grain_database.ApiResponse,
            context: *ApiContext,
        ) void {
            _ = request;
            _ = response;
            _ = context;
        }
    }.handle;

    try registry.register_endpoint(
        HttpMethod.get,
        "/api/v1/test",
        handler,
        false,
    );

    const endpoint = registry.get_endpoint(HttpMethod.get, "/api/v1/test");
    try testing.expect(endpoint != null);
    try testing.expect(endpoint.?.method == HttpMethod.get);
}

test "register database endpoints" {
    const allocator = testing.allocator;
    var registry = try EndpointRegistry.init(allocator);
    defer registry.deinit();

    var storage = try StorageEngine.init(allocator, 1024 * 1024);
    defer storage.deinit();

    var schema = try Schema.init(allocator);
    defer schema.deinit();

    var graph_db = try Graph.init(allocator);
    defer graph_db.deinit();

    var fulltext = try InvertedIndex.init(allocator);
    defer fulltext.deinit();

    var limiter = try RateLimiter.init(allocator, 100);
    defer limiter.deinit();

    var context = ApiContext.init(
        allocator,
        &storage,
        &schema,
        &graph_db,
        &fulltext,
        &limiter,
    );

    try register_database_endpoints(&registry, &context);
    try testing.expect(registry.endpoints_len > 0);
}

test "multiple endpoints" {
    const allocator = testing.allocator;
    var registry = try EndpointRegistry.init(allocator);
    defer registry.deinit();

    const handler = struct {
        fn handle(
            request: *grain_database.ApiRequest,
            response: *grain_database.ApiResponse,
            context: *ApiContext,
        ) void {
            _ = request;
            _ = response;
            _ = context;
        }
    }.handle;

    try registry.register_endpoint(
        HttpMethod.get,
        "/api/v1/test1",
        handler,
        false,
    );
    try registry.register_endpoint(
        HttpMethod.post,
        "/api/v1/test2",
        handler,
        true,
    );
    try registry.register_endpoint(
        HttpMethod.put,
        "/api/v1/test3",
        handler,
        false,
    );

    try testing.expect(registry.endpoints_len == 3);
}

test "endpoint with authentication required" {
    const allocator = testing.allocator;
    var registry = try EndpointRegistry.init(allocator);
    defer registry.deinit();

    const handler = struct {
        fn handle(
            request: *grain_database.ApiRequest,
            response: *grain_database.ApiResponse,
            context: *ApiContext,
        ) void {
            _ = request;
            _ = response;
            _ = context;
        }
    }.handle;

    try registry.register_endpoint(
        HttpMethod.get,
        "/api/v1/secure",
        handler,
        true,
    );

    const endpoint = registry.get_endpoint(HttpMethod.get, "/api/v1/secure");
    try testing.expect(endpoint != null);
    try testing.expect(endpoint.?.requires_auth == true);
}

