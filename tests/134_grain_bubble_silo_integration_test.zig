//! Grain Bubble Silo Integration Tests.
//!
//! Why: Test Silo integration for design asset storage.
//! Architecture: Unit tests for Silo integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-054259-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const canvas = @import("grain_bubble").canvas;
const component = @import("grain_bubble").component;
const silo_integration = @import("grain_bubble").silo_integration;

test "silo integration init" {
    const integration = silo_integration.SiloIntegration.init();
    std.debug.assert(integration.storage == null);
    std.debug.assert(integration.next_asset_id == 1);
}

test "silo integration set storage" {
    var integration = silo_integration.SiloIntegration.init();
    // Note: In real implementation, would create actual Storage instance.
    // For Phase 3, testing interface structure.
    std.debug.assert(integration.storage == null);
}

test "silo integration store canvas" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var integration = silo_integration.SiloIntegration.init();
    const key = "test-canvas-1";
    const result = integration.store_canvas(&canvas_data, key);
    // Returns false when storage not set (expected for Phase 3).
    std.debug.assert(result == false);
}

test "silo integration load canvas" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var integration = silo_integration.SiloIntegration.init();
    const key = "test-canvas-1";
    const result = integration.load_canvas(key, &canvas_data);
    // Returns false when storage not set (expected for Phase 3).
    std.debug.assert(result == false);
}

test "silo integration store component" {
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
    var integration = silo_integration.SiloIntegration.init();
    if (library.get_component(component_id)) |comp| {
        const key = "test-component-1";
        const result = integration.store_component(comp, key);
        // Returns false when storage not set (expected for Phase 3).
        std.debug.assert(result == false);
    }
}

test "silo integration load component" {
    var comp = component.Component.init();
    var integration = silo_integration.SiloIntegration.init();
    const key = "test-component-1";
    const result = integration.load_component(key, &comp);
    // Returns false when storage not set (expected for Phase 3).
    std.debug.assert(result == false);
}

