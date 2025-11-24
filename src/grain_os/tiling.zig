//! Grain OS Tiling: Dynamic tiling engine for window management.
//!
//! Why: River-inspired dynamic tiling with clean-room implementation.
//! Architecture: View/container tree, iterative layout calculation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-11-23-170000-pst: Active implementation

const std = @import("std");
const wayland = @import("wayland/protocol.zig");

// Bounded: Max number of views (windows) in tiling system.
// 2025-11-23-170000-pst: Active constant
pub const MAX_VIEWS: u32 = 1024;

// Bounded: Max number of children per container.
// 2025-11-23-170000-pst: Active constant
pub const MAX_CONTAINER_CHILDREN: u32 = 256;

// Bounded: Max number of tags (bitmask-based, u32 = 32 tags).
// 2025-11-23-170000-pst: Active constant
pub const MAX_TAGS: u32 = 32;

// Bounded: Max tag name length.
// 2025-11-23-170000-pst: Active constant
pub const MAX_TAG_NAME_LEN: u32 = 64;

// Tag bitmask type (32 tags max).
// 2025-11-23-170000-pst: Active type
pub const TagMask = u32;

// Container type enumeration.
// 2025-11-23-170000-pst: Active enum
pub const ContainerType = enum(u8) {
    horizontal, // Horizontal split (left/right)
    vertical, // Vertical split (top/bottom)
    stack, // Stacked views (overlapping)
};

// View: represents a window/view in the tiling system.
// 2025-11-23-170000-pst: Active struct
pub const View = struct {
    id: u32, // View ID (unique identifier)
    surface_id: wayland.ObjectId, // Wayland surface ID
    x: i32, // X position (calculated by layout)
    y: i32, // Y position (calculated by layout)
    width: u32, // Width (calculated by layout)
    height: u32, // Height (calculated by layout)
    tags: TagMask, // Tag bitmask (multiple tags per view)
    focused: bool, // Focus state
    visible: bool, // Visibility state

    /// Initialize view.
    // 2025-11-23-170000-pst: Active function
    pub fn init(id: u32, surface_id: wayland.ObjectId) View {
        std.debug.assert(id > 0);
        std.debug.assert(surface_id > 0);
        const view = View{
            .id = id,
            .surface_id = surface_id,
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
            .tags = 0,
            .focused = false,
            .visible = true,
        };
        std.debug.assert(view.id > 0);
        return view;
    }

    /// Add tag to view.
    // 2025-11-23-170000-pst: Active function
    pub fn add_tag(self: *View, tag_index: u32) void {
        std.debug.assert(tag_index < MAX_TAGS);
        self.tags |= @as(TagMask, 1) << tag_index;
        std.debug.assert(tag_index < MAX_TAGS);
    }

    /// Remove tag from view.
    // 2025-11-23-170000-pst: Active function
    pub fn remove_tag(self: *View, tag_index: u32) void {
        std.debug.assert(tag_index < MAX_TAGS);
        self.tags &= ~(@as(TagMask, 1) << tag_index);
    }

    /// Check if view has tag.
    // 2025-11-23-170000-pst: Active function
    pub fn has_tag(self: *const View, tag_index: u32) bool {
        std.debug.assert(tag_index < MAX_TAGS);
        return (self.tags & (@as(TagMask, 1) << tag_index)) != 0;
    }
};

// Container: represents a tiling container (split, stack, etc.).
// 2025-11-23-170000-pst: Active struct
pub const Container = struct {
    id: u32, // Container ID (unique identifier)
    container_type: ContainerType, // Container type
    x: i32, // X position (calculated by layout)
    y: i32, // Y position (calculated by layout)
    width: u32, // Width (calculated by layout)
    height: u32, // Height (calculated by layout)
    children: [MAX_CONTAINER_CHILDREN]u32, // Child view/container IDs
    children_len: u32, // Number of children
    is_view: bool, // True if child is a view, false if container

    /// Initialize container.
    // 2025-11-23-170000-pst: Active function
    pub fn init(id: u32, container_type: ContainerType) Container {
        std.debug.assert(id > 0);
        var container = Container{
            .id = id,
            .container_type = container_type,
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
            .children = undefined,
            .children_len = 0,
            .is_view = true, // Default: children are views
        };
        var i: u32 = 0;
        while (i < MAX_CONTAINER_CHILDREN) : (i += 1) {
            container.children[i] = 0;
        }
        std.debug.assert(container.id > 0);
        return container;
    }

    /// Add child view/container to container.
    // 2025-11-23-170000-pst: Active function
    pub fn add_child(self: *Container, child_id: u32) void {
        std.debug.assert(child_id > 0);
        std.debug.assert(self.children_len < MAX_CONTAINER_CHILDREN);
        self.children[self.children_len] = child_id;
        self.children_len += 1;
        std.debug.assert(self.children_len <= MAX_CONTAINER_CHILDREN);
    }
};

// Tiling engine: manages views and containers, calculates layouts.
// 2025-11-23-170000-pst: Active struct
pub const TilingEngine = struct {
    views: [MAX_VIEWS]View, // All views
    views_len: u32, // Number of views
    containers: [MAX_VIEWS]Container, // All containers (bounded by MAX_VIEWS)
    containers_len: u32, // Number of containers
    root_container_id: u32, // Root container ID (0 = no root)
    next_view_id: u32, // Next view ID to assign
    next_container_id: u32, // Next container ID to assign
    allocator: std.mem.Allocator,

    /// Initialize tiling engine.
    // 2025-11-23-170000-pst: Active function
    pub fn init(allocator: std.mem.Allocator) TilingEngine {
        var engine = TilingEngine{
            .views = undefined,
            .views_len = 0,
            .containers = undefined,
            .containers_len = 0,
            .root_container_id = 0,
            .next_view_id = 1,
            .next_container_id = 1,
            .allocator = allocator,
        };
        var i: u32 = 0;
        while (i < MAX_VIEWS) : (i += 1) {
            engine.views[i] = View.init(0, 0);
            engine.containers[i] = Container.init(0, .horizontal);
        }
        std.debug.assert(engine.next_view_id > 0);
        std.debug.assert(engine.next_container_id > 0);
        return engine;
    }

    /// Create view.
    // 2025-11-23-170000-pst: Active function
    pub fn create_view(self: *TilingEngine, surface_id: wayland.ObjectId) !u32 {
        std.debug.assert(surface_id > 0);
        std.debug.assert(self.views_len < MAX_VIEWS);
        const view_id = self.next_view_id;
        self.next_view_id += 1;
        const view = View.init(view_id, surface_id);
        self.views[self.views_len] = view;
        self.views_len += 1;
        std.debug.assert(self.views_len <= MAX_VIEWS);
        std.debug.assert(view_id > 0);
        return view_id;
    }

    /// Get view by ID.
    // 2025-11-23-170000-pst: Active function
    pub fn get_view(self: *TilingEngine, view_id: u32) ?*View {
        std.debug.assert(view_id > 0);
        var i: u32 = 0;
        while (i < self.views_len) : (i += 1) {
            if (self.views[i].id == view_id) {
                return &self.views[i];
            }
        }
        return null;
    }

    /// Create container.
    // 2025-11-23-170000-pst: Active function
    pub fn create_container(self: *TilingEngine, container_type: ContainerType) !u32 {
        std.debug.assert(self.containers_len < MAX_VIEWS);
        const container_id = self.next_container_id;
        self.next_container_id += 1;
        const container = Container.init(container_id, container_type);
        self.containers[self.containers_len] = container;
        self.containers_len += 1;
        std.debug.assert(self.containers_len <= MAX_VIEWS);
        std.debug.assert(container_id > 0);
        return container_id;
    }

    /// Get container by ID.
    // 2025-11-23-170000-pst: Active function
    pub fn get_container(self: *TilingEngine, container_id: u32) ?*Container {
        std.debug.assert(container_id > 0);
        var i: u32 = 0;
        while (i < self.containers_len) : (i += 1) {
            if (self.containers[i].id == container_id) {
                return &self.containers[i];
            }
        }
        return null;
    }

    /// Calculate layout for container tree (iterative, no recursion).
    // 2025-11-23-170000-pst: Active function
    pub fn calculate_layout(
        self: *TilingEngine,
        container_id: u32,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
    ) void {
        std.debug.assert(container_id > 0);
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        // Stack-based traversal (no recursion)
        var stack: [MAX_VIEWS]struct {
            container_id: u32,
            x: i32,
            y: i32,
            width: u32,
            height: u32,
        } = undefined;
        var stack_len: u32 = 0;

        // Push root container
        stack[stack_len] = .{
            .container_id = container_id,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
        stack_len += 1;

        // Iterative traversal
        while (stack_len > 0) {
            stack_len -= 1;
            const current = stack[stack_len];
            const container = self.get_container(current.container_id) orelse continue;

            // Set container position/size
            container.x = current.x;
            container.y = current.y;
            container.width = current.width;
            container.height = current.height;

            // Calculate layout for children
            if (container.children_len == 0) {
                continue;
            }

            // Simple split layout (equal sizes)
            const child_width = if (container.container_type == .horizontal)
                current.width / container.children_len
            else
                current.width;
            const child_height = if (container.container_type == .vertical)
                current.height / container.children_len
            else
                current.height;

            var child_x = current.x;
            var child_y = current.y;
            var i: u32 = 0;
            while (i < container.children_len) : (i += 1) {
                const child_id = container.children[i];
                if (container.is_view) {
                    // Child is a view: set position/size
                    if (self.get_view(child_id)) |view| {
                        view.x = child_x;
                        view.y = child_y;
                        view.width = child_width;
                        view.height = child_height;
                    }
                } else {
                    // Child is a container: push to stack
                    if (stack_len < MAX_VIEWS) {
                        stack[stack_len] = .{
                            .container_id = child_id,
                            .x = child_x,
                            .y = child_y,
                            .width = child_width,
                            .height = child_height,
                        };
                        stack_len += 1;
                    }
                }

                // Update position for next child
                if (container.container_type == .horizontal) {
                    child_x += @as(i32, @intCast(child_width));
                } else if (container.container_type == .vertical) {
                    child_y += @as(i32, @intCast(child_height));
                }
            }
        }
    }
};

