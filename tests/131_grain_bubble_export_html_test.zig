//! Grain Bubble HTML Export Tests.
//!
//! Why: Test HTML export functionality for canvas designs.
//! Architecture: Unit tests for HTML export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-020615-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const canvas = @import("grain_bubble").canvas;
const component = @import("grain_bubble").component;
const export_html = @import("grain_bubble").export_html;

test "html document init" {
    const doc = export_html.HtmlDocument.init(800, 600);
    std.debug.assert(doc.width == 800);
    std.debug.assert(doc.height == 600);
    std.debug.assert(doc.html_content_len == 0);
    std.debug.assert(doc.css_content_len == 0);
}

test "html document header footer" {
    var doc = export_html.HtmlDocument.init(800, 600);
    doc.write_html_header();
    std.debug.assert(doc.html_content_len > 0);
    doc.write_html_footer();
    std.debug.assert(doc.html_content_len > 0);
    const content = doc.get_html_content();
    std.debug.assert(content.len > 0);
    std.debug.assert(std.mem.indexOf(u8, content, "<!DOCTYPE html>") != null);
    std.debug.assert(std.mem.indexOf(u8, content, "</html>") != null);
}

test "html export rectangle" {
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
    var doc = export_html.HtmlDocument.init(800, 600);
    doc.write_html_header();
    doc.write_canvas_css();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            doc.export_shape(&layer.shapes[0]);
            std.debug.assert(doc.html_content_len > 0);
            std.debug.assert(doc.css_content_len > 0);
        }
    }
    doc.write_css_to_html();
    doc.write_html_footer();
    const html = doc.get_html_content();
    std.debug.assert(std.mem.indexOf(u8, html, "shape-") != null);
    std.debug.assert(std.mem.indexOf(u8, html, "#FF0000") != null);
}

test "html export circle" {
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
    var doc = export_html.HtmlDocument.init(800, 600);
    doc.write_html_header();
    doc.write_canvas_css();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            doc.export_shape(&layer.shapes[0]);
            std.debug.assert(doc.css_content_len > 0);
        }
    }
    doc.write_css_to_html();
    doc.write_html_footer();
    const html = doc.get_html_content();
    std.debug.assert(std.mem.indexOf(u8, html, "border-radius: 50%") != null);
}

test "html export rounded rectangle" {
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
    var doc = export_html.HtmlDocument.init(800, 600);
    doc.write_html_header();
    doc.write_canvas_css();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            doc.export_shape(&layer.shapes[0]);
            std.debug.assert(doc.css_content_len > 0);
        }
    }
    doc.write_css_to_html();
    doc.write_html_footer();
    const html = doc.get_html_content();
    std.debug.assert(std.mem.indexOf(u8, html, "border-radius:") != null);
}

test "html export text" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    _ = canvas_data.add_text(layer_id, 10.0, 20.0, "Hello", 16, 0x000000FF);
    var doc = export_html.HtmlDocument.init(800, 600);
    doc.write_html_header();
    doc.write_canvas_css();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.texts_len > 0) {
            doc.export_text(&layer.texts[0]);
            std.debug.assert(doc.html_content_len > 0);
            std.debug.assert(doc.css_content_len > 0);
        }
    }
    doc.write_css_to_html();
    doc.write_html_footer();
    const html = doc.get_html_content();
    std.debug.assert(std.mem.indexOf(u8, html, "Hello") != null);
    std.debug.assert(std.mem.indexOf(u8, html, "text-") != null);
}

test "html export canvas" {
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
    var doc = export_html.HtmlDocument.init(800, 600);
    doc.export_canvas(&canvas_data);
    std.debug.assert(doc.html_content_len > 0);
    const html = doc.get_html_content();
    std.debug.assert(html.len > 0);
    std.debug.assert(std.mem.indexOf(u8, html, "<!DOCTYPE html>") != null);
    std.debug.assert(std.mem.indexOf(u8, html, "canvas-container") != null);
}

test "html export shape with stroke" {
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
    var doc = export_html.HtmlDocument.init(800, 600);
    doc.write_html_header();
    doc.write_canvas_css();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            doc.export_shape(&layer.shapes[0]);
            std.debug.assert(doc.css_content_len > 0);
        }
    }
    doc.write_css_to_html();
    doc.write_html_footer();
    const html = doc.get_html_content();
    std.debug.assert(std.mem.indexOf(u8, html, "border:") != null);
}

test "html export component variant" {
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
    var doc = export_html.HtmlDocument.init(800, 600);
    doc.write_html_header();
    doc.write_canvas_css();
    if (library.get_component(component_id)) |comp| {
        std.debug.assert(comp.variants_len > 0);
        doc.export_component_variant(&comp.variants[0]);
        std.debug.assert(doc.html_content_len > 0);
        std.debug.assert(doc.css_content_len > 0);
    }
    doc.write_css_to_html();
    doc.write_html_footer();
    const html = doc.get_html_content();
    std.debug.assert(html.len > 0);
}

