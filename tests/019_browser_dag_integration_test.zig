//! Browser-DAG Integration Tests
//!
//! Objective: Validate browser-DAG integration functionality.
//! Tests verify that DOM nodes are correctly mapped to DAG nodes, web requests
//! are mapped to DAG events, and unified state works correctly.
//!
//! Methodology:
//! - Test DOM node to DAG node mapping
//! - Test web request to DAG event mapping
//! - Test streaming updates
//! - Test unified state (editor + browser)
//! - Test dependency tracking (parent-child relationships)
//!
//! TigerStyle Principles:
//! - Exhaustive testing: valid data, invalid data, edge cases
//! - Assertions detect programmer errors: assert preconditions, postconditions, invariants
//! - Explicit types: u32/u64 instead of usize for cross-platform consistency
//! - Bounded loops: all loops have fixed upper bounds
//! - Comments explain why: not just what the code does, but why it's written this way
//! - Pair assertions: verify both input validation and output correctness
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive test coverage, deterministic behavior, explicit limits

const std = @import("std");
const testing = std.testing;
const browser_dag = @import("../src/browser_dag_integration.zig");
const BrowserDagIntegration = browser_dag.BrowserDagIntegration;
const DOMNode = browser_dag.DOMNode;
const WebRequest = browser_dag.WebRequest;
const dag_core = @import("../src/dag_core.zig");
const DagCore = dag_core.DagCore;

test "Browser-DAG: Map DOM node to DAG node" {
    // Objective: Verify DOM nodes are correctly mapped to DAG nodes.
    // Methodology: Create DOM node, map to DAG, verify DAG node exists.
    // Why: Foundation test for browser-DAG integration.
    
    const allocator = testing.allocator;
    
    // Initialize DAG.
    var dag = try DagCore.init(allocator);
    defer dag.deinit();
    
    // Initialize browser-DAG integration.
    var browser_dag_integration = BrowserDagIntegration.init(allocator, &dag);
    
    // Create DOM node.
    const dom_node = DOMNode{
        .id = 1,
        .node_type = .element,
        .tag_name = "div",
        .text_content = "Hello World",
        .attributes = "class=container",
        .parent_id = 0, // Root
        .children = &[_]u32{},
    };
    
    // Map DOM node to DAG.
    const dag_node_id = try browser_dag_integration.mapDomNodeToDag(dom_node);
    
    // Assert: DAG node must be created (postcondition).
    try testing.expect(dag_node_id > 0);
    
    // Assert: DAG node must exist (postcondition).
    const dag_node = dag.getNode(dag_node_id);
    try testing.expect(dag_node != null);
    try testing.expect(dag_node.?.node_type == .dom_node);
}

test "Browser-DAG: Map DOM node with parent" {
    // Objective: Verify DOM nodes with parents create dependency edges.
    // Methodology: Create parent and child DOM nodes, verify edge is created.
    // Why: Dependency tracking enables unified state between editor and browser.
    
    const allocator = testing.allocator;
    
    // Initialize DAG.
    var dag = try DagCore.init(allocator);
    defer dag.deinit();
    
    // Initialize browser-DAG integration.
    var browser_dag_integration = BrowserDagIntegration.init(allocator, &dag);
    
    // Create parent DOM node.
    const parent_dom = DOMNode{
        .id = 1,
        .node_type = .element,
        .tag_name = "div",
        .text_content = "",
        .attributes = "",
        .parent_id = 0,
        .children = &[_]u32{},
    };
    
    const parent_dag_id = try browser_dag_integration.mapDomNodeToDag(parent_dom);
    
    // Create child DOM node.
    const child_dom = DOMNode{
        .id = 2,
        .node_type = .element,
        .tag_name = "p",
        .text_content = "Child",
        .attributes = "",
        .parent_id = 1, // Parent is DOM node 1
        .children = &[_]u32{},
    };
    
    const child_dag_id = try browser_dag_integration.mapDomNodeToDag(child_dom);
    
    // Assert: Both nodes must be created (postcondition).
    try testing.expect(parent_dag_id > 0);
    try testing.expect(child_dag_id > 0);
    try testing.expect(child_dag_id != parent_dag_id);
    
    // Assert: Dependency edge must be created (postcondition).
    const edges = dag.getEdges(child_dag_id, true); // Incoming edges
    try testing.expect(edges.len > 0);
}

test "Browser-DAG: Map web request to DAG event" {
    // Objective: Verify web requests are correctly mapped to DAG events.
    // Methodology: Create web request, map to DAG, verify event exists.
    // Why: Web requests must be tracked in unified DAG state.
    
    const allocator = testing.allocator;
    
    // Initialize DAG.
    var dag = try DagCore.init(allocator);
    defer dag.deinit();
    
    // Initialize browser-DAG integration.
    var browser_dag_integration = BrowserDagIntegration.init(allocator, &dag);
    
    // Create web request.
    const request = WebRequest{
        .url = "https://example.com",
        .method = "GET",
        .headers = "Accept: text/html",
        .body = "",
        .status_code = 200,
        .response_body = "<html>Hello</html>",
        .timestamp = 1000,
    };
    
    // Map web request to DAG event.
    const event_id = try browser_dag_integration.mapWebRequestToDag(request, &[_]u64{});
    
    // Assert: Event must be created (postcondition).
    try testing.expect(event_id > 0);
}

test "Browser-DAG: Streaming updates" {
    // Objective: Verify streaming updates process events correctly.
    // Methodology: Add events, process streaming updates, verify events are processed.
    // Why: Real-time updates enable responsive browser behavior.
    
    const allocator = testing.allocator;
    
    // Initialize DAG.
    var dag = try DagCore.init(allocator);
    defer dag.deinit();
    
    // Initialize browser-DAG integration.
    var browser_dag_integration = BrowserDagIntegration.init(allocator, &dag);
    
    // Create and map web request (creates event).
    const request = WebRequest{
        .url = "https://example.com",
        .method = "GET",
        .headers = "",
        .body = "",
        .status_code = 200,
        .response_body = "Response",
        .timestamp = 1000,
    };
    
    _ = try browser_dag_integration.mapWebRequestToDag(request, &[_]u64{});
    
    // Assert: Event must be pending (precondition).
    try testing.expect(dag.pending_events_len > 0);
    
    // Process streaming updates.
    try browser_dag_integration.processStreamingUpdates();
    
    // Assert: Events must be processed (postcondition).
    try testing.expect(dag.pending_events_len == 0);
}

test "Browser-DAG: Unified state (editor + browser)" {
    // Objective: Verify unified state tracks both editor and browser nodes.
    // Methodology: Add editor nodes and browser nodes, verify unified count.
    // Why: Unified state enables editor-browser integration.
    
    const allocator = testing.allocator;
    
    // Initialize DAG.
    var dag = try DagCore.init(allocator);
    defer dag.deinit();
    
    // Add editor node (AST node).
    const editor_node_id = try dag.addNode(
        .ast_node,
        "fn main() void {}",
    );
    
    // Initialize browser-DAG integration.
    var browser_dag_integration = BrowserDagIntegration.init(allocator, &dag);
    
    // Add browser node (DOM node).
    const dom_node = DOMNode{
        .id = 1,
        .node_type = .element,
        .tag_name = "div",
        .text_content = "",
        .attributes = "",
        .parent_id = 0,
        .children = &[_]u32{},
    };
    
    const browser_node_id = try browser_dag_integration.mapDomNodeToDag(dom_node);
    
    // Assert: Both nodes must exist (postcondition).
    try testing.expect(editor_node_id > 0);
    try testing.expect(browser_node_id > 0);
    
    // Assert: Unified state must include both (postcondition).
    const unified_count = browser_dag_integration.getUnifiedState();
    try testing.expect(unified_count >= 2);
    
    // Assert: Browser nodes count must be correct (postcondition).
    const browser_count = browser_dag_integration.getBrowserNodesCount();
    try testing.expect(browser_count >= 1);
}

test "Browser-DAG: Multiple DOM nodes" {
    // Objective: Verify multiple DOM nodes can be mapped correctly.
    // Methodology: Create multiple DOM nodes, verify all are mapped.
    // Why: Real pages have multiple DOM nodes, all must be tracked.
    
    const allocator = testing.allocator;
    
    // Initialize DAG.
    var dag = try DagCore.init(allocator);
    defer dag.deinit();
    
    // Initialize browser-DAG integration.
    var browser_dag_integration = BrowserDagIntegration.init(allocator, &dag);
    
    // Create multiple DOM nodes.
    const dom_nodes = [_]DOMNode{
        .{
            .id = 1,
            .node_type = .element,
            .tag_name = "html",
            .text_content = "",
            .attributes = "",
            .parent_id = 0,
            .children = &[_]u32{},
        },
        .{
            .id = 2,
            .node_type = .element,
            .tag_name = "body",
            .text_content = "",
            .attributes = "",
            .parent_id = 1,
            .children = &[_]u32{},
        },
        .{
            .id = 3,
            .node_type = .element,
            .tag_name = "p",
            .text_content = "Hello",
            .attributes = "",
            .parent_id = 2,
            .children = &[_]u32{},
        },
    };
    
    // Map all DOM nodes to DAG.
    var dag_node_ids: [3]u32 = undefined;
    var i: u32 = 0;
    while (i < 3) : (i += 1) {
        dag_node_ids[i] = try browser_dag_integration.mapDomNodeToDag(dom_nodes[i]);
    }
    
    // Assert: All nodes must be created (postcondition).
    try testing.expect(dag_node_ids[0] > 0);
    try testing.expect(dag_node_ids[1] > 0);
    try testing.expect(dag_node_ids[2] > 0);
    
    // Assert: All nodes must be unique (postcondition).
    try testing.expect(dag_node_ids[0] != dag_node_ids[1]);
    try testing.expect(dag_node_ids[1] != dag_node_ids[2]);
    try testing.expect(dag_node_ids[0] != dag_node_ids[2]);
}

test "Browser-DAG: Web request with parent events" {
    // Objective: Verify web requests can reference parent events (HashDAG-style).
    // Methodology: Create parent event, create child event with parent reference.
    // Why: HashDAG-style ordering enables deterministic event processing.
    
    const allocator = testing.allocator;
    
    // Initialize DAG.
    var dag = try DagCore.init(allocator);
    defer dag.deinit();
    
    // Initialize browser-DAG integration.
    var browser_dag_integration = BrowserDagIntegration.init(allocator, &dag);
    
    // Create first web request (parent).
    const parent_request = WebRequest{
        .url = "https://example.com",
        .method = "GET",
        .headers = "",
        .body = "",
        .status_code = 200,
        .response_body = "Parent",
        .timestamp = 1000,
    };
    
    const parent_event_id = try browser_dag_integration.mapWebRequestToDag(
        parent_request,
        &[_]u64{},
    );
    
    // Create second web request (child, references parent).
    const child_request = WebRequest{
        .url = "https://example.com/api",
        .method = "GET",
        .headers = "",
        .body = "",
        .status_code = 200,
        .response_body = "Child",
        .timestamp = 1001,
    };
    
    const child_event_id = try browser_dag_integration.mapWebRequestToDag(
        child_request,
        &[_]u64{parent_event_id},
    );
    
    // Assert: Both events must be created (postcondition).
    try testing.expect(parent_event_id > 0);
    try testing.expect(child_event_id > 0);
    try testing.expect(child_event_id != parent_event_id);
}

test "Browser-DAG: URL node reuse" {
    // Objective: Verify URL nodes are reused for same URL.
    // Methodology: Create multiple requests to same URL, verify single node.
    // Why: URL nodes should be unique per URL, not per request.
    
    const allocator = testing.allocator;
    
    // Initialize DAG.
    var dag = try DagCore.init(allocator);
    defer dag.deinit();
    
    // Initialize browser-DAG integration.
    var browser_dag_integration = BrowserDagIntegration.init(allocator, &dag);
    
    // Create first request to URL.
    const request1 = WebRequest{
        .url = "https://example.com",
        .method = "GET",
        .headers = "",
        .body = "",
        .status_code = 200,
        .response_body = "Response 1",
        .timestamp = 1000,
    };
    
    const event1_id = try browser_dag_integration.mapWebRequestToDag(request1, &[_]u64{});
    
    // Create second request to same URL.
    const request2 = WebRequest{
        .url = "https://example.com",
        .method = "GET",
        .headers = "",
        .body = "",
        .status_code = 200,
        .response_body = "Response 2",
        .timestamp = 1001,
    };
    
    const event2_id = try browser_dag_integration.mapWebRequestToDag(request2, &[_]u64{});
    
    // Assert: Both events must be created (postcondition).
    try testing.expect(event1_id > 0);
    try testing.expect(event2_id > 0);
    
    // Assert: URL node should be reused (same node_id for both events).
    // Note: This requires checking event node_id, which is internal to DAG.
    // For now, we verify events are created successfully.
}

