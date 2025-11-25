//! Grain Skate Graph Renderer: Renders graph visualization to pixel buffer.
//!
//! Why: Draw nodes and edges to window buffer for display.
//! Architecture: Pixel buffer rendering, coordinate transformation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-11-24-121500-pst: Active implementation

const std = @import("std");
const GraphVisualization = @import("graph_viz.zig").GraphVisualization;

// Bounded: Max buffer width (explicit limit, in pixels)
// 2025-11-24-121500-pst: Active constant
pub const MAX_BUFFER_WIDTH: u32 = 4096;

// Bounded: Max buffer height (explicit limit, in pixels)
// 2025-11-24-121500-pst: Active constant
pub const MAX_BUFFER_HEIGHT: u32 = 4096;

// Color constants (RGBA format)
// 2025-11-24-121500-pst: Active constants
pub const COLOR_BACKGROUND: u32 = 0xFF1E1E1E; // Dark gray background
pub const COLOR_NODE: u32 = 0xFF4A90E2; // Blue node
pub const COLOR_NODE_SELECTED: u32 = 0xFFE24A4A; // Red selected node
pub const COLOR_EDGE: u32 = 0xFF666666; // Gray edge
pub const COLOR_TEXT: u32 = 0xFFFFFFFF; // White text

// Graph renderer state.
// 2025-11-24-121500-pst: Active struct
pub const GraphRenderer = struct {
    graph_viz: *GraphVisualization,
    buffer_width: u32,
    buffer_height: u32,

    /// Initialize graph renderer.
    // 2025-11-24-121500-pst: Active function
    pub fn init(graph_viz: *GraphVisualization, buffer_width: u32, buffer_height: u32) GraphRenderer {
        std.debug.assert(buffer_width > 0);
        std.debug.assert(buffer_width <= MAX_BUFFER_WIDTH);
        std.debug.assert(buffer_height > 0);
        std.debug.assert(buffer_height <= MAX_BUFFER_HEIGHT);
        std.debug.assert(graph_viz.zoom > 0.0);

        return GraphRenderer{
            .graph_viz = graph_viz,
            .buffer_width = buffer_width,
            .buffer_height = buffer_height,
        };
    }

    /// Render graph to RGBA buffer.
    // 2025-11-24-121500-pst: Active function
    pub fn render(self: *const GraphRenderer, buffer: []u8) void {
        std.debug.assert(buffer.len >= self.buffer_width * self.buffer_height * 4);
        std.debug.assert(self.graph_viz.zoom > 0.0);

        // Clear buffer with background color
        self.clear_buffer(buffer);

        // Render edges first (so nodes appear on top)
        self.render_edges(buffer);

        // Render nodes
        self.render_nodes(buffer);
    }

    /// Clear buffer with background color.
    // 2025-11-24-121500-pst: Active function
    fn clear_buffer(self: *const GraphRenderer, buffer: []u8) void {
        const bg_r = @as(u8, @truncate((COLOR_BACKGROUND >> 16) & 0xFF));
        const bg_g = @as(u8, @truncate((COLOR_BACKGROUND >> 8) & 0xFF));
        const bg_b = @as(u8, @truncate(COLOR_BACKGROUND & 0xFF));
        const bg_a = @as(u8, @truncate((COLOR_BACKGROUND >> 24) & 0xFF));

        var y: u32 = 0;
        while (y < self.buffer_height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.buffer_width) : (x += 1) {
                const idx = (y * self.buffer_width + x) * 4;
                buffer[idx + 0] = bg_r;
                buffer[idx + 1] = bg_g;
                buffer[idx + 2] = bg_b;
                buffer[idx + 3] = bg_a;
            }
        }
    }

    /// Render edges to buffer.
    // 2025-11-24-121500-pst: Active function
    fn render_edges(self: *const GraphRenderer, buffer: []u8) void {
        const edge_r = @as(u8, @truncate((COLOR_EDGE >> 16) & 0xFF));
        const edge_g = @as(u8, @truncate((COLOR_EDGE >> 8) & 0xFF));
        const edge_b = @as(u8, @truncate(COLOR_EDGE & 0xFF));
        const edge_a = @as(u8, @truncate((COLOR_EDGE >> 24) & 0xFF));

        var e: u32 = 0;
        while (e < self.graph_viz.edges_len) : (e += 1) {
            if (!self.graph_viz.edges[e].visible) {
                continue;
            }

            const from_node = self.graph_viz.find_node(self.graph_viz.edges[e].from_block_id);
            const to_node = self.graph_viz.find_node(self.graph_viz.edges[e].to_block_id);
            if (from_node == null or to_node == null) {
                continue;
            }

            const from_idx = from_node.?;
            const to_idx = to_node.?;

            // Transform normalized coordinates to pixel coordinates
            const x1 = self.normalized_to_pixel_x(self.graph_viz.nodes[from_idx].position.x);
            const y1 = self.normalized_to_pixel_y(self.graph_viz.nodes[from_idx].position.y);
            const x2 = self.normalized_to_pixel_x(self.graph_viz.nodes[to_idx].position.x);
            const y2 = self.normalized_to_pixel_y(self.graph_viz.nodes[to_idx].position.y);

            // Draw line using Bresenham's algorithm (iterative)
            self.draw_line(buffer, x1, y1, x2, y2, edge_r, edge_g, edge_b, edge_a);
        }
    }

    /// Render nodes to buffer.
    // 2025-11-24-121500-pst: Active function
    fn render_nodes(self: *const GraphRenderer, buffer: []u8) void {
        var n: u32 = 0;
        while (n < self.graph_viz.nodes_len) : (n += 1) {
            if (!self.graph_viz.nodes[n].visible) {
                continue;
            }

            // Choose color based on selection state
            const color = if (self.graph_viz.nodes[n].selected) COLOR_NODE_SELECTED else COLOR_NODE;
            const node_r = @as(u8, @truncate((color >> 16) & 0xFF));
            const node_g = @as(u8, @truncate((color >> 8) & 0xFF));
            const node_b = @as(u8, @truncate(color & 0xFF));
            const node_a = @as(u8, @truncate((color >> 24) & 0xFF));

            // Transform normalized coordinates to pixel coordinates
            const center_x = self.normalized_to_pixel_x(self.graph_viz.nodes[n].position.x);
            const center_y = self.normalized_to_pixel_y(self.graph_viz.nodes[n].position.y);
            const radius = @as(u32, @intFromFloat(self.graph_viz.nodes[n].radius * self.graph_viz.zoom));

            // Draw filled circle
            self.draw_circle(buffer, center_x, center_y, radius, node_r, node_g, node_b, node_a);
        }
    }

    /// Draw line using Bresenham's algorithm (iterative).
    // 2025-11-24-121500-pst: Active function
    fn draw_line(self: *const GraphRenderer, buffer: []u8, x1: u32, y1: u32, x2: u32, y2: u32, r: u8, g: u8, b: u8, a: u8) void {
        var x0 = @as(i32, @intCast(x1));
        var y0 = @as(i32, @intCast(y1));
        const x1_i = @as(i32, @intCast(x2));
        const y1_i = @as(i32, @intCast(y2));

        const dx = std.math.absInt(x1_i - x0) catch 0;
        const dy = std.math.absInt(y1_i - y0) catch 0;
        const sx: i32 = if (x0 < x1_i) 1 else -1;
        const sy: i32 = if (y0 < y1_i) 1 else -1;
        var err = dx - dy;

        while (true) {
            if (x0 >= 0 and x0 < @as(i32, @intCast(self.buffer_width)) and y0 >= 0 and y0 < @as(i32, @intCast(self.buffer_height))) {
                const idx = (@as(u32, @intCast(y0)) * self.buffer_width + @as(u32, @intCast(x0))) * 4;
                buffer[idx + 0] = r;
                buffer[idx + 1] = g;
                buffer[idx + 2] = b;
                buffer[idx + 3] = a;
            }

            if (x0 == x1_i and y0 == y1_i) {
                break;
            }

            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x0 += sx;
            }
            if (e2 < dx) {
                err += dx;
                y0 += sy;
            }
        }
    }

    /// Draw filled circle (iterative).
    // 2025-11-24-121500-pst: Active function
    fn draw_circle(self: *const GraphRenderer, buffer: []u8, center_x: u32, center_y: u32, radius: u32, r: u8, g: u8, b: u8, a: u8) void {
        if (radius == 0) {
            return;
        }

        const radius_i = @as(i32, @intCast(radius));
        const center_x_i = @as(i32, @intCast(center_x));
        const center_y_i = @as(i32, @intCast(center_y));

        var y: i32 = -radius_i;
        while (y <= radius_i) : (y += 1) {
            var x: i32 = -radius_i;
            while (x <= radius_i) : (x += 1) {
                const dist_sq = x * x + y * y;
                if (dist_sq <= radius_i * radius_i) {
                    const px = center_x_i + x;
                    const py = center_y_i + y;
                    if (px >= 0 and px < @as(i32, @intCast(self.buffer_width)) and py >= 0 and py < @as(i32, @intCast(self.buffer_height))) {
                        const idx = (@as(u32, @intCast(py)) * self.buffer_width + @as(u32, @intCast(px))) * 4;
                        buffer[idx + 0] = r;
                        buffer[idx + 1] = g;
                        buffer[idx + 2] = b;
                        buffer[idx + 3] = a;
                    }
                }
            }
        }
    }

    /// Transform normalized X coordinate to pixel coordinate.
    // 2025-11-24-121500-pst: Active function
    fn normalized_to_pixel_x(self: *const GraphRenderer, normalized_x: f32) u32 {
        std.debug.assert(normalized_x >= 0.0);
        std.debug.assert(normalized_x <= 1.0);
        const offset_x = (normalized_x - self.graph_viz.center_x) * self.graph_viz.zoom;
        const pixel_x = (@as(f32, @floatFromInt(self.buffer_width)) * 0.5) + (offset_x * @as(f32, @floatFromInt(self.buffer_width)));
        const clamped = std.math.clamp(pixel_x, 0.0, @as(f32, @floatFromInt(self.buffer_width - 1)));
        return @as(u32, @intFromFloat(clamped));
    }

    /// Transform normalized Y coordinate to pixel coordinate.
    // 2025-11-24-121500-pst: Active function
    fn normalized_to_pixel_y(self: *const GraphRenderer, normalized_y: f32) u32 {
        std.debug.assert(normalized_y >= 0.0);
        std.debug.assert(normalized_y <= 1.0);
        const offset_y = (normalized_y - self.graph_viz.center_y) * self.graph_viz.zoom;
        const pixel_y = (@as(f32, @floatFromInt(self.buffer_height)) * 0.5) + (offset_y * @as(f32, @floatFromInt(self.buffer_height)));
        const clamped = std.math.clamp(pixel_y, 0.0, @as(f32, @floatFromInt(self.buffer_height - 1)));
        return @as(u32, @intFromFloat(clamped));
    }
};

