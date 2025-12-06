//! Grain Bubble: Visual design tool for Grain OS.
//!
//! Why: Figma/Framer-inspired design tool with SLC philosophy.
//! Architecture: Native desktop app with Grain OS integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-05-143400-pst: Grain Bubble Agent

pub const canvas = @import("canvas.zig");
pub const bubble_renderer = @import("bubble_renderer.zig");
pub const export_pdf = @import("export_pdf.zig");

