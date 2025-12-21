//! Grain Flow Dashboard API Tests
//!
//! Tests for dashboard API endpoint handlers and registration.

const std = @import("std");
const grain_flow = @import("grain_flow");
const grain_core = @import("grain_core");

test "dashboard api context initialization" {
    const context = grain_flow.DashboardApiContext.init();
    std.debug.assert(context.observatory == null);
}

test "dashboard api context set observatory" {
    var context = grain_flow.DashboardApiContext.init();
    var observatory = grain_flow.WorkflowObservatory.init();
    context.set_observatory(&observatory);
    std.debug.assert(context.observatory != null);
}

test "dashboard api set context" {
    var observatory = grain_flow.WorkflowObservatory.init();
    grain_flow.set_dashboard_context(&observatory);
    // Context should be set (no way to verify without exposing internals).
}

test "dashboard api register endpoints" {
    var api_server = grain_core.api_server.ApiServer.init(8080);
    const count = grain_flow.register_dashboard_endpoints(&api_server);
    std.debug.assert(count == 2); // Summary and metrics endpoints.
}

test "dashboard api summary request handler" {
    var observatory = grain_flow.WorkflowObservatory.init();
    var workflow_collector = grain_flow.WorkflowMetricsCollector.init();
    observatory.set_workflow_collector(&workflow_collector);

    // Record test data.
    _ = workflow_collector.record_execution(
        1,
        "test_workflow",
        1000,
        2000,
        grain_flow.WorkflowExecutionStatus.success,
    );

    // Set context.
    grain_flow.set_dashboard_context(&observatory);

    // Create mock request and response.
    var request = grain_core.api_server.HttpRequest.init();
    var response = grain_core.api_server.HttpResponse.init();

    // Call handler.
    grain_flow.handle_summary_request(&request, &response);

    // Verify response.
    std.debug.assert(response.status == grain_core.api_server.HttpStatus.ok);
    std.debug.assert(response.body_len > 0);
}

test "dashboard api metrics request handler" {
    var observatory = grain_flow.WorkflowObservatory.init();
    var workflow_collector = grain_flow.WorkflowMetricsCollector.init();
    observatory.set_workflow_collector(&workflow_collector);

    // Record test data.
    _ = workflow_collector.record_execution(
        1,
        "test_workflow",
        1000,
        2000,
        grain_flow.WorkflowExecutionStatus.success,
    );

    // Set context.
    grain_flow.set_dashboard_context(&observatory);

    // Create mock request and response.
    var request = grain_core.api_server.HttpRequest.init();
    var response = grain_core.api_server.HttpResponse.init();

    // Call handler.
    grain_flow.handle_metrics_request(&request, &response);

    // Verify response.
    std.debug.assert(response.status == grain_core.api_server.HttpStatus.ok);
    std.debug.assert(response.body_len > 0);
}

test "dashboard api handler without observatory" {
    // Reset context (observatory not set).
    var empty_context = grain_flow.DashboardApiContext.init();
    // Note: We can't directly reset the global context, but we can test
    // the handler behavior when observatory is null by not setting it.

    // Create mock request and response.
    var request = grain_core.api_server.HttpRequest.init();
    var response = grain_core.api_server.HttpResponse.init();

    // Call handler (should handle gracefully).
    grain_flow.handle_summary_request(&request, &response);
    // Should return service unavailable or handle gracefully.
    _ = empty_context; // Suppress unused warning.
}
