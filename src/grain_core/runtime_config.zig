//! Grain OS Runtime Configuration: riverctl-like IPC configuration system.
//!
//! Why: Allow runtime configuration of compositor via IPC channels.
//! Architecture: IPC channel-based command processing.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");
const layout_generator = @import("layout_generator.zig");
const keyboard_shortcuts = @import("keyboard_shortcuts.zig");

// Bounded: Max configuration command length.
pub const MAX_CMD_LEN: u32 = 256;

// Bounded: Max number of configuration commands.
pub const MAX_COMMANDS: u32 = 32;

// Configuration command type.
pub const ConfigCommand = enum(u8) {
    set_layout,
    set_shortcut,
    set_border_width,
    set_title_bar_height,
    get_layout,
    get_shortcuts,
    unknown,
};

// Configuration command parser.
pub const ConfigParser = struct {
    pub fn parse_command(cmd_str: []const u8) ConfigCommand {
        std.debug.assert(cmd_str.len > 0);
        std.debug.assert(cmd_str.len <= MAX_CMD_LEN);
        // Parse command string (format: "command arg1 arg2 ...").
        if (std.mem.eql(u8, cmd_str, "set-layout")) {
            return ConfigCommand.set_layout;
        } else if (std.mem.eql(u8, cmd_str, "set-shortcut")) {
            return ConfigCommand.set_shortcut;
        } else if (std.mem.eql(u8, cmd_str, "set-border-width")) {
            return ConfigCommand.set_border_width;
        } else if (std.mem.eql(u8, cmd_str, "set-title-bar-height")) {
            return ConfigCommand.set_title_bar_height;
        } else if (std.mem.eql(u8, cmd_str, "get-layout")) {
            return ConfigCommand.get_layout;
        } else if (std.mem.eql(u8, cmd_str, "get-shortcuts")) {
            return ConfigCommand.get_shortcuts;
        }
        return ConfigCommand.unknown;
    }

    pub fn parse_layout_type(layout_str: []const u8) ?layout_generator.LayoutType {
        std.debug.assert(layout_str.len > 0);
        if (std.mem.eql(u8, layout_str, "tall")) {
            return layout_generator.LayoutType.tall;
        } else if (std.mem.eql(u8, layout_str, "wide")) {
            return layout_generator.LayoutType.wide;
        } else if (std.mem.eql(u8, layout_str, "grid")) {
            return layout_generator.LayoutType.grid;
        } else if (std.mem.eql(u8, layout_str, "monocle")) {
            return layout_generator.LayoutType.monocle;
        }
        return null;
    }
};

// Runtime configuration manager.
pub const RuntimeConfig = struct {
    compositor_ptr: *compositor.Compositor,
    config_channel_id: u32,

    pub fn init(comp: *compositor.Compositor, channel_id: u32) RuntimeConfig {
        std.debug.assert(@intFromPtr(comp) != 0);
        std.debug.assert(channel_id > 0);
        return RuntimeConfig{
            .compositor_ptr = comp,
            .config_channel_id = channel_id,
        };
    }

    // Process configuration command from IPC channel.
    pub fn process_command(self: *RuntimeConfig, cmd_str: []const u8) bool {
        std.debug.assert(cmd_str.len > 0);
        std.debug.assert(cmd_str.len <= MAX_CMD_LEN);
        const cmd = ConfigParser.parse_command(cmd_str);
        switch (cmd) {
            .set_layout => {
                // Parse layout type from command (format: "set-layout tall").
                const split_result = self.split_command(cmd_str);
                if (split_result.len >= 2) {
                    if (ConfigParser.parse_layout_type(split_result.parts[1])) |layout_type| {
                        _ = self.compositor_ptr.set_layout(layout_type);
                        return true;
                    }
                }
                return false;
            },
            .get_layout => {
                // Return current layout type (via channel response).
                const current_layout = self.compositor_ptr.get_current_layout();
                _ = current_layout;
                return true;
            },
            .set_border_width => {
                // Parse border width from command (format: "set-border-width 2").
                const split_result = self.split_command(cmd_str);
                if (split_result.len >= 2) {
                    const width = self.parse_u32(split_result.parts[1]);
                    if (width) |w| {
                        self.compositor_ptr.set_border_width(w);
                        return true;
                    }
                }
                return false;
            },
            .set_title_bar_height => {
                // Parse title bar height from command (format: "set-title-bar-height 24").
                const split_result = self.split_command(cmd_str);
                if (split_result.len >= 2) {
                    const height = self.parse_u32(split_result.parts[1]);
                    if (height) |h| {
                        self.compositor_ptr.set_title_bar_height(h);
                        return true;
                    }
                }
                return false;
            },
            .set_shortcut, .get_shortcuts, .unknown => {
                return false;
            },
        }
    }

    // Split command string into parts (space-separated).
    fn split_command(self: *RuntimeConfig, cmd_str: []const u8) struct { parts: [MAX_COMMANDS][]const u8, len: u32 } {
        _ = self;
        std.debug.assert(cmd_str.len > 0);
        // Simple split: find spaces.
        var parts: [MAX_COMMANDS][]const u8 = undefined;
        var parts_len: u32 = 0;
        var start: u32 = 0;
        var i: u32 = 0;
        while (i < cmd_str.len and parts_len < MAX_COMMANDS) : (i += 1) {
            if (cmd_str[i] == ' ' or cmd_str[i] == '\t') {
                if (i > start) {
                    parts[parts_len] = cmd_str[start..i];
                    parts_len += 1;
                }
                start = i + 1;
            }
        }
        if (start < cmd_str.len and parts_len < MAX_COMMANDS) {
            parts[parts_len] = cmd_str[start..];
            parts_len += 1;
        }
        std.debug.assert(parts_len <= MAX_COMMANDS);
        return .{ .parts = parts, .len = parts_len };
    }

    // Parse u32 from string.
    fn parse_u32(self: *RuntimeConfig, str: []const u8) ?u32 {
        _ = self;
        std.debug.assert(str.len > 0);
        var result: u32 = 0;
        var i: u32 = 0;
        while (i < str.len) : (i += 1) {
            const c = str[i];
            if (c >= '0' and c <= '9') {
                result = result * 10 + (c - '0');
            } else {
                return null;
            }
        }
        return result;
    }
};

