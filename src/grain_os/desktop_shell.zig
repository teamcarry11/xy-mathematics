//! Grain OS Desktop Shell: Status bar and launcher.
//!
//! Why: Provide basic desktop UI elements (status bar, launcher).
//! Architecture: Renders on top of compositor framebuffer.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const framebuffer_renderer = @import("framebuffer_renderer.zig");
const workspace = @import("workspace.zig");

// Bounded: Status bar height.
pub const STATUS_BAR_HEIGHT: u32 = 32;

// Bounded: Launcher width.
pub const LAUNCHER_WIDTH: u32 = 300;

// Bounded: Launcher height.
pub const LAUNCHER_HEIGHT: u32 = 400;

// Bounded: Max launcher items.
pub const MAX_LAUNCHER_ITEMS: u32 = 32;

// Bounded: Max item name length.
pub const MAX_ITEM_NAME_LEN: u32 = 64;

// Launcher item: application entry.
pub const LauncherItem = struct {
    name: [MAX_ITEM_NAME_LEN]u8,
    name_len: u32,
    command: [MAX_ITEM_NAME_LEN]u8,
    command_len: u32,
    icon: u32, // Placeholder for icon ID.

    pub fn init(name: []const u8, command: []const u8) LauncherItem {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_ITEM_NAME_LEN);
        std.debug.assert(command.len > 0);
        std.debug.assert(command.len <= MAX_ITEM_NAME_LEN);
        var item = LauncherItem{
            .name = undefined,
            .name_len = 0,
            .command = undefined,
            .command_len = 0,
            .icon = 0,
        };
        @memset(&item.name, 0);
        @memset(&item.command, 0);
        const name_copy_len = @min(name.len, MAX_ITEM_NAME_LEN);
        @memcpy(item.name[0..name_copy_len], name[0..name_copy_len]);
        item.name_len = @intCast(name_copy_len);
        const cmd_copy_len = @min(command.len, MAX_ITEM_NAME_LEN);
        @memcpy(item.command[0..cmd_copy_len], command[0..cmd_copy_len]);
        item.command_len = @intCast(cmd_copy_len);
        std.debug.assert(item.name_len > 0);
        return item;
    }
};

// Desktop shell: status bar and launcher.
pub const DesktopShell = struct {
    renderer: *const framebuffer_renderer.FramebufferRenderer,
    output_width: u32,
    output_height: u32,
    launcher_items: [MAX_LAUNCHER_ITEMS]LauncherItem,
    launcher_items_len: u32,
    launcher_visible: bool,
    current_workspace_id: u32,

    pub fn init(
        renderer: *const framebuffer_renderer.FramebufferRenderer,
        output_width: u32,
        output_height: u32,
    ) DesktopShell {
        std.debug.assert(@intFromPtr(renderer) != 0);
        std.debug.assert(output_width > 0);
        std.debug.assert(output_height > 0);
        var shell = DesktopShell{
            .renderer = renderer,
            .output_width = output_width,
            .output_height = output_height,
            .launcher_items = undefined,
            .launcher_items_len = 0,
            .launcher_visible = false,
            .current_workspace_id = 1,
        };
        // Initialize launcher items array.
        var i: u32 = 0;
        while (i < MAX_LAUNCHER_ITEMS) : (i += 1) {
            shell.launcher_items[i] = LauncherItem.init("", "");
        }
        // Add default launcher items.
        _ = shell.add_launcher_item("Terminal", "terminal");
        _ = shell.add_launcher_item("Editor", "editor");
        _ = shell.add_launcher_item("Browser", "browser");
        std.debug.assert(shell.launcher_items_len > 0);
        return shell;
    }

    // Add item to launcher.
    pub fn add_launcher_item(self: *DesktopShell, name: []const u8, command: []const u8) bool {
        std.debug.assert(name.len > 0);
        std.debug.assert(command.len > 0);
        if (self.launcher_items_len >= MAX_LAUNCHER_ITEMS) return false;
        self.launcher_items[self.launcher_items_len] = LauncherItem.init(name, command);
        self.launcher_items_len += 1;
        std.debug.assert(self.launcher_items_len <= MAX_LAUNCHER_ITEMS);
        return true;
    }

    // Toggle launcher visibility.
    pub fn toggle_launcher(self: *DesktopShell) void {
        self.launcher_visible = !self.launcher_visible;
    }

    // Set current workspace ID.
    pub fn set_current_workspace(self: *DesktopShell, workspace_id: u32) void {
        std.debug.assert(workspace_id > 0);
        self.current_workspace_id = workspace_id;
    }

    // Render status bar.
    pub fn render_status_bar(self: *const DesktopShell) void {
        std.debug.assert(self.output_width > 0);
        std.debug.assert(self.output_height > 0);
        // Draw status bar background.
        const status_y = self.output_height - STATUS_BAR_HEIGHT;
        self.renderer.draw_rect(
            0,
            @as(i32, @intCast(status_y)),
            self.output_width,
            STATUS_BAR_HEIGHT,
            framebuffer_renderer.COLOR_DARK_BG,
        );
        // Draw workspace indicator (simple rectangle for now).
        const workspace_x: u32 = 10;
        const workspace_y: u32 = status_y + 8;
        const workspace_width: u32 = 16;
        const workspace_height: u32 = 16;
        self.renderer.draw_rect(
            @as(i32, @intCast(workspace_x)),
            @as(i32, @intCast(workspace_y)),
            workspace_width,
            workspace_height,
            framebuffer_renderer.COLOR_BLUE,
        );
        // TODO: Draw time and other status bar elements.
    }

    // Render launcher.
    pub fn render_launcher(self: *const DesktopShell) void {
        if (!self.launcher_visible) return;
        std.debug.assert(self.output_width > 0);
        std.debug.assert(self.output_height > 0);
        // Draw launcher background.
        const launcher_x = (self.output_width - LAUNCHER_WIDTH) / 2;
        const launcher_y = (self.output_height - LAUNCHER_HEIGHT) / 2;
        self.renderer.draw_rect(
            @as(i32, @intCast(launcher_x)),
            @as(i32, @intCast(launcher_y)),
            LAUNCHER_WIDTH,
            LAUNCHER_HEIGHT,
            framebuffer_renderer.COLOR_DARK_BG,
        );
        // Draw launcher border.
        self.renderer.draw_rect(
            @as(i32, @intCast(launcher_x)),
            @as(i32, @intCast(launcher_y)),
            LAUNCHER_WIDTH,
            2,
            framebuffer_renderer.COLOR_WHITE,
        );
        // TODO: Draw launcher items.
    }

    // Render desktop shell (status bar and launcher).
    pub fn render(self: *const DesktopShell) void {
        self.render_status_bar();
        self.render_launcher();
    }
};

