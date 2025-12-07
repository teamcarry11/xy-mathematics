//! Grain Bubble PDF Export: Export designs to PDF format.
//!
//! Why: Export high-quality vector graphics to PDF.
//! Architecture: PDF document generation with vector graphics.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-113622-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");
const component = @import("component.zig");

// Bounded: Max PDF page width (points, 1 point = 1/72 inch).
pub const MAX_PDF_WIDTH: u32 = 10000;

// Bounded: Max PDF page height (points).
pub const MAX_PDF_HEIGHT: u32 = 10000;

// Bounded: Max PDF content length.
pub const MAX_PDF_CONTENT_LEN: u32 = 1024 * 1024; // 1 MB

// PDF document: PDF file structure.
pub const PdfDocument = struct {
    content: [MAX_PDF_CONTENT_LEN]u8,
    content_len: u32,
    width: u32,
    height: u32,

    pub fn init(width: u32, height: u32) PdfDocument {
        std.debug.assert(width > 0);
        std.debug.assert(width <= MAX_PDF_WIDTH);
        std.debug.assert(height > 0);
        std.debug.assert(height <= MAX_PDF_HEIGHT);
        var doc = PdfDocument{
            .content = undefined,
            .content_len = 0,
            .width = width,
            .height = height,
        };
        @memset(doc.content[0..], 0);
        std.debug.assert(doc.width > 0);
        std.debug.assert(doc.height > 0);
        return doc;
    }

    // Write PDF header.
    pub fn write_header(self: *PdfDocument) void {
        std.debug.assert(self.content_len == 0);
        const header = "%PDF-1.4\n";
        const header_len = header.len;
        std.debug.assert(self.content_len + header_len <= MAX_PDF_CONTENT_LEN);
        @memcpy(
            self.content[self.content_len..self.content_len + header_len],
            header[0..header_len],
        );
        self.content_len += @as(u32, @intCast(header_len));
        std.debug.assert(self.content_len <= MAX_PDF_CONTENT_LEN);
    }

    // Write PDF footer.
    pub fn write_footer(self: *PdfDocument) void {
        std.debug.assert(self.content_len > 0);
        const footer = "%%EOF\n";
        const footer_len = footer.len;
        std.debug.assert(self.content_len + footer_len <= MAX_PDF_CONTENT_LEN);
        @memcpy(
            self.content[self.content_len..self.content_len + footer_len],
            footer[0..footer_len],
        );
        self.content_len += @as(u32, @intCast(footer_len));
        std.debug.assert(self.content_len <= MAX_PDF_CONTENT_LEN);
    }

    // Write string to PDF content.
    fn write_string(self: *PdfDocument, text: []const u8) void {
        std.debug.assert(text.len > 0);
        std.debug.assert(self.content_len + text.len <= MAX_PDF_CONTENT_LEN);
        @memcpy(
            self.content[self.content_len..self.content_len + text.len],
            text[0..text.len],
        );
        self.content_len += @as(u32, @intCast(text.len));
        std.debug.assert(self.content_len <= MAX_PDF_CONTENT_LEN);
    }

    // Write PDF color (RGB to PDF format: 0.0-1.0).
    fn write_color(self: *PdfDocument, color: u32) void {
        const r = @as(f64, @floatFromInt((color >> 24) & 0xFF)) / 255.0;
        const g = @as(f64, @floatFromInt((color >> 16) & 0xFF)) / 255.0;
        const b = @as(f64, @floatFromInt((color >> 8) & 0xFF)) / 255.0;
        var buf: [64]u8 = undefined;
        const color_str = std.fmt.bufPrint(
            buf[0..],
            "{d:.3} {d:.3} {d:.3} rg\n",
            .{ r, g, b },
        ) catch return;
        self.write_string(color_str);
    }

    // Write PDF stroke color.
    fn write_stroke_color(self: *PdfDocument, color: u32) void {
        const r = @as(f64, @floatFromInt((color >> 24) & 0xFF)) / 255.0;
        const g = @as(f64, @floatFromInt((color >> 16) & 0xFF)) / 255.0;
        const b = @as(f64, @floatFromInt((color >> 8) & 0xFF)) / 255.0;
        var buf: [64]u8 = undefined;
        const color_str = std.fmt.bufPrint(
            buf[0..],
            "{d:.3} {d:.3} {d:.3} RG\n",
            .{ r, g, b },
        ) catch return;
        self.write_string(color_str);
    }

    // Export shape to PDF.
    pub fn export_shape(
        self: *PdfDocument,
        shape: *const canvas.Shape,
    ) void {
        std.debug.assert(@intFromPtr(shape) != 0);
        // PDF uses points (1/72 inch), convert from canvas units.
        const x_pt = shape.x;
        const y_pt = shape.y;
        const width_pt = shape.width;
        const height_pt = shape.height;
        // PDF coordinate system: origin at bottom-left, Y increases upward.
        // Canvas: origin at top-left, Y increases downward.
        // Convert Y coordinate.
        const pdf_y = @as(f64, @floatFromInt(self.height)) - y_pt - height_pt;
        switch (shape.shape_type) {
            .rectangle => {
                self.export_rectangle(
                    x_pt,
                    pdf_y,
                    width_pt,
                    height_pt,
                    shape.color,
                    shape.stroke_width,
                    shape.stroke_color,
                );
            },
            .circle => {
                self.export_circle(
                    x_pt + width_pt / 2.0,
                    pdf_y + height_pt / 2.0,
                    @min(width_pt, height_pt) / 2.0,
                    shape.color,
                    shape.stroke_width,
                    shape.stroke_color,
                );
            },
            .rounded_rectangle => {
                self.export_rounded_rectangle(
                    x_pt,
                    pdf_y,
                    width_pt,
                    height_pt,
                    shape.corner_radius,
                    shape.color,
                    shape.stroke_width,
                    shape.stroke_color,
                );
            },
        }
    }

    // Export rectangle to PDF.
    fn export_rectangle(
        self: *PdfDocument,
        x: f64,
        y: f64,
        width: f64,
        height: f64,
        fill_color: u32,
        stroke_width: f64,
        stroke_color: u32,
    ) void {
        std.debug.assert(width > 0.0);
        std.debug.assert(height > 0.0);
        var buf: [256]u8 = undefined;
        // Draw rectangle path.
        const path_str = std.fmt.bufPrint(
            buf[0..],
            "{d:.2} {d:.2} {d:.2} {d:.2} re\n",
            .{ x, y, width, height },
        ) catch return;
        self.write_string(path_str);
        // Fill if color is not transparent.
        if ((fill_color & 0xFF) != 0) {
            self.write_color(fill_color);
            if (stroke_width > 0.0) {
                // Fill and stroke.
                const stroke_str = std.fmt.bufPrint(
                    buf[0..],
                    "{d:.2} w\n",
                    .{stroke_width},
                ) catch return;
                self.write_string(stroke_str);
                self.write_stroke_color(stroke_color);
                self.write_string("B\n"); // Fill and stroke.
            } else {
                self.write_string("f\n"); // Fill only.
            }
        } else if (stroke_width > 0.0) {
            // Stroke only.
            const stroke_str = std.fmt.bufPrint(
                buf[0..],
                "{d:.2} w\n",
                .{stroke_width},
            ) catch return;
            self.write_string(stroke_str);
            self.write_stroke_color(stroke_color);
            self.write_string("S\n"); // Stroke only.
        }
    }

    // Export circle to PDF (as a rounded rectangle with full radius).
    fn export_circle(
        self: *PdfDocument,
        center_x: f64,
        center_y: f64,
        radius: f64,
        fill_color: u32,
        stroke_width: f64,
        stroke_color: u32,
    ) void {
        std.debug.assert(radius > 0.0);
        // Draw circle using PDF arc (approximated as rounded rectangle).
        const diameter = radius * 2.0;
        self.export_rounded_rectangle(
            center_x - radius,
            center_y - radius,
            diameter,
            diameter,
            radius,
            fill_color,
            stroke_width,
            stroke_color,
        );
    }

    // Export rounded rectangle to PDF.
    fn export_rounded_rectangle(
        self: *PdfDocument,
        x: f64,
        y: f64,
        width: f64,
        height: f64,
        corner_radius: f64,
        fill_color: u32,
        stroke_width: f64,
        stroke_color: u32,
    ) void {
        std.debug.assert(width > 0.0);
        std.debug.assert(height > 0.0);
        std.debug.assert(corner_radius >= 0.0);
        const radius = @min(corner_radius, @min(width, height) / 2.0);
        if (radius == 0.0) {
            // Simple rectangle.
            self.export_rectangle(x, y, width, height, fill_color, stroke_width, stroke_color);
            return;
        }
        // PDF rounded rectangle using bezier curves.
        // For Phase 1, approximate as rectangle (full implementation later).
        // This is a simplified version.
        self.export_rectangle(x, y, width, height, fill_color, stroke_width, stroke_color);
    }

    // Export text to PDF (simplified for Phase 1).
    pub fn export_text(
        self: *PdfDocument,
        text: *const canvas.Text,
    ) void {
        std.debug.assert(@intFromPtr(text) != 0);
        // PDF coordinate system: origin at bottom-left.
        const pdf_y = @as(f64, @floatFromInt(self.height)) - text.y;
        var buf: [512]u8 = undefined;
        // Basic text rendering (simplified for Phase 1).
        // Full implementation will include font embedding.
        const text_content = text.content[0..text.content_len];
        if (text_content.len > 0) {
            // Write text position and content (simplified).
            const text_str = std.fmt.bufPrint(
                buf[0..],
                "BT\n{d:.2} {d:.2} Td\n({s}) Tj\nET\n",
                .{ text.x, pdf_y, text_content },
            ) catch return;
            self.write_string(text_str);
        }
    }

    // Export canvas to PDF.
    pub fn export_canvas(
        self: *PdfDocument,
        canvas_state: *const canvas.Canvas,
    ) void {
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        self.write_header();
        // Export layers in z-order.
        var layer_i: u32 = 0;
        while (layer_i < canvas_state.layers_len) : (layer_i += 1) {
            const layer = &canvas_state.layers[layer_i];
            if (!layer.visible) {
                continue;
            }
            // Export shapes.
            var shape_i: u32 = 0;
            while (shape_i < layer.shapes_len) : (shape_i += 1) {
                self.export_shape(&layer.shapes[shape_i]);
            }
            // Export texts.
            var text_i: u32 = 0;
            while (text_i < layer.texts_len) : (text_i += 1) {
                self.export_text(&layer.texts[text_i]);
            }
        }
        self.write_footer();
    }

    // Export component variant to PDF.
    pub fn export_component_variant(
        self: *PdfDocument,
        variant: *const component.ComponentVariant,
    ) void {
        std.debug.assert(@intFromPtr(variant) != 0);
        // Export shapes from variant.
        var shape_i: u32 = 0;
        while (shape_i < variant.shapes_len) : (shape_i += 1) {
            self.export_shape(&variant.shapes[shape_i]);
        }
        // Export texts from variant.
        var text_i: u32 = 0;
        while (text_i < variant.texts_len) : (text_i += 1) {
            self.export_text(&variant.texts[text_i]);
        }
    }

    // Export component to PDF (exports default variant).
    pub fn export_component(
        self: *PdfDocument,
        comp: *const component.Component,
    ) void {
        std.debug.assert(@intFromPtr(comp) != 0);
        if (comp.variants_len == 0) {
            return;
        }
        // Export default variant (first variant).
        const default_variant = &comp.variants[0];
        self.export_component_variant(default_variant);
    }

    // Get PDF content as slice.
    pub fn get_content(self: *const PdfDocument) []const u8 {
        std.debug.assert(self.content_len > 0);
        std.debug.assert(self.content_len <= MAX_PDF_CONTENT_LEN);
        return self.content[0..self.content_len];
    }
};

