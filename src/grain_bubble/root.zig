//! Grain Bubble: Visual design tool for Grain OS.
//!
//! Why: Native visual design tool with SLC philosophy.
//! Architecture: Native desktop app with Grain OS integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-19-191440-pst: Grain Bubble Agent

pub const canvas = @import("canvas.zig");
pub const bubble_renderer = @import("bubble_renderer.zig");
pub const canvas_renderer = @import("canvas_renderer.zig");
pub const canvas_input = @import("canvas_input.zig");
pub const export_pdf = @import("export_pdf.zig");
pub const export_html = @import("export_html.zig");
pub const export_framework = @import("export_framework.zig");
pub const export_slc = @import("export_slc.zig");
pub const undo_redo = @import("undo_redo.zig");
pub const component = @import("component.zig");
pub const silo_integration = @import("silo_integration.zig");
pub const court_integration = @import("court_integration.zig");
pub const dag_integration = @import("dag_integration.zig");
pub const export_optimize = @import("export_optimize.zig");
pub const export_preview = @import("export_preview.zig");

