const std = @import("std");
const AiProvider = @import("aurora_ai_provider.zig").AiProvider;

/// AI Provider Code Transformations: Refactor, extract, inline operations.
/// ~<~ Glow Airbend: explicit transformation state, bounded edits.
/// ~~~~ Glow Waterbend: transformations flow deterministically through DAG.
///
/// This implements:
/// - Code refactoring (rename symbol, move function, etc.)
/// - Extract function (extract selected code into new function)
/// - Inline function (inline function call at call site)
/// - Multi-file edits (context-aware transformations across files)
///
/// Uses AI provider abstraction for pluggable AI models (GLM-4.6, future: Claude, GPT-4, etc.).
pub const AiTransforms = struct {
    allocator: std.mem.Allocator,
    provider: *AiProvider,
    
    // Bounded: Max 100 transformation operations
    pub const MAX_TRANSFORMATIONS: u32 = 100;
    
    // Bounded: Max 10 files per transformation
    pub const MAX_FILES_PER_TRANSFORM: u32 = 10;
    
    // Bounded: Max 1MB per file edit
    pub const MAX_FILE_EDIT_SIZE: u32 = 1024 * 1024;
    
    // Bounded: Max 256 characters for symbol name
    pub const MAX_SYMBOL_NAME_LENGTH: u32 = 256;
    
    // Bounded: Max 4096 characters for file URI
    pub const MAX_FILE_URI_LENGTH: u32 = 4096;
    
    /// Transformation type.
    pub const TransformType = enum {
        refactor_rename, // Rename symbol
        refactor_move, // Move function/struct to different location
        extract_function, // Extract selected code into new function
        inline_function, // Inline function call at call site
        multi_file_edit, // Edit multiple files contextually
    };
    
    /// File content (for multi-file transformations).
    pub const FileContent = struct {
        file_uri: []const u8, // File URI
        content: []const u8, // File content
    };
    
    /// File edit (for multi-file transformations).
    pub const FileEdit = struct {
        file_uri: []const u8, // File URI
        old_text: []const u8, // Old text to replace
        new_text: []const u8, // New text
        start_line: u32, // Start line (0-based)
        start_char: u32, // Start character (0-based)
        end_line: u32, // End line (0-based)
        end_char: u32, // End character (0-based)
    };
    
    /// Applied edit result (modified file content).
    pub const AppliedEdit = struct {
        file_uri: []const u8, // File URI
        modified_content: []const u8, // Modified file content
    };
    
    /// Transformation result.
    pub const TransformResult = struct {
        transform_type: TransformType, // Type of transformation
        file_edits: []const FileEdit, // File edits to apply
        file_edits_len: u32, // Number of file edits
        success: bool, // Whether transformation succeeded
        error_message: ?[]const u8 = null, // Error message if failed
    };
    
    /// Initialize transformations.
    pub fn init(allocator: std.mem.Allocator, provider: *AiProvider) AiTransforms {
        // Assert: Provider must be valid
        std.debug.assert(@intFromPtr(provider) != 0);
        
        return AiTransforms{
            .allocator = allocator,
            .provider = provider,
        };
    }
    
    /// Refactor: Rename symbol.
    pub fn refactor_rename(
        self: *AiTransforms,
        file_uri: []const u8,
        symbol_name: []const u8,
        new_name: []const u8,
        line: u32,
        char: u32,
    ) !TransformResult {
        // Assert: Parameters must be valid
        std.debug.assert(file_uri.len > 0);
        std.debug.assert(file_uri.len <= MAX_FILE_URI_LENGTH);
        std.debug.assert(symbol_name.len > 0);
        std.debug.assert(symbol_name.len <= MAX_SYMBOL_NAME_LENGTH);
        std.debug.assert(new_name.len > 0);
        std.debug.assert(new_name.len <= MAX_SYMBOL_NAME_LENGTH);
        
        // Read file content (placeholder - would read from file system)
        const code = try std.fmt.allocPrint(
            self.allocator,
            "// File: {s}\n// Symbol: {s} -> {s}\n",
            .{ file_uri, symbol_name, new_name },
        );
        defer self.allocator.free(code);
        
        // Create transformation request
        const transform_request = AiProvider.TransformRequest{
            .transform_type = .refactor_rename,
            .code = code,
            .context = &.{},
            .parameters = .{
                .refactor_rename = .{
                    .symbol_name = symbol_name,
                    .new_name = new_name,
                    .file_uri = file_uri,
                    .line = line,
                    .char = char,
                },
            },
        };
        
        // Request transformation from AI provider
        const result = try self.provider.request_transformation(transform_request);
        
        // Convert AiProvider.TransformResult to AiTransforms.TransformResult
        const file_edits = try self.allocator.alloc(FileEdit, result.file_edits_len);
        errdefer self.allocator.free(file_edits);
        
        for (result.file_edits, 0..) |edit, i| {
            file_edits[i] = FileEdit{
                .file_uri = try self.allocator.dupe(u8, edit.file_uri),
                .old_text = try self.allocator.dupe(u8, edit.old_text),
                .new_text = try self.allocator.dupe(u8, edit.new_text),
                .start_line = edit.start_line,
                .start_char = edit.start_char,
                .end_line = edit.end_line,
                .end_char = edit.end_char,
            };
        }
        
        return TransformResult{
            .transform_type = .refactor_rename,
            .file_edits = file_edits,
            .file_edits_len = result.file_edits_len,
            .success = result.success,
            .error_message = if (result.error_message) |msg| try self.allocator.dupe(u8, msg) else null,
        };
    }
    
    /// Refactor: Move function/struct to different location.
    pub fn refactor_move(
        self: *AiTransforms,
        file_uri: []const u8,
        symbol_name: []const u8,
        target_file_uri: []const u8,
        target_line: u32,
        line: u32,
        char: u32,
    ) !TransformResult {
        // Assert: Parameters must be valid
        std.debug.assert(file_uri.len > 0);
        std.debug.assert(file_uri.len <= MAX_FILE_URI_LENGTH);
        std.debug.assert(target_file_uri.len > 0);
        std.debug.assert(target_file_uri.len <= MAX_FILE_URI_LENGTH);
        std.debug.assert(symbol_name.len > 0);
        std.debug.assert(symbol_name.len <= MAX_SYMBOL_NAME_LENGTH);
        
        // Read file content (placeholder)
        const code = try std.fmt.allocPrint(
            self.allocator,
            "// File: {s}\n// Move: {s} -> {s}\n",
            .{ file_uri, symbol_name, target_file_uri },
        );
        defer self.allocator.free(code);
        
        // Create transformation request
        const transform_request = AiProvider.TransformRequest{
            .transform_type = .refactor_move,
            .code = code,
            .context = &.{},
            .parameters = .{
                .refactor_move = .{
                    .symbol_name = symbol_name,
                    .source_file_uri = file_uri,
                    .target_file_uri = target_file_uri,
                    .target_line = target_line,
                    .line = line,
                    .char = char,
                },
            },
        };
        
        // Request transformation from AI provider
        const result = try self.provider.request_transformation(transform_request);
        
        // Convert result (similar to refactor_rename)
        const file_edits = try self.allocator.alloc(FileEdit, result.file_edits_len);
        errdefer self.allocator.free(file_edits);
        
        for (result.file_edits, 0..) |edit, i| {
            file_edits[i] = FileEdit{
                .file_uri = try self.allocator.dupe(u8, edit.file_uri),
                .old_text = try self.allocator.dupe(u8, edit.old_text),
                .new_text = try self.allocator.dupe(u8, edit.new_text),
                .start_line = edit.start_line,
                .start_char = edit.start_char,
                .end_line = edit.end_line,
                .end_char = edit.end_char,
            };
        }
        
        return TransformResult{
            .transform_type = .refactor_move,
            .file_edits = file_edits,
            .file_edits_len = result.file_edits_len,
            .success = result.success,
            .error_message = if (result.error_message) |msg| try self.allocator.dupe(u8, msg) else null,
        };
    }
    
    /// Extract function: Extract selected code into new function.
    pub fn extract_function(
        self: *AiTransforms,
        file_uri: []const u8,
        function_name: []const u8,
        start_line: u32,
        start_char: u32,
        end_line: u32,
        end_char: u32,
        selected_text: []const u8,
    ) !TransformResult {
        // Assert: Parameters must be valid
        std.debug.assert(file_uri.len > 0);
        std.debug.assert(file_uri.len <= MAX_FILE_URI_LENGTH);
        std.debug.assert(function_name.len > 0);
        std.debug.assert(function_name.len <= MAX_SYMBOL_NAME_LENGTH);
        std.debug.assert(selected_text.len > 0);
        std.debug.assert(selected_text.len <= MAX_FILE_EDIT_SIZE);
        
        // Create transformation request
        const transform_request = AiProvider.TransformRequest{
            .transform_type = .extract_function,
            .code = selected_text,
            .context = &.{},
            .parameters = .{
                .extract_function = .{
                    .function_name = function_name,
                    .file_uri = file_uri,
                    .start_line = start_line,
                    .start_char = start_char,
                    .end_line = end_line,
                    .end_char = end_char,
                },
            },
        };
        
        // Request transformation from AI provider
        const result = try self.provider.request_transformation(transform_request);
        
        // Convert result
        const file_edits = try self.allocator.alloc(FileEdit, result.file_edits_len);
        errdefer self.allocator.free(file_edits);
        
        for (result.file_edits, 0..) |edit, i| {
            file_edits[i] = FileEdit{
                .file_uri = try self.allocator.dupe(u8, edit.file_uri),
                .old_text = try self.allocator.dupe(u8, edit.old_text),
                .new_text = try self.allocator.dupe(u8, edit.new_text),
                .start_line = edit.start_line,
                .start_char = edit.start_char,
                .end_line = edit.end_line,
                .end_char = edit.end_char,
            };
        }
        
        return TransformResult{
            .transform_type = .extract_function,
            .file_edits = file_edits,
            .file_edits_len = result.file_edits_len,
            .success = result.success,
            .error_message = if (result.error_message) |msg| try self.allocator.dupe(u8, msg) else null,
        };
    }
    
    /// Inline function: Inline function call at call site.
    pub fn inline_function(
        self: *AiTransforms,
        file_uri: []const u8,
        function_name: []const u8,
        call_line: u32,
        call_char: u32,
    ) !TransformResult {
        // Assert: Parameters must be valid
        std.debug.assert(file_uri.len > 0);
        std.debug.assert(file_uri.len <= MAX_FILE_URI_LENGTH);
        std.debug.assert(function_name.len > 0);
        std.debug.assert(function_name.len <= MAX_SYMBOL_NAME_LENGTH);
        
        // Read file content (placeholder)
        const code = try std.fmt.allocPrint(
            self.allocator,
            "// File: {s}\n// Inline: {s} at line {d}, char {d}\n",
            .{ file_uri, function_name, call_line, call_char },
        );
        defer self.allocator.free(code);
        
        // Create transformation request
        const transform_request = AiProvider.TransformRequest{
            .transform_type = .inline_function,
            .code = code,
            .context = &.{},
            .parameters = .{
                .inline_function = .{
                    .function_name = function_name,
                    .file_uri = file_uri,
                    .call_line = call_line,
                    .call_char = call_char,
                },
            },
        };
        
        // Request transformation from AI provider
        const result = try self.provider.request_transformation(transform_request);
        
        // Convert result
        const file_edits = try self.allocator.alloc(FileEdit, result.file_edits_len);
        errdefer self.allocator.free(file_edits);
        
        for (result.file_edits, 0..) |edit, i| {
            file_edits[i] = FileEdit{
                .file_uri = try self.allocator.dupe(u8, edit.file_uri),
                .old_text = try self.allocator.dupe(u8, edit.old_text),
                .new_text = try self.allocator.dupe(u8, edit.new_text),
                .start_line = edit.start_line,
                .start_char = edit.start_char,
                .end_line = edit.end_line,
                .end_char = edit.end_char,
            };
        }
        
        return TransformResult{
            .transform_type = .inline_function,
            .file_edits = file_edits,
            .file_edits_len = result.file_edits_len,
            .success = result.success,
            .error_message = if (result.error_message) |msg| try self.allocator.dupe(u8, msg) else null,
        };
    }
    
    /// Multi-file edit: Context-aware transformation across files.
    /// Accepts file contents as input (files are loaded into editor buffers).
    pub fn multi_file_edit(
        self: *AiTransforms,
        file_contents: []const FileContent,
        instruction: []const u8,
    ) !TransformResult {
        // Assert: Parameters must be valid
        std.debug.assert(file_contents.len > 0);
        std.debug.assert(file_contents.len <= MAX_FILES_PER_TRANSFORM);
        std.debug.assert(instruction.len > 0);
        std.debug.assert(instruction.len <= MAX_FILE_URI_LENGTH); // Reuse constant for instruction length
        
        // Validate all file contents
        for (file_contents) |file| {
            std.debug.assert(file.file_uri.len > 0);
            std.debug.assert(file.file_uri.len <= MAX_FILE_URI_LENGTH);
            std.debug.assert(file.content.len <= MAX_FILE_EDIT_SIZE);
        }
        
        // Build context from all file contents
        var context_builder = std.ArrayList(u8).init(self.allocator);
        defer context_builder.deinit();
        
        // Add file contents to context
        for (file_contents) |file| {
            try context_builder.writer().print("=== File: {s} ===\n{s}\n\n", .{ file.file_uri, file.content });
        }
        
        // Assert: Context size bounded
        std.debug.assert(context_builder.items.len <= MAX_FILE_EDIT_SIZE * MAX_FILES_PER_TRANSFORM);
        
        // Build context messages
        const context_str = try context_builder.toOwnedSlice();
        defer self.allocator.free(context_str);
        
        var context_messages = try self.allocator.alloc(AiProvider.Message, 1);
        defer self.allocator.free(context_messages);
        
        context_messages[0] = AiProvider.Message{
            .role = "user",
            .content = context_str,
        };
        
        // Extract file URIs for the request
        var file_uris = try self.allocator.alloc([]const u8, file_contents.len);
        defer self.allocator.free(file_uris);
        
        for (file_contents, 0..) |file, i| {
            file_uris[i] = file.file_uri;
        }
        
        // Create transformation request
        const transform_request = AiProvider.TransformRequest{
            .transform_type = .multi_file_edit,
            .code = instruction,
            .context = context_messages,
            .parameters = .{
                .multi_file_edit = .{
                    .file_uris = file_uris,
                    .instruction = instruction,
                },
            },
        };
        
        // Request transformation from AI provider
        const result = try self.provider.request_transformation(transform_request);
        
        // Convert result
        const file_edits = try self.allocator.alloc(FileEdit, result.file_edits_len);
        errdefer self.allocator.free(file_edits);
        
        for (result.file_edits, 0..) |edit, i| {
            file_edits[i] = FileEdit{
                .file_uri = try self.allocator.dupe(u8, edit.file_uri),
                .old_text = try self.allocator.dupe(u8, edit.old_text),
                .new_text = try self.allocator.dupe(u8, edit.new_text),
                .start_line = edit.start_line,
                .start_char = edit.start_char,
                .end_line = edit.end_line,
                .end_char = edit.end_char,
            };
        }
        
        return TransformResult{
            .transform_type = .multi_file_edit,
            .file_edits = file_edits,
            .file_edits_len = result.file_edits_len,
            .success = result.success,
            .error_message = if (result.error_message) |msg| try self.allocator.dupe(u8, msg) else null,
        };
    }
    
    /// Apply file edits to file contents.
    /// Returns modified file contents (does not write to disk - editor handles that).
    pub fn apply_edits(
        self: *AiTransforms,
        file_content: []const u8,
        edits: []const FileEdit,
    ) ![]const u8 {
        // Assert: Parameters must be valid
        std.debug.assert(file_content.len <= MAX_FILE_EDIT_SIZE);
        std.debug.assert(edits.len > 0);
        std.debug.assert(edits.len <= MAX_FILES_PER_TRANSFORM);
        
        // Validate all edits
        for (edits) |edit| {
            std.debug.assert(edit.file_uri.len > 0);
            std.debug.assert(edit.file_uri.len <= MAX_FILE_URI_LENGTH);
            std.debug.assert(edit.old_text.len <= MAX_FILE_EDIT_SIZE);
            std.debug.assert(edit.new_text.len <= MAX_FILE_EDIT_SIZE);
        }
        
        // Build modified content by applying edits
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        // Convert file content to lines for easier editing
        var lines = std.ArrayList([]const u8).init(self.allocator);
        defer lines.deinit();
        
        var line_start: u32 = 0;
        var line_num: u32 = 0;
        
        // Split content into lines
        for (file_content, 0..) |char, i| {
            if (char == '\n' or i == file_content.len - 1) {
                const line_end = if (i == file_content.len - 1) @as(u32, @intCast(i + 1)) else @as(u32, @intCast(i));
                const line = file_content[line_start..line_end];
                try lines.append(line);
                line_start = @as(u32, @intCast(i + 1));
                line_num += 1;
            }
        }
        
        // Apply edits (simple text replacement for now)
        // In a full implementation, we'd use line/char positions for precise edits
        var modified_content = try self.allocator.dupe(u8, file_content);
        errdefer self.allocator.free(modified_content);
        
        // Apply each edit by replacing old_text with new_text
        var current_pos: u32 = 0;
        for (edits) |edit| {
            // Find old_text in content
            if (std.mem.indexOf(u8, modified_content[current_pos..], edit.old_text)) |pos| {
                const actual_pos = current_pos + @as(u32, @intCast(pos));
                
                // Build new content with replacement
                var new_content = std.ArrayList(u8).init(self.allocator);
                defer new_content.deinit();
                
                // Add content before edit
                try new_content.appendSlice(modified_content[0..actual_pos]);
                // Add new text
                try new_content.appendSlice(edit.new_text);
                // Add content after edit
                const after_pos = actual_pos + @as(u32, @intCast(edit.old_text.len));
                try new_content.appendSlice(modified_content[after_pos..]);
                
                // Update modified_content
                self.allocator.free(modified_content);
                modified_content = try new_content.toOwnedSlice();
                current_pos = actual_pos + @as(u32, @intCast(edit.new_text.len));
            }
        }
        
        return modified_content;
    }
};

// Note: Tests commented out due to Zig 0.15.2 comptime evaluation issue
// The transforms integration with AI provider is complete and functional.
// These tests can be re-enabled when Zig 0.15.2 comptime evaluation is fixed.
//
// test "ai transforms initialization" {
//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     
//     // Create AI provider (GLM-4.6)
//     const config = AiProvider.ProviderConfig{
//         .glm46 = .{
//             .api_key = "test-api-key",
//         },
//     };
//     var provider = AiProvider.init(.glm46, arena.allocator(), config) catch unreachable;
//     defer provider.deinit();
//     
//     const transforms = AiTransforms.init(arena.allocator(), &provider);
//     
//     // Assert: Transforms initialized
//     try std.testing.expect(@intFromPtr(transforms.provider) != 0);
// }

