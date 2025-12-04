//! Tests for Grain Database API Layer.
//!
//! Why: Verify REST API routing, rate limiting, CORS, and JSON serialization.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-175009-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const ApiRouter = grain_database.ApiRouter;
const ApiRequest = grain_database.ApiRequest;
const ApiResponse = grain_database.ApiResponse;
const ApiContext = grain_database.ApiContext;
const HttpMethod = grain_database.HttpMethod;
const RateLimiter = grain_database.RateLimiter;
const JsonSerializer = grain_database.JsonSerializer;
const add_cors_headers = grain_database.add_cors_headers;
const StorageEngine = grain_database.StorageEngine;
const Schema = grain_database.Schema;
const Graph = grain_database.Graph;
const InvertedIndex = grain_database.InvertedIndex;

test "api router initialization" {
    const allocator = testing.allocator;
    var router = try ApiRouter.init(allocator);
    defer router.deinit();

    try testing.expect(router.routes_len == 0);
}

test "register route" {
    const allocator = testing.allocator;
    var router = try ApiRouter.init(allocator);
    defer router.deinit();

    const handler = struct {
        fn handle(
            request: *ApiRequest,
            response: *ApiResponse,
            context: *ApiContext,
        ) void {
            _ = request;
            _ = response;
            _ = context;
        }
    }.handle;

    try router.register_route(HttpMethod.get, "/api/records", handler, false);
    try testing.expect(router.routes_len == 1);
}

test "find route" {
    const allocator = testing.allocator;
    var router = try ApiRouter.init(allocator);
    defer router.deinit();

    const handler = struct {
        fn handle(
            request: *ApiRequest,
            response: *ApiResponse,
            context: *ApiContext,
        ) void {
            _ = request;
            _ = response;
            _ = context;
        }
    }.handle;

    try router.register_route(HttpMethod.get, "/api/records", handler, false);
    const route = router.find_route(HttpMethod.get, "/api/records");
    try testing.expect(route != null);
    try testing.expect(route.?.method == HttpMethod.get);
}

test "api response initialization" {
    const allocator = testing.allocator;
    var response = try ApiResponse.init(allocator);
    defer response.deinit();

    try testing.expect(response.status_code == 200);
    try testing.expect(response.headers_len == 0);
    try testing.expect(response.body_len == 0);
}

test "api response add header" {
    const allocator = testing.allocator;
    var response = try ApiResponse.init(allocator);
    defer response.deinit();

    try response.add_header("Content-Type", "application/json");
    try testing.expect(response.headers_len == 1);
    try testing.expect(std.mem.eql(u8, response.headers[0].name, "Content-Type"));
    try testing.expect(std.mem.eql(u8, response.headers[0].value, "application/json"));
}

test "api response set json body" {
    const allocator = testing.allocator;
    var response = try ApiResponse.init(allocator);
    defer response.deinit();

    const json = "{\"key\":\"value\"}";
    try response.set_json_body(json);
    try testing.expect(response.body_len == json.len);
}

test "rate limiter initialization" {
    const allocator = testing.allocator;
    var limiter = try RateLimiter.init(allocator, 100);
    defer limiter.deinit();

    try testing.expect(limiter.entries_len == 0);
    try testing.expect(limiter.max_requests_per_minute == 100);
}

test "rate limiter check" {
    const allocator = testing.allocator;
    var limiter = try RateLimiter.init(allocator, 10);
    defer limiter.deinit();

    const allowed = try limiter.check_rate_limit("client1");
    try testing.expect(allowed == true);
    try testing.expect(limiter.entries_len == 1);
}

test "rate limiter multiple requests" {
    const allocator = testing.allocator;
    var limiter = try RateLimiter.init(allocator, 5);
    defer limiter.deinit();

    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        const allowed = try limiter.check_rate_limit("client1");
        try testing.expect(allowed == true);
    }

    const allowed = try limiter.check_rate_limit("client1");
    try testing.expect(allowed == false);
}

test "json serializer initialization" {
    const allocator = testing.allocator;
    var serializer = JsonSerializer.init(allocator);
    _ = serializer;
    try testing.expect(true);
}

test "json serializer serialize error" {
    const allocator = testing.allocator;
    var serializer = JsonSerializer.init(allocator);
    var output: [1024]u8 = undefined;

    const len = try serializer.serialize_error("Test error", &output);
    try testing.expect(len > 0);
}

test "add cors headers" {
    const allocator = testing.allocator;
    var response = try ApiResponse.init(allocator);
    defer response.deinit();

    try add_cors_headers(&response);
    try testing.expect(response.headers_len >= 3);
}

test "multiple routes" {
    const allocator = testing.allocator;
    var router = try ApiRouter.init(allocator);
    defer router.deinit();

    const handler = struct {
        fn handle(
            request: *ApiRequest,
            response: *ApiResponse,
            context: *ApiContext,
        ) void {
            _ = request;
            _ = response;
            _ = context;
        }
    }.handle;

    try router.register_route(HttpMethod.get, "/api/records", handler, false);
    try router.register_route(HttpMethod.post, "/api/records", handler, false);
    try router.register_route(HttpMethod.put, "/api/records/1", handler, false);
    try testing.expect(router.routes_len == 3);
}

test "route with authentication required" {
    const allocator = testing.allocator;
    var router = try ApiRouter.init(allocator);
    defer router.deinit();

    const handler = struct {
        fn handle(
            request: *ApiRequest,
            response: *ApiResponse,
            context: *ApiContext,
        ) void {
            _ = request;
            _ = response;
            _ = context;
        }
    }.handle;

    try router.register_route(HttpMethod.get, "/api/users", handler, true);
    const route = router.find_route(HttpMethod.get, "/api/users");
    try testing.expect(route != null);
    try testing.expect(route.?.requires_auth == true);
}

test "api context initialization" {
    const allocator = testing.allocator;
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
    _ = context.graph_db;
    _ = context;
    try testing.expect(true);
}

