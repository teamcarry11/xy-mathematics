const std = @import("std");
const Tab = @import("tab.zig").Tab;

/// Grain Terminal Pane: Represents a split pane in terminal.
/// ~<~ Glow Airbend: explicit pane state, bounded split management.
/// ~~~~ Glow Waterbend: deterministic pane layout, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Pane = struct {
    // Bounded: Max panes per split (explicit limit)
    pub const MAX_PANES: u32 = 16;

    /// Split direction enumeration.
    pub const SplitDirection = enum(u8) {
        horizontal, // Horizontal split (panes side by side)
        vertical, // Vertical split (panes stacked)
    };

    /// Pane structure.
    id: u32, // Pane ID (unique identifier)
    x: u32, // Pane X position (pixels)
    y: u32, // Pane Y position (pixels)
    width: u32, // Pane width (pixels)
    height: u32, // Pane height (pixels)
    tab: ?*Tab, // Associated tab (if leaf pane)
    split_direction: ?SplitDirection, // Split direction (if split pane)
    children: []Pane, // Child panes (if split pane)
    children_len: u32, // Number of children
    allocator: std.mem.Allocator,

    /// Initialize leaf pane (no split).
    pub fn init_leaf(allocator: std.mem.Allocator, id: u32, x: u32, y: u32, width: u32, height: u32) !Pane {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        // Assert: Dimensions must be valid
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        // Pre-allocate children buffer (even for leaf, for consistency)
        const children = try allocator.alloc(Pane, MAX_PANES);
        errdefer allocator.free(children);

        return Pane{
            .id = id,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .tab = null,
            .split_direction = null,
            .children = children,
            .children_len = 0,
            .allocator = allocator,
        };
    }

    /// Initialize split pane.
    pub fn init_split(allocator: std.mem.Allocator, id: u32, x: u32, y: u32, width: u32, height: u32, direction: SplitDirection) !Pane {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        // Assert: Dimensions must be valid
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        // Pre-allocate children buffer
        const children = try allocator.alloc(Pane, MAX_PANES);
        errdefer allocator.free(children);

        return Pane{
            .id = id,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .tab = null,
            .split_direction = direction,
            .children = children,
            .children_len = 0,
            .allocator = allocator,
        };
    }

    /// Deinitialize pane and free memory.
    pub fn deinit(self: *Pane) void {
        // Assert: Allocator must be valid
        std.debug.assert(self.allocator.ptr != null);

        // Deinitialize children
        var i: u32 = 0;
        while (i < self.children_len) : (i += 1) {
            self.children[i].deinit();
        }

        // Free children buffer
        self.allocator.free(self.children);

        self.* = undefined;
    }

    /// Add child pane to split.
    pub fn add_child(self: *Pane, child: Pane) !void {
        // Assert: Must be split pane
        std.debug.assert(self.split_direction != null);

        // Check children limit
        if (self.children_len >= MAX_PANES) {
            return error.TooManyPanes;
        }

        self.children[self.children_len] = child;
        self.children_len += 1;
    }

    /// Split pane (create split with two children).
    pub fn split(self: *Pane, allocator: std.mem.Allocator, direction: SplitDirection, split_pos: u32) !Pane {
        // Assert: Must be leaf pane
        std.debug.assert(self.split_direction == null);

        // Assert: Split position must be valid
        std.debug.assert(split_pos > 0);
        if (direction == .horizontal) {
            std.debug.assert(split_pos < self.width);
        } else {
            std.debug.assert(split_pos < self.height);
        }

        // Create new split pane
        var split_pane = try Pane.init_split(allocator, self.id, self.x, self.y, self.width, self.height, direction);

        // Create two child panes
        if (direction == .horizontal) {
            // Horizontal split: left and right panes
            var left_pane = try Pane.init_leaf(allocator, self.id + 1, self.x, self.y, split_pos, self.height);
            const right_pane = try Pane.init_leaf(allocator, self.id + 2, self.x + split_pos, self.y, self.width - split_pos, self.height);

            // Copy tab to left pane
            left_pane.tab = self.tab;

            try split_pane.add_child(left_pane);
            try split_pane.add_child(right_pane);
        } else {
            // Vertical split: top and bottom panes
            var top_pane = try Pane.init_leaf(allocator, self.id + 1, self.x, self.y, self.width, split_pos);
            const bottom_pane = try Pane.init_leaf(allocator, self.id + 2, self.x, self.y + split_pos, self.width, self.height - split_pos);

            // Copy tab to top pane
            top_pane.tab = self.tab;

            try split_pane.add_child(top_pane);
            try split_pane.add_child(bottom_pane);
        }

        return split_pane;
    }

    /// Check if pane is leaf (has tab).
    pub fn is_leaf(self: *const Pane) bool {
        return self.split_direction == null;
    }

    /// Get pane at position (for mouse clicks) - iterative implementation.
    pub fn get_pane_at(self: *Pane, x: u32, y: u32) ?*Pane {
        // Assert: Position must be valid
        std.debug.assert(x < 0xFFFFFFFF);
        std.debug.assert(y < 0xFFFFFFFF);

        // Use stack-based search (no recursion)
        var stack: [MAX_PANES]*Pane = undefined;
        var stack_len: u32 = 0;

        // Start with root pane
        stack[stack_len] = self;
        stack_len += 1;

        // Iterative search
        while (stack_len > 0) {
            stack_len -= 1;
            const current = stack[stack_len];

            // Check if point is within current pane
            if (x < current.x or x >= current.x + current.width or y < current.y or y >= current.y + current.height) {
                continue;
            }

            // If leaf, return it
            if (current.is_leaf()) {
                return current;
            }

            // Add children to stack (search in reverse order for depth-first)
            var i: u32 = current.children_len;
            while (i > 0) {
                i -= 1;
                if (stack_len < MAX_PANES) {
                    stack[stack_len] = &current.children[i];
                    stack_len += 1;
                }
            }
        }

        return null;
    }

    /// Set pane tab.
    pub fn set_tab(self: *Pane, tab: *Tab) void {
        // Assert: Must be leaf pane
        std.debug.assert(self.is_leaf());
        self.tab = tab;
    }

    /// Get pane tab.
    pub fn get_tab(self: *const Pane) ?*Tab {
        return self.tab;
    }
};

