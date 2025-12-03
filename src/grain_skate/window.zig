const std = @import("std");
const MacWindow = @import("macos_window");
const Editor = @import("editor.zig").Editor;
const Block = @import("block.zig").Block;
const GraphVisualization = @import("graph_viz.zig").GraphVisualization;
const GraphRenderer = @import("graph_renderer.zig").GraphRenderer;
const EditorRenderer = @import("editor_renderer.zig").EditorRenderer;
const events = @import("platform/events.zig");

/// Grain Skate Window: Native macOS window management for knowledge graph application.
/// ~<~ Glow Airbend: explicit window state, bounded UI buffers.
/// ~~~~ Glow Waterbend: deterministic rendering, iterative UI updates.
///
/// 2025-11-23-170000-pst: Active implementation
pub const SkateWindow = struct {
    // Bounded: Max window title length (explicit limit)
    // 2025-11-23-170000-pst: Active constant
    pub const MAX_TITLE_LEN: u32 = 256;

    // Bounded: Max window width (explicit limit, in pixels)
    // 2025-11-23-170000-pst: Active constant
    pub const MAX_WIDTH: u32 = 4096;

    // Bounded: Max window height (explicit limit, in pixels)
    // 2025-11-23-170000-pst: Active constant
    pub const MAX_HEIGHT: u32 = 4096;

    /// Window state.
    // 2025-11-23-170000-pst: Active struct
    window: *MacWindow.Window,
    editor: ?*Editor.EditorState,
    current_block_id: ?u32,
    graph_renderer: ?*GraphRenderer,
    editor_renderer: ?*EditorRenderer,
    allocator: std.mem.Allocator,
    split_pane_enabled: bool, // Whether split pane mode is enabled
    split_position: u32, // Split position in pixels (0 = left edge, width = right edge)

    /// Initialize Grain Skate window.
    // 2025-11-23-170000-pst: Active function
    pub fn init(allocator: std.mem.Allocator, title: []const u8, width: u32, height: u32) !SkateWindow {
        // Assert: Title must be bounded
        std.debug.assert(title.len <= MAX_TITLE_LEN);
        std.debug.assert(width > 0 and width <= MAX_WIDTH);
        std.debug.assert(height > 0 and height <= MAX_HEIGHT);

        // Create macOS window
        const window = try allocator.create(MacWindow.Window);
        window.* = MacWindow.Window.init(allocator, title);
        window.width = width;
        window.height = height;

        return SkateWindow{
            .window = window,
            .editor = null,
            .current_block_id = null,
            .graph_renderer = null,
            .editor_renderer = null,
            .allocator = allocator,
            .split_pane_enabled = false,
            .split_position = width / 2, // Default: 50/50 split
        };
    }

    /// Deinitialize Grain Skate window.
    // 2025-11-23-170000-pst: Active function
    pub fn deinit(self: *SkateWindow) void {
        // Clean up graph renderer if present
        if (self.graph_renderer) |renderer| {
            self.allocator.destroy(renderer);
        }
        // Clean up editor renderer if present
        if (self.editor_renderer) |renderer| {
            self.allocator.destroy(renderer);
        }
        // Clean up editor if present
        if (self.editor) |editor| {
            editor.deinit();
            self.allocator.destroy(editor);
        }

        // Clean up window
        self.window.deinit();
        self.allocator.destroy(self.window);

        self.* = undefined;
    }

    /// Show window.
    // 2025-11-23-170000-pst: Active function
    pub fn show(self: *SkateWindow) void {
        self.window.show();
    }

    /// Set current block for editing.
    // 2025-11-23-170000-pst: Active function
    pub fn set_current_block(self: *SkateWindow, block: *Block.BlockData) !void {
        // Assert: Block must be valid
        std.debug.assert(block.id > 0);

        // Create or update editor with block content
        if (self.editor) |editor| {
            // Update existing editor: deinit old and create new with block content
            editor.deinit();
            self.allocator.destroy(editor);
            self.editor = null;
        }
        // Create new editor with block content
        const editor = try self.allocator.create(Editor.EditorState);
        errdefer self.allocator.destroy(editor);
        editor.* = try Editor.EditorState.init(self.allocator, block.content);
        self.editor = editor;

        // Create or update editor renderer
        if (self.editor_renderer) |renderer| {
            self.allocator.destroy(renderer);
            self.editor_renderer = null;
        }
        const editor_renderer = try self.allocator.create(EditorRenderer);
        editor_renderer.* = EditorRenderer.init(editor, self.window.width, self.window.height);
        // Set block title for status line display
        if (block.title_len > 0) {
            editor_renderer.set_block_title(block.title[0..block.title_len]);
        }
        self.editor_renderer = editor_renderer;

        self.current_block_id = block.id;
    }

    /// Close editor and return to graph view.
    // 2025-12-02-160942-pst: Active function
    pub fn close_editor(self: *SkateWindow) void {
        // Clean up editor renderer
        if (self.editor_renderer) |renderer| {
            self.allocator.destroy(renderer);
            self.editor_renderer = null;
        }
        // Clean up editor
        if (self.editor) |editor| {
            editor.deinit();
            self.allocator.destroy(editor);
            self.editor = null;
        }
        // Clear current block ID
        self.current_block_id = null;
    }

    /// Get current block ID.
    // 2025-11-23-170000-pst: Active function
    pub fn get_current_block_id(self: *const SkateWindow) ?u32 {
        return self.current_block_id;
    }

    /// Get editor state.
    // 2025-11-23-170000-pst: Active function
    pub fn get_editor(self: *const SkateWindow) ?*Editor.EditorState {
        return self.editor;
    }

    /// Get editor renderer.
    // 2025-12-02-164404-pst: Active function
    pub fn get_editor_renderer(self: *SkateWindow) ?*EditorRenderer {
        return self.editor_renderer;
    }

    /// Set graph visualization for rendering.
    // 2025-11-24-163500-pst: Active function
    pub fn set_graph_viz(self: *SkateWindow, graph_viz: *GraphVisualization) !void {
        std.debug.assert(graph_viz.zoom > 0.0);
        // Clean up existing renderer if present
        if (self.graph_renderer) |renderer| {
            self.allocator.destroy(renderer);
            self.graph_renderer = null;
        }
        // Create new renderer with current window dimensions
        const buffer_width = self.window.width;
        const buffer_height = self.window.height;
        const renderer = try self.allocator.create(GraphRenderer);
        renderer.* = GraphRenderer.init(graph_viz, buffer_width, buffer_height);
        self.graph_renderer = renderer;
    }

    /// Handle window resize event (update renderer and layout).
    // 2025-11-24-181000-pst: Active function
    pub fn handle_resize(self: *SkateWindow, new_width: u32, new_height: u32) !void {
        std.debug.assert(new_width > 0 and new_width <= MAX_WIDTH);
        std.debug.assert(new_height > 0 and new_height <= MAX_HEIGHT);

        // Update window dimensions
        self.window.width = new_width;
        self.window.height = new_height;

        // Update graph renderer if present
        if (self.graph_renderer) |renderer| {
            // Recreate renderer with new dimensions
            const graph_viz = renderer.graph_viz;
            const block_storage = if (renderer.block_storage) |bs| bs else null;
            self.allocator.destroy(renderer);
            const new_renderer = try self.allocator.create(GraphRenderer);
            new_renderer.* = GraphRenderer.init(graph_viz, new_width, new_height);
            if (block_storage) |bs| {
                new_renderer.set_block_storage(bs);
            }
            self.graph_renderer = new_renderer;
        }
        // Update editor renderer if present
        if (self.editor_renderer) |renderer| {
            const editor = renderer.editor;
            self.allocator.destroy(renderer);
            const new_renderer = try self.allocator.create(EditorRenderer);
            new_renderer.* = EditorRenderer.init(editor, new_width, new_height);
            self.editor_renderer = new_renderer;
        }
    }

    /// Set block storage for title rendering.
    // 2025-11-24-171200-pst: Active function
    pub fn set_block_storage(self: *SkateWindow, block_storage: *Block.BlockStorage) void {
        if (self.graph_renderer) |renderer| {
            renderer.set_block_storage(block_storage);
        }
    }

    /// Render graph to window buffer.
    // 2025-11-24-163500-pst: Active function
    pub fn render_graph(self: *SkateWindow) void {
        if (self.graph_renderer) |renderer| {
            const buffer = self.window.getBuffer();
            renderer.render(buffer);
        }
    }

    /// Render graph to sub-rectangle of buffer (for split pane).
    // 2025-12-02-173853-pst: Active function
    fn render_graph_to_rect(self: *SkateWindow, buffer: []u8, x: u32, y: u32, width: u32, height: u32) void {
        if (self.graph_renderer) |renderer| {
            // Create temporary renderer with pane dimensions
            const graph_viz = renderer.graph_viz;
            const block_storage = if (renderer.block_storage) |bs| bs else null;
            var temp_renderer = GraphRenderer.init(graph_viz, width, height);
            if (block_storage) |bs| {
                temp_renderer.set_block_storage(bs);
            }
            // Render to temporary buffer (use sub-rectangle of main buffer)
            const temp_buffer = buffer[(y * self.window.width + x) * 4..][0..(width * height * 4)];
            temp_renderer.render(temp_buffer);
        }
    }

    /// Render editor to window buffer.
    // 2025-12-02-142853-pst: Active function
    pub fn render_editor(self: *SkateWindow, command_buffer: []const u8) void {
        if (self.editor_renderer) |renderer| {
            // Set command buffer for command mode display
            renderer.set_command_buffer(command_buffer);
            const buffer = self.window.getBuffer();
            renderer.render(buffer);
        }
    }

    /// Render editor to sub-rectangle of buffer (for split pane).
    // 2025-12-02-173853-pst: Active function
    fn render_editor_to_rect(self: *SkateWindow, buffer: []u8, command_buffer: []const u8, x: u32, y: u32, width: u32, height: u32) void {
        if (self.editor_renderer) |renderer| {
            // Create temporary renderer with pane dimensions
            const editor = renderer.editor;
            var temp_renderer = EditorRenderer.init(editor, width, height);
            // Copy state from original renderer
            temp_renderer.set_command_buffer(command_buffer);
            if (renderer.block_title.len > 0) {
                temp_renderer.set_block_title(renderer.block_title);
            }
            temp_renderer.set_modified(renderer.modified);
            // Render to temporary buffer (use sub-rectangle of main buffer)
            const temp_buffer = buffer[(y * self.window.width + x) * 4..][0..(width * height * 4)];
            temp_renderer.render(temp_buffer);
        }
    }

    /// Copy rectangle from source buffer to destination buffer.
    // 2025-12-02-173853-pst: Active function
    fn copy_buffer_rect(self: *SkateWindow, src_buffer: []u8, dst_buffer: []u8, src_x: u32, src_y: u32, src_width: u32, src_height: u32, dst_x: u32, dst_y: u32, dst_width: u32, dst_height: u32) void {
        const window_width = self.window.width;
        const window_height = self.window.height;
        // Calculate copy dimensions (min of source and destination)
        const copy_width = @min(@min(src_width - src_x, dst_width - dst_x), window_width - dst_x);
        const copy_height = @min(@min(src_height - src_y, dst_height - dst_y), window_height - dst_y);
        // Copy pixel rows
        var row: u32 = 0;
        while (row < copy_height) : (row += 1) {
            const src_row_start = ((src_y + row) * src_width + src_x) * 4;
            const dst_row_start = ((dst_y + row) * window_width + dst_x) * 4;
            const row_size = copy_width * 4;
            @memcpy(dst_buffer[dst_row_start..][0..row_size], src_buffer[src_row_start..][0..row_size]);
        }
    }

    /// Present window (render graph/editor and display).
    // 2025-11-24-163500-pst: Active function
    pub fn present(self: *SkateWindow) !void {
        const buffer = self.window.getBuffer();
        // Clear buffer with background color
        const bg_color: u32 = 0xFF1E1E1E; // Dark gray
        const bg_r = @as(u8, @truncate((bg_color >> 16) & 0xFF));
        const bg_g = @as(u8, @truncate((bg_color >> 8) & 0xFF));
        const bg_b = @as(u8, @truncate(bg_color & 0xFF));
        const bg_a = @as(u8, @truncate((bg_color >> 24) & 0xFF));
        const buffer_size = self.window.width * self.window.height * 4;
        var i: u32 = 0;
        while (i < buffer_size) : (i += 4) {
            buffer[i + 0] = bg_r;
            buffer[i + 1] = bg_g;
            buffer[i + 2] = bg_b;
            buffer[i + 3] = bg_a;
        }
        // Render based on split pane mode
        if (self.split_pane_enabled and self.graph_renderer != null and self.editor_renderer != null) {
            // Split pane mode: render both views side-by-side
            const split_x = @min(self.split_position, self.window.width - 1);
            const graph_width = split_x;
            const editor_x = split_x + 1; // +1 for divider
            const editor_width = self.window.width - editor_x;
            const height = self.window.height;
            // Render graph to left pane
            if (graph_width > 0) {
                self.render_graph_to_rect(buffer, 0, 0, graph_width, height);
            }
            // Render divider line
            if (split_x < self.window.width) {
                var y: u32 = 0;
                const divider_color: u32 = 0xFF666666; // Gray divider
                const div_r = @as(u8, @truncate((divider_color >> 16) & 0xFF));
                const div_g = @as(u8, @truncate((divider_color >> 8) & 0xFF));
                const div_b = @as(u8, @truncate(divider_color & 0xFF));
                const div_a = @as(u8, @truncate((divider_color >> 24) & 0xFF));
                while (y < height) : (y += 1) {
                    const idx = (y * self.window.width + split_x) * 4;
                    buffer[idx + 0] = div_r;
                    buffer[idx + 1] = div_g;
                    buffer[idx + 2] = div_b;
                    buffer[idx + 3] = div_a;
                }
            }
            // Render editor to right pane
            if (editor_width > 0) {
                self.render_editor_to_rect(buffer, "", editor_x, 0, editor_width, height);
            }
        } else {
            // Single pane mode: render editor if present (editor takes priority over graph)
            if (self.editor_renderer != null) {
                self.render_editor(""); // Empty command buffer for normal rendering
            } else {
                // Render graph if renderer is set
                self.render_graph();
            }
        }
        // Present window buffer
        try self.window.present();
    }

    /// Handle mouse click event (find node at click position).
    // 2025-11-24-172500-pst: Active function
    pub fn handle_mouse_click(self: *SkateWindow, x: f64, y: f64) ?u32 {
        if (self.graph_renderer == null) {
            return null;
        }

        const graph_viz = self.graph_renderer.?.graph_viz;
        const buffer_width = self.graph_renderer.?.buffer_width;
        const buffer_height = self.graph_renderer.?.buffer_height;

        // Convert window coordinates to buffer coordinates
        // Window coordinates: 0,0 is bottom-left (macOS convention)
        // Buffer coordinates: 0,0 is top-left
        const buffer_x = @as(u32, @intFromFloat(x));
        const buffer_y = @as(u32, @intFromFloat(@as(f64, @floatFromInt(buffer_height)) - y));

        // Bounds check
        if (buffer_x >= buffer_width or buffer_y >= buffer_height) {
            return null;
        }

        // Find node at click position
        return graph_viz.find_node_at_pixel(buffer_x, buffer_y, buffer_width, buffer_height);
    }

    /// Handle keyboard event (route to modal editor if editor is active).
    // 2025-12-02-151416-pst: Active function
    pub fn handle_keyboard_event(self: *SkateWindow, event: events.KeyboardEvent) bool {
        // Don't intercept Ctrl+Alt (for OS window management)
        if (event.modifiers.control and event.modifiers.option) {
            return false; // Let OS handle it
        }
        // Only handle key down events
        if (event.kind != .down) {
            return false;
        }
        // If editor is active, we'll handle it (but need modal editor)
        // For now, return false to indicate we didn't handle it
        // The app will route it to modal editor
        return false;
    }

    /// Enable or disable split pane mode.
    // 2025-12-02-173853-pst: Active function
    pub fn set_split_pane(self: *SkateWindow, enabled: bool) void {
        self.split_pane_enabled = enabled;
        // Update default split position if enabling
        if (enabled) {
            self.split_position = self.window.width / 2;
        }
    }

    /// Set split position (in pixels from left edge).
    // 2025-12-02-173853-pst: Active function
    pub fn set_split_position(self: *SkateWindow, position: u32) void {
        // Clamp split position to valid range (leave at least 100px for each pane)
        const min_pos: u32 = 100;
        const max_pos = if (self.window.width > 200) self.window.width - 100 else self.window.width;
        self.split_position = std.math.clamp(position, min_pos, max_pos);
    }

    /// Get split pane enabled state.
    // 2025-12-02-173853-pst: Active function
    pub fn is_split_pane_enabled(self: *const SkateWindow) bool {
        return self.split_pane_enabled;
    }
};

