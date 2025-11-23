const std = @import("std");
const Terminal = @import("terminal.zig").Terminal;

/// Grain Terminal Tab: Represents a single terminal tab.
/// ~<~ Glow Airbend: explicit tab state, bounded terminal instances.
/// ~~~~ Glow Waterbend: deterministic tab management, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Tab = struct {
    // Bounded: Max tab title length (explicit limit)
    pub const MAX_TITLE_LEN: u32 = 256;

    /// Tab state enumeration.
    pub const TabState = enum(u8) {
        active, // Active tab
        inactive, // Inactive tab
        closed, // Closed tab (for cleanup)
    };

    /// Tab structure.
    id: u32, // Tab ID (unique identifier)
    title: []const u8, // Tab title (bounded)
    title_len: u32,
    state: TabState, // Tab state
    terminal: Terminal, // Terminal instance
    cells: []Terminal.Cell, // Terminal cells buffer
    allocator: std.mem.Allocator,

    /// Initialize tab with terminal dimensions.
    pub fn init(allocator: std.mem.Allocator, id: u32, width: u32, height: u32, title: []const u8) !Tab {
        // Assert: Allocator must be valid
        // Assert: Allocator must be valid (allocator is used below)

        // Assert: Dimensions must be valid
        std.debug.assert(width > 0 and width <= Terminal.MAX_WIDTH);
        std.debug.assert(height > 0 and height <= Terminal.MAX_HEIGHT);

        // Assert: Title must be bounded
        std.debug.assert(title.len <= MAX_TITLE_LEN);

        // Initialize terminal
        const terminal = Terminal.init(width, height);

        // Allocate cells buffer
        const cells = try allocator.alloc(Terminal.Cell, width * height);
        errdefer allocator.free(cells);

        // Initialize cells to spaces
        var i: u32 = 0;
        while (i < width * height) : (i += 1) {
            cells[i] = Terminal.Cell{
                .ch = ' ',
                .attrs = Terminal.CellAttributes{
                    .fg_color = 7,
                    .bg_color = 0,
                    .bold = false,
                    .italic = false,
                    .underline = false,
                    .blink = false,
                    .reverse = false,
                },
            };
        }

        // Allocate title
        const title_copy = try allocator.dupe(u8, title);
        errdefer allocator.free(title_copy);

        return Tab{
            .id = id,
            .title = title_copy,
            .title_len = @as(u32, @intCast(title_copy.len)),
            .state = .inactive,
            .terminal = terminal,
            .cells = cells,
            .allocator = allocator,
        };
    }

    /// Deinitialize tab and free memory.
    pub fn deinit(self: *Tab) void {
        // Assert: Allocator must be valid
        std.debug.assert(self.allocator.ptr != null);

        // Free title
        if (self.title_len > 0) {
            self.allocator.free(self.title);
        }

        // Free cells buffer
        self.allocator.free(self.cells);

        self.* = undefined;
    }

    /// Process input character in tab's terminal.
    pub fn process_char(self: *Tab, ch: u8) void {
        self.terminal.process_char(ch, self.cells);
    }

    /// Clear tab's terminal.
    pub fn clear(self: *Tab) void {
        self.terminal.clear(self.cells);
    }

    /// Get terminal cells.
    pub fn get_cells(self: *const Tab) []const Terminal.Cell {
        return self.cells;
    }

    /// Get terminal instance.
    pub fn get_terminal(self: *Tab) *Terminal {
        return &self.terminal;
    }

    /// Set tab title.
    pub fn set_title(self: *Tab, title: []const u8) !void {
        // Assert: Title must be bounded
        std.debug.assert(title.len <= MAX_TITLE_LEN);

        // Free old title
        if (self.title_len > 0) {
            self.allocator.free(self.title);
        }

        // Allocate new title
        const title_copy = try self.allocator.dupe(u8, title);
        self.title = title_copy;
        self.title_len = @as(u32, @intCast(title_copy.len));
    }

    /// Set tab state.
    pub fn set_state(self: *Tab, state: TabState) void {
        self.state = state;
    }

    /// Get tab state.
    pub fn get_state(self: *const Tab) TabState {
        return self.state;
    }
};

