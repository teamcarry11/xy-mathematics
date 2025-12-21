//! Tests for Aurora VCS module.
//!
//! Why: Verify VCS client functionality (virtual files, readonly ranges,
//! jj command integration, edit watching).
//! Architecture: Comprehensive test coverage for Magit-style VCS integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-145649-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const VcsClient = @import("aurora_vcs").VcsClient;

test "vcs constants" {
    // Assert: MAX_VIRTUAL_FILES constant
    std.debug.assert(VcsClient.MAX_VIRTUAL_FILES == 1000);
    
    // Assert: MAX_PENDING_COMMANDS constant
    std.debug.assert(VcsClient.MAX_PENDING_COMMANDS == 100);
}

test "vcs readonly type enum" {
    // Assert: ReadonlyType enum values
    std.debug.assert(@intFromEnum(VcsClient.ReadonlyType.commit_hash) == 0);
    std.debug.assert(@intFromEnum(VcsClient.ReadonlyType.parent_info) == 1);
    std.debug.assert(@intFromEnum(VcsClient.ReadonlyType.file_path) == 2);
    std.debug.assert(@intFromEnum(VcsClient.ReadonlyType.diff_header) == 3);
}

test "vcs readonly range structure" {
    // Assert: ReadonlyRange structure
    const range = VcsClient.ReadonlyRange{
        .start = 10,
        .end = 20,
        .type = .commit_hash,
    };
    
    std.debug.assert(range.start == 10);
    std.debug.assert(range.end == 20);
    std.debug.assert(range.type == .commit_hash);
}

test "vcs client initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    // Assert: Client initialized
    std.debug.assert(client.virtual_files.items.len == 0);
    std.debug.assert(client.pending_commands.items.len == 0);
    std.debug.assert(std.mem.eql(u8, client.repo_path, repo_path));
}

test "vcs client deinitialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    client.deinit();
    
    // Assert: Client deinitialized (no crash)
}

test "vcs parse status output headers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const status_output = "Working copy changes:\n";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_status_output(status_output, &ranges);
    
    // Assert: Should find header range
    std.debug.assert(ranges.items.len > 0);
    std.debug.assert(ranges.items[0].type == .diff_header);
}

test "vcs parse status output commit hash" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const status_output = "Commit: abc123def456\n";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_status_output(status_output, &ranges);
    
    // Assert: Should find commit hash range
    std.debug.assert(ranges.items.len > 0);
    std.debug.assert(ranges.items[0].type == .commit_hash);
}

test "vcs parse status output parent info" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const status_output = "Parent: xyz789\n";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_status_output(status_output, &ranges);
    
    // Assert: Should find parent info range
    std.debug.assert(ranges.items.len > 0);
    std.debug.assert(ranges.items[0].type == .parent_info);
}

test "vcs parse status output file path" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const status_output = "  modified: src/main.zig\n";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_status_output(status_output, &ranges);
    
    // Assert: Should find file path range
    std.debug.assert(ranges.items.len > 0);
    std.debug.assert(ranges.items[0].type == .file_path);
}

test "vcs parse status output hunk header" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const status_output = "@@ -10,5 +10,5 @@\n";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_status_output(status_output, &ranges);
    
    // Assert: Should find hunk header range
    std.debug.assert(ranges.items.len > 0);
    std.debug.assert(ranges.items[0].type == .diff_header);
}

test "vcs parse status output multiple ranges" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const status_output =
        \\Working copy changes:
        \\  modified: src/main.zig
        \\Commit: abc123def456
        \\Parent: xyz789
    ;
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_status_output(status_output, &ranges);
    
    // Assert: Should find multiple ranges
    std.debug.assert(ranges.items.len >= 3);
}

test "vcs parse diff output diff header" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const diff_output = "diff --git a/file.zig b/file.zig\n";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_diff_output(diff_output, &ranges);
    
    // Assert: Should find diff header range
    std.debug.assert(ranges.items.len > 0);
    std.debug.assert(ranges.items[0].type == .diff_header);
}

test "vcs parse diff output index line" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const diff_output = "index 1234567..abcdefg\n";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_diff_output(diff_output, &ranges);
    
    // Assert: Should find index range
    std.debug.assert(ranges.items.len > 0);
    std.debug.assert(ranges.items[0].type == .diff_header);
}

test "vcs parse diff output file headers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const diff_output = "--- a/file.zig\n+++ b/file.zig\n";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_diff_output(diff_output, &ranges);
    
    // Assert: Should find file header ranges
    std.debug.assert(ranges.items.len >= 2);
    std.debug.assert(ranges.items[0].type == .diff_header);
    std.debug.assert(ranges.items[1].type == .diff_header);
}

test "vcs parse diff output hunk header" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const diff_output = "@@ -10,5 +10,5 @@ function\n";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_diff_output(diff_output, &ranges);
    
    // Assert: Should find hunk header range
    std.debug.assert(ranges.items.len > 0);
    std.debug.assert(ranges.items[0].type == .diff_header);
}

test "vcs parse diff output multiple headers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const diff_output =
        \\diff --git a/file.zig b/file.zig
        \\index 1234567..abcdefg
        \\--- a/file.zig
        \\+++ b/file.zig
        \\@@ -10,5 +10,5 @@ function
    ;
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_diff_output(diff_output, &ranges);
    
    // Assert: Should find multiple header ranges
    std.debug.assert(ranges.items.len >= 5);
}

test "vcs get virtual file not found" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const vf = client.get_virtual_file(".jj/status.jj");
    
    // Assert: Should return null for non-existent file
    std.debug.assert(vf == null);
}

test "vcs readonly range validation" {
    // Assert: ReadonlyRange start < end
    const range = VcsClient.ReadonlyRange{
        .start = 10,
        .end = 20,
        .type = .commit_hash,
    };
    
    std.debug.assert(range.start < range.end);
    std.debug.assert(range.end > range.start);
}

test "vcs bounds checking virtual files" {
    // Assert: MAX_VIRTUAL_FILES is bounded
    std.debug.assert(VcsClient.MAX_VIRTUAL_FILES > 0);
    std.debug.assert(VcsClient.MAX_VIRTUAL_FILES <= 10000); // Reasonable upper bound
}

test "vcs bounds checking pending commands" {
    // Assert: MAX_PENDING_COMMANDS is bounded
    std.debug.assert(VcsClient.MAX_PENDING_COMMANDS > 0);
    std.debug.assert(VcsClient.MAX_PENDING_COMMANDS <= 10000); // Reasonable upper bound
}

test "vcs readonly type coverage" {
    // Assert: All ReadonlyType variants exist
    const types = [_]VcsClient.ReadonlyType{
        .commit_hash,
        .parent_info,
        .file_path,
        .diff_header,
    };
    
    std.debug.assert(types.len == 4);
}

test "vcs parse status output empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const status_output = "";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    // Assert: Empty output should not crash
    try client.parse_status_output(status_output, &ranges);
    std.debug.assert(ranges.items.len == 0);
}

test "vcs parse diff output empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const diff_output = "";
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    // Assert: Empty output should not crash
    try client.parse_diff_output(diff_output, &ranges);
    std.debug.assert(ranges.items.len == 0);
}
