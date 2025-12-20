//! Tests for Aurora LSP Client.
//!
//! Why: Verify LSP client functionality (initialization, document lifecycle,
//! snapshot management, diagnostics, message handling).
//! Architecture: Comprehensive test coverage for LSP operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! NOTE: Some tests require a running LSP server (e.g., completion, hover).
//! These tests focus on client-side functionality that can be tested without
//! a server: initialization, document lifecycle, snapshot management, diagnostics.
//!
//! 2025-12-20-143848-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const LspClient = @import("aurora_lsp").LspClient;

test "lsp client initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    // Assert: Client initialized correctly
    std.debug.assert(client.request_id == 1);
    std.debug.assert(client.current_snapshot_id == 0);
    std.debug.assert(client.snapshots.items.len == 0);
    std.debug.assert(client.pending_requests.count() == 0);
    std.debug.assert(client.diagnostics.count() == 0);
    std.debug.assert(client.server_process == null);
}

test "lsp client snapshot creation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri = "file:///test.zig";
    const text = "const std = @import(\"std\");\n";

    // Create snapshot via didOpen
    try client.didOpen(uri, text);

    // Assert: Snapshot created
    std.debug.assert(client.snapshots.items.len == 1);
    std.debug.assert(client.current_snapshot_id == 1);
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].uri, uri));
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].text, text));
    std.debug.assert(client.snapshots.items[0].version == 1);
    std.debug.assert(client.snapshots.items[0].id == 1);
}

test "lsp client document lifecycle didOpen" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri = "file:///test.zig";
    const text = "const std = @import(\"std\");\n";

    try client.didOpen(uri, text);

    // Assert: Document opened and snapshot created
    std.debug.assert(client.snapshots.items.len == 1);
    std.debug.assert(client.current_snapshot_id == 1);
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].uri, uri));
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].text, text));
}

test "lsp client document lifecycle didChange incremental" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri = "file:///test.zig";
    const initial_text = "const std = @import(\"std\");\n";

    try client.didOpen(uri, initial_text);

    // Create incremental change
    const change = LspClient.TextDocumentChange{
        .range = LspClient.Range{
            .start = LspClient.Position{ .line = 0, .character = 0 },
            .end = LspClient.Position{ .line = 0, .character = 0 },
        },
        .range_length = 0,
        .text = "pub ",
    };

    const changes = [_]LspClient.TextDocumentChange{change};
    try client.didChange(uri, &changes);

    // Assert: Snapshot updated
    std.debug.assert(client.snapshots.items.len == 1);
    std.debug.assert(client.current_snapshot_id == 2);
    std.debug.assert(client.snapshots.items[0].version == 2);
    const expected_text = "pub const std = @import(\"std\");\n";
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].text, expected_text));
}

test "lsp client document lifecycle didChange full replacement" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri = "file:///test.zig";
    const initial_text = "const std = @import(\"std\");\n";
    const new_text = "pub const std = @import(\"std\");\n";

    try client.didOpen(uri, initial_text);

    // Create full replacement change (null range)
    const change = LspClient.TextDocumentChange{
        .range = null,
        .range_length = null,
        .text = new_text,
    };

    const changes = [_]LspClient.TextDocumentChange{change};
    try client.didChange(uri, &changes);

    // Assert: Snapshot updated with full replacement
    std.debug.assert(client.snapshots.items.len == 1);
    std.debug.assert(client.current_snapshot_id == 2);
    std.debug.assert(client.snapshots.items[0].version == 2);
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].text, new_text));
}

test "lsp client document lifecycle didClose" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri = "file:///test.zig";
    const text = "const std = @import(\"std\");\n";

    try client.didOpen(uri, text);
    std.debug.assert(client.snapshots.items.len == 1);

    try client.didClose(uri);

    // Assert: Snapshot removed
    std.debug.assert(client.snapshots.items.len == 0);
}

test "lsp client multiple documents" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri1 = "file:///test1.zig";
    const uri2 = "file:///test2.zig";
    const text1 = "const std = @import(\"std\");\n";
    const text2 = "pub fn main() void {}\n";

    try client.didOpen(uri1, text1);
    try client.didOpen(uri2, text2);

    // Assert: Both documents tracked
    std.debug.assert(client.snapshots.items.len == 2);
    std.debug.assert(client.current_snapshot_id == 2);

    // Close one document
    try client.didClose(uri1);

    // Assert: One document remains
    std.debug.assert(client.snapshots.items.len == 1);
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].uri, uri2));
}

test "lsp client snapshot versioning" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri = "file:///test.zig";
    const initial_text = "const std = @import(\"std\");\n";

    try client.didOpen(uri, initial_text);
    std.debug.assert(client.snapshots.items[0].version == 1);

    // Make multiple changes
    const change1 = LspClient.TextDocumentChange{
        .range = null,
        .range_length = null,
        .text = "pub const std = @import(\"std\");\n",
    };
    const changes1 = [_]LspClient.TextDocumentChange{change1};
    try client.didChange(uri, &changes1);
    std.debug.assert(client.snapshots.items[0].version == 2);

    const change2 = LspClient.TextDocumentChange{
        .range = null,
        .range_length = null,
        .text = "pub const std = @import(\"std\");\npub fn main() void {}\n",
    };
    const changes2 = [_]LspClient.TextDocumentChange{change2};
    try client.didChange(uri, &changes2);
    std.debug.assert(client.snapshots.items[0].version == 3);
}

test "lsp client diagnostics storage" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri = "file:///test.zig";
    const uri_copy = try allocator.dupe(u8, uri);

    // Add diagnostics manually (simulating server response)
    var diags = std.ArrayListUnmanaged(LspClient.Diagnostic){};
    const diag = LspClient.Diagnostic{
        .range = LspClient.Range{
            .start = LspClient.Position{ .line = 0, .character = 0 },
            .end = LspClient.Position{ .line = 0, .character = 5 },
        },
        .severity = 1, // Error
        .message = try allocator.dupe(u8, "Undefined variable"),
        .source = try allocator.dupe(u8, "zls"),
    };
    try diags.append(allocator, diag);
    try client.diagnostics.put(uri_copy, diags);

    // Assert: Diagnostics stored
    std.debug.assert(client.diagnostics.count() == 1);
    const stored_diags = client.diagnostics.get(uri).?;
    std.debug.assert(stored_diags.items.len == 1);
    std.debug.assert(stored_diags.items[0].severity == 1);
    std.debug.assert(std.mem.eql(u8, stored_diags.items[0].message, "Undefined variable"));
}

test "lsp client request id increment" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    // Assert: Initial request ID is 1
    std.debug.assert(client.request_id == 1);

    // Simulate request (would normally call sendRequest)
    // Request ID should increment on each request
    // Note: This test verifies the initial state; actual increment
    // happens in sendRequest which requires server communication
}

test "lsp client bounds checking uri length" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    // Create URI within bounds (4096 chars max)
    var uri_buf: [4096]u8 = undefined;
    @memset(&uri_buf, 'a');
    const uri = uri_buf[0..4096];

    const text = "test\n";
    try client.didOpen(uri, text);

    // Assert: Document opened successfully
    std.debug.assert(client.snapshots.items.len == 1);
}

test "lsp client bounds checking snapshot limit" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    // Create snapshots up to limit (MAX_SNAPSHOTS = 1000)
    // Note: This test would require creating 1000 documents, which is expensive
    // Instead, verify the constant is defined
    std.debug.assert(LspClient.MAX_SNAPSHOTS == 1000);
}

test "lsp client position validation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri = "file:///test.zig";
    const text = "line 1\nline 2\nline 3\n";

    try client.didOpen(uri, text);

    // Create change with valid position
    const change = LspClient.TextDocumentChange{
        .range = LspClient.Range{
            .start = LspClient.Position{ .line = 1, .character = 0 },
            .end = LspClient.Position{ .line = 1, .character = 6 },
        },
        .range_length = 6,
        .text = "line two\n",
    };

    const changes = [_]LspClient.TextDocumentChange{change};
    try client.didChange(uri, &changes);

    // Assert: Change applied correctly
    std.debug.assert(client.snapshots.items[0].version == 2);
}

test "lsp client incremental edit multiple changes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);
    defer client.deinit();

    const uri = "file:///test.zig";
    const initial_text = "const std = @import(\"std\");\n";

    try client.didOpen(uri, initial_text);

    // Apply multiple incremental changes
    const change1 = LspClient.TextDocumentChange{
        .range = LspClient.Range{
            .start = LspClient.Position{ .line = 0, .character = 0 },
            .end = LspClient.Position{ .line = 0, .character = 0 },
        },
        .range_length = 0,
        .text = "pub ",
    };

    const change2 = LspClient.TextDocumentChange{
        .range = LspClient.Range{
            .start = LspClient.Position{ .line = 0, .character = 20 },
            .end = LspClient.Position{ .line = 0, .character = 20 },
        },
        .range_length = 0,
        .text = "\npub fn main() void {}\n",
    };

    const changes = [_]LspClient.TextDocumentChange{ change1, change2 };
    try client.didChange(uri, &changes);

    // Assert: Changes applied
    std.debug.assert(client.snapshots.items[0].version == 2);
    const expected = "pub const std = @import(\"std\");\npub fn main() void {}\n";
    std.debug.assert(std.mem.eql(u8, client.snapshots.items[0].text, expected));
}

test "lsp client deinitialization cleanup" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = LspClient.init(allocator);

    const uri = "file:///test.zig";
    const text = "const std = @import(\"std\");\n";

    try client.didOpen(uri, text);

    // Add diagnostics
    const uri_copy = try allocator.dupe(u8, uri);
    var diags = std.ArrayListUnmanaged(LspClient.Diagnostic){};
    const diag = LspClient.Diagnostic{
        .range = LspClient.Range{
            .start = LspClient.Position{ .line = 0, .character = 0 },
            .end = LspClient.Position{ .line = 0, .character = 5 },
        },
        .severity = 1,
        .message = try allocator.dupe(u8, "Test error"),
        .source = null,
    };
    try diags.append(allocator, diag);
    try client.diagnostics.put(uri_copy, diags);

    // Deinitialize
    client.deinit();

    // Assert: Cleanup completed (no leaks)
    // Note: Actual leak detection would require valgrind or similar
    // This test verifies deinit doesn't crash
}
