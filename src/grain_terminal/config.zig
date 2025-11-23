const std = @import("std");

/// Grain Terminal Configuration: Theme, font, and settings management.
/// ~<~ Glow Airbend: explicit configuration state, bounded settings.
/// ~~~~ Glow Waterbend: deterministic configuration, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Config = struct {
    // Bounded: Max configuration key length (explicit limit)
    pub const MAX_KEY_LEN: u32 = 256;

    // Bounded: Max configuration value length (explicit limit)
    pub const MAX_VALUE_LEN: u32 = 4_096;

    // Bounded: Max configuration entries (explicit limit)
    pub const MAX_CONFIG_ENTRIES: u32 = 1_024;

    /// Theme enumeration.
    pub const Theme = enum(u8) {
        dark, // Dark theme (default)
        light, // Light theme
        solarized_dark, // Solarized dark
        solarized_light, // Solarized light
        gruvbox_dark, // Gruvbox dark
        gruvbox_light, // Gruvbox light
    };

    /// Font size enumeration.
    pub const FontSize = enum(u8) {
        small, // 8pt
        medium, // 12pt (default)
        large, // 16pt
        xlarge, // 20pt
    };

    /// Configuration entry (key-value pair).
    pub const ConfigEntry = struct {
        key: []const u8, // Configuration key (bounded)
        key_len: u32,
        value: []const u8, // Configuration value (bounded)
        value_len: u32,
    };

    /// Terminal configuration state.
    theme: Theme, // Current theme
    font_size: FontSize, // Current font size
    font_family: []const u8, // Font family name (bounded)
    font_family_len: u32,
    show_tabs: bool, // Show tab bar
    show_scrollbar: bool, // Show scrollbar
    scrollback_lines: u32, // Number of scrollback lines
    cursor_blink: bool, // Cursor blinking
    cursor_shape: CursorShape, // Cursor shape
    entries: []ConfigEntry, // Configuration entries (bounded)
    entries_len: u32, // Number of entries

    /// Cursor shape enumeration.
    pub const CursorShape = enum(u8) {
        block, // Block cursor (default)
        underline, // Underline cursor
        bar, // Bar cursor
    };

    /// Initialize default configuration.
    pub fn init(allocator: std.mem.Allocator) !Config {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        // Pre-allocate entries buffer
        const entries = try allocator.alloc(ConfigEntry, MAX_CONFIG_ENTRIES);
        errdefer allocator.free(entries);

        // Default font family
        const default_font = try allocator.dupe(u8, "monospace");
        errdefer allocator.free(default_font);

        return Config{
            .theme = .dark,
            .font_size = .medium,
            .font_family = default_font,
            .font_family_len = @as(u32, @intCast(default_font.len)),
            .show_tabs = true,
            .show_scrollbar = true,
            .scrollback_lines = 10_000,
            .cursor_blink = true,
            .cursor_shape = .block,
            .entries = entries,
            .entries_len = 0,
        };
    }

    /// Deinitialize configuration and free memory.
    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        // Free all entry keys and values
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].key_len > 0) {
                allocator.free(self.entries[i].key);
            }
            if (self.entries[i].value_len > 0) {
                allocator.free(self.entries[i].value);
            }
        }

        // Free font family
        if (self.font_family_len > 0) {
            allocator.free(self.font_family);
        }

        // Free entries buffer
        allocator.free(self.entries);

        self.* = undefined;
    }

    /// Set configuration value.
    pub fn set(self: *Config, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        // Assert: Key and value must be bounded
        std.debug.assert(key.len <= MAX_KEY_LEN);
        std.debug.assert(value.len <= MAX_VALUE_LEN);

        // Check if entry already exists
        if (self.find_entry(key)) |entry| {
            // Update existing entry
            allocator.free(entry.value);
            const new_value = try allocator.dupe(u8, value);
            entry.value = new_value;
            entry.value_len = @as(u32, @intCast(new_value.len));
            return;
        }

        // Check entry limit
        if (self.entries_len >= MAX_CONFIG_ENTRIES) {
            return error.TooManyEntries;
        }

        // Allocate key and value
        const key_copy = try allocator.dupe(u8, key);
        errdefer allocator.free(key_copy);
        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);

        // Store entry
        self.entries[self.entries_len] = ConfigEntry{
            .key = key_copy,
            .key_len = @as(u32, @intCast(key_copy.len)),
            .value = value_copy,
            .value_len = @as(u32, @intCast(value_copy.len)),
        };
        self.entries_len += 1;
    }

    /// Get configuration value.
    pub fn get(self: *const Config, key: []const u8) ?[]const u8 {
        if (self.find_entry(key)) |entry| {
            return entry.value;
        }
        return null;
    }

    /// Find configuration entry by key.
    fn find_entry(self: *const Config, key: []const u8) ?*ConfigEntry {
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (std.mem.eql(u8, self.entries[i].key, key)) {
                return &self.entries[i];
            }
        }
        return null;
    }

    /// Set theme.
    pub fn set_theme(self: *Config, theme: Theme) void {
        self.theme = theme;
    }

    /// Get theme.
    pub fn get_theme(self: *const Config) Theme {
        return self.theme;
    }

    /// Set font size.
    pub fn set_font_size(self: *Config, font_size: FontSize) void {
        self.font_size = font_size;
    }

    /// Get font size.
    pub fn get_font_size(self: *const Config) FontSize {
        return self.font_size;
    }

    /// Get font size in points.
    pub fn get_font_size_points(self: *const Config) u32 {
        return switch (self.font_size) {
            .small => 8,
            .medium => 12,
            .large => 16,
            .xlarge => 20,
        };
    }
};

