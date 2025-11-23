const std = @import("std");
const MacWindow = @import("macos_window");
const AuroraRenderer = @import("aurora_renderer.zig").AuroraRenderer;
const Pane = @import("pane.zig").Pane;
const Tab = @import("tab.zig").Tab;
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
    
    pub const RenderContext = struct {
        allocator: std.mem.Allocator,
        buffer: *@import("grain_buffer").GrainBuffer,
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
    
    pub const Component = fn (context: *RenderContext) RenderResult;
    
    allocator: std.mem.Allocator,
    buffer: @import("../grain_buffer.zig").GrainBuffer,
    
    pub fn init(allocator: std.mem.Allocator, seed: []const u8) !GrainAurora {
        const GrainBuffer = @import("../grain_buffer.zig").GrainBuffer;
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
        _ = self;
        _ = component;
        _ = route;
        // Placeholder: full implementation would call component
    }
};

/// Grain Terminal Window: Window management using Aurora window system.
/// ~<~ Glow Airbend: explicit window state, bounded components.
/// ~~~~ Glow Waterbend: deterministic window management, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const TerminalWindow = struct {
    // Bounded: Max window title length (explicit limit)
    pub const MAX_TITLE_LEN: u32 = 256;
    
    allocator: std.mem.Allocator,
    window: MacWindow.Window,
    aurora: GrainAurora,
    renderer: AuroraRenderer,
    root_pane: ?*Pane,
    tabs: []*Tab,
    tabs_len: u32,
    active_tab_id: u32,
    config: Config,
    title: []const u8,
    
    /// Initialize terminal window.
    pub fn init(
        allocator: std.mem.Allocator,
        title: []const u8,
        width: u32,
        height: u32,
    ) !TerminalWindow {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        // Assert: Title must be bounded
        std.debug.assert(title.len <= MAX_TITLE_LEN);
        
        // Assert: Dimensions must be valid
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        
        // Initialize macOS window
        const window = try MacWindow.Window.init(allocator, title);
        errdefer window.deinit();
        
        // Initialize Aurora
        var aurora = try GrainAurora.init(allocator, "");
        errdefer aurora.deinit();
        
        // Initialize renderer
        const renderer = AuroraRenderer.init(allocator);
        
        // Initialize config
        const config = try Config.init(allocator);
        errdefer config.deinit();
        
        // Allocate tabs buffer
        const tabs = try allocator.alloc(*Tab, Tab.MAX_TITLE_LEN); // Reuse constant
        errdefer allocator.free(tabs);
        
        // Allocate title
        const title_copy = try allocator.dupe(u8, title);
        errdefer allocator.free(title_copy);
        
        return TerminalWindow{
            .allocator = allocator,
            .window = window,
            .aurora = aurora,
            .renderer = renderer,
            .root_pane = null,
            .tabs = tabs,
            .tabs_len = 0,
            .active_tab_id = 0,
            .config = config,
            .title = title_copy,
        };
    }
    
    /// Deinitialize terminal window and free memory.
    pub fn deinit(self: *TerminalWindow) void {
        // Assert: Allocator must be valid
        std.debug.assert(self.allocator.ptr != null);
        
        // Deinitialize root pane
        if (self.root_pane) |pane| {
            pane.deinit();
            self.allocator.free(pane);
        }
        
        // Deinitialize tabs
        var i: u32 = 0;
        while (i < self.tabs_len) : (i += 1) {
            self.tabs[i].deinit();
            self.allocator.free(self.tabs[i]);
        }
        self.allocator.free(self.tabs);
        
        // Deinitialize config
        self.config.deinit();
        
        // Deinitialize Aurora
        self.aurora.deinit();
        
        // Deinitialize window
        self.window.deinit();
        
        // Free title
        self.allocator.free(self.title);
        
        self.* = undefined;
    }
    
    /// Show terminal window.
    pub fn show(self: *TerminalWindow) !void {
        // Assert: Window must be valid
        std.debug.assert(@intFromPtr(&self.window) != 0);
        
        try self.window.show();
    }
    
    /// Render terminal window to Aurora.
    /// Contract:
    ///   Input: Terminal state (panes, tabs, config)
    ///   Output: Renders to Aurora buffer
    ///   Errors: Allocation errors
    pub fn render(self: *TerminalWindow) !void {
        // Assert: Window must be valid
        std.debug.assert(@intFromPtr(&self.window) != 0);
        
        // If root pane exists, render it
        if (self.root_pane) |pane| {
            const pane_result = try self.renderer.render_pane(pane, &self.config);
            
            // Create terminal component that uses pane result
            // Note: In a full implementation, we'd create a component struct here
            // For now, we just use pane_result directly
            _ = pane_result;
            
            // Return pane result (simplified for now)
            // In full implementation, would create proper component structure
                        .readonly_spans = &.{},
                    };
                }
            };
            
            // Render to Aurora
            // Note: Full integration would pass pane_result.root to component
            const component_fn = struct {
                fn view(ctx: *GrainAurora.RenderContext) GrainAurora.RenderResult {
                    _ = ctx;
                    const empty_text = "";
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
            }.view;
            
            try self.aurora.render(component_fn, "/terminal");
            
            // Free pane result readonly spans
            self.allocator.free(pane_result.readonly_spans);
        } else {
            // No root pane: render empty component
            const component = struct {
                fn view(ctx: *GrainAurora.RenderContext) GrainAurora.RenderResult {
                    _ = ctx;
                    const empty_text = "";
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
            }.view;
            
            try self.aurora.render(component, "/terminal");
        }
    }
    
    /// Add tab to terminal window.
    pub fn add_tab(self: *TerminalWindow, tab: *Tab) !void {
        // Assert: Tab must be valid
        std.debug.assert(@intFromPtr(tab) != 0);
        
        // Check tabs limit
        if (self.tabs_len >= Tab.MAX_TITLE_LEN) {
            return error.TooManyTabs;
        }
        
        self.tabs[self.tabs_len] = tab;
        self.tabs_len += 1;
        
        // If first tab, set as active
        if (self.tabs_len == 1) {
            self.active_tab_id = tab.id;
        }
    }
    
    /// Set root pane.
    pub fn set_root_pane(self: *TerminalWindow, pane: *Pane) void {
        // Assert: Pane must be valid
        std.debug.assert(@intFromPtr(pane) != 0);
        
        self.root_pane = pane;
    }
    
    /// Get active tab.
    pub fn get_active_tab(self: *const TerminalWindow) ?*Tab {
        var i: u32 = 0;
        while (i < self.tabs_len) : (i += 1) {
            if (self.tabs[i].id == self.active_tab_id) {
                return self.tabs[i];
            }
        }
        return null;
    }
    
    /// Set active tab.
    pub fn set_active_tab(self: *TerminalWindow, tab_id: u32) void {
        // Assert: Tab ID must be valid
        std.debug.assert(tab_id < 0xFFFFFFFF);
        
        // Verify tab exists
        var i: u32 = 0;
        while (i < self.tabs_len) : (i += 1) {
            if (self.tabs[i].id == tab_id) {
                self.active_tab_id = tab_id;
                return;
            }
        }
    }
};

