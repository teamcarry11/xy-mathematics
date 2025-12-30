//! Grain Bubble Court Integration Tests.
//!
//! Why: Test Court integration for vector search and LLM suggestions.
//! Architecture: Unit tests for Court integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-054259-pst: Grain Bubble Agent
//! 2025-12-28-144543-pst: Updated for timeout and error handling

const std = @import("std");
const testing = std.testing;
const canvas = @import("grain_bubble").canvas;
const component = @import("grain_bubble").component;
const court_integration = @import("grain_bubble").court_integration;

test "court integration init" {
    const integration = court_integration.CourtIntegration.init();
    std.debug.assert(integration.compute == null);
    std.debug.assert(integration.next_suggestion_id == 1);
    std.debug.assert(integration.timeout_api_ms == court_integration.DEFAULT_TIMEOUT_API_MS);
    std.debug.assert(integration.timeout_content_ms == court_integration.DEFAULT_TIMEOUT_CONTENT_MS);
    std.debug.assert(integration.max_retries == court_integration.DEFAULT_MAX_RETRIES);
    std.debug.assert(integration.retry_delay_ms == court_integration.DEFAULT_RETRY_DELAY_MS);
}

test "court integration set compute" {
    var integration = court_integration.CourtIntegration.init();
    // Note: In real implementation, would create actual CourtCompute instance.
    // For Phase 3, testing interface structure.
    std.debug.assert(integration.compute == null);
}

test "court integration search similar components" {
    var integration = court_integration.CourtIntegration.init();
    var query_vector: [128]f32 = undefined;
    @memset(query_vector[0..], 0.0);
    var results: [8]court_integration.ComponentMatch = undefined;
    var i: u32 = 0;
    while (i < results.len) : (i += 1) {
        results[i] = court_integration.ComponentMatch.init();
    }
    const result = integration.search_similar_components(
        query_vector[0..],
        results[0..],
    );
    // Returns error when compute not set (expected for Phase 3).
    std.debug.assert(result == error.ComputeNotSet);
}

test "court integration get design suggestions" {
    var integration = court_integration.CourtIntegration.init();
    const context = "Create a button component";
    var suggestions: [4]court_integration.DesignSuggestion = undefined;
    var i: u32 = 0;
    while (i < suggestions.len) : (i += 1) {
        suggestions[i] = court_integration.DesignSuggestion.init();
    }
    const result = integration.get_design_suggestions(
        context,
        suggestions[0..],
    );
    // Returns error when compute not set (expected for Phase 3).
    std.debug.assert(result == error.ComputeNotSet);
}

test "court integration generate component embedding" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var library = component.ComponentLibrary.init();
    const layer_id = canvas_data.create_layer("Test Layer").?;
    const shape_id = canvas_data.add_shape(
        layer_id,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
    ).?;
    _ = canvas_data.select_shape(shape_id);
    const component_id = library.create_component_from_selection(&canvas_data, "Button").?;
    var integration = court_integration.CourtIntegration.init();
    if (library.get_component(component_id)) |comp| {
        var embedding: [128]f32 = undefined;
        @memset(embedding[0..], 0.0);
        const result = integration.generate_component_embedding(comp, embedding[0..]);
        // Returns error when compute not set (expected for Phase 3).
        std.debug.assert(result == error.ComputeNotSet);
    }
}

test "court integration component to description" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var library = component.ComponentLibrary.init();
    const layer_id = canvas_data.create_layer("Test Layer").?;
    const shape_id = canvas_data.add_shape(
        layer_id,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
    ).?;
    _ = canvas_data.select_shape(shape_id);
    const component_id = library.create_component_from_selection(&canvas_data, "Button").?;
    if (library.get_component(component_id)) |comp| {
        var buffer: [256]u8 = undefined;
        const len = court_integration.CourtIntegration.component_to_description(comp, buffer[0..]);
        std.debug.assert(len > 0);
        std.debug.assert(len <= 256);
    }
}

test "court integration canvas to context" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    _ = canvas_data.add_shape(
        layer_id,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
    );
    var buffer: [512]u8 = undefined;
    const len = court_integration.CourtIntegration.canvas_to_context(&canvas_data, buffer[0..]);
    std.debug.assert(len > 0);
    std.debug.assert(len <= 512);
}

test "court integration timeout configuration" {
    var integration = court_integration.CourtIntegration.init();
    std.debug.assert(integration.timeout_api_ms == court_integration.DEFAULT_TIMEOUT_API_MS);
    std.debug.assert(integration.timeout_content_ms == court_integration.DEFAULT_TIMEOUT_CONTENT_MS);
    integration.set_timeout_api(15000);
    std.debug.assert(integration.timeout_api_ms == 15000);
    integration.set_timeout_content(90000);
    std.debug.assert(integration.timeout_content_ms == 90000);
}

test "court integration retry configuration" {
    var integration = court_integration.CourtIntegration.init();
    std.debug.assert(integration.max_retries == court_integration.DEFAULT_MAX_RETRIES);
    std.debug.assert(integration.retry_delay_ms == court_integration.DEFAULT_RETRY_DELAY_MS);
    integration.set_max_retries(5);
    std.debug.assert(integration.max_retries == 5);
    integration.set_retry_delay(200);
    std.debug.assert(integration.retry_delay_ms == 200);
}

test "court integration error retryability" {
    std.debug.assert(court_integration.is_retryable_error(court_integration.CourtComputeError.SramAllocationFailed) == true);
    std.debug.assert(court_integration.is_retryable_error(court_integration.CourtComputeError.OperationFailed) == true);
    std.debug.assert(court_integration.is_retryable_error(court_integration.CourtComputeError.OperationTimeout) == true);
    std.debug.assert(court_integration.is_retryable_error(court_integration.CourtComputeError.ComputeNotSet) == false);
    std.debug.assert(court_integration.is_retryable_error(court_integration.CourtComputeError.InvalidInput) == false);
    std.debug.assert(court_integration.is_retryable_error(court_integration.CourtComputeError.OperationNotCompleted) == true);
}
