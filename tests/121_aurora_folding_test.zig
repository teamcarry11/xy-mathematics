//! Tests for Aurora Folding module.
//!
//! Why: Verify folding functionality (parse, toggle, fold state, fold retrieval).
//! Architecture: Comprehensive test coverage for code folding operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-200935-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const Folding = @import("aurora_folding").Folding;

test "folding constants" {
    // Assert: Constants are defined correctly
    std.debug.assert(Folding.MAX_FOLDS == 1_000);
    std.debug.assert(Folding.MAX_FOLDS > 0);
}

test "folding initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    // Assert: Folding initialized correctly
    std.debug.assert(folding.folds.items.len == 0);
}

test "folding deinitialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    folding.deinit();

    // Assert: Deinitialization completed (no crash)
}

test "folding parse simple function" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
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
    std.debug.assert(folding.folds.items.len == 1);

    const fold = folding.folds.items[0];
    std.debug.assert(fold.start_line == 0);
    std.debug.assert(fold.folded == true);
}

test "folding parse multiple functions" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
        \\
        \\fn helper() void {
        \\    return;
        \\}
    ;

    try folding.parse(code);

    // Assert: Should find two folds
    std.debug.assert(folding.folds.items.len == 2);
}

test "folding parse struct" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code =
        \\pub const MyStruct = struct {
        \\    field: u32,
        \\};
    ;

    try folding.parse(code);

    // Assert: Should find one fold
    std.debug.assert(folding.folds.items.len == 1);
}

test "folding parse enum" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code =
        \\pub const MyEnum = enum {
        \\    variant1,
        \\    variant2,
        \\};
    ;

    try folding.parse(code);

    // Assert: Should find one fold
    std.debug.assert(folding.folds.items.len == 1);
}

test "folding parse union" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code =
        \\pub const MyUnion = union {
        \\    variant1: u32,
        \\    variant2: u64,
        \\};
    ;

    try folding.parse(code);

    // Assert: Should find one fold
    std.debug.assert(folding.folds.items.len == 1);
}

test "folding parse empty code" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code = "// comment\n";

    try folding.parse(code);

    // Assert: Should find no folds
    std.debug.assert(folding.folds.items.len == 0);
}

test "folding toggle fold" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
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
    std.debug.assert(folding.isFolded(0) == true);

    // Toggle
    folding.toggleFold(0);

    // Assert: Now unfolded
    std.debug.assert(folding.isFolded(0) == false);
}

test "folding toggle fold twice" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
    ;

    try folding.parse(code);

    // Toggle twice
    folding.toggleFold(0);
    folding.toggleFold(0);

    // Assert: Back to folded
    std.debug.assert(folding.isFolded(0) == true);
}

test "folding is folded invalid line" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
    ;

    try folding.parse(code);

    // Assert: Invalid line is not folded
    std.debug.assert(folding.isFolded(999) == false);
}

test "folding get fold" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
    ;

    try folding.parse(code);

    // Assert: Get fold for valid line
    const fold = folding.getFold(0);
    std.debug.assert(fold != null);
    if (fold) |f| {
        std.debug.assert(f.start_line == 0);
        std.debug.assert(f.folded == true);
    }
}

test "folding get fold invalid line" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
    ;

    try folding.parse(code);

    // Assert: Get fold for invalid line returns null
    const fold = folding.getFold(999);
    std.debug.assert(fold == null);
}

test "folding get all folds" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
        \\
        \\fn helper() void {
        \\    return;
        \\}
    ;

    try folding.parse(code);

    // Assert: Get all folds
    const folds = folding.getAllFolds();
    std.debug.assert(folds.len == 2);
}

test "folding parse and clear" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var folding = Folding.init(arena.allocator());
    defer folding.deinit();

    const code1 =
        \\pub fn main() void {
        \\    return;
        \\}
    ;

    try folding.parse(code1);
    std.debug.assert(folding.folds.items.len == 1);

    const code2 = "// empty\n";
    try folding.parse(code2);

    // Assert: Folds cleared after new parse
    std.debug.assert(folding.folds.items.len == 0);
}

test "folding bounds checking" {
    // Assert: MAX_FOLDS is reasonable
    std.debug.assert(Folding.MAX_FOLDS == 1_000);
    std.debug.assert(Folding.MAX_FOLDS > 0);
    std.debug.assert(Folding.MAX_FOLDS <= 10_000);
}

test "folding fold structure" {
    // Assert: Fold structure fields
    const fold = Folding.Fold{
        .start_line = 0,
        .end_line = 2,
        .body_start = 1,
        .body_end = 2,
        .folded = true,
    };

    std.debug.assert(fold.start_line == 0);
    std.debug.assert(fold.end_line == 2);
    std.debug.assert(fold.body_start == 1);
    std.debug.assert(fold.body_end == 2);
    std.debug.assert(fold.folded == true);
}
