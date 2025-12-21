//! Tests for Aurora AI Provider Abstraction.
//!
//! Why: Verify AI provider interface functionality (data structures,
//! bounds checking, provider types, request validation).
//! Architecture: Comprehensive test coverage for AI provider operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! NOTE: Some tests require actual AI API calls (completion, transformation).
//! These tests focus on client-side functionality that can be tested without
//! a server: data structures, bounds checking, request validation.
//!
//! 2025-12-20-161128-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const AiProvider = @import("aurora_ai_provider").AiProvider;

test "ai provider constants" {
    // Assert: Constants are defined correctly
    std.debug.assert(AiProvider.MAX_CONTEXT_TOKENS == 200_000);
    std.debug.assert(AiProvider.MAX_MESSAGE_SIZE == 8 * 1024);
    std.debug.assert(AiProvider.MAX_MESSAGES == 100);
}

test "ai provider type enum" {
    // Assert: Provider type enum values
    const provider_type = AiProvider.ProviderType.glm46;
    std.debug.assert(provider_type == .glm46);
}

test "ai provider message structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const role = "user";
    const content = "Complete this code: const x = ";
    const content_copy = try allocator.dupe(u8, content);

    const message = AiProvider.Message{
        .role = role,
        .content = content_copy,
    };

    // Assert: Message structure correct
    std.debug.assert(std.mem.eql(u8, message.role, role));
    std.debug.assert(std.mem.eql(u8, message.content, content));
}

test "ai provider completion request structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const message_content = "Complete this code";
    const content_copy = try allocator.dupe(u8, message_content);

    const messages = [_]AiProvider.Message{
        .{
            .role = "user",
            .content = content_copy,
        },
    };

    const request = AiProvider.CompletionRequest{
        .messages = &messages,
        .max_tokens = 100,
        .temperature = 0.7,
        .stream = true,
    };

    // Assert: Request structure correct
    std.debug.assert(request.messages.len == 1);
    std.debug.assert(request.max_tokens == 100);
    std.debug.assert(request.temperature == 0.7);
    std.debug.assert(request.stream == true);
}

test "ai provider completion chunk structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const content = "const x = 42;";
    const content_copy = try allocator.dupe(u8, content);

    const chunk = AiProvider.CompletionChunk{
        .content = content_copy,
        .is_done = false,
    };

    // Assert: Chunk structure correct
    std.debug.assert(std.mem.eql(u8, chunk.content, content));
    std.debug.assert(chunk.is_done == false);
}

test "ai provider transform type enum" {
    // Assert: Transform type enum values
    std.debug.assert(@intFromEnum(AiProvider.TransformType.refactor_rename) == 0);
    std.debug.assert(@intFromEnum(AiProvider.TransformType.refactor_move) == 1);
    std.debug.assert(@intFromEnum(AiProvider.TransformType.extract_function) == 2);
    std.debug.assert(@intFromEnum(AiProvider.TransformType.inline_function) == 3);
    std.debug.assert(@intFromEnum(AiProvider.TransformType.multi_file_edit) == 4);
}

test "ai provider transform parameters refactor rename" {
    const symbol_name = "old_name";
    const new_name = "new_name";
    const file_uri = "file:///test.zig";

    const params = AiProvider.TransformParameters{
        .refactor_rename = .{
            .symbol_name = symbol_name,
            .new_name = new_name,
            .file_uri = file_uri,
            .line = 10,
            .char = 5,
        },
    };

    // Assert: Parameters structure correct
    std.debug.assert(params == .refactor_rename);
    std.debug.assert(std.mem.eql(u8, params.refactor_rename.symbol_name, symbol_name));
    std.debug.assert(std.mem.eql(u8, params.refactor_rename.new_name, new_name));
    std.debug.assert(params.refactor_rename.line == 10);
    std.debug.assert(params.refactor_rename.char == 5);
    // Use params to verify structure
    _ = params.refactor_rename.file_uri;
}

test "ai provider transform request structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const code = "pub fn test() void {}\n";
    const code_copy = try allocator.dupe(u8, code);

    const request = AiProvider.TransformRequest{
        .transform_type = .refactor_rename,
        .code = code_copy,
        .context = &.{},
        .parameters = .{
            .refactor_rename = .{
                .symbol_name = "test",
                .new_name = "test_renamed",
                .file_uri = "file:///test.zig",
                .line = 0,
                .char = 0,
            },
        },
    };

    // Assert: Request structure correct
    std.debug.assert(request.transform_type == .refactor_rename);
    std.debug.assert(std.mem.eql(u8, request.code, code));
    std.debug.assert(request.context.len == 0);
    // Use request to verify structure
    _ = request.parameters;
}

test "ai provider transform result structure" {
    const result = AiProvider.TransformResult{
        .file_edits = &.{},
        .file_edits_len = 0,
        .success = true,
        .error_message = null,
    };

    // Assert: Result structure correct
    std.debug.assert(result.file_edits_len == 0);
    std.debug.assert(result.success == true);
    std.debug.assert(result.error_message == null);
    // Use result to verify structure
    _ = result.file_edits;
}

test "ai provider file edit structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_uri = "file:///test.zig";
    const old_text = "old code";
    const new_text = "new code";
    const old_text_copy = try allocator.dupe(u8, old_text);
    const new_text_copy = try allocator.dupe(u8, new_text);

    const edit = AiProvider.FileEdit{
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

test "ai provider tool call request structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const tool_name = "zig_build";
    const arg1 = "test";
    const arg1_copy = try allocator.dupe(u8, arg1);
    const args = [_][]const u8{arg1_copy};

    const request = AiProvider.ToolCallRequest{
        .tool_name = tool_name,
        .arguments = &args,
        .context = &.{},
    };

    // Assert: Request structure correct
    std.debug.assert(std.mem.eql(u8, request.tool_name, tool_name));
    std.debug.assert(request.arguments.len == 1);
    std.debug.assert(request.context.len == 0);
}

test "ai provider tool call result structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const output = "Build successful";
    const output_copy = try allocator.dupe(u8, output);

    const result = AiProvider.ToolCallResult{
        .success = true,
        .output = output_copy,
        .error_output = null,
        .exit_code = 0,
    };

    // Assert: Result structure correct
    std.debug.assert(result.success == true);
    std.debug.assert(std.mem.eql(u8, result.output, output));
    std.debug.assert(result.error_output == null);
    std.debug.assert(result.exit_code == 0);
}

test "ai provider provider config structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const api_key = "test-api-key";
    const api_key_copy = try allocator.dupe(u8, api_key);

    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = api_key_copy,
            .api_url = "https://api.cerebras.ai/v1",
            .model = "glm-4.6",
        },
    };

    // Assert: Config structure correct
    std.debug.assert(config == .glm46);
    std.debug.assert(std.mem.eql(u8, config.glm46.api_key, api_key));
    std.debug.assert(std.mem.eql(u8, config.glm46.api_url, "https://api.cerebras.ai/v1"));
    std.debug.assert(std.mem.eql(u8, config.glm46.model, "glm-4.6"));
}

test "ai provider bounds checking message size" {
    // Assert: MAX_MESSAGE_SIZE is reasonable
    std.debug.assert(AiProvider.MAX_MESSAGE_SIZE == 8 * 1024);
    std.debug.assert(AiProvider.MAX_MESSAGE_SIZE > 0);
}

test "ai provider bounds checking messages count" {
    // Assert: MAX_MESSAGES is reasonable
    std.debug.assert(AiProvider.MAX_MESSAGES == 100);
    std.debug.assert(AiProvider.MAX_MESSAGES > 0);
}

test "ai provider bounds checking context tokens" {
    // Assert: MAX_CONTEXT_TOKENS is reasonable
    std.debug.assert(AiProvider.MAX_CONTEXT_TOKENS == 200_000);
    std.debug.assert(AiProvider.MAX_CONTEXT_TOKENS > 0);
}

test "ai provider transform parameters extract function" {
    const function_name = "extracted_func";
    const file_uri = "file:///test.zig";

    const params = AiProvider.TransformParameters{
        .extract_function = .{
            .function_name = function_name,
            .file_uri = file_uri,
            .start_line = 5,
            .start_char = 0,
            .end_line = 10,
            .end_char = 0,
        },
    };

    // Assert: Parameters structure correct
    std.debug.assert(params == .extract_function);
    std.debug.assert(std.mem.eql(u8, params.extract_function.function_name, function_name));
    std.debug.assert(params.extract_function.start_line == 5);
    std.debug.assert(params.extract_function.end_line == 10);
    // Use params to verify structure
    _ = params.extract_function.file_uri;
    _ = params.extract_function.start_char;
    _ = params.extract_function.end_char;
}

test "ai provider transform parameters multi file edit" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_uri1 = "file:///test1.zig";
    const file_uri2 = "file:///test2.zig";
    const instruction = "Update both files";
    const instruction_copy = try allocator.dupe(u8, instruction);
    const file_uris = [_][]const u8{ file_uri1, file_uri2 };

    const params = AiProvider.TransformParameters{
        .multi_file_edit = .{
            .file_uris = &file_uris,
            .instruction = instruction_copy,
        },
    };

    // Assert: Parameters structure correct
    std.debug.assert(params == .multi_file_edit);
    std.debug.assert(params.multi_file_edit.file_uris.len == 2);
    std.debug.assert(std.mem.eql(u8, params.multi_file_edit.instruction, instruction));
}
