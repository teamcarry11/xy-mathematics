//! Grain Bubble HTML Export: Export designs to responsive HTML.
//!
//! Why: Export designs to web-ready HTML/CSS.
//! Architecture: HTML/CSS generation with responsive design.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-020615-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");
const component = @import("component.zig");

// Bounded: Max HTML content length.
pub const MAX_HTML_CONTENT_LEN: u32 = 2 * 1024 * 1024; // 2 MB

// Bounded: Max CSS content length.
pub const MAX_CSS_CONTENT_LEN: u32 = 512 * 1024; // 512 KB

// Bounded: Max HTML class name length.
pub const MAX_CLASS_NAME_LEN: u32 = 64;

// HTML document: HTML file structure.
pub const HtmlDocument = struct {
    html_content: [MAX_HTML_CONTENT_LEN]u8,
    html_content_len: u32,
    css_content: [MAX_CSS_CONTENT_LEN]u8,
    css_content_len: u32,
    width: u32,
    height: u32,
    next_class_id: u32,

    pub fn init(width: u32, height: u32) HtmlDocument {
        std.debug.assert(width > 0);
        std.debug.assert(height <= 10000);
        std.debug.assert(height > 0);
        std.debug.assert(height <= 10000);
        var doc = HtmlDocument{
            .html_content = undefined,
            .html_content_len = 0,
            .css_content = undefined,
            .css_content_len = 0,
            .width = width,
            .height = height,
            .next_class_id = 1,
        };
        @memset(doc.html_content[0..], 0);
        @memset(doc.css_content[0..], 0);
        std.debug.assert(doc.width > 0);
        std.debug.assert(doc.height > 0);
        return doc;
    }

    // Write string to HTML content.
    fn write_html(self: *HtmlDocument, text: []const u8) void {
        std.debug.assert(text.len > 0);
        std.debug.assert(self.html_content_len + text.len <= MAX_HTML_CONTENT_LEN);
        @memcpy(
            self.html_content[self.html_content_len..self.html_content_len + text.len],
            text[0..text.len],
        );
        self.html_content_len += @as(u32, @intCast(text.len));
        std.debug.assert(self.html_content_len <= MAX_HTML_CONTENT_LEN);
    }

    // Write string to CSS content.
    fn write_css(self: *HtmlDocument, text: []const u8) void {
        std.debug.assert(text.len > 0);
        std.debug.assert(self.css_content_len + text.len <= MAX_CSS_CONTENT_LEN);
        @memcpy(
            self.css_content[self.css_content_len..self.css_content_len + text.len],
            text[0..text.len],
        );
        self.css_content_len += @as(u32, @intCast(text.len));
        std.debug.assert(self.css_content_len <= MAX_CSS_CONTENT_LEN);
    }

    // Convert ARGB color to CSS hex color.
    fn color_to_css_hex(color: u32) [7]u8 {
        const r = (color >> 24) & 0xFF;
        const g = (color >> 16) & 0xFF;
        const b = (color >> 8) & 0xFF;
        var hex: [7]u8 = undefined;
        _ = std.fmt.bufPrint(
            hex[0..],
            "#{:02X}{:02X}{:02X}",
            .{ r, g, b },
        ) catch unreachable;
        return hex;
    }

    // Write HTML header.
    pub fn write_html_header(self: *HtmlDocument) void {
        std.debug.assert(self.html_content_len == 0);
        std.debug.assert(self.css_content_len == 0);
        const header = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n";
        self.write_html(header);
        const meta = "<meta charset=\"UTF-8\">\n<meta name=\"viewport\" ";
        self.write_html(meta);
        const viewport = "content=\"width=device-width, initial-scale=1.0\">\n";
        self.write_html(viewport);
        const title = "<title>Grain Bubble Export</title>\n";
        self.write_html(title);
        const style_tag = "<style>\n";
        self.write_html(style_tag);
    }

    // Write CSS to HTML (inserts CSS into style tag).
    fn write_css_to_html(self: *HtmlDocument) void {
        std.debug.assert(self.css_content_len > 0);
        std.debug.assert(self.html_content_len + self.css_content_len <= MAX_HTML_CONTENT_LEN);
        @memcpy(
            self.html_content[self.html_content_len..self.html_content_len + self.css_content_len],
            self.css_content[0..self.css_content_len],
        );
        self.html_content_len += self.css_content_len;
        std.debug.assert(self.html_content_len <= MAX_HTML_CONTENT_LEN);
    }

    // Write HTML footer.
    pub fn write_html_footer(self: *HtmlDocument) void {
        std.debug.assert(self.html_content_len > 0);
        const style_close = "</style>\n";
        self.write_html(style_close);
        const head_close = "</head>\n<body>\n";
        self.write_html(head_close);
        const container = "<div class=\"canvas-container\">\n";
        self.write_html(container);
        const body_close = "</div>\n</body>\n</html>\n";
        self.write_html(body_close);
        std.debug.assert(self.html_content_len > 0);
    }

    // Write CSS for canvas container.
    fn write_canvas_css(self: *HtmlDocument) void {
        std.debug.assert(self.css_content_len == 0);
        var buf: [256]u8 = undefined;
        const css = std.fmt.bufPrint(
            buf[0..],
            ".canvas-container {{\n  width: {d}px;\n  height: {d}px;\n  ",
            .{ self.width, self.height },
        ) catch return;
        self.write_css(css);
        const css2 = "position: relative;\n  margin: 0 auto;\n  " ++
            "background: #ffffff;\n}}\n\n";
        self.write_css(css2);
    }

    // Export shape to HTML/CSS.
    pub fn export_shape(
        self: *HtmlDocument,
        shape: *const canvas.Shape,
    ) void {
        std.debug.assert(@intFromPtr(shape) != 0);
        var class_name_buf: [MAX_CLASS_NAME_LEN]u8 = undefined;
        const class_name = std.fmt.bufPrint(
            class_name_buf[0..],
            "shape-{}",
            .{self.next_class_id},
        ) catch return;
        self.next_class_id += 1;
        const color_hex = self.color_to_css_hex(shape.color);
        var html_buf: [512]u8 = undefined;
        const html = std.fmt.bufPrint(
            html_buf[0..],
            "  <div class=\"{s}\"></div>\n",
            .{class_name},
        ) catch return;
        self.write_html(html);
        var css_buf: [512]u8 = undefined;
        const css = std.fmt.bufPrint(
            css_buf[0..],
            ".{s} {{\n  position: absolute;\n  left: {d:.1f}px;\n  ",
            .{ class_name, shape.x },
        ) catch return;
        self.write_css(css);
        const css2 = std.fmt.bufPrint(
            css_buf[0..],
            "top: {d:.1f}px;\n  width: {d:.1f}px;\n  height: {d:.1f}px;\n  ",
            .{ shape.y, shape.width, shape.height },
        ) catch return;
        self.write_css(css2);
        const css3 = std.fmt.bufPrint(
            css_buf[0..],
            "background-color: {s};\n",
            .{color_hex},
        ) catch return;
        self.write_css(css3);
        switch (shape.shape_type) {
            .rectangle => {
                const css4 = "  border-radius: 0;\n";
                self.write_css(css4);
            },
            .circle => {
                const css4 = "  border-radius: 50%;\n";
                self.write_css(css4);
            },
            .rounded_rectangle => {
                const css4 = std.fmt.bufPrint(
                    css_buf[0..],
                    "  border-radius: {d:.1f}px;\n",
                    .{shape.corner_radius},
                ) catch return;
                self.write_css(css4);
            },
        }
        if (shape.stroke_width > 0.0) {
            const stroke_hex = self.color_to_css_hex(shape.stroke_color);
            const css5 = std.fmt.bufPrint(
                css_buf[0..],
                "  border: {d:.1f}px solid {s};\n",
                .{ shape.stroke_width, stroke_hex },
            ) catch return;
            self.write_css(css5);
        }
        const css_close = "}\n\n";
        self.write_css(css_close);
    }

    // Export text to HTML/CSS.
    pub fn export_text(
        self: *HtmlDocument,
        text: *const canvas.Text,
    ) void {
        std.debug.assert(@intFromPtr(text) != 0);
        var class_name_buf: [MAX_CLASS_NAME_LEN]u8 = undefined;
        const class_name = std.fmt.bufPrint(
            class_name_buf[0..],
            "text-{}",
            .{self.next_class_id},
        ) catch return;
        self.next_class_id += 1;
        const color_hex = self.color_to_css_hex(text.color);
        const text_content = text.content[0..text.content_len];
        var html_buf: [512]u8 = undefined;
        const html = std.fmt.bufPrint(
            html_buf[0..],
            "  <div class=\"{s}\">{s}</div>\n",
            .{ class_name, text_content },
        ) catch return;
        self.write_html(html);
        var css_buf: [512]u8 = undefined;
        const css = std.fmt.bufPrint(
            css_buf[0..],
            ".{s} {{\n  position: absolute;\n  left: {d:.1f}px;\n  ",
            .{ class_name, text.x },
        ) catch return;
        self.write_css(css);
        const css2 = std.fmt.bufPrint(
            css_buf[0..],
            "top: {d:.1f}px;\n  font-size: {d}px;\n  color: {s};\n}}\n\n",
            .{ text.y, text.font_size, color_hex },
        ) catch return;
        self.write_css(css2);
    }

    // Export canvas to HTML.
    pub fn export_canvas(
        self: *HtmlDocument,
        canvas_state: *const canvas.Canvas,
    ) void {
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        self.write_html_header();
        self.write_canvas_css();
        var layer_i: u32 = 0;
        while (layer_i < canvas_state.layers_len) : (layer_i += 1) {
            const layer = &canvas_state.layers[layer_i];
            if (!layer.visible) {
                continue;
            }
            var shape_i: u32 = 0;
            while (shape_i < layer.shapes_len) : (shape_i += 1) {
                self.export_shape(&layer.shapes[shape_i]);
            }
            var text_i: u32 = 0;
            while (text_i < layer.texts_len) : (text_i += 1) {
                self.export_text(&layer.texts[text_i]);
            }
        }
        self.write_css_to_html();
        self.write_html_footer();
    }

    // Export component variant to HTML.
    pub fn export_component_variant(
        self: *HtmlDocument,
        variant: *const component.ComponentVariant,
    ) void {
        std.debug.assert(@intFromPtr(variant) != 0);
        var shape_i: u32 = 0;
        while (shape_i < variant.shapes_len) : (shape_i += 1) {
            self.export_shape(&variant.shapes[shape_i]);
        }
        var text_i: u32 = 0;
        while (text_i < variant.texts_len) : (text_i += 1) {
            self.export_text(&variant.texts[text_i]);
        }
    }

    // Get HTML content as slice.
    pub fn get_html_content(self: *const HtmlDocument) []const u8 {
        std.debug.assert(self.html_content_len > 0);
        std.debug.assert(self.html_content_len <= MAX_HTML_CONTENT_LEN);
        return self.html_content[0..self.html_content_len];
    }

    // Get CSS content as slice.
    pub fn get_css_content(self: *const HtmlDocument) []const u8 {
        std.debug.assert(self.css_content_len <= MAX_CSS_CONTENT_LEN);
        return self.css_content[0..self.css_content_len];
    }
};

