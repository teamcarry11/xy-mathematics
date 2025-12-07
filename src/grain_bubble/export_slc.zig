//! Grain Bubble SLC Export: Export designs to SLC asset bundles.
//!
//! Why: Export self-contained, ready-to-deploy demo bundles.
//! Architecture: Single-file HTML bundles with embedded CSS/JS.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-030523-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");
const component = @import("component.zig");

// Bounded: Max SLC bundle content length.
pub const MAX_SLC_CONTENT_LEN: u32 = 4 * 1024 * 1024; // 4 MB

// Bounded: Max class name length.
pub const MAX_CLASS_NAME_LEN: u32 = 64;

// SLC bundle: Self-contained HTML bundle.
pub const SlcBundle = struct {
    content: [MAX_SLC_CONTENT_LEN]u8,
    content_len: u32,
    next_class_id: u32,
    bundle_name: [64]u8,
    bundle_name_len: u32,

    pub fn init(name: []const u8) SlcBundle {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= 64);
        var bundle = SlcBundle{
            .content = undefined,
            .content_len = 0,
            .next_class_id = 1,
            .bundle_name = undefined,
            .bundle_name_len = 0,
        };
        @memset(bundle.content[0..], 0);
        @memset(bundle.bundle_name[0..], 0);
        const name_len = @min(name.len, 64);
        @memcpy(bundle.bundle_name[0..name_len], name[0..name_len]);
        bundle.bundle_name_len = @as(u32, @intCast(name_len));
        std.debug.assert(bundle.bundle_name_len > 0);
        return bundle;
    }

    // Write string to content.
    fn write_content(self: *SlcBundle, text: []const u8) void {
        std.debug.assert(text.len > 0);
        std.debug.assert(self.content_len + text.len <= MAX_SLC_CONTENT_LEN);
        @memcpy(
            self.content[self.content_len..self.content_len + text.len],
            text[0..text.len],
        );
        self.content_len += @as(u32, @intCast(text.len));
        std.debug.assert(self.content_len <= MAX_SLC_CONTENT_LEN);
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

    // Write HTML header with embedded styles.
    pub fn write_header(self: *SlcBundle, width: u32, height: u32) void {
        std.debug.assert(self.content_len == 0);
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        const header = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n";
        self.write_content(header);
        const meta = "<meta charset=\"UTF-8\">\n<meta name=\"viewport\" ";
        self.write_content(meta);
        const viewport = "content=\"width=device-width, initial-scale=1.0\">\n";
        self.write_content(viewport);
        const title = "<title>SLC Bundle</title>\n";
        self.write_content(title);
        const style_tag = "<style>\n";
        self.write_content(style_tag);
        var css_buf: [256]u8 = undefined;
        const container_css = std.fmt.bufPrint(
            css_buf[0..],
            "body {{\n  margin: 0;\n  padding: 0;\n  ",
            .{},
        ) catch return;
        self.write_content(container_css);
        const container_css2 = std.fmt.bufPrint(
            css_buf[0..],
            "font-family: system-ui, -apple-system, sans-serif;\n}}\n\n",
            .{},
        ) catch return;
        self.write_content(container_css2);
        const canvas_css = std.fmt.bufPrint(
            css_buf[0..],
            ".slc-canvas {{\n  width: {d}px;\n  height: {d}px;\n  ",
            .{ width, height },
        ) catch return;
        self.write_content(canvas_css);
        const canvas_css2 = "position: relative;\n  margin: 0 auto;\n  " ++
            "background: #ffffff;\n  box-shadow: 0 2px 8px rgba(0,0,0,0.1);\n}}\n\n";
        self.write_content(canvas_css2);
    }

    // Write HTML footer.
    pub fn write_footer(self: *SlcBundle) void {
        std.debug.assert(self.content_len > 0);
        const style_close = "</style>\n";
        self.write_content(style_close);
        const head_close = "</head>\n<body>\n";
        self.write_content(head_close);
        const container = "<div class=\"slc-canvas\">\n";
        self.write_content(container);
        const body_close = "</div>\n</body>\n</html>\n";
        self.write_content(body_close);
        std.debug.assert(self.content_len > 0);
    }

    // Export shape to SLC bundle.
    pub fn export_shape(
        self: *SlcBundle,
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
            "    <div class=\"{s}\"></div>\n",
            .{class_name},
        ) catch return;
        self.write_content(html);
        var css_buf: [512]u8 = undefined;
        const css = std.fmt.bufPrint(
            css_buf[0..],
            ".{s} {{\n  position: absolute;\n  left: {d:.1f}px;\n  ",
            .{ class_name, shape.x },
        ) catch return;
        self.write_content(css);
        const css2 = std.fmt.bufPrint(
            css_buf[0..],
            "top: {d:.1f}px;\n  width: {d:.1f}px;\n  height: {d:.1f}px;\n  ",
            .{ shape.y, shape.width, shape.height },
        ) catch return;
        self.write_content(css2);
        const css3 = std.fmt.bufPrint(
            css_buf[0..],
            "background-color: {s};\n",
            .{color_hex},
        ) catch return;
        self.write_content(css3);
        switch (shape.shape_type) {
            .rectangle => {
                const css4 = "  border-radius: 0;\n";
                self.write_content(css4);
            },
            .circle => {
                const css4 = "  border-radius: 50%;\n";
                self.write_content(css4);
            },
            .rounded_rectangle => {
                const css4 = std.fmt.bufPrint(
                    css_buf[0..],
                    "  border-radius: {d:.1f}px;\n",
                    .{shape.corner_radius},
                ) catch return;
                self.write_content(css4);
            },
        }
        if (shape.stroke_width > 0.0) {
            const stroke_hex = self.color_to_css_hex(shape.stroke_color);
            const css5 = std.fmt.bufPrint(
                css_buf[0..],
                "  border: {d:.1f}px solid {s};\n",
                .{ shape.stroke_width, stroke_hex },
            ) catch return;
            self.write_content(css5);
        }
        const css_close = "}\n\n";
        self.write_content(css_close);
    }

    // Export text to SLC bundle.
    pub fn export_text(
        self: *SlcBundle,
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
            "    <div class=\"{s}\">{s}</div>\n",
            .{ class_name, text_content },
        ) catch return;
        self.write_content(html);
        var css_buf: [512]u8 = undefined;
        const css = std.fmt.bufPrint(
            css_buf[0..],
            ".{s} {{\n  position: absolute;\n  left: {d:.1f}px;\n  ",
            .{ class_name, text.x },
        ) catch return;
        self.write_content(css);
        const css2 = std.fmt.bufPrint(
            css_buf[0..],
            "top: {d:.1f}px;\n  font-size: {d}px;\n  color: {s};\n}}\n\n",
            .{ text.y, text.font_size, color_hex },
        ) catch return;
        self.write_content(css2);
    }

    // Export canvas to SLC bundle.
    pub fn export_canvas(
        self: *SlcBundle,
        canvas_state: *const canvas.Canvas,
    ) void {
        std.debug.assert(@intFromPtr(canvas_state) != 0);
        const width = canvas_state.viewport.width;
        const height = canvas_state.viewport.height;
        self.write_header(width, height);
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
        self.write_footer();
    }

    // Export component variant to SLC bundle.
    pub fn export_component_variant(
        self: *SlcBundle,
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

    // Get SLC bundle content as slice.
    pub fn get_content(self: *const SlcBundle) []const u8 {
        std.debug.assert(self.content_len > 0);
        std.debug.assert(self.content_len <= MAX_SLC_CONTENT_LEN);
        return self.content[0..self.content_len];
    }

    // Get bundle name as slice.
    pub fn get_bundle_name(self: *const SlcBundle) []const u8 {
        std.debug.assert(self.bundle_name_len > 0);
        return self.bundle_name[0..self.bundle_name_len];
    }
};

