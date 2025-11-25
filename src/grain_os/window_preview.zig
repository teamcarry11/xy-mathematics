//! Grain OS Window Preview: Thumbnail generation for windows.
//!
//! Why: Provide visual previews of windows for switching and taskbar.
//! Architecture: Window thumbnail generation and caching.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");
const framebuffer_renderer = @import("framebuffer_renderer.zig");

// Bounded: Max preview cache size.
pub const MAX_PREVIEW_CACHE: u32 = 256;

// Bounded: Preview thumbnail dimensions.
pub const PREVIEW_WIDTH: u32 = 160;
pub const PREVIEW_HEIGHT: u32 = 90;

// Preview entry: cached window thumbnail.
pub const WindowPreview = struct {
    window_id: u32,
    width: u32,
    height: u32,
    pixels: [PREVIEW_WIDTH * PREVIEW_HEIGHT]u32,
    valid: bool,
    timestamp: u64, // Last update timestamp.

    pub fn init(window_id: u32) WindowPreview {
        std.debug.assert(window_id > 0);
        var preview = WindowPreview{
            .window_id = window_id,
            .width = PREVIEW_WIDTH,
            .height = PREVIEW_HEIGHT,
            .pixels = undefined,
            .valid = false,
            .timestamp = 0,
        };
        var i: u32 = 0;
        while (i < PREVIEW_WIDTH * PREVIEW_HEIGHT) : (i += 1) {
            preview.pixels[i] = 0;
        }
        return preview;
    }

    // Clear preview (mark invalid).
    pub fn clear(self: *WindowPreview) void {
        self.valid = false;
        self.timestamp = 0;
    }
};

// Preview manager: manages window preview cache.
pub const PreviewManager = struct {
    previews: [MAX_PREVIEW_CACHE]WindowPreview,
    previews_len: u32,

    pub fn init() PreviewManager {
        var manager = PreviewManager{
            .previews = undefined,
            .previews_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_PREVIEW_CACHE) : (i += 1) {
            manager.previews[i] = WindowPreview.init(0);
        }
        return manager;
    }

    // Get or create preview for window.
    pub fn get_preview(
        self: *PreviewManager,
        window_id: u32,
    ) ?*WindowPreview {
        std.debug.assert(window_id > 0);
        // Find existing preview.
        var i: u32 = 0;
        while (i < self.previews_len) : (i += 1) {
            if (self.previews[i].window_id == window_id) {
                return &self.previews[i];
            }
        }
        // Create new preview if space available.
        if (self.previews_len >= MAX_PREVIEW_CACHE) {
            return null;
        }
        self.previews[self.previews_len] = WindowPreview.init(window_id);
        self.previews_len += 1;
        return &self.previews[self.previews_len - 1];
    }

    // Remove preview for window.
    pub fn remove_preview(self: *PreviewManager, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.previews_len) : (i += 1) {
            if (self.previews[i].window_id == window_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining previews left.
        while (i < self.previews_len - 1) : (i += 1) {
            self.previews[i] = self.previews[i + 1];
        }
        self.previews_len -= 1;
        return true;
    }

    // Clear all previews.
    pub fn clear_all(self: *PreviewManager) void {
        var i: u32 = 0;
        while (i < self.previews_len) : (i += 1) {
            self.previews[i].clear();
        }
        self.previews_len = 0;
    }

    // Generate preview from window (downscaled thumbnail).
    pub fn generate_preview(
        self: *PreviewManager,
        window_id: u32,
        _win_x: i32,
        _win_y: i32,
        _win_width: u32,
        _win_height: u32,
        _screen_width: u32,
        _screen_height: u32,
    ) bool {
        std.debug.assert(window_id > 0);
        // Discard unused parameters (for future framebuffer sampling).
        _ = _win_x;
        _ = _win_y;
        _ = _win_width;
        _ = _win_height;
        _ = _screen_width;
        _ = _screen_height;
        if (self.get_preview(window_id)) |preview| {
            // Generate downscaled preview (simplified: solid color for now).
            // In full implementation, would sample from framebuffer.
            const bg_color: u32 = 0xFFCCCCCC; // Light gray.
            var y: u32 = 0;
            while (y < PREVIEW_HEIGHT) : (y += 1) {
                var x: u32 = 0;
                while (x < PREVIEW_WIDTH) : (x += 1) {
                    const idx = y * PREVIEW_WIDTH + x;
                    preview.pixels[idx] = bg_color;
                }
            }
            preview.valid = true;
            preview.timestamp = 0; // Would use actual timestamp in full impl.
            return true;
        }
        return false;
    }

    // Get preview count.
    pub fn get_count(self: *const PreviewManager) u32 {
        return self.previews_len;
    }
};

