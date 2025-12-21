//! Tests for Aurora AI Transforms.
//!
//! Why: Verify AI transforms functionality (data structures, bounds checking,
//! transformation types, file edit operations).
//! Architecture: Comprehensive test coverage for AI transforms operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! NOTE: Some tests require actual AI API calls (refactor, extract, inline).
//! These tests focus on client-side functionality that can be tested without
//! a server: data structures, bounds checking, transformation types, file edits.
//!
//! 2025-12-20-175007-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const AiTransforms = @import("aurora_ai_transforms").AiTransforms;

test "ai transforms constants" {
    // Assert: Constants are defined correctly
    std.debug.assert(AiTransforms.MAX_TRANSFORMATIONS == 100);
    std.debug.assert(AiTransforms.MAX_FILES_PER_TRANSFORM == 10);
    std.debug.assert(AiTransforms.MAX_FILE_EDIT_SIZE == 1024 * 1024);
    std.debug.assert(AiTransforms.MAX_SYMBOL_NAME_LENGTH == 256);
    std.debug.assert(AiTransforms.MAX_FILE_URI_LENGTH == 4096);
}

test "ai transforms transform type enum" {
    // Assert: Transform type enum values
    std.debug.assert(@intFromEnum(AiTransforms.TransformType.refactor_rename) == 0);
    std.debug.assert(@intFromEnum(AiTransforms.TransformType.refactor_move) == 1);
    std.debug.assert(@intFromEnum(AiTransforms.TransformType.extract_function) == 2);
    std.debug.assert(@intFromEnum(AiTransforms.TransformType.inline_function) == 3);
    std.debug.assert(@intFromEnum(AiTransforms.TransformType.multi_file_edit) == 4);
}

test "ai transforms file content structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_uri = "file:///test.zig";
    const content = "pub fn main() void {}\n";
    const content_copy = try allocator.dupe(u8, content);

    const file_content = AiTransforms.FileContent{
        .file_uri = file_uri,
        .content = content_copy,
    };

    // Assert: File content structure correct
    std.debug.assert(std.mem.eql(u8, file_content.file_uri, file_uri));
    std.debug.assert(std.mem.eql(u8, file_content.content, content));
}

test "ai transforms file edit structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_uri = "file:///test.zig";
    const old_text = "old code";
    const new_text = "new code";
    const old_text_copy = try allocator.dupe(u8, old_text);
    const new_text_copy = try allocator.dupe(u8, new_text);

    const edit = AiTransforms.FileEdit{
        .file_uri = file_uri,
        .old_text = old_text_copy,
        .new_text = new_text_copy,
        .start_line = 5,
        .start_char = 10,
        .end_line = 5,
        .end_char = 18,
    };

    // Assert: Edit structure correct
    std.debug.assert(std.mem.eql(u8, edit.file_uri, file_uri));
    std.debug.assert(std.mem.eql(u8, edit.old_text, old_text));
    std.debug.assert(std.mem.eql(u8, edit.new_text, new_text));
    std.debug.assert(edit.start_line == 5);
    std.debug.assert(edit.end_line == 5);
}

test "ai transforms applied edit structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_uri = "file:///test.zig";
    const modified_content = "pub fn main() void {}\n";
    const modified_content_copy = try allocator.dupe(u8, modified_content);

    const applied_edit = AiTransforms.AppliedEdit{
        .file_uri = file_uri,
        .modified_content = modified_content_copy,
    };

    // Assert: Applied edit structure correct
    std.debug.assert(std.mem.eql(u8, applied_edit.file_uri, file_uri));
    std.debug.assert(std.mem.eql(u8, applied_edit.modified_content, modified_content));
}

test "ai transforms transform result structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const result = AiTransforms.TransformResult{
        .transform_type = .refactor_rename,
        .file_edits = &.{},
        .file_edits_len = 0,
        .success = true,
        .error_message = null,
    };

    // Assert: Result structure correct
    std.debug.assert(result.transform_type == .refactor_rename);
    std.debug.assert(result.file_edits_len == 0);
    std.debug.assert(result.success == true);
    std.debug.assert(result.error_message == null);
    // Use result to verify structure
    _ = result.file_edits;
}

test "ai transforms transform result with error" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const error_msg = "Transformation failed";
    const error_msg_copy = try allocator.dupe(u8, error_msg);

    const result = AiTransforms.TransformResult{
        .transform_type = .extract_function,
        .file_edits = &.{},
        .file_edits_len = 0,
        .success = false,
        .error_message = error_msg_copy,
    };

    // Assert: Result structure correct
    std.debug.assert(result.transform_type == .extract_function);
    std.debug.assert(result.success == false);
    std.debug.assert(result.error_message != null);
    if (result.error_message) |msg| {
        std.debug.assert(std.mem.eql(u8, msg, error_msg));
    }
}

test "ai transforms bounds checking symbol name length" {
    // Assert: MAX_SYMBOL_NAME_LENGTH is reasonable
    std.debug.assert(AiTransforms.MAX_SYMBOL_NAME_LENGTH == 256);
    std.debug.assert(AiTransforms.MAX_SYMBOL_NAME_LENGTH > 0);
}

test "ai transforms bounds checking file uri length" {
    // Assert: MAX_FILE_URI_LENGTH is reasonable
    std.debug.assert(AiTransforms.MAX_FILE_URI_LENGTH == 4096);
    std.debug.assert(AiTransforms.MAX_FILE_URI_LENGTH > 0);
}

test "ai transforms bounds checking file edit size" {
    // Assert: MAX_FILE_EDIT_SIZE is reasonable
    std.debug.assert(AiTransforms.MAX_FILE_EDIT_SIZE == 1024 * 1024);
    std.debug.assert(AiTransforms.MAX_FILE_EDIT_SIZE > 0);
}

test "ai transforms bounds checking transformations count" {
    // Assert: MAX_TRANSFORMATIONS is reasonable
    std.debug.assert(AiTransforms.MAX_TRANSFORMATIONS == 100);
    std.debug.assert(AiTransforms.MAX_TRANSFORMATIONS > 0);
}

test "ai transforms bounds checking files per transform" {
    // Assert: MAX_FILES_PER_TRANSFORM is reasonable
    std.debug.assert(AiTransforms.MAX_FILES_PER_TRANSFORM == 10);
    std.debug.assert(AiTransforms.MAX_FILES_PER_TRANSFORM > 0);
}

test "ai transforms file edit line range" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_uri = "file:///test.zig";
    const old_text = "line 1\nline 2\nline 3\n";
    const new_text = "line one\nline two\nline three\n";
    const old_text_copy = try allocator.dupe(u8, old_text);
    const new_text_copy = try allocator.dupe(u8, new_text);

    const edit = AiTransforms.FileEdit{
        .file_uri = file_uri,
        .old_text = old_text_copy,
        .new_text = new_text_copy,
        .start_line = 0,
        .start_char = 0,
        .end_line = 2,
        .end_char = 6,
    };

    // Assert: Edit line range correct
    std.debug.assert(edit.start_line == 0);
    std.debug.assert(edit.end_line == 2);
    std.debug.assert(edit.start_char == 0);
    std.debug.assert(edit.end_char == 6);
}

test "ai transforms transform result multiple edits" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_uri = "file:///test.zig";
    const old_text1 = "old1";
    const new_text1 = "new1";
    const old_text1_copy = try allocator.dupe(u8, old_text1);
    const new_text1_copy = try allocator.dupe(u8, new_text1);

    const old_text2 = "old2";
    const new_text2 = "new2";
    const old_text2_copy = try allocator.dupe(u8, old_text2);
    const new_text2_copy = try allocator.dupe(u8, new_text2);

    const edits = [_]AiTransforms.FileEdit{
        .{
            .file_uri = file_uri,
            .old_text = old_text1_copy,
            .new_text = new_text1_copy,
            .start_line = 0,
            .start_char = 0,
            .end_line = 0,
            .end_char = 4,
        },
        .{
            .file_uri = file_uri,
            .old_text = old_text2_copy,
            .new_text = new_text2_copy,
            .start_line = 1,
            .start_char = 0,
            .end_line = 1,
            .end_char = 4,
        },
    };

    const result = AiTransforms.TransformResult{
        .transform_type = .multi_file_edit,
        .file_edits = &edits,
        .file_edits_len = 2,
        .success = true,
        .error_message = null,
    };

    // Assert: Result structure correct
    std.debug.assert(result.transform_type == .multi_file_edit);
    std.debug.assert(result.file_edits_len == 2);
    std.debug.assert(result.success == true);
    std.debug.assert(result.file_edits[0].start_line == 0);
    std.debug.assert(result.file_edits[1].start_line == 1);
}

test "ai transforms transform types coverage" {
    // Assert: All transform types are defined
    _ = AiTransforms.TransformType.refactor_rename;
    _ = AiTransforms.TransformType.refactor_move;
    _ = AiTransforms.TransformType.extract_function;
    _ = AiTransforms.TransformType.inline_function;
    _ = AiTransforms.TransformType.multi_file_edit;
}

test "ai transforms file content multiple files" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_uri1 = "file:///test1.zig";
    const file_uri2 = "file:///test2.zig";
    const content1 = "pub fn main() void {}\n";
    const content2 = "pub fn helper() void {}\n";
    const content1_copy = try allocator.dupe(u8, content1);
    const content2_copy = try allocator.dupe(u8, content2);

    const file_contents = [_]AiTransforms.FileContent{
        .{
            .file_uri = file_uri1,
            .content = content1_copy,
        },
        .{
            .file_uri = file_uri2,
            .content = content2_copy,
        },
    };

    // Assert: File contents structure correct
    std.debug.assert(file_contents.len == 2);
    std.debug.assert(std.mem.eql(u8, file_contents[0].file_uri, file_uri1));
    std.debug.assert(std.mem.eql(u8, file_contents[1].file_uri, file_uri2));
}
