const std = @import("std");

/// Method folding: fold function/method bodies by default, show signatures.
/// ~<~ Glow Airbend: explicit fold boundaries, bounded regions.
/// ~~~~ Glow Waterbend: folds flow naturally from code structure.
pub const Folding = struct {
    allocator: std.mem.Allocator,
    folds: std.ArrayListUnmanaged(Fold),
    
    // Bounded: Max 1000 foldable regions
    pub const MAX_FOLDS: u32 = 1000;
    
    pub const Fold = struct {
        start_line: u32, // Line where function signature starts
        end_line: u32, // Line where function body ends
        body_start: u32, // Line where body starts (after signature)
        body_end: u32, // Line where body ends
        folded: bool, // Whether this fold is currently collapsed
    };
    
    pub fn init(allocator: std.mem.Allocator) Folding {
        return Folding{
            .allocator = allocator,
            .folds = .{},
        };
    }
    
    pub fn deinit(self: *Folding) void {
        self.folds.deinit(self.allocator);
        self.* = undefined;
    }
    
    /// Parse code and identify foldable regions (functions, methods, structs).
    /// Uses simple regex-based parsing for Zig code.
    pub fn parse(self: *Folding, text: []const u8) !void {
        // Assert: Text must be non-empty
        std.debug.assert(text.len > 0);
        
        // Clear existing folds
        self.folds.clearRetainingCapacity();
        
        // Split into lines
        var lines = std.mem.splitSequence(u8, text, "\n");
        var line_num: u32 = 0;
        var current_fold: ?Fold = null;
        
        while (lines.next()) |line| : (line_num += 1) {
            const trimmed = std.mem.trim(u8, line, " \t");
            
            // Check for function signature (Zig: "pub fn", "fn", "const fn")
            if (std.mem.indexOf(u8, trimmed, "fn ") != null or
                std.mem.indexOf(u8, trimmed, "pub fn ") != null or
                std.mem.indexOf(u8, trimmed, "const fn ") != null)
            {
                // If we have a current fold, close it
                if (current_fold) |*fold| {
                    fold.end_line = line_num - 1;
                    fold.body_end = line_num - 1;
                    try self.folds.append(self.allocator, fold.*);
                }
                
                // Start new fold
                current_fold = Fold{
                    .start_line = line_num,
                    .end_line = line_num,
                    .body_start = line_num + 1, // Assume body starts next line
                    .body_end = line_num + 1,
                    .folded = true, // Fold by default
                };
            }
            
            // Check for struct/enum/union (also foldable)
            if (std.mem.indexOf(u8, trimmed, "pub const ") != null and
                (std.mem.indexOf(u8, trimmed, "= struct") != null or
                 std.mem.indexOf(u8, trimmed, "= enum") != null or
                 std.mem.indexOf(u8, trimmed, "= union") != null))
            {
                if (current_fold) |*fold| {
                    fold.end_line = line_num - 1;
                    fold.body_end = line_num - 1;
                    try self.folds.append(self.allocator, fold.*);
                }
                
                current_fold = Fold{
                    .start_line = line_num,
                    .end_line = line_num,
                    .body_start = line_num + 1,
                    .body_end = line_num + 1,
                    .folded = true,
                };
            }
            
            // Check for closing brace (end of function/struct)
            if (std.mem.eql(u8, trimmed, "}") or std.mem.eql(u8, trimmed, "};")) {
                if (current_fold) |*fold| {
                    fold.end_line = line_num;
                    fold.body_end = line_num;
                    try self.folds.append(self.allocator, fold.*);
                    current_fold = null;
                }
            }
            
            // Assert: Folds must be within bounds
            std.debug.assert(self.folds.items.len <= MAX_FOLDS);
        }
        
        // Close any remaining fold
        if (current_fold) |*fold| {
            fold.end_line = line_num;
            fold.body_end = line_num;
            try self.folds.append(self.allocator, fold.*);
        }
    }
    
    /// Toggle fold at given line (expand if folded, collapse if expanded).
    pub fn toggleFold(self: *Folding, line: u32) void {
        for (self.folds.items) |*fold| {
            if (fold.start_line == line) {
                fold.folded = !fold.folded;
                return;
            }
        }
    }
    
    /// Check if a line is folded (body is hidden).
    pub fn isFolded(self: *const Folding, line: u32) bool {
        for (self.folds.items) |fold| {
            if (fold.start_line == line and fold.folded) {
                return true;
            }
        }
        return false;
    }
    
    /// Get fold for a given line (if it exists).
    pub fn getFold(self: *const Folding, line: u32) ?Fold {
        for (self.folds.items) |fold| {
            if (fold.start_line == line) {
                return fold;
            }
        }
        return null;
    }
    
    /// Get all folds (for rendering fold markers).
    pub fn getAllFolds(self: *const Folding) []const Fold {
        return self.folds.items;
    }
};

test "folding parse simple function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var folding = Folding.init(arena.allocator());
    defer folding.deinit();
    
    const code =
        \\pub fn main() void {
        \\    std.debug.print("Hello\n", .{});
        \\}
    ;
    
    try folding.parse(code);
    
    // Assert: Should find one fold
    try std.testing.expectEqual(@as(usize, 1), folding.folds.items.len);
    
    const fold = folding.folds.items[0];
    try std.testing.expectEqual(@as(u32, 0), fold.start_line);
    try std.testing.expectEqual(@as(u32, 2), fold.end_line);
    try std.testing.expect(fold.folded);
}

test "folding toggle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var folding = Folding.init(arena.allocator());
    defer folding.deinit();
    
    const code =
        \\pub fn main() void {
        \\    return;
        \\}
    ;
    
    try folding.parse(code);
    
    // Assert: Initially folded
    try std.testing.expect(folding.isFolded(0));
    
    // Toggle
    folding.toggleFold(0);
    
    // Assert: Now unfolded
    try std.testing.expect(!folding.isFolded(0));
}

