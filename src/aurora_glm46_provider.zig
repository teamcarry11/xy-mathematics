const std = @import("std");
const AiProvider = @import("aurora_ai_provider.zig").AiProvider;
const Glm46Client = @import("aurora_glm46.zig").Glm46Client;

/// GLM-4.6 Provider: GLM-4.6-specific implementation of AI provider interface.
/// ~<~ Glow Airbend: explicit GLM-4.6 API calls, bounded context windows.
/// ~~~~ Glow Waterbend: GLM-4.6 responses flow deterministically.
pub const Glm46Provider = struct {
    allocator: std.mem.Allocator,
    client: Glm46Client,
    
    /// Initialize GLM-4.6 provider.
    pub fn init(allocator: std.mem.Allocator, config: AiProvider.ProviderConfig) !*Glm46Provider {
        // Assert: Config must be for GLM-4.6
        std.debug.assert(config == .glm46);
        std.debug.assert(allocator.ptr != null);
        std.debug.assert(config.glm46.api_key.len > 0);
        
        const provider = try allocator.create(Glm46Provider);
        errdefer allocator.destroy(provider);
        
        provider.* = Glm46Provider{
            .allocator = allocator,
            .client = Glm46Client.init(allocator, config.glm46.api_key),
        };
        
        return provider;
    }
    
    /// Deinitialize GLM-4.6 provider.
    pub fn deinit_impl(self: *anyopaque) void {
        const provider: *Glm46Provider = @ptrCast(@alignCast(self));
        provider.client.deinit();
        provider.allocator.destroy(provider);
    }
    
    /// Request code completion (streaming).
    pub fn request_completion_impl(
        self: *anyopaque,
        request: AiProvider.CompletionRequest,
        callback: fn (chunk: AiProvider.CompletionChunk) void,
    ) !void {
        const provider: *Glm46Provider = @ptrCast(@alignCast(self));
        
        // Assert: Request must be valid
        std.debug.assert(request.messages.len > 0);
        std.debug.assert(request.messages.len <= AiProvider.MAX_MESSAGES);
        
        // Convert AiProvider messages to Glm46Client messages
        const messages = try provider.allocator.alloc(Glm46Client.Message, request.messages.len);
        defer provider.allocator.free(messages);
        
        for (request.messages, 0..) |msg, i| {
            // Assert: Message content must be within bounds
            std.debug.assert(msg.content.len <= AiProvider.MAX_MESSAGE_SIZE);
            
            messages[i] = Glm46Client.Message{
                .role = msg.role,
                .content = msg.content,
            };
        }
        
        // Request completion from GLM-4.6 client
        try provider.client.requestCompletion(messages, struct {
            fn callback_wrapper(chunk: []const u8) void {
                callback(AiProvider.CompletionChunk{
                    .content = chunk,
                    .is_done = false,
                });
            }
        }.callback_wrapper);
        
        // Signal completion
        callback(AiProvider.CompletionChunk{
            .content = "",
            .is_done = true,
        });
    }
    
    /// Request code transformation.
    pub fn request_transformation_impl(
        self: *anyopaque,
        request: AiProvider.TransformRequest,
    ) !AiProvider.TransformResult {
        const provider: *Glm46Provider = @ptrCast(@alignCast(self));
        
        // Convert transformation request to GLM-4.6 format
        // For now, return placeholder (full implementation would call GLM-4.6 API)
        _ = request;
        _ = provider;
        
        const error_msg = try provider.allocator.dupe(u8, "Not yet implemented");
        return AiProvider.TransformResult{
            .file_edits = &.{},
            .file_edits_len = 0,
            .success = false,
            .error_message = error_msg,
        };
    }
    
    /// Request tool call.
    pub fn request_tool_call_impl(
        self: *anyopaque,
        request: AiProvider.ToolCallRequest,
    ) !AiProvider.ToolCallResult {
        const provider: *Glm46Provider = @ptrCast(@alignCast(self));
        
        // For now, return placeholder (full implementation would call GLM-4.6 API with tool calling)
        _ = request;
        
        const error_msg = try provider.allocator.dupe(u8, "Not yet implemented");
        return AiProvider.ToolCallResult{
            .success = false,
            .output = "",
            .error_output = error_msg,
            .exit_code = -1,
        };
    }
    
    /// Get provider type.
    pub fn get_provider_type_impl(self: *const anyopaque) AiProvider.ProviderType {
        _ = self;
        return .glm46;
    }
    
    /// VTable implementation for GLM-4.6 provider.
    pub const vtable_impl = AiProvider.VTable{
        .request_completion = request_completion_impl,
        .request_transformation = request_transformation_impl,
        .request_tool_call = request_tool_call_impl,
        .get_provider_type = get_provider_type_impl,
        .deinit = deinit_impl,
    };
};

test "glm46 provider initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    var provider = try Glm46Provider.init(arena.allocator(), config);
    defer Glm46Provider.deinit_impl(provider);
    
    // Assert: Provider initialized
    try std.testing.expect(@intFromPtr(provider) != 0);
}

