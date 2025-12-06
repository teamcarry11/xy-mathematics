//! Grain Core: Zig-native desktop environment for RISC-V
//!
//! Why: Provide a complete desktop environment running on Grain Kernel.
//! Architecture: Wayland compositor, window manager, application framework.
//! GrainStyle: grain_case, u32/u64, max 70 lines, max 100 chars, all warnings.

pub const wayland = @import("wayland/protocol.zig");
pub const compositor = @import("compositor.zig");
pub const tiling = @import("tiling.zig");
pub const layout = @import("layout.zig");
pub const layout_generator = @import("layout_generator.zig");
pub const framebuffer_renderer = @import("framebuffer_renderer.zig");
pub const input_handler = @import("input_handler.zig");
pub const workspace = @import("workspace.zig");
pub const window_actions = @import("window_actions.zig");
pub const keyboard_shortcuts = @import("keyboard_shortcuts.zig");
pub const runtime_config = @import("runtime_config.zig");
pub const desktop_shell = @import("desktop_shell.zig");
pub const application = @import("application.zig");
pub const window_snapping = @import("window_snapping.zig");
pub const window_switching = @import("window_switching.zig");
pub const window_state = @import("window_state.zig");
pub const window_preview = @import("window_preview.zig");
pub const window_visual = @import("window_visual.zig");
pub const window_stacking = @import("window_stacking.zig");
pub const window_opacity = @import("window_opacity.zig");
pub const window_animation = @import("window_animation.zig");
pub const window_decorations = @import("window_decorations.zig");
pub const window_constraints = @import("window_constraints.zig");
pub const window_grouping = @import("window_grouping.zig");
pub const window_focus = @import("window_focus.zig");
pub const window_effects = @import("window_effects.zig");
pub const window_drag_drop = @import("window_drag_drop.zig");
pub const tiling_config = @import("tiling_config.zig");
pub const window_rules = @import("window_rules.zig");
pub const window_events = @import("window_events.zig");
pub const window_session = @import("window_session.zig");
pub const lock_screen = @import("lock_screen.zig");
pub const font_renderer = @import("font_renderer.zig");
pub const notification = @import("notification.zig");
pub const clipboard = @import("clipboard.zig");
pub const app_launcher = @import("app_launcher.zig");
pub const system_tray = @import("system_tray.zig");
pub const power_management = @import("power_management.zig");
pub const display_management = @import("display_management.zig");
pub const settings_manager = @import("settings_manager.zig");
pub const theme_manager = @import("theme_manager.zig");
pub const screen_capture = @import("screen_capture.zig");
pub const file_manager = @import("file_manager.zig");
pub const resource_monitor = @import("resource_monitor.zig");
pub const audio_manager = @import("audio_manager.zig");
pub const network_manager = @import("network_manager.zig");
pub const process_manager = @import("process_manager.zig");
pub const system_logger = @import("system_logger.zig");
pub const time_manager = @import("time_manager.zig");
pub const security_manager = @import("security_manager.zig");
pub const service_manager = @import("service_manager.zig");
pub const backup_manager = @import("backup_manager.zig");
pub const update_manager = @import("update_manager.zig");
pub const package_manager = @import("package_manager.zig");
pub const health_monitor = @import("health_monitor.zig");
pub const process_supervision = @import("process_supervision.zig");
pub const system_metrics = @import("system_metrics.zig");
pub const system_diagnostics = @import("system_diagnostics.zig");
pub const api_server = @import("api_server.zig");
pub const json_helpers = @import("json_helpers.zig");
pub const middleware = @import("middleware.zig");
pub const connection_manager = @import("connection_manager.zig");
pub const api_server_network = @import("api_server_network.zig");
pub const auth_service = @import("auth_service.zig");
pub const network_stack = @import("network_stack.zig");
pub const websocket = @import("websocket.zig");
pub const websocket_handshake = @import("websocket_handshake.zig");

