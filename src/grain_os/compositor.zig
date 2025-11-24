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
        // Calculate layout with current output dimensions.
        self.tiling_tree.calculate_layout(
            0,
            0,
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
        // Recalculate layout.
        self.tiling_tree.calculate_layout(
            0,
            0,
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
        // Recalculate tiling layout for all windows.
        self.tiling_tree.calculate_layout(
            0,
            0,
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
    }
};

