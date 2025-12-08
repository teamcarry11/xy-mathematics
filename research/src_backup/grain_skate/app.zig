//! Grain Skate Application: Main application integrating all components.
//!
//! Why: Unified application connecting window, editor, graph, and blocks.
//! Architecture: Component integration, event-driven updates.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-11-24-111000-pst: Active implementation

const std = @import("std");
const Block = @import("block.zig").Block;
const Editor = @import("editor.zig").Editor;
const SkateWindow = @import("window.zig").SkateWindow;
const ModalEditor = @import("modal_editor.zig").ModalEditor;
const GraphVisualization = @import("graph_viz.zig").GraphVisualization;
const Social = @import("social.zig").Social;
const StorageIntegration = @import("storage_integration.zig").StorageIntegration;
const events = @import("platform/events.zig");

// Bounded: Max blocks in application.
// 2025-11-24-111000-pst: Active constant
pub const MAX_APP_BLOCKS: u32 = 10_000;

// Bounded: Max pending operations.
// 2025-11-24-111000-pst: Active constant
pub const MAX_PENDING_OPS: u32 = 256;

// Auto-save timeout (seconds of inactivity before auto-save)
// 2025-12-02-170157-pst: Active constant
pub const AUTO_SAVE_TIMEOUT_SEC: u64 = 30; // 30 seconds

// Application state.
// 2025-11-24-111000-pst: Active struct
pub const GrainSkateApp = struct {
    block_storage: *Block.BlockStorage,
    window: *SkateWindow,
    modal_editor: ?*ModalEditor,
    graph_viz: *GraphVisualization,
    social_manager: *Social.SocialManager,
    storage_integration: ?*StorageIntegration.Integration,
    last_edit_time: u64, // Last edit timestamp (Unix seconds) for auto-save
    allocator: std.mem.Allocator,

    /// Initialize Grain Skate application.
    // 2025-11-24-111000-pst: Active function
    pub fn init(
        allocator: std.mem.Allocator,
        block_storage: *Block.BlockStorage,
        window: *SkateWindow,
    ) !GrainSkateApp {
        // Initialize graph visualization
        const graph_viz = try allocator.create(GraphVisualization);
        graph_viz.* = GraphVisualization.init(allocator);
        errdefer allocator.destroy(graph_viz);

        // Initialize social manager
        const social_manager = try allocator.create(Social.SocialManager);
        social_manager.* = try Social.SocialManager.init(allocator, block_storage);
        errdefer social_manager.deinit();
        errdefer allocator.destroy(social_manager);

        const now = std.time.timestamp();
        return GrainSkateApp{
            .block_storage = block_storage,
            .window = window,
            .modal_editor = null,
            .graph_viz = graph_viz,
            .social_manager = social_manager,
            .storage_integration = null,
            .last_edit_time = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }

    /// Deinitialize Grain Skate application.
    // 2025-11-24-111000-pst: Active function
    pub fn deinit(self: *GrainSkateApp) void {
        // Clean up modal editor
        if (self.modal_editor) |modal_editor| {
            modal_editor.deinit();
            self.allocator.destroy(modal_editor);
        }

        // Clean up storage integration
        if (self.storage_integration) |storage_integration| {
            storage_integration.deinit();
            self.allocator.destroy(storage_integration);
        }

        // Clean up social manager
        self.social_manager.deinit();
        self.allocator.destroy(self.social_manager);

        // Clean up graph visualization
        self.allocator.destroy(self.graph_viz);

        self.* = undefined;
    }

    /// Load blocks into graph visualization.
    // 2025-11-24-111000-pst: Active function
    pub fn load_blocks_to_graph(self: *GrainSkateApp) void {
        // Clear existing graph
        self.graph_viz.nodes_len = 0;
        self.graph_viz.edges_len = 0;

        // Add all blocks as nodes
        var i: u32 = 0;
        while (i < self.block_storage.blocks_len) : (i += 1) {
            const block = &self.block_storage.blocks[i];
            if (block.id > 0) {
                self.graph_viz.add_block(block.id);

                // Add links as edges
                var j: u32 = 0;
                while (j < block.links_len) : (j += 1) {
                    self.graph_viz.add_link(block.id, block.links[j]);
                }
            }
        }

        // Calculate layout
        self.graph_viz.calculate_layout(50);

        // Set graph visualization in window for rendering
        try self.window.set_graph_viz(self.graph_viz);

        // Set block storage for title rendering
        self.window.set_block_storage(self.block_storage);
    }

    /// Open block for editing.
    // 2025-11-24-111000-pst: Active function
    pub fn open_block(self: *GrainSkateApp, block_id: u32) !void {
        std.debug.assert(block_id > 0);
        const block = self.block_storage.get_block(block_id) orelse return;

        // Set block in window
        try self.window.set_current_block(block);

        // Initialize modal editor if needed
        if (self.window.get_editor()) |editor| {
            if (self.modal_editor == null) {
                const modal_editor = try self.allocator.create(ModalEditor);
                modal_editor.* = try ModalEditor.init(self.allocator, editor);
                self.modal_editor = modal_editor;
            }
        }

        // Select block in graph
        self.graph_viz.select_block(block_id);
    }

    /// Create new block.
    // 2025-11-24-111000-pst: Active function
    pub fn create_block(self: *GrainSkateApp, title: []const u8, content: []const u8) !u32 {
        const block_id = try self.block_storage.create_block(title, content);
        // Add to graph
        self.graph_viz.add_block(block_id);
        // Recalculate layout
        self.graph_viz.calculate_layout(50);
        return block_id;
    }

    /// Link two blocks.
    // 2025-11-24-111000-pst: Active function
    pub fn link_blocks(self: *GrainSkateApp, from_id: u32, to_id: u32) !void {
        std.debug.assert(from_id > 0);
        std.debug.assert(to_id > 0);
        try self.block_storage.link_blocks(from_id, to_id);
        // Add link to graph
        self.graph_viz.add_link(from_id, to_id);
        // Recalculate layout
        self.graph_viz.calculate_layout(50);
    }

    /// Update current block content.
    // 2025-11-24-111000-pst: Active function
    pub fn update_current_block(self: *GrainSkateApp, new_content: []const u8) !void {
        const block_id = self.window.get_current_block_id() orelse return;
        try self.block_storage.update_content(block_id, new_content);
        // Reset last edit time after save (manual or auto)
        const now = std.time.timestamp();
        self.last_edit_time = @as(u64, @intCast(now));
    }

    /// Perform auto-save if content is modified and timeout elapsed.
    // 2025-12-02-170157-pst: Active function
    pub fn check_auto_save(self: *GrainSkateApp) void {
        // Only auto-save if editor is active and has modified content
        if (self.window.get_editor()) |editor| {
            if (self.window.get_editor_renderer()) |renderer| {
                if (!renderer.modified) {
                    return; // No modifications, skip auto-save
                }
                // Check if auto-save timeout has elapsed
                const now = std.time.timestamp();
                const now_u64 = @as(u64, @intCast(now));
                const elapsed = if (now_u64 > self.last_edit_time)
                    now_u64 - self.last_edit_time
                else
                    0;
                if (elapsed >= AUTO_SAVE_TIMEOUT_SEC) {
                    // Perform auto-save
                    const content = editor.buffer.get_content() catch |err| {
                        // Display error message
                        if (self.window.get_editor_renderer()) |renderer| {
                            const err_msg = "Failed to get content";
                            renderer.set_error(err_msg, 5); // 5 second timeout
                        }
                        return;
                    };
                    defer editor.allocator.free(content);
                    self.update_current_block(content) catch |err| {
                        // Display error message
                        if (self.window.get_editor_renderer()) |renderer| {
                            const err_msg = "Failed to save block";
                            renderer.set_error(err_msg, 5); // 5 second timeout
                        }
                        return;
                    };
                    // Clear modified flag after successful auto-save
                    renderer.set_modified(false);
                }
            }
        }
    }

    /// Update last edit time (call when content is modified).
    // 2025-12-02-170157-pst: Active function
    pub fn update_last_edit_time(self: *GrainSkateApp) void {
        const now = std.time.timestamp();
        self.last_edit_time = @as(u64, @intCast(now));
    }

    /// Get graph visualization.
    // 2025-11-24-111000-pst: Active function
    pub fn get_graph(self: *const GrainSkateApp) *GraphVisualization {
        return self.graph_viz;
    }

    /// Get social manager.
    // 2025-11-24-111000-pst: Active function
    pub fn get_social(self: *const GrainSkateApp) *Social.SocialManager {
        return self.social_manager;
    }

    /// Handle mouse click on graph (open block if node clicked).
    // 2025-11-24-172500-pst: Active function
    pub fn handle_graph_click(self: *GrainSkateApp, x: f64, y: f64) void {
        if (self.window.handle_mouse_click(x, y)) |block_id| {
            // Open block if node was clicked
            self.open_block(block_id) catch |err| {
                // Ignore errors (block might not exist)
                _ = err;
            };
        }
    }

    /// Handle window resize event (update graph renderer and layout).
    // 2025-11-24-181000-pst: Active function
    pub fn handle_window_resize(self: *GrainSkateApp, new_width: u32, new_height: u32) !void {
        // Update window and renderer
        try self.window.handle_resize(new_width, new_height);
        // Graph visualization layout will adapt automatically on next render
    }

    /// Handle keyboard event (route to modal editor if editor is active).
    // 2025-12-02-151416-pst: Active function
    pub fn handle_keyboard_event(self: *GrainSkateApp, event: events.KeyboardEvent) bool {
        // Don't intercept Ctrl+Alt (for OS window management)
        if (event.modifiers.control and event.modifiers.option) {
            return false; // Let OS handle it
        }
        // Only handle key down events
        if (event.kind != .down) {
            return false;
        }
        // Route to modal editor if editor is active
        if (self.modal_editor) |modal_editor| {
            modal_editor.handle_key_event(event) catch |err| {
                // Display error message
                if (self.window.get_editor_renderer()) |renderer| {
                    const err_msg = "Failed to handle key event";
                    renderer.set_error(err_msg, 3); // 3 second timeout
                }
                return false;
            };
            // Check for command results (save, quit, etc.)
            const cmd_result = modal_editor.get_last_command_result();
            if (cmd_result == .save or cmd_result == .save_quit) {
                // Save editor content to block storage
                if (self.window.get_editor()) |editor| {
                    const content = editor.buffer.get_content() catch |err| {
                        // Display error message
                        if (self.window.get_editor_renderer()) |renderer| {
                            const err_msg = "Failed to get content";
                            renderer.set_error(err_msg, 5); // 5 second timeout
                        }
                    } else {
                        self.update_current_block(content) catch |err| {
                            // Display error message
                            if (self.window.get_editor_renderer()) |renderer| {
                                const err_msg = "Failed to save block";
                                renderer.set_error(err_msg, 5); // 5 second timeout
                            }
                        } else {
                            // Clear error on successful save
                            if (self.window.get_editor_renderer()) |renderer| {
                                renderer.clear_error();
                                renderer.set_modified(false);
                            }
                        }
                        // Free temporary content buffer
                        editor.allocator.free(content);
                    }
                }
            }
            // Handle quit commands
            var editor_was_closed = false;
            if (cmd_result == .save_quit or cmd_result == .quit or cmd_result == .force_quit) {
                // Quit: close editor and return to graph view
                self.window.close_editor();
                // Clear modal editor reference
                if (self.modal_editor) |modal_editor| {
                    modal_editor.deinit();
                    self.allocator.destroy(modal_editor);
                    self.modal_editor = null;
                }
                editor_was_closed = true;
            }
            // Mark content as modified if editor has undo history (indicates edits)
            if (!editor_was_closed and self.window.get_editor()) |editor| {
                if (editor.undo_history_len > 0) {
                    if (self.window.get_editor_renderer()) |renderer| {
                        renderer.set_modified(true);
                        // Update last edit time for auto-save tracking
                        self.update_last_edit_time();
                    }
                }
            }
            // Check for auto-save (only if editor is still active)
            if (!editor_was_closed) {
                self.check_auto_save();
            }
            // Render appropriate view (editor or graph)
            if (!editor_was_closed and self.window.get_editor()) |editor| {
                // Get command buffer for command mode display
                if (self.modal_editor) |modal_editor| {
                    const cmd_buf = if (editor.mode == .command)
                        modal_editor.get_command_string()
                    else
                        "";
                    // Render editor with command buffer and present window
                    self.window.render_editor(cmd_buf);
                }
            } else {
                // Editor closed, render graph view instead
                self.window.render_graph();
            }
            self.window.window.present() catch |err| {
                _ = err;
            };
            return true; // Event was handled
        }
        return false; // No editor active, didn't handle
    }
};

