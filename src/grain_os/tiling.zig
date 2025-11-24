//! Grain OS Tiling: Dynamic window tiling layout.
//!
//! Why: Arrange windows in tiled layouts (master-stack, grid, etc.).
//! Architecture: Iterative algorithms (no recursion, Grain Style requirement).
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Max tree depth for tiling splits.
pub const MAX_TREE_DEPTH: u32 = 32;

// Bounded: Max windows per layout.
pub const MAX_LAYOUT_WINDOWS: u32 = 256;

// Split direction: vertical or horizontal.
pub const SplitDirection = enum {
    vertical,
    horizontal,
};

// Tiling node: represents a split or window in the tiling tree.
pub const TilingNode = struct {
    // Node type: split or window.
    node_type: NodeType,
    // Split direction (if split node).
    split_dir: SplitDirection,
    // Split ratio (0.0 to 1.0, if split node).
    split_ratio: f64,
    // Window ID (if window node).
    window_id: u32,
    // Child indices (if split node).
    left_child: u32,
    right_child: u32,
    // Parent index (for traversal).
    parent: u32,
    // Bounding box (x, y, width, height).
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    // Node index in tree array.
    index: u32,

    const NodeType = enum {
        split,
        window,
    };

    pub fn init_split(
        index: u32,
        split_dir: SplitDirection,
        split_ratio: f64,
        left_child: u32,
        right_child: u32,
    ) TilingNode {
        std.debug.assert(index < MAX_LAYOUT_WINDOWS);
        std.debug.assert(split_ratio >= 0.0);
        std.debug.assert(split_ratio <= 1.0);
        std.debug.assert(left_child < MAX_LAYOUT_WINDOWS);
        std.debug.assert(right_child < MAX_LAYOUT_WINDOWS);
        return TilingNode{
            .node_type = .split,
            .split_dir = split_dir,
            .split_ratio = split_ratio,
            .window_id = 0,
            .left_child = left_child,
            .right_child = right_child,
            .parent = MAX_LAYOUT_WINDOWS, // Invalid parent (root has no parent).
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
            .index = index,
        };
    }

    pub fn init_window(
        index: u32,
        window_id: u32,
    ) TilingNode {
        std.debug.assert(index < MAX_LAYOUT_WINDOWS);
        std.debug.assert(window_id > 0);
        return TilingNode{
            .node_type = .window,
            .split_dir = .vertical, // Unused for window nodes.
            .split_ratio = 0.0, // Unused for window nodes.
            .window_id = window_id,
            .left_child = MAX_LAYOUT_WINDOWS, // Invalid (no children).
            .right_child = MAX_LAYOUT_WINDOWS, // Invalid (no children).
            .parent = MAX_LAYOUT_WINDOWS, // Will be set when added to tree.
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
            .index = index,
        };
    }

    pub fn set_bounds(self: *TilingNode, x: i32, y: i32, width: u32, height: u32) void {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        self.x = x;
        self.y = y;
        self.width = width;
        self.height = height;
    }
};

// Tiling tree: manages window tiling layout.
pub const TilingTree = struct {
    nodes: [MAX_LAYOUT_WINDOWS]TilingNode,
    nodes_len: u32,
    root_index: u32,
    next_node_index: u32,

    pub fn init() TilingTree {
        var tree = TilingTree{
            .nodes = undefined,
            .nodes_len = 0,
            .root_index = MAX_LAYOUT_WINDOWS, // Invalid (no root yet).
            .next_node_index = 0,
        };
        var i: u32 = 0;
        while (i < MAX_LAYOUT_WINDOWS) : (i += 1) {
            tree.nodes[i] = TilingNode.init_window(i, 0);
        }
        std.debug.assert(tree.nodes_len == 0);
        return tree;
    }

    pub fn add_window(self: *TilingTree, window_id: u32) !void {
        std.debug.assert(window_id > 0);
        std.debug.assert(self.nodes_len < MAX_LAYOUT_WINDOWS);
        const node_index = self.next_node_index;
        self.next_node_index += 1;
        self.nodes[node_index] = TilingNode.init_window(node_index, window_id);
        self.nodes_len += 1;
        if (self.root_index == MAX_LAYOUT_WINDOWS) {
            // First window: set as root.
            self.root_index = node_index;
            self.nodes[node_index].parent = MAX_LAYOUT_WINDOWS;
        } else {
            // Add as split: create new split with old root and new window.
            const old_root = self.root_index;
            const split_index = self.next_node_index;
            self.next_node_index += 1;
            std.debug.assert(self.nodes_len < MAX_LAYOUT_WINDOWS);
            self.nodes_len += 1;
            // Create vertical split (main on left, new window on right).
            self.nodes[split_index] = TilingNode.init_split(
                split_index,
                .vertical,
                0.6, // 60% main, 40% new window.
                old_root,
                node_index,
            );
            self.nodes[old_root].parent = split_index;
            self.nodes[node_index].parent = split_index;
            self.root_index = split_index;
            self.nodes[split_index].parent = MAX_LAYOUT_WINDOWS;
        }
        std.debug.assert(self.nodes_len <= MAX_LAYOUT_WINDOWS);
        std.debug.assert(self.root_index < MAX_LAYOUT_WINDOWS);
    }

    pub fn remove_window(self: *TilingTree, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        // Find window node.
        var i: u32 = 0;
        var window_index: u32 = MAX_LAYOUT_WINDOWS;
        while (i < self.nodes_len) : (i += 1) {
            if (self.nodes[i].node_type == .window and
                self.nodes[i].window_id == window_id)
            {
                window_index = i;
                break;
            }
        }
        if (window_index == MAX_LAYOUT_WINDOWS) {
            return false; // Window not found.
        }
        // Remove window node and update tree.
        const parent_index = self.nodes[window_index].parent;
        if (parent_index == MAX_LAYOUT_WINDOWS) {
            // Window is root: clear tree.
            self.root_index = MAX_LAYOUT_WINDOWS;
            self.nodes_len = 0;
            self.next_node_index = 0;
            return true;
        }
        // Replace parent split with sibling.
        const parent = &self.nodes[parent_index];
        const sibling_index = if (parent.left_child == window_index)
            parent.right_child
        else
            parent.left_child;
        std.debug.assert(sibling_index < MAX_LAYOUT_WINDOWS);
        const grandparent_index = parent.parent;
        if (grandparent_index == MAX_LAYOUT_WINDOWS) {
            // Parent is root: sibling becomes root.
            self.root_index = sibling_index;
            self.nodes[sibling_index].parent = MAX_LAYOUT_WINDOWS;
        } else {
            // Replace parent with sibling in grandparent.
            const grandparent = &self.nodes[grandparent_index];
            if (grandparent.left_child == parent_index) {
                grandparent.left_child = sibling_index;
            } else {
                grandparent.right_child = sibling_index;
            }
            self.nodes[sibling_index].parent = grandparent_index;
        }
        // Note: We don't actually remove nodes from array (just mark as unused).
        // This is acceptable for Grain Style (bounded array, no dynamic allocation).
        return true;
    }

    // Calculate window positions using iterative algorithm (no recursion).
    pub fn calculate_layout(
        self: *TilingTree,
        output_x: i32,
        output_y: i32,
        output_width: u32,
        output_height: u32,
    ) void {
        std.debug.assert(output_width > 0);
        std.debug.assert(output_height > 0);
        if (self.root_index == MAX_LAYOUT_WINDOWS) {
            return; // Empty tree.
        }
        // Set root bounds.
        self.nodes[self.root_index].set_bounds(
            output_x,
            output_y,
            output_width,
            output_height,
        );
        // Iterative traversal: use stack to traverse tree.
        var stack: [MAX_TREE_DEPTH]u32 = undefined;
        var stack_len: u32 = 0;
        stack[stack_len] = self.root_index;
        stack_len += 1;
        while (stack_len > 0) {
            stack_len -= 1;
            const node_index = stack[stack_len];
            const node = &self.nodes[node_index];
            if (node.node_type == .split) {
                // Calculate child bounds based on split.
                const parent_x = node.x;
                const parent_y = node.y;
                const parent_width = node.width;
                const parent_height = node.height;
                if (node.split_dir == .vertical) {
                    // Vertical split: left and right.
                    const left_width = @as(u32, @intFromFloat(@as(f64, @floatFromInt(parent_width)) * node.split_ratio));
                    const right_width = parent_width - left_width;
                    std.debug.assert(left_width > 0);
                    std.debug.assert(right_width > 0);
                    self.nodes[node.left_child].set_bounds(
                        parent_x,
                        parent_y,
                        left_width,
                        parent_height,
                    );
                    self.nodes[node.right_child].set_bounds(
                        parent_x + @as(i32, @intCast(left_width)),
                        parent_y,
                        right_width,
                        parent_height,
                    );
                } else {
                    // Horizontal split: top and bottom.
                    const top_height = @as(u32, @intFromFloat(@as(f64, @floatFromInt(parent_height)) * node.split_ratio));
                    const bottom_height = parent_height - top_height;
                    std.debug.assert(top_height > 0);
                    std.debug.assert(bottom_height > 0);
                    self.nodes[node.left_child].set_bounds(
                        parent_x,
                        parent_y,
                        parent_width,
                        top_height,
                    );
                    self.nodes[node.right_child].set_bounds(
                        parent_x,
                        parent_y + @as(i32, @intCast(top_height)),
                        parent_width,
                        bottom_height,
                    );
                }
                // Push children onto stack.
                std.debug.assert(stack_len + 2 <= MAX_TREE_DEPTH);
                stack[stack_len] = node.right_child;
                stack_len += 1;
                stack[stack_len] = node.left_child;
                stack_len += 1;
            }
        }
    }

    // Get window bounds for a specific window ID.
    pub fn get_window_bounds(self: *TilingTree, window_id: u32) ?struct {
        x: i32,
        y: i32,
        width: u32,
        height: u32,
    } {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            if (self.nodes[i].node_type == .window and
                self.nodes[i].window_id == window_id)
            {
                return .{
                    .x = self.nodes[i].x,
                    .y = self.nodes[i].y,
                    .width = self.nodes[i].width,
                    .height = self.nodes[i].height,
                };
            }
        }
        return null;
    }
};
