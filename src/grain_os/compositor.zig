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
const window_rules = @import("window_rules.zig");
const window_events = @import("window_events.zig");
const window_session = @import("window_session.zig");
const lock_screen_mod = @import("lock_screen.zig");
const notification = @import("notification.zig");
const clipboard = @import("clipboard.zig");
const app_launcher = @import("app_launcher.zig");
const system_tray = @import("system_tray.zig");
const power_management = @import("power_management.zig");
const display_management = @import("display_management.zig");
const settings_manager = @import("settings_manager.zig");
const theme_manager = @import("theme_manager.zig");
const screen_capture = @import("screen_capture.zig");
const file_manager = @import("file_manager.zig");
const resource_monitor = @import("resource_monitor.zig");
const audio_manager = @import("audio_manager.zig");
const network_manager = @import("network_manager.zig");
const process_manager = @import("process_manager.zig");
const system_logger = @import("system_logger.zig");
const time_manager = @import("time_manager.zig");
const security_manager = @import("security_manager.zig");
const service_manager = @import("service_manager.zig");
const backup_manager = @import("backup_manager.zig");
const update_manager = @import("update_manager.zig");
const package_manager = @import("package_manager.zig");
const health_monitor = @import("health_monitor.zig");
const process_supervision = @import("process_supervision.zig");
const system_metrics = @import("system_metrics.zig");
const system_diagnostics = @import("system_diagnostics.zig");
const keyboard_shortcuts = @import("keyboard_shortcuts.zig");
const desktop_shell = @import("desktop_shell.zig");
const runtime_config = @import("runtime_config.zig");
const application = @import("application.zig");
const tiling_config = @import("tiling_config.zig");

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
    rule_manager: window_rules.WindowRuleManager,
    event_manager: window_events.EventManager,
    session_manager: window_session.SessionManager,
    lock_screen_manager: lock_screen_mod.LockScreenManager,
    notification_manager: notification.NotificationManager,
    clipboard_manager: clipboard.ClipboardManager,
    app_launcher_manager: app_launcher.ApplicationLauncher,
    system_tray_manager: system_tray.SystemTrayManager,
    power_manager: power_management.PowerManagementManager,
    display_manager: display_management.DisplayManager,
    settings_manager: settings_manager.SettingsManager,
    theme_manager: theme_manager.ThemeManager,
    screen_capture_manager: screen_capture.ScreenCaptureManager,
    file_manager: file_manager.FileManager,
    resource_monitor: resource_monitor.ResourceMonitor,
    audio_manager: audio_manager.AudioManager,
    network_manager: network_manager.NetworkManager,
    process_manager: process_manager.ProcessManager,
    system_logger: system_logger.SystemLogger,
    time_manager: time_manager.TimeManager,
    security_manager: security_manager.SecurityManager,
    service_manager: service_manager.ServiceManager,
    backup_manager: backup_manager.BackupManager,
    update_manager: update_manager.UpdateManager,
    package_manager: package_manager.PackageManager,
    health_monitor: health_monitor.HealthMonitor,
    process_supervisor: process_supervision.ProcessSupervisor,
    metrics_aggregator: system_metrics.MetricsAggregator,
    system_diagnostics: system_diagnostics.SystemDiagnostics,
    border_width: u32, // Configurable border width
    title_bar_height: u32, // Configurable title bar height

    pub fn init(allocator: std.mem.Allocator) Compositor {
        std.debug.assert(@intFromPtr(allocator.ptr) != 0);
        var comp = Compositor{
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
            .shell = undefined, // Will be initialized after compositor is created
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
            .rule_manager = window_rules.WindowRuleManager.init(),
            .event_manager = window_events.EventManager.init(),
            .session_manager = window_session.SessionManager.init(),
            .lock_screen_manager = lock_screen_mod.LockScreenManager.init(),
            .notification_manager = notification.NotificationManager.init(),
            .clipboard_manager = clipboard.ClipboardManager.init(),
            .app_launcher_manager = app_launcher.ApplicationLauncher.init(),
            .system_tray_manager = system_tray.SystemTrayManager.init(),
            .power_manager = power_management.PowerManagementManager.init(),
            .display_manager = display_management.DisplayManager.init(),
            .settings_manager = settings_manager.SettingsManager.init(),
            .theme_manager = theme_manager.ThemeManager.init(),
            .screen_capture_manager = screen_capture.ScreenCaptureManager.init(),
            .file_manager = file_manager.FileManager.init(),
            .resource_monitor = resource_monitor.ResourceMonitor.init(),
            .audio_manager = audio_manager.AudioManager.init(),
            .network_manager = network_manager.NetworkManager.init(),
            .process_manager = process_manager.ProcessManager.init(),
            .system_logger = system_logger.SystemLogger.init(),
            .time_manager = time_manager.TimeManager.init(),
            .security_manager = security_manager.SecurityManager.init(),
            .service_manager = service_manager.ServiceManager.init(),
            .backup_manager = backup_manager.BackupManager.init(),
            .update_manager = update_manager.UpdateManager.init(),
            .package_manager = package_manager.PackageManager.init(),
            .health_monitor = health_monitor.HealthMonitor.init(),
            .process_supervisor = process_supervision.ProcessSupervisor.init(),
            .metrics_aggregator = system_metrics.MetricsAggregator.init(),
            .system_diagnostics = system_diagnostics.SystemDiagnostics.init(),
            .border_width = BORDER_WIDTH, // Default border width
            .title_bar_height = TITLE_BAR_HEIGHT, // Default title bar height
        };
        var i: u32 = 0;
        while (i < MAX_WINDOWS) : (i += 1) {
            comp.windows[i] = Window.init(0, 0, 0, 0, 0, 0);
        }
        comp.next_object_id = 4;
        comp.app_launcher = application.ApplicationLauncher.init(
            &comp.app_registry,
        );
        comp.shell.set_app_registry(&comp.app_registry);
        std.debug.assert(comp.windows_len == 0);
        std.debug.assert(comp.next_window_id > 0);
        return comp;
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

    // Get window (mutable version for modifications).
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

    // Get window (const version for read-only access).
    pub fn get_window_const(self: *const Compositor, window_id: u32) ?*const Window {
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
            @as(i32, @intCast(win.x)) + @as(i32, @intCast(self.border_width)),
            @as(i32, @intCast(win.y)) + @as(i32, @intCast(self.border_width)),
            win.width - (self.border_width * 2),
            self.title_bar_height,
            title_bar_color,
        );
        // Draw title bar buttons.
        self.render_title_bar_buttons(win);
        // Draw window content area (background, apply opacity).
        const content_y = @as(i32, @intCast(win.y)) + @as(i32, @intCast(self.border_width + self.title_bar_height));
        const content_height = win.height - (self.border_width * 2) - self.title_bar_height;
        const content_color = window_opacity.apply_opacity_to_color(
            framebuffer_renderer.COLOR_WHITE,
            win.opacity,
        );
        self.renderer.draw_rect(
            @as(i32, @intCast(win.x)) + @as(i32, @intCast(self.border_width)),
            content_y,
            win.width - (self.border_width * 2),
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
        self.resource_monitor.set_syscall_fn(fn_ptr);
        self.process_manager.set_syscall_fn(fn_ptr);
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
                            } else if (self.get_window(window_id)) |win| {
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
            win.y = @as(i32, @intCast(self.border_width + self.title_bar_height));
            win.width = self.output.width;
            win.height = self.output.height - (self.border_width * 2) - self.title_bar_height;
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

    // Set border width (runtime configuration).
    // 2025-11-25-183652-pst: Active function
    pub fn set_border_width(self: *Compositor, width: u32) void {
        std.debug.assert(width > 0);
        std.debug.assert(width <= 32); // Bounded: max 32 pixels
        self.border_width = width;
    }

    // Set title bar height (runtime configuration).
    // 2025-11-25-183652-pst: Active function
    pub fn set_title_bar_height(self: *Compositor, height: u32) void {
        std.debug.assert(height > 0);
        std.debug.assert(height <= 64); // Bounded: max 64 pixels
        self.title_bar_height = height;
    }

    // Get border width.
    pub fn get_border_width(self: *const Compositor) u32 {
        return self.border_width;
    }

    // Get title bar height.
    pub fn get_title_bar_height(self: *const Compositor) u32 {
        return self.title_bar_height;
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
                while (i < MAX_TITLE_LEN) : (i += 1) {
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
        if (self.get_window_const(window_id)) |win| {
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
            const title_bar_x = win.x + @as(i32, @intCast(self.border_width));
            const title_bar_y = win.y + @as(i32, @intCast(self.border_width));
            const title_bar_width = win.width - (self.border_width * 2);
            const x_i32 = @as(i32, @intCast(x));
            const y_i32 = @as(i32, @intCast(y));
            return (x_i32 >= title_bar_x and x_i32 < title_bar_x + @as(i32, @intCast(title_bar_width)) and
                y_i32 >= title_bar_y and y_i32 < title_bar_y + @as(i32, @intCast(self.title_bar_height)));
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
        if (self.get_window_const(window_id)) |win| {
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

    // Add window rule.
    pub fn add_window_rule(
        self: *Compositor,
        match_type: window_rules.MatchType,
        pattern: []const u8,
        action_type: window_rules.ActionType,
    ) ?u32 {
        return self.rule_manager.add_rule(match_type, pattern, action_type);
    }

    // Remove window rule.
    pub fn remove_window_rule(self: *Compositor, rule_id: u32) bool {
        return self.rule_manager.remove_rule(rule_id);
    }

    // Get rule count.
    pub fn get_rule_count(self: *const Compositor) u32 {
        return self.rule_manager.get_rule_count();
    }

    // Create window session.
    pub fn create_window_session(self: *Compositor, name: []const u8) ?u32 {
        if (self.session_manager.create_session(name)) |session_id| {
            // Save all current window states to session.
            if (self.session_manager.find_session(session_id)) |session| {
                var i: u32 = 0;
                while (i < self.windows_len) : (i += 1) {
                    const win = &self.windows[i];
                    const workspace_id = if (self.workspace_manager.get_window_workspace(win.id)) |ws_id|
                        ws_id
                    else
                        self.workspace_manager.current_workspace_id;
                    const title_slice = win.title[0..win.title_len];
                    _ = session.state_manager.save_window(
                        win.id,
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
            }
            return session_id;
        }
        return null;
    }

    // Restore window session.
    pub fn restore_window_session(self: *Compositor, session_id: u32) bool {
        std.debug.assert(session_id > 0);
        if (self.session_manager.find_session(session_id)) |session| {
            // Restore all windows from session.
            var i: u32 = 0;
            while (i < session.state_manager.entries_len) : (i += 1) {
                const entry = session.state_manager.entries[i];
                if (self.get_window(entry.window_id)) |win| {
                    win.x = entry.x;
                    win.y = entry.y;
                    win.width = entry.width;
                    win.height = entry.height;
                    win.minimized = entry.minimized;
                    win.maximized = entry.maximized;
                    win.visible = !entry.minimized;
                    // Restore title.
                    var j: u32 = 0;
                    while (j < MAX_TITLE_LEN) : (j += 1) {
                        win.title[j] = 0;
                    }
                    j = 0;
                    while (j < entry.title_len) : (j += 1) {
                        win.title[j] = entry.title[j];
                    }
                    win.title_len = entry.title_len;
                    // Assign to workspace.
                    _ = self.workspace_manager.assign_window_to_workspace(
                        entry.window_id,
                        entry.workspace_id,
                    );
                }
            }
            self.recalculate_layout();
            return true;
        }
        return false;
    }

    // Delete window session.
    pub fn delete_window_session(self: *Compositor, session_id: u32) bool {
        return self.session_manager.delete_session(session_id);
    }

    // Find session by name.
    pub fn find_session_by_name(self: *Compositor, name: []const u8) ?u32 {
        if (self.session_manager.find_session_by_name(name)) |session| {
            return session.session_id;
        }
        return null;
    }

    // Get session count.
    pub fn get_session_count(self: *const Compositor) u32 {
        return self.session_manager.get_session_count();
    }

    // Lock screen.
    pub fn lock_compositor_screen(self: *Compositor) void {
        self.lock_screen_manager.lock();
    }

    // Unlock screen.
    pub fn unlock_compositor_screen(self: *Compositor) void {
        self.lock_screen_manager.unlock();
    }

    // Check if screen is locked.
    pub fn is_screen_locked(self: *const Compositor) bool {
        return self.lock_screen_manager.is_locked();
    }

    // Add user identity.
    pub fn add_user_identity(
        self: *Compositor,
        name: []const u8,
        home_path: []const u8,
    ) ?u32 {
        return self.lock_screen_manager.add_identity(name, home_path);
    }

    // Authenticate with password.
    pub fn authenticate_password(
        self: *Compositor,
        identity_id: u32,
        password: []const u8,
    ) bool {
        return self.lock_screen_manager.authenticate_password(identity_id, password);
    }

    // Authenticate with TouchID.
    pub fn authenticate_touchid(self: *Compositor, identity_id: u32) bool {
        return self.lock_screen_manager.authenticate_touchid(identity_id);
    }

    // Get current identity.
    pub fn get_current_identity(self: *const Compositor) ?*const lock_screen_mod.UserIdentity {
        return self.lock_screen_manager.identity_manager.get_current_identity();
    }

    // Get identity count.
    pub fn get_identity_count(self: *const Compositor) u32 {
        return self.lock_screen_manager.identity_manager.get_identity_count();
    }

    // Add event listener.
    // 2025-11-26-124738-pst: Active function
    pub fn add_event_listener(
        self: *Compositor,
        listener_fn: window_events.EventListenerFn,
        user_data: ?*anyopaque,
    ) bool {
        return self.event_manager.add_listener(listener_fn, user_data);
    }

    // Show notification.
    pub fn show_notification(
        self: *Compositor,
        title: []const u8,
        message: []const u8,
        priority: notification.NotificationPriority,
    ) ?u32 {
        return self.notification_manager.add_notification(title, message, priority);
    }

    // Remove notification.
    pub fn remove_notification(self: *Compositor, notification_id: u32) bool {
        return self.notification_manager.remove_notification(notification_id);
    }

    // Expire notification.
    pub fn expire_notification(self: *Compositor, notification_id: u32) bool {
        return self.notification_manager.expire_notification(notification_id);
    }

    // Get notification count.
    pub fn get_notification_count(self: *const Compositor) u32 {
        return self.notification_manager.get_notification_count();
    }

    // Get active notification count.
    pub fn get_active_notification_count(self: *const Compositor) u32 {
        return self.notification_manager.get_active_count();
    }

    // Clear all notifications.
    pub fn clear_all_notifications(self: *Compositor) void {
        self.notification_manager.clear_all();
    }

    // Clear expired notifications.
    pub fn clear_expired_notifications(self: *Compositor) void {
        self.notification_manager.clear_expired();
    }

    // Set clipboard data.
    pub fn set_clipboard_data(
        self: *Compositor,
        format: clipboard.ClipboardFormat,
        data: []const u8,
        format_name: []const u8,
    ) bool {
        return self.clipboard_manager.set_data(format, data, format_name);
    }

    // Get clipboard data.
    pub fn get_clipboard_data(self: *const Compositor) ?[]const u8 {
        return self.clipboard_manager.get_data();
    }

    // Get clipboard format.
    pub fn get_clipboard_format(self: *const Compositor) clipboard.ClipboardFormat {
        return self.clipboard_manager.get_format();
    }

    // Get clipboard format name.
    pub fn get_clipboard_format_name(self: *const Compositor) []const u8 {
        return self.clipboard_manager.get_format_name();
    }

    // Check if clipboard is empty.
    pub fn is_clipboard_empty(self: *const Compositor) bool {
        return self.clipboard_manager.is_empty();
    }

    // Clear clipboard.
    pub fn clear_clipboard(self: *Compositor) void {
        self.clipboard_manager.clear();
    }

    // Get clipboard history entry.
    pub fn get_clipboard_history_entry(self: *const Compositor, index: u32) ?*const clipboard.ClipboardEntry {
        return self.clipboard_manager.get_history_entry(index);
    }

    // Get clipboard history count.
    pub fn get_clipboard_history_count(self: *const Compositor) u32 {
        return self.clipboard_manager.get_history_count();
    }

    // Clear clipboard history.
    pub fn clear_clipboard_history(self: *Compositor) void {
        self.clipboard_manager.clear_history();
    }

    // Add app to launcher.
    pub fn add_app_to_launcher(
        self: *Compositor,
        app_id: u32,
        name: []const u8,
        icon_path: []const u8,
    ) bool {
        return self.app_launcher_manager.add_app(app_id, name, icon_path);
    }

    // Search apps in launcher.
    pub fn search_apps_in_launcher(
        self: *Compositor,
        query: []const u8,
        results: []u32,
    ) u32 {
        return self.app_launcher_manager.search_apps(query, results);
    }

    // Add app to favorites.
    pub fn add_app_to_favorites(self: *Compositor, app_id: u32) bool {
        return self.app_launcher_manager.add_favorite(app_id);
    }

    // Remove app from favorites.
    pub fn remove_app_from_favorites(self: *Compositor, app_id: u32) bool {
        return self.app_launcher_manager.remove_favorite(app_id);
    }

    // Record app usage.
    pub fn record_app_usage(self: *Compositor, app_id: u32) void {
        self.app_launcher_manager.record_app_usage(app_id);
    }

    // Show app launcher.
    pub fn show_app_launcher(self: *Compositor) void {
        self.app_launcher_manager.show();
    }

    // Hide app launcher.
    pub fn hide_app_launcher(self: *Compositor) void {
        self.app_launcher_manager.hide();
    }

    // Check if app launcher is visible.
    pub fn is_app_launcher_visible(self: *const Compositor) bool {
        return self.app_launcher_manager.is_visible();
    }

    // Get app launcher count.
    pub fn get_app_launcher_count(self: *const Compositor) u32 {
        return self.app_launcher_manager.get_app_count();
    }

    // Get favorites count.
    pub fn get_favorites_count(self: *const Compositor) u32 {
        return self.app_launcher_manager.get_favorites_count();
    }

    // Get recent apps count.
    pub fn get_recent_apps_count(self: *const Compositor) u32 {
        return self.app_launcher_manager.get_recent_apps_count();
    }

    // Add tray icon.
    pub fn add_tray_icon(
        self: *Compositor,
        app_id: u32,
        icon_path: []const u8,
        tooltip: []const u8,
    ) ?u32 {
        return self.system_tray_manager.add_icon(app_id, icon_path, tooltip);
    }

    // Remove tray icon.
    pub fn remove_tray_icon(self: *Compositor, icon_id: u32) bool {
        return self.system_tray_manager.remove_icon(icon_id);
    }

    // Update tray icon tooltip.
    pub fn update_tray_icon_tooltip(
        self: *Compositor,
        icon_id: u32,
        tooltip: []const u8,
    ) bool {
        return self.system_tray_manager.update_tooltip(icon_id, tooltip);
    }

    // Show tray icon.
    pub fn show_tray_icon(self: *Compositor, icon_id: u32) bool {
        return self.system_tray_manager.show_icon(icon_id);
    }

    // Hide tray icon.
    pub fn hide_tray_icon(self: *Compositor, icon_id: u32) bool {
        return self.system_tray_manager.hide_icon(icon_id);
    }

    // Show system tray.
    pub fn show_system_tray(self: *Compositor) void {
        self.system_tray_manager.show();
    }

    // Hide system tray.
    pub fn hide_system_tray(self: *Compositor) void {
        self.system_tray_manager.hide();
    }

    // Check if system tray is visible.
    pub fn is_system_tray_visible(self: *const Compositor) bool {
        return self.system_tray_manager.is_visible();
    }

    // Get tray icon count.
    pub fn get_tray_icon_count(self: *const Compositor) u32 {
        return self.system_tray_manager.get_icon_count();
    }

    // Get visible tray icon count.
    pub fn get_visible_tray_icon_count(self: *const Compositor) u32 {
        return self.system_tray_manager.get_visible_icon_count();
    }

    // Suspend system.
    pub fn suspend_system(self: *Compositor) bool {
        return self.power_manager.suspend_system();
    }

    // Hibernate system.
    pub fn hibernate_system(self: *Compositor) bool {
        return self.power_manager.hibernate_system();
    }

    // Shutdown system.
    pub fn shutdown_system(self: *Compositor) bool {
        return self.power_manager.shutdown_system();
    }

    // Get power state.
    pub fn get_power_state(self: *const Compositor) power_management.PowerState {
        return self.power_manager.get_power_state();
    }

    // Get battery level.
    pub fn get_battery_level(self: *const Compositor) u32 {
        return self.power_manager.get_battery_level();
    }

    // Set battery level.
    pub fn set_battery_level(self: *Compositor, level: u32) void {
        self.power_manager.set_battery_level(level);
    }

    // Get battery state.
    pub fn get_battery_state(self: *const Compositor) power_management.BatteryState {
        return self.power_manager.get_battery_state();
    }

    // Set battery state.
    pub fn set_battery_state(self: *Compositor, state: power_management.BatteryState) void {
        self.power_manager.set_battery_state(state);
    }

    // Enable auto-suspend.
    pub fn enable_auto_suspend(self: *Compositor, timeout_ms: u32) void {
        self.power_manager.enable_auto_suspend(timeout_ms);
    }

    // Disable auto-suspend.
    pub fn disable_auto_suspend(self: *Compositor) void {
        self.power_manager.disable_auto_suspend();
    }

    // Check if auto-suspend is enabled.
    pub fn is_auto_suspend_enabled(self: *const Compositor) bool {
        return self.power_manager.is_auto_suspend_enabled();
    }

    // Get auto-suspend timeout.
    pub fn get_auto_suspend_timeout(self: *const Compositor) u32 {
        return self.power_manager.get_auto_suspend_timeout();
    }

    // Add display.
    pub fn add_display(
        self: *Compositor,
        name: []const u8,
        width: u32,
        height: u32,
        connection: display_management.DisplayConnection,
    ) ?u32 {
        return self.display_manager.add_display(name, width, height, connection);
    }

    // Remove display.
    pub fn remove_display(self: *Compositor, display_id: u32) bool {
        return self.display_manager.remove_display(display_id);
    }

    // Set display position.
    pub fn set_display_position(
        self: *Compositor,
        display_id: u32,
        x: i32,
        y: i32,
    ) bool {
        return self.display_manager.set_display_position(display_id, x, y);
    }

    // Set primary display.
    pub fn set_primary_display(self: *Compositor, display_id: u32) bool {
        return self.display_manager.set_primary_display(display_id);
    }

    // Enable display.
    pub fn enable_display(self: *Compositor, display_id: u32) bool {
        return self.display_manager.enable_display(display_id);
    }

    // Disable display.
    pub fn disable_display(self: *Compositor, display_id: u32) bool {
        return self.display_manager.disable_display(display_id);
    }

    // Get primary display.
    pub fn get_primary_display(self: *const Compositor) ?*const display_management.Display {
        return self.display_manager.get_primary_display();
    }

    // Get display count.
    pub fn get_display_count(self: *const Compositor) u32 {
        return self.display_manager.get_display_count();
    }

    // Get active display count.
    pub fn get_active_display_count(self: *const Compositor) u32 {
        return self.display_manager.get_active_display_count();
    }

    // Add settings category.
    pub fn add_settings_category(
        self: *Compositor,
        name: []const u8,
    ) ?u32 {
        return self.settings_manager.add_category(name);
    }

    // Add setting.
    pub fn add_setting(
        self: *Compositor,
        category_id: u32,
        key: []const u8,
        value_type: settings_manager.SettingValueType,
    ) ?u32 {
        return self.settings_manager.add_setting(category_id, key, value_type);
    }

    // Set setting string value.
    pub fn set_setting_string(
        self: *Compositor,
        setting_id: u32,
        value: []const u8,
    ) bool {
        return self.settings_manager.set_setting_string(setting_id, value);
    }

    // Set setting integer value.
    pub fn set_setting_integer(
        self: *Compositor,
        setting_id: u32,
        value: i64,
    ) bool {
        return self.settings_manager.set_setting_integer(setting_id, value);
    }

    // Set setting boolean value.
    pub fn set_setting_boolean(
        self: *Compositor,
        setting_id: u32,
        value: bool,
    ) bool {
        return self.settings_manager.set_setting_boolean(setting_id, value);
    }

    // Set setting float value.
    pub fn set_setting_float(
        self: *Compositor,
        setting_id: u32,
        value: f64,
    ) bool {
        return self.settings_manager.set_setting_float(setting_id, value);
    }

    // Find setting by key.
    pub fn find_setting_by_key(
        self: *Compositor,
        category_id: u32,
        key: []const u8,
    ) ?*const settings_manager.Setting {
        return self.settings_manager.find_setting_by_key(category_id, key);
    }

    // Remove setting.
    pub fn remove_setting(self: *Compositor, setting_id: u32) bool {
        return self.settings_manager.remove_setting(setting_id);
    }

    // Get setting count.
    pub fn get_setting_count(self: *const Compositor) u32 {
        return self.settings_manager.get_setting_count();
    }

    // Get category count.
    pub fn get_category_count(self: *const Compositor) u32 {
        return self.settings_manager.get_category_count();
    }

    // Add theme.
    pub fn add_theme(
        self: *Compositor,
        name: []const u8,
        bg_color: []const u8,
        fg_color: []const u8,
        border_color: []const u8,
        accent_color: []const u8,
    ) ?u32 {
        return self.theme_manager.add_theme(name, bg_color, fg_color, border_color, accent_color);
    }

    // Set current theme.
    pub fn set_current_theme(self: *Compositor, theme_id: u32) bool {
        return self.theme_manager.set_current_theme(theme_id);
    }

    // Get current theme.
    pub fn get_current_theme(self: *const Compositor) ?*const theme_manager.Theme {
        return self.theme_manager.get_current_theme();
    }

    // Remove theme.
    pub fn remove_theme(self: *Compositor, theme_id: u32) bool {
        return self.theme_manager.remove_theme(theme_id);
    }

    // Get theme count.
    pub fn get_theme_count(self: *const Compositor) u32 {
        return self.theme_manager.get_theme_count();
    }

    // Capture screenshot.
    pub fn capture_screenshot(
        self: *Compositor,
        name: []const u8,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        format: screen_capture.CaptureFormat,
        timestamp: u64,
    ) ?u32 {
        return self.screen_capture_manager.capture_screenshot(name, x, y, width, height, format, timestamp);
    }

    // Start screen recording.
    pub fn start_screen_recording(
        self: *Compositor,
        name: []const u8,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        format: screen_capture.CaptureFormat,
        timestamp: u64,
    ) ?u32 {
        return self.screen_capture_manager.start_recording(name, x, y, width, height, format, timestamp);
    }

    // Stop screen recording.
    pub fn stop_screen_recording(self: *Compositor) bool {
        return self.screen_capture_manager.stop_recording();
    }

    // Check if recording is active.
    pub fn is_recording_active(self: *const Compositor) bool {
        return self.screen_capture_manager.is_recording_active();
    }

    // Get current recording ID.
    pub fn get_current_recording_id(self: *const Compositor) ?u32 {
        return self.screen_capture_manager.get_current_recording_id();
    }

    // Remove capture.
    pub fn remove_capture(self: *Compositor, capture_id: u32) bool {
        return self.screen_capture_manager.remove_capture(capture_id);
    }

    // Get capture count.
    pub fn get_capture_count(self: *const Compositor) u32 {
        return self.screen_capture_manager.get_capture_count();
    }

    // Add file entry.
    pub fn add_file_entry(
        self: *Compositor,
        name: []const u8,
        path: []const u8,
        file_type: file_manager.FileType,
        size: u64,
        modified_time: u64,
    ) ?u32 {
        return self.file_manager.add_file_entry(name, path, file_type, size, modified_time);
    }

    // Find file entry by path.
    pub fn find_file_entry_by_path(
        self: *Compositor,
        path: []const u8,
    ) ?*const file_manager.FileEntry {
        return self.file_manager.find_file_entry_by_path(path);
    }

    // Set current directory.
    pub fn set_current_directory(self: *Compositor, path: []const u8) bool {
        return self.file_manager.set_current_directory(path);
    }

    // Get current directory.
    pub fn get_current_directory(self: *const Compositor) []const u8 {
        return self.file_manager.get_current_directory();
    }

    // Remove file entry.
    pub fn remove_file_entry(self: *Compositor, entry_id: u32) bool {
        return self.file_manager.remove_file_entry(entry_id);
    }

    // Clear all file entries.
    pub fn clear_all_file_entries(self: *Compositor) void {
        self.file_manager.clear_all();
    }

    // Get file count.
    pub fn get_file_count(self: *const Compositor) u32 {
        return self.file_manager.get_file_count();
    }

    // Update resource usage.
    pub fn update_resource_usage(
        self: *Compositor,
        cpu_percent: f64,
        memory_used: u64,
        memory_total: u64,
        disk_used: u64,
        disk_total: u64,
        timestamp: u64,
    ) void {
        self.resource_monitor.update_usage(cpu_percent, memory_used, memory_total, disk_used, disk_total, timestamp);
    }

    // Update resource usage from kernel.
    pub fn update_resource_usage_from_kernel(self: *Compositor, timestamp: u64) bool {
        return self.resource_monitor.update_from_kernel(timestamp);
    }

    // Get CPU usage.
    pub fn get_cpu_usage(self: *const Compositor) f64 {
        return self.resource_monitor.get_cpu_usage();
    }

    // Get memory usage.
    pub fn get_memory_usage(self: *const Compositor) u64 {
        return self.resource_monitor.get_memory_usage();
    }

    // Get total memory.
    pub fn get_total_memory(self: *const Compositor) u64 {
        return self.resource_monitor.get_total_memory();
    }

    // Get memory usage percentage.
    pub fn get_memory_usage_percent(self: *const Compositor) f64 {
        return self.resource_monitor.get_memory_usage_percent();
    }

    // Get disk usage.
    pub fn get_disk_usage(self: *const Compositor) u64 {
        return self.resource_monitor.get_disk_usage();
    }

    // Get total disk.
    pub fn get_total_disk(self: *const Compositor) u64 {
        return self.resource_monitor.get_total_disk();
    }

    // Get disk usage percentage.
    pub fn get_disk_usage_percent(self: *const Compositor) f64 {
        return self.resource_monitor.get_disk_usage_percent();
    }

    // Get current resource usage.
    pub fn get_current_resource_usage(self: *const Compositor) resource_monitor.ResourceUsage {
        return self.resource_monitor.get_current_usage();
    }

    // Get total process count from resource monitor.
    pub fn get_total_process_count(self: *const Compositor) u32 {
        return self.resource_monitor.get_total_processes();
    }

    // Get running process count from resource monitor.
    pub fn get_running_process_count_from_monitor(self: *const Compositor) u32 {
        return self.resource_monitor.get_running_processes();
    }

    // Get exited process count from resource monitor.
    pub fn get_exited_process_count(self: *const Compositor) u32 {
        return self.resource_monitor.get_exited_processes();
    }

    // Get resource history entry.
    pub fn get_resource_history_entry(self: *const Compositor, index: u32) ?*const resource_monitor.ResourceUsage {
        return self.resource_monitor.get_history_entry(index);
    }

    // Get resource history count.
    pub fn get_resource_history_count(self: *const Compositor) u32 {
        return self.resource_monitor.get_history_count();
    }

    // Clear resource history.
    pub fn clear_resource_history(self: *Compositor) void {
        self.resource_monitor.clear_history();
    }

    // Add audio device.
    pub fn add_audio_device(
        self: *Compositor,
        name: []const u8,
        device_type: audio_manager.AudioDeviceType,
    ) ?u32 {
        return self.audio_manager.add_device(name, device_type);
    }

    // Set device volume.
    pub fn set_audio_device_volume(self: *Compositor, device_id: u32, volume: u32) bool {
        return self.audio_manager.set_device_volume(device_id, volume);
    }

    // Get device volume.
    pub fn get_audio_device_volume(self: *Compositor, device_id: u32) ?u32 {
        return self.audio_manager.get_device_volume(device_id);
    }

    // Mute device.
    pub fn mute_audio_device(self: *Compositor, device_id: u32) bool {
        return self.audio_manager.mute_device(device_id);
    }

    // Unmute device.
    pub fn unmute_audio_device(self: *Compositor, device_id: u32) bool {
        return self.audio_manager.unmute_device(device_id);
    }

    // Set active output device.
    pub fn set_active_audio_output_device(self: *Compositor, device_id: u32) bool {
        return self.audio_manager.set_active_output_device(device_id);
    }

    // Set active input device.
    pub fn set_active_audio_input_device(self: *Compositor, device_id: u32) bool {
        return self.audio_manager.set_active_input_device(device_id);
    }

    // Get active output device.
    pub fn get_active_audio_output_device(self: *const Compositor) ?*const audio_manager.AudioDevice {
        return self.audio_manager.get_active_output_device();
    }

    // Get active input device.
    pub fn get_active_audio_input_device(self: *const Compositor) ?*const audio_manager.AudioDevice {
        return self.audio_manager.get_active_input_device();
    }

    // Set master volume.
    pub fn set_master_volume(self: *Compositor, volume: u32) void {
        self.audio_manager.set_master_volume(volume);
    }

    // Get master volume.
    pub fn get_master_volume(self: *const Compositor) u32 {
        return self.audio_manager.get_master_volume();
    }

    // Mute master.
    pub fn mute_master_audio(self: *Compositor) void {
        self.audio_manager.mute_master();
    }

    // Unmute master.
    pub fn unmute_master_audio(self: *Compositor) void {
        self.audio_manager.unmute_master();
    }

    // Check if master is muted.
    pub fn is_master_audio_muted(self: *const Compositor) bool {
        return self.audio_manager.is_master_muted();
    }

    // Remove audio device.
    pub fn remove_audio_device(self: *Compositor, device_id: u32) bool {
        return self.audio_manager.remove_device(device_id);
    }

    // Get audio device count.
    pub fn get_audio_device_count(self: *const Compositor) u32 {
        return self.audio_manager.get_device_count();
    }

    // Add network interface.
    pub fn add_network_interface(
        self: *Compositor,
        name: []const u8,
        interface_type: network_manager.InterfaceType,
    ) ?u32 {
        return self.network_manager.add_interface(name, interface_type);
    }

    // Set interface IP address.
    pub fn set_network_interface_ip(
        self: *Compositor,
        interface_id: u32,
        ip_address: []const u8,
        ip_type: network_manager.IpAddressType,
    ) bool {
        return self.network_manager.set_interface_ip(interface_id, ip_address, ip_type);
    }

    // Set interface netmask.
    pub fn set_network_interface_netmask(
        self: *Compositor,
        interface_id: u32,
        netmask: []const u8,
    ) bool {
        return self.network_manager.set_interface_netmask(interface_id, netmask);
    }

    // Set interface gateway.
    pub fn set_network_interface_gateway(
        self: *Compositor,
        interface_id: u32,
        gateway: []const u8,
    ) bool {
        return self.network_manager.set_interface_gateway(interface_id, gateway);
    }

    // Bring interface up.
    pub fn bring_network_interface_up(self: *Compositor, interface_id: u32) bool {
        return self.network_manager.bring_interface_up(interface_id);
    }

    // Bring interface down.
    pub fn bring_network_interface_down(self: *Compositor, interface_id: u32) bool {
        return self.network_manager.bring_interface_down(interface_id);
    }

    // Set active interface.
    pub fn set_active_network_interface(self: *Compositor, interface_id: u32) bool {
        return self.network_manager.set_active_interface(interface_id);
    }

    // Get active interface.
    pub fn get_active_network_interface(self: *const Compositor) ?*const network_manager.NetworkInterface {
        return self.network_manager.get_active_interface();
    }

    // Remove network interface.
    pub fn remove_network_interface(self: *Compositor, interface_id: u32) bool {
        return self.network_manager.remove_interface(interface_id);
    }

    // Get network interface count.
    pub fn get_network_interface_count(self: *const Compositor) u32 {
        return self.network_manager.get_interface_count();
    }

    // Add process.
    pub fn add_process(
        self: *Compositor,
        parent_process_id: u32,
        name: []const u8,
        cmd_line: []const u8,
        start_time: u64,
    ) ?u32 {
        return self.process_manager.add_process(parent_process_id, name, cmd_line, start_time);
    }

    // Spawn process using kernel spawn syscall.
    pub fn spawn_process(
        self: *Compositor,
        parent_process_id: u32,
        name: []const u8,
        cmd_line: []const u8,
        start_time: u64,
    ) ?u32 {
        return self.process_manager.spawn_process(parent_process_id, name, cmd_line, start_time);
    }

    // Kill process using kernel kill syscall.
    pub fn kill_process(self: *Compositor, process_id: u32) bool {
        return self.process_manager.kill_process(process_id);
    }

    // Set process state.
    pub fn set_process_state(
        self: *Compositor,
        process_id: u32,
        state: process_manager.ProcessState,
    ) bool {
        return self.process_manager.set_process_state(process_id, state);
    }

    // Set process priority.
    pub fn set_process_priority(
        self: *Compositor,
        process_id: u32,
        priority: process_manager.ProcessPriority,
    ) bool {
        return self.process_manager.set_process_priority(process_id, priority);
    }

    // Update process CPU usage.
    pub fn update_process_cpu_usage(
        self: *Compositor,
        process_id: u32,
        cpu_usage: f64,
    ) bool {
        return self.process_manager.update_process_cpu_usage(process_id, cpu_usage);
    }

    // Set process priority via kernel syscall.
    pub fn set_process_priority_via_kernel(
        self: *Compositor,
        process_id: u32,
        nice_value: i8,
    ) bool {
        return self.process_manager.set_process_priority_via_kernel(process_id, nice_value);
    }

    // Get process priority via kernel syscall.
    pub fn get_process_priority_via_kernel(
        self: *Compositor,
        process_id: u32,
    ) ?i8 {
        return self.process_manager.get_process_priority_via_kernel(process_id);
    }

    // Update process memory usage.
    pub fn update_process_memory_usage(
        self: *Compositor,
        process_id: u32,
        memory_usage: u64,
    ) bool {
        return self.process_manager.update_process_memory_usage(process_id, memory_usage);
    }

    // Remove process.
    pub fn remove_process(self: *Compositor, process_id: u32) bool {
        return self.process_manager.remove_process(process_id);
    }

    // Get process count.
    pub fn get_process_count(self: *const Compositor) u32 {
        return self.process_manager.get_process_count();
    }

    // Get running process count.
    pub fn get_running_process_count(self: *const Compositor) u32 {
        return self.process_manager.get_running_process_count();
    }

    // Log system event.
    pub fn log_system_event(
        self: *Compositor,
        level: system_logger.LogLevel,
        source: []const u8,
        message: []const u8,
        timestamp: u64,
    ) ?u32 {
        return self.system_logger.log(level, source, message, timestamp);
    }

    // Set minimum log level.
    pub fn set_min_log_level(self: *Compositor, level: system_logger.LogLevel) void {
        self.system_logger.set_min_log_level(level);
    }

    // Get minimum log level.
    pub fn get_min_log_level(self: *const Compositor) system_logger.LogLevel {
        return self.system_logger.get_min_log_level();
    }

    // Get log entry by index.
    pub fn get_log_entry(self: *const Compositor, index: u32) ?*const system_logger.LogEntry {
        return self.system_logger.get_entry(index);
    }

    // Clear all logs.
    pub fn clear_all_logs(self: *Compositor) void {
        self.system_logger.clear_all();
    }

    // Get log count.
    pub fn get_log_count(self: *const Compositor) u32 {
        return self.system_logger.get_log_count();
    }

    // Get log count by level.
    pub fn get_log_count_by_level(self: *const Compositor, level: system_logger.LogLevel) u32 {
        return self.system_logger.get_log_count_by_level(level);
    }

    // Set system time.
    pub fn set_system_time(self: *Compositor, time_ns: u64) void {
        self.time_manager.set_system_time(time_ns);
    }

    // Get system time.
    pub fn get_system_time(self: *const Compositor) u64 {
        return self.time_manager.get_system_time();
    }

    // Set timezone.
    pub fn set_timezone(
        self: *Compositor,
        name: []const u8,
        abbreviation: []const u8,
        offset_seconds: i32,
    ) bool {
        return self.time_manager.set_timezone(name, abbreviation, offset_seconds);
    }

    // Get timezone.
    pub fn get_timezone(self: *const Compositor) time_manager.Timezone {
        return self.time_manager.get_timezone();
    }

    // Set time format.
    pub fn set_time_format(self: *Compositor, format: time_manager.TimeFormat) void {
        self.time_manager.set_time_format(format);
    }

    // Get time format.
    pub fn get_time_format(self: *const Compositor) time_manager.TimeFormat {
        return self.time_manager.get_time_format();
    }

    // Set date format.
    pub fn set_date_format(self: *Compositor, format: time_manager.DateFormat) void {
        self.time_manager.set_date_format(format);
    }

    // Get date format.
    pub fn get_date_format(self: *const Compositor) time_manager.DateFormat {
        return self.time_manager.get_date_format();
    }

    // Enable auto-sync.
    pub fn enable_time_auto_sync(self: *Compositor) void {
        self.time_manager.enable_auto_sync();
    }

    // Disable auto-sync.
    pub fn disable_time_auto_sync(self: *Compositor) void {
        self.time_manager.disable_auto_sync();
    }

    // Check if auto-sync is enabled.
    pub fn is_time_auto_sync_enabled(self: *const Compositor) bool {
        return self.time_manager.is_auto_sync_enabled();
    }

    // Get local time.
    pub fn get_local_time(self: *const Compositor) u64 {
        return self.time_manager.get_local_time();
    }

    // Add permission.
    pub fn add_permission(
        self: *Compositor,
        name: []const u8,
        permission_type: security_manager.PermissionType,
    ) ?u32 {
        return self.security_manager.add_permission(name, permission_type);
    }

    // Add user.
    pub fn add_user(
        self: *Compositor,
        name: []const u8,
        role: security_manager.UserRole,
    ) ?u32 {
        return self.security_manager.add_user(name, role);
    }

    // Grant permission to user.
    pub fn grant_permission(self: *Compositor, user_id: u32, permission_id: u32) bool {
        return self.security_manager.grant_permission(user_id, permission_id);
    }

    // Revoke permission from user.
    pub fn revoke_permission(self: *Compositor, user_id: u32, permission_id: u32) bool {
        return self.security_manager.revoke_permission(user_id, permission_id);
    }

    // Check if user has permission.
    pub fn has_permission(self: *const Compositor, user_id: u32, permission_id: u32) bool {
        return self.security_manager.has_permission(user_id, permission_id);
    }

    // Set current user.
    pub fn set_current_user(self: *Compositor, user_id: u32) bool {
        return self.security_manager.set_current_user(user_id);
    }

    // Get current user.
    pub fn get_current_user(self: *const Compositor) ?*const security_manager.User {
        return self.security_manager.get_current_user();
    }

    // Remove user.
    pub fn remove_user(self: *Compositor, user_id: u32) bool {
        return self.security_manager.remove_user(user_id);
    }

    // Get permission count.
    pub fn get_permission_count(self: *const Compositor) u32 {
        return self.security_manager.get_permission_count();
    }

    // Get user count.
    pub fn get_user_count(self: *const Compositor) u32 {
        return self.security_manager.get_user_count();
    }

    // Add service.
    pub fn add_service(
        self: *Compositor,
        name: []const u8,
        description: []const u8,
        service_type: service_manager.ServiceType,
    ) ?u32 {
        return self.service_manager.add_service(name, description, service_type);
    }

    // Start service.
    pub fn start_service(self: *Compositor, service_id: u32) bool {
        return self.service_manager.start_service(service_id);
    }

    // Stop service.
    pub fn stop_service(self: *Compositor, service_id: u32) bool {
        return self.service_manager.stop_service(service_id);
    }

    // Restart service.
    pub fn restart_service(self: *Compositor, service_id: u32) bool {
        return self.service_manager.restart_service(service_id);
    }

    // Enable service auto-start.
    pub fn enable_service_auto_start(self: *Compositor, service_id: u32) bool {
        return self.service_manager.enable_auto_start(service_id);
    }

    // Disable service auto-start.
    pub fn disable_service_auto_start(self: *Compositor, service_id: u32) bool {
        return self.service_manager.disable_auto_start(service_id);
    }

    // Enable restart on failure.
    pub fn enable_service_restart_on_failure(self: *Compositor, service_id: u32) bool {
        return self.service_manager.enable_restart_on_failure(service_id);
    }

    // Disable restart on failure.
    pub fn disable_service_restart_on_failure(self: *Compositor, service_id: u32) bool {
        return self.service_manager.disable_restart_on_failure(service_id);
    }

    // Add service dependency.
    pub fn add_service_dependency(self: *Compositor, service_id: u32, dependency_id: u32) bool {
        return self.service_manager.add_dependency(service_id, dependency_id);
    }

    // Remove service dependency.
    pub fn remove_service_dependency(self: *Compositor, service_id: u32, dependency_id: u32) bool {
        return self.service_manager.remove_dependency(service_id, dependency_id);
    }

    // Remove service.
    pub fn remove_service(self: *Compositor, service_id: u32) bool {
        return self.service_manager.remove_service(service_id);
    }

    // Get service count.
    pub fn get_service_count(self: *const Compositor) u32 {
        return self.service_manager.get_service_count();
    }

    // Get running service count.
    pub fn get_running_service_count(self: *const Compositor) u32 {
        return self.service_manager.get_running_service_count();
    }

    // Create backup.
    pub fn create_backup(
        self: *Compositor,
        name: []const u8,
        description: []const u8,
        path: []const u8,
        backup_type: backup_manager.BackupType,
        timestamp: u64,
    ) ?u32 {
        return self.backup_manager.create_backup(name, description, path, backup_type, timestamp);
    }

    // Start backup operation.
    pub fn start_backup(self: *Compositor, backup_id: u32) bool {
        return self.backup_manager.start_backup(backup_id);
    }

    // Complete backup operation.
    pub fn complete_backup(self: *Compositor, backup_id: u32, size_bytes: u64) bool {
        return self.backup_manager.complete_backup(backup_id, size_bytes);
    }

    // Fail backup operation.
    pub fn fail_backup(self: *Compositor, backup_id: u32) bool {
        return self.backup_manager.fail_backup(backup_id);
    }

    // Cancel backup operation.
    pub fn cancel_backup(self: *Compositor, backup_id: u32) bool {
        return self.backup_manager.cancel_backup(backup_id);
    }

    // Restore from backup.
    pub fn restore_backup(self: *Compositor, backup_id: u32) bool {
        return self.backup_manager.restore_backup(backup_id);
    }

    // Remove backup.
    pub fn remove_backup(self: *Compositor, backup_id: u32) bool {
        return self.backup_manager.remove_backup(backup_id);
    }

    // Get backup count.
    pub fn get_backup_count(self: *const Compositor) u32 {
        return self.backup_manager.get_backup_count();
    }

    // Get completed backup count.
    pub fn get_completed_backup_count(self: *const Compositor) u32 {
        return self.backup_manager.get_completed_backup_count();
    }

    // Get current backup ID.
    pub fn get_current_backup_id(self: *const Compositor) u32 {
        return self.backup_manager.get_current_backup_id();
    }

    // Add update.
    pub fn add_update(
        self: *Compositor,
        version: []const u8,
        description: []const u8,
        url: []const u8,
        update_type: update_manager.UpdateType,
        size_bytes: u64,
        release_date: u64,
    ) ?u32 {
        return self.update_manager.add_update(version, description, url, update_type, size_bytes, release_date);
    }

    // Start download.
    pub fn start_update_download(self: *Compositor, update_id: u32) bool {
        return self.update_manager.start_download(update_id);
    }

    // Complete download.
    pub fn complete_update_download(self: *Compositor, update_id: u32) bool {
        return self.update_manager.complete_download(update_id);
    }

    // Start installation.
    pub fn start_update_installation(self: *Compositor, update_id: u32) bool {
        return self.update_manager.start_installation(update_id);
    }

    // Complete installation.
    pub fn complete_update_installation(self: *Compositor, update_id: u32) bool {
        return self.update_manager.complete_installation(update_id);
    }

    // Fail update.
    pub fn fail_update(self: *Compositor, update_id: u32) bool {
        return self.update_manager.fail_update(update_id);
    }

    // Cancel update.
    pub fn cancel_update(self: *Compositor, update_id: u32) bool {
        return self.update_manager.cancel_update(update_id);
    }

    // Remove update.
    pub fn remove_update(self: *Compositor, update_id: u32) bool {
        return self.update_manager.remove_update(update_id);
    }

    // Set current version.
    pub fn set_current_version(self: *Compositor, version: []const u8) bool {
        return self.update_manager.set_current_version(version);
    }

    // Get current version.
    pub fn get_current_version(self: *const Compositor) []const u8 {
        return self.update_manager.get_current_version();
    }

    // Enable auto-update.
    pub fn enable_auto_update(self: *Compositor) void {
        self.update_manager.enable_auto_update();
    }

    // Disable auto-update.
    pub fn disable_auto_update(self: *Compositor) void {
        self.update_manager.disable_auto_update();
    }

    // Check if auto-update is enabled.
    pub fn is_auto_update_enabled(self: *const Compositor) bool {
        return self.update_manager.is_auto_update_enabled();
    }

    // Get update count.
    pub fn get_update_count(self: *const Compositor) u32 {
        return self.update_manager.get_update_count();
    }

    // Get available update count.
    pub fn get_available_update_count(self: *const Compositor) u32 {
        return self.update_manager.get_available_update_count();
    }

    // Get current update ID.
    pub fn get_current_update_id(self: *const Compositor) u32 {
        return self.update_manager.get_current_update_id();
    }

    // Add package.
    pub fn add_package(
        self: *Compositor,
        name: []const u8,
        version: []const u8,
        description: []const u8,
        size_bytes: u64,
    ) ?u32 {
        return self.package_manager.add_package(name, version, description, size_bytes);
    }

    // Install package.
    pub fn install_package(self: *Compositor, package_id: u32, timestamp: u64) bool {
        return self.package_manager.install_package(package_id, timestamp);
    }

    // Remove package.
    pub fn remove_package(self: *Compositor, package_id: u32) bool {
        return self.package_manager.remove_package(package_id);
    }

    // Add package dependency.
    pub fn add_package_dependency(self: *Compositor, package_id: u32, dependency_id: u32) bool {
        return self.package_manager.add_dependency(package_id, dependency_id);
    }

    // Remove package dependency.
    pub fn remove_package_dependency(self: *Compositor, package_id: u32, dependency_id: u32) bool {
        return self.package_manager.remove_dependency(package_id, dependency_id);
    }

    // Remove package entry.
    pub fn remove_package_entry(self: *Compositor, package_id: u32) bool {
        return self.package_manager.remove_package_entry(package_id);
    }

    // Get package count.
    pub fn get_package_count(self: *const Compositor) u32 {
        return self.package_manager.get_package_count();
    }

    // Get installed package count.
    pub fn get_installed_package_count(self: *const Compositor) u32 {
        return self.package_manager.get_installed_package_count();
    }

    // Add health check.
    pub fn add_health_check(self: *Compositor, name: []const u8) ?u32 {
        return self.health_monitor.add_health_check(name);
    }

    // Update health check status.
    pub fn update_health_check(
        self: *Compositor,
        check_id: u32,
        status: health_monitor.HealthStatus,
        message: []const u8,
        timestamp: u64,
    ) bool {
        return self.health_monitor.update_health_check(check_id, status, message, timestamp);
    }

    // Remove health check.
    pub fn remove_health_check(self: *Compositor, check_id: u32) bool {
        return self.health_monitor.remove_health_check(check_id);
    }

    // Get overall health status.
    pub fn get_overall_health_status(self: *const Compositor) health_monitor.HealthStatus {
        return self.health_monitor.get_overall_status();
    }

    // Get health check count.
    pub fn get_health_check_count(self: *const Compositor) u32 {
        return self.health_monitor.get_health_check_count();
    }

    // Get healthy check count.
    pub fn get_healthy_check_count(self: *const Compositor) u32 {
        return self.health_monitor.get_healthy_check_count();
    }

    // Get warning check count.
    pub fn get_warning_check_count(self: *const Compositor) u32 {
        return self.health_monitor.get_warning_check_count();
    }

    // Get critical check count.
    pub fn get_critical_check_count(self: *const Compositor) u32 {
        return self.health_monitor.get_critical_check_count();
    }

    // Add supervised process.
    pub fn add_supervised_process(
        self: *Compositor,
        process_id: u32,
        policy: process_supervision.SupervisionPolicy,
        max_restarts: u32,
        restart_delay_ms: u32,
    ) ?u32 {
        return self.process_supervisor.add_supervised_process(process_id, policy, max_restarts, restart_delay_ms);
    }

    // Update supervised process state.
    pub fn update_supervised_process_state(
        self: *Compositor,
        process_id: u32,
        state: process_supervision.SupervisionState,
    ) bool {
        return self.process_supervisor.update_process_state(process_id, state);
    }

    // Record supervised process exit.
    pub fn record_supervised_process_exit(
        self: *Compositor,
        process_id: u32,
        exit_code: i32,
        timestamp: u64,
    ) bool {
        return self.process_supervisor.record_process_exit(process_id, exit_code, timestamp);
    }

    // Remove supervised process.
    pub fn remove_supervised_process(self: *Compositor, supervision_id: u32) bool {
        return self.process_supervisor.remove_supervised_process(supervision_id);
    }

    // Get supervised process count.
    pub fn get_supervised_process_count(self: *const Compositor) u32 {
        return self.process_supervisor.get_supervised_count();
    }

    // Get running supervised count.
    pub fn get_running_supervised_count(self: *const Compositor) u32 {
        return self.process_supervisor.get_running_count();
    }

    // Get crashed supervised count.
    pub fn get_crashed_supervised_count(self: *const Compositor) u32 {
        return self.process_supervisor.get_crashed_count();
    }

    // Update system metrics from all sources.
    pub fn update_system_metrics(self: *Compositor, timestamp: u64) void {
        // Update from resource monitor.
        self.metrics_aggregator.update_from_resource_monitor(
            self.resource_monitor.get_cpu_usage(),
            self.resource_monitor.get_memory_usage_percent(),
            self.resource_monitor.get_disk_usage_percent(),
            self.resource_monitor.get_total_processes(),
            self.resource_monitor.get_running_processes(),
        );
        // Update from health monitor.
        const overall_health = self.health_monitor.get_overall_status();
        const health_status = switch (overall_health) {
            health_monitor.HealthStatus.healthy => system_metrics.SystemHealth.healthy,
            health_monitor.HealthStatus.warning => system_metrics.SystemHealth.warning,
            health_monitor.HealthStatus.critical => system_metrics.SystemHealth.critical,
            health_monitor.HealthStatus.unknown => system_metrics.SystemHealth.unknown,
        };
        self.metrics_aggregator.update_from_health_monitor(
            health_status,
            self.health_monitor.get_healthy_check_count(),
            self.health_monitor.get_warning_check_count(),
            self.health_monitor.get_critical_check_count(),
        );
        // Update from process supervisor.
        self.metrics_aggregator.update_from_process_supervisor(
            self.process_supervisor.get_supervised_count(),
            self.process_supervisor.get_running_count(),
            self.process_supervisor.get_crashed_count(),
        );
        // Update timestamp.
        self.metrics_aggregator.update_timestamp(timestamp);
    }

    // Get system status.
    pub fn get_system_status(self: *Compositor) system_metrics.SystemStatus {
        return self.metrics_aggregator.get_system_status();
    }

    // Get overall system health.
    pub fn get_overall_system_health(self: *Compositor) system_metrics.SystemHealth {
        return self.metrics_aggregator.get_overall_health();
    }

    // Add diagnostic check.
    pub fn add_diagnostic_check(
        self: *Compositor,
        name: []const u8,
        severity: system_diagnostics.DiagnosticSeverity,
        message: []const u8,
        timestamp: u64,
    ) ?u32 {
        return self.system_diagnostics.add_diagnostic_check(name, severity, message, timestamp);
    }

    // Remove diagnostic check.
    pub fn remove_diagnostic_check(self: *Compositor, check_id: u32) bool {
        return self.system_diagnostics.remove_diagnostic_check(check_id);
    }

    // Get diagnostic check count.
    pub fn get_diagnostic_check_count(self: *const Compositor) u32 {
        return self.system_diagnostics.get_diagnostic_check_count();
    }

    // Get diagnostic check count by severity.
    pub fn get_diagnostic_check_count_by_severity(
        self: *const Compositor,
        severity: system_diagnostics.DiagnosticSeverity,
    ) u32 {
        return self.system_diagnostics.get_diagnostic_check_count_by_severity(severity);
    }

    // Clear all diagnostic checks.
    pub fn clear_all_diagnostic_checks(self: *Compositor) void {
        self.system_diagnostics.clear_all();
    }

    // Clear diagnostic checks by severity.
    pub fn clear_diagnostic_checks_by_severity(
        self: *Compositor,
        severity: system_diagnostics.DiagnosticSeverity,
    ) void {
        self.system_diagnostics.clear_by_severity(severity);
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
                        const min_y: i32 = @as(i32, @intCast(self.border_width + self.title_bar_height));
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
        std.debug.assert(win.resize_state.active);
        // Parameters x and y are used in calculations below.
        // Self is used implicitly through method calls.
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
        const max_width = self.output.width - (self.border_width * 2);
        const max_height = self.output.height - (self.border_width * 2) - self.title_bar_height - desktop_shell.STATUS_BAR_HEIGHT;
        win.width = if (win.width > max_width) max_width else win.width;
        win.height = if (win.height > max_height) max_height else win.height;
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

