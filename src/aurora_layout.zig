const std = @import("std");

/// Multi-pane layout system inspired by River compositor.
/// ~<~ Glow Airbend: explicit layout tree, bounded panes.
/// ~~~~ Glow Waterbend: layout flows deterministically from split operations.
pub const Layout = struct {
    allocator: std.mem.Allocator,
    root: ?*Pane = null,
    
    // Bounded: Max 100 panes per workspace
    pub const MAX_PANES: u32 = 100;
    pane_count: u32 = 0,
    
    // Bounded: Max 10 workspaces
    pub const MAX_WORKSPACES: u32 = 10;
    workspaces: std.ArrayList(Workspace) = undefined,
    current_workspace: u32 = 0,
    
    pub const Pane = struct {
        id: u32,
        rect: Rectangle,
        pane_type: PaneType,
        parent: ?*Pane = null,
        left: ?*Pane = null,
        right: ?*Pane = null,
        focused: bool = false,
    };
    
    pub const Rectangle = struct {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    };
    
    pub const PaneType = enum {
        editor,
        terminal,
        vcs_status,
        browser,
    };
    
    pub const SplitDirection = enum {
        horizontal,
        vertical,
    };
    
    pub const Workspace = struct {
        id: u32,
        name: []const u8,
        root: ?*Pane = null,
    };
    
    pub fn init(allocator: std.mem.Allocator) Layout {
        return Layout{
            .allocator = allocator,
            .workspaces = std.ArrayList(Workspace).init(allocator),
        };
    }
    
    pub fn deinit(self: *Layout) void {
        // Free all panes (iterative, no recursion)
        if (self.root) |root| {
            self.free_pane_tree(root);
        }
        
        // Free workspace names
        for (self.workspaces.items) |*ws| {
            self.allocator.free(ws.name);
            if (ws.root) |root| {
                self.free_pane_tree(root);
            }
        }
        self.workspaces.deinit();
        
        self.* = undefined;
    }
    
    /// Free pane tree iteratively (no recursion, GrainStyle).
    fn free_pane_tree(self: *Layout, root: *Pane) void {
        // Assert: Root must be valid
        std.debug.assert(root != null);
        
        // Use explicit stack instead of recursion
        // Bounded: Max stack depth of MAX_PANES
        var stack: [MAX_PANES]?*Pane = undefined;
        var stack_len: u32 = 0;
        
        stack[stack_len] = root;
        stack_len += 1;
        
        while (stack_len > 0) {
            // Assert: Stack depth within bounds
            std.debug.assert(stack_len <= MAX_PANES);
            
            stack_len -= 1;
            const current = stack[stack_len].?;
            
            // Add children to stack
            if (current.left) |left| {
                // Assert: Stack has room
                std.debug.assert(stack_len < MAX_PANES);
                stack[stack_len] = left;
                stack_len += 1;
            }
            if (current.right) |right| {
                // Assert: Stack has room
                std.debug.assert(stack_len < MAX_PANES);
                stack[stack_len] = right;
                stack_len += 1;
            }
            
            // Free current pane
            self.allocator.destroy(current);
            self.pane_count -= 1;
        }
    }
    
    /// Create initial workspace with single editor pane.
    pub fn create_workspace(self: *Layout, name: []const u8, width: u32, height: u32) !u32 {
        // Assert: Name and dimensions must be valid
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= 256); // Bounded name length
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(width <= 16384); // Bounded width (16K)
        std.debug.assert(height <= 16384); // Bounded height (16K)
        
        // Assert: Bounded workspaces
        std.debug.assert(self.workspaces.items.len < MAX_WORKSPACES);
        
        // Create root pane (editor)
        const pane = try self.allocator.create(Pane);
        pane.* = Pane{
            .id = self.pane_count,
            .rect = Rectangle{
                .x = 0,
                .y = 0,
                .width = width,
                .height = height,
            },
            .pane_type = .editor,
            .focused = true,
        };
        self.pane_count += 1;
        
        // Assert: Bounded panes
        std.debug.assert(self.pane_count <= MAX_PANES);
        
        // Create workspace
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        
        const workspace_id = @intCast(self.workspaces.items.len);
        try self.workspaces.append(Workspace{
            .id = workspace_id,
            .name = name_copy,
            .root = pane,
        });
        
        // Set as root if first workspace
        if (self.workspaces.items.len == 1) {
            self.root = pane;
        }
        
        // Assert: Workspace created successfully
        std.debug.assert(self.workspaces.items.len <= MAX_WORKSPACES);
        
        return workspace_id;
    }
    
    /// Split focused pane in given direction.
    pub fn split_pane(self: *Layout, direction: SplitDirection, pane_type: PaneType) !void {
        // Assert: Must have root pane
        std.debug.assert(self.root != null);
        std.debug.assert(self.pane_count < MAX_PANES);
        
        // Find focused pane
        const focused = self.find_focused_pane() orelse return error.NoFocusedPane;
        
        // Create new pane
        const new_pane = try self.allocator.create(Pane);
        new_pane.* = Pane{
            .id = self.pane_count,
            .rect = Rectangle{
                .x = 0,
                .y = 0,
                .width = 0,
                .height = 0,
            },
            .pane_type = pane_type,
            .parent = focused,
        };
        self.pane_count += 1;
        
        // Assert: Bounded panes
        std.debug.assert(self.pane_count <= MAX_PANES);
        
        // Split focused pane
        if (direction == .horizontal) {
            // Horizontal split: left/right
            const new_width = focused.rect.width / 2;
            const old_width = focused.rect.width - new_width;
            
            new_pane.rect = Rectangle{
                .x = focused.rect.x + @intCast(old_width),
                .y = focused.rect.y,
                .width = new_width,
                .height = focused.rect.height,
            };
            
            focused.rect.width = old_width;
            focused.left = new_pane;
        } else {
            // Vertical split: top/bottom
            const new_height = focused.rect.height / 2;
            const old_height = focused.rect.height - new_height;
            
            new_pane.rect = Rectangle{
                .x = focused.rect.x,
                .y = focused.rect.y + @intCast(old_height),
                .width = focused.rect.width,
                .height = new_height,
            };
            
            focused.rect.height = old_height;
            focused.right = new_pane;
        }
        
        // Focus new pane
        focused.focused = false;
        new_pane.focused = true;
        
        // Assert: Split successful
        std.debug.assert(new_pane.rect.width > 0);
        std.debug.assert(new_pane.rect.height > 0);
    }
    
    /// Find focused pane (iterative search, no recursion).
    fn find_focused_pane(self: *Layout) ?*Pane {
        if (self.root == null) return null;
        
        // Use explicit stack instead of recursion
        var stack: [MAX_PANES]?*Pane = undefined;
        var stack_len: u32 = 0;
        
        stack[stack_len] = self.root;
        stack_len += 1;
        
        while (stack_len > 0) {
            // Assert: Stack depth within bounds
            std.debug.assert(stack_len <= MAX_PANES);
            
            stack_len -= 1;
            const current = stack[stack_len].?;
            
            // Check if focused
            if (current.focused) {
                return current;
            }
            
            // Add children to stack
            if (current.left) |left| {
                // Assert: Stack has room
                std.debug.assert(stack_len < MAX_PANES);
                stack[stack_len] = left;
                stack_len += 1;
            }
            if (current.right) |right| {
                // Assert: Stack has room
                std.debug.assert(stack_len < MAX_PANES);
                stack[stack_len] = right;
                stack_len += 1;
            }
        }
        
        return null;
    }
    
    /// Focus next pane (River-style navigation).
    pub fn focus_next(self: *Layout) void {
        // Assert: Must have root
        std.debug.assert(self.root != null);
        
        const focused = self.find_focused_pane() orelse return;
        
        // Find next pane in traversal order (left-to-right, top-to-bottom)
        const next = self.find_next_pane(focused);
        if (next) |n| {
            focused.focused = false;
            n.focused = true;
        }
    }
    
    /// Find next pane in traversal order (iterative).
    fn find_next_pane(self: *Layout, current: *Pane) ?*Pane {
        _ = self;
        
        // Simple traversal: prefer left, then right, then parent's right
        if (current.left) |left| {
            return left;
        }
        if (current.right) |right| {
            return right;
        }
        
        // Go up to parent and try its right sibling
        var parent = current.parent;
        while (parent) |p| {
            if (p.right) |right| {
                if (right.id != current.id) {
                    return right;
                }
            }
            parent = p.parent;
        }
        
        return null;
    }
    
    /// Close focused pane (merge with sibling or parent).
    pub fn close_pane(self: *Layout) !void {
        // Assert: Must have root
        std.debug.assert(self.root != null);
        
        const focused = self.find_focused_pane() orelse return error.NoFocusedPane;
        
        // Cannot close root if it's the only pane
        if (focused.parent == null and focused.left == null and focused.right == null) {
            return error.CannotCloseLastPane;
        }
        
        // If has parent, merge with sibling
        if (focused.parent) |parent| {
            // Give sibling focus
            if (parent.left) |left| {
                if (left.id == focused.id) {
                    // Focus is left child, focus right sibling
                    if (parent.right) |right| {
                        right.focused = true;
                        // Merge right into parent
                        parent.rect = right.rect;
                        parent.left = right.left;
                        parent.right = right.right;
                        self.allocator.destroy(right);
                        self.pane_count -= 1;
                    } else {
                        // No right sibling, become parent
                        parent.focused = true;
                        parent.left = null;
                    }
                } else {
                    // Focus is right child, focus left sibling
                    if (parent.left) |left| {
                        left.focused = true;
                        // Merge left into parent
                        parent.rect = left.rect;
                        parent.left = left.left;
                        parent.right = left.right;
                        self.allocator.destroy(left);
                        self.pane_count -= 1;
                    } else {
                        // No left sibling, become parent
                        parent.focused = true;
                        parent.right = null;
                    }
                }
            }
            
            // Free focused pane
            self.allocator.destroy(focused);
            self.pane_count -= 1;
        } else {
            // Root pane: replace with child
            if (focused.left) |left| {
                left.focused = true;
                left.parent = null;
                self.root = left;
                self.allocator.destroy(focused);
                self.pane_count -= 1;
            } else if (focused.right) |right| {
                right.focused = true;
                right.parent = null;
                self.root = right;
                self.allocator.destroy(focused);
                self.pane_count -= 1;
            }
        }
        
        // Assert: Pane count valid
        std.debug.assert(self.pane_count > 0);
    }
    
    /// Switch to workspace (River-style workspace switching).
    pub fn switch_workspace(self: *Layout, workspace_id: u32) !void {
        // Assert: Workspace ID must be valid
        std.debug.assert(workspace_id < MAX_WORKSPACES);
        std.debug.assert(workspace_id < self.workspaces.items.len);
        
        self.current_workspace = workspace_id;
        const workspace = &self.workspaces.items[workspace_id];
        self.root = workspace.root;
        
        // Assert: Workspace switched successfully
        std.debug.assert(self.root != null);
    }
    
    /// Get all panes in current workspace (for rendering).
    pub fn get_panes(self: *Layout, panes: *std.ArrayList(*Pane)) !void {
        // Assert: Must have root
        std.debug.assert(self.root != null);
        
        // Clear existing panes
        panes.clearRetainingCapacity();
        
        // Traverse tree and collect all panes (iterative)
        var stack: [MAX_PANES]?*Pane = undefined;
        var stack_len: u32 = 0;
        
        stack[stack_len] = self.root;
        stack_len += 1;
        
        while (stack_len > 0) {
            // Assert: Stack depth within bounds
            std.debug.assert(stack_len <= MAX_PANES);
            
            stack_len -= 1;
            const current = stack[stack_len].?;
            
            // Add to list
            try panes.append(current);
            
            // Add children to stack
            if (current.left) |left| {
                // Assert: Stack has room
                std.debug.assert(stack_len < MAX_PANES);
                stack[stack_len] = left;
                stack_len += 1;
            }
            if (current.right) |right| {
                // Assert: Stack has room
                std.debug.assert(stack_len < MAX_PANES);
                stack[stack_len] = right;
                stack_len += 1;
            }
        }
        
        // Assert: Panes collected successfully
        std.debug.assert(panes.items.len <= MAX_PANES);
    }
    
    /// Resize layout to new dimensions (recalculate all pane rectangles).
    pub fn resize(self: *Layout, width: u32, height: u32) !void {
        // Assert: Dimensions must be valid
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(width <= 16384); // Bounded width
        std.debug.assert(height <= 16384); // Bounded height
        
        if (self.root == null) return;
        
        // Resize root pane
        self.root.?.rect.width = width;
        self.root.?.rect.height = height;
        
        // Recursively resize children (iterative)
        var stack: [MAX_PANES]?*Pane = undefined;
        var stack_len: u32 = 0;
        
        stack[stack_len] = self.root;
        stack_len += 1;
        
        while (stack_len > 0) {
            // Assert: Stack depth within bounds
            std.debug.assert(stack_len <= MAX_PANES);
            
            stack_len -= 1;
            const current = stack[stack_len].?;
            
            // Resize children based on split direction
            if (current.left) |left| {
                if (current.right) |right| {
                    // Both children: determine split direction
                    if (left.rect.x == current.rect.x) {
                        // Vertical split (top/bottom)
                        const left_height = current.rect.height / 2;
                        const right_height = current.rect.height - left_height;
                        
                        left.rect = Rectangle{
                            .x = current.rect.x,
                            .y = current.rect.y,
                            .width = current.rect.width,
                            .height = left_height,
                        };
                        
                        right.rect = Rectangle{
                            .x = current.rect.x,
                            .y = current.rect.y + @intCast(left_height),
                            .width = current.rect.width,
                            .height = right_height,
                        };
                    } else {
                        // Horizontal split (left/right)
                        const left_width = current.rect.width / 2;
                        const right_width = current.rect.width - left_width;
                        
                        left.rect = Rectangle{
                            .x = current.rect.x,
                            .y = current.rect.y,
                            .width = left_width,
                            .height = current.rect.height,
                        };
                        
                        right.rect = Rectangle{
                            .x = current.rect.x + @intCast(left_width),
                            .y = current.rect.y,
                            .width = right_width,
                            .height = current.rect.height,
                        };
                    }
                    
                    // Add children to stack
                    // Assert: Stack has room
                    std.debug.assert(stack_len + 2 <= MAX_PANES);
                    stack[stack_len] = left;
                    stack_len += 1;
                    stack[stack_len] = right;
                    stack_len += 1;
                } else {
                    // Only left child: fill parent
                    left.rect = current.rect;
                    // Assert: Stack has room
                    std.debug.assert(stack_len < MAX_PANES);
                    stack[stack_len] = left;
                    stack_len += 1;
                }
            } else if (current.right) |right| {
                // Only right child: fill parent
                right.rect = current.rect;
                // Assert: Stack has room
                std.debug.assert(stack_len < MAX_PANES);
                stack[stack_len] = right;
                stack_len += 1;
            }
        }
    }
};

test "layout create workspace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var layout = Layout.init(arena.allocator());
    defer layout.deinit();
    
    const workspace_id = try layout.create_workspace("main", 1920, 1080);
    
    // Assert: Workspace created
    std.debug.assert(workspace_id == 0);
    std.debug.assert(layout.root != null);
    std.debug.assert(layout.root.?.pane_type == .editor);
    std.debug.assert(layout.root.?.focused == true);
}

test "layout split pane" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var layout = Layout.init(arena.allocator());
    defer layout.deinit();
    
    _ = try layout.create_workspace("main", 1920, 1080);
    try layout.split_pane(.horizontal, .terminal);
    
    // Assert: Split successful
    std.debug.assert(layout.pane_count == 2);
    std.debug.assert(layout.root.?.left != null);
    std.debug.assert(layout.root.?.left.?.pane_type == .terminal);
    std.debug.assert(layout.root.?.left.?.focused == true);
}

test "layout focus next" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var layout = Layout.init(arena.allocator());
    defer layout.deinit();
    
    _ = try layout.create_workspace("main", 1920, 1080);
    try layout.split_pane(.horizontal, .terminal);
    
    // Focus should be on terminal
    std.debug.assert(layout.root.?.left.?.focused == true);
    
    // Focus next should go back to editor
    layout.focus_next();
    
    // Assert: Focus moved
    std.debug.assert(layout.root.?.focused == true);
    std.debug.assert(layout.root.?.left.?.focused == false);
}

