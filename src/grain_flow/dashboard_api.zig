//! Grain Flow Dashboard API: HTTP endpoints for Workflow Observatory.
//!
//! Why: Provides HTTP API endpoints for dashboard visualization of workflow metrics.
//! Integrates with Core Agent's API Server to expose observatory data.
//!
//! Architecture: API endpoint handlers, JSON response generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-084005-pst: Phase 3 Workflow Observatory Dashboard API
//! 2025-12-28-175000-pst: ZON Format Support Added (format query parameter)

const std = @import("std");
const workflow_observatory = @import("workflow_observatory.zig");
const grain_core = @import("grain_core");

// Bounded: Max JSON response size (10MB).
pub const MAX_JSON_RESPONSE_SIZE: u32 = 10_485_760;

// Bounded: Max ZON response size (10MB).
pub const MAX_ZON_RESPONSE_SIZE: u32 = 10_485_760;

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
        std.debug.assert(obs != undefined);
        self.observatory = obs;
    }
};

// Global context (for handler functions).
var dashboard_context: DashboardApiContext = DashboardApiContext.init();

/// Set dashboard context observatory.
pub fn set_dashboard_context(obs: *workflow_observatory.WorkflowObservatory) void {
    dashboard_context.set_observatory(obs);
}

// Parse query parameter value from query string.
fn get_query_param(query: []const u8, param_name: []const u8) ?[]const u8 {
    std.debug.assert(param_name.len > 0);
    if (query.len == 0) {
        return null;
    }
    var i: u32 = 0;
    while (i < query.len) : (i += 1) {
        // Check if this is the parameter we're looking for.
        if (i + param_name.len < query.len and query[i + param_name.len] == '=') {
            var match: bool = true;
            var j: u32 = 0;
            while (j < param_name.len) : (j += 1) {
                if (query[i + j] != param_name[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                // Found parameter, extract value.
                const value_start = i + param_name.len + 1;
                var value_end = value_start;
                while (value_end < query.len and query[value_end] != '&') : (value_end += 1) {}
                return query[value_start..value_end];
            }
        }
        // Skip to next parameter (after '&').
        while (i < query.len and query[i] != '&') : (i += 1) {}
    }
    return null;
}

/// Handle GET /api/workflow-observatory/summary request.
pub fn handle_summary_request(
    request: *grain_core.api_server.HttpRequest,
    response: *grain_core.api_server.HttpResponse,
) void {
    std.debug.assert(request != undefined);
    std.debug.assert(response != undefined);

    // Parse format parameter from query string.
    const query_str = request.query[0..request.query_len];
    const format_param = get_query_param(query_str, "format");
    const use_zon = format_param != null and std.mem.eql(u8, format_param.?, "zon");

    // Set response headers based on format.
    if (use_zon) {
        _ = response.add_header("Content-Type", "text/plain; charset=utf-8");
    } else {
        _ = response.add_header("Content-Type", "application/json");
    }
    _ = response.add_header("Access-Control-Allow-Origin", "*");

    // Check if observatory is available.
    if (dashboard_context.observatory) |obs| {
        if (use_zon) {
            // Generate aggregated summary ZON.
            var zon_buffer: [MAX_ZON_RESPONSE_SIZE]u8 = undefined;
            const written = obs.get_aggregated_summary_zon(&zon_buffer);
            if (written > 0 and written < zon_buffer.len) {
                const body_len = @min(written, MAX_ZON_RESPONSE_SIZE);
                var i: u32 = 0;
                while (i < body_len and i < response.body.len) : (i += 1) {
                    response.body[i] = zon_buffer[i];
                }
                response.body_len = body_len;
                response.status = grain_core.api_server.HttpStatus.ok;
            } else {
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
            // Generate aggregated summary JSON (default).
            var json_buffer: [MAX_JSON_RESPONSE_SIZE]u8 = undefined;
            const written = obs.get_aggregated_summary(&json_buffer);
            if (written > 0 and written < json_buffer.len) {
                const body_len = @min(written, MAX_JSON_RESPONSE_SIZE);
                var i: u32 = 0;
                while (i < body_len and i < response.body.len) : (i += 1) {
                    response.body[i] = json_buffer[i];
                }
                response.body_len = body_len;
                response.status = grain_core.api_server.HttpStatus.ok;
            } else {
                response.status = grain_core.api_server.HttpStatus.internal_server_error;
                const error_msg = "{\"error\":\"Failed to generate summary\"}";
                const msg_len = @min(error_msg.len, response.body.len);
                var j: u32 = 0;
                while (j < msg_len) : (j += 1) {
                    response.body[j] = error_msg[j];
                }
                response.body_len = msg_len;
            }
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
    std.debug.assert(request != null);
    std.debug.assert(response != null);

    // Parse format parameter from query string.
    const query_str = request.query[0..request.query_len];
    const format_param = get_query_param(query_str, "format");
    const use_zon = format_param != null and std.mem.eql(u8, format_param.?, "zon");

    // Set response headers based on format.
    if (use_zon) {
        _ = response.add_header("Content-Type", "text/plain; charset=utf-8");
    } else {
        _ = response.add_header("Content-Type", "application/json");
    }
    _ = response.add_header("Access-Control-Allow-Origin", "*");

    // Check if observatory is available.
    if (dashboard_context.observatory) |obs| {
        if (use_zon) {
            // Generate full metrics ZON.
            var zon_buffer: [MAX_ZON_RESPONSE_SIZE]u8 = undefined;
            const written = obs.export_all_metrics_zon(&zon_buffer);
            if (written > 0 and written < zon_buffer.len) {
                const body_len = @min(written, MAX_ZON_RESPONSE_SIZE);
                var i: u32 = 0;
                while (i < body_len and i < response.body.len) : (i += 1) {
                    response.body[i] = zon_buffer[i];
                }
                response.body_len = body_len;
                response.status = grain_core.api_server.HttpStatus.ok;
            } else {
                response.status = grain_core.api_server.HttpStatus.internal_server_error;
                const error_msg = "{\"error\":\"Failed to export metrics\"}";
                const msg_len = @min(error_msg.len, response.body.len);
                var j: u32 = 0;
                while (j < msg_len) : (j += 1) {
                    response.body[j] = error_msg[j];
                }
                response.body_len = msg_len;
            }
        } else {
            // Generate full metrics JSON (default).
            var json_buffer: [MAX_JSON_RESPONSE_SIZE]u8 = undefined;
            const written = obs.export_all_metrics_json(&json_buffer);
            if (written > 0 and written < json_buffer.len) {
                const body_len = @min(written, MAX_JSON_RESPONSE_SIZE);
                var i: u32 = 0;
                while (i < body_len and i < response.body.len) : (i += 1) {
                    response.body[i] = json_buffer[i];
                }
                response.body_len = body_len;
                response.status = grain_core.api_server.HttpStatus.ok;
            } else {
                response.status = grain_core.api_server.HttpStatus.internal_server_error;
                const error_msg = "{\"error\":\"Failed to export metrics\"}";
                const msg_len = @min(error_msg.len, response.body.len);
                var j: u32 = 0;
                while (j < msg_len) : (j += 1) {
                    response.body[j] = error_msg[j];
                }
                response.body_len = msg_len;
            }
        }
    } else {
        // Observatory not available.
        response.status = grain_core.api_server.HttpStatus.service_unavailable;
        const error_msg = "{\"error\":\"Observatory not available\"}";
        const msg_len = @min(error_msg.len, response.body.len);
        var k: u32 = 0;
        while (k < msg_len) : (k += 1) {
            response.body[k] = error_msg[k];
        }
        response.body_len = msg_len;
    }
}

/// Handle GET /api/workflow-observatory/dashboard request (serve HTML).
pub fn handle_dashboard_request(
    request: *grain_core.api_server.HttpRequest,
    response: *grain_core.api_server.HttpResponse,
) void {
    std.debug.assert(request != undefined);
    std.debug.assert(response != undefined);

    // Set response headers.
    _ = response.add_header("Content-Type", "text/html; charset=utf-8");
    _ = response.add_header("Access-Control-Allow-Origin", "*");

    // Serve dashboard HTML (embedded).
    const dashboard_html = @embedFile("dashboard.html");
    const html_len = @min(dashboard_html.len, response.body.len);
    var i: u32 = 0;
    while (i < html_len) : (i += 1) {
        response.body[i] = dashboard_html[i];
    }
    response.body_len = html_len;
    response.status = grain_core.api_server.HttpStatus.ok;
}

/// Register dashboard API endpoints with Core API Server.
pub fn register_dashboard_endpoints(
    api_server: *grain_core.api_server.ApiServer,
) u32 {
    std.debug.assert(api_server != undefined);
    var count: u32 = 0;

    // Register dashboard HTML endpoint.
    if (api_server.register_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/dashboard",
        handle_dashboard_request,
    )) {
        count += 1;
    }

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
