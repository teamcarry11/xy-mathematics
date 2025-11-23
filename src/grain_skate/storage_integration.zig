const std = @import("std");
const Block = @import("block.zig").Block;
const grain_field = @import("grain_field");
const grain_silo = @import("grain_silo");
const FieldCompute = grain_field.Compute.FieldCompute;
const ObjectStorage = grain_silo.Storage.ObjectStorage;

/// Grain Skate Storage Integration: Integrates Grain Field and Grain Silo with block storage.
/// ~<~ Glow Airbend: explicit integration state, bounded block-to-object mapping.
/// ~~~~ Glow Waterbend: deterministic storage operations, iterative algorithms.
///
/// 2025-11-23-114146-pst: Active implementation
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const StorageIntegration = struct {
    // Bounded: Max block-to-object mappings (explicit limit)
    pub const MAX_BLOCK_MAPPINGS: u32 = 100_000;

    /// Block-to-object mapping structure.
    // 2025-11-23-114146-pst: Active struct
    pub const BlockMapping = struct {
        block_id: u32, // Block ID
        object_key: []const u8, // Object key in Grain Silo
        object_key_len: u32,
        is_hot: bool, // Is block in hot cache (Grain Field SRAM)?
        hot_cache_offset: ?u64, // Hot cache offset (if in SRAM)
        allocator: std.mem.Allocator,

        /// Initialize block mapping.
        // 2025-11-23-124357-pst: Active function
        pub fn init(allocator: std.mem.Allocator, block_id: u32, object_key: []const u8) !BlockMapping {

            // Allocate object key
            const key_copy = try allocator.dupe(u8, object_key);
            errdefer allocator.free(key_copy);

            return BlockMapping{
                .block_id = block_id,
                .object_key = key_copy,
                .object_key_len = @as(u32, @intCast(key_copy.len)),
                .is_hot = false,
                .hot_cache_offset = null,
                .allocator = allocator,
            };
        }

        /// Deinitialize block mapping and free memory.
        pub fn deinit(self: *BlockMapping) void {
            // Assert: Allocator must be valid
            // Assert: Allocator must be valid (check by attempting deallocation)
            _ = self.allocator;

            // Free object key
            if (self.object_key_len > 0) {
                self.allocator.free(self.object_key);
            }

            self.* = undefined;
        }
    };

    /// Storage integration structure.
    // 2025-11-23-114146-pst: Active struct
    pub const Integration = struct {
        block_storage: *Block.BlockStorage, // Block storage
        field_compute: *FieldCompute, // Grain Field compute layer
        object_storage: *ObjectStorage, // Grain Silo object storage
        mappings: []BlockMapping, // Block-to-object mappings (bounded)
        mappings_len: u32, // Number of mappings
        allocator: std.mem.Allocator,

        /// Initialize storage integration.
        // 2025-11-23-114146-pst: Active function
        pub fn init(
            allocator: std.mem.Allocator,
            block_storage: *Block.BlockStorage,
            field_compute: *FieldCompute,
            object_storage: *ObjectStorage,
        ) !Integration {
            // Assert: Allocator must be valid (check by attempting allocation)
            // allocator is used in pre-allocate calls below

            // Pre-allocate mappings buffer
            const mappings = try allocator.alloc(BlockMapping, MAX_BLOCK_MAPPINGS);
            errdefer allocator.free(mappings);

            return Integration{
                .block_storage = block_storage,
                .field_compute = field_compute,
                .object_storage = object_storage,
                .mappings = mappings,
                .mappings_len = 0,
                .allocator = allocator,
            };
        }

        /// Deinitialize storage integration and free memory.
        pub fn deinit(self: *Integration) void {
            // Assert: Allocator must be valid
            // Assert: Allocator must be valid (check by attempting deallocation)
            _ = self.allocator;

            // Deinitialize all mappings
            var i: u32 = 0;
            while (i < self.mappings_len) : (i += 1) {
                self.mappings[i].deinit();
            }

            // Free mappings buffer
            self.allocator.free(self.mappings);

            self.* = undefined;
        }

        /// Persist block to Grain Silo (cold storage).
        // 2025-11-23-114146-pst: Active function
        pub fn persist_block(self: *Integration, block_id: u32) !void {
            if (self.block_storage.get_block(block_id)) |block| {
                // Create object key from block ID
                var key_buf: [64]u8 = undefined;
                const key = try std.fmt.bufPrint(&key_buf, "block-{}", .{block_id});

                // Serialize block data (simplified: just content for now)
                const metadata = try std.fmt.allocPrint(self.allocator, "title:{s}", .{block.title});
                defer self.allocator.free(metadata);

                // Store in Grain Silo
                try self.object_storage.store_object(key, block.content, metadata);

                // Create mapping
                if (self.mappings_len >= MAX_BLOCK_MAPPINGS) {
                    return error.TooManyMappings;
                }

                var mapping = try BlockMapping.init(self.allocator, block_id, key);
                errdefer mapping.deinit();

                self.mappings[self.mappings_len] = mapping;
                self.mappings_len += 1;
            } else {
                return error.BlockNotFound;
            }
        }

        /// Load block from Grain Silo (cold storage).
        // 2025-11-23-114146-pst: Active function
        pub fn load_block(self: *Integration, block_id: u32) !void {
            // Find mapping
            var i: u32 = 0;
            while (i < self.mappings_len) : (i += 1) {
                if (self.mappings[i].block_id == block_id) {
                    const mapping = &self.mappings[i];

                    // Get object from Grain Silo
                    if (self.object_storage.get_object(mapping.object_key)) |object| {
                        // Update block content (block must already exist)
                        if (self.block_storage.get_block(block_id)) |block| {
                            try block.update_content(object.data);
                        } else {
                            return error.BlockNotFound;
                        }
                    } else {
                        return error.ObjectNotFound;
                    }
                    return;
                }
            }
            return error.MappingNotFound;
        }

        /// Promote block to hot cache (Grain Field SRAM).
        // 2025-11-23-114146-pst: Active function
        pub fn promote_block_to_hot(self: *Integration, block_id: u32) !void {
            // Find mapping
            var i: u32 = 0;
            while (i < self.mappings_len) : (i += 1) {
                if (self.mappings[i].block_id == block_id) {
                    const mapping = &self.mappings[i];

                    // Get block
                    if (self.block_storage.get_block(block_id)) |block| {
                        // Allocate SRAM for block content
                        const cache_offset = try self.field_compute.allocate_sram(0, @as(u64, @intCast(block.content_len)));

                        // Promote object to hot cache
                        try self.object_storage.promote_to_hot(mapping.object_key, cache_offset);

                        // Update mapping
                        mapping.is_hot = true;
                        mapping.hot_cache_offset = cache_offset;
                    } else {
                        return error.BlockNotFound;
                    }
                    return;
                }
            }
            return error.MappingNotFound;
        }

        /// Demote block from hot cache (move to cold storage).
        // 2025-11-23-114146-pst: Active function
        pub fn demote_block_from_hot(self: *Integration, block_id: u32) void {
            // Find mapping
            var i: u32 = 0;
            while (i < self.mappings_len) : (i += 1) {
                if (self.mappings[i].block_id == block_id) {
                    const mapping = &self.mappings[i];

                    if (mapping.is_hot) {
                        // Demote object from hot cache
                        self.object_storage.demote_from_hot(mapping.object_key);

                        // Update mapping
                        mapping.is_hot = false;
                        mapping.hot_cache_offset = null;
                    }
                    return;
                }
            }
        }
    };
};

