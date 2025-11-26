//! Grain OS: Zig-native desktop environment for RISC-V
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

