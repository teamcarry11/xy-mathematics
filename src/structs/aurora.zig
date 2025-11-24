/// Aurora UI structs: component tree, rendering, and editor definitions.
/// All Aurora-related struct definitions in one place.

/// Text renderer: converts GrainBuffer text into RGBA pixels.
pub const TextRenderer = struct {
    width: u32,
    height: u32,
    font_width: u32 = 8,
    font_height: u32 = 8,
};

/// Flux filter state: color filter modes for Aurora.
pub const FluxState = struct {
    mode: enum { none, darkroom },
};

/// Aurora component node: union of text, column, row, button.
pub const AuroraNode = union(enum) {
    text: []const u8,
    column: Column,
    row: Row,
    button: Button,
};

/// Column layout: vertical stack of children.
pub const Column = struct {
    children: []const AuroraNode,
};

/// Row layout: horizontal stack of children.
pub const Row = struct {
    children: []const AuroraNode,
};

/// Button component: interactive element with id and label.
pub const Button = struct {
    id: []const u8,
    label: []const u8,
};

/// Render context: allocator, buffer, and route for component rendering.
pub const RenderContext = struct {
    allocator: std.mem.Allocator,
    buffer: *GrainBuffer,
    route: []const u8,
};

/// Render result: root node, readonly spans, and ghost text spans.
pub const RenderResult = struct {
    root: AuroraNode,
    readonly_spans: []const Span,
    ghost_spans: []const Span = &.{}, // Ghost text spans (AI completions)
};

/// Span: start and end indices for readonly regions.
pub const Span = struct {
    start: usize,
    end: usize,
};

const std = @import("std");
const GrainBuffer = @import("../grain_buffer.zig").GrainBuffer;

