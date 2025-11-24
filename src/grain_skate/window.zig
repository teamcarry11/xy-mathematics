const std = @import("std");
const MacWindow = @import("macos_window");
const Editor = @import("editor.zig").Editor;
const Block = @import("block.zig").Block;

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
            .allocator = allocator,
        };
    }

    /// Deinitialize Grain Skate window.
    // 2025-11-23-170000-pst: Active function
    pub fn deinit(self: *SkateWindow) void {
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
};

