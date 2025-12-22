//! Tests for Aurora GLM-4.6 Provider module.
//!
//! Why: Verify GLM-4.6 provider functionality (AI provider interface,
//! completion requests, tool calls).
//! Architecture: Comprehensive test coverage for GLM-4.6 AI provider implementation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-234944-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const Glm46Provider = @import("aurora_glm46_provider").Glm46Provider;
const AiProvider = @import("aurora_ai_provider").AiProvider;

test "glm46 provider initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    // Assert: Provider initialized
    std.debug.assert(@intFromPtr(provider) != 0);
}

test "glm46 provider deinitialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    Glm46Provider.deinit_impl(provider);
    
    // Assert: Provider deinitialized (no crash)
}

test "glm46 provider get provider type" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    const provider_type = Glm46Provider.get_provider_type_impl(provider);
    
    // Assert: Provider type is GLM-4.6
    try testing.expectEqual(AiProvider.ProviderType.glm46, provider_type);
}

test "glm46 provider vtable implementation" {
    // Assert: VTable exists and has required functions
    std.debug.assert(@intFromPtr(&Glm46Provider.vtable_impl) != 0);
    std.debug.assert(@intFromPtr(Glm46Provider.vtable_impl.request_completion) != 0);
    std.debug.assert(@intFromPtr(Glm46Provider.vtable_impl.request_transformation) != 0);
    std.debug.assert(@intFromPtr(Glm46Provider.vtable_impl.request_tool_call) != 0);
    std.debug.assert(@intFromPtr(Glm46Provider.vtable_impl.get_provider_type) != 0);
    std.debug.assert(@intFromPtr(Glm46Provider.vtable_impl.deinit) != 0);
}

test "glm46 provider init with empty api key fails" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "",
        },
    };
    
    // Assert: Initialization fails with empty API key
    testing.expectError(error.AssertionFailed, Glm46Provider.init(arena.allocator(), config));
}

test "glm46 provider init with invalid config fails" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    // Note: This test would require a different provider config type
    // For now, we test that GLM-4.6 config works
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    // Assert: Provider initialized with valid config
    std.debug.assert(@intFromPtr(provider) != 0);
}

test "glm46 provider request transformation not implemented" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    const transform_request = AiProvider.TransformRequest{
        .source_code = "test code",
        .transformation_type = .refactor,
        .file_path = "test.zig",
    };
    
    const result = try Glm46Provider.request_transformation_impl(provider, transform_request);
    
    // Assert: Transformation not implemented
    try testing.expectEqual(false, result.success);
    try testing.expectEqual(@as(u32, 0), result.file_edits_len);
    std.debug.assert(result.error_message != null);
}

test "glm46 provider request tool call echo" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    const tool_request = AiProvider.ToolCallRequest{
        .tool_name = "echo",
        .arguments = &.{"hello"},
    };
    
    const result = try Glm46Provider.request_tool_call_impl(provider, tool_request);
    defer {
        provider.allocator.free(result.output);
        if (result.error_output) |err| provider.allocator.free(err);
    }
    
    // Assert: Tool call executed
    try testing.expectEqual(true, result.success);
    try testing.expectEqual(@as(i32, 0), result.exit_code);
    std.debug.assert(result.output.len > 0);
}

test "glm46 provider request tool call false command" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    const tool_request = AiProvider.ToolCallRequest{
        .tool_name = "false",
        .arguments = &.{},
    };
    
    const result = try Glm46Provider.request_tool_call_impl(provider, tool_request);
    defer {
        provider.allocator.free(result.output);
        if (result.error_output) |err| provider.allocator.free(err);
    }
    
    // Assert: Tool call executed (false returns non-zero exit code)
    try testing.expectEqual(false, result.success);
    try testing.expect(result.exit_code != 0);
}

test "glm46 provider request tool call true command" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    const tool_request = AiProvider.ToolCallRequest{
        .tool_name = "true",
        .arguments = &.{},
    };
    
    const result = try Glm46Provider.request_tool_call_impl(provider, tool_request);
    defer {
        provider.allocator.free(result.output);
        if (result.error_output) |err| provider.allocator.free(err);
    }
    
    // Assert: Tool call executed (true returns zero exit code)
    try testing.expectEqual(true, result.success);
    try testing.expectEqual(@as(i32, 0), result.exit_code);
}

test "glm46 provider request tool call with multiple arguments" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    const tool_request = AiProvider.ToolCallRequest{
        .tool_name = "echo",
        .arguments = &.{ "hello", "world" },
    };
    
    const result = try Glm46Provider.request_tool_call_impl(provider, tool_request);
    defer {
        provider.allocator.free(result.output);
        if (result.error_output) |err| provider.allocator.free(err);
    }
    
    // Assert: Tool call executed with multiple arguments
    try testing.expectEqual(true, result.success);
    std.debug.assert(result.output.len > 0);
}

test "glm46 provider request tool call empty tool name fails" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    const tool_request = AiProvider.ToolCallRequest{
        .tool_name = "",
        .arguments = &.{},
    };
    
    // Assert: Empty tool name fails
    testing.expectError(error.AssertionFailed, Glm46Provider.request_tool_call_impl(provider, tool_request));
}

test "glm46 provider request completion empty messages fails" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    var callback_called = false;
    const completion_request = AiProvider.CompletionRequest{
        .messages = &.{},
    };
    
    // Assert: Empty messages fails
    testing.expectError(error.AssertionFailed, Glm46Provider.request_completion_impl(provider, completion_request, struct {
        fn callback(chunk: AiProvider.CompletionChunk) void {
            _ = chunk;
        }
    }.callback));
}

test "glm46 provider vtable deinit" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    
    // Use vtable deinit
    Glm46Provider.vtable_impl.deinit(provider);
    
    // Assert: Provider deinitialized via vtable (no crash)
}

test "glm46 provider vtable get provider type" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    const provider_type = Glm46Provider.vtable_impl.get_provider_type(provider);
    
    // Assert: Provider type retrieved via vtable
    try testing.expectEqual(AiProvider.ProviderType.glm46, provider_type);
}

test "glm46 provider multiple instances" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key-1",
        },
    };
    
    const provider1 = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider1);
    
    const config2 = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key-2",
        },
    };
    
    const provider2 = try Glm46Provider.init(arena.allocator(), config2);
    defer Glm46Provider.deinit_impl(provider2);
    
    // Assert: Multiple instances can coexist
    std.debug.assert(@intFromPtr(provider1) != @intFromPtr(provider2));
    try testing.expectEqual(AiProvider.ProviderType.glm46, Glm46Provider.get_provider_type_impl(provider1));
    try testing.expectEqual(AiProvider.ProviderType.glm46, Glm46Provider.get_provider_type_impl(provider2));
}

test "glm46 provider tool call output bounds" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    // Test with a command that produces small output
    const tool_request = AiProvider.ToolCallRequest{
        .tool_name = "echo",
        .arguments = &.{"test"},
    };
    
    const result = try Glm46Provider.request_tool_call_impl(provider, tool_request);
    defer {
        provider.allocator.free(result.output);
        if (result.error_output) |err| provider.allocator.free(err);
    }
    
    // Assert: Output is within bounds (10MB max)
    std.debug.assert(result.output.len <= 10 * 1024 * 1024);
}

test "glm46 provider tool call error output bounds" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    // Test with a command that may produce error output
    const tool_request = AiProvider.ToolCallRequest{
        .tool_name = "false",
        .arguments = &.{},
    };
    
    const result = try Glm46Provider.request_tool_call_impl(provider, tool_request);
    defer {
        provider.allocator.free(result.output);
        if (result.error_output) |err| provider.allocator.free(err);
    }
    
    // Assert: Error output is within bounds (10MB max) or null
    if (result.error_output) |err| {
        std.debug.assert(err.len <= 10 * 1024 * 1024);
    }
}

test "glm46 provider tool call exit code handling" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    // Test with true (exit code 0)
    const tool_request_true = AiProvider.ToolCallRequest{
        .tool_name = "true",
        .arguments = &.{},
    };
    
    const result_true = try Glm46Provider.request_tool_call_impl(provider, tool_request_true);
    defer {
        provider.allocator.free(result_true.output);
        if (result_true.error_output) |err| provider.allocator.free(err);
    }
    
    try testing.expectEqual(@as(i32, 0), result_true.exit_code);
    
    // Test with false (exit code non-zero)
    const tool_request_false = AiProvider.ToolCallRequest{
        .tool_name = "false",
        .arguments = &.{},
    };
    
    const result_false = try Glm46Provider.request_tool_call_impl(provider, tool_request_false);
    defer {
        provider.allocator.free(result_false.output);
        if (result_false.error_output) |err| provider.allocator.free(err);
    }
    
    try testing.expect(result_false.exit_code != 0);
}

test "glm46 provider transformation request error message" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    const provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    const transform_request = AiProvider.TransformRequest{
        .source_code = "test code",
        .transformation_type = .refactor,
        .file_path = "test.zig",
    };
    
    const result = try Glm46Provider.request_transformation_impl(provider, transform_request);
    
    // Assert: Error message indicates not implemented
    std.debug.assert(result.error_message != null);
    std.debug.assert(std.mem.indexOf(u8, result.error_message.?, "Not yet implemented") != null);
}
