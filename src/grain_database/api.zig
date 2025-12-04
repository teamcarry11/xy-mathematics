//! Grain Database API: REST API layer for mobile backend integration.
//!
//! Why: Expose database operations via REST API for mobile apps.
//! Architecture: Endpoint handlers, JSON serialization, middleware.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-03-175009-pst: Grain Database Agent
//!
//! Note: Integrates with Grain OS Agent's API Server (Phase 59).

const std = @import("std");
const storage_engine = @import("storage_engine.zig");
const relational = @import("relational.zig");
const graph = @import("graph.zig");
const index = @import("index.zig");

// Bounded: Max request body size (bytes).
pub const MAX_REQUEST_BODY_SIZE: u32 = 1_048_576; // 1 MB

// Bounded: Max response body size (bytes).
pub const MAX_RESPONSE_BODY_SIZE: u32 = 10_485_760; // 10 MB

// Bounded: Max routes.
pub const MAX_ROUTES: u32 = 256;

// Bounded: Max rate limit entries.
pub const MAX_RATE_LIMIT_ENTRIES: u32 = 10_000;

// HTTP method.
pub const HttpMethod = enum {
    get,
    post,
    put,
    delete,
    patch,
};

// API request context.
pub const ApiRequest = struct {
    method: HttpMethod,
    path: []const u8,
    path_len: u32,
    headers: []const Header,
    headers_len: u32,
    body: []const u8,
    body_len: u32,
    query_params: []const QueryParam,
    query_params_len: u32,
    allocator: std.mem.Allocator,

    pub const Header = struct {
        name: []const u8,
        name_len: u32,
        value: []const u8,
        value_len: u32,
    };

    pub const QueryParam = struct {
        key: []const u8,
        key_len: u32,
        value: []const u8,
        value_len: u32,
    };

    // Get header value by name.
    pub fn get_header(self: *ApiRequest, name: []const u8) ?[]const u8 {
        std.debug.assert(name.len <= 256);
        var i: u32 = 0;
        while (i < self.headers_len) : (i += 1) {
            if (std.mem.eql(u8, self.headers[i].name, name)) {
                return self.headers[i].value;
            }
        }
        return null;
    }

    // Get query parameter value by key.
    pub fn get_query_param(self: *ApiRequest, key: []const u8) ?[]const u8 {
        std.debug.assert(key.len <= 256);
        var i: u32 = 0;
        while (i < self.query_params_len) : (i += 1) {
            if (std.mem.eql(u8, self.query_params[i].key, key)) {
                return self.query_params[i].value;
            }
        }
        return null;
    }
};

// API response.
pub const ApiResponse = struct {
    status_code: u16,
    headers: []const Header,
    headers_len: u32,
    body: []const u8,
    body_len: u32,
    allocator: std.mem.Allocator,

    pub const Header = struct {
        name: []const u8,
        name_len: u32,
        value: []const u8,
        value_len: u32,
    };

    // Initialize response.
    pub fn init(allocator: std.mem.Allocator) !ApiResponse {
        var headers = try allocator.alloc(Header, 32);
        errdefer allocator.free(headers);

        var body = try allocator.alloc(u8, MAX_RESPONSE_BODY_SIZE);
        errdefer allocator.free(body);

        return ApiResponse{
            .status_code = 200,
            .headers = headers,
            .headers_len = 0,
            .body = body,
            .body_len = 0,
            .allocator = allocator,
        };
    }

    // Deinitialize response and free memory.
    pub fn deinit(self: *ApiResponse) void {
        self.allocator.free(self.headers);
        self.allocator.free(self.body);
        self.* = undefined;
    }

    // Add header to response.
    pub fn add_header(
        self: *ApiResponse,
        name: []const u8,
        value: []const u8,
    ) !void {
        std.debug.assert(self.headers_len < 32);
        std.debug.assert(name.len <= 256);
        std.debug.assert(value.len <= 1024);

        if (self.headers_len >= 32) {
            return error.TooManyHeaders;
        }

        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        self.headers[self.headers_len] = Header{
            .name = name_copy,
            .name_len = @as(u32, @intCast(name_copy.len)),
            .value = value_copy,
            .value_len = @as(u32, @intCast(value_copy.len)),
        };
        self.headers_len += 1;
    }

    // Set response body (JSON).
    pub fn set_json_body(
        self: *ApiResponse,
        json: []const u8,
    ) !void {
        std.debug.assert(json.len <= MAX_RESPONSE_BODY_SIZE);

        if (json.len > self.body.len) {
            return error.BodyTooLarge;
        }

        @memcpy(self.body[0..json.len], json);
        self.body_len = @as(u32, @intCast(json.len));
    }
};

// Route handler function type.
pub const RouteHandler = *const fn (
    request: *ApiRequest,
    response: *ApiResponse,
    context: *ApiContext,
) void;

// API route definition.
pub const Route = struct {
    method: HttpMethod,
    path: []const u8,
    path_len: u32,
    handler: RouteHandler,
    requires_auth: bool,
    allocator: std.mem.Allocator,

    // Initialize route.
    pub fn init(
        allocator: std.mem.Allocator,
        method: HttpMethod,
        path: []const u8,
        handler: RouteHandler,
        requires_auth: bool,
    ) !Route {
        std.debug.assert(path.len <= 512);
        const path_copy = try allocator.dupe(u8, path);
        errdefer allocator.free(path_copy);

        return Route{
            .method = method,
            .path = path_copy,
            .path_len = @as(u32, @intCast(path_copy.len)),
            .handler = handler,
            .requires_auth = requires_auth,
            .allocator = allocator,
        };
    }

    // Deinitialize route and free memory.
    pub fn deinit(self: *Route) void {
        if (self.path_len > 0) {
            self.allocator.free(self.path);
        }
        self.* = undefined;
    }
};

// Rate limit entry.
pub const RateLimitEntry = struct {
    client_id: []const u8,
    client_id_len: u32,
    request_count: u32,
    window_start: u64,
    allocator: std.mem.Allocator,

    // Initialize rate limit entry.
    pub fn init(
        allocator: std.mem.Allocator,
        client_id: []const u8,
    ) !RateLimitEntry {
        std.debug.assert(client_id.len <= 256);
        const id_copy = try allocator.dupe(u8, client_id);
        errdefer allocator.free(id_copy);

        const now = std.time.timestamp();

        return RateLimitEntry{
            .client_id = id_copy,
            .client_id_len = @as(u32, @intCast(id_copy.len)),
            .request_count = 1,
            .window_start = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }

    // Deinitialize entry and free memory.
    pub fn deinit(self: *RateLimitEntry) void {
        if (self.client_id_len > 0) {
            self.allocator.free(self.client_id);
        }
        self.* = undefined;
    }
};

// Rate limiter: Tracks requests per client.
pub const RateLimiter = struct {
    entries: []RateLimitEntry,
    entries_len: u32,
    max_requests_per_minute: u32,
    allocator: std.mem.Allocator,

    // Initialize rate limiter.
    pub fn init(
        allocator: std.mem.Allocator,
        max_requests_per_minute: u32,
    ) !RateLimiter {
        const entries = try allocator.alloc(
            RateLimitEntry,
            MAX_RATE_LIMIT_ENTRIES,
        );
        errdefer allocator.free(entries);

        return RateLimiter{
            .entries = entries,
            .entries_len = 0,
            .max_requests_per_minute = max_requests_per_minute,
            .allocator = allocator,
        };
    }

    // Deinitialize rate limiter and free memory.
    pub fn deinit(self: *RateLimiter) void {
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            self.entries[i].deinit();
        }
        self.allocator.free(self.entries);
        self.* = undefined;
    }

    // Check if client exceeds rate limit.
    pub fn check_rate_limit(
        self: *RateLimiter,
        client_id: []const u8,
    ) !bool {
        std.debug.assert(client_id.len <= 256);
        const now = std.time.timestamp();
        const window_seconds: u64 = 60;

        const entry = try self.find_or_create_entry(client_id);
        if (now - entry.window_start > window_seconds) {
            entry.request_count = 1;
            entry.window_start = @as(u64, @intCast(now));
            return true;
        }

        if (entry.request_count >= self.max_requests_per_minute) {
            return false;
        }

        entry.request_count += 1;
        return true;
    }

    // Find or create rate limit entry.
    fn find_or_create_entry(
        self: *RateLimiter,
        client_id: []const u8,
    ) !*RateLimitEntry {
        std.debug.assert(client_id.len <= 256);

        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (std.mem.eql(u8, self.entries[i].client_id, client_id)) {
                return &self.entries[i];
            }
        }

        if (self.entries_len >= MAX_RATE_LIMIT_ENTRIES) {
            return error.TooManyRateLimitEntries;
        }

        const entry = try RateLimitEntry.init(self.allocator, client_id);
        errdefer entry.deinit();

        self.entries[self.entries_len] = entry;
        self.entries_len += 1;

        std.debug.assert(self.entries_len <= MAX_RATE_LIMIT_ENTRIES);
        return &self.entries[self.entries_len - 1];
    }
};

// API context: Database and configuration.
pub const ApiContext = struct {
    storage: *storage_engine.StorageEngine,
    schema: *relational.Schema,
    graph_db: *graph.Graph,
    fulltext_index: *index.InvertedIndex,
    rate_limiter: *RateLimiter,
    allocator: std.mem.Allocator,

    // Initialize API context.
    pub fn init(
        allocator: std.mem.Allocator,
        storage: *storage_engine.StorageEngine,
        schema: *relational.Schema,
        graph_db: *graph.Graph,
        fulltext_index: *index.InvertedIndex,
        rate_limiter: *RateLimiter,
    ) ApiContext {
        return ApiContext{
            .storage = storage,
            .schema = schema,
            .graph_db = graph_db,
            .fulltext_index = fulltext_index,
            .rate_limiter = rate_limiter,
            .allocator = allocator,
        };
    }
};

// API router: Manages routes and handles requests.
pub const ApiRouter = struct {
    routes: []Route,
    routes_len: u32,
    allocator: std.mem.Allocator,

    // Initialize API router.
    pub fn init(allocator: std.mem.Allocator) !ApiRouter {
        const routes = try allocator.alloc(Route, MAX_ROUTES);
        errdefer allocator.free(routes);

        return ApiRouter{
            .routes = routes,
            .routes_len = 0,
            .allocator = allocator,
        };
    }

    // Deinitialize router and free memory.
    pub fn deinit(self: *ApiRouter) void {
        var i: u32 = 0;
        while (i < self.routes_len) : (i += 1) {
            self.routes[i].deinit();
        }
        self.allocator.free(self.routes);
        self.* = undefined;
    }

    // Register route.
    pub fn register_route(
        self: *ApiRouter,
        method: HttpMethod,
        path: []const u8,
        handler: RouteHandler,
        requires_auth: bool,
    ) !void {
        std.debug.assert(self.routes_len < MAX_ROUTES);

        if (self.routes_len >= MAX_ROUTES) {
            return error.TooManyRoutes;
        }

        var route = try Route.init(
            self.allocator,
            method,
            path,
            handler,
            requires_auth,
        );
        errdefer route.deinit();

        self.routes[self.routes_len] = route;
        self.routes_len += 1;

        std.debug.assert(self.routes_len <= MAX_ROUTES);
    }

    // Find route by method and path.
    pub fn find_route(
        self: *ApiRouter,
        method: HttpMethod,
        path: []const u8,
    ) ?*Route {
        std.debug.assert(path.len <= 1024);
        var i: u32 = 0;
        while (i < self.routes_len) : (i += 1) {
            if (self.routes[i].method == method) {
                if (std.mem.eql(u8, self.routes[i].path, path)) {
                    return &self.routes[i];
                }
            }
        }
        return null;
    }
};

// CORS middleware: Add CORS headers to response.
pub fn add_cors_headers(response: *ApiResponse) !void {
    try response.add_header("Access-Control-Allow-Origin", "*");
    try response.add_header(
        "Access-Control-Allow-Methods",
        "GET, POST, PUT, DELETE, OPTIONS",
    );
    try response.add_header(
        "Access-Control-Allow-Headers",
        "Content-Type, Authorization",
    );
}

// JSON serialization helpers.
pub const JsonSerializer = struct {
    allocator: std.mem.Allocator,

    // Initialize JSON serializer.
    pub fn init(allocator: std.mem.Allocator) JsonSerializer {
        return JsonSerializer{
            .allocator = allocator,
        };
    }

    // Serialize record to JSON.
    pub fn serialize_record(
        self: *JsonSerializer,
        record: *storage_engine.Record,
        output: []u8,
    ) !u32 {
        std.debug.assert(output.len >= MAX_RESPONSE_BODY_SIZE);

        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();

        try json.writer().print(
            "{{\"id\":{},\"key\":\"{}\",\"value\":\"{}\"}}",
            .{ record.record_id, record.key, record.value },
        );

        if (json.items.len > output.len) {
            return error.BufferTooSmall;
        }

        @memcpy(output[0..json.items.len], json.items);
        return @as(u32, @intCast(json.items.len));
    }

    // Serialize error to JSON.
    pub fn serialize_error(
        self: *JsonSerializer,
        error_message: []const u8,
        output: []u8,
    ) !u32 {
        std.debug.assert(output.len >= 1024);

        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();

        try json.writer().print("{{\"error\":\"{}\"}}", .{error_message});

        if (json.items.len > output.len) {
            return error.BufferTooSmall;
        }

        @memcpy(output[0..json.items.len], json.items);
        return @as(u32, @intCast(json.items.len));
    }
};

// WebSocket support for livestream coordination.
pub const WebSocketConnection = struct {
    connection_id: u64,
    client_id: []const u8,
    client_id_len: u32,
    is_active: bool,
    last_ping: u64,
    allocator: std.mem.Allocator,

    // Initialize WebSocket connection.
    pub fn init(
        allocator: std.mem.Allocator,
        connection_id: u64,
        client_id: []const u8,
    ) !WebSocketConnection {
        std.debug.assert(client_id.len <= 256);
        const id_copy = try allocator.dupe(u8, client_id);
        errdefer allocator.free(id_copy);

        const now = std.time.timestamp();

        return WebSocketConnection{
            .connection_id = connection_id,
            .client_id = id_copy,
            .client_id_len = @as(u32, @intCast(id_copy.len)),
            .is_active = true,
            .last_ping = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }

    // Deinitialize connection and free memory.
    pub fn deinit(self: *WebSocketConnection) void {
        if (self.client_id_len > 0) {
            self.allocator.free(self.client_id);
        }
        self.* = undefined;
    }

    // Update last ping timestamp.
    pub fn update_ping(self: *WebSocketConnection) void {
        const now = std.time.timestamp();
        self.last_ping = @as(u64, @intCast(now));
        std.debug.assert(self.last_ping > 0);
    }
};

// Bounded: Max WebSocket connections.
pub const MAX_WEBSOCKET_CONNECTIONS: u32 = 1000;

// WebSocket connection manager.
pub const WebSocketManager = struct {
    connections: []WebSocketConnection,
    connections_len: u32,
    allocator: std.mem.Allocator,

    // Initialize WebSocket manager.
    pub fn init(allocator: std.mem.Allocator) !WebSocketManager {
        const connections = try allocator.alloc(
            WebSocketConnection,
            MAX_WEBSOCKET_CONNECTIONS,
        );
        errdefer allocator.free(connections);

        return WebSocketManager{
            .connections = connections,
            .connections_len = 0,
            .allocator = allocator,
        };
    }

    // Deinitialize manager and free memory.
    pub fn deinit(self: *WebSocketManager) void {
        var i: u32 = 0;
        while (i < self.connections_len) : (i += 1) {
            self.connections[i].deinit();
        }
        self.allocator.free(self.connections);
        self.* = undefined;
    }

    // Add WebSocket connection.
    pub fn add_connection(
        self: *WebSocketManager,
        connection_id: u64,
        client_id: []const u8,
    ) !u32 {
        std.debug.assert(self.connections_len < MAX_WEBSOCKET_CONNECTIONS);

        if (self.connections_len >= MAX_WEBSOCKET_CONNECTIONS) {
            return error.TooManyConnections;
        }

        var conn = try WebSocketConnection.init(
            self.allocator,
            connection_id,
            client_id,
        );
        errdefer conn.deinit();

        self.connections[self.connections_len] = conn;
        self.connections_len += 1;

        std.debug.assert(self.connections_len <= MAX_WEBSOCKET_CONNECTIONS);
        return self.connections_len - 1;
    }

    // Remove WebSocket connection.
    pub fn remove_connection(
        self: *WebSocketManager,
        connection_idx: u32,
    ) void {
        std.debug.assert(connection_idx < self.connections_len);

        self.connections[connection_idx].deinit();

        if (connection_idx < self.connections_len - 1) {
            self.connections[connection_idx] =
                self.connections[self.connections_len - 1];
        }

        self.connections_len -= 1;
    }

    // Get connection by ID.
    pub fn get_connection(
        self: *WebSocketManager,
        connection_id: u64,
    ) ?*WebSocketConnection {
        var i: u32 = 0;
        while (i < self.connections_len) : (i += 1) {
            if (self.connections[i].connection_id == connection_id) {
                return &self.connections[i];
            }
        }
        return null;
    }
};

// JWT authentication middleware.
pub const AuthMiddleware = struct {
    secret: []const u8,
    secret_len: u32,
    allocator: std.mem.Allocator,

    // Initialize authentication middleware.
    pub fn init(
        allocator: std.mem.Allocator,
        secret: []const u8,
    ) !AuthMiddleware {
        std.debug.assert(secret.len > 0);
        std.debug.assert(secret.len <= 256);
        const secret_copy = try allocator.dupe(u8, secret);
        errdefer allocator.free(secret_copy);

        return AuthMiddleware{
            .secret = secret_copy,
            .secret_len = @as(u32, @intCast(secret_copy.len)),
            .allocator = allocator,
        };
    }

    // Deinitialize middleware and free memory.
    pub fn deinit(self: *AuthMiddleware) void {
        if (self.secret_len > 0) {
            self.allocator.free(self.secret);
        }
        self.* = undefined;
    }

    // Validate JWT token from Authorization header.
    pub fn validate_request(
        self: *AuthMiddleware,
        request: *ApiRequest,
    ) bool {
        std.debug.assert(request != null);

        const auth_header = request.get_header("Authorization");
        if (auth_header == null) {
            return false;
        }

        const auth_value = auth_header.?;
        if (auth_value.len < 7) {
            return false;
        }

        if (!std.mem.eql(u8, auth_value[0..7], "Bearer ")) {
            return false;
        }

        const token = auth_value[7..];
        if (token.len == 0) {
            return false;
        }

        const now = std.time.timestamp();
        const current_time = @as(u64, @intCast(now));

        var claims: struct {
            user_id: [64]u8,
            user_id_len: u32,
            exp: u64,
            iat: u64,
        } = undefined;

        return self.validate_jwt_token(token, current_time, &claims);
    }

    // Validate JWT token (simplified validation).
    fn validate_jwt_token(
        self: *AuthMiddleware,
        token: []const u8,
        current_time: u64,
        claims: *struct {
            user_id: [64]u8,
            user_id_len: u32,
            exp: u64,
            iat: u64,
        },
    ) bool {
        std.debug.assert(token.len > 0);
        std.debug.assert(token.len <= 2048);
        std.debug.assert(current_time > 0);

        var parts: [3][]const u8 = undefined;
        var part_count: u32 = 0;
        var start: u32 = 0;
        var i: u32 = 0;

        while (i < token.len and part_count < 3) : (i += 1) {
            if (token[i] == '.') {
                parts[part_count] = token[start..i];
                part_count += 1;
                start = i + 1;
            }
        }

        if (part_count < 2) {
            return false;
        }

        parts[part_count] = token[start..];
        part_count += 1;

        if (part_count != 3) {
            return false;
        }

        var exp_found: bool = false;
        var exp_value: u64 = 0;
        var user_id_start: ?u32 = null;
        var user_id_end: ?u32 = null;

        var claims_decoded: [256]u8 = undefined;
        var claims_decoded_len: u32 = 0;

        i = 0;
        while (i < parts[1].len and claims_decoded_len < 256) : (i += 1) {
            const c = parts[1][i];
            if (c == '-' or c == '_') {
                claims_decoded[claims_decoded_len] = '+';
            } else if (c == '/') {
                claims_decoded[claims_decoded_len] = '=';
            } else {
                claims_decoded[claims_decoded_len] = c;
            }
            claims_decoded_len += 1;
        }

        i = 0;
        while (i < claims_decoded_len) : (i += 1) {
            if (i + 3 < claims_decoded_len and
                std.mem.eql(u8, claims_decoded[i..i + 4], "\"exp\""))
            {
                i += 4;
                while (i < claims_decoded_len and
                    (claims_decoded[i] == ' ' or claims_decoded[i] == ':')) : (i += 1)
                {}
                const exp_str_start = i;
                while (i < claims_decoded_len and
                    claims_decoded[i] >= '0' and claims_decoded[i] <= '9') : (i += 1)
                {}
                const exp_str = claims_decoded[exp_str_start..i];
                exp_value = 0;
                var exp_j: u32 = 0;
                while (exp_j < exp_str.len) : (exp_j += 1) {
                    if (exp_str[exp_j] >= '0' and exp_str[exp_j] <= '9') {
                        exp_value = exp_value * 10 + @as(u64, exp_str[exp_j] - '0');
                    }
                }
                exp_found = true;
            }
            if (i + 7 < claims_decoded_len and
                std.mem.eql(u8, claims_decoded[i..i + 8], "\"user_id\""))
            {
                i += 8;
                while (i < claims_decoded_len and claims_decoded[i] != '"') : (i += 1) {}
                i += 1;
                user_id_start = i;
                while (i < claims_decoded_len and claims_decoded[i] != '"') : (i += 1) {}
                user_id_end = i;
            }
        }

        if (!exp_found) {
            return false;
        }

        if (current_time > exp_value) {
            return false;
        }

        if (user_id_start != null and user_id_end != null) {
            const user_id_len = user_id_end.? - user_id_start.?;
            if (user_id_len > 0 and user_id_len <= 64) {
                std.mem.copyForwards(
                    u8,
                    &claims.user_id,
                    claims_decoded[user_id_start.?..user_id_end.?],
                );
                claims.user_id_len = @as(u32, @intCast(user_id_len));
            }
        }

        claims.exp = exp_value;
        claims.iat = 0;

        std.debug.assert(claims.user_id_len > 0);
        std.debug.assert(claims.exp > 0);

        return true;
    }
};

