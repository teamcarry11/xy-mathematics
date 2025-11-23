// Grain Terminal root module
// Re-exports all Grain Terminal components

pub const Terminal = @import("terminal.zig").Terminal;
pub const Renderer = @import("renderer.zig").Renderer;
pub const Config = @import("config.zig").Config;
pub const Tab = @import("tab.zig").Tab;
pub const Pane = @import("pane.zig").Pane;

