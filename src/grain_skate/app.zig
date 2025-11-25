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

// Bounded: Max blocks in application.
// 2025-11-24-111000-pst: Active constant
pub const MAX_APP_BLOCKS: u32 = 10_000;

// Bounded: Max pending operations.
// 2025-11-24-111000-pst: Active constant
pub const MAX_PENDING_OPS: u32 = 256;

// Application state.
// 2025-11-24-111000-pst: Active struct
pub const GrainSkateApp = struct {
    block_storage: *Block.BlockStorage,
    window: *SkateWindow,
    modal_editor: ?*ModalEditor,
    graph_viz: *GraphVisualization,
    social_manager: *Social.SocialManager,
    storage_integration: ?*StorageIntegration.Integration,
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

        return GrainSkateApp{
            .block_storage = block_storage,
            .window = window,
            .modal_editor = null,
            .graph_viz = graph_viz,
            .social_manager = social_manager,
            .storage_integration = null,
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
};

