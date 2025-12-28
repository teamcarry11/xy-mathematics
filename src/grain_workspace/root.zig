//! Grain Workspace: Desktop applications for Grain OS.
//!
//! Why: Provide essential desktop applications for Grain OS users.
//! Architecture: Modular applications using Grain Core services.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-164418-pst: Active implementation

pub const notes = @import("notes/app.zig");
pub const monitor = @import("monitor/app.zig");
pub const terminal_plus = @import("terminal_plus/app.zig");
pub const package_manager_ui = @import("package_manager_ui/app.zig");
pub const file_manager = @import("file_manager/app.zig");
pub const network_tools = @import("network_tools/app.zig");
pub const devtools = @import("devtools/app.zig");
pub const text_editor = @import("text_editor/app.zig");
pub const grain_style_cli = @import("grain_style_cli/main.zig");
pub const components = @import("components.zig");

