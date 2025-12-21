//! Grain Flow Dashboard API: HTTP endpoints for Workflow Observatory.
//!
//! Why: Provides HTTP API endpoints for dashboard visualization of workflow metrics.
//! Integrates with Core Agent's API Server to expose observatory data.
//!
//! Architecture: API endpoint handlers, JSON response generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-084005-pst: Phase 3 Workflow Observatory Dashboard API

const std = @import("std");
const workflow_observatory = @import("workflow_observatory.zig");
const grain_core = @import("grain_core");

// Bounded: Max JSON response size (10MB).
pub const MAX_JSON_RESPONSE_SIZE: u32 = 10_485_760;

// Bounded: Max path length.
pub const MAX_PATH_LEN: u32 = 256;

// Dashboard API context: holds observatory instance.
pub const DashboardApiContext = struct {
    observatory: ?*workflow_observatory.WorkflowObservatory,

    pub fn init() DashboardApiContext {
        return DashboardApiContext{
            .observatory = null,
        };
    }

    /// Set observatory instance.
    pub fn set_observatory(
        self: *DashboardApiContext,
        obs: *workflow_observatory.WorkflowObservatory,
    ) void {
        std.debug.assert(obs != null);
        self.observatory = obs;
    }
};

// Global context (for handler functions).
var dashboard_context: DashboardApiContext = DashboardApiContext.init();

/// Set dashboard context observatory.
pub fn set_dashboard_context(obs: *workflow_observatory.WorkflowObservatory) void {
    dashboard_context.set_observatory(obs);
}

/// Handle GET /api/workflow-observatory/summary request.
pub fn handle_summary_request(
    request: *grain_core.api_server.HttpRequest,
    response: *grain_core.api_server.HttpResponse,
) void {
    _ = request;
    std.debug.assert(request != null);
    std.debug.assert(response != null);

    // Set response headers.
    _ = response.add_header("Content-Type", "application/json");
    _ = response.add_header("Access-Control-Allow-Origin", "*");

    // Check if observatory is available.
    if (dashboard_context.observatory) |obs| {
        // Generate aggregated summary JSON.
        var json_buffer: [MAX_JSON_RESPONSE_SIZE]u8 = undefined;
        const written = obs.get_aggregated_summary(&json_buffer);
        if (written > 0 and written < json_buffer.len) {
            // Set response body.
            const body_len = @min(written, MAX_JSON_RESPONSE_SIZE);
            var i: u32 = 0;
            while (i < body_len and i < response.body.len) : (i += 1) {
                response.body[i] = json_buffer[i];
            }
            response.body_len = body_len;
            response.status = grain_core.api_server.HttpStatus.ok;
        } else {
            // Error: buffer overflow or empty.
            response.status = grain_core.api_server.HttpStatus.internal_server_error;
            const error_msg = "{\"error\":\"Failed to generate summary\"}";
            const msg_len = @min(error_msg.len, response.body.len);
            var j: u32 = 0;
            while (j < msg_len) : (j += 1) {
                response.body[j] = error_msg[j];
            }
            response.body_len = msg_len;
        }
    } else {
        // Observatory not available.
        response.status = grain_core.api_server.HttpStatus.service_unavailable;
        const error_msg = "{\"error\":\"Observatory not available\"}";
        const msg_len = @min(error_msg.len, response.body.len);
        var i: u32 = 0;
        while (i < msg_len) : (i += 1) {
            response.body[i] = error_msg[i];
        }
        response.body_len = msg_len;
    }
}

/// Handle GET /api/workflow-observatory/metrics request.
pub fn handle_metrics_request(
    request: *grain_core.api_server.HttpRequest,
    response: *grain_core.api_server.HttpResponse,
) void {
    _ = request;
    std.debug.assert(request != null);
    std.debug.assert(response != null);

    // Set response headers.
    _ = response.add_header("Content-Type", "application/json");
    _ = response.add_header("Access-Control-Allow-Origin", "*");

    // Check if observatory is available.
    if (dashboard_context.observatory) |obs| {
        // Generate full metrics JSON.
        var json_buffer: [MAX_JSON_RESPONSE_SIZE]u8 = undefined;
        const written = obs.export_all_metrics_json(&json_buffer);
        if (written > 0 and written < json_buffer.len) {
            // Set response body.
            const body_len = @min(written, MAX_JSON_RESPONSE_SIZE);
            var i: u32 = 0;
            while (i < body_len and i < response.body.len) : (i += 1) {
                response.body[i] = json_buffer[i];
            }
            response.body_len = body_len;
            response.status = grain_core.api_server.HttpStatus.ok;
        } else {
            // Error: buffer overflow or empty.
            response.status = grain_core.api_server.HttpStatus.internal_server_error;
            const error_msg = "{\"error\":\"Failed to export metrics\"}";
            const msg_len = @min(error_msg.len, response.body.len);
            i = 0;
            while (i < msg_len) : (i += 1) {
                response.body[i] = error_msg[i];
            }
            response.body_len = msg_len;
        }
    } else {
        // Observatory not available.
        response.status = grain_core.api_server.HttpStatus.service_unavailable;
        const error_msg = "{\"error\":\"Observatory not available\"}";
        const msg_len = @min(error_msg.len, response.body.len);
        var i: u32 = 0;
        while (i < msg_len) : (i += 1) {
            response.body[i] = error_msg[i];
        }
        response.body_len = msg_len;
    }
}

/// Register dashboard API endpoints with Core API Server.
pub fn register_dashboard_endpoints(
    api_server: *grain_core.api_server.ApiServer,
) u32 {
    std.debug.assert(api_server != null);
    var count: u32 = 0;

    // Register summary endpoint.
    if (api_server.register_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/summary",
        handle_summary_request,
    )) {
        count += 1;
    }

    // Register metrics endpoint.
    if (api_server.register_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/metrics",
        handle_metrics_request,
    )) {
        count += 1;
    }

    return count;
}
