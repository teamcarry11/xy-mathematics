//! Grain OS System Tray: System tray for background applications.
//!
//! Why: Provide system tray for background applications and system indicators.
//! Architecture: Tray icon management, notifications, tooltips.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max tray icons.
pub const MAX_TRAY_ICONS: u32 = 32;

// Bounded: Max tooltip length.
pub const MAX_TOOLTIP_LEN: u32 = 128;

// Bounded: Max icon path length.
pub const MAX_ICON_PATH_LEN: u32 = 256;

// Tray icon: represents a system tray icon.
pub const TrayIcon = struct {
    icon_id: u32,
    app_id: u32,
    icon_path: [MAX_ICON_PATH_LEN]u8,
    icon_path_len: u32,
    tooltip: [MAX_TOOLTIP_LEN]u8,
    tooltip_len: u32,
    visible: bool,
    active: bool,

    pub fn init() TrayIcon {
        var icon = TrayIcon{
            .icon_id = 0,
            .app_id = 0,
            .icon_path = undefined,
            .icon_path_len = 0,
            .tooltip = undefined,
            .tooltip_len = 0,
            .visible = true,
            .active = true,
        };
        var i: u32 = 0;
        while (i < MAX_ICON_PATH_LEN) : (i += 1) {
            icon.icon_path[i] = 0;
        }
        i = 0;
        while (i < MAX_TOOLTIP_LEN) : (i += 1) {
            icon.tooltip[i] = 0;
        }
        return icon;
    }
};

// System tray manager: manages system tray icons.
pub const SystemTrayManager = struct {
    icons: [MAX_TRAY_ICONS]TrayIcon,
    icons_len: u32,
    next_icon_id: u32,
    visible: bool,

    pub fn init() SystemTrayManager {
        var manager = SystemTrayManager{
            .icons = undefined,
            .icons_len = 0,
            .next_icon_id = 1,
            .visible = true,
        };
        var i: u32 = 0;
        while (i < MAX_TRAY_ICONS) : (i += 1) {
            manager.icons[i] = TrayIcon.init();
        }
        return manager;
    }

    // Add tray icon.
    pub fn add_icon(
        self: *SystemTrayManager,
        app_id: u32,
        icon_path: []const u8,
        tooltip: []const u8,
    ) ?u32 {
        if (self.icons_len >= MAX_TRAY_ICONS) {
            return null;
        }
        if (icon_path.len > MAX_ICON_PATH_LEN) {
            return null;
        }
        if (tooltip.len > MAX_TOOLTIP_LEN) {
            return null;
        }
        const icon_id = self.next_icon_id;
        self.next_icon_id += 1;
        self.icons[self.icons_len] = TrayIcon.init();
        self.icons[self.icons_len].icon_id = icon_id;
        self.icons[self.icons_len].app_id = app_id;
        var i: u32 = 0;
        while (i < MAX_ICON_PATH_LEN) : (i += 1) {
            self.icons[self.icons_len].icon_path[i] = 0;
        }
        const icon_len = @min(icon_path.len, MAX_ICON_PATH_LEN);
        i = 0;
        while (i < icon_len) : (i += 1) {
            self.icons[self.icons_len].icon_path[i] = icon_path[i];
        }
        self.icons[self.icons_len].icon_path_len = @intCast(icon_len);
        i = 0;
        while (i < MAX_TOOLTIP_LEN) : (i += 1) {
            self.icons[self.icons_len].tooltip[i] = 0;
        }
        const tooltip_len = @min(tooltip.len, MAX_TOOLTIP_LEN);
        i = 0;
        while (i < tooltip_len) : (i += 1) {
            self.icons[self.icons_len].tooltip[i] = tooltip[i];
        }
        self.icons[self.icons_len].tooltip_len = @intCast(tooltip_len);
        self.icons_len += 1;
        return icon_id;
    }

    // Find icon by ID.
    pub fn find_icon(
        self: *SystemTrayManager,
        icon_id: u32,
    ) ?*TrayIcon {
        std.debug.assert(icon_id > 0);
        var i: u32 = 0;
        while (i < self.icons_len) : (i += 1) {
            if (self.icons[i].icon_id == icon_id and self.icons[i].active) {
                return &self.icons[i];
            }
        }
        return null;
    }

    // Find icon by app ID.
    pub fn find_icon_by_app_id(
        self: *SystemTrayManager,
        app_id: u32,
    ) ?*TrayIcon {
        std.debug.assert(app_id > 0);
        var i: u32 = 0;
        while (i < self.icons_len) : (i += 1) {
            if (self.icons[i].app_id == app_id and self.icons[i].active) {
                return &self.icons[i];
            }
        }
        return null;
    }

    // Remove tray icon.
    pub fn remove_icon(self: *SystemTrayManager, icon_id: u32) bool {
        std.debug.assert(icon_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.icons_len) : (i += 1) {
            if (self.icons[i].icon_id == icon_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining icons left.
        while (i < self.icons_len - 1) : (i += 1) {
            self.icons[i] = self.icons[i + 1];
        }
        self.icons_len -= 1;
        return true;
    }

    // Update icon tooltip.
    pub fn update_tooltip(
        self: *SystemTrayManager,
        icon_id: u32,
        tooltip: []const u8,
    ) bool {
        std.debug.assert(icon_id > 0);
        if (tooltip.len > MAX_TOOLTIP_LEN) {
            return false;
        }
        if (self.find_icon(icon_id)) |icon| {
            var i: u32 = 0;
            while (i < MAX_TOOLTIP_LEN) : (i += 1) {
                icon.tooltip[i] = 0;
            }
            const tooltip_len = @min(tooltip.len, MAX_TOOLTIP_LEN);
            i = 0;
            while (i < tooltip_len) : (i += 1) {
                icon.tooltip[i] = tooltip[i];
            }
            icon.tooltip_len = @intCast(tooltip_len);
            return true;
        }
        return false;
    }

    // Show tray icon.
    pub fn show_icon(self: *SystemTrayManager, icon_id: u32) bool {
        std.debug.assert(icon_id > 0);
        if (self.find_icon(icon_id)) |icon| {
            icon.visible = true;
            return true;
        }
        return false;
    }

    // Hide tray icon.
    pub fn hide_icon(self: *SystemTrayManager, icon_id: u32) bool {
        std.debug.assert(icon_id > 0);
        if (self.find_icon(icon_id)) |icon| {
            icon.visible = false;
            return true;
        }
        return false;
    }

    // Show system tray.
    pub fn show(self: *SystemTrayManager) void {
        self.visible = true;
    }

    // Hide system tray.
    pub fn hide(self: *SystemTrayManager) void {
        self.visible = false;
    }

    // Check if system tray is visible.
    pub fn is_visible(self: *const SystemTrayManager) bool {
        return self.visible;
    }

    // Get icon count.
    pub fn get_icon_count(self: *const SystemTrayManager) u32 {
        return self.icons_len;
    }

    // Get visible icon count.
    pub fn get_visible_icon_count(self: *const SystemTrayManager) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.icons_len) : (i += 1) {
            if (self.icons[i].visible and self.icons[i].active) {
                count += 1;
            }
        }
        return count;
    }
};

