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
const window_snapping = @import("window_snapping.zig");
const window_switching = @import("window_switching.zig");
const window_state = @import("window_state.zig");
const window_preview = @import("window_preview.zig");
const window_visual = @import("window_visual.zig");
const window_stacking = @import("window_stacking.zig");
const window_opacity = @import("window_opacity.zig");
const window_animation = @import("window_animation.zig");
const window_decorations = @import("window_decorations.zig");
const window_constraints = @import("window_constraints.zig");
const window_grouping = @import("window_grouping.zig");
const window_focus = @import("window_focus.zig");
const window_effects = @import("window_effects.zig");
const window_drag_drop = @import("window_drag_drop.zig");
const keyboard_shortcuts = @import("keyboard_shortcuts.zig");

// Bounded: Max number of windows.
pub const MAX_WINDOWS: u32 = 256;

// Bounded: Max window title length.
pub const MAX_TITLE_LEN: u32 = 256;

// Bounded: Title bar height.
pub const TITLE_BAR_HEIGHT: u32 = 24;

// Bounded: Window border width.
pub const BORDER_WIDTH: u32 = 2;

// Bounded: Resize handle size.
pub const RESIZE_HANDLE_SIZE: u32 = 8;

// Window drag state.
pub const DragState = struct {
    active: bool,
    start_x: i32,
    start_y: i32,
    window_start_x: i32,
    window_start_y: i32,
};

// Window resize state.
pub const ResizeState = struct {
    active: bool,
    handle: ResizeHandle,
    start_x: i32,
    start_y: i32,
    window_start_width: u32,
    window_start_height: u32,
    window_start_x: i32,
    window_start_y: i32,
};

// Resize handle type.
pub const ResizeHandle = enum(u8) {
    none,
    top_left,
    top,
    top_right,
    right,
    bottom_right,
    bottom,
    bottom_left,
    left,
};

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
    opacity: u8, // Window opacity (0 = transparent, 255 = opaque).
    constraints: window_constraints.WindowConstraints,
    drag_state: DragState,
    resize_state: ResizeState,

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
            .opacity = window_opacity.OPACITY_DEFAULT,
            .constraints = window_constraints.WindowConstraints.init(),
            .drag_state = DragState{
                .active = false,
                .start_x = 0,
                .start_y = 0,
                .window_start_x = 0,
                .window_start_y = 0,
            },
            .resize_state = ResizeState{
                .active = false,
                .handle = ResizeHandle.none,
                .start_x = 0,
                .start_y = 0,
                .window_start_width = 0,
                .window_start_height = 0,
                .window_start_x = 0,
                .window_start_y = 0,
            },
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
    switch_order: window_switching.WindowSwitchOrder,
    state_manager: window_state.WindowStateManager,
    preview_manager: window_preview.PreviewManager,
    window_stack: window_stacking.WindowStack,
    animation_manager: window_animation.AnimationManager,
    group_manager: window_grouping.WindowGroupManager,
    focus_manager: window_focus.FocusManager,
    drop_zone_manager: window_drag_drop.DropZoneManager,

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
            .switch_order = window_switching.WindowSwitchOrder.init(),
            .state_manager = window_state.WindowStateManager.init(),
            .preview_manager = window_preview.PreviewManager.init(),
            .window_stack = window_stacking.WindowStack.init(),
            .animation_manager = window_animation.AnimationManager.init(),
            .group_manager = window_grouping.WindowGroupManager.init(),
            .focus_manager = window_focus.FocusManager.init(),
            .drop_zone_manager = window_drag_drop.DropZoneManager.init(),
        };
        var i: u32 = 0;
        while (i < MAX_WINDOWS) : (i += 1) {
            compositor.windows[i] = Window.init(0, 0, 0, 0, 0, 0);
        }
        compositor.next_object_id = 4;
        compositor.app_launcher = application.ApplicationLauncher.init(
            &compositor.app_registry,
        );
        compositor.shell.set_app_registry(&compositor.app_registry);
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
        // Add window to switch order.
        _ = self.switch_order.add_window(window_id);
        // Add window to stacking order (at top).
        _ = self.window_stack.add_window(window_id);
        // Start fade-in effect for new window.
        _ = window_effects.start_fade_in(&self.animation_manager, window_id, 0);
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
        // Remove from switch order.
        _ = self.switch_order.remove_window(window_id);
        // Remove from stacking order.
        _ = self.window_stack.remove_window(window_id);
        // Remove from state manager.
        _ = self.state_manager.remove_window(window_id);
        // Remove from preview manager.
        _ = self.preview_manager.remove_preview(window_id);
        // Remove from all groups.
        self.group_manager.remove_window_from_all_groups(window_id);
        // Start fade-out effect before removal (would wait for completion in full impl).
        if (self.get_window(window_id)) |win| {
            _ = window_effects.start_fade_out(&self.animation_manager, window_id, win.opacity, 0);
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
        // Update animations (simplified: use fixed timestamp).
        self.update_animations(0); // Would use actual timestamp in full impl.
        // Clear framebuffer to background color.
        self.renderer.clear(framebuffer_renderer.COLOR_DARK_BG);
        // Render windows in stacking order (bottom to top).
        var stack_i: u32 = 0;
        while (stack_i < self.window_stack.window_ids_len) : (stack_i += 1) {
            if (self.window_stack.get_window_at(stack_i)) |window_id| {
                if (self.get_window(window_id)) |win| {
                    if (win.visible and !win.minimized) {
                        self.render_window_decorations(win);
                    }
                }
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
        // Render shadow if enabled.
        if (window_visual.should_render_shadow(win.minimized)) {
            self.render_window_shadow(win);
        }
        // Render focus glow if focused.
        if (window_visual.should_render_focus_glow(win.focused)) {
            self.render_focus_glow(win);
        }
        // Draw window border (apply opacity).
        const base_border_color = if (win.focused)
            framebuffer_renderer.COLOR_BLUE
        else
            framebuffer_renderer.COLOR_WHITE;
        const border_color = window_opacity.apply_opacity_to_color(
            base_border_color,
            win.opacity,
        );
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
        // Draw title bar (apply opacity).
        const base_title_bar_color = if (win.focused)
            framebuffer_renderer.COLOR_BLUE
        else
            framebuffer_renderer.COLOR_DARK_BG;
        const title_bar_color = window_opacity.apply_opacity_to_color(
            base_title_bar_color,
            win.opacity,
        );
        self.renderer.draw_rect(
            @as(i32, @intCast(win.x)) + @as(i32, @intCast(BORDER_WIDTH)),
            @as(i32, @intCast(win.y)) + @as(i32, @intCast(BORDER_WIDTH)),
            win.width - (BORDER_WIDTH * 2),
            TITLE_BAR_HEIGHT,
            title_bar_color,
        );
        // Draw title bar buttons.
        self.render_title_bar_buttons(win);
        // Draw window content area (background, apply opacity).
        const content_y = @as(i32, @intCast(win.y)) + @as(i32, @intCast(BORDER_WIDTH + TITLE_BAR_HEIGHT));
        const content_height = win.height - (BORDER_WIDTH * 2) - TITLE_BAR_HEIGHT;
        const content_color = window_opacity.apply_opacity_to_color(
            framebuffer_renderer.COLOR_WHITE,
            win.opacity,
        );
        self.renderer.draw_rect(
            @as(i32, @intCast(win.x)) + @as(i32, @intCast(BORDER_WIDTH)),
            content_y,
            win.width - (BORDER_WIDTH * 2),
            content_height,
            content_color,
        );
    }

    // Render window shadow.
    fn render_window_shadow(self: *Compositor, win: *Window) void {
        std.debug.assert(win.width > 0);
        std.debug.assert(win.height > 0);
        const shadow_x = win.x + window_visual.SHADOW_OFFSET_X;
        const shadow_y = win.y + window_visual.SHADOW_OFFSET_Y;
        const shadow_color = window_visual.calc_shadow_color(
            framebuffer_renderer.COLOR_BLACK,
            window_visual.SHADOW_ALPHA,
        );
        // Draw shadow rectangle (simplified: solid shadow).
        self.renderer.draw_rect(
            shadow_x,
            shadow_y,
            win.width,
            win.height,
            shadow_color,
        );
    }

    // Render focus glow around window.
    fn render_focus_glow(self: *Compositor, win: *Window) void {
        std.debug.assert(win.width > 0);
        std.debug.assert(win.height > 0);
        const glow_size = window_visual.FOCUS_GLOW_SIZE;
        const glow_color = window_visual.calc_focus_glow_color(
            framebuffer_renderer.COLOR_BLUE,
        );
        // Draw glow rectangles around window border.
        // Top glow.
        self.renderer.draw_rect(
            win.x - @as(i32, @intCast(glow_size)),
            win.y - @as(i32, @intCast(glow_size)),
            win.width + (glow_size * 2),
            glow_size,
            glow_color,
        );
        // Bottom glow.
        self.renderer.draw_rect(
            win.x - @as(i32, @intCast(glow_size)),
            @as(i32, @intCast(win.y)) + @as(i32, @intCast(win.height)),
            win.width + (glow_size * 2),
            glow_size,
            glow_color,
        );
        // Left glow.
        self.renderer.draw_rect(
            win.x - @as(i32, @intCast(glow_size)),
            win.y,
            glow_size,
            win.height,
            glow_color,
        );
        // Right glow.
        self.renderer.draw_rect(
            @as(i32, @intCast(win.x)) + @as(i32, @intCast(win.width)),
            win.y,
            glow_size,
            win.height,
            glow_color,
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
            // Add to focus history.
            self.focus_manager.add_focus_history(window_id, 0); // Would use actual timestamp.
            // Move to front of switch order.
            self.switch_order.move_to_front(window_id);
            // Raise to top of stacking order.
            _ = self.window_stack.raise_to_top(window_id);
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
                    // Check for launcher item click first.
                    if (self.shell.launcher_visible) {
                        if (self.shell.get_launcher_item_at(
                            event.mouse.x,
                            event.mouse.y,
                        )) |item_index| {
                            if (item_index < self.shell.launcher_items_len) {
                                const item = &self.shell.launcher_items[item_index];
                                const cmd_slice = item.command[0..item.command_len];
                                _ = self.launch_application(cmd_slice);
                            }
                            return;
                        }
                    }
                    // Check for window resize handle.
                    const window_id_opt = self.find_window_at(
                        event.mouse.x,
                        event.mouse.y,
                    );
                    if (window_id_opt) |window_id| {
                        if (self.get_resize_handle(window_id, event.mouse.x, event.mouse.y)) |handle| {
                            if (handle != ResizeHandle.none) {
                                self.start_resize(window_id, handle, event.mouse.x, event.mouse.y);
                            } else {
                                const button_type = window_decorations.get_button_at(
                                    win.x,
                                    win.y,
                                    win.width,
                                    event.mouse.x,
                                    event.mouse.y,
                                );
                                if (button_type == window_decorations.ButtonType.close) {
                                    _ = self.remove_window(window_id);
                                } else if (button_type == window_decorations.ButtonType.minimize) {
                                    _ = self.minimize_window(window_id);
                                } else if (button_type == window_decorations.ButtonType.maximize) {
                                    if (win.maximized) {
                                        _ = self.unmaximize_window(window_id);
                                    } else {
                                        _ = self.maximize_window(window_id);
                                    }
                                } else if (self.is_in_title_bar(window_id, event.mouse.x, event.mouse.y)) {
                                    self.start_drag(window_id, event.mouse.x, event.mouse.y);
                                } else {
                                _ = self.focus_window(window_id);
                            }
                        } else {
                            self.unfocus_all();
                        }
                    } else {
                        self.unfocus_all();
                    }
                } else if (event.mouse.kind == .move) {
                    // Handle mouse move (dragging/resizing, focus-follows-mouse).
                    self.handle_mouse_move(event.mouse.x, event.mouse.y);
                    // Focus-follows-mouse: focus window under cursor.
                    if (self.focus_manager.should_focus_on_mouse_move()) {
                        if (self.find_window_at(event.mouse.x, event.mouse.y)) |window_id| {
                            if (window_id != self.focused_window_id) {
                                _ = self.focus_window(window_id);
                            }
                        } else if (self.focus_manager.should_unfocus_on_mouse_leave()) {
                            self.unfocus_all();
                        }
                    }
                } else if (event.mouse.kind == .up) {
                    // Handle mouse release (end drag/resize).
                    self.end_drag();
                    self.end_resize();
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

    // Toggle launcher visibility.
    pub fn toggle_launcher(self: *Compositor) void {
        self.shell.toggle_launcher();
    }

    // Register application.
    pub fn register_application(
        self: *Compositor,
        name: []const u8,
        path: []const u8,
        command: []const u8,
    ) ?u32 {
        const app_id = self.app_registry.register_application(name, path, command);
        // Sync launcher items after registration.
        self.shell.sync_launcher_items();
        return app_id;
    }

    // Launch application by name.
    pub fn launch_application(self: *Compositor, name: []const u8) bool {
        return self.app_launcher.launch_application_by_name(name);
    }

    // Switch to next window (forward cycle).
    pub fn switch_to_next_window(self: *Compositor) bool {
        if (self.switch_order.get_next()) |window_id| {
            return self.focus_window(window_id);
        }
        return false;
    }

    // Switch to previous window (backward cycle).
    pub fn switch_to_previous_window(self: *Compositor) bool {
        if (self.switch_order.get_previous()) |window_id| {
            return self.focus_window(window_id);
        }
        return false;
    }

    // Save window state.
    pub fn save_window_state(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            const workspace_id = if (self.workspace_manager.get_window_workspace(window_id)) |ws_id|
                ws_id
            else
                self.workspace_manager.current_workspace_id;
            const title_slice = win.title[0..win.title_len];
            return self.state_manager.save_window(
                window_id,
                win.x,
                win.y,
                win.width,
                win.height,
                win.minimized,
                win.maximized,
                workspace_id,
                title_slice,
            );
        }
        return false;
    }

    // Restore window state.
    pub fn restore_window_state(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.state_manager.get_window_state(window_id)) |state| {
            if (self.get_window(window_id)) |win| {
                win.x = state.x;
                win.y = state.y;
                win.width = state.width;
                win.height = state.height;
                win.minimized = state.minimized;
                win.maximized = state.maximized;
                win.visible = !state.minimized;
                // Restore title.
                var i: u32 = 0;
                while (i < compositor.MAX_TITLE_LEN) : (i += 1) {
                    win.title[i] = 0;
                }
                i = 0;
                while (i < state.title_len) : (i += 1) {
                    win.title[i] = state.title[i];
                }
                win.title_len = state.title_len;
                // Assign to workspace.
                _ = self.workspace_manager.assign_window_to_workspace(
                    window_id,
                    state.workspace_id,
                );
                self.recalculate_layout();
                return true;
            }
        }
        return false;
    }

    // Save all window states.
    pub fn save_all_window_states(self: *Compositor) void {
        var i: u32 = 0;
        while (i < self.windows_len) : (i += 1) {
            _ = self.save_window_state(self.windows[i].id);
        }
    }

    // Generate preview for window.
    pub fn generate_window_preview(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            return self.preview_manager.generate_preview(
                window_id,
                win.x,
                win.y,
                win.width,
                win.height,
                self.output.width,
                self.output.height,
            );
        }
        return false;
    }

    // Get window preview.
    pub fn get_window_preview(
        self: *Compositor,
        window_id: u32,
    ) ?*window_preview.WindowPreview {
        std.debug.assert(window_id > 0);
        return self.preview_manager.get_preview(window_id);
    }

    // Generate previews for all visible windows.
    pub fn generate_all_previews(self: *Compositor) void {
        var i: u32 = 0;
        while (i < self.windows_len) : (i += 1) {
            const win = &self.windows[i];
            if (win.visible and !win.minimized) {
                _ = self.generate_window_preview(win.id);
            }
        }
    }

    // Raise window to top of stacking order.
    pub fn raise_window(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        return self.window_stack.raise_to_top(window_id);
    }

    // Lower window to bottom of stacking order.
    pub fn lower_window(self: *Compositor, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        return self.window_stack.lower_to_bottom(window_id);
    }

    // Set window opacity.
    pub fn set_window_opacity(self: *Compositor, window_id: u32, opacity: u8) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            win.opacity = window_opacity.clamp_opacity(opacity);
            return true;
        }
        return false;
    }

    // Get window opacity.
    pub fn get_window_opacity(self: *const Compositor, window_id: u32) ?u8 {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            return win.opacity;
        }
        return null;
    }

    // Update all active animations.
    pub fn update_animations(self: *Compositor, current_time: u64) void {
        var i: u32 = 0;
        while (i < self.animation_manager.animations_len) : (i += 1) {
            const anim = &self.animation_manager.animations[i];
            if (anim.active) {
                if (self.animation_manager.update_animation(
                    anim.window_id,
                    current_time,
                )) |values| {
                    if (self.get_window(anim.window_id)) |win| {
                        win.x = values.x;
                        win.y = values.y;
                        win.width = values.width;
                        win.height = values.height;
                        win.opacity = values.opacity;
                    }
                }
            }
        }
    }

    // Start move animation for window.
    pub fn animate_move(
        self: *Compositor,
        window_id: u32,
        target_x: i32,
        target_y: i32,
        start_time: u64,
    ) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            return self.animation_manager.start_animation(
                window_id,
                window_animation.AnimationType.move,
                win.x,
                win.y,
                win.width,
                win.height,
                win.opacity,
                target_x,
                target_y,
                win.width,
                win.height,
                win.opacity,
                start_time,
            );
        }
        return false;
    }

    // Start resize animation for window.
    pub fn animate_resize(
        self: *Compositor,
        window_id: u32,
        target_width: u32,
        target_height: u32,
        start_time: u64,
    ) bool {
        std.debug.assert(window_id > 0);
        std.debug.assert(target_width > 0);
        std.debug.assert(target_height > 0);
        if (self.get_window(window_id)) |win| {
            return self.animation_manager.start_animation(
                window_id,
                window_animation.AnimationType.resize,
                win.x,
                win.y,
                win.width,
                win.height,
                win.opacity,
                win.x,
                win.y,
                target_width,
                target_height,
                win.opacity,
                start_time,
            );
        }
        return false;
    }

    // Check if point is in title bar.
    pub fn is_in_title_bar(
        self: *Compositor,
        window_id: u32,
        x: u32,
        y: u32,
    ) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            const title_bar_x = win.x + @as(i32, @intCast(BORDER_WIDTH));
            const title_bar_y = win.y + @as(i32, @intCast(BORDER_WIDTH));
            const title_bar_width = win.width - (BORDER_WIDTH * 2);
            const x_i32 = @as(i32, @intCast(x));
            const y_i32 = @as(i32, @intCast(y));
            return (x_i32 >= title_bar_x and x_i32 < title_bar_x + @as(i32, @intCast(title_bar_width)) and
                y_i32 >= title_bar_y and y_i32 < title_bar_y + @as(i32, @intCast(TITLE_BAR_HEIGHT)));
        }
        return false;
    }

    // Render title bar buttons.
    fn render_title_bar_buttons(self: *Compositor, win: *Window) void {
        std.debug.assert(win.width > 0);
        // Render close button.
        const close_bounds = window_decorations.get_close_button_bounds(
            win.x,
            win.y,
            win.width,
        );
        const close_color = window_decorations.get_button_color(
            window_decorations.ButtonType.close,
            false, // hovered (would track in full impl)
            false, // pressed (would track in full impl)
            win.focused,
        );
        const close_color_opacity = window_opacity.apply_opacity_to_color(
            close_color,
            win.opacity,
        );
        self.renderer.draw_rect(
            close_bounds.x,
            close_bounds.y,
            close_bounds.width,
            close_bounds.height,
            close_color_opacity,
        );
        // Render minimize button.
        const minimize_bounds = window_decorations.get_minimize_button_bounds(
            win.x,
            win.y,
            win.width,
        );
        const minimize_color = window_decorations.get_button_color(
            window_decorations.ButtonType.minimize,
            false,
            false,
            win.focused,
        );
        const minimize_color_opacity = window_opacity.apply_opacity_to_color(
            minimize_color,
            win.opacity,
        );
        self.renderer.draw_rect(
            minimize_bounds.x,
            minimize_bounds.y,
            minimize_bounds.width,
            minimize_bounds.height,
            minimize_color_opacity,
        );
        // Render maximize button.
        const maximize_bounds = window_decorations.get_maximize_button_bounds(
            win.x,
            win.y,
            win.width,
        );
        const maximize_color = window_decorations.get_button_color(
            window_decorations.ButtonType.maximize,
            false,
            false,
            win.focused,
        );
        const maximize_color_opacity = window_opacity.apply_opacity_to_color(
            maximize_color,
            win.opacity,
        );
        self.renderer.draw_rect(
            maximize_bounds.x,
            maximize_bounds.y,
            maximize_bounds.width,
            maximize_bounds.height,
            maximize_color_opacity,
        );
    }

    // Set window constraints.
    pub fn set_window_constraints(
        self: *Compositor,
        window_id: u32,
        min_width: u32,
        min_height: u32,
        max_width: u32,
        max_height: u32,
        aspect_ratio: f32,
    ) bool {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            win.constraints.set_min_size(min_width, min_height);
            win.constraints.set_max_size(max_width, max_height);
            win.constraints.set_aspect_ratio(aspect_ratio);
            return true;
        }
        return false;
    }

    // Get window constraints.
    pub fn get_window_constraints(
        self: *const Compositor,
        window_id: u32,
    ) ?window_constraints.WindowConstraints {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            return win.constraints;
        }
        return null;
    }

    // Create window group.
    pub fn create_window_group(self: *Compositor) ?u32 {
        return self.group_manager.create_group();
    }

    // Add window to group.
    pub fn add_window_to_group(
        self: *Compositor,
        window_id: u32,
        group_id: u32,
    ) bool {
        std.debug.assert(window_id > 0);
        std.debug.assert(group_id > 0);
        return self.group_manager.add_window_to_group(window_id, group_id);
    }

    // Remove window from group.
    pub fn remove_window_from_group(
        self: *Compositor,
        window_id: u32,
        group_id: u32,
    ) bool {
        std.debug.assert(window_id > 0);
        std.debug.assert(group_id > 0);
        return self.group_manager.remove_window_from_group(window_id, group_id);
    }

    // Find group for window.
    pub fn find_window_group(self: *Compositor, window_id: u32) ?u32 {
        std.debug.assert(window_id > 0);
        return self.group_manager.find_group_for_window(window_id);
    }

    // Delete window group.
    pub fn delete_window_group(self: *Compositor, group_id: u32) bool {
        std.debug.assert(group_id > 0);
        return self.group_manager.delete_group(group_id);
    }

    // Set focus policy.
    pub fn set_focus_policy(self: *Compositor, policy: window_focus.FocusPolicy) void {
        self.focus_manager.set_policy(policy);
    }

    // Get focus policy.
    pub fn get_focus_policy(self: *const Compositor) window_focus.FocusPolicy {
        return self.focus_manager.get_policy();
    }

    // Get previous focused window.
    pub fn get_previous_focused_window(self: *Compositor) ?u32 {
        return self.focus_manager.get_previous_focus();
    }

    // Get resize handle at mouse position.
    pub fn get_resize_handle(
        self: *Compositor,
        window_id: u32,
        x: u32,
        y: u32,
    ) ?ResizeHandle {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            if (win.maximized) return ResizeHandle.none;
            const win_x = @as(u32, @intCast(win.x));
            const win_y = @as(u32, @intCast(win.y));
            const handle_size = RESIZE_HANDLE_SIZE;
            // Check corners first.
            if (x >= win_x and x < win_x + handle_size and
                y >= win_y and y < win_y + handle_size)
            {
                return ResizeHandle.top_left;
            }
            if (x >= win_x + win.width - handle_size and x < win_x + win.width and
                y >= win_y and y < win_y + handle_size)
            {
                return ResizeHandle.top_right;
            }
            if (x >= win_x and x < win_x + handle_size and
                y >= win_y + win.height - handle_size and y < win_y + win.height)
            {
                return ResizeHandle.bottom_left;
            }
            if (x >= win_x + win.width - handle_size and x < win_x + win.width and
                y >= win_y + win.height - handle_size and y < win_y + win.height)
            {
                return ResizeHandle.bottom_right;
            }
            // Check edges.
            if (x >= win_x and x < win_x + handle_size) {
                return ResizeHandle.left;
            }
            if (x >= win_x + win.width - handle_size and x < win_x + win.width) {
                return ResizeHandle.right;
            }
            if (y >= win_y and y < win_y + handle_size) {
                return ResizeHandle.top;
            }
            if (y >= win_y + win.height - handle_size and y < win_y + win.height) {
                return ResizeHandle.bottom;
            }
        }
        return ResizeHandle.none;
    }

    // Start window drag.
    pub fn start_drag(self: *Compositor, window_id: u32, x: u32, y: u32) void {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            if (win.maximized) return;
            win.drag_state.active = true;
            win.drag_state.start_x = @as(i32, @intCast(x));
            win.drag_state.start_y = @as(i32, @intCast(y));
            win.drag_state.window_start_x = win.x;
            win.drag_state.window_start_y = win.y;
            _ = self.focus_window(window_id);
        }
    }

    // Handle mouse move during drag/resize.
    fn handle_mouse_move(self: *Compositor, x: u32, y: u32) void {
        // Handle dragging.
        if (self.focused_window_id > 0) {
            if (self.get_window(self.focused_window_id)) |win| {
                if (win.drag_state.active) {
                    const dx = @as(i32, @intCast(x)) - win.drag_state.start_x;
                    const dy = @as(i32, @intCast(y)) - win.drag_state.start_y;
                    win.x = win.drag_state.window_start_x + dx;
                    win.y = win.drag_state.window_start_y + dy;
                    // Apply window snapping if near edges/corners.
                    const snap_state = window_snapping.apply_snap(
                        &win.x,
                        &win.y,
                        &win.width,
                        &win.height,
                        self.output.width,
                        self.output.height,
                        window_snapping.SNAP_THRESHOLD,
                    );
                    // If not snapped, clamp to screen bounds.
                    if (!snap_state.snapped) {
                        const min_x: i32 = 0;
                        const min_y: i32 = @as(i32, @intCast(BORDER_WIDTH + TITLE_BAR_HEIGHT));
                        const max_x: i32 = @as(i32, @intCast(self.output.width)) - @as(i32, @intCast(win.width));
                        const max_y: i32 = @as(i32, @intCast(self.output.height)) - @as(i32, @intCast(win.height)) - @as(i32, @intCast(desktop_shell.STATUS_BAR_HEIGHT));
                        win.x = std.math.clamp(win.x, min_x, max_x);
                        win.y = std.math.clamp(win.y, min_y, max_y);
                    }
                }
            }
        }
        // Handle resizing.
        var i: u32 = 0;
        while (i < self.windows_len) : (i += 1) {
            const win = &self.windows[i];
            if (win.resize_state.active) {
                self.update_resize(win, x, y);
            }
        }
    }

    // Start window resize.
    pub fn start_resize(
        self: *Compositor,
        window_id: u32,
        handle: ResizeHandle,
        x: u32,
        y: u32,
    ) void {
        std.debug.assert(window_id > 0);
        if (self.get_window(window_id)) |win| {
            if (win.maximized) return;
            win.resize_state.active = true;
            win.resize_state.handle = handle;
            win.resize_state.start_x = @as(i32, @intCast(x));
            win.resize_state.start_y = @as(i32, @intCast(y));
            win.resize_state.window_start_width = win.width;
            win.resize_state.window_start_height = win.height;
            win.resize_state.window_start_x = win.x;
            win.resize_state.window_start_y = win.y;
            _ = self.focus_window(window_id);
        }
    }

    // Update window resize.
    fn update_resize(self: *Compositor, win: *Window, x: u32, y: u32) void {
        _ = self;
        std.debug.assert(win.resize_state.active);
        const dx = @as(i32, @intCast(x)) - win.resize_state.start_x;
        const dy = @as(i32, @intCast(y)) - win.resize_state.start_y;
        const min_size: u32 = 100;
        switch (win.resize_state.handle) {
            .top_left => {
                const new_width = if (win.resize_state.window_start_width > @as(u32, @intCast(-dx)))
                    win.resize_state.window_start_width - @as(u32, @intCast(-dx))
                else
                    min_size;
                const new_height = if (win.resize_state.window_start_height > @as(u32, @intCast(-dy)))
                    win.resize_state.window_start_height - @as(u32, @intCast(-dy))
                else
                    min_size;
                win.width = if (new_width < min_size) min_size else new_width;
                win.height = if (new_height < min_size) min_size else new_height;
                win.x = win.resize_state.window_start_x + dx;
                win.y = win.resize_state.window_start_y + dy;
            },
            .top => {
                const new_height = if (win.resize_state.window_start_height > @as(u32, @intCast(-dy)))
                    win.resize_state.window_start_height - @as(u32, @intCast(-dy))
                else
                    min_size;
                win.height = if (new_height < min_size) min_size else new_height;
                win.y = win.resize_state.window_start_y + dy;
            },
            .top_right => {
                const new_width = win.resize_state.window_start_width + @as(u32, @intCast(dx));
                const new_height = if (win.resize_state.window_start_height > @as(u32, @intCast(-dy)))
                    win.resize_state.window_start_height - @as(u32, @intCast(-dy))
                else
                    min_size;
                win.width = if (new_width < min_size) min_size else new_width;
                win.height = if (new_height < min_size) min_size else new_height;
                win.y = win.resize_state.window_start_y + dy;
            },
            .right => {
                const new_width = win.resize_state.window_start_width + @as(u32, @intCast(dx));
                win.width = if (new_width < min_size) min_size else new_width;
            },
            .bottom_right => {
                const new_width = win.resize_state.window_start_width + @as(u32, @intCast(dx));
                const new_height = win.resize_state.window_start_height + @as(u32, @intCast(dy));
                win.width = if (new_width < min_size) min_size else new_width;
                win.height = if (new_height < min_size) min_size else new_height;
            },
            .bottom => {
                const new_height = win.resize_state.window_start_height + @as(u32, @intCast(dy));
                win.height = if (new_height < min_size) min_size else new_height;
            },
            .bottom_left => {
                const new_width = if (win.resize_state.window_start_width > @as(u32, @intCast(-dx)))
                    win.resize_state.window_start_width - @as(u32, @intCast(-dx))
                else
                    min_size;
                const new_height = win.resize_state.window_start_height + @as(u32, @intCast(dy));
                win.width = if (new_width < min_size) min_size else new_width;
                win.height = if (new_height < min_size) min_size else new_height;
                win.x = win.resize_state.window_start_x + dx;
            },
            .left => {
                const new_width = if (win.resize_state.window_start_width > @as(u32, @intCast(-dx)))
                    win.resize_state.window_start_width - @as(u32, @intCast(-dx))
                else
                    min_size;
                win.width = if (new_width < min_size) min_size else new_width;
                win.x = win.resize_state.window_start_x + dx;
            },
            .none => {},
        }
        // Apply window constraints.
        const constrained = win.constraints.apply_constraints(win.width, win.height);
        win.width = constrained.width;
        win.height = constrained.height;
        // Clamp window to screen bounds.
        const max_width = self.output.width - (BORDER_WIDTH * 2);
        const max_height = self.output.height - (BORDER_WIDTH * 2) - TITLE_BAR_HEIGHT - desktop_shell.STATUS_BAR_HEIGHT;
        win.width = std.math.min(win.width, max_width);
        win.height = std.math.min(win.height, max_height);
    }

    // End window drag.
    pub fn end_drag(self: *Compositor) void {
        if (self.focused_window_id > 0) {
            if (self.get_window(self.focused_window_id)) |win| {
                win.drag_state.active = false;
            }
        }
    }

    // End window resize.
    pub fn end_resize(self: *Compositor) void {
        var i: u32 = 0;
        while (i < self.windows_len) : (i += 1) {
            self.windows[i].resize_state.active = false;
            self.windows[i].resize_state.handle = ResizeHandle.none;
        }
    }
};

