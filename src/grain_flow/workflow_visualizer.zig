//! Grain Flow Workflow Visualizer: Visual workflow representation.
//!
//! Why: Provides visual representation of workflows for debugging and design.
//! Workflows are rendered as DAGs with nodes (agents/tasks) and edges (dependencies),
//! and can be exported to HTML/PDF via Bubble Agent export pipeline.
//!
//! Architecture: Workflow DAG rendering, node/edge visualization, state visualization.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-08-140000-pst: Phase 4 Workflow Visualizer Foundation

const std = @import("std");
const workflow_engine = @import("workflow_engine.zig");

// Bounded: Max SVG content length.
pub const MAX_SVG_CONTENT_LEN: u32 = 2 * 1024 * 1024; // 2 MB

// Bounded: Max HTML content length.
pub const MAX_HTML_CONTENT_LEN: u32 = 2 * 1024 * 1024; // 2 MB

// Bounded: Max node label length.
pub const MAX_NODE_LABEL_LEN: u32 = 128;

// Node position: 2D position for node rendering.
pub const NodePosition = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) NodePosition {
        return NodePosition{
            .x = x,
            .y = y,
        };
    }
};

// Node visual: visual representation of a workflow node.
pub const NodeVisual = struct {
    node_id: u32,
    position: NodePosition,
    width: u32,
    height: u32,
    label: [MAX_NODE_LABEL_LEN]u8,
    label_len: u32,
    status_color: u32, // ARGB color

    pub fn init(node_id: u32, position: NodePosition, label: []const u8) NodeVisual {
        std.debug.assert(node_id > 0);
        std.debug.assert(label.len > 0);
        var visual = NodeVisual{
            .node_id = node_id,
            .position = position,
            .width = 120,
            .height = 60,
            .label = undefined,
            .label_len = 0,
            .status_color = 0xFF000000, // Black by default
        };
        var i: u32 = 0;
        while (i < MAX_NODE_LABEL_LEN) : (i += 1) {
            visual.label[i] = 0;
        }
        const label_len = @min(label.len, MAX_NODE_LABEL_LEN);
        i = 0;
        while (i < label_len) : (i += 1) {
            visual.label[i] = label[i];
        }
        visual.label_len = @intCast(label_len);
        return visual;
    }

    pub fn set_status_color(self: *NodeVisual, status: workflow_engine.NodeStatus) void {
        std.debug.assert(self.node_id > 0);
        switch (status) {
            .pending => self.status_color = 0xFF808080, // Gray
            .running => self.status_color = 0xFF0000FF, // Blue
            .completed => self.status_color = 0xFF00FF00, // Green
            .failed => self.status_color = 0xFFFF0000, // Red
            .skipped => self.status_color = 0xFFFFFF00, // Yellow
        }
    }
};

// Edge visual: visual representation of a workflow edge.
pub const EdgeVisual = struct {
    from_node_id: u32,
    to_node_id: u32,
    edge_type: workflow_engine.EdgeType,
    color: u32, // ARGB color

    pub fn init(
        from_node_id: u32,
        to_node_id: u32,
        edge_type: workflow_engine.EdgeType,
    ) EdgeVisual {
        std.debug.assert(from_node_id > 0);
        std.debug.assert(to_node_id > 0);
        std.debug.assert(from_node_id != to_node_id);
        var visual = EdgeVisual{
            .from_node_id = from_node_id,
            .to_node_id = to_node_id,
            .edge_type = edge_type,
            .color = 0xFF000000, // Black by default
        };
        switch (edge_type) {
            .dependency => visual.color = 0xFF000000, // Black
            .data_flow => visual.color = 0xFF0000FF, // Blue
            .conditional => visual.color = 0xFFFF00FF, // Magenta
        }
        return visual;
    }
};

// Workflow visualizer: renders workflows visually.
pub const WorkflowVisualizer = struct {
    svg_content: [MAX_SVG_CONTENT_LEN]u8,
    svg_content_len: u32,
    html_content: [MAX_HTML_CONTENT_LEN]u8,
    html_content_len: u32,
    node_visuals: [workflow_engine.MAX_WORKFLOW_NODES]NodeVisual,
    node_visuals_len: u32,
    edge_visuals: [workflow_engine.MAX_WORKFLOW_EDGES]EdgeVisual,
    edge_visuals_len: u32,
    width: u32,
    height: u32,

    pub fn init(width: u32, height: u32) WorkflowVisualizer {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        var visualizer = WorkflowVisualizer{
            .svg_content = undefined,
            .svg_content_len = 0,
            .html_content = undefined,
            .html_content_len = 0,
            .node_visuals = undefined,
            .node_visuals_len = 0,
            .edge_visuals = undefined,
            .edge_visuals_len = 0,
            .width = width,
            .height = height,
        };
        var i: u32 = 0;
        while (i < MAX_SVG_CONTENT_LEN) : (i += 1) {
            visualizer.svg_content[i] = 0;
        }
        i = 0;
        while (i < MAX_HTML_CONTENT_LEN) : (i += 1) {
            visualizer.html_content[i] = 0;
        }
        i = 0;
        while (i < workflow_engine.MAX_WORKFLOW_NODES) : (i += 1) {
            visualizer.node_visuals[i] = NodeVisual.init(0, NodePosition.init(0, 0), "");
        }
        i = 0;
        while (i < workflow_engine.MAX_WORKFLOW_EDGES) : (i += 1) {
            visualizer.edge_visuals[i] = EdgeVisual.init(0, 0, workflow_engine.EdgeType.dependency);
        }
        return visualizer;
    }

    // Add node visual.
    pub fn add_node_visual(self: *WorkflowVisualizer, visual: NodeVisual) bool {
        std.debug.assert(visual.node_id > 0);
        if (self.node_visuals_len >= workflow_engine.MAX_WORKFLOW_NODES) {
            return false;
        }
        self.node_visuals[self.node_visuals_len] = visual;
        self.node_visuals_len += 1;
        return true;
    }

    // Add edge visual.
    pub fn add_edge_visual(self: *WorkflowVisualizer, visual: EdgeVisual) bool {
        std.debug.assert(visual.from_node_id > 0);
        std.debug.assert(visual.to_node_id > 0);
        if (self.edge_visuals_len >= workflow_engine.MAX_WORKFLOW_EDGES) {
            return false;
        }
        self.edge_visuals[self.edge_visuals_len] = visual;
        self.edge_visuals_len += 1;
        return true;
    }

    // Render workflow to SVG (iterative layout).
    pub fn render_to_svg(
        self: *WorkflowVisualizer,
        workflow: *const workflow_engine.Workflow,
    ) bool {
        std.debug.assert(workflow.workflow_id > 0);
        if (self.svg_content_len > 0) {
            return false; // Already rendered
        }
        // Simple grid layout (iterative, no recursion).
        var x: i32 = 100;
        var y: i32 = 100;
        const row_height: i32 = 100;
        var i: u32 = 0;
        while (i < workflow.nodes_len) : (i += 1) {
            const node = &workflow.nodes[i];
            var label_buf: [MAX_NODE_LABEL_LEN]u8 = undefined;
            const label_len = @min(node.name_len, MAX_NODE_LABEL_LEN);
            var j: u32 = 0;
            while (j < label_len) : (j += 1) {
                label_buf[j] = node.name[j];
            }
            const position = NodePosition.init(x, y);
            var visual = NodeVisual.init(node.node_id, position, label_buf[0..label_len]);
            visual.set_status_color(node.status);
            _ = self.add_node_visual(visual);
            x += 200;
            if (x > @as(i32, @intCast(self.width)) - 200) {
                x = 100;
                y += row_height;
            }
        }
        i = 0;
        while (i < workflow.edges_len) : (i += 1) {
            const edge = &workflow.edges[i];
            const edge_visual = EdgeVisual.init(
                edge.from_node_id,
                edge.to_node_id,
                edge.edge_type,
            );
            _ = self.add_edge_visual(edge_visual);
        }
        // Generate SVG content.
        _ = self.write_svg_header();
        _ = self.write_svg_edges();
        _ = self.write_svg_nodes();
        _ = self.write_svg_footer();
        return true;
    }

    // Render workflow to HTML.
    pub fn render_to_html(
        self: *WorkflowVisualizer,
        workflow: *const workflow_engine.Workflow,
    ) bool {
        std.debug.assert(workflow.workflow_id > 0);
        if (self.html_content_len > 0) {
            return false; // Already rendered
        }
        _ = self.render_to_svg(workflow);
        _ = self.write_html_header();
        _ = self.write_html_svg_embed();
        _ = self.write_html_footer();
        return true;
    }

    // Write SVG header.
    fn write_svg_header(self: *WorkflowVisualizer) bool {
        std.debug.assert(self.svg_content_len == 0);
        _ = self.write_svg_string("<svg width=\"");
        var width_buf: [32]u8 = undefined;
        const width_str = std.fmt.bufPrint(&width_buf, "{}", .{self.width}) catch return false;
        _ = self.write_svg_string(width_str);
        _ = self.write_svg_string("\" height=\"");
        var height_buf: [32]u8 = undefined;
        const height_str = std.fmt.bufPrint(&height_buf, "{}", .{self.height}) catch return false;
        _ = self.write_svg_string(height_str);
        _ = self.write_svg_string("\" xmlns=\"http://www.w3.org/2000/svg\">\n");
        return true;
    }

    // Write SVG footer.
    fn write_svg_footer(self: *WorkflowVisualizer) bool {
        const footer = "</svg>\n";
        return self.write_svg_string(footer);
    }

    // Write SVG edges.
    fn write_svg_edges(self: *WorkflowVisualizer) bool {
        var i: u32 = 0;
        while (i < self.edge_visuals_len) : (i += 1) {
            const edge = &self.edge_visuals[i];
            var from_pos: ?NodePosition = null;
            var to_pos: ?NodePosition = null;
            var j: u32 = 0;
            while (j < self.node_visuals_len) : (j += 1) {
                if (self.node_visuals[j].node_id == edge.from_node_id) {
                    from_pos = self.node_visuals[j].position;
                }
                if (self.node_visuals[j].node_id == edge.to_node_id) {
                    to_pos = self.node_visuals[j].position;
                }
            }
            if (from_pos != null and to_pos != null) {
                const color_hex = self.color_to_hex(edge.color);
                _ = self.write_svg_string("<line x1=\"");
                var x1_buf: [32]u8 = undefined;
                const x1_str = std.fmt.bufPrint(&x1_buf, "{}", .{from_pos.?.x}) catch continue;
                _ = self.write_svg_string(x1_str);
                _ = self.write_svg_string("\" y1=\"");
                var y1_buf: [32]u8 = undefined;
                const y1_str = std.fmt.bufPrint(&y1_buf, "{}", .{from_pos.?.y}) catch continue;
                _ = self.write_svg_string(y1_str);
                _ = self.write_svg_string("\" x2=\"");
                var x2_buf: [32]u8 = undefined;
                const x2_str = std.fmt.bufPrint(&x2_buf, "{}", .{to_pos.?.x}) catch continue;
                _ = self.write_svg_string(x2_str);
                _ = self.write_svg_string("\" y2=\"");
                var y2_buf: [32]u8 = undefined;
                const y2_str = std.fmt.bufPrint(&y2_buf, "{}", .{to_pos.?.y}) catch continue;
                _ = self.write_svg_string(y2_str);
                _ = self.write_svg_string("\" stroke=\"");
                _ = self.write_svg_string(&color_hex);
                _ = self.write_svg_string("\" stroke-width=\"2\"/>\n");
            }
        }
        return true;
    }

    // Write SVG nodes.
    fn write_svg_nodes(self: *WorkflowVisualizer) bool {
        var i: u32 = 0;
        while (i < self.node_visuals_len) : (i += 1) {
            const node = &self.node_visuals[i];
            const color_hex = self.color_to_hex(node.status_color);
            _ = self.write_svg_string("<rect x=\"");
            var x_buf: [32]u8 = undefined;
            const x_str = std.fmt.bufPrint(&x_buf, "{}", .{node.position.x}) catch continue;
            _ = self.write_svg_string(x_str);
            _ = self.write_svg_string("\" y=\"");
            var y_buf: [32]u8 = undefined;
            const y_str = std.fmt.bufPrint(&y_buf, "{}", .{node.position.y}) catch continue;
            _ = self.write_svg_string(y_str);
            _ = self.write_svg_string("\" width=\"");
            var w_buf: [32]u8 = undefined;
            const w_str = std.fmt.bufPrint(&w_buf, "{}", .{node.width}) catch continue;
            _ = self.write_svg_string(w_str);
            _ = self.write_svg_string("\" height=\"");
            var h_buf: [32]u8 = undefined;
            const h_str = std.fmt.bufPrint(&h_buf, "{}", .{node.height}) catch continue;
            _ = self.write_svg_string(h_str);
            _ = self.write_svg_string("\" fill=\"");
            _ = self.write_svg_string(&color_hex);
            _ = self.write_svg_string("\" stroke=\"#000000\" stroke-width=\"1\"/>\n");
            _ = self.write_svg_string("<text x=\"");
            const text_x = node.position.x + @as(i32, @intCast(node.width / 2));
            var tx_buf: [32]u8 = undefined;
            const tx_str = std.fmt.bufPrint(&tx_buf, "{}", .{text_x}) catch continue;
            _ = self.write_svg_string(tx_str);
            _ = self.write_svg_string("\" y=\"");
            const text_y = node.position.y + @as(i32, @intCast(node.height / 2));
            var ty_buf: [32]u8 = undefined;
            const ty_str = std.fmt.bufPrint(&ty_buf, "{}", .{text_y}) catch continue;
            _ = self.write_svg_string(ty_str);
            _ = self.write_svg_string("\" text-anchor=\"middle\" fill=\"#FFFFFF\">");
            _ = self.write_svg_string(node.label[0..node.label_len]);
            _ = self.write_svg_string("</text>\n");
        }
        return true;
    }

    // Write HTML header.
    fn write_html_header(self: *WorkflowVisualizer) bool {
        std.debug.assert(self.html_content_len == 0);
        const header = "<!DOCTYPE html>\n<html><head><title>Workflow</title></head><body>\n";
        return self.write_html_string(header);
    }

    // Write HTML SVG embed.
    fn write_html_svg_embed(self: *WorkflowVisualizer) bool {
        var i: u32 = 0;
        while (i < self.svg_content_len) : (i += 1) {
            if (!self.write_html_char(self.svg_content[i])) {
                return false;
            }
        }
        return true;
    }

    // Write HTML footer.
    fn write_html_footer(self: *WorkflowVisualizer) bool {
        const footer = "</body></html>\n";
        return self.write_html_string(footer);
    }

    // Write string to SVG content.
    fn write_svg_string(self: *WorkflowVisualizer, text: []const u8) bool {
        std.debug.assert(text.len > 0);
        if (self.svg_content_len + text.len > MAX_SVG_CONTENT_LEN) {
            return false;
        }
        var i: u32 = 0;
        while (i < text.len) : (i += 1) {
            self.svg_content[self.svg_content_len] = text[i];
            self.svg_content_len += 1;
        }
        return true;
    }

    // Write string to HTML content.
    fn write_html_string(self: *WorkflowVisualizer, text: []const u8) bool {
        std.debug.assert(text.len > 0);
        if (self.html_content_len + text.len > MAX_HTML_CONTENT_LEN) {
            return false;
        }
        var i: u32 = 0;
        while (i < text.len) : (i += 1) {
            self.html_content[self.html_content_len] = text[i];
            self.html_content_len += 1;
        }
        return true;
    }

    // Write char to HTML content.
    fn write_html_char(self: *WorkflowVisualizer, c: u8) bool {
        if (self.html_content_len >= MAX_HTML_CONTENT_LEN) {
            return false;
        }
        self.html_content[self.html_content_len] = c;
        self.html_content_len += 1;
        return true;
    }

    // Convert ARGB color to hex string.
    fn color_to_hex(self: *const WorkflowVisualizer, color: u32) [7]u8 {
        _ = self;
        const r = (color >> 24) & 0xFF;
        const g = (color >> 16) & 0xFF;
        const b = (color >> 8) & 0xFF;
        var hex: [7]u8 = undefined;
        _ = std.fmt.bufPrint(
            &hex,
            "#{:02X}{:02X}{:02X}",
            .{ r, g, b },
        ) catch return "#000000";
        return hex;
    }

    // Get SVG content.
    pub fn get_svg_content(self: *const WorkflowVisualizer) []const u8 {
        return self.svg_content[0..self.svg_content_len];
    }

    // Get HTML content.
    pub fn get_html_content(self: *const WorkflowVisualizer) []const u8 {
        return self.html_content[0..self.html_content_len];
    }

    // Clear visualizer.
    pub fn clear(self: *WorkflowVisualizer) void {
        self.svg_content_len = 0;
        self.html_content_len = 0;
        self.node_visuals_len = 0;
        self.edge_visuals_len = 0;
    }
};
