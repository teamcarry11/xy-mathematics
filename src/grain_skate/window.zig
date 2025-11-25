const std = @import("std");
const MacWindow = @import("macos_window");
const Editor = @import("editor.zig").Editor;
const Block = @import("block.zig").Block;
const GraphVisualization = @import("graph_viz.zig").GraphVisualization;
const GraphRenderer = @import("graph_renderer.zig").GraphRenderer;

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
    allocator: std.mem.Allocator,

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
            .allocator = allocator,
        };
    }

    /// Deinitialize Grain Skate window.
    // 2025-11-23-170000-pst: Active function
    pub fn deinit(self: *SkateWindow) void {
        // Clean up graph renderer if present
        if (self.graph_renderer) |renderer| {
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
            // Update existing editor (placeholder - full implementation will update buffer)
            _ = editor;
        } else {
            // Create new editor
            const editor = try Editor.EditorState.init(self.allocator, block.content);
            errdefer editor.deinit();
            self.editor = editor;
        }

        self.current_block_id = block.id;
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

    /// Present window (render graph and display).
    // 2025-11-24-163500-pst: Active function
    pub fn present(self: *SkateWindow) !void {
        // Render graph if renderer is set
        self.render_graph();
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
};

