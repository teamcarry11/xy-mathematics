//! Tests for Grain Database Middleware Integration.
//!
//! Why: Verify middleware integration with Grain OS API Server.
//! Architecture: Comprehensive test coverage for middleware adapters.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-05-083545-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const grain_os = @import("grain_os");
const StorageEngine = grain_database.StorageEngine;
const Schema = grain_database.Schema;
const Graph = grain_database.Graph;
const InvertedIndex = grain_database.InvertedIndex;
const RateLimiter = grain_database.RateLimiter;
const DatabaseContext = grain_database.DatabaseContext;
const set_database_context = grain_database.set_database_context;
const database_rate_limit_middleware = grain_database.database_rate_limit_middleware;
const database_auth_middleware = grain_database.database_auth_middleware;
const database_cors_middleware = grain_database.database_cors_middleware;
const database_content_type_middleware = grain_database.database_content_type_middleware;
const register_database_middleware = grain_database.register_database_middleware;

test "database rate limit middleware allows request" {
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

    var context = DatabaseContext.init(
        allocator,
        &storage,
        &schema,
        &graph_db,
        &fulltext,
        &limiter,
    );
    defer context.deinit();

    set_database_context(&context);

    var req = grain_os.api_server.HttpRequest.init();
    _ = req.add_header("X-Client-ID", "test-client");

    var res = grain_os.api_server.HttpResponse.init();

    const allowed = database_rate_limit_middleware(&req, &res);
    try testing.expect(allowed == true);
    try testing.expect(res.status == grain_os.api_server.HttpStatus.ok);
}

test "database cors middleware adds headers" {
    var req = grain_os.api_server.HttpRequest.init();
    var res = grain_os.api_server.HttpResponse.init();

    const allowed = database_cors_middleware(&req, &res);
    try testing.expect(allowed == true);
    try testing.expect(res.headers_len > 0);
}

test "database auth middleware checks authorization" {
    var req = grain_os.api_server.HttpRequest.init();
    _ = req.add_header("Authorization", "Bearer test-token");
    var res = grain_os.api_server.HttpResponse.init();

    const allowed = database_auth_middleware(&req, &res);
    try testing.expect(allowed == true);
}

test "database auth middleware rejects missing authorization" {
    var req = grain_os.api_server.HttpRequest.init();
    var res = grain_os.api_server.HttpResponse.init();

    const allowed = database_auth_middleware(&req, &res);
    try testing.expect(allowed == false);
    try testing.expect(res.status == grain_os.api_server.HttpStatus.unauthorized);
}

test "database content type middleware validates json" {
    var req = grain_os.api_server.HttpRequest.init();
    req.method = grain_os.api_server.HttpMethod.post;
    _ = req.add_header("Content-Type", "application/json");
    var res = grain_os.api_server.HttpResponse.init();

    const allowed = database_content_type_middleware(&req, &res);
    try testing.expect(allowed == true);
}

test "register database middleware" {
    var registration_count: u32 = 0;

    const MockRegister = struct {
        count: *u32,
        fn register(
            self: *@This(),
            method: grain_os.api_server.HttpMethod,
            path: []const u8,
            middleware: grain_os.api_server.Middleware,
        ) bool {
            _ = method;
            _ = path;
            _ = middleware;
            self.count.* += 1;
            return true;
        }
    };

    var mock = MockRegister{ .count = &registration_count };
    const MockCall = struct {
        mock_ptr: *MockRegister,
        fn call(
            self: *const @This(),
            method: grain_os.api_server.HttpMethod,
            path: []const u8,
            middleware: grain_os.api_server.Middleware,
        ) bool {
            return self.mock_ptr.register(method, path, middleware);
        }
    };
    const mock_call = MockCall{ .mock_ptr = &mock };

    const registered = register_database_middleware(mock_call.call);
    try testing.expect(registered == true);
    try testing.expect(registration_count == 9);
}

