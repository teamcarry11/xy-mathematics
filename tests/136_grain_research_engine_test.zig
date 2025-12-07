//! Tests for Grain Research Engine.
//!
//! Why: Verify research data collection, storage, and query capabilities.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-070000-pst: Grain Research Agent Phase 1

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const ResearchEngine = grain_research.ResearchEngine;
const ResearchEntry = grain_research.ResearchEntry;
const QueryFilter = grain_research.QueryFilter;
const MAX_QUERY_RESULTS = grain_research.research_engine.MAX_QUERY_RESULTS;

test "research engine initialization" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);

    try testing.expect(engine.get_entry_count() == 0);
    try testing.expect(engine.next_entry_id == 1);

    engine.deinit();
}

test "collect research entry" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const title = "Test Entry";
    const content = "This is test content for research.";
    const tags = [_][]const u8{ "test", "research" };

    const entry_id = try engine.collect(title, content, &tags);

    try testing.expect(entry_id == 1);
    try testing.expect(engine.get_entry_count() == 1);
    try testing.expect(engine.next_entry_id == 2);
}

test "get entry by id" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const title = "Test Entry";
    const content = "This is test content.";
    const tags = [_][]const u8{ "test" };

    const entry_id = try engine.collect(title, content, &tags);

    const entry = engine.get_entry_by_id(entry_id);
    try testing.expect(entry != null);
    try testing.expect(entry.?.entry_id == entry_id);
    try testing.expect(std.mem.eql(u8, entry.?.title, title));
    try testing.expect(std.mem.eql(u8, entry.?.content, content));
}

test "query by tag" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const title1 = "Entry 1";
    const content1 = "Content 1";
    const tags1 = [_][]const u8{ "tag1", "common" };
    _ = try engine.collect(title1, content1, &tags1);

    const title2 = "Entry 2";
    const content2 = "Content 2";
    const tags2 = [_][]const u8{ "tag2", "common" };
    _ = try engine.collect(title2, content2, &tags2);

    const title3 = "Entry 3";
    const content3 = "Content 3";
    const tags3 = [_][]const u8{ "tag3" };
    _ = try engine.collect(title3, content3, &tags3);

    const filter = QueryFilter{ .tag = "common" };
    var result = try engine.query(filter);
    defer result.deinit();

    try testing.expect(result.entries_len == 2);
    try testing.expect(result.total_matched == 2);
}

test "query by title contains" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const title1 = "Python Tutorial";
    const content1 = "Learn Python";
    const tags1 = [_][]const u8{ "python" };
    _ = try engine.collect(title1, content1, &tags1);

    const title2 = "Zig Tutorial";
    const content2 = "Learn Zig";
    const tags2 = [_][]const u8{ "zig" };
    _ = try engine.collect(title2, content2, &tags2);

    const filter = QueryFilter{ .title_contains = "Python" };
    var result = try engine.query(filter);
    defer result.deinit();

    try testing.expect(result.entries_len == 1);
    try testing.expect(std.mem.eql(u8, result.entries[0].title, title1));
}

test "query by content contains" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const title1 = "Entry 1";
    const content1 = "This is about research";
    const tags1 = [_][]const u8{ "research" };
    _ = try engine.collect(title1, content1, &tags1);

    const title2 = "Entry 2";
    const content2 = "This is about analysis";
    const tags2 = [_][]const u8{ "analysis" };
    _ = try engine.collect(title2, content2, &tags2);

    const filter = QueryFilter{ .content_contains = "research" };
    var result = try engine.query(filter);
    defer result.deinit();

    try testing.expect(result.entries_len == 1);
    try testing.expect(std.mem.eql(u8, result.entries[0].content, content1));
}

test "query by date range" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const now = std.time.timestamp();
    const before = @as(u64, @intCast(now - 3600));
    const after = @as(u64, @intCast(now + 3600));

    const title = "Entry";
    const content = "Content";
    const tags = [_][]const u8{ "test" };
    _ = try engine.collect(title, content, &tags);

    const filter = QueryFilter{
        .created_after = before,
        .created_before = after,
    };
    var result = try engine.query(filter);
    defer result.deinit();

    try testing.expect(result.entries_len == 1);
}

test "query with multiple filters" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const title1 = "Python Research";
    const content1 = "Python is great";
    const tags1 = [_][]const u8{ "python", "research" };
    _ = try engine.collect(title1, content1, &tags1);

    const title2 = "Zig Research";
    const content2 = "Zig is great";
    const tags2 = [_][]const u8{ "zig", "research" };
    _ = try engine.collect(title2, content2, &tags2);

    const filter = QueryFilter{
        .tag = "research",
        .title_contains = "Python",
    };
    var result = try engine.query(filter);
    defer result.deinit();

    try testing.expect(result.entries_len == 1);
    try testing.expect(std.mem.eql(u8, result.entries[0].title, title1));
}

test "query returns empty result" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const filter = QueryFilter{ .tag = "nonexistent" };
    var result = try engine.query(filter);
    defer result.deinit();

    try testing.expect(result.entries_len == 0);
    try testing.expect(result.total_matched == 0);
}

test "query limits results" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const title = "Entry";
    const content = "Content";
    const tags = [_][]const u8{ "test" };

    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        _ = try engine.collect(title, content, &tags);
    }

    const filter = QueryFilter{ .tag = "test" };
    var result = try engine.query(filter);
    defer result.deinit();

    try testing.expect(result.entries_len <= MAX_QUERY_RESULTS);
    try testing.expect(result.total_matched == 100);
}

test "research entry deinit" {
    const allocator = testing.allocator;
    var entry = try ResearchEntry.init(
        allocator,
        1,
        "Title",
        "Content",
        &[_][]const u8{ "tag" },
    );

    try testing.expect(entry.entry_id == 1);
    try testing.expect(std.mem.eql(u8, entry.title, "Title"));
    try testing.expect(std.mem.eql(u8, entry.content, "Content"));
    try testing.expect(entry.tags_len == 1);

    entry.deinit();
}

test "query result deinit" {
    const allocator = testing.allocator;
    var engine = ResearchEngine.init(allocator);
    defer engine.deinit();

    const title = "Entry";
    const content = "Content";
    const tags = [_][]const u8{ "test" };
    _ = try engine.collect(title, content, &tags);

    const filter = QueryFilter{ .tag = "test" };
    var result = try engine.query(filter);

    try testing.expect(result.entries_len == 1);
    result.deinit();
}
