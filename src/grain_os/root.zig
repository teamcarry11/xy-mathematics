//! Grain OS: Zig-native desktop environment for RISC-V
//!
//! Why: Provide a complete desktop environment running on Grain Kernel.
//! Architecture: Wayland compositor, window manager, application framework.
//! GrainStyle: grain_case, u32/u64, max 70 lines, max 100 chars, all warnings.

pub const wayland = @import("wayland/protocol.zig");
pub const compositor = @import("compositor.zig");

