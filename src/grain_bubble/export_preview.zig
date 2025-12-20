//! Grain Bubble Export Preview: Preview exported designs.
//!
//! Why: Allow users to preview exports before finalizing.
//! Architecture: Preview data generation and metadata.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-143300-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");
const component = @import("component.zig");
const export_html = @import("export_html.zig");
const export_framework = @import("export_framework.zig");
const export_slc = @import("export_slc.zig");
const export_optimize = @import("export_optimize.zig");

// Bounded: Max preview content length.
pub const MAX_PREVIEW_CONTENT_LEN: u32 = 4 * 1024 * 1024; // 4 MB

// Bounded: Max preview metadata length.
pub const MAX_PREVIEW_METADATA_LEN: u32 = 1024; // 1 KB

// Preview format type.
pub const PreviewFormat = enum(u8) {
    html = 0,
    svelte = 1,
    slc = 2,
    pdf = 3,
};

// Export preview: preview data for exported designs.
pub const ExportPreview = struct {
    format: PreviewFormat,
    content: [MAX_PREVIEW_CONTENT_LEN]u8,
    content_len: u32,
    metadata: [MAX_PREVIEW_METADATA_LEN]u8,
    metadata_len: u32,
    width: u32,
    height: u32,
    file_size: u32,
    optimized_size: u32,
    compression_ratio: f32,

    pub fn init(format: PreviewFormat, width: u32, height: u32) ExportPreview {
        std.debug.assert(width > 0);
        std.debug.assert(width <= 10000);
        std.debug.assert(height > 0);
        std.debug.assert(height <= 10000);
        var preview = ExportPreview{
            .format = format,
            .content = undefined,
            .content_len = 0,
            .metadata = undefined,
            .metadata_len = 0,
            .width = width,
            .height = height,
            .file_size = 0,
            .optimized_size = 0,
            .compression_ratio = 0.0,
        };
        @memset(preview.content[0..], 0);
        @memset(preview.metadata[0..], 0);
        std.debug.assert(preview.width > 0);
        std.debug.assert(preview.height > 0);
        return preview;
    }

    // Set preview content.
    pub fn set_content(self: *ExportPreview, content: []const u8) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(content.len > 0);
        std.debug.assert(content.len <= MAX_PREVIEW_CONTENT_LEN);
        const copy_len = @min(content.len, MAX_PREVIEW_CONTENT_LEN);
        @memcpy(self.content[0..copy_len], content[0..copy_len]);
        self.content_len = @as(u32, @intCast(copy_len));
        self.file_size = @as(u32, @intCast(copy_len));
        std.debug.assert(self.content_len > 0);
        std.debug.assert(self.content_len <= MAX_PREVIEW_CONTENT_LEN);
    }

    // Set preview metadata.
    pub fn set_metadata(self: *ExportPreview, metadata: []const u8) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(metadata.len > 0);
        std.debug.assert(metadata.len <= MAX_PREVIEW_METADATA_LEN);
        const copy_len = @min(metadata.len, MAX_PREVIEW_METADATA_LEN);
        @memcpy(self.metadata[0..copy_len], metadata[0..copy_len]);
        self.metadata_len = @as(u32, @intCast(copy_len));
        std.debug.assert(self.metadata_len > 0);
        std.debug.assert(self.metadata_len <= MAX_PREVIEW_METADATA_LEN);
    }

    // Calculate optimized size and compression ratio.
    pub fn calculate_optimization(
        self: *ExportPreview,
        optimizer: *export_optimize.ExportOptimizer,
    ) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(optimizer) != 0);
        std.debug.assert(self.content_len > 0);
        if (self.format == .html or self.format == .slc) {
            var optimized_buffer: [MAX_PREVIEW_CONTENT_LEN]u8 = undefined;
            const optimized_len = optimizer.minify_html_content(
                self.content[0..self.content_len],
                &optimized_buffer,
            );
            self.optimized_size = optimized_len;
            self.compression_ratio = optimizer.calculate_compression_ratio(
                self.file_size,
                optimized_len,
            );
            std.debug.assert(self.optimized_size <= self.file_size);
            std.debug.assert(self.compression_ratio >= 0.0);
            std.debug.assert(self.compression_ratio <= 1.0);
        } else if (self.format == .svelte) {
            var optimized_buffer: [MAX_PREVIEW_CONTENT_LEN]u8 = undefined;
            const optimized_len = optimizer.minify_html_content(
                self.content[0..self.content_len],
                &optimized_buffer,
            );
            self.optimized_size = optimized_len;
            self.compression_ratio = optimizer.calculate_compression_ratio(
                self.file_size,
                optimized_len,
            );
            std.debug.assert(self.optimized_size <= self.file_size);
            std.debug.assert(self.compression_ratio >= 0.0);
            std.debug.assert(self.compression_ratio <= 1.0);
        } else {
            // PDF doesn't need optimization in preview.
            self.optimized_size = self.file_size;
            self.compression_ratio = 1.0;
        }
    }

    // Generate preview from HTML document.
    pub fn from_html_document(
        self: *ExportPreview,
        html_doc: *export_html.HtmlDocument,
    ) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(html_doc) != 0);
        std.debug.assert(html_doc.html_content_len > 0);
        self.format = .html;
        self.width = html_doc.width;
        self.height = html_doc.height;
        const html_content = html_doc.get_html_content();
        const html_len = @min(html_content.len, MAX_PREVIEW_CONTENT_LEN);
        @memcpy(self.content[0..html_len], html_content[0..html_len]);
        self.content_len = @as(u32, @intCast(html_len));
        self.file_size = @as(u32, @intCast(html_len));
        const metadata_str = std.fmt.bufPrint(
            &self.metadata,
            "HTML Export: {}x{}px, {} bytes",
            .{ self.width, self.height, self.content_len },
        ) catch |_| {
            self.metadata_len = 0;
            return;
        };
        self.set_metadata(metadata_str);
        std.debug.assert(self.content_len > 0);
    }

    // Generate preview from Svelte component.
    pub fn from_svelte_component(
        self: *ExportPreview,
        svelte_comp: *export_framework.SvelteComponent,
    ) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(svelte_comp) != 0);
        std.debug.assert(svelte_comp.template_content_len > 0);
        self.format = .svelte;
        const svelte_content = svelte_comp.get_content();
        self.set_content(svelte_content);
        const metadata_str = std.fmt.bufPrint(
            &self.metadata,
            "Svelte Component: {} bytes",
            .{self.content_len},
        ) catch |_| {
            self.metadata_len = 0;
            return;
        };
        self.set_metadata(metadata_str);
        std.debug.assert(self.content_len > 0);
    }

    // Generate preview from SLC bundle.
    pub fn from_slc_bundle(
        self: *ExportPreview,
        slc_bundle: *export_slc.SlcBundle,
        width: u32,
        height: u32,
    ) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(slc_bundle) != 0);
        std.debug.assert(slc_bundle.content_len > 0);
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        self.format = .slc;
        self.width = width;
        self.height = height;
        const slc_content = slc_bundle.get_content();
        self.set_content(slc_content);
        const metadata_str = std.fmt.bufPrint(
            &self.metadata,
            "SLC Bundle: {}x{}px, {} bytes",
            .{ self.width, self.height, self.content_len },
        ) catch |_| {
            self.metadata_len = 0;
            return;
        };
        self.set_metadata(metadata_str);
        std.debug.assert(self.content_len > 0);
    }

    // Get preview content as slice.
    pub fn get_content(self: *const ExportPreview) []const u8 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(self.content_len > 0);
        return self.content[0..self.content_len];
    }

    // Get preview metadata as slice.
    pub fn get_metadata(self: *const ExportPreview) []const u8 {
        std.debug.assert(@intFromPtr(self) != 0);
        if (self.metadata_len == 0) {
            return "";
        }
        return self.metadata[0..self.metadata_len];
    }
};
