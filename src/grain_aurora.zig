const std = @import("std");
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;
const AuroraFilter = @import("aurora_filter.zig");
const AuroraCocoa = @import("aurora_cocoa.zig");

/// GrainAurora — component-first TigerStyle UI stitching engine.
// ~<~ Glow Airbend: keep renders light.
// ~~~~ Glow Waterbend: streams of components stay deterministic.
pub const GrainAurora = struct {
    pub const Node = union(enum) {
        text: []const u8,
        column: Column,
        row: Row,
        button: Button,
    };

    pub const Column = struct {
        children: []const Node,
    };

    pub const Row = struct {
        children: []const Node,
    };

    pub const Button = struct {
        id: []const u8,
        label: []const u8,
    };

    pub const Component = fn (context: *RenderContext) RenderResult;

    pub const RenderContext = struct {
        allocator: std.mem.Allocator,
        buffer: *GrainBuffer,
        route: []const u8,
    };

    pub const RenderResult = struct {
        root: Node,
        readonly_spans: []const Span,
    };

    pub const Span = struct {
        start: usize,
        end: usize,
    };

    allocator: std.mem.Allocator,
    buffer: GrainBuffer,

    pub fn init(allocator: std.mem.Allocator, seed: []const u8) !GrainAurora {
        const buffer = try GrainBuffer.fromSlice(allocator, seed);
        return GrainAurora{
            .allocator = allocator,
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *GrainAurora) void {
        self.buffer.deinit();
        self.* = undefined;
    }

    pub fn render(
        self: *GrainAurora,
        component: Component,
        route: []const u8,
    ) !void {
        self.buffer.deinit();
        const fresh = try GrainBuffer.fromSlice(self.allocator, "");
        self.buffer = fresh;
        var ctx = RenderContext{
            .allocator = self.allocator,
            .buffer = &self.buffer,
            .route = route,
        };
        const result = component(&ctx);
        try writeNode(&self.buffer, result.root);
        for (result.readonly_spans) |span| {
            try self.buffer.markReadOnly(span.start, span.end);
        }
    }
};

fn writeNode(buffer: *GrainBuffer, node: GrainAurora.Node) !void {
    switch (node) {
        .text => |value| try buffer.append(value),
        .button => |btn| {
            try buffer.append("[");
            try buffer.append(btn.label);
            try buffer.append("]");
        },
        .row => |row| {
            try buffer.append("{ ");
            for (row.children, 0..) |child, index| {
                if (index > 0) try buffer.append(" | ");
                try writeNode(buffer, child);
            }
            try buffer.append(" }");
        },
        .column => |col| {
            for (col.children) |child| {
                try writeNode(buffer, child);
                try buffer.append("\n");
            }
        },
    }
}

test "grain aurora renders simple column" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var aurora = try GrainAurora.init(arena.allocator(), "");
    defer aurora.deinit();

    const component = struct {
        fn view(ctx: *GrainAurora.RenderContext) GrainAurora.RenderResult {
            _ = ctx;
            return GrainAurora.RenderResult{
                .root = .{ .column = .{
                    .children = &.{
                        .{ .text = "Hello" },
                        .{ .button = .{ .id = "submit", .label = "Submit" } },
                    },
                } },
                .readonly_spans = &.{
                    .{ .start = 0, .end = 5 },
                },
            };
        }
    }.view;

    try aurora.render(component, "/hello");
    const rendered = aurora.buffer.textSlice();
    try std.testing.expect(std.mem.startsWith(u8, rendered, "Hello\n[Submit]"));
}

pub fn demo() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app = try AuroraCocoa.App.init(gpa.allocator(), .{
        .title = "Aurora Sandbox",
        .menu = &.{ .{ .title = "Aurora" }, .{ .title = "File" }, .{ .title = "View ▸ Flux ▸ Darkroom" } },
    });
    defer app.deinit();
    try app.present();

    var pixels = [_]u8{ 180, 160, 150, 255, 200, 120, 100, 255 };
    AuroraFilter.apply(.darkroom, &pixels);
    std.debug.print("Applied darkroom filter to {d} pixels\\n", .{pixels.len / 4});
}
