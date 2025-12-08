//! Grain Skate Graph Visualization: Visual representation of knowledge graph.
//!
//! Why: Interactive graph visualization for blocks and links.
//! Architecture: Force-directed layout, iterative algorithms.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-11-24-110000-pst: Active implementation

const std = @import("std");
const Block = @import("block.zig").Block;

// Bounded: Max nodes in graph visualization.
// 2025-11-24-110000-pst: Active constant
pub const MAX_NODES: u32 = 1024;

// Bounded: Max edges in graph visualization.
// 2025-11-24-110000-pst: Active constant
pub const MAX_EDGES: u32 = 4096;

// Bounded: Max iterations for force-directed layout.
// 2025-11-24-110000-pst: Active constant
pub const MAX_ITERATIONS: u32 = 100;

// Node position in graph.
// 2025-11-24-110000-pst: Active struct
pub const NodePosition = struct {
    x: f32, // X position (normalized 0.0-1.0)
    y: f32, // Y position (normalized 0.0-1.0)
    vx: f32, // X velocity (for force-directed)
    vy: f32, // Y velocity (for force-directed)
};

// Graph node (represents a block).
// 2025-11-24-110000-pst: Active struct
pub const GraphNode = struct {
    block_id: u32, // Block ID
    position: NodePosition, // Node position
    radius: f32, // Node radius (for rendering)
    selected: bool, // Selection state
    visible: bool, // Visibility state
};

// Graph edge (represents a link).
// 2025-11-24-110000-pst: Active struct
pub const GraphEdge = struct {
    from_block_id: u32, // Source block ID
    to_block_id: u32, // Target block ID
    visible: bool, // Visibility state
};

// Graph visualization state.
// 2025-11-24-110000-pst: Active struct
pub const GraphVisualization = struct {
    nodes: [MAX_NODES]GraphNode, // Graph nodes
    nodes_len: u32, // Number of nodes
    edges: [MAX_EDGES]GraphEdge, // Graph edges
    edges_len: u32, // Number of edges
    center_x: f32, // View center X (normalized)
    center_y: f32, // View center Y (normalized)
    zoom: f32, // Zoom level (1.0 = normal)
    selected_block_id: ?u32, // Currently selected block
    allocator: std.mem.Allocator,

    /// Initialize graph visualization.
    // 2025-11-24-110000-pst: Active function
    pub fn init(allocator: std.mem.Allocator) GraphVisualization {
        var viz = GraphVisualization{
            .nodes = undefined,
            .nodes_len = 0,
            .edges = undefined,
            .edges_len = 0,
            .center_x = 0.5,
            .center_y = 0.5,
            .zoom = 1.0,
            .selected_block_id = null,
            .allocator = allocator,
        };
        var i: u32 = 0;
        while (i < MAX_NODES) : (i += 1) {
            viz.nodes[i] = GraphNode{
                .block_id = 0,
                .position = NodePosition{ .x = 0.0, .y = 0.0, .vx = 0.0, .vy = 0.0 },
                .radius = 10.0,
                .selected = false,
                .visible = true,
            };
        }
        i = 0;
        while (i < MAX_EDGES) : (i += 1) {
            viz.edges[i] = GraphEdge{
                .from_block_id = 0,
                .to_block_id = 0,
                .visible = true,
            };
        }
        std.debug.assert(viz.zoom > 0.0);
        return viz;
    }

    /// Add block to graph.
    // 2025-11-24-110000-pst: Active function
    pub fn add_block(self: *GraphVisualization, block_id: u32) void {
        std.debug.assert(block_id > 0);
        std.debug.assert(self.nodes_len < MAX_NODES);
        const node = GraphNode{
            .block_id = block_id,
            .position = NodePosition{
                .x = 0.5 + (std.math.sin(@as(f32, @floatFromInt(block_id))) * 0.2),
                .y = 0.5 + (std.math.cos(@as(f32, @floatFromInt(block_id))) * 0.2),
                .vx = 0.0,
                .vy = 0.0,
            },
            .radius = 10.0,
            .selected = false,
            .visible = true,
        };
        self.nodes[self.nodes_len] = node;
        self.nodes_len += 1;
        std.debug.assert(self.nodes_len <= MAX_NODES);
    }

    /// Add link to graph.
    // 2025-11-24-110000-pst: Active function
    pub fn add_link(self: *GraphVisualization, from_id: u32, to_id: u32) void {
        std.debug.assert(from_id > 0);
        std.debug.assert(to_id > 0);
        std.debug.assert(self.edges_len < MAX_EDGES);
        const edge = GraphEdge{
            .from_block_id = from_id,
            .to_block_id = to_id,
            .visible = true,
        };
        self.edges[self.edges_len] = edge;
        self.edges_len += 1;
        std.debug.assert(self.edges_len <= MAX_EDGES);
    }

    /// Calculate force-directed layout (iterative, no recursion).
    // 2025-11-24-110000-pst: Active function
    pub fn calculate_layout(self: *GraphVisualization, iterations: u32) void {
        std.debug.assert(iterations > 0);
        std.debug.assert(iterations <= MAX_ITERATIONS);
        if (self.nodes_len == 0) {
            return;
        }

        // Force-directed layout parameters
        const k: f32 = 1.0; // Spring constant
        const repulsion: f32 = 100.0; // Repulsion force
        const damping: f32 = 0.9; // Velocity damping

        var iter: u32 = 0;
        while (iter < iterations) : (iter += 1) {
            self.reset_velocities();
            self.calculate_repulsion_forces(repulsion);
            self.calculate_attraction_forces(k);
            self.update_positions(damping);
        }
    }

    /// Reset all node velocities.
    // 2025-11-24-110000-pst: Active function
    fn reset_velocities(self: *GraphVisualization) void {
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            self.nodes[i].position.vx = 0.0;
            self.nodes[i].position.vy = 0.0;
        }
    }

    /// Calculate repulsion forces between all node pairs.
    // 2025-11-24-110000-pst: Active function
    fn calculate_repulsion_forces(self: *GraphVisualization, repulsion: f32) void {
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            var j: u32 = i + 1;
            while (j < self.nodes_len) : (j += 1) {
                const dx = self.nodes[j].position.x - self.nodes[i].position.x;
                const dy = self.nodes[j].position.y - self.nodes[i].position.y;
                const dist_sq = (dx * dx) + (dy * dy);
                if (dist_sq < 0.0001) {
                    continue; // Avoid division by zero
                }
                const dist = std.math.sqrt(dist_sq);
                const force = repulsion / dist_sq;
                const fx = (dx / dist) * force;
                const fy = (dy / dist) * force;
                self.nodes[i].position.vx -= fx;
                self.nodes[i].position.vy -= fy;
                self.nodes[j].position.vx += fx;
                self.nodes[j].position.vy += fy;
            }
        }
    }

    /// Calculate attraction forces along edges.
    // 2025-11-24-110000-pst: Active function
    fn calculate_attraction_forces(self: *GraphVisualization, k: f32) void {
        var e: u32 = 0;
        while (e < self.edges_len) : (e += 1) {
            const from_node = self.find_node(self.edges[e].from_block_id);
            const to_node = self.find_node(self.edges[e].to_block_id);
            if (from_node == null or to_node == null) {
                continue;
            }
            const from_idx = from_node.?;
            const to_idx = to_node.?;
            const dx = self.nodes[to_idx].position.x - self.nodes[from_idx].position.x;
            const dy = self.nodes[to_idx].position.y - self.nodes[from_idx].position.y;
            const dist_sq = (dx * dx) + (dy * dy);
            if (dist_sq < 0.0001) {
                continue;
            }
            const dist = std.math.sqrt(dist_sq);
            const force = k * dist;
            const fx = (dx / dist) * force;
            const fy = (dy / dist) * force;
            self.nodes[from_idx].position.vx += fx;
            self.nodes[from_idx].position.vy += fy;
            self.nodes[to_idx].position.vx -= fx;
            self.nodes[to_idx].position.vy -= fy;
        }
    }

    /// Update node positions with damping and bounds clamping.
    // 2025-11-24-110000-pst: Active function
    fn update_positions(self: *GraphVisualization, damping: f32) void {
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            self.nodes[i].position.x += self.nodes[i].position.vx * damping;
            self.nodes[i].position.y += self.nodes[i].position.vy * damping;
            // Clamp to bounds
            if (self.nodes[i].position.x < 0.0) {
                self.nodes[i].position.x = 0.0;
            }
            if (self.nodes[i].position.x > 1.0) {
                self.nodes[i].position.x = 1.0;
            }
            if (self.nodes[i].position.y < 0.0) {
                self.nodes[i].position.y = 0.0;
            }
            if (self.nodes[i].position.y > 1.0) {
                self.nodes[i].position.y = 1.0;
            }
        }
    }

    /// Find node index by block ID.
    // 2025-11-24-110000-pst: Active function
    fn find_node(self: *const GraphVisualization, block_id: u32) ?u32 {
        std.debug.assert(block_id > 0);
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            if (self.nodes[i].block_id == block_id) {
                return i;
            }
        }
        return null;
    }

    /// Select block in graph.
    // 2025-11-24-110000-pst: Active function
    pub fn select_block(self: *GraphVisualization, block_id: u32) void {
        std.debug.assert(block_id > 0);
        // Deselect all
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            self.nodes[i].selected = false;
        }
        // Select target
        if (self.find_node(block_id)) |idx| {
            self.nodes[idx].selected = true;
            self.selected_block_id = block_id;
        }
    }

    /// Pan view (move center).
    // 2025-11-24-110000-pst: Active function
    pub fn pan(self: *GraphVisualization, dx: f32, dy: f32) void {
        self.center_x += dx;
        self.center_y += dy;
        // Clamp to bounds
        if (self.center_x < 0.0) {
            self.center_x = 0.0;
        }
        if (self.center_x > 1.0) {
            self.center_x = 1.0;
        }
        if (self.center_y < 0.0) {
            self.center_y = 0.0;
        }
        if (self.center_y > 1.0) {
            self.center_y = 1.0;
        }
    }

    /// Zoom view.
    // 2025-11-24-110000-pst: Active function
    pub fn zoom_view(self: *GraphVisualization, delta: f32) void {
        self.zoom += delta;
        // Clamp zoom
        if (self.zoom < 0.1) {
            self.zoom = 0.1;
        }
        if (self.zoom > 10.0) {
            self.zoom = 10.0;
        }
        std.debug.assert(self.zoom > 0.0);
    }

    /// Find node at pixel coordinates (hit testing).
    // 2025-11-24-172500-pst: Active function
    pub fn find_node_at_pixel(self: *const GraphVisualization, pixel_x: u32, pixel_y: u32, buffer_width: u32, buffer_height: u32) ?u32 {
        std.debug.assert(pixel_x < buffer_width);
        std.debug.assert(pixel_y < buffer_height);
        std.debug.assert(buffer_width > 0);
        std.debug.assert(buffer_height > 0);

        // Transform pixel coordinates to normalized coordinates
        const normalized_x = self.pixel_to_normalized_x(pixel_x, buffer_width);
        const normalized_y = self.pixel_to_normalized_y(pixel_y, buffer_height);

        // Check each node (reverse order for top-to-bottom hit testing)
        var i: u32 = self.nodes_len;
        while (i > 0) : (i -= 1) {
            const node_idx = i - 1;
            if (!self.nodes[node_idx].visible) {
                continue;
            }

            const node_x = self.nodes[node_idx].position.x;
            const node_y = self.nodes[node_idx].position.y;
            const node_radius = self.nodes[node_idx].radius * self.zoom;

            // Calculate distance from click to node center
            const dx = normalized_x - node_x;
            const dy = normalized_y - node_y;
            const dist_sq = (dx * dx) + (dy * dy);
            const radius_sq = node_radius * node_radius;

            // Check if click is within node radius
            if (dist_sq <= radius_sq) {
                return self.nodes[node_idx].block_id;
            }
        }

        return null;
    }

    /// Transform pixel X coordinate to normalized coordinate.
    // 2025-11-24-172500-pst: Active function
    fn pixel_to_normalized_x(self: *const GraphVisualization, pixel_x: u32, buffer_width: u32) f32 {
        const offset_x = (@as(f32, @floatFromInt(pixel_x)) - (@as(f32, @floatFromInt(buffer_width)) * 0.5)) / self.zoom;
        const normalized_x = self.center_x + (offset_x / @as(f32, @floatFromInt(buffer_width)));
        return std.math.clamp(normalized_x, 0.0, 1.0);
    }

    /// Transform pixel Y coordinate to normalized coordinate.
    // 2025-11-24-172500-pst: Active function
    fn pixel_to_normalized_y(self: *const GraphVisualization, pixel_y: u32, buffer_height: u32) f32 {
        const offset_y = (@as(f32, @floatFromInt(pixel_y)) - (@as(f32, @floatFromInt(buffer_height)) * 0.5)) / self.zoom;
        const normalized_y = self.center_y + (offset_y / @as(f32, @floatFromInt(buffer_height)));
        return std.math.clamp(normalized_y, 0.0, 1.0);
    }
};

