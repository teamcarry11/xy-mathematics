//! Grain OS Compositor: Wayland compositor for desktop environment.
//!
//! Why: Manage windows, surfaces, and input for Grain OS desktop.
//! Architecture: Wayland protocol, kernel framebuffer rendering.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const wayland = @import("wayland/protocol.zig");
const basin_kernel = @import("basin_kernel");
const tiling = @import("tiling.zig");
const framebuffer_renderer = @import("framebuffer_renderer.zig");
const layout_generator = @import("layout_generator.zig");
const input_handler = @import("input_handler.zig");

// Bounded: Max number of windows.
pub const MAX_WINDOWS: u32 = 256;

// Bounded: Max window title length.
pub const MAX_TITLE_LEN: u32 = 256;

// Window state: represents a window in the compositor.
pub const Window = struct {
    id: u32,
    surface_id: wayland.ObjectId,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    title: [MAX_TITLE_LEN]u8,
    title_len: u32,
    visible: bool,
    focused: bool,

    pub fn init(
        id: u32,
        surface_id: wayland.ObjectId,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
    ) Window {
        std.debug.assert(id > 0);
        std.debug.assert(surface_id > 0);
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        var window = Window{
            .id = id,
            .surface_id = surface_id,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .title = undefined,
            .title_len = 0,
            .visible = true,
            .focused = false,
        };
        var j: u32 = 0;
        while (j < MAX_TITLE_LEN) : (j += 1) {
            window.title[j] = 0;
        }
        std.debug.assert(window.id > 0);
        return window;
    }

    pub fn set_title(self: *Window, title: []const u8) void {
        std.debug.assert(title.len <= MAX_TITLE_LEN);
        const copy_len = @min(title.len, MAX_TITLE_LEN);
        var i: u32 = 0;
        while (i < MAX_TITLE_LEN) : (i += 1) {
            self.title[i] = 0;
        }
        i = 0;
        while (i < copy_len) : (i += 1) {
            self.title[i] = title[i];
        }
        self.title_len = @intCast(copy_len);
        std.debug.assert(self.title_len <= MAX_TITLE_LEN);
    }
};

// Compositor: main compositor state.
pub const Compositor = struct {
    allocator: std.mem.Allocator,
    windows: [MAX_WINDOWS]Window,
    windows_len: u32,
    next_window_id: u32,
    next_object_id: wayland.ObjectId,
    registry: wayland.Registry,
    output: wayland.Output,
    seat: wayland.Seat,
    framebuffer_base: u64,
    tiling_tree: tiling.TilingTree,
    renderer: framebuffer_renderer.FramebufferRenderer,
    layout_registry: layout_generator.LayoutRegistry,
    input: input_handler.InputHandler,
    focused_window_id: u32,

    pub fn init(allocator: std.mem.Allocator) Compositor {
        std.debug.assert(@intFromPtr(allocator.ptr) != 0);
        var compositor = Compositor{
            .allocator = allocator,
            .windows = undefined,
            .windows_len = 0,
            .next_window_id = 1,
            .next_object_id = 1,
            .registry = wayland.Registry.init(1),
            .output = wayland.Output.init(2, 1024, 768, 1024, 768),
            .seat = wayland.Seat.init(3),
            .framebuffer_base = 0x90000000,
            .tiling_tree = tiling.TilingTree.init(),
            .renderer = framebuffer_renderer.FramebufferRenderer.init(),
            .layout_registry = layout_generator.LayoutRegistry.init(),
            .input = input_handler.InputHandler.init(),
            .focused_window_id = 0,
        };
        var i: u32 = 0;
        while (i < MAX_WINDOWS) : (i += 1) {
            compositor.windows[i] = Window.init(0, 0, 0, 0, 0, 0);
        }
        compositor.next_object_id = 4;
        std.debug.assert(compositor.windows_len == 0);
        std.debug.assert(compositor.next_window_id > 0);
        return compositor;
    }

    pub fn create_window(
        self: *Compositor,
        width: u32,
        height: u32,
    ) !u32 {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(self.windows_len < MAX_WINDOWS);
        const window_id = self.next_window_id;
        const surface_id = self.next_object_id;
        self.next_window_id += 1;
        self.next_object_id += 1;
        const window = Window.init(
            window_id,
            surface_id,
            0,
            0,
            width,
            height,
        );
        self.windows[self.windows_len] = window;
        self.windows_len += 1;
        // Add window to tiling tree.
        self.tiling_tree.add_window(window_id) catch {
            return error.OutOfMemory;
        };
        // Calculate layout with current layout generator.
        self.layout_registry.apply_layout(
            &self.tiling_tree,
            self.output.width,
            self.output.height,
        );
        // Update window position from tiling tree.
        if (self.tiling_tree.get_window_bounds(window_id)) |bounds| {
            if (self.get_window(window_id)) |win| {
                win.x = bounds.x;
                win.y = bounds.y;
                win.width = bounds.width;
                win.height = bounds.height;
            }
        }
        std.debug.assert(self.windows_len <= MAX_WINDOWS);
        std.debug.assert(window_id > 0);
        return window_id;
    }

    pub fn get_window(self: *Compositor, window_id: u32) ?*Window {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.windows_len) : (i += 1) {
            if (self.windows[i].id == window_id) {
                std.debug.assert(self.windows[i].id == window_id);
                return &self.windows[i];
            }
        }
        return null;
    }

    pub fn remove_window(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        // Find and remove window from array.
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.windows_len) : (i += 1) {
            if (self.windows[i].id == window_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Remove from tiling tree.
        _ = self.tiling_tree.remove_window(window_id);
        // Shift remaining windows left.
        while (i < self.windows_len - 1) : (i += 1) {
            self.windows[i] = self.windows[i + 1];
        }
        self.windows_len -= 1;
        // Recalculate layout with current layout generator.
        self.layout_registry.apply_layout(
            &self.tiling_tree,
            self.output.width,
            self.output.height,
        );
        // Update remaining window positions.
        var j: u32 = 0;
        while (j < self.windows_len) : (j += 1) {
            const win_id = self.windows[j].id;
            if (self.tiling_tree.get_window_bounds(win_id)) |bounds| {
                self.windows[j].x = bounds.x;
                self.windows[j].y = bounds.y;
                self.windows[j].width = bounds.width;
                self.windows[j].height = bounds.height;
            }
        }
        return true;
    }

    pub fn recalculate_layout(self: *Compositor) void {
        // Recalculate tiling layout with current layout generator.
        self.layout_registry.apply_layout(
            &self.tiling_tree,
            self.output.width,
            self.output.height,
        );
        // Update window positions.
        var i: u32 = 0;
        while (i < self.windows_len) : (i += 1) {
            const win_id = self.windows[i].id;
            if (self.tiling_tree.get_window_bounds(win_id)) |bounds| {
                self.windows[i].x = bounds.x;
                self.windows[i].y = bounds.y;
                self.windows[i].width = bounds.width;
                self.windows[i].height = bounds.height;
            }
        }
    }

    pub fn set_layout(self: *Compositor, layout_type: layout_generator.LayoutType) bool {
        std.debug.assert(@intFromEnum(layout_type) < 4);
        const success = self.layout_registry.set_current_layout(layout_type);
        if (success) {
            self.layout_registry.apply_layout(
                &self.tiling_tree,
                self.output.width,
                self.output.height,
            );
            // Update window positions from tiling tree.
            var i: u32 = 0;
            while (i < self.windows_len) : (i += 1) {
                const win_id = self.windows[i].id;
                if (self.tiling_tree.get_window_bounds(win_id)) |bounds| {
                    self.windows[i].x = bounds.x;
                    self.windows[i].y = bounds.y;
                    self.windows[i].width = bounds.width;
                    self.windows[i].height = bounds.height;
                }
            }
        }
        return success;
    }

    pub fn get_current_layout(self: *const Compositor) layout_generator.LayoutType {
        return self.layout_registry.current_layout;
    }

    pub fn render_to_framebuffer(self: *Compositor) void {
        std.debug.assert(self.framebuffer_base > 0);
        // Clear framebuffer to background color.
        self.renderer.clear(framebuffer_renderer.COLOR_DARK_BG);
        // Render each visible window.
        var i: u32 = 0;
        while (i < self.windows_len) : (i += 1) {
            const win = &self.windows[i];
            if (win.visible) {
                // Draw window background (simple rectangle for now).
                self.renderer.draw_rect(
                    win.x,
                    win.y,
                    win.width,
                    win.height,
                    framebuffer_renderer.COLOR_WHITE,
                );
            }
        }
    }

    pub fn set_syscall_fn(
        self: *Compositor,
        fn_ptr: *const fn (u32, u64, u64, u64, u64) i64,
    ) void {
        self.renderer.set_syscall_fn(fn_ptr);
        self.input.set_syscall_fn(fn_ptr);
    }

    // Find window at mouse position (hit testing).
    pub fn find_window_at(self: *const Compositor, x: u32, y: u32) ?u32 {
        std.debug.assert(x < self.output.width);
        std.debug.assert(y < self.output.height);
        // Check windows in reverse order (top to bottom).
        var i: u32 = self.windows_len;
        while (i > 0) {
            i -= 1;
            const win = &self.windows[i];
            if (win.visible) {
                const win_x = @as(u32, @intCast(win.x));
                const win_y = @as(u32, @intCast(win.y));
                if (x >= win_x and x < win_x + win.width and
                    y >= win_y and y < win_y + win.height)
                {
                    return win.id;
                }
            }
        }
        return null;
    }

    // Focus window by ID.
    pub fn focus_window(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        // Unfocus current window.
        if (self.focused_window_id > 0) {
            if (self.get_window(self.focused_window_id)) |win| {
                win.focused = false;
            }
        }
        // Focus new window.
        if (self.get_window(window_id)) |win| {
            win.focused = true;
            self.focused_window_id = window_id;
            return true;
        }
        return false;
    }

    // Unfocus all windows.
    pub fn unfocus_all(self: *Compositor) void {
        if (self.focused_window_id > 0) {
            if (self.get_window(self.focused_window_id)) |win| {
                win.focused = false;
            }
            self.focused_window_id = 0;
        }
    }

    // Process input events and route to windows.
    pub fn process_input(self: *Compositor) !void {
        const event_opt = try self.input.read_event();
        if (event_opt) |event| {
            if (event.event_type == .mouse) {
                // Handle mouse events.
                if (event.mouse.kind == .down) {
                    // Mouse click: focus window at click position.
                    const window_id_opt = self.find_window_at(
                        event.mouse.x,
                        event.mouse.y,
                    );
                    if (window_id_opt) |window_id| {
                        _ = self.focus_window(window_id);
                    } else {
                        self.unfocus_all();
                    }
                }
            } else if (event.event_type == .keyboard) {
                // Handle keyboard events (route to focused window).
                if (self.focused_window_id > 0) {
                    // TODO: Route keyboard event to focused window.
                    _ = event.keyboard;
                }
            }
        }
    }

    // Get focused window ID.
    pub fn get_focused_window_id(self: *const Compositor) u32 {
        return self.focused_window_id;
    }
};

