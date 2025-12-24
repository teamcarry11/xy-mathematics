//! Grain Database Integration: Grain OS API Server integration.
//!
//! Why: Integrate database endpoints with Grain OS API Server (Phase 59).
//! Architecture: Route registration, handler adapters, API Server interface.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-142508-pst: Grain Database Agent
//!
//! Note: Integrates with Grain OS Agent's API Server (Phase 59).

const std = @import("std");
const api = @import("api.zig");
const storage_engine = @import("storage_engine.zig");
const relational = @import("relational.zig");
const graph = @import("graph.zig");
const index = @import("index.zig");
const query = @import("query.zig");

// Import Grain OS API Server types (when available).
// For now, we define compatible types.
pub const HttpMethod = enum(u8) {
    get,
    post,
    put,
    delete,
    patch,
    head,
    options,
};

pub const HttpStatus = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    conflict = 409,
    internal_server_error = 500,
    service_unavailable = 503,
};

// HTTP request (compatible with Grain OS API Server).
pub const HttpRequest = struct {
    method: HttpMethod,
    path: []const u8,
    path_len: u32,
    query: []const u8,
    query_len: u32,
    headers: []const HttpHeader,
    headers_len: u32,
    body: []const u8,
    body_len: u32,

    pub const HttpHeader = struct {
        name: []const u8,
        name_len: u32,
        value: []const u8,
        value_len: u32,
    };

    // Get header by name.
    pub fn get_header(self: *const HttpRequest, name: []const u8) ?[]const u8 {
        std.debug.assert(name.len > 0);
        var i: u32 = 0;
        while (i < self.headers_len) : (i += 1) {
            if (std.mem.eql(u8, self.headers[i].name, name)) {
                return self.headers[i].value;
            }
        }
        return null;
    }
};

// HTTP response (compatible with Grain OS API Server).
pub const HttpResponse = struct {
    status: HttpStatus,
    headers: []HttpHeader,
    headers_len: u32,
    body: []u8,
    body_len: u32,
    allocator: std.mem.Allocator,

    pub const HttpHeader = struct {
        name: []const u8,
        name_len: u32,
        value: []const u8,
        value_len: u32,
    };

    // Add header to response.
    pub fn add_header(
        self: *HttpResponse,
        name: []const u8,
        value: []const u8,
    ) bool {
        std.debug.assert(self.headers_len < 32);
        std.debug.assert(name.len <= 128);
        std.debug.assert(value.len <= 512);

        if (self.headers_len >= 32) {
            return false;
        }

        const name_copy = self.allocator.dupe(u8, name) catch return false;
        const value_copy = self.allocator.dupe(u8, value) catch {
            self.allocator.free(name_copy);
            return false;
        };

        self.headers[self.headers_len] = HttpHeader{
            .name = name_copy,
            .name_len = @as(u32, @intCast(name_copy.len)),
            .value = value_copy,
            .value_len = @as(u32, @intCast(value_copy.len)),
        };
        self.headers_len += 1;
        return true;
    }
};

// Route handler type (compatible with Grain OS API Server).
pub const RouteHandler = *const fn (*HttpRequest, *HttpResponse) void;

// Database context for handlers.
pub const DatabaseContext = struct {
    storage: *storage_engine.StorageEngine,
    schema: *relational.Schema,
    graph_db: *graph.Graph,
    fulltext_index: *index.InvertedIndex,
    rate_limiter: *api.RateLimiter,
    allocator: std.mem.Allocator,

    // Initialize database context.
    pub fn init(
        allocator: std.mem.Allocator,
        storage: *storage_engine.StorageEngine,
        schema: *relational.Schema,
        graph_db: *graph.Graph,
        fulltext_index: *index.InvertedIndex,
        rate_limiter: *api.RateLimiter,
    ) DatabaseContext {
        return DatabaseContext{
            .storage = storage,
            .schema = schema,
            .graph_db = graph_db,
            .fulltext_index = fulltext_index,
            .rate_limiter = rate_limiter,
            .allocator = allocator,
        };
    }
};

// Global database context (set during initialization).
var global_db_context: ?*DatabaseContext = null;

// Set global database context.
pub fn set_database_context(context: *DatabaseContext) void {
    global_db_context = context;
    std.debug.assert(global_db_context != null);
}

// Get global database context.
pub fn get_database_context() ?*DatabaseContext {
    return global_db_context;
}

// Register all database endpoints with Grain OS API Server.
// This function should be called with compositor.register_api_route().
pub fn register_database_endpoints_with_compositor(
    register_fn: *const fn (HttpMethod, []const u8, RouteHandler) bool,
) bool {
    std.debug.assert(register_fn != null);

    // Key-value endpoints.
    if (!register_fn(HttpMethod.get, "/api/v1/records/{id}", handle_get_record)) {
        return false;
    }
    if (!register_fn(HttpMethod.post, "/api/v1/records", handle_create_record)) {
        return false;
    }
    if (!register_fn(HttpMethod.put, "/api/v1/records/{id}", handle_update_record)) {
        return false;
    }
    if (!register_fn(HttpMethod.delete, "/api/v1/records/{id}", handle_delete_record)) {
        return false;
    }

    // Relational endpoints.
    if (!register_fn(HttpMethod.get, "/api/v1/tables", handle_list_tables)) {
        return false;
    }
    if (!register_fn(HttpMethod.post, "/api/v1/query", handle_execute_query)) {
        return false;
    }

    // Graph endpoints.
    if (!register_fn(HttpMethod.get, "/api/v1/graph/nodes/{id}", handle_get_node)) {
        return false;
    }
    if (!register_fn(HttpMethod.post, "/api/v1/graph/traverse", handle_traverse_graph)) {
        return false;
    }

    // Full-text search endpoints.
    if (!register_fn(HttpMethod.get, "/api/v1/search", handle_fulltext_search)) {
        return false;
    }

    // Health check endpoint.
    if (!register_fn(HttpMethod.get, "/api/v1/health", handle_health_check)) {
        return false;
    }

    return true;
}

// Extract path parameter (e.g., {id} from /api/v1/records/{id}).
fn extract_path_param(
    pattern: []const u8,
    path: []const u8,
) ?[]const u8 {
    std.debug.assert(pattern.len > 0);
    std.debug.assert(path.len > 0);
    var pattern_pos: u32 = 0;
    var path_pos: u32 = 0;
    var param_start: ?u32 = null;
    while (pattern_pos < pattern.len and path_pos < path.len) : (pattern_pos += 1) {
        if (pattern[pattern_pos] == '{') {
            param_start = path_pos;
        } else if (pattern[pattern_pos] == '}') {
            if (param_start) |start| {
                return path[start..path_pos];
            }
        } else if (pattern[pattern_pos] == path[path_pos]) {
            path_pos += 1;
        } else if (param_start != null) {
            path_pos += 1;
        } else {
            return null;
        }
    }
    return null;
}

// Parse record ID from path.
fn parse_record_id(path: []const u8) ?u64 {
    std.debug.assert(path.len > 0);
    const pattern = "/api/v1/records/{id}";
    const param = extract_path_param(pattern, path) orelse return null;
    var id: u64 = 0;
    var i: u32 = 0;
    while (i < param.len) : (i += 1) {
        if (param[i] >= '0' and param[i] <= '9') {
            id = id * 10 + @as(u64, param[i] - '0');
        } else {
            return null;
        }
    }
    return if (id > 0) id else null;
}

// Handler: Get record by ID.
pub fn handle_get_record(req: *HttpRequest, res: *HttpResponse) void {
    std.debug.assert(req != null);
    std.debug.assert(res != null);
    const context = get_database_context() orelse {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    const path = req.path[0..req.path_len];
    const record_id = parse_record_id(path) orelse {
        res.status = HttpStatus.bad_request;
        return;
    };
    var serializer = api.JsonSerializer.init(context.allocator);
    const record = context.storage.read_record_by_id(record_id);
    if (record) |r| {
        res.status = HttpStatus.ok;
        _ = res.add_header("Content-Type", "application/json");
        const json_len = serializer.serialize_record(r, res.body) catch {
            res.status = HttpStatus.internal_server_error;
            return;
        };
        res.body_len = json_len;
    } else {
        res.status = HttpStatus.not_found;
        const error_len = serializer.serialize_error(
            "Record not found",
            res.body,
        ) catch {
            res.status = HttpStatus.internal_server_error;
            return;
        };
        res.body_len = error_len;
    }
}

// Parse simple JSON body for record creation (key and value).
fn parse_create_record_body(body: []const u8) struct {
    key: ?[]const u8,
    value: ?[]const u8,
} {
    std.debug.assert(body.len <= 65536);
    var key: ?[]const u8 = null;
    var value: ?[]const u8 = null;
    var i: u32 = 0;
    while (i < body.len) : (i += 1) {
        if (i + 4 < body.len and std.mem.eql(u8, body[i..i + 5], "\"key\"")) {
            i += 5;
            while (i < body.len and body[i] != '"') : (i += 1) {}
            i += 1;
            const key_start = i;
            while (i < body.len and body[i] != '"') : (i += 1) {}
            key = body[key_start..i];
        } else if (i + 5 < body.len and std.mem.eql(u8, body[i..i + 6], "\"value\"")) {
            i += 6;
            while (i < body.len and body[i] != '"') : (i += 1) {}
            i += 1;
            const value_start = i;
            while (i < body.len and body[i] != '"') : (i += 1) {}
            value = body[value_start..i];
        }
    }
    return .{ .key = key, .value = value };
}

// Handler: Create new record.
pub fn handle_create_record(req: *HttpRequest, res: *HttpResponse) void {
    std.debug.assert(req != null);
    std.debug.assert(res != null);
    const context = get_database_context() orelse {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    const body = req.body[0..req.body_len];
    const parsed = parse_create_record_body(body);
    if (parsed.key == null or parsed.value == null) {
        res.status = HttpStatus.bad_request;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Missing key or value", res.body) catch {};
        return;
    }
    const record_id = context.storage.create_record(
        parsed.key.?,
        parsed.value.?,
    ) catch |err| {
        res.status = if (err == error.RecordExists) HttpStatus.conflict else HttpStatus.internal_server_error;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Failed to create record", res.body) catch {};
        return;
    };
    res.status = HttpStatus.created;
    _ = res.add_header("Content-Type", "application/json");
    var serializer = api.JsonSerializer.init(context.allocator);
    const record = context.storage.read_record_by_id(record_id);
    if (record) |r| {
        const json_len = serializer.serialize_record(r, res.body) catch {
            res.status = HttpStatus.internal_server_error;
            return;
        };
        res.body_len = json_len;
    }
}

// Handler: Update existing record.
pub fn handle_update_record(req: *HttpRequest, res: *HttpResponse) void {
    std.debug.assert(req != null);
    std.debug.assert(res != null);
    const context = get_database_context() orelse {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    const path = req.path[0..req.path_len];
    const record_id = parse_record_id(path) orelse {
        res.status = HttpStatus.bad_request;
        return;
    };
    const record = context.storage.read_record_by_id(record_id);
    if (record == null) {
        res.status = HttpStatus.not_found;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Record not found", res.body) catch {};
        return;
    }
    const body = req.body[0..req.body_len];
    const parsed = parse_create_record_body(body);
    if (parsed.value == null) {
        res.status = HttpStatus.bad_request;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Missing value", res.body) catch {};
        return;
    }
    context.storage.update_record(record.?.key, parsed.value.?) catch {
        res.status = HttpStatus.internal_server_error;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Failed to update record", res.body) catch {};
        return;
    };
    res.status = HttpStatus.ok;
    _ = res.add_header("Content-Type", "application/json");
    var serializer = api.JsonSerializer.init(context.allocator);
    const updated = context.storage.read_record_by_id(record_id);
    if (updated) |r| {
        const json_len = serializer.serialize_record(r, res.body) catch {
            res.status = HttpStatus.internal_server_error;
            return;
        };
        res.body_len = json_len;
    }
}

// Handler: Delete record by ID.
pub fn handle_delete_record(req: *HttpRequest, res: *HttpResponse) void {
    std.debug.assert(req != null);
    std.debug.assert(res != null);
    const context = get_database_context() orelse {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    const path = req.path[0..req.path_len];
    const record_id = parse_record_id(path) orelse {
        res.status = HttpStatus.bad_request;
        return;
    };
    const record = context.storage.read_record_by_id(record_id);
    if (record == null) {
        res.status = HttpStatus.not_found;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Record not found", res.body) catch {};
        return;
    }
    context.storage.delete_record(record.?.key) catch {
        res.status = HttpStatus.internal_server_error;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Failed to delete record", res.body) catch {};
        return;
    };
    res.status = HttpStatus.no_content;
}

// Handler: List all tables.
pub fn handle_list_tables(req: *HttpRequest, res: *HttpResponse) void {
    _ = req;
    std.debug.assert(res != null);
    const context = get_database_context() orelse {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    res.status = HttpStatus.ok;
    _ = res.add_header("Content-Type", "application/json");
    var stream = std.io.fixedBufferStream(res.body);
    const writer = stream.writer();
    writer.print("{{\"tables\":[", .{}) catch {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    var i: u32 = 0;
    while (i < context.schema.tables_len) : (i += 1) {
        if (i > 0) {
            writer.print(",", .{}) catch {
                res.status = HttpStatus.internal_server_error;
                return;
            };
        }
        const table = context.schema.tables[i];
        writer.print("\"{}\"", .{table.name[0..table.name_len]}) catch {
            res.status = HttpStatus.internal_server_error;
            return;
        };
    }
    writer.print("]}}", .{}) catch {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    res.body_len = @as(u32, @intCast(stream.getPos()));
}

// Parse query from JSON body (simplified: expects {"query": "SELECT ..."}).
fn parse_query_body(body: []const u8) ?[]const u8 {
    std.debug.assert(body.len <= 65536);
    var i: u32 = 0;
    while (i + 7 < body.len) : (i += 1) {
        if (std.mem.eql(u8, body[i..i + 8], "\"query\"")) {
            i += 8;
            while (i < body.len and body[i] != '"') : (i += 1) {}
            i += 1;
            const query_start = i;
            while (i < body.len and body[i] != '"') : (i += 1) {}
            return body[query_start..i];
        }
    }
    return null;
}

// Handler: Execute SQL-like query.
pub fn handle_execute_query(req: *HttpRequest, res: *HttpResponse) void {
    std.debug.assert(req != null);
    std.debug.assert(res != null);
    const context = get_database_context() orelse {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    const body = req.body[0..req.body_len];
    if (body.len == 0) {
        res.status = HttpStatus.bad_request;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Missing query", res.body) catch {};
        return;
    }
    const query_str = parse_query_body(body) orelse {
        res.status = HttpStatus.bad_request;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Invalid query format", res.body) catch {};
        return;
    };
    if (query_str.len > query.MAX_QUERY_LEN) {
        res.status = HttpStatus.bad_request;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Query too long", res.body) catch {};
        return;
    }
    var executor = query.QueryExecutor.init(
        context.allocator,
        context.schema,
        context.storage,
    );
    var query_obj = query.Query.init(
        context.allocator,
        query.QueryType.select,
        "default",
    ) catch {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    defer query_obj.deinit();
    executor.execute_select(&query_obj) catch {
        res.status = HttpStatus.internal_server_error;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Query execution failed", res.body) catch {};
        return;
    };
    res.status = HttpStatus.ok;
    _ = res.add_header("Content-Type", "application/json");
    var serializer = api.JsonSerializer.init(context.allocator);
    _ = serializer.serialize_error("Query executed (results not yet serialized)", res.body) catch {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    res.body_len = 50;
}

// Parse node ID from path.
fn parse_node_id(path: []const u8) ?u64 {
    std.debug.assert(path.len > 0);
    const pattern = "/api/v1/graph/nodes/{id}";
    const param = extract_path_param(pattern, path) orelse return null;
    var id: u64 = 0;
    var i: u32 = 0;
    while (i < param.len) : (i += 1) {
        if (param[i] >= '0' and param[i] <= '9') {
            id = id * 10 + @as(u64, param[i] - '0');
        } else {
            return null;
        }
    }
    return if (id > 0) id else null;
}

// Handler: Get graph node by ID.
pub fn handle_get_node(req: *HttpRequest, res: *HttpResponse) void {
    std.debug.assert(req != null);
    std.debug.assert(res != null);
    const context = get_database_context() orelse {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    const path = req.path[0..req.path_len];
    const node_id = parse_node_id(path) orelse {
        res.status = HttpStatus.bad_request;
        return;
    };
    const node = context.graph_db.get_node(node_id);
    if (node) |n| {
        res.status = HttpStatus.ok;
        _ = res.add_header("Content-Type", "application/json");
        var stream = std.io.fixedBufferStream(res.body);
        const writer = stream.writer();
        writer.print(
            "{{\"id\":{},\"type\":\"{}\",\"properties\":\"{}\"}}",
            .{ n.node_id, n.node_type[0..n.node_type_len], n.properties[0..n.properties_len] },
        ) catch {
            res.status = HttpStatus.internal_server_error;
            return;
        };
        res.body_len = @as(u32, @intCast(stream.getPos()));
    } else {
        res.status = HttpStatus.not_found;
        var serializer = api.JsonSerializer.init(context.allocator);
        const error_len = serializer.serialize_error("Node not found", res.body) catch {
            res.status = HttpStatus.internal_server_error;
            return;
        };
        res.body_len = error_len;
    }
}

// Parse traversal parameters from JSON body (simplified: expects {"start_node_id": 123}).
fn parse_traversal_body(body: []const u8) ?u64 {
    std.debug.assert(body.len <= 65536);
    var i: u32 = 0;
    while (i + 14 < body.len) : (i += 1) {
        if (std.mem.eql(u8, body[i..i + 15], "\"start_node_id\"")) {
            i += 15;
            while (i < body.len and (body[i] == ' ' or body[i] == ':')) : (i += 1) {}
            var node_id: u64 = 0;
            while (i < body.len and body[i] >= '0' and body[i] <= '9') : (i += 1) {
                node_id = node_id * 10 + @as(u64, body[i] - '0');
            }
            return if (node_id > 0) node_id else null;
        }
    }
    return null;
}

// Handler: Traverse graph from node.
pub fn handle_traverse_graph(req: *HttpRequest, res: *HttpResponse) void {
    std.debug.assert(req != null);
    std.debug.assert(res != null);
    const context = get_database_context() orelse {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    const body = req.body[0..req.body_len];
    if (body.len == 0) {
        res.status = HttpStatus.bad_request;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Missing traversal parameters", res.body) catch {};
        return;
    }
    const start_node_id = parse_traversal_body(body) orelse {
        res.status = HttpStatus.bad_request;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Invalid traversal parameters", res.body) catch {};
        return;
    };
    var visited: [graph.MAX_NODES]bool = undefined;
    var node_count: u32 = 0;
    const visitor = struct {
        fn visit(node_id: u64) void {
            _ = node_id;
            node_count += 1;
        }
    }.visit;
    context.graph_db.traverse_bfs(start_node_id, visitor, &visited) catch {
        res.status = HttpStatus.internal_server_error;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Graph traversal failed", res.body) catch {};
        return;
    };
    res.status = HttpStatus.ok;
    _ = res.add_header("Content-Type", "application/json");
    var stream = std.io.fixedBufferStream(res.body);
    const writer = stream.writer();
    writer.print("{{\"nodes_visited\":{}}}", .{node_count}) catch {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    res.body_len = @as(u32, @intCast(stream.getPos()));
}

// Handler: Full-text search.
pub fn handle_fulltext_search(req: *HttpRequest, res: *HttpResponse) void {
    std.debug.assert(req != null);
    std.debug.assert(res != null);
    const context = get_database_context() orelse {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    const search_query = req.query[0..req.query_len];
    if (search_query.len == 0) {
        res.status = HttpStatus.bad_request;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Missing search query", res.body) catch {};
        return;
    }
    if (search_query.len > 10000) {
        res.status = HttpStatus.bad_request;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Search query too long", res.body) catch {};
        return;
    }
    var results: [index.MAX_DOCS_PER_TOKEN]u64 = undefined;
    const result_count = context.fulltext_index.search(search_query, &results) catch {
        res.status = HttpStatus.internal_server_error;
        var serializer = api.JsonSerializer.init(context.allocator);
        _ = serializer.serialize_error("Search failed", res.body) catch {};
        return;
    };
    res.status = HttpStatus.ok;
    _ = res.add_header("Content-Type", "application/json");
    var stream = std.io.fixedBufferStream(res.body);
    const writer = stream.writer();
    writer.print("{{\"results\":[", .{}) catch {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    var i: u32 = 0;
    while (i < result_count) : (i += 1) {
        if (i > 0) {
            writer.print(",", .{}) catch {
                res.status = HttpStatus.internal_server_error;
                return;
            };
        }
        writer.print("{}", .{results[i]}) catch {
            res.status = HttpStatus.internal_server_error;
            return;
        };
    }
    writer.print("],\"count\":{}}}", .{result_count}) catch {
        res.status = HttpStatus.internal_server_error;
        return;
    };
    res.body_len = @as(u32, @intCast(stream.getPos()));
}

