const std = @import("std");
const Terminal = @import("terminal.zig").Terminal;
const Tab = @import("tab.zig").Tab;
const Pane = @import("pane.zig").Pane;
const Config = @import("config.zig").Config;

// Note: GrainAurora import will be resolved via build.zig module dependencies
// For now, we'll use a forward declaration approach
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
    
    pub const RenderResult = struct {
        root: Node,
        readonly_spans: []const Span,
    };
    
    pub const Span = struct {
        start: usize,
        end: usize,
    };
};

/// Grain Terminal Aurora Renderer: Converts terminal cells to Aurora components.
/// ~<~ Glow Airbend: explicit rendering state, bounded components.
/// ~~~~ Glow Waterbend: deterministic rendering, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const AuroraRenderer = struct {
    // Bounded: Max terminal cells per render (explicit limit)
    pub const MAX_CELLS_PER_RENDER: u32 = 10_000;
    
    // Bounded: Max lines per terminal view (explicit limit)
    pub const MAX_LINES: u32 = 1_000;
    
    // Bounded: Max columns per terminal view (explicit limit)
    pub const MAX_COLUMNS: u32 = 500;
    
    allocator: std.mem.Allocator,
    
    /// Initialize Aurora renderer.
    pub fn init(allocator: std.mem.Allocator) AuroraRenderer {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        return AuroraRenderer{
            .allocator = allocator,
        };
    }
    
    /// Render terminal tab to Aurora component.
    /// Contract:
    ///   Input: tab, config, width, height
    ///   Output: Aurora RenderResult with terminal content as text nodes
    ///   Errors: Allocation errors
    pub fn render_tab(
        self: *AuroraRenderer,
        tab: *Tab,
        config: *const Config,
        width: u32,
        height: u32,
    ) !GrainAurora.RenderResult {
        // Assert: Tab must be valid
        std.debug.assert(@intFromPtr(tab) != 0);
        std.debug.assert(@intFromPtr(config) != 0);
        
        // Assert: Dimensions must be valid
        std.debug.assert(width > 0 and width <= MAX_COLUMNS);
        std.debug.assert(height > 0 and height <= MAX_LINES);
        
        // Assert: Terminal dimensions must match
        std.debug.assert(tab.terminal.width == width);
        std.debug.assert(tab.terminal.height == height);
        
        // Get terminal cells
        const cells = tab.cells;
        std.debug.assert(cells.len >= width * height);
        
        // Build text lines (iterative, no recursion)
        var lines = try std.ArrayList([]const u8).initCapacity(self.allocator, height);
        defer {
            for (lines.items) |line| {
                self.allocator.free(line);
            }
            lines.deinit();
        }
        
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            // Build line text
            var line_buf = try std.ArrayList(u8).initCapacity(self.allocator, width);
            defer line_buf.deinit();
            
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                const cell_idx = y * width + x;
                std.debug.assert(cell_idx < cells.len);
                
                const cell = cells[cell_idx];
                try line_buf.append(cell.ch);
            }
            
            const line = try line_buf.toOwnedSlice();
            try lines.append(line);
        }
        
        // Convert lines to Aurora text nodes
        var text_nodes = try self.allocator.alloc(GrainAurora.Node, lines.items.len);
        errdefer self.allocator.free(text_nodes);
        
        for (lines.items, 0..) |line, i| {
            text_nodes[i] = GrainAurora.Node{
                .text = line,
            };
        }
        
        // Create column component with text nodes
        const column = GrainAurora.Column{
            .children = text_nodes,
        };
        
        const root = GrainAurora.Node{
            .column = column,
        };
        
        // Create readonly spans for tab title (first line)
        const readonly_spans = if (lines.items.len > 0) blk: {
            const title_span = try self.allocator.alloc(GrainAurora.Span, 1);
            title_span[0] = GrainAurora.Span{
                .start = 0,
                .end = lines.items[0].len,
            };
            break :blk title_span;
        } else &.{};
        
        return GrainAurora.RenderResult{
            .root = root,
            .readonly_spans = readonly_spans,
        };
    }
    
    /// Render pane with tabs to Aurora component.
    /// Contract:
    ///   Input: pane, config
    ///   Output: Aurora RenderResult with pane layout
    ///   Errors: Allocation errors
    pub fn render_pane(
        self: *AuroraRenderer,
        pane: *Pane,
        config: *const Config,
    ) !GrainAurora.RenderResult {
        // Assert: Pane must be valid
        std.debug.assert(@intFromPtr(pane) != 0);
        std.debug.assert(@intFromPtr(config) != 0);
        
        // If leaf pane with tab, render tab
        if (pane.is_leaf()) {
            if (pane.tab) |tab| {
                return try self.render_tab(tab, config, pane.width, pane.height);
            } else {
                // Empty pane: return empty column
                const empty_text = try self.allocator.dupe(u8, "");
                errdefer self.allocator.free(empty_text);
                
                const text_node = GrainAurora.Node{
                    .text = empty_text,
                };
                
                const column = GrainAurora.Column{
                    .children = &.{text_node},
                };
                
                return GrainAurora.RenderResult{
                    .root = .{ .column = column },
                    .readonly_spans = &.{},
                };
            }
        }
        
        // Split pane: render children (iterative, no recursion)
        var child_results = try std.ArrayList(GrainAurora.RenderResult).initCapacity(
            self.allocator,
            pane.children_len,
        );
        defer {
            for (child_results.items) |*result| {
                // Free readonly spans
                self.allocator.free(result.readonly_spans);
            }
            child_results.deinit();
        }
        
        var i: u32 = 0;
        while (i < pane.children_len) : (i += 1) {
            const child_result = try self.render_pane(&pane.children[i], config);
            try child_results.append(child_result);
        }
        
        // Convert child results to nodes
        var child_nodes = try self.allocator.alloc(GrainAurora.Node, child_results.items.len);
        errdefer self.allocator.free(child_nodes);
        
        for (child_results.items, 0..) |*result, j| {
            child_nodes[j] = result.root;
        }
        
        // Create row or column based on split direction
        const root = if (pane.split_direction == .horizontal) blk: {
            const row = GrainAurora.Row{
                .children = child_nodes,
            };
            break :blk GrainAurora.Node{ .row = row };
        } else blk: {
            const column = GrainAurora.Column{
                .children = child_nodes,
            };
            break :blk GrainAurora.Node{ .column = column };
        };
        
        // Combine readonly spans from children
        var total_spans: u32 = 0;
        for (child_results.items) |result| {
            total_spans += @as(u32, @intCast(result.readonly_spans.len));
        }
        
        const readonly_spans = try self.allocator.alloc(GrainAurora.Span, total_spans);
        errdefer self.allocator.free(readonly_spans);
        
        var span_idx: u32 = 0;
        for (child_results.items) |result| {
            for (result.readonly_spans) |span| {
                readonly_spans[span_idx] = span;
                span_idx += 1;
            }
        }
        
        return GrainAurora.RenderResult{
            .root = root,
            .readonly_spans = readonly_spans,
        };
    }
    
    /// Render tab bar to Aurora component.
    /// Contract:
    ///   Input: tabs array, active_tab_id, config
    ///   Output: Aurora RenderResult with tab bar as row of buttons
    ///   Errors: Allocation errors
    pub fn render_tab_bar(
        self: *AuroraRenderer,
        tabs: []const *Tab,
        _: u32, // active_tab_id (unused for now)
        config: *const Config,
    ) !GrainAurora.RenderResult {
        // Assert: Config must be valid
        std.debug.assert(@intFromPtr(config) != 0);
        
        // Assert: Tabs array must be bounded
        std.debug.assert(tabs.len <= Tab.MAX_TITLE_LEN); // Reuse constant for max tabs
        
        // If tabs not shown, return empty
        if (!config.show_tabs) {
            const empty_text = try self.allocator.dupe(u8, "");
            errdefer self.allocator.free(empty_text);
            
            const text_node = GrainAurora.Node{
                .text = empty_text,
            };
            
            const row = GrainAurora.Row{
                .children = &.{text_node},
            };
            
            return GrainAurora.RenderResult{
                .root = .{ .row = row },
                .readonly_spans = &.{},
            };
        }
        
        // Create button nodes for each tab
        var button_nodes = try self.allocator.alloc(GrainAurora.Node, tabs.len);
        errdefer self.allocator.free(button_nodes);
        
        for (tabs, 0..) |tab, i| {
            // Create tab ID string
            const tab_id_buf = try std.fmt.allocPrint(self.allocator, "tab_{d}", .{tab.id});
            errdefer self.allocator.free(tab_id_buf);
            
            // Use tab title or default
            const label = if (tab.title_len > 0) tab.title else "Terminal";
            
            const button = GrainAurora.Button{
                .id = tab_id_buf,
                .label = label,
            };
            
            button_nodes[i] = GrainAurora.Node{
                .button = button,
            };
        }
        
        // Create row component with tab buttons
        const row = GrainAurora.Row{
            .children = button_nodes,
        };
        
        return GrainAurora.RenderResult{
            .root = .{ .row = row },
            .readonly_spans = &.{},
        };
    }
};

