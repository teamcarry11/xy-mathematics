const std = @import("std");

/// Grain Silo: Object storage abstraction (Turbopuffer replacement).
/// ~<~ Glow Airbend: explicit storage state, bounded object management.
/// ~~~~ Glow Waterbend: deterministic storage operations, iterative algorithms.
///
/// Represents the storage layer: S3-compatible object storage for cold data,
/// with hot cache integration via Grain Field SRAM.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
///
/// 2025-11-23-114146-pst: Active implementation
pub const Storage = struct {
    // Bounded: Max object key length (explicit limit)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_OBJECT_KEY_LEN: u32 = 1_024;

    // Bounded: Max object size (explicit limit, in bytes)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_OBJECT_SIZE: u64 = 1_073_741_824; // 1 GB

    // Bounded: Max objects (explicit limit)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_OBJECTS: u32 = 1_000_000;

    // Bounded: Max metadata size (explicit limit, in bytes)
    // 2025-11-23-114146-pst: Active constant
    pub const MAX_METADATA_SIZE: u32 = 65_536; // 64 KB

    /// Object structure.
    // 2025-11-23-114146-pst: Active struct
    pub const Object = struct {
        key: []const u8, // Object key (bounded)
        key_len: u32,
        data: []const u8, // Object data (bounded)
        data_len: u64,
        metadata: []const u8, // Object metadata (bounded)
        metadata_len: u32,
        created_at: u64, // Creation timestamp (Unix epoch)
        updated_at: u64, // Last update timestamp (Unix epoch)
        is_hot: bool, // Is object in hot cache (Grain Toroid SRAM)?
        hot_cache_offset: ?u64, // Hot cache offset (if in SRAM)
        allocator: std.mem.Allocator,

        /// Initialize object.
        // 2025-11-23-114146-pst: Active function
        pub fn init(allocator: std.mem.Allocator, key: []const u8, data: []const u8, metadata: []const u8) !Object {

            // Assert: Key, data, and metadata must be bounded
            std.debug.assert(key.len <= MAX_OBJECT_KEY_LEN);
            std.debug.assert(data.len <= MAX_OBJECT_SIZE);
            std.debug.assert(metadata.len <= MAX_METADATA_SIZE);

            // Get current timestamp
            const now = std.time.timestamp();

            // Allocate key
            const key_copy = try allocator.dupe(u8, key);
            errdefer allocator.free(key_copy);

            // Allocate data
            const data_copy = try allocator.dupe(u8, data);
            errdefer allocator.free(data_copy);

            // Allocate metadata
            const metadata_copy = try allocator.dupe(u8, metadata);
            errdefer allocator.free(metadata_copy);

            return Object{
                .key = key_copy,
                .key_len = @as(u32, @intCast(key_copy.len)),
                .data = data_copy,
                .data_len = @as(u64, @intCast(data_copy.len)),
                .metadata = metadata_copy,
                .metadata_len = @as(u32, @intCast(metadata_copy.len)),
                .created_at = @as(u64, @intCast(now)),
                .updated_at = @as(u64, @intCast(now)),
                .is_hot = false,
                .hot_cache_offset = null,
                .allocator = allocator,
            };
        }

        /// Deinitialize object and free memory.
        pub fn deinit(self: *Object) void {
            // Assert: Allocator must be valid
            std.debug.assert(self.allocator.ptr != null);

            // Free key
            if (self.key_len > 0) {
                self.allocator.free(self.key);
            }

            // Free data
            if (self.data_len > 0) {
                self.allocator.free(self.data);
            }

            // Free metadata
            if (self.metadata_len > 0) {
                self.allocator.free(self.metadata);
            }

            self.* = undefined;
        }

        /// Mark object as hot (in SRAM cache).
        pub fn mark_hot(self: *Object, cache_offset: u64) void {
            self.is_hot = true;
            self.hot_cache_offset = cache_offset;
        }

        /// Mark object as cold (not in SRAM cache).
        pub fn mark_cold(self: *Object) void {
            self.is_hot = false;
            self.hot_cache_offset = null;
        }
    };

    /// Object storage structure.
    // 2025-11-23-114146-pst: Active struct
    pub const ObjectStorage = struct {
        objects: []Object, // Objects buffer (bounded)
        objects_len: u32, // Number of objects
        hot_cache_size: u64, // Hot cache size (SRAM capacity)
        hot_cache_used: u64, // Hot cache used (bytes)
        allocator: std.mem.Allocator,

        /// Initialize object storage.
        // 2025-11-23-114146-pst: Active function
        pub fn init(allocator: std.mem.Allocator, hot_cache_size: u64) !ObjectStorage {
            // Assert: Allocator must be valid (check by attempting allocation)
            _ = allocator;

            // Pre-allocate objects buffer
            const objects = try allocator.alloc(Object, MAX_OBJECTS);
            errdefer allocator.free(objects);

            return ObjectStorage{
                .objects = objects,
                .objects_len = 0,
                .hot_cache_size = hot_cache_size,
                .hot_cache_used = 0,
                .allocator = allocator,
            };
        }

        /// Deinitialize object storage and free memory.
        pub fn deinit(self: *ObjectStorage) void {
            // Assert: Allocator must be valid (check by attempting allocation)
            _ = self.allocator;

            // Deinitialize all objects
            var i: u32 = 0;
            while (i < self.objects_len) : (i += 1) {
                self.objects[i].deinit();
            }

            // Free objects buffer
            self.allocator.free(self.objects);

            self.* = undefined;
        }

        /// Store object (cold storage).
        // 2025-11-23-114146-pst: Active function
        pub fn store_object(self: *ObjectStorage, key: []const u8, data: []const u8, metadata: []const u8) !void {
            // Check objects limit
            if (self.objects_len >= MAX_OBJECTS) {
                return error.TooManyObjects;
            }

            // Check if object already exists
            if (self.find_object(key)) |_| {
                return error.ObjectExists;
            }

            // Create object
            var object = try Object.init(self.allocator, key, data, metadata);
            errdefer object.deinit();

            // Store object
            self.objects[self.objects_len] = object;
            self.objects_len += 1;
        }

        /// Get object by key.
        pub fn get_object(self: *ObjectStorage, key: []const u8) ?*Object {
            return self.find_object(key);
        }

        /// Promote object to hot cache (move to SRAM).
        // 2025-11-23-114146-pst: Active function
        pub fn promote_to_hot(self: *ObjectStorage, key: []const u8, cache_offset: u64) !void {
            if (self.find_object(key)) |object| {
                // Check hot cache capacity
                if (self.hot_cache_used + object.data_len > self.hot_cache_size) {
                    return error.HotCacheFull;
                }

                // Mark as hot
                object.mark_hot(cache_offset);
                self.hot_cache_used += object.data_len;
            } else {
                return error.ObjectNotFound;
            }
        }

        /// Demote object from hot cache (move to cold storage).
        pub fn demote_from_hot(self: *ObjectStorage, key: []const u8) void {
            if (self.find_object(key)) |object| {
                if (object.is_hot) {
                    self.hot_cache_used -= object.data_len;
                    object.mark_cold();
                }
            }
        }

        /// Find object by key (internal helper).
        fn find_object(self: *ObjectStorage, key: []const u8) ?*Object {
            var i: u32 = 0;
            while (i < self.objects_len) : (i += 1) {
                if (std.mem.eql(u8, self.objects[i].key, key)) {
                    return &self.objects[i];
                }
            }
            return null;
        }
    };
};

