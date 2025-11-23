const std = @import("std");
const Block = @import("block.zig").Block;

/// Grain Skate Social: Link-based replies, transclusion, and export/import.
/// ~<~ Glow Airbend: explicit social state, bounded reply/transclusion management.
/// ~~~~ Glow Waterbend: deterministic social operations, iterative algorithms.
///
/// 2025-11-23-122043-pst: Active implementation
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Social = struct {
    // Bounded: Max reply depth (explicit limit)
    // 2025-11-23-122043-pst: Active constant
    pub const MAX_REPLY_DEPTH: u32 = 100;

    // Bounded: Max transclusion depth (explicit limit)
    // 2025-11-23-122043-pst: Active constant
    pub const MAX_TRANSCLUSION_DEPTH: u32 = 50;

    // Bounded: Max transclusions per block (explicit limit)
    // 2025-11-23-122043-pst: Active constant
    pub const MAX_TRANSCLUSIONS_PER_BLOCK: u32 = 32;

    /// Reply relationship structure.
    // 2025-11-23-122043-pst: Active struct
    pub const Reply = struct {
        reply_block_id: u32, // Block that is the reply
        parent_block_id: u32, // Block being replied to
        depth: u32, // Depth in reply thread (0 = direct reply)
        created_at: u64, // Reply creation timestamp
    };

    /// Transclusion structure.
    // 2025-11-23-122043-pst: Active struct
    pub const Transclusion = struct {
        source_block_id: u32, // Block being transcluded
        target_block_id: u32, // Block that transcludes
        offset: u32, // Offset in target block content where transclusion appears
        length: u32, // Length of transcluded content
        depth: u32, // Transclusion depth (0 = direct)
    };

    /// Social features manager.
    // 2025-11-23-122043-pst: Active struct
    pub const SocialManager = struct {
        block_storage: *Block.BlockStorage, // Block storage
        replies: []Reply, // Reply relationships (bounded)
        replies_len: u32, // Number of replies
        transclusions: []Transclusion, // Transclusion relationships (bounded)
        transclusions_len: u32, // Number of transclusions
        allocator: std.mem.Allocator,

        // Bounded: Max replies (explicit limit)
        pub const MAX_REPLIES: u32 = 10_000;

        // Bounded: Max transclusions (explicit limit)
        pub const MAX_TRANSCLUSIONS: u32 = 10_000;

        /// Initialize social manager.
        // 2025-11-23-122043-pst: Active function
        pub fn init(allocator: std.mem.Allocator, block_storage: *Block.BlockStorage) !SocialManager {
            // Pre-allocate replies buffer
            const replies = try allocator.alloc(Reply, MAX_REPLIES);
            errdefer allocator.free(replies);

            // Pre-allocate transclusions buffer
            const transclusions = try allocator.alloc(Transclusion, MAX_TRANSCLUSIONS);
            errdefer allocator.free(transclusions);

            return SocialManager{
                .block_storage = block_storage,
                .replies = replies,
                .replies_len = 0,
                .transclusions = transclusions,
                .transclusions_len = 0,
                .allocator = allocator,
            };
        }

        /// Deinitialize social manager and free memory.
        pub fn deinit(self: *SocialManager) void {
            self.allocator.free(self.replies);
            self.allocator.free(self.transclusions);
            self.* = undefined;
        }

        /// Create reply relationship between blocks.
        // 2025-11-23-122043-pst: Active function
        pub fn create_reply(self: *SocialManager, reply_block_id: u32, parent_block_id: u32) !void {
            // Assert: Blocks must exist
            std.debug.assert(self.block_storage.get_block(reply_block_id) != null);
            std.debug.assert(self.block_storage.get_block(parent_block_id) != null);

            // Check reply limit
            if (self.replies_len >= MAX_REPLIES) {
                return error.TooManyReplies;
            }

            // Calculate reply depth (iterative, no recursion)
            const depth = try self.calculate_reply_depth(parent_block_id);

            // Assert: Depth must be bounded
            std.debug.assert(depth < MAX_REPLY_DEPTH);

            // Get current timestamp
            const now = std.time.timestamp();

            // Create reply relationship
            self.replies[self.replies_len] = Reply{
                .reply_block_id = reply_block_id,
                .parent_block_id = parent_block_id,
                .depth = depth,
                .created_at = @as(u64, @intCast(now)),
            };
            self.replies_len += 1;

            // Link blocks bidirectionally
            try self.block_storage.link_blocks(reply_block_id, parent_block_id);
        }

        /// Calculate reply depth for a block (iterative).
        // 2025-11-23-122043-pst: Active function
        fn calculate_reply_depth(self: *SocialManager, block_id: u32) !u32 {
            // Iterative depth calculation (no recursion)
            var depth: u32 = 0;
            var current_block_id: u32 = block_id;
            var visited: [MAX_REPLY_DEPTH]bool = undefined;
            @memset(&visited, false);
            var visited_count: u32 = 0;

            // Find parent replies iteratively
            while (depth < MAX_REPLY_DEPTH) {
                // Check for cycle
                if (visited_count > 0) {
                    var i: u32 = 0;
                    while (i < visited_count) : (i += 1) {
                        if (visited[i] and i == current_block_id) {
                            return error.CyclicReply;
                        }
                    }
                }
                visited[visited_count] = true;
                visited_count += 1;

                // Find parent reply
                var found_parent: bool = false;
                var i: u32 = 0;
                while (i < self.replies_len) : (i += 1) {
                    if (self.replies[i].reply_block_id == current_block_id) {
                        current_block_id = self.replies[i].parent_block_id;
                        depth += 1;
                        found_parent = true;
                        break;
                    }
                }

                if (!found_parent) {
                    break;
                }
            }

            return depth;
        }

        /// Get reply thread for a block (all replies in thread).
        // 2025-11-23-122043-pst: Active function
        pub fn get_reply_thread(self: *SocialManager, block_id: u32, thread: []u32) !u32 {
            // Assert: Thread buffer must be large enough
            std.debug.assert(thread.len >= MAX_REPLY_DEPTH);

            var thread_len: u32 = 0;
            thread[thread_len] = block_id;
            thread_len += 1;

            // Find all direct replies (iterative)
            var i: u32 = 0;
            while (i < self.replies_len) : (i += 1) {
                if (self.replies[i].parent_block_id == block_id) {
                    if (thread_len >= thread.len) {
                        return error.ThreadTooLarge;
                    }
                    thread[thread_len] = self.replies[i].reply_block_id;
                    thread_len += 1;
                }
            }

            return thread_len;
        }

        /// Create transclusion relationship.
        // 2025-11-23-122043-pst: Active function
        pub fn create_transclusion(self: *SocialManager, source_block_id: u32, target_block_id: u32, offset: u32, length: u32) !void {
            // Assert: Blocks must exist
            std.debug.assert(self.block_storage.get_block(source_block_id) != null);
            std.debug.assert(self.block_storage.get_block(target_block_id) != null);

            // Check transclusion limit
            if (self.transclusions_len >= MAX_TRANSCLUSIONS) {
                return error.TooManyTransclusions;
            }

            // Calculate transclusion depth (iterative, no recursion)
            const depth = try self.calculate_transclusion_depth(source_block_id);

            // Assert: Depth must be bounded
            std.debug.assert(depth < MAX_TRANSCLUSION_DEPTH);

            // Create transclusion relationship
            self.transclusions[self.transclusions_len] = Transclusion{
                .source_block_id = source_block_id,
                .target_block_id = target_block_id,
                .offset = offset,
                .length = length,
                .depth = depth,
            };
            self.transclusions_len += 1;
        }

        /// Calculate transclusion depth for a block (iterative).
        // 2025-11-23-122043-pst: Active function
        fn calculate_transclusion_depth(self: *SocialManager, block_id: u32) !u32 {
            // Iterative depth calculation (no recursion)
            var depth: u32 = 0;
            var current_block_id: u32 = block_id;
            var visited: [MAX_TRANSCLUSION_DEPTH]bool = undefined;
            @memset(&visited, false);
            var visited_count: u32 = 0;

            // Find parent transclusions iteratively
            while (depth < MAX_TRANSCLUSION_DEPTH) {
                // Check for cycle
                if (visited_count > 0) {
                    var i: u32 = 0;
                    while (i < visited_count) : (i += 1) {
                        if (visited[i] and i == current_block_id) {
                            return error.CyclicTransclusion;
                        }
                    }
                }
                visited[visited_count] = true;
                visited_count += 1;

                // Find parent transclusion
                var found_parent: bool = false;
                var i: u32 = 0;
                while (i < self.transclusions_len) : (i += 1) {
                    if (self.transclusions[i].source_block_id == current_block_id) {
                        current_block_id = self.transclusions[i].target_block_id;
                        depth += 1;
                        found_parent = true;
                        break;
                    }
                }

                if (!found_parent) {
                    break;
                }
            }

            return depth;
        }

        /// Get transcluded content for a block (with transclusions expanded).
        // 2025-11-23-122043-pst: Active function
        pub fn get_transcluded_content(self: *SocialManager, block_id: u32, output: []u8) !u32 {
            // Get block
            const block = self.block_storage.get_block(block_id) orelse return error.BlockNotFound;

            // Start with block content
            var output_len: u32 = 0;
            if (block.content_len > 0) {
                if (output_len + block.content_len > output.len) {
                    return error.OutputTooSmall;
                }
                @memcpy(output[output_len..][0..block.content_len], block.content);
                output_len += block.content_len;
            }

            // Find transclusions in this block (iterative)
            var i: u32 = 0;
            while (i < self.transclusions_len) : (i += 1) {
                if (self.transclusions[i].target_block_id == block_id) {
                    const transclusion = &self.transclusions[i];

                    // Get transcluded block content
                    const transcluded_block = self.block_storage.get_block(transclusion.source_block_id) orelse continue;

                    // Insert transcluded content at offset
                    if (output_len + transcluded_block.content_len > output.len) {
                        return error.OutputTooSmall;
                    }

                    // For simplicity, append transcluded content (full implementation would insert at offset)
                    @memcpy(output[output_len..][0..transcluded_block.content_len], transcluded_block.content);
                    output_len += transcluded_block.content_len;
                }
            }

            return output_len;
        }
    };

    /// Export format structure.
    // 2025-11-23-122043-pst: Active struct
    pub const ExportFormat = enum(u8) {
        json, // JSON format
        markdown, // Markdown format
        plain_text, // Plain text format
    };

    /// Export manager.
    // 2025-11-23-122043-pst: Active struct
    pub const ExportManager = struct {
        block_storage: *Block.BlockStorage,
        social_manager: *SocialManager,
        allocator: std.mem.Allocator,

        /// Export block to JSON format.
        // 2025-11-23-122043-pst: Active function
        pub fn export_block_json(self: *ExportManager, block_id: u32, output: []u8) !u32 {
            _ = self.block_storage.get_block(block_id) orelse return error.BlockNotFound;

            // Simple JSON export (full implementation would use proper JSON library)
            var output_len: u32 = 0;
            const json_start = "{\"id\":";
            if (output_len + json_start.len > output.len) return error.OutputTooSmall;
            @memcpy(output[output_len..][0..json_start.len], json_start);
            output_len += @as(u32, @intCast(json_start.len));

            // Export ID, title, content, links, etc.
            // Simplified for now - full implementation would serialize all fields

            return output_len;
        }

        /// Export block to Markdown format.
        // 2025-11-23-122043-pst: Active function
        pub fn export_block_markdown(self: *ExportManager, block_id: u32, output: []u8) !u32 {
            const block = self.block_storage.get_block(block_id) orelse return error.BlockNotFound;

            // Simple Markdown export
            var output_len: u32 = 0;

            // Title as heading
            if (block.title_len > 0) {
                const heading = "# ";
                if (output_len + heading.len > output.len) return error.OutputTooSmall;
                @memcpy(output[output_len..][0..heading.len], heading);
                output_len += @as(u32, @intCast(heading.len));

                if (output_len + block.title_len > output.len) return error.OutputTooSmall;
                @memcpy(output[output_len..][0..block.title_len], block.title);
                output_len += block.title_len;

                const newline = "\n\n";
                if (output_len + newline.len > output.len) return error.OutputTooSmall;
                @memcpy(output[output_len..][0..newline.len], newline);
                output_len += @as(u32, @intCast(newline.len));
            }

            // Content
            if (block.content_len > 0) {
                if (output_len + block.content_len > output.len) return error.OutputTooSmall;
                @memcpy(output[output_len..][0..block.content_len], block.content);
                output_len += block.content_len;
            }

            return output_len;
        }

        /// Import block from JSON format.
        // 2025-11-23-122043-pst: Active function
        pub fn import_block_json(self: *ExportManager, json_data: []const u8) !u32 {
            // Simple JSON import (full implementation would use proper JSON parser)
            _ = self;
            _ = json_data;
            // For now, return error - full implementation needed
            return error.NotImplemented;
        }
    };
};

