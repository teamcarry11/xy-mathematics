//! Grain Bubble Component Tests.
//!
//! Why: Test component system functionality.
//! Architecture: Unit tests for component library.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-135535-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const canvas = @import("grain_bubble").canvas;
const component = @import("grain_bubble").component;

test "component library init" {
    const library = component.ComponentLibrary.init();
    std.debug.assert(library.components_len == 0);
    std.debug.assert(library.next_component_id == 1);
    std.debug.assert(library.next_variant_id == 1);
    std.debug.assert(library.next_token_id == 1);
}

test "component library create component from selection" {
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
    std.debug.assert(component_id > 0);
    std.debug.assert(library.components_len == 1);
    if (library.get_component(component_id)) |comp| {
        std.debug.assert(comp.name_len > 0);
        std.debug.assert(comp.variants_len == 1);
        std.debug.assert(comp.variants[0].shapes_len == 1);
    }
}

test "component library get component by name" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var library = component.ComponentLibrary.init();
    const layer_id = canvas_data.create_layer("Test Layer").?;
    const shape_id = canvas_data.add_shape(
        layer_id,
        .circle,
        10.0,
        20.0,
        50.0,
        50.0,
        0x00FF00FF,
        0.0,
    ).?;
    _ = canvas_data.select_shape(shape_id);
    const component_id = library.create_component_from_selection(&canvas_data, "Icon").?;
    if (library.get_component_by_name("Icon")) |comp| {
        std.debug.assert(comp.id == component_id);
        std.debug.assert(comp.variants_len == 1);
    }
}

test "component library instantiate component" {
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
    const instance_id = library.instantiate_component(
        component_id,
        &canvas_data,
        layer_id,
        200.0,
        200.0,
    ).?;
    std.debug.assert(instance_id > 0);
    if (canvas_data.get_layer(layer_id)) |layer| {
        std.debug.assert(layer.shapes_len == 2); // Original + instance
    }
}

test "component library add variant" {
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
    const variant_id = library.add_variant(
        component_id,
        "hover",
        .state,
    ).?;
    std.debug.assert(variant_id > 0);
    if (library.get_component(component_id)) |comp| {
        std.debug.assert(comp.variants_len == 2);
    }
}

test "component library add design token" {
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
    const token_id = library.add_design_token(
        component_id,
        "primary-color",
        .color,
        .{ .color = 0xFF0000FF },
    ).?;
    std.debug.assert(token_id > 0);
    if (library.get_component(component_id)) |comp| {
        std.debug.assert(comp.design_tokens_len == 1);
        std.debug.assert(comp.design_tokens[0].token_type == .color);
        std.debug.assert(comp.design_tokens[0].value.color == 0xFF0000FF);
    }
}

