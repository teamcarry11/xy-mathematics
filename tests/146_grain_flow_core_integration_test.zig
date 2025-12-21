//! Integration tests for Grain Flow Agent → Grain Core Agent integration.
//!
//! Why: Verify Flow Agent's integration with Core services (API Server, Auth, WebSocket).
//! Architecture: Test Flow → Core integration points (Dashboard API, Event Bus, Agent Coordinator).
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-094300-pst: Phase 64 Integration Tests

const std = @import("std");
const grain_flow = @import("grain_flow");
const grain_core = @import("grain_core");

// Test: Dashboard API endpoint registration with Core API Server.
test "flow dashboard api register endpoints" {
    var api_server = grain_core.api_server.ApiServer.init(8080);
    const count = grain_flow.register_dashboard_endpoints(&api_server);
    std.debug.assert(count == 3); // dashboard, summary, metrics
    std.debug.assert(api_server.get_route_count() == 3);
}

// Test: Dashboard API endpoint registration finds routes.
test "flow dashboard api find registered routes" {
    var api_server = grain_core.api_server.ApiServer.init(8080);
    _ = grain_flow.register_dashboard_endpoints(&api_server);
    
    // Find dashboard route.
    const dashboard_route = api_server.find_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/dashboard",
    );
    std.debug.assert(dashboard_route != null);
    if (dashboard_route) |r| {
        std.debug.assert(r.active);
    }
    
    // Find summary route.
    const summary_route = api_server.find_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/summary",
    );
    std.debug.assert(summary_route != null);
    if (summary_route) |r| {
        std.debug.assert(r.active);
    }
    
    // Find metrics route.
    const metrics_route = api_server.find_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/metrics",
    );
    std.debug.assert(metrics_route != null);
    if (metrics_route) |r| {
        std.debug.assert(r.active);
    }
}

// Test: Dashboard API request handling (dashboard HTML).
test "flow dashboard api handle dashboard request" {
    var api_server = grain_core.api_server.ApiServer.init(8080);
    _ = grain_flow.register_dashboard_endpoints(&api_server);
    
    // Create request.
    var request = grain_core.api_server.HttpRequest.init();
    request.method = grain_core.api_server.HttpMethod.get;
    request.path_len = 35; // "/api/workflow-observatory/dashboard"
    var i: u32 = 0;
    const path = "/api/workflow-observatory/dashboard";
    while (i < path.len) : (i += 1) {
        request.path[i] = path[i];
    }
    
    // Create response.
    var response = grain_core.api_server.HttpResponse.init();
    
    // Find and call handler.
    const route = api_server.find_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/dashboard",
    );
    std.debug.assert(route != null);
    if (route) |r| {
        if (r.handler) |handler| {
            handler(&request, &response);
            std.debug.assert(response.status == grain_core.api_server.HttpStatus.ok);
            std.debug.assert(response.body_len > 0);
        }
    }
}

// Test: Dashboard API request handling (summary JSON).
test "flow dashboard api handle summary request" {
    var api_server = grain_core.api_server.ApiServer.init(8080);
    _ = grain_flow.register_dashboard_endpoints(&api_server);
    
    // Create request.
    var request = grain_core.api_server.HttpRequest.init();
    request.method = grain_core.api_server.HttpMethod.get;
    request.path_len = 33; // "/api/workflow-observatory/summary"
    var i: u32 = 0;
    const path = "/api/workflow-observatory/summary";
    while (i < path.len) : (i += 1) {
        request.path[i] = path[i];
    }
    
    // Create response.
    var response = grain_core.api_server.HttpResponse.init();
    
    // Find and call handler.
    const route = api_server.find_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/summary",
    );
    std.debug.assert(route != null);
    if (route) |r| {
        if (r.handler) |handler| {
            handler(&request, &response);
            // Should return service_unavailable if observatory not set.
            std.debug.assert(response.status == grain_core.api_server.HttpStatus.service_unavailable);
        }
    }
}

// Test: Dashboard API request handling (summary JSON with observatory).
test "flow dashboard api handle summary request with observatory" {
    // Initialize observatory.
    var observatory = grain_flow.WorkflowObservatory.init();
    
    // Set dashboard context.
    grain_flow.set_dashboard_context(&observatory);
    
    // Register endpoints.
    var api_server = grain_core.api_server.ApiServer.init(8080);
    _ = grain_flow.register_dashboard_endpoints(&api_server);
    
    // Create request.
    var request = grain_core.api_server.HttpRequest.init();
    request.method = grain_core.api_server.HttpMethod.get;
    request.path_len = 33; // "/api/workflow-observatory/summary"
    var i: u32 = 0;
    const path = "/api/workflow-observatory/summary";
    while (i < path.len) : (i += 1) {
        request.path[i] = path[i];
    }
    
    // Create response.
    var response = grain_core.api_server.HttpResponse.init();
    
    // Find and call handler.
    const route = api_server.find_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/summary",
    );
    std.debug.assert(route != null);
    if (route) |r| {
        if (r.handler) |handler| {
            handler(&request, &response);
            // Should return ok with JSON summary.
            std.debug.assert(response.status == grain_core.api_server.HttpStatus.ok);
            std.debug.assert(response.body_len > 0);
        }
    }
}

// Test: Dashboard API request handling (metrics JSON).
test "flow dashboard api handle metrics request" {
    var api_server = grain_core.api_server.ApiServer.init(8080);
    _ = grain_flow.register_dashboard_endpoints(&api_server);
    
    // Create request.
    var request = grain_core.api_server.HttpRequest.init();
    request.method = grain_core.api_server.HttpMethod.get;
    request.path_len = 32; // "/api/workflow-observatory/metrics"
    var i: u32 = 0;
    const path = "/api/workflow-observatory/metrics";
    while (i < path.len) : (i += 1) {
        request.path[i] = path[i];
    }
    
    // Create response.
    var response = grain_core.api_server.HttpResponse.init();
    
    // Find and call handler.
    const route = api_server.find_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/metrics",
    );
    std.debug.assert(route != null);
    if (route) |r| {
        if (r.handler) |handler| {
            handler(&request, &response);
            // Should return service_unavailable if observatory not set.
            std.debug.assert(response.status == grain_core.api_server.HttpStatus.service_unavailable);
        }
    }
}

// Test: Dashboard API request handling (metrics JSON with observatory).
test "flow dashboard api handle metrics request with observatory" {
    // Initialize observatory.
    var observatory = grain_flow.WorkflowObservatory.init();
    
    // Set dashboard context.
    grain_flow.set_dashboard_context(&observatory);
    
    // Register endpoints.
    var api_server = grain_core.api_server.ApiServer.init(8080);
    _ = grain_flow.register_dashboard_endpoints(&api_server);
    
    // Create request.
    var request = grain_core.api_server.HttpRequest.init();
    request.method = grain_core.api_server.HttpMethod.get;
    request.path_len = 32; // "/api/workflow-observatory/metrics"
    var i: u32 = 0;
    const path = "/api/workflow-observatory/metrics";
    while (i < path.len) : (i += 1) {
        request.path[i] = path[i];
    }
    
    // Create response.
    var response = grain_core.api_server.HttpResponse.init();
    
    // Find and call handler.
    const route = api_server.find_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/metrics",
    );
    std.debug.assert(route != null);
    if (route) |r| {
        if (r.handler) |handler| {
            handler(&request, &response);
            // Should return ok with JSON metrics.
            std.debug.assert(response.status == grain_core.api_server.HttpStatus.ok);
            std.debug.assert(response.body_len > 0);
        }
    }
}

// Test: Dashboard API integration with Core API Server start/stop.
test "flow dashboard api with core api server lifecycle" {
    var api_server = grain_core.api_server.ApiServer.init(8080);
    _ = grain_flow.register_dashboard_endpoints(&api_server);
    
    // Start server.
    const started = api_server.start();
    std.debug.assert(started);
    std.debug.assert(api_server.is_running());
    
    // Stop server.
    api_server.stop();
    std.debug.assert(!api_server.is_running());
}

// Test: Event Bus integration pattern (future Core WebSocket integration).
test "flow event bus integration pattern" {
    // Initialize event bus.
    var event_bus = grain_flow.EventBus.init();
    
    // Publish event (standalone, future: via Core WebSocket).
    const timestamp: u64 = 1000;
    const published = event_bus.publish_event(
        grain_flow.EventType.workflow_started,
        1, // source_agent_id
        0, // destination_agent_id (broadcast)
        timestamp,
    );
    std.debug.assert(published);
    
    // Process events (standalone, future: via Core WebSocket).
    event_bus.process_events();
}

// Test: Agent Coordinator integration pattern (future Core Auth integration).
test "flow agent coordinator integration pattern" {
    // Initialize event bus.
    var event_bus = grain_flow.EventBus.init();
    
    // Initialize coordinator (requires event bus).
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    
    // Register agent (standalone, future: with Core Auth).
    const timestamp: u64 = 1000;
    const agent_id_opt = coordinator.register_agent("test_agent", timestamp);
    std.debug.assert(agent_id_opt != null);
    if (agent_id_opt) |agent_id| {
        std.debug.assert(agent_id > 0);
        
        // Find agent (standalone, future: with Core Auth verification).
        const agent = coordinator.find_agent(agent_id);
        std.debug.assert(agent != null);
        if (agent) |a| {
            std.debug.assert(a.status == grain_flow.AgentStatus.active);
        }
    }
}

// Test: Workflow Engine integration pattern (uses Core services indirectly).
test "flow workflow engine integration pattern" {
    // Initialize event bus.
    var event_bus = grain_flow.EventBus.init();
    
    // Initialize coordinator.
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    
    // Initialize engine (requires event bus and coordinator).
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    
    // Create workflow (uses Core services indirectly).
    const timestamp: u64 = 1000;
    const workflow_id = engine.create_workflow("test_workflow", timestamp);
    std.debug.assert(workflow_id > 0);
    
    // Get workflow.
    const workflow = engine.get_workflow(workflow_id);
    std.debug.assert(workflow != null);
    if (workflow) |w| {
        std.debug.assert(w.status == grain_flow.WorkflowStatus.pending);
    }
}

// Test: Multiple Flow endpoints registered with Core API Server.
test "flow multiple endpoints with core api server" {
    var api_server = grain_core.api_server.ApiServer.init(8080);
    
    // Register Flow endpoints.
    const flow_count = grain_flow.register_dashboard_endpoints(&api_server);
    std.debug.assert(flow_count == 3);
    
    // Register additional Core route (simulate other agent).
    const handler: grain_core.api_server.RouteHandler = &test_handler;
    const core_registered = api_server.register_route(
        grain_core.api_server.HttpMethod.get,
        "/api/core/test",
        handler,
    );
    std.debug.assert(core_registered);
    
    // Verify all routes registered.
    std.debug.assert(api_server.get_route_count() == 4);
    
    // Verify Flow routes still accessible.
    const dashboard_route = api_server.find_route(
        grain_core.api_server.HttpMethod.get,
        "/api/workflow-observatory/dashboard",
    );
    std.debug.assert(dashboard_route != null);
}

// Test handler for integration tests.
fn test_handler(
    _req: *grain_core.api_server.HttpRequest,
    res: *grain_core.api_server.HttpResponse,
) void {
    _ = _req;
    res.status = grain_core.api_server.HttpStatus.ok;
    _ = res.add_header("Content-Type", "application/json");
    const body = "{\"status\":\"ok\"}";
    var i: u32 = 0;
    while (i < body.len and i < res.body.len) : (i += 1) {
        res.body[i] = body[i];
    }
    res.body_len = @intCast(body.len);
}
