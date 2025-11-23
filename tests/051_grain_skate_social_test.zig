const std = @import("std");
const testing = std.testing;
const grain_skate = @import("grain_skate");
const Block = grain_skate.Block;
const Social = grain_skate.Social;

test "social manager init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var social = try Social.SocialManager.init(allocator, &block_storage);
    defer social.deinit();

    try testing.expect(social.replies_len == 0);
    try testing.expect(social.transclusions_len == 0);
}

test "create reply" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var social = try Social.SocialManager.init(allocator, &block_storage);
    defer social.deinit();

    const parent_id = try block_storage.create_block("Parent", "Parent content");
    const reply_id = try block_storage.create_block("Reply", "Reply content");

    try social.create_reply(reply_id, parent_id);

    try testing.expect(social.replies_len == 1);
    try testing.expect(social.replies[0].reply_block_id == reply_id);
    try testing.expect(social.replies[0].parent_block_id == parent_id);
    try testing.expect(social.replies[0].depth == 0);
}

test "get reply thread" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var social = try Social.SocialManager.init(allocator, &block_storage);
    defer social.deinit();

    const parent_id = try block_storage.create_block("Parent", "Parent content");
    const reply1_id = try block_storage.create_block("Reply 1", "Reply 1 content");
    const reply2_id = try block_storage.create_block("Reply 2", "Reply 2 content");

    try social.create_reply(reply1_id, parent_id);
    try social.create_reply(reply2_id, parent_id);

    var thread: [100]u32 = undefined;
    const thread_len = try social.get_reply_thread(parent_id, &thread);

    try testing.expect(thread_len >= 1);
    try testing.expect(thread[0] == parent_id);
}

test "create transclusion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var social = try Social.SocialManager.init(allocator, &block_storage);
    defer social.deinit();

    const source_id = try block_storage.create_block("Source", "Source content");
    const target_id = try block_storage.create_block("Target", "Target content");

    try social.create_transclusion(source_id, target_id, 0, 10);

    try testing.expect(social.transclusions_len == 1);
    try testing.expect(social.transclusions[0].source_block_id == source_id);
    try testing.expect(social.transclusions[0].target_block_id == target_id);
}

test "get transcluded content" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var social = try Social.SocialManager.init(allocator, &block_storage);
    defer social.deinit();

    const source_id = try block_storage.create_block("Source", "Source content");
    const target_id = try block_storage.create_block("Target", "Target content");

    try social.create_transclusion(source_id, target_id, 0, 10);

    var output: [1024]u8 = undefined;
    const output_len = try social.get_transcluded_content(target_id, &output);

    try testing.expect(output_len > 0);
}

test "export block markdown" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var social = try Social.SocialManager.init(allocator, &block_storage);
    defer social.deinit();

    var export_mgr = Social.ExportManager{
        .block_storage = &block_storage,
        .social_manager = &social,
        .allocator = allocator,
    };

    const block_id = try block_storage.create_block("Test Title", "Test content");

    var output: [1024]u8 = undefined;
    const output_len = try export_mgr.export_block_markdown(block_id, &output);

    try testing.expect(output_len > 0);
}

