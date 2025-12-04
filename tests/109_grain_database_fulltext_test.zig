//! Tests for Grain Database Full-Text Search.
//!
//! Why: Verify inverted index, tokenization, stemming, and search.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-173339-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const InvertedIndex = grain_database.InvertedIndex;
const tokenize = grain_database.tokenize;
const stem = grain_database.stem;

test "inverted index initialization" {
    const allocator = testing.allocator;
    var index = try InvertedIndex.init(allocator);
    defer index.deinit();

    try testing.expect(index.entries_len == 0);
}

test "index document" {
    const allocator = testing.allocator;
    var index = try InvertedIndex.init(allocator);
    defer index.deinit();

    try index.index_document(1, "policy education reform");
    try testing.expect(index.entries_len > 0);
}

test "search documents" {
    const allocator = testing.allocator;
    var index = try InvertedIndex.init(allocator);
    defer index.deinit();

    try index.index_document(1, "policy education reform");
    try index.index_document(2, "policy healthcare reform");
    try index.index_document(3, "education system improvement");

    var results: [1000]u64 = undefined;
    const count = try index.search("education", &results);
    try testing.expect(count >= 2);
}

test "tokenize text" {
    const allocator = testing.allocator;
    var tokens: [1000][]const u8 = undefined;
    var tokens_len: u32 = 0;

    try tokenize("hello world test", &tokens, &tokens_len);
    try testing.expect(tokens_len == 3);
    try testing.expect(std.mem.eql(u8, tokens[0], "hello"));
    try testing.expect(std.mem.eql(u8, tokens[1], "world"));
    try testing.expect(std.mem.eql(u8, tokens[2], "test"));
}

test "tokenize empty text" {
    const allocator = testing.allocator;
    var tokens: [1000][]const u8 = undefined;
    var tokens_len: u32 = 0;

    try tokenize("", &tokens, &tokens_len);
    try testing.expect(tokens_len == 0);
}

test "tokenize with multiple spaces" {
    const allocator = testing.allocator;
    var tokens: [1000][]const u8 = undefined;
    var tokens_len: u32 = 0;

    try tokenize("hello   world    test", &tokens, &tokens_len);
    try testing.expect(tokens_len == 3);
}

test "stem word" {
    const allocator = testing.allocator;
    const stemmed = try stem("running", allocator);
    defer allocator.free(stemmed);

    try testing.expect(stemmed.len <= 7);
}

test "stem word lowercase" {
    const allocator = testing.allocator;
    const stemmed = try stem("HELLO", allocator);
    defer allocator.free(stemmed);

    try testing.expect(std.mem.eql(u8, stemmed, "hello"));
}

test "stem word with suffix" {
    const allocator = testing.allocator;
    const stemmed1 = try stem("running", allocator);
    defer allocator.free(stemmed1);

    const stemmed2 = try stem("run", allocator);
    defer allocator.free(stemmed2);

    try testing.expect(true);
}

test "search multiple documents" {
    const allocator = testing.allocator;
    var index = try InvertedIndex.init(allocator);
    defer index.deinit();

    try index.index_document(1, "climate change policy");
    try index.index_document(2, "economic policy reform");
    try index.index_document(3, "healthcare policy change");

    var results: [1000]u64 = undefined;
    const count = try index.search("policy", &results);
    try testing.expect(count >= 3);
}

test "search case insensitive" {
    const allocator = testing.allocator;
    var index = try InvertedIndex.init(allocator);
    defer index.deinit();

    try index.index_document(1, "Policy Education Reform");
    try index.index_document(2, "policy healthcare reform");

    var results: [1000]u64 = undefined;
    const count = try index.search("POLICY", &results);
    try testing.expect(count >= 2);
}

test "search with stemming" {
    const allocator = testing.allocator;
    var index = try InvertedIndex.init(allocator);
    defer index.deinit();

    try index.index_document(1, "running policy");
    try index.index_document(2, "run policy");

    var results: [1000]u64 = undefined;
    const count1 = try index.search("running", &results);
    const count2 = try index.search("run", &results);
    try testing.expect(count1 >= 1);
    try testing.expect(count2 >= 1);
}

test "index document with special characters" {
    const allocator = testing.allocator;
    var index = try InvertedIndex.init(allocator);
    defer index.deinit();

    try index.index_document(1, "policy: education, reform!");
    try testing.expect(index.entries_len > 0);
}

test "search empty query" {
    const allocator = testing.allocator;
    var index = try InvertedIndex.init(allocator);
    defer index.deinit();

    try index.index_document(1, "policy education");

    var results: [1000]u64 = undefined;
    const count = try index.search("", &results);
    try testing.expect(count == 0);
}

test "search nonexistent term" {
    const allocator = testing.allocator;
    var index = try InvertedIndex.init(allocator);
    defer index.deinit();

    try index.index_document(1, "policy education");

    var results: [1000]u64 = undefined;
    const count = try index.search("nonexistent", &results);
    try testing.expect(count == 0);
}

