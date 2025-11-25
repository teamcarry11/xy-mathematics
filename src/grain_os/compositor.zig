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
const workspace = @import("workspace.zig");
const keyboard_shortcuts = @import("keyboard_shortcuts.zig");
const runtime_config = @import("runtime_config.zig");
const desktop_shell = @import("desktop_shell.zig");
const application = @import("application.zig");

// Bounded: Max number of windows.
pub const MAX_WINDOWS: u32 = 256;

// Bounded: Max window title length.
pub const MAX_TITLE_LEN: u32 = 256;

// Bounded: Title bar height.
pub const TITLE_BAR_HEIGHT: u32 = 24;

// Bounded: Window border width.
pub const BORDER_WIDTH: u32 = 2;

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
    minimized: bool,
    maximized: bool,

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
            .minimized = false,
            .maximized = false,
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
    workspace_manager: workspace.WorkspaceManager,
    input: input_handler.InputHandler,
    focused_window_id: u32,
    shortcut_registry: keyboard_shortcuts.ShortcutRegistry,
    config_manager: ?runtime_config.RuntimeConfig,
    shell: desktop_shell.DesktopShell,
    app_registry: application.ApplicationRegistry,
    app_launcher: application.ApplicationLauncher,

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
            .workspace_manager = workspace.WorkspaceManager.init(),
            .input = input_handler.InputHandler.init(),
            .focused_window_id = 0,
            .shortcut_registry = keyboard_shortcuts.ShortcutRegistry.init(),
            .config_manager = null,
            .shell = desktop_shell.DesktopShell.init(
                &compositor.renderer,
                compositor.output.width,
                compositor.output.height,
            ),
            .app_registry = application.ApplicationRegistry.init(),
            .app_launcher = undefined,
        };
        var i: u32 = 0;
        while (i < MAX_WINDOWS) : (i += 1) {
            compositor.windows[i] = Window.init(0, 0, 0, 0, 0, 0);
        }
        compositor.next_object_id = 4;
        compositor.app_launcher = application.ApplicationLauncher.init(
            &compositor.app_registry,
        );
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
        // Assign window to current workspace.
        if (self.workspace_manager.get_current_workspace()) |current_ws| {
            _ = self.workspace_manager.assign_window_to_workspace(
                window_id,
                current_ws.id,
            );
        }
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
        // Remove from workspace.
        if (self.workspace_manager.get_current_workspace()) |ws| {
            _ = ws.remove_window(window_id);
        }
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

    pub fn switch_workspace(self: *Compositor, workspace_id: u32) bool {
        std.debug.assert(workspace_id > 0);
        return self.workspace_manager.switch_workspace(workspace_id);
    }

    pub fn get_current_workspace_id(self: *const Compositor) u32 {
        return self.workspace_manager.current_workspace_id;
    }

    pub fn create_workspace(self: *Compositor, name: []const u8) ?u32 {
        std.debug.assert(name.len <= 32);
        return self.workspace_manager.create_workspace(name);
    }

    pub fn assign_window_to_workspace(
        self: *Compositor,
        window_id: u32,
        workspace_id: u32,
    ) bool {
        std.debug.assert(window_id > 0);
        std.debug.assert(workspace_id > 0);
        const assigned = self.workspace_manager.assign_window_to_workspace(
            window_id,
            workspace_id,
        );
        if (assigned) {
            // Update window visibility.
            if (self.get_window(window_id)) |win| {
                const is_current = (workspace_id == self.workspace_manager.current_workspace_id);
                win.visible = is_current;
            }
            // Recalculate layout.
            self.recalculate_layout();
        }
        return assigned;
    }

    pub fn render_to_framebuffer(self: *Compositor) void {
        std.debug.assert(self.framebuffer_base > 0);
        // Clear framebuffer to background color.
        self.renderer.clear(framebuffer_renderer.COLOR_DARK_BG);
        // Render each visible, non-minimized window.
        var i: u32 = 0;
        while (i < self.windows_len) : (i += 1) {
            const win = &self.windows[i];
            if (win.visible and !win.minimized) {
                self.render_window_decorations(win);
            }
        }
        // Render desktop shell (status bar and launcher).
        self.shell.set_current_workspace(self.workspace_manager.current_workspace_id);
        self.shell.render();
    }

    // Render window decorations (border, title bar, content area).
    fn render_window_decorations(self: *Compositor, win: *Window) void {
        std.debug.assert(win.width > 0);
        std.debug.assert(win.height > 0);
        // Draw window border.
        const border_color = if (win.focused)
            framebuffer_renderer.COLOR_BLUE
        else
            framebuffer_renderer.COLOR_WHITE;
        // Top border.
        self.renderer.draw_rect(
            win.x,
            win.y,
            win.width,
            BORDER_WIDTH,
            border_color,
        );
        // Bottom border.
        self.renderer.draw_rect(
            win.x,
            @as(i32, @intCast(win.y)) + @as(i32, @intCast(win.height)) - @as(i32, @intCast(BORDER_WIDTH)),
            win.width,
            BORDER_WIDTH,
            border_color,
        );
        // Left border.
        self.renderer.draw_rect(
            win.x,
            win.y,
            BORDER_WIDTH,
            win.height,
            border_color,
        );
        // Right border.
        self.renderer.draw_rect(
            @as(i32, @intCast(win.x)) + @as(i32, @intCast(win.width)) - @as(i32, @intCast(BORDER_WIDTH)),
            win.y,
            BORDER_WIDTH,
            win.height,
            border_color,
        );
        // Draw title bar.
        const title_bar_color = if (win.focused)
            framebuffer_renderer.COLOR_BLUE
        else
            framebuffer_renderer.COLOR_DARK_BG;
        self.renderer.draw_rect(
            @as(i32, @intCast(win.x)) + @as(i32, @intCast(BORDER_WIDTH)),
            @as(i32, @intCast(win.y)) + @as(i32, @intCast(BORDER_WIDTH)),
            win.width - (BORDER_WIDTH * 2),
            TITLE_BAR_HEIGHT,
            title_bar_color,
        );
        // Draw window content area (background).
        const content_y = @as(i32, @intCast(win.y)) + @as(i32, @intCast(BORDER_WIDTH + TITLE_BAR_HEIGHT));
        const content_height = win.height - (BORDER_WIDTH * 2) - TITLE_BAR_HEIGHT;
        self.renderer.draw_rect(
            @as(i32, @intCast(win.x)) + @as(i32, @intCast(BORDER_WIDTH)),
            content_y,
            win.width - (BORDER_WIDTH * 2),
            content_height,
            framebuffer_renderer.COLOR_WHITE,
        );
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
            if (win.visible and !win.minimized) {
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
                    // Check for close button click.
                    const window_id_opt = self.find_window_at(
                        event.mouse.x,
                        event.mouse.y,
                    );
                    if (window_id_opt) |window_id| {
                        if (self.is_in_close_button(window_id, event.mouse.x, event.mouse.y)) {
                            _ = self.remove_window(window_id);
                        } else {
                            _ = self.focus_window(window_id);
                        }
                    } else {
                        self.unfocus_all();
                    }
                }
            } else if (event.event_type == .keyboard) {
                // Handle keyboard shortcuts for window management.
                if (event.keyboard.kind == .down) {
                    const action_opt = self.shortcut_registry.find_shortcut(
                        event.keyboard.modifiers,
                        event.keyboard.key_code,
                    );
                    if (action_opt) |action| {
                        if (self.focused_window_id > 0) {
                            _ = action(self, self.focused_window_id);
                        }
                    } else if (self.focused_window_id > 0) {
                        // Route keyboard event to focused window if no shortcut matched.
                        _ = event.keyboard;
                    }
                }
            }
        }
    }

    // Minimize window.
    pub fn minimize_window(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            win.minimized = true;
            win.visible = false;
            return true;
        }
        return false;
    }

    // Restore window (unminimize).
    pub fn restore_window(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            win.minimized = false;
            win.visible = true;
            return true;
        }
        return false;
    }

    // Maximize window.
    pub fn maximize_window(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            win.maximized = true;
            win.x = 0;
            win.y = @as(i32, @intCast(BORDER_WIDTH + TITLE_BAR_HEIGHT));
            win.width = self.output.width;
            win.height = self.output.height - (BORDER_WIDTH * 2) - TITLE_BAR_HEIGHT;
            self.recalculate_layout();
            return true;
        }
        return false;
    }

    // Unmaximize window.
    pub fn unmaximize_window(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            win.maximized = false;
            // Restore from tiling tree.
            if (self.tiling_tree.get_window_bounds(window_id)) |bounds| {
                win.x = bounds.x;
                win.y = bounds.y;
                win.width = bounds.width;
                win.height = bounds.height;
            }
            self.recalculate_layout();
            return true;
        }
        return false;
    }

    // Get focused window ID.
    pub fn get_focused_window_id(self: *const Compositor) u32 {
        return self.focused_window_id;
    }

    // Initialize runtime configuration manager.
    pub fn init_runtime_config(self: *Compositor, channel_id: u32) void {
        std.debug.assert(channel_id > 0);
        self.config_manager = runtime_config.RuntimeConfig.init(self, channel_id);
    }

    // Process configuration command.
    pub fn process_config_command(self: *Compositor, cmd_str: []const u8) bool {
        std.debug.assert(cmd_str.len > 0);
        if (self.config_manager) |*config| {
            return config.process_command(cmd_str);
        }
        return false;
    }
};

