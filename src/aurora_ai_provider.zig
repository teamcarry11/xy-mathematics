const std = @import("std");

/// AI Provider: Abstract interface for AI/LLM code assistance.
/// ~<~ Glow Airbend: explicit provider interface, bounded operations.
/// ~~~~ Glow Waterbend: AI responses flow deterministically through DAG.
///
/// This provides a unified interface for different AI models:
/// - GLM-4.6 (Cerebras API)
/// - Future: Other LLMs (Claude, GPT-4, etc.)
pub const AiProvider = struct {
    // Bounded: Max 200K token context window
    pub const MAX_CONTEXT_TOKENS: u32 = 200_000;
    
    // Bounded: Max 8KB message size
    pub const MAX_MESSAGE_SIZE: u32 = 8 * 1024;
    
    // Bounded: Max 100 messages per request
    pub const MAX_MESSAGES: u32 = 100;
    
    /// Provider type.
    pub const ProviderType = enum {
        glm46, // GLM-4.6 via Cerebras API
        // Future: claude, gpt4, etc.
    };
    
    /// Message in conversation.
    pub const Message = struct {
        role: []const u8, // "system", "user", "assistant"
        content: []const u8,
    };
    
    /// Completion request.
    pub const CompletionRequest = struct {
        messages: []const Message, // Conversation messages
        max_tokens: ?u32 = null, // Max tokens to generate
        temperature: f32 = 0.7, // Temperature (0.0-2.0)
        stream: bool = true, // Whether to stream response
    };
    
    /// Completion chunk (for streaming).
    pub const CompletionChunk = struct {
        content: []const u8, // Chunk content
        is_done: bool, // Whether this is the final chunk
    };
    
    /// Transformation request.
    pub const TransformRequest = struct {
        transform_type: TransformType, // Type of transformation
        code: []const u8, // Code to transform
        context: []const Message, // Additional context
        parameters: TransformParameters, // Transformation-specific parameters
    };
    
    /// Transformation type.
    pub const TransformType = enum {
        refactor_rename,
        refactor_move,
        extract_function,
        inline_function,
        multi_file_edit,
    };
    
    /// Transformation parameters.
    pub const TransformParameters = union(TransformType) {
        refactor_rename: struct {
            symbol_name: []const u8,
            new_name: []const u8,
            file_uri: []const u8,
            line: u32,
            char: u32,
        },
        refactor_move: struct {
            symbol_name: []const u8,
            source_file_uri: []const u8,
            target_file_uri: []const u8,
            target_line: u32,
            line: u32,
            char: u32,
        },
        extract_function: struct {
            function_name: []const u8,
            file_uri: []const u8,
            start_line: u32,
            start_char: u32,
            end_line: u32,
            end_char: u32,
        },
        inline_function: struct {
            function_name: []const u8,
            file_uri: []const u8,
            call_line: u32,
            call_char: u32,
        },
        multi_file_edit: struct {
            file_uris: []const []const u8,
            instruction: []const u8,
        },
    };
    
    /// Transformation result.
    pub const TransformResult = struct {
        file_edits: []const FileEdit, // File edits to apply
        file_edits_len: u32, // Number of file edits
        success: bool, // Whether transformation succeeded
        error_message: ?[]const u8 = null, // Error message if failed
    };
    
    /// File edit (for transformations).
    pub const FileEdit = struct {
        file_uri: []const u8, // File URI
        old_text: []const u8, // Old text to replace
        new_text: []const u8, // New text
        start_line: u32, // Start line (0-based)
        start_char: u32, // Start character (0-based)
        end_line: u32, // End line (0-based)
        end_char: u32, // End character (0-based)
    };
    
    /// Tool call request.
    pub const ToolCallRequest = struct {
        tool_name: []const u8, // Tool name (e.g., "zig_build", "jj_status")
        arguments: []const []const u8, // Tool arguments
        context: []const Message, // Additional context
    };
    
    /// Tool call result.
    pub const ToolCallResult = struct {
        success: bool, // Whether tool call succeeded
        output: []const u8, // Tool output (stdout)
        error_output: ?[]const u8 = null, // Tool error (stderr)
        exit_code: i32, // Exit code
    };
    
    /// VTable for AI provider operations.
    pub const VTable = struct {
        /// Request code completion (streaming).
        request_completion: *const fn (
            self: *anyopaque,
            request: CompletionRequest,
            callback: fn (chunk: CompletionChunk) void,
        ) anyerror!void,
        
        /// Request code transformation.
        request_transformation: *const fn (
            self: *anyopaque,
            request: TransformRequest,
        ) anyerror!TransformResult,
        
        /// Request tool call.
        request_tool_call: *const fn (
            self: *anyopaque,
            request: ToolCallRequest,
        ) anyerror!ToolCallResult,
        
        /// Get provider type.
        get_provider_type: *const fn (self: *const anyopaque) ProviderType,
        
        /// Deinitialize provider.
        deinit: *const fn (self: *anyopaque) void,
    };
    
    vtable: *const VTable,
    impl: *anyopaque, // Type-erased provider implementation
    
    /// Initialize AI provider with specific implementation.
    pub fn init(provider_type: ProviderType, allocator: std.mem.Allocator, config: ProviderConfig) !AiProvider {
        switch (provider_type) {
            .glm46 => {
                const Glm46Provider = @import("aurora_glm46_provider.zig").Glm46Provider;
                const provider = try Glm46Provider.init(allocator, config);
                return AiProvider{
                    .vtable = &Glm46Provider.vtable_impl,
                    .impl = provider,
                };
            },
        }
    }
    
    /// Deinitialize AI provider.
    pub fn deinit(self: *AiProvider) void {
        self.vtable.deinit(self.impl);
    }
    
    /// Request code completion (streaming).
    pub fn request_completion(
        self: *AiProvider,
        request: CompletionRequest,
        callback: fn (chunk: CompletionChunk) void,
    ) !void {
        // Assert: Request must be valid
        std.debug.assert(request.messages.len > 0);
        std.debug.assert(request.messages.len <= MAX_MESSAGES);
        
        // Validate context window
        var total_tokens: u32 = 0;
        for (request.messages) |msg| {
            const msg_tokens = @as(u32, @intCast(msg.content.len / 4)); // Rough estimate
            total_tokens += msg_tokens;
        }
        std.debug.assert(total_tokens <= MAX_CONTEXT_TOKENS);
        
        try self.vtable.request_completion(self.impl, request, callback);
    }
    
    /// Request code transformation.
    pub fn request_transformation(
        self: *AiProvider,
        request: TransformRequest,
    ) !TransformResult {
        // Assert: Request must be valid
        std.debug.assert(request.code.len > 0);
        std.debug.assert(request.code.len <= MAX_MESSAGE_SIZE);
        
        return try self.vtable.request_transformation(self.impl, request);
    }
    
    /// Request tool call.
    pub fn request_tool_call(
        self: *AiProvider,
        request: ToolCallRequest,
    ) !ToolCallResult {
        // Assert: Request must be valid
        std.debug.assert(request.tool_name.len > 0);
        std.debug.assert(request.tool_name.len <= 256); // Bounded tool name length
        std.debug.assert(request.arguments.len <= 100); // Bounded arguments
        
        return try self.vtable.request_tool_call(self.impl, request);
    }
    
    /// Get provider type.
    pub fn get_provider_type(self: *const AiProvider) ProviderType {
        return self.vtable.get_provider_type(self.impl);
    }
    
    /// Provider configuration.
    pub const ProviderConfig = union(ProviderType) {
        glm46: struct {
            api_key: []const u8,
            api_url: []const u8 = "https://api.cerebras.ai/v1",
            model: []const u8 = "glm-4.6",
        },
    };
};

test "ai provider initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const config = AiProvider.ProviderConfig{
        .glm46 = .{
            .api_key = "test-api-key",
        },
    };
    
    // Initialize AI provider (GLM-4.6)
    var provider = AiProvider.init(.glm46, arena.allocator(), config) catch |err| {
        std.debug.panic("Failed to init AI provider: {}", .{err});
    };
    defer provider.deinit();
    
    // Assert: Provider type correct
    try std.testing.expect(provider.get_provider_type() == .glm46);
}

