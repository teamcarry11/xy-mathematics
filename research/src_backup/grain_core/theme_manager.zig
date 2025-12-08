//! Grain OS Theme Manager: UI theme and appearance management.
//!
//! Why: Provide theme management for UI appearance customization.
//! Architecture: Theme storage, color schemes, font settings.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max themes.
pub const MAX_THEMES: u32 = 16;

// Bounded: Max theme name length.
pub const MAX_THEME_NAME_LEN: u32 = 64;

// Bounded: Max color value length (hex format).
pub const MAX_COLOR_LEN: u32 = 8;

// Theme: represents a UI theme.
pub const Theme = struct {
    theme_id: u32,
    name: [MAX_THEME_NAME_LEN]u8,
    name_len: u32,
    bg_color: [MAX_COLOR_LEN]u8,
    bg_color_len: u32,
    fg_color: [MAX_COLOR_LEN]u8,
    fg_color_len: u32,
    border_color: [MAX_COLOR_LEN]u8,
    border_color_len: u32,
    accent_color: [MAX_COLOR_LEN]u8,
    accent_color_len: u32,
    active: bool,

    pub fn init() Theme {
        var theme = Theme{
            .theme_id = 0,
            .name = undefined,
            .name_len = 0,
            .bg_color = undefined,
            .bg_color_len = 0,
            .fg_color = undefined,
            .fg_color_len = 0,
            .border_color = undefined,
            .border_color_len = 0,
            .accent_color = undefined,
            .accent_color_len = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_THEME_NAME_LEN) : (i += 1) {
            theme.name[i] = 0;
        }
        i = 0;
        while (i < MAX_COLOR_LEN) : (i += 1) {
            theme.bg_color[i] = 0;
            theme.fg_color[i] = 0;
            theme.border_color[i] = 0;
            theme.accent_color[i] = 0;
        }
        return theme;
    }
};

// Theme manager: manages UI themes.
pub const ThemeManager = struct {
    themes: [MAX_THEMES]Theme,
    themes_len: u32,
    next_theme_id: u32,
    current_theme_id: u32,

    pub fn init() ThemeManager {
        var manager = ThemeManager{
            .themes = undefined,
            .themes_len = 0,
            .next_theme_id = 1,
            .current_theme_id = 0,
        };
        var i: u32 = 0;
        while (i < MAX_THEMES) : (i += 1) {
            manager.themes[i] = Theme.init();
        }
        return manager;
    }

    // Add theme.
    pub fn add_theme(
        self: *ThemeManager,
        name: []const u8,
        bg_color: []const u8,
        fg_color: []const u8,
        border_color: []const u8,
        accent_color: []const u8,
    ) ?u32 {
        if (self.themes_len >= MAX_THEMES) {
            return null;
        }
        if (name.len > MAX_THEME_NAME_LEN) {
            return null;
        }
        if (bg_color.len > MAX_COLOR_LEN or fg_color.len > MAX_COLOR_LEN or border_color.len > MAX_COLOR_LEN or accent_color.len > MAX_COLOR_LEN) {
            return null;
        }
        const theme_id = self.next_theme_id;
        self.next_theme_id += 1;
        self.themes[self.themes_len] = Theme.init();
        self.themes[self.themes_len].theme_id = theme_id;
        self.themes[self.themes_len].active = true;
        var i: u32 = 0;
        while (i < MAX_THEME_NAME_LEN) : (i += 1) {
            self.themes[self.themes_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_THEME_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.themes[self.themes_len].name[i] = name[i];
        }
        self.themes[self.themes_len].name_len = @intCast(name_len);
        const bg_len = @min(bg_color.len, MAX_COLOR_LEN);
        i = 0;
        while (i < MAX_COLOR_LEN) : (i += 1) {
            self.themes[self.themes_len].bg_color[i] = 0;
        }
        i = 0;
        while (i < bg_len) : (i += 1) {
            self.themes[self.themes_len].bg_color[i] = bg_color[i];
        }
        self.themes[self.themes_len].bg_color_len = @intCast(bg_len);
        const fg_len = @min(fg_color.len, MAX_COLOR_LEN);
        i = 0;
        while (i < MAX_COLOR_LEN) : (i += 1) {
            self.themes[self.themes_len].fg_color[i] = 0;
        }
        i = 0;
        while (i < fg_len) : (i += 1) {
            self.themes[self.themes_len].fg_color[i] = fg_color[i];
        }
        self.themes[self.themes_len].fg_color_len = @intCast(fg_len);
        const border_len = @min(border_color.len, MAX_COLOR_LEN);
        i = 0;
        while (i < MAX_COLOR_LEN) : (i += 1) {
            self.themes[self.themes_len].border_color[i] = 0;
        }
        i = 0;
        while (i < border_len) : (i += 1) {
            self.themes[self.themes_len].border_color[i] = border_color[i];
        }
        self.themes[self.themes_len].border_color_len = @intCast(border_len);
        const accent_len = @min(accent_color.len, MAX_COLOR_LEN);
        i = 0;
        while (i < MAX_COLOR_LEN) : (i += 1) {
            self.themes[self.themes_len].accent_color[i] = 0;
        }
        i = 0;
        while (i < accent_len) : (i += 1) {
            self.themes[self.themes_len].accent_color[i] = accent_color[i];
        }
        self.themes[self.themes_len].accent_color_len = @intCast(accent_len);
        if (self.current_theme_id == 0) {
            self.current_theme_id = theme_id;
        }
        self.themes_len += 1;
        return theme_id;
    }

    // Find theme by ID.
    pub fn find_theme(
        self: *ThemeManager,
        theme_id: u32,
    ) ?*Theme {
        std.debug.assert(theme_id > 0);
        var i: u32 = 0;
        while (i < self.themes_len) : (i += 1) {
            if (self.themes[i].theme_id == theme_id and self.themes[i].active) {
                return &self.themes[i];
            }
        }
        return null;
    }

    // Set current theme.
    pub fn set_current_theme(self: *ThemeManager, theme_id: u32) bool {
        std.debug.assert(theme_id > 0);
        if (self.find_theme(theme_id)) |_| {
            self.current_theme_id = theme_id;
            return true;
        }
        return false;
    }

    // Get current theme.
    pub fn get_current_theme(self: *const ThemeManager) ?*const Theme {
        if (self.current_theme_id == 0) {
            return null;
        }
        var i: u32 = 0;
        while (i < self.themes_len) : (i += 1) {
            if (self.themes[i].theme_id == self.current_theme_id) {
                return &self.themes[i];
            }
        }
        return null;
    }

    // Remove theme.
    pub fn remove_theme(self: *ThemeManager, theme_id: u32) bool {
        std.debug.assert(theme_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.themes_len) : (i += 1) {
            if (self.themes[i].theme_id == theme_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        if (self.current_theme_id == theme_id) {
            self.current_theme_id = 0;
            if (self.themes_len > 1) {
                var j: u32 = 0;
                while (j < self.themes_len) : (j += 1) {
                    if (j != i and self.themes[j].active) {
                        self.current_theme_id = self.themes[j].theme_id;
                        break;
                    }
                }
            }
        }
        // Shift remaining themes left.
        while (i < self.themes_len - 1) : (i += 1) {
            self.themes[i] = self.themes[i + 1];
        }
        self.themes_len -= 1;
        return true;
    }

    // Get theme count.
    pub fn get_theme_count(self: *const ThemeManager) u32 {
        return self.themes_len;
    }
};

