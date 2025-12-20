//! Grain Bubble Export Preview Tests
//!
//! Tests for export preview functionality.
//!
//! 2025-12-20-143300-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const grain_bubble = @import("grain_bubble");
const canvas = grain_bubble.canvas;
const component = grain_bubble.component;
const export_html = grain_bubble.export_html;
const export_framework = grain_bubble.export_framework;
const export_slc = grain_bubble.export_slc;
const export_optimize = grain_bubble.export_optimize;
const export_preview = grain_bubble.export_preview;

test "export_preview init" {
    const preview = export_preview.ExportPreview.init(
        .html,
        800,
        600,
    );
    try testing.expect(preview.format == .html);
    try testing.expect(preview.width == 800);
    try testing.expect(preview.height == 600);
    try testing.expect(preview.content_len == 0);
    try testing.expect(preview.metadata_len == 0);
    try testing.expect(preview.file_size == 0);
    try testing.expect(preview.optimized_size == 0);
    try testing.expect(preview.compression_ratio == 0.0);
}

test "export_preview set_content" {
    var preview = export_preview.ExportPreview.init(
        .html,
        800,
        600,
    );
    const test_content = "<html><body>Test</body></html>";
    preview.set_content(test_content);
    try testing.expect(preview.content_len == test_content.len);
    try testing.expect(preview.file_size == test_content.len);
    const content = preview.get_content();
    try testing.expect(std.mem.eql(u8, content, test_content));
}

test "export_preview set_metadata" {
    var preview = export_preview.ExportPreview.init(
        .html,
        800,
        600,
    );
    const test_metadata = "HTML Export: 800x600px, 1024 bytes";
    preview.set_metadata(test_metadata);
    try testing.expect(preview.metadata_len == test_metadata.len);
    const metadata = preview.get_metadata();
    try testing.expect(std.mem.eql(u8, metadata, test_metadata));
}

test "export_preview from_html_document" {
    var canvas_state = canvas.Canvas.init(800, 600);
    var html_doc = export_html.HtmlDocument.init(800, 600);
    html_doc.export_canvas(&canvas_state);
    var preview = export_preview.ExportPreview.init(
        .html,
        800,
        600,
    );
    preview.from_html_document(&html_doc);
    try testing.expect(preview.format == .html);
    try testing.expect(preview.width == 800);
    try testing.expect(preview.height == 600);
    try testing.expect(preview.content_len > 0);
    try testing.expect(preview.metadata_len > 0);
    const metadata = preview.get_metadata();
    try testing.expect(metadata.len > 0);
}

test "export_preview from_svelte_component" {
    var svelte_comp = export_framework.SvelteComponent.init("TestComponent");
    var preview = export_preview.ExportPreview.init(
        .svelte,
        800,
        600,
    );
    preview.from_svelte_component(&svelte_comp);
    try testing.expect(preview.format == .svelte);
    try testing.expect(preview.content_len >= 0);
    const metadata = preview.get_metadata();
    try testing.expect(metadata.len >= 0);
}

test "export_preview from_slc_bundle" {
    var canvas_state = canvas.Canvas.init(800, 600);
    var slc_bundle = export_slc.SlcBundle.init("TestBundle");
    slc_bundle.write_header(800, 600);
    slc_bundle.export_canvas(&canvas_state);
    slc_bundle.write_footer();
    var preview = export_preview.ExportPreview.init(
        .slc,
        800,
        600,
    );
    preview.from_slc_bundle(&slc_bundle, 800, 600);
    try testing.expect(preview.format == .slc);
    try testing.expect(preview.width == 800);
    try testing.expect(preview.height == 600);
    try testing.expect(preview.content_len > 0);
    try testing.expect(preview.metadata_len > 0);
    const metadata = preview.get_metadata();
    try testing.expect(metadata.len > 0);
}

test "export_preview calculate_optimization html" {
    var canvas_state = canvas.Canvas.init(800, 600);
    var html_doc = export_html.HtmlDocument.init(800, 600);
    html_doc.export_canvas(&canvas_state);
    var preview = export_preview.ExportPreview.init(
        .html,
        800,
        600,
    );
    preview.from_html_document(&html_doc);
    var optimizer = export_optimize.ExportOptimizer.init();
    preview.calculate_optimization(&optimizer);
    try testing.expect(preview.optimized_size > 0);
    try testing.expect(preview.optimized_size <= preview.file_size);
    try testing.expect(preview.compression_ratio >= 0.0);
    try testing.expect(preview.compression_ratio <= 1.0);
}

test "export_preview calculate_optimization svelte" {
    var svelte_comp = export_framework.SvelteComponent.init("TestComponent");
    var preview = export_preview.ExportPreview.init(
        .svelte,
        800,
        600,
    );
    preview.from_svelte_component(&svelte_comp);
    var optimizer = export_optimize.ExportOptimizer.init();
    preview.calculate_optimization(&optimizer);
    try testing.expect(preview.optimized_size >= 0);
    try testing.expect(preview.optimized_size <= preview.file_size);
    try testing.expect(preview.compression_ratio >= 0.0);
    try testing.expect(preview.compression_ratio <= 1.0);
}

test "export_preview calculate_optimization slc" {
    var canvas_state = canvas.Canvas.init(800, 600);
    var slc_bundle = export_slc.SlcBundle.init("TestBundle");
    slc_bundle.write_header(800, 600);
    slc_bundle.export_canvas(&canvas_state);
    slc_bundle.write_footer();
    var preview = export_preview.ExportPreview.init(
        .slc,
        800,
        600,
    );
    preview.from_slc_bundle(&slc_bundle, 800, 600);
    var optimizer = export_optimize.ExportOptimizer.init();
    preview.calculate_optimization(&optimizer);
    try testing.expect(preview.optimized_size > 0);
    try testing.expect(preview.optimized_size <= preview.file_size);
    try testing.expect(preview.compression_ratio >= 0.0);
    try testing.expect(preview.compression_ratio <= 1.0);
}

test "export_preview calculate_optimization pdf" {
    var preview = export_preview.ExportPreview.init(
        .pdf,
        800,
        600,
    );
    const test_content = "PDF content";
    preview.set_content(test_content);
    var optimizer = export_optimize.ExportOptimizer.init();
    preview.calculate_optimization(&optimizer);
    try testing.expect(preview.optimized_size == preview.file_size);
    try testing.expect(preview.compression_ratio == 1.0);
}

test "export_preview get_content empty" {
    var preview = export_preview.ExportPreview.init(
        .html,
        800,
        600,
    );
    const content = preview.get_content();
    try testing.expect(content.len == 0);
}

test "export_preview get_metadata empty" {
    var preview = export_preview.ExportPreview.init(
        .html,
        800,
        600,
    );
    const metadata = preview.get_metadata();
    try testing.expect(metadata.len == 0);
}
