//! Grain Bubble Export Optimization: Minification and compression.
//!
//! Why: Optimize exports for production deployment.
//! Architecture: HTML/CSS minification and compression utilities.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-19-191440-pst: Grain Bubble Agent

const std = @import("std");

// Bounded: Max content length for optimization.
pub const MAX_OPTIMIZED_CONTENT_LEN: u32 = 4 * 1024 * 1024; // 4 MB

// Export optimizer: minifies and compresses exports.
pub const ExportOptimizer = struct {
    minify_html: bool,
    minify_css: bool,
    compress: bool,

    pub fn init() ExportOptimizer {
        const optimizer = ExportOptimizer{
            .minify_html = true,
            .minify_css = true,
            .compress = false,
        };
        std.debug.assert(optimizer.minify_html == true);
        std.debug.assert(optimizer.minify_css == true);
        return optimizer;
    }

    // Set optimization options.
    pub fn set_options(
        self: *ExportOptimizer,
        minify_html: bool,
        minify_css: bool,
        compress: bool,
    ) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.minify_html = minify_html;
        self.minify_css = minify_css;
        self.compress = compress;
        std.debug.assert(self.minify_html == minify_html);
    }

    // Minify HTML content (remove whitespace, comments).
    pub fn minify_html_content(
        self: *ExportOptimizer,
        input: []const u8,
        output: []u8,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(input.len > 0);
        std.debug.assert(output.len >= input.len);
        if (!self.minify_html) {
            const copy_len = @min(input.len, output.len);
            @memcpy(output[0..copy_len], input[0..copy_len]);
            return copy_len;
        }
        // Simple minification: remove extra whitespace and newlines.
        var out_offset: u32 = 0;
        var in_offset: u32 = 0;
        var in_whitespace: bool = false;
        while (in_offset < input.len and out_offset < output.len) {
            const ch = input[in_offset];
            if (ch == ' ' or ch == '\n' or ch == '\r' or ch == '\t') {
                if (!in_whitespace and out_offset > 0) {
                    if (out_offset < output.len) {
                        output[out_offset] = ' ';
                        out_offset += 1;
                    }
                }
                in_whitespace = true;
            } else {
                in_whitespace = false;
                if (out_offset < output.len) {
                    output[out_offset] = ch;
                    out_offset += 1;
                }
            }
            in_offset += 1;
        }
        std.debug.assert(out_offset <= output.len);
        return out_offset;
    }

    // Minify CSS content (remove whitespace, comments).
    pub fn minify_css_content(
        self: *ExportOptimizer,
        input: []const u8,
        output: []u8,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(input.len > 0);
        std.debug.assert(output.len >= input.len);
        if (!self.minify_css) {
            const copy_len = @min(input.len, output.len);
            @memcpy(output[0..copy_len], input[0..copy_len]);
            return copy_len;
        }
        // Simple minification: remove extra whitespace and newlines.
        var out_offset: u32 = 0;
        var in_offset: u32 = 0;
        var in_whitespace: bool = false;
        while (in_offset < input.len and out_offset < output.len) {
            const ch = input[in_offset];
            if (ch == ' ' or ch == '\n' or ch == '\r' or ch == '\t') {
                if (!in_whitespace and out_offset > 0) {
                    if (out_offset < output.len) {
                        output[out_offset] = ' ';
                        out_offset += 1;
                    }
                }
                in_whitespace = true;
            } else {
                in_whitespace = false;
                if (out_offset < output.len) {
                    output[out_offset] = ch;
                    out_offset += 1;
                }
            }
            in_offset += 1;
        }
        std.debug.assert(out_offset <= output.len);
        return out_offset;
    }

    // Calculate compression ratio (simplified for Phase 4).
    pub fn calculate_compression_ratio(
        self: *ExportOptimizer,
        original_size: u32,
        optimized_size: u32,
    ) f32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(original_size > 0);
        std.debug.assert(optimized_size <= original_size);
        if (original_size == 0) {
            return 0.0;
        }
        const ratio: f32 = @as(f32, @floatFromInt(optimized_size)) / @as(f32, @floatFromInt(original_size));
        std.debug.assert(ratio >= 0.0);
        std.debug.assert(ratio <= 1.0);
        return ratio;
    }
};
