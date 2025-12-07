//! Grain Bubble PDF Export Tests.
//!
//! Why: Test PDF export functionality for canvas designs.
//! Architecture: Unit tests for PDF export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-113622-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const canvas = @import("grain_bubble").canvas;
const component = @import("grain_bubble").component;
const export_pdf = @import("grain_bubble").export_pdf;

test "pdf document init" {
    const doc = export_pdf.PdfDocument.init(612, 792); // Letter size
    std.debug.assert(doc.width == 612);
    std.debug.assert(doc.height == 792);
    std.debug.assert(doc.content_len == 0);
}

test "pdf document header footer" {
    var doc = export_pdf.PdfDocument.init(612, 792);
    doc.write_header();
    std.debug.assert(doc.content_len > 0);
    const content = doc.get_content();
    std.debug.assert(content.len > 0);
    std.debug.assert(content[0] == '%');
    doc.write_footer();
    std.debug.assert(doc.content_len > doc.content_len - 10);
}

test "pdf export rectangle" {
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
    var doc = export_pdf.PdfDocument.init(612, 792);
    doc.write_header();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            doc.export_shape(&layer.shapes[0]);
            std.debug.assert(doc.content_len > 0);
        }
    }
    doc.write_footer();
}

test "pdf export circle" {
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
    var doc = export_pdf.PdfDocument.init(612, 792);
    doc.write_header();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            doc.export_shape(&layer.shapes[0]);
            std.debug.assert(doc.content_len > 0);
        }
    }
    doc.write_footer();
}

test "pdf export rounded rectangle" {
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
    var doc = export_pdf.PdfDocument.init(612, 792);
    doc.write_header();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            doc.export_shape(&layer.shapes[0]);
            std.debug.assert(doc.content_len > 0);
        }
    }
    doc.write_footer();
}

test "pdf export canvas" {
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
    var doc = export_pdf.PdfDocument.init(612, 792);
    doc.export_canvas(&canvas_data);
    std.debug.assert(doc.content_len > 0);
    const content = doc.get_content();
    std.debug.assert(content.len > 0);
    std.debug.assert(content[0] == '%');
}

test "pdf export shape with stroke" {
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
    var doc = export_pdf.PdfDocument.init(612, 792);
    doc.write_header();
    if (canvas_data.get_layer(layer_id)) |layer| {
        if (layer.shapes_len > 0) {
            doc.export_shape(&layer.shapes[0]);
            std.debug.assert(doc.content_len > 0);
        }
    }
    doc.write_footer();
}

test "pdf export component variant" {
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
    var doc = export_pdf.PdfDocument.init(612, 792);
    doc.write_header();
    if (library.get_component(component_id)) |comp| {
        std.debug.assert(comp.variants_len > 0);
        doc.export_component_variant(&comp.variants[0]);
        std.debug.assert(doc.content_len > 0);
    }
    doc.write_footer();
}

test "pdf export component" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var library = component.ComponentLibrary.init();
    const layer_id = canvas_data.create_layer("Test Layer").?;
    const shape_id = canvas_data.add_shape(
        layer_id,
        .rounded_rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0x00FF00FF,
        5.0,
    ).?;
    _ = canvas_data.select_shape(shape_id);
    const component_id = library.create_component_from_selection(&canvas_data, "Card").?;
    var doc = export_pdf.PdfDocument.init(612, 792);
    doc.write_header();
    if (library.get_component(component_id)) |comp| {
        doc.export_component(comp);
        std.debug.assert(doc.content_len > 0);
    }
    doc.write_footer();
}

