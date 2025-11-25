//! Grain Skate Graph Renderer: Renders graph visualization to pixel buffer.
//!
//! Why: Draw nodes and edges to window buffer for display.
//! Architecture: Pixel buffer rendering, coordinate transformation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-11-24-121500-pst: Active implementation

const std = @import("std");
const GraphVisualization = @import("graph_viz.zig").GraphVisualization;
const Block = @import("block.zig").Block;

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

// Bounded: Max label length (explicit limit, in characters)
// 2025-11-24-171200-pst: Active constant
pub const MAX_LABEL_LEN: u32 = 32;

// Letter patterns for 5x7 bitmap font (A-Z).
// 2025-11-24-171200-pst: Active constant
const LETTER_PATTERNS = [26][7]u5{
    // A
    .{ 0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
    // B
    .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110 },
    // C
    .{ 0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110 },
    // D
    .{ 0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110 },
    // E
    .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111 },
    // F
    .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000 },
    // G
    .{ 0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110 },
    // H
    .{ 0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
    // I
    .{ 0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
    // J
    .{ 0b00111, 0b00010, 0b00010, 0b00010, 0b10010, 0b10010, 0b01100 },
    // K
    .{ 0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001 },
    // L
    .{ 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111 },
    // M
    .{ 0b10001, 0b11011, 0b10101, 0b10001, 0b10001, 0b10001, 0b10001 },
    // N
    .{ 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001 },
    // O
    .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
    // P
    .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000 },
    // Q
    .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101 },
    // R
    .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001 },
    // S
    .{ 0b01110, 0b10001, 0b10000, 0b01110, 0b00001, 0b10001, 0b01110 },
    // T
    .{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100 },
    // U
    .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
    // V
    .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100 },
    // W
    .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10101, 0b11011, 0b10001 },
    // X
    .{ 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b01010, 0b10001 },
    // Y
    .{ 0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100 },
    // Z
    .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111 },
};

// Graph renderer state.
// 2025-11-24-121500-pst: Active struct
pub const GraphRenderer = struct {
    graph_viz: *GraphVisualization,
    block_storage: ?*Block.BlockStorage,
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
            .block_storage = null,
            .buffer_width = buffer_width,
            .buffer_height = buffer_height,
        };
    }

    /// Set block storage for title lookup.
    // 2025-11-24-171200-pst: Active function
    pub fn set_block_storage(self: *GraphRenderer, block_storage: *Block.BlockStorage) void {
        self.block_storage = block_storage;
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

        // Render node labels
        self.render_labels(buffer);
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

    /// Render node labels (block IDs as numbers).
    // 2025-11-24-170000-pst: Active function
    fn render_labels(self: *const GraphRenderer, buffer: []u8) void {
        const text_r = @as(u8, @truncate((COLOR_TEXT >> 16) & 0xFF));
        const text_g = @as(u8, @truncate((COLOR_TEXT >> 8) & 0xFF));
        const text_b = @as(u8, @truncate(COLOR_TEXT & 0xFF));
        const text_a = @as(u8, @truncate((COLOR_TEXT >> 24) & 0xFF));

        var n: u32 = 0;
        while (n < self.graph_viz.nodes_len) : (n += 1) {
            if (!self.graph_viz.nodes[n].visible) {
                continue;
            }

            // Transform normalized coordinates to pixel coordinates
            const center_x = self.normalized_to_pixel_x(self.graph_viz.nodes[n].position.x);
            const center_y = self.normalized_to_pixel_y(self.graph_viz.nodes[n].position.y);
            const radius = @as(u32, @intFromFloat(self.graph_viz.nodes[n].radius * self.graph_viz.zoom));

            // Label position: below node (center_y + radius + offset)
            const label_y = center_y + radius + 12;
            const label_x = center_x;

            // Render block title if available, otherwise render block ID
            if (self.block_storage) |storage| {
                if (storage.get_block(self.graph_viz.nodes[n].block_id)) |block| {
                    if (block.title_len > 0) {
                        self.draw_text(buffer, block.title[0..block.title_len], label_x, label_y, text_r, text_g, text_b, text_a);
                        continue;
                    }
                }
            }
            // Fallback to block ID if no title available
            self.draw_number(buffer, self.graph_viz.nodes[n].block_id, label_x, label_y, text_r, text_g, text_b, text_a);
        }
    }

    /// Draw number at position (simple 5x7 bitmap font for digits).
    // 2025-11-24-170000-pst: Active function
    fn draw_number(self: *const GraphRenderer, buffer: []u8, number: u32, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        // Convert number to string (max 10 digits for u32)
        var digits: [10]u8 = undefined;
        var num = number;
        var digit_count: u32 = 0;

        if (num == 0) {
            digits[0] = '0';
            digit_count = 1;
        } else {
            while (num > 0 and digit_count < 10) : (digit_count += 1) {
                digits[9 - digit_count] = @as(u8, @intCast('0' + (num % 10)));
                num /= 10;
            }
        }

        // Draw each digit
        var i: u32 = 0;
        while (i < digit_count) : (i += 1) {
            const digit = digits[10 - digit_count + i];
            const digit_x = x + (i * 6); // 6 pixels per digit (5 width + 1 spacing)
            self.draw_digit(buffer, digit, digit_x, y, r, g, b, a);
        }
    }

    /// Draw single digit using simple 5x7 bitmap font.
    // 2025-11-24-170000-pst: Active function
    fn draw_digit(self: *const GraphRenderer, buffer: []u8, digit: u8, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        // Simple 5x7 bitmap patterns for digits 0-9
        const patterns = [10][7]u5{
            // 0
            .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
            // 1
            .{ 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
            // 2
            .{ 0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111 },
            // 3
            .{ 0b01110, 0b10001, 0b00001, 0b00110, 0b00001, 0b10001, 0b01110 },
            // 4
            .{ 0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010 },
            // 5
            .{ 0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110 },
            // 6
            .{ 0b00110, 0b01000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110 },
            // 7
            .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000 },
            // 8
            .{ 0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110 },
            // 9
            .{ 0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00010, 0b01100 },
        };

        if (digit < '0' or digit > '9') {
            return; // Invalid digit
        }

        const pattern_idx = digit - '0';
        const pattern = patterns[pattern_idx];

        // Draw pattern (5x7)
        var row: u32 = 0;
        while (row < 7) : (row += 1) {
            var col: u32 = 0;
            while (col < 5) : (col += 1) {
                if ((pattern[row] & (@as(u5, 1) << @as(u3, @intCast(4 - col)))) != 0) {
                    const px = x + col;
                    const py = y + row;
                    if (px < self.buffer_width and py < self.buffer_height) {
                        const idx = (py * self.buffer_width + px) * 4;
                        buffer[idx + 0] = r;
                        buffer[idx + 1] = g;
                        buffer[idx + 2] = b;
                        buffer[idx + 3] = a;
                    }
                }
            }
        }
    }

    /// Draw text string (supports alphanumeric and basic punctuation).
    // 2025-11-24-171200-pst: Active function
    fn draw_text(self: *const GraphRenderer, buffer: []u8, text: []const u8, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        // Truncate text to max label length
        const text_len = @min(text.len, MAX_LABEL_LEN);
        var char_x = x;

        // Draw each character
        var i: u32 = 0;
        while (i < text_len) : (i += 1) {
            const ch = text[i];
            if (self.draw_char(buffer, ch, char_x, y, r, g, b, a)) {
                char_x += 6; // 6 pixels per character (5 width + 1 spacing)
            }
        }
    }

    /// Draw single character (supports digits, letters, space, basic punctuation).
    // 2025-11-24-171200-pst: Active function
    fn draw_char(self: *const GraphRenderer, buffer: []u8, ch: u8, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) bool {
        // Handle digits (already implemented)
        if (ch >= '0' and ch <= '9') {
            self.draw_digit(buffer, ch, x, y, r, g, b, a);
            return true;
        }

        // Handle space
        if (ch == ' ') {
            return true; // Skip space (no rendering needed)
        }

        // Handle uppercase letters (A-Z)
        if (ch >= 'A' and ch <= 'Z') {
            self.draw_letter_upper(buffer, ch, x, y, r, g, b, a);
            return true;
        }

        // Handle lowercase letters (a-z) - render as uppercase for simplicity
        if (ch >= 'a' and ch <= 'z') {
            const upper_ch = ch - ('a' - 'A');
            self.draw_letter_upper(buffer, upper_ch, x, y, r, g, b, a);
            return true;
        }

        // Unsupported character - skip
        return false;
    }

    /// Draw uppercase letter using simple 5x7 bitmap font.
    // 2025-11-24-171200-pst: Active function
    fn draw_letter_upper(self: *const GraphRenderer, buffer: []u8, letter: u8, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        if (letter < 'A' or letter > 'Z') {
            return; // Invalid letter
        }

        const pattern_idx = letter - 'A';
        const pattern = LETTER_PATTERNS[pattern_idx];

        // Draw pattern (5x7)
        self.draw_pattern(buffer, pattern, x, y, r, g, b, a);
    }

    /// Draw 5x7 pattern to buffer.
    // 2025-11-24-171200-pst: Active function
    fn draw_pattern(self: *const GraphRenderer, buffer: []u8, pattern: [7]u5, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        var row: u32 = 0;
        while (row < 7) : (row += 1) {
            var col: u32 = 0;
            while (col < 5) : (col += 1) {
                if ((pattern[row] & (@as(u5, 1) << @as(u3, @intCast(4 - col)))) != 0) {
                    const px = x + col;
                    const py = y + row;
                    if (px < self.buffer_width and py < self.buffer_height) {
                        const idx = (py * self.buffer_width + px) * 4;
                        buffer[idx + 0] = r;
                        buffer[idx + 1] = g;
                        buffer[idx + 2] = b;
                        buffer[idx + 3] = a;
                    }
                }
            }
        }
    }
};

