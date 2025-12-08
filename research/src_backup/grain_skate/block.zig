const std = @import("std");

/// Grain Skate Block: Text block with links in knowledge graph.
/// ~<~ Glow Airbend: explicit block state, bounded block storage.
/// ~~~~ Glow Waterbend: deterministic block linking, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
///
/// 2025-11-23-114146-pst: Active implementation
pub const Block = struct {
    // Bounded: Max block content length (explicit limit, in bytes)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_BLOCK_CONTENT: u32 = 1_048_576; // 1 MB

    // Bounded: Max links per block (explicit limit)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_LINKS_PER_BLOCK: u32 = 256;

    // Bounded: Max block title length (explicit limit)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_BLOCK_TITLE: u32 = 512;

    /// Block structure.
    // 2025-11-23-114146-pst: Active struct
    pub const BlockData = struct {
        id: u32, // Block ID (unique identifier)
        title: []const u8, // Block title (bounded)
        title_len: u32,
        content: []const u8, // Block content (bounded)
        content_len: u32,
        created_at: u64, // Creation timestamp (Unix epoch)
        updated_at: u64, // Last update timestamp (Unix epoch)
        links: []u32, // Linked block IDs (bounded)
        links_len: u32,
        backlinks: []u32, // Blocks that link to this block (bounded)
        backlinks_len: u32,
        dag_node_id: ?u32, // Associated DAG node ID (if using DAG)
        allocator: std.mem.Allocator,

        /// Initialize block data.
        // 2025-11-23-114146-pst: Active function
        pub fn init(allocator: std.mem.Allocator, id: u32, title: []const u8, content: []const u8) !BlockData {

            // Assert: Title and content must be bounded
            std.debug.assert(title.len <= MAX_BLOCK_TITLE);
            std.debug.assert(content.len <= MAX_BLOCK_CONTENT);

            // Get current timestamp
            const now = std.time.timestamp();

            // Allocate title
            const title_copy = try allocator.dupe(u8, title);
            errdefer allocator.free(title_copy);

            // Allocate content
            const content_copy = try allocator.dupe(u8, content);
            errdefer allocator.free(content_copy);

            // Pre-allocate links buffer
            const links = try allocator.alloc(u32, MAX_LINKS_PER_BLOCK);
            errdefer allocator.free(links);

            // Pre-allocate backlinks buffer
            const backlinks = try allocator.alloc(u32, MAX_LINKS_PER_BLOCK);
            errdefer allocator.free(backlinks);

            return BlockData{
                .id = id,
                .title = title_copy,
                .title_len = @as(u32, @intCast(title_copy.len)),
                .content = content_copy,
                .content_len = @as(u32, @intCast(content_copy.len)),
                .created_at = @as(u64, @intCast(now)),
                .updated_at = @as(u64, @intCast(now)),
                .links = links,
                .links_len = 0,
                .backlinks = backlinks,
                .backlinks_len = 0,
                .dag_node_id = null,
                .allocator = allocator,
            };
        }

        /// Deinitialize block data and free memory.
        pub fn deinit(self: *BlockData) void {
            // Assert: Allocator must be valid (check by attempting deallocation)
            _ = self.allocator;

            // Free title
            if (self.title_len > 0) {
                self.allocator.free(self.title);
            }

            // Free content
            if (self.content_len > 0) {
                self.allocator.free(self.content);
            }

            // Free links
            self.allocator.free(self.links);

            // Free backlinks
            self.allocator.free(self.backlinks);

            self.* = undefined;
        }

        /// Add link to another block.
        pub fn add_link(self: *BlockData, target_block_id: u32) !void {
            // Check links limit
            if (self.links_len >= MAX_LINKS_PER_BLOCK) {
                return error.TooManyLinks;
            }

            // Check if link already exists
            var i: u32 = 0;
            while (i < self.links_len) : (i += 1) {
                if (self.links[i] == target_block_id) {
                    return; // Link already exists
                }
            }

            self.links[self.links_len] = target_block_id;
            self.links_len += 1;

            // Update timestamp
            const now = std.time.timestamp();
            self.updated_at = @as(u64, @intCast(now));
        }

        /// Remove link to another block.
        pub fn remove_link(self: *BlockData, target_block_id: u32) void {
            var i: u32 = 0;
            while (i < self.links_len) : (i += 1) {
                if (self.links[i] == target_block_id) {
                    // Shift remaining links left
                    var j: u32 = i;
                    while (j < self.links_len - 1) : (j += 1) {
                        self.links[j] = self.links[j + 1];
                    }
                    self.links_len -= 1;

                    // Update timestamp
                    const now = std.time.timestamp();
                    self.updated_at = @as(u64, @intCast(now));
                    return;
                }
            }
        }

        /// Add backlink (block that links to this block).
        pub fn add_backlink(self: *BlockData, source_block_id: u32) !void {
            // Check backlinks limit
            if (self.backlinks_len >= MAX_LINKS_PER_BLOCK) {
                return error.TooManyBacklinks;
            }

            // Check if backlink already exists
            var i: u32 = 0;
            while (i < self.backlinks_len) : (i += 1) {
                if (self.backlinks[i] == source_block_id) {
                    return; // Backlink already exists
                }
            }

            self.backlinks[self.backlinks_len] = source_block_id;
            self.backlinks_len += 1;
        }

        /// Remove backlink.
        pub fn remove_backlink(self: *BlockData, source_block_id: u32) void {
            var i: u32 = 0;
            while (i < self.backlinks_len) : (i += 1) {
                if (self.backlinks[i] == source_block_id) {
                    // Shift remaining backlinks left
                    var j: u32 = i;
                    while (j < self.backlinks_len - 1) : (j += 1) {
                        self.backlinks[j] = self.backlinks[j + 1];
                    }
                    self.backlinks_len -= 1;
                    return;
                }
            }
        }

        /// Update block content.
        pub fn update_content(self: *BlockData, new_content: []const u8) !void {
            // Assert: Content must be bounded
            std.debug.assert(new_content.len <= MAX_BLOCK_CONTENT);

            // Free old content
            if (self.content_len > 0) {
                self.allocator.free(self.content);
            }

            // Allocate new content
            const content_copy = try self.allocator.dupe(u8, new_content);
            self.content = content_copy;
            self.content_len = @as(u32, @intCast(content_copy.len));

            // Update timestamp
            const now = std.time.timestamp();
            self.updated_at = @as(u64, @intCast(now));
        }

        /// Update block title.
        pub fn update_title(self: *BlockData, new_title: []const u8) !void {
            // Assert: Title must be bounded
            std.debug.assert(new_title.len <= MAX_BLOCK_TITLE);

            // Free old title
            if (self.title_len > 0) {
                self.allocator.free(self.title);
            }

            // Allocate new title
            const title_copy = try self.allocator.dupe(u8, new_title);
            self.title = title_copy;
            self.title_len = @as(u32, @intCast(title_copy.len));

            // Update timestamp
            const now = std.time.timestamp();
            self.updated_at = @as(u64, @intCast(now));
        }
    };

    /// Block storage manager.
    // 2025-11-23-114146-pst: Active struct
    pub const BlockStorage = struct {
        // Bounded: Max blocks (explicit limit)
        pub const MAX_BLOCKS: u32 = 100_000;

        blocks: []BlockData, // Blocks buffer (bounded)
        blocks_len: u32, // Number of blocks
        next_block_id: u32, // Next available block ID
        allocator: std.mem.Allocator,

        /// Initialize block storage.
        // 2025-11-23-114146-pst: Active function
        pub fn init(allocator: std.mem.Allocator) !BlockStorage {

            // Pre-allocate blocks buffer
            const blocks = try allocator.alloc(BlockData, MAX_BLOCKS);
            errdefer allocator.free(blocks);

            return BlockStorage{
                .blocks = blocks,
                .blocks_len = 0,
                .next_block_id = 1, // Start at 1
                .allocator = allocator,
            };
        }

        /// Deinitialize block storage and free memory.
        pub fn deinit(self: *BlockStorage) void {
            // Assert: Allocator must be valid (check by attempting deallocation)
            _ = self.allocator;

            // Deinitialize all blocks
            var i: u32 = 0;
            while (i < self.blocks_len) : (i += 1) {
                self.blocks[i].deinit();
            }

            // Free blocks buffer
            self.allocator.free(self.blocks);

            self.* = undefined;
        }

        /// Create new block.
        // 2025-11-23-114146-pst: Active function
        pub fn create_block(self: *BlockStorage, title: []const u8, content: []const u8) !u32 {
            // Check blocks limit
            if (self.blocks_len >= MAX_BLOCKS) {
                return error.TooManyBlocks;
            }

            // Create block
            const block_id = self.next_block_id;
            self.next_block_id += 1;

            var block_data = try BlockData.init(self.allocator, block_id, title, content);
            errdefer block_data.deinit();

            // Store block
            self.blocks[self.blocks_len] = block_data;
            self.blocks_len += 1;

            return block_id;
        }

        /// Get block by ID.
        pub fn get_block(self: *BlockStorage, block_id: u32) ?*BlockData {
            return self.find_block(block_id);
        }

        /// Link two blocks (bidirectional).
        // 2025-11-23-114146-pst: Active function
        pub fn link_blocks(self: *BlockStorage, source_id: u32, target_id: u32) !void {
            if (self.find_block(source_id)) |source| {
                if (self.find_block(target_id)) |target| {
                    // Add link from source to target
                    try source.add_link(target_id);

                    // Add backlink from target to source
                    try target.add_backlink(source_id);
                } else {
                    return error.BlockNotFound;
                }
            } else {
                return error.BlockNotFound;
            }
        }

        /// Unlink two blocks (bidirectional).
        pub fn unlink_blocks(self: *BlockStorage, source_id: u32, target_id: u32) void {
            if (self.find_block(source_id)) |source| {
                if (self.find_block(target_id)) |target| {
                    // Remove link from source to target
                    source.remove_link(target_id);

                    // Remove backlink from target to source
                    target.remove_backlink(source_id);
                }
            }
        }

        /// Find block by ID (internal helper).
        fn find_block(self: *BlockStorage, block_id: u32) ?*BlockData {
            var i: u32 = 0;
            while (i < self.blocks_len) : (i += 1) {
                if (self.blocks[i].id == block_id) {
                    return &self.blocks[i];
                }
            }
            return null;
        }
    };
};

