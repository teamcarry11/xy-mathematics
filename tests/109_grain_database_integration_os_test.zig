//! Tests for Grain Database Grain OS Integration Layer.
//!
//! Why: Verify API Server integration interfaces and handler functions.
//! Architecture: Comprehensive test coverage for Grain OS integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-153056-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const DatabaseContext = grain_database.DatabaseContext;
const set_database_context = grain_database.set_database_context;
const get_database_context = grain_database.get_database_context;
const register_database_endpoints_with_compositor = grain_database.register_database_endpoints_with_compositor;
const HttpMethod = grain_database.HttpMethod;
const HttpStatus = grain_database.HttpStatus;
const HttpRequest = grain_database.HttpRequest;
const HttpResponse = grain_database.HttpResponse;
const StorageEngine = grain_database.StorageEngine;
const Schema = grain_database.Schema;
const Graph = grain_database.Graph;
const InvertedIndex = grain_database.InvertedIndex;
const RateLimiter = grain_database.RateLimiter;
const IdempotencyCache = grain_database.IdempotencyCache;
const RequestDedupCache = grain_database.RequestDedupCache;

test "database context initialization" {
    const allocator = testing.allocator;
    const storage = try StorageEngine.init(allocator, 1024 * 1024);
    defer storage.deinit();

    var schema = try Schema.init(allocator);
    defer schema.deinit();

    var graph_db = try Graph.init(allocator);
    defer graph_db.deinit();

    var fulltext = try InvertedIndex.init(allocator);
    defer fulltext.deinit();

    var limiter = try RateLimiter.init(allocator, 100);
    defer limiter.deinit();

    var idempotency_cache = try IdempotencyCache.init(allocator);
    defer idempotency_cache.deinit();

    var dedup_cache = try RequestDedupCache.init(allocator);
    defer dedup_cache.deinit();

    const context = DatabaseContext.init(
        allocator,
        &storage,
        &schema,
        &graph_db,
        &fulltext,
        &limiter,
        &idempotency_cache,
        &dedup_cache,
    );

    try testing.expect(context.storage != null);
    try testing.expect(context.schema != null);
    try testing.expect(context.graph_db != null);
}

test "set and get database context" {
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

    var idempotency_cache = try IdempotencyCache.init(allocator);
    defer idempotency_cache.deinit();

    var context = DatabaseContext.init(
        allocator,
        &storage,
        &schema,
        &graph_db,
        &fulltext,
        &limiter,
        &idempotency_cache,
    );

    set_database_context(&context);
    const retrieved = get_database_context();
    try testing.expect(retrieved != null);
    try testing.expect(retrieved.? == &context);
}

test "register database endpoints with compositor" {
    var registration_count: u32 = 0;

    const MockRegister = struct {
        count: *u32,
        fn register(
            self: *@This(),
            method: HttpMethod,
            path: []const u8,
            handler: grain_database.RouteHandler,
        ) bool {
            _ = method;
            _ = path;
            _ = handler;
            self.count.* += 1;
            return true;
        }
    };

    var mock = MockRegister{ .count = &registration_count };
    const MockCall = struct {
        mock_ptr: *MockRegister,
        fn call(
            self: *const @This(),
            method: HttpMethod,
            path: []const u8,
            handler: grain_database.RouteHandler,
        ) bool {
            return self.mock_ptr.register(method, path, handler);
        }
    };
    const mock_call = MockCall{ .mock_ptr = &mock };

    const registered = register_database_endpoints_with_compositor(mock_call.call);
    try testing.expect(registered == true);
    try testing.expect(registration_count == 9);
}

test "handler function signature compatibility" {
    const allocator = testing.allocator;
    const storage = try StorageEngine.init(allocator, 1024 * 1024);
    defer storage.deinit();

    var schema = try Schema.init(allocator);
    defer schema.deinit();

    var graph_db = try Graph.init(allocator);
    defer graph_db.deinit();

    var fulltext = try InvertedIndex.init(allocator);
    defer fulltext.deinit();

    var limiter = try RateLimiter.init(allocator, 100);
    defer limiter.deinit();

    var idempotency_cache = try IdempotencyCache.init(allocator);
    defer idempotency_cache.deinit();

    var context = DatabaseContext.init(
        allocator,
        &storage,
        &schema,
        &graph_db,
        &fulltext,
        &limiter,
        &idempotency_cache,
    );

    set_database_context(&context);

    var req = HttpRequest{
        .method = HttpMethod.get,
        .path = "/api/v1/records/123",
        .path_len = 20,
        .query = "",
        .query_len = 0,
        .headers = &.{},
        .headers_len = 0,
        .body = "",
        .body_len = 0,
    };

    var headers: [32]HttpResponse.HttpHeader = undefined;
    var body: [65536]u8 = undefined;
    var res = HttpResponse{
        .status = HttpStatus.ok,
        .headers = &headers,
        .headers_len = 0,
        .body = &body,
        .body_len = 0,
        .allocator = allocator,
    };

    const handler: grain_database.RouteHandler = grain_database.handle_get_record;
    handler(&req, &res);

    // Handler is now implemented, should return bad_request (invalid ID format) or not_found
    try testing.expect(res.status == HttpStatus.bad_request or
        res.status == HttpStatus.not_found or
        res.status == HttpStatus.internal_server_error);
}

test "http method enum values" {
    try testing.expect(@intFromEnum(HttpMethod.get) == 0);
    try testing.expect(@intFromEnum(HttpMethod.post) == 1);
    try testing.expect(@intFromEnum(HttpMethod.put) == 2);
    try testing.expect(@intFromEnum(HttpMethod.delete) == 3);
}

test "http status enum values" {
    try testing.expect(@intFromEnum(HttpStatus.ok) == 200);
    try testing.expect(@intFromEnum(HttpStatus.created) == 201);
    try testing.expect(@intFromEnum(HttpStatus.bad_request) == 400);
    try testing.expect(@intFromEnum(HttpStatus.not_found) == 404);
}

test "http request get header" {
    _ = testing.allocator;
    const header1 = HttpRequest.HttpHeader{
        .name = "Content-Type",
        .name_len = 12,
        .value = "application/json",
        .value_len = 16,
    };
    const header2 = HttpRequest.HttpHeader{
        .name = "Authorization",
        .name_len = 13,
        .value = "Bearer token123",
        .value_len = 15,
    };
    const headers = [_]HttpRequest.HttpHeader{ header1, header2 };

    const req = HttpRequest{
        .method = HttpMethod.post,
        .path = "/api/v1/records",
        .path_len = 16,
        .query = "",
        .query_len = 0,
        .headers = &headers,
        .headers_len = 2,
        .body = "",
        .body_len = 0,
    };

    const content_type = req.get_header("Content-Type");
    try testing.expect(content_type != null);
    try testing.expect(std.mem.eql(u8, content_type.?, "application/json"));

    const auth = req.get_header("Authorization");
    try testing.expect(auth != null);
    try testing.expect(std.mem.eql(u8, auth.?, "Bearer token123"));
}

test "http response add header" {
    const allocator = testing.allocator;
    var headers: [32]HttpResponse.HttpHeader = undefined;
    var body: [65536]u8 = undefined;
    var res = HttpResponse{
        .status = HttpStatus.ok,
        .headers = &headers,
        .headers_len = 0,
        .body = &body,
        .body_len = 0,
        .allocator = allocator,
    };

    const added1 = res.add_header("Content-Type", "application/json");
    try testing.expect(added1 == true);
    try testing.expect(res.headers_len == 1);

    const added2 = res.add_header("Access-Control-Allow-Origin", "*");
    try testing.expect(added2 == true);
    try testing.expect(res.headers_len == 2);
}

