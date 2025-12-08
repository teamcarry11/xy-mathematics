// Grain Terminal root module
// Re-exports all Grain Terminal components

pub const Terminal = @import("terminal.zig").Terminal;
pub const Renderer = @import("renderer.zig").Renderer;
pub const Config = @import("config.zig").Config;
pub const Tab = @import("tab.zig").Tab;
pub const Pane = @import("pane.zig").Pane;
pub const Session = @import("session.zig").Session;
pub const GrainscriptIntegration = @import("grainscript_integration.zig").GrainscriptIntegration;
pub const Plugin = @import("plugin.zig").Plugin;
pub const AuroraRenderer = @import("aurora_renderer.zig").AuroraRenderer;
pub const TerminalWindow = @import("window.zig").TerminalWindow;

