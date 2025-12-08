//! Grain Database Integration: API Server integration interfaces.
//!
//! Why: Prepare database for integration with Grain OS API Server (Phase 59).
//! Architecture: Integration interfaces, endpoint contracts, helper functions.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-104041-pst: Grain Database Agent
//!
//! Note: This module prepares for integration with Grain OS Agent's API Server.

const std = @import("std");
const api = @import("api.zig");
const storage_engine = @import("storage_engine.zig");
const relational = @import("relational.zig");
const graph = @import("graph.zig");
const index = @import("index.zig");

// Bounded: Max endpoint definitions.
pub const MAX_ENDPOINTS: u32 = 64;

// Bounded: Max path parameters per endpoint.
pub const MAX_PATH_PARAMS: u32 = 8;

// Database endpoint definition.
pub const DatabaseEndpoint = struct {
    method: api.HttpMethod,
    path: []const u8,
    path_len: u32,
    handler: EndpointHandler,
    requires_auth: bool,
    allocator: std.mem.Allocator,

    pub const EndpointHandler = *const fn (
        request: *api.ApiRequest,
        response: *api.ApiResponse,
        context: *api.ApiContext,
    ) void;

    // Initialize endpoint.
    pub fn init(
        allocator: std.mem.Allocator,
        method: api.HttpMethod,
        path: []const u8,
        handler: EndpointHandler,
        requires_auth: bool,
    ) !DatabaseEndpoint {
        std.debug.assert(path.len <= 512);
        const path_copy = try allocator.dupe(u8, path);
        errdefer allocator.free(path_copy);

        return DatabaseEndpoint{
            .method = method,
            .path = path_copy,
            .path_len = @as(u32, @intCast(path_copy.len)),
            .handler = handler,
            .requires_auth = requires_auth,
            .allocator = allocator,
        };
    }

    // Deinitialize endpoint and free memory.
    pub fn deinit(self: *DatabaseEndpoint) void {
        if (self.path_len > 0) {
            self.allocator.free(self.path);
        }
        self.* = undefined;
    }
};

// Endpoint registry: Manages database endpoints.
pub const EndpointRegistry = struct {
    endpoints: []DatabaseEndpoint,
    endpoints_len: u32,
    allocator: std.mem.Allocator,

    // Initialize endpoint registry.
    pub fn init(allocator: std.mem.Allocator) !EndpointRegistry {
        const endpoints = try allocator.alloc(
            DatabaseEndpoint,
            MAX_ENDPOINTS,
        );
        errdefer allocator.free(endpoints);

        return EndpointRegistry{
            .endpoints = endpoints,
            .endpoints_len = 0,
            .allocator = allocator,
        };
    }

    // Deinitialize registry and free memory.
    pub fn deinit(self: *EndpointRegistry) void {
        var i: u32 = 0;
        while (i < self.endpoints_len) : (i += 1) {
            self.endpoints[i].deinit();
        }
        self.allocator.free(self.endpoints);
        self.* = undefined;
    }

    // Register endpoint.
    pub fn register_endpoint(
        self: *EndpointRegistry,
        method: api.HttpMethod,
        path: []const u8,
        handler: DatabaseEndpoint.EndpointHandler,
        requires_auth: bool,
    ) !void {
        std.debug.assert(self.endpoints_len < MAX_ENDPOINTS);

        if (self.endpoints_len >= MAX_ENDPOINTS) {
            return error.TooManyEndpoints;
        }

        var endpoint = try DatabaseEndpoint.init(
            self.allocator,
            method,
            path,
            handler,
            requires_auth,
        );
        errdefer endpoint.deinit();

        self.endpoints[self.endpoints_len] = endpoint;
        self.endpoints_len += 1;

        std.debug.assert(self.endpoints_len <= MAX_ENDPOINTS);
    }

    // Get endpoint by method and path.
    pub fn get_endpoint(
        self: *EndpointRegistry,
        method: api.HttpMethod,
        path: []const u8,
    ) ?*DatabaseEndpoint {
        std.debug.assert(path.len <= 1024);
        var i: u32 = 0;
        while (i < self.endpoints_len) : (i += 1) {
            if (self.endpoints[i].method == method) {
                if (std.mem.eql(u8, self.endpoints[i].path, path)) {
                    return &self.endpoints[i];
                }
            }
        }
        return null;
    }
};

// Register all database endpoints.
pub fn register_database_endpoints(
    registry: *EndpointRegistry,
    context: *api.ApiContext,
) !void {
    _ = context;
    std.debug.assert(registry != null);

    // Key-value endpoints.
    try registry.register_endpoint(
        api.HttpMethod.get,
        "/api/v1/records/{id}",
        handle_get_record,
        false,
    );

    try registry.register_endpoint(
        api.HttpMethod.post,
        "/api/v1/records",
        handle_create_record,
        true,
    );

    try registry.register_endpoint(
        api.HttpMethod.put,
        "/api/v1/records/{id}",
        handle_update_record,
        true,
    );

    try registry.register_endpoint(
        api.HttpMethod.delete,
        "/api/v1/records/{id}",
        handle_delete_record,
        true,
    );

    // Relational endpoints.
    try registry.register_endpoint(
        api.HttpMethod.get,
        "/api/v1/tables",
        handle_list_tables,
        false,
    );

    try registry.register_endpoint(
        api.HttpMethod.post,
        "/api/v1/query",
        handle_execute_query,
        true,
    );

    // Graph endpoints.
    try registry.register_endpoint(
        api.HttpMethod.get,
        "/api/v1/graph/nodes/{id}",
        handle_get_node,
        false,
    );

    try registry.register_endpoint(
        api.HttpMethod.post,
        "/api/v1/graph/traverse",
        handle_traverse_graph,
        true,
    );

    // Full-text search endpoints.
    try registry.register_endpoint(
        api.HttpMethod.get,
        "/api/v1/search",
        handle_fulltext_search,
        false,
    );

    std.debug.assert(registry.endpoints_len > 0);
}

// Handler: Get record by ID.
fn handle_get_record(
    request: *api.ApiRequest,
    response: *api.ApiResponse,
    context: *api.ApiContext,
) void {
    _ = request;
    _ = response;
    _ = context;
    // TODO: Implement when API Server is available.
}

// Handler: Create new record.
fn handle_create_record(
    request: *api.ApiRequest,
    response: *api.ApiResponse,
    context: *api.ApiContext,
) void {
    _ = request;
    _ = response;
    _ = context;
    // TODO: Implement when API Server is available.
}

// Handler: Update existing record.
fn handle_update_record(
    request: *api.ApiRequest,
    response: *api.ApiResponse,
    context: *api.ApiContext,
) void {
    _ = request;
    _ = response;
    _ = context;
    // TODO: Implement when API Server is available.
}

// Handler: Delete record by ID.
fn handle_delete_record(
    request: *api.ApiRequest,
    response: *api.ApiResponse,
    context: *api.ApiContext,
) void {
    _ = request;
    _ = response;
    _ = context;
    // TODO: Implement when API Server is available.
}

// Handler: List all tables.
fn handle_list_tables(
    request: *api.ApiRequest,
    response: *api.ApiResponse,
    context: *api.ApiContext,
) void {
    _ = request;
    _ = response;
    _ = context;
    // TODO: Implement when API Server is available.
}

// Handler: Execute SQL-like query.
fn handle_execute_query(
    request: *api.ApiRequest,
    response: *api.ApiResponse,
    context: *api.ApiContext,
) void {
    _ = request;
    _ = response;
    _ = context;
    // TODO: Implement when API Server is available.
}

// Handler: Get graph node by ID.
fn handle_get_node(
    request: *api.ApiRequest,
    response: *api.ApiResponse,
    context: *api.ApiContext,
) void {
    _ = request;
    _ = response;
    _ = context;
    // TODO: Implement when API Server is available.
}

// Handler: Traverse graph from node.
fn handle_traverse_graph(
    request: *api.ApiRequest,
    response: *api.ApiResponse,
    context: *api.ApiContext,
) void {
    _ = request;
    _ = response;
    _ = context;
    // TODO: Implement when API Server is available.
}

// Handler: Full-text search.
fn handle_fulltext_search(
    request: *api.ApiRequest,
    response: *api.ApiResponse,
    context: *api.ApiContext,
) void {
    _ = request;
    _ = response;
    _ = context;
    // TODO: Implement when API Server is available.
}

// API contract: Request/response format definitions.
pub const ApiContract = struct {
    // Record response format.
    pub const RecordResponse = struct {
        id: u64,
        key: []const u8,
        value: []const u8,
    };

    // Error response format.
    pub const ErrorResponse = struct {
        error_message: []const u8,
        code: u16,
    };

    // Query request format.
    pub const QueryRequest = struct {
        query: []const u8,
        params: []const []const u8,
    };

    // Query response format.
    pub const QueryResponse = struct {
        rows: []const []const []const u8,
        columns: []const []const u8,
    };
};

