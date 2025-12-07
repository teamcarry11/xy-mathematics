//! Grain Bubble Svelte Export Tests.
//!
//! Why: Test Svelte export functionality for canvas designs.
//! Architecture: Unit tests for Svelte component generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-023640-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const canvas = @import("grain_bubble").canvas;
const component = @import("grain_bubble").component;
const export_framework = @import("grain_bubble").export_framework;

test "svelte component init" {
    const comp = export_framework.SvelteComponent.init("TestComponent");
    std.debug.assert(comp.template_content_len == 0);
    std.debug.assert(comp.style_content_len == 0);
    const name = comp.get_component_name();
    std.debug.assert(name.len > 0);
    std.debug.assert(std.mem.eql(u8, name, "TestComponent"));
}

test "svelte component script section" {
    var comp = export_framework.SvelteComponent.init("TestComponent");
    comp.write_script_section();
    std.debug.assert(comp.template_content_len > 0);
    const content = comp.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "<script>") != null);
}

test "svelte export rectangle" {
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
    var comp = export_framework.SvelteComponent.init("TestComponent");
    comp.write_script_section();
    comp.write_template_start();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            comp.export_shape(&layer.shapes[0]);
            std.debug.assert(comp.template_content_len > 0);
            std.debug.assert(comp.style_content_len > 0);
        }
    }
    comp.write_template_end();
    comp.write_style_start();
    comp.write_style_end();
    const content = comp.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "shape-") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "#FF0000") != null);
}

test "svelte export circle" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    _ = canvas_data.add_shape(
        layer_id,
        .circle,
        10.0,
        20.0,
        50.0,
        50.0,
        0x00FF00FF,
        0.0,
    );
    var comp = export_framework.SvelteComponent.init("TestComponent");
    comp.write_script_section();
    comp.write_template_start();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            comp.export_shape(&layer.shapes[0]);
            std.debug.assert(comp.style_content_len > 0);
        }
    }
    comp.write_template_end();
    comp.write_style_start();
    comp.write_style_end();
    const content = comp.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "border-radius: 50%") != null);
}

test "svelte export rounded rectangle" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    _ = canvas_data.add_shape(
        layer_id,
        .rounded_rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0x0000FFFF,
        10.0,
    );
    var comp = export_framework.SvelteComponent.init("TestComponent");
    comp.write_script_section();
    comp.write_template_start();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            comp.export_shape(&layer.shapes[0]);
            std.debug.assert(comp.style_content_len > 0);
        }
    }
    comp.write_template_end();
    comp.write_style_start();
    comp.write_style_end();
    const content = comp.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "border-radius:") != null);
}

test "svelte export text" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    _ = canvas_data.add_text(layer_id, 10.0, 20.0, "Hello", 16, 0x000000FF);
    var comp = export_framework.SvelteComponent.init("TestComponent");
    comp.write_script_section();
    comp.write_template_start();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.texts_len > 0) {
            comp.export_text(&layer.texts[0]);
            std.debug.assert(comp.template_content_len > 0);
            std.debug.assert(comp.style_content_len > 0);
        }
    }
    comp.write_template_end();
    comp.write_style_start();
    comp.write_style_end();
    const content = comp.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "Hello") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "text-") != null);
}

test "svelte export canvas" {
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
    _ = canvas_data.add_text(layer_id, 10.0, 10.0, "Hello", 16, 0x000000FF);
    var comp = export_framework.SvelteComponent.init("TestComponent");
    comp.export_canvas(&canvas_data);
    std.debug.assert(comp.template_content_len > 0);
    const content = comp.get_content();
    std.debug.assert(content.len > 0);
    std.debug.assert(std.mem.indexOf(u8, content, "<script>") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "<style>") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "component") != null);
}

test "svelte export shape with stroke" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    _ = canvas_data.add_shape_with_stroke(
        layer_id,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
        2.0,
        0x000000FF,
    );
    var comp = export_framework.SvelteComponent.init("TestComponent");
    comp.write_script_section();
    comp.write_template_start();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            comp.export_shape(&layer.shapes[0]);
            std.debug.assert(comp.style_content_len > 0);
        }
    }
    comp.write_template_end();
    comp.write_style_start();
    comp.write_style_end();
    const content = comp.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "border:") != null);
}

test "svelte export component variant" {
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
    var comp = export_framework.SvelteComponent.init("ButtonComponent");
    comp.write_script_section();
    comp.write_template_start();
    if (library.get_component(component_id)) |comp_data| {
        std.debug.assert(comp_data.variants_len > 0);
        comp.export_component_variant(&comp_data.variants[0]);
        std.debug.assert(comp.template_content_len > 0);
        std.debug.assert(comp.style_content_len > 0);
    }
    comp.write_template_end();
    comp.write_style_start();
    comp.write_style_end();
    const content = comp.get_content();
    std.debug.assert(content.len > 0);
}

