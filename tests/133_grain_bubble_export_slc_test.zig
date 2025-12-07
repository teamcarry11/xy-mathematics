//! Grain Bubble SLC Export Tests.
//!
//! Why: Test SLC asset bundle export functionality.
//! Architecture: Unit tests for SLC bundle generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-030523-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const canvas = @import("grain_bubble").canvas;
const component = @import("grain_bubble").component;
const export_slc = @import("grain_bubble").export_slc;

test "slc bundle init" {
    const bundle = export_slc.SlcBundle.init("TestBundle");
    std.debug.assert(bundle.content_len == 0);
    const name = bundle.get_bundle_name();
    std.debug.assert(name.len > 0);
    std.debug.assert(std.mem.eql(u8, name, "TestBundle"));
}

test "slc bundle header footer" {
    var bundle = export_slc.SlcBundle.init("TestBundle");
    bundle.write_header(800, 600);
    std.debug.assert(bundle.content_len > 0);
    bundle.write_footer();
    std.debug.assert(bundle.content_len > 0);
    const content = bundle.get_content();
    std.debug.assert(content.len > 0);
    std.debug.assert(std.mem.indexOf(u8, content, "<!DOCTYPE html>") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "</html>") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "slc-canvas") != null);
}

test "slc export rectangle" {
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
    var bundle = export_slc.SlcBundle.init("TestBundle");
    bundle.write_header(800, 600);
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            bundle.export_shape(&layer.shapes[0]);
            std.debug.assert(bundle.content_len > 0);
        }
    }
    bundle.write_footer();
    const content = bundle.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "shape-") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "#FF0000") != null);
}

test "slc export circle" {
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
    var bundle = export_slc.SlcBundle.init("TestBundle");
    bundle.write_header(800, 600);
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            bundle.export_shape(&layer.shapes[0]);
            std.debug.assert(bundle.content_len > 0);
        }
    }
    bundle.write_footer();
    const content = bundle.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "border-radius: 50%") != null);
}

test "slc export rounded rectangle" {
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
    var bundle = export_slc.SlcBundle.init("TestBundle");
    bundle.write_header(800, 600);
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            bundle.export_shape(&layer.shapes[0]);
            std.debug.assert(bundle.content_len > 0);
        }
    }
    bundle.write_footer();
    const content = bundle.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "border-radius:") != null);
}

test "slc export text" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    _ = canvas_data.add_text(layer_id, 10.0, 20.0, "Hello", 16, 0x000000FF);
    var bundle = export_slc.SlcBundle.init("TestBundle");
    bundle.write_header(800, 600);
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.texts_len > 0) {
            bundle.export_text(&layer.texts[0]);
            std.debug.assert(bundle.content_len > 0);
        }
    }
    bundle.write_footer();
    const content = bundle.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "Hello") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "text-") != null);
}

test "slc export canvas" {
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
    var bundle = export_slc.SlcBundle.init("TestBundle");
    bundle.export_canvas(&canvas_data);
    std.debug.assert(bundle.content_len > 0);
    const content = bundle.get_content();
    std.debug.assert(content.len > 0);
    std.debug.assert(std.mem.indexOf(u8, content, "<!DOCTYPE html>") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "slc-canvas") != null);
}

test "slc export shape with stroke" {
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
    var bundle = export_slc.SlcBundle.init("TestBundle");
    bundle.write_header(800, 600);
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            bundle.export_shape(&layer.shapes[0]);
            std.debug.assert(bundle.content_len > 0);
        }
    }
    bundle.write_footer();
    const content = bundle.get_content();
    std.debug.assert(std.mem.indexOf(u8, content, "border:") != null);
}

test "slc export component variant" {
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
    var bundle = export_slc.SlcBundle.init("TestBundle");
    bundle.write_header(800, 600);
    if (library.get_component(component_id)) |comp| {
        std.debug.assert(comp.variants_len > 0);
        bundle.export_component_variant(&comp.variants[0]);
        std.debug.assert(bundle.content_len > 0);
    }
    bundle.write_footer();
    const content = bundle.get_content();
    std.debug.assert(content.len > 0);
}

