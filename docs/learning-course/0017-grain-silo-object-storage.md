# Grain Silo: Object Storage Abstraction

**Prerequisites**: Grain OS Architecture (0010), Grain Field (0016)  
**Focus**: Object storage abstraction (Turbopuffer replacement) with hot/cold data separation  
**GrainStyle**: Explicit object limits, bounded storage, deterministic operations

## What is Grain Silo?

Grain Silo is an object storage abstraction that provides:

- **S3-compatible storage**: Store objects with keys, data, and metadata
- **Hot/cold separation**: Hot data in SRAM (Grain Field), cold data in object storage
- **Automatic promotion/demotion**: Move data between hot and cold based on usage
- **Bounded storage**: Explicit limits on object count and size

**Why Grain Silo?**

- **Turbopuffer replacement**: Open-source alternative to proprietary storage
- **Hot cache integration**: Works with Grain Field SRAM for fast access
- **Scalable**: Handles millions of objects with bounded memory
- **Deterministic**: Predictable performance with explicit limits

## Object Structure

### Object Data

```zig
pub const Object = struct {
    key: []const u8,            // Object key (bounded: MAX_OBJECT_KEY_LEN = 1KB)
    key_len: u32,
    data: []const u8,           // Object data (bounded: MAX_OBJECT_SIZE = 1GB)
    data_len: u64,
    metadata: []const u8,       // Object metadata (bounded: MAX_METADATA_SIZE = 64KB)
    metadata_len: u32,
    created_at: u64,            // Creation timestamp
    updated_at: u64,            // Last update timestamp
    is_hot: bool,               // Is object in hot cache (SRAM)?
    hot_cache_offset: ?u64,     // Hot cache offset (if in SRAM)
    allocator: std.mem.Allocator,
};
```

**Why These Fields?**

- **key**: Unique identifier for object lookup
- **data**: Object content (bounded size)
- **metadata**: Additional metadata (tags, properties)
- **is_hot/hot_cache_offset**: Hot cache tracking

### Object Storage Manager

```zig
pub const ObjectStorage = struct {
    objects: []Object,          // Pre-allocated objects buffer
    objects_len: u32,           // Number of objects
    hot_cache_size: u64,        // Hot cache capacity (SRAM size)
    hot_cache_used: u64,        // Hot cache used (bytes)
    allocator: std.mem.Allocator,
    
    pub const MAX_OBJECT_KEY_LEN: u32 = 1_024;      // 1 KB
    pub const MAX_OBJECT_SIZE: u64 = 1_073_741_824; // 1 GB
    pub const MAX_OBJECTS: u32 = 1_000_000;
    pub const MAX_METADATA_SIZE: u32 = 65_536;     // 64 KB
};
```

**Why Bounded?**

- **MAX_OBJECT_KEY_LEN**: Maximum key length
- **MAX_OBJECT_SIZE**: Maximum object size (1GB)
- **MAX_OBJECTS**: Maximum number of objects
- **MAX_METADATA_SIZE**: Maximum metadata size

## Storing Objects

### Store Object (Cold Storage)

```zig
pub fn store_object(
    self: *ObjectStorage,
    key: []const u8,
    data: []const u8,
    metadata: []const u8
) !void {
    // Assert: Bounds checking
    std.debug.assert(key.len <= MAX_OBJECT_KEY_LEN);
    std.debug.assert(data.len <= MAX_OBJECT_SIZE);
    std.debug.assert(metadata.len <= MAX_METADATA_SIZE);
    std.debug.assert(self.objects_len < MAX_OBJECTS);
    
    // Check if object already exists
    if (self.get_object(key)) |existing| {
        // Update existing object
        try existing.update_data(data);
        try existing.update_metadata(metadata);
        return;
    }
    
    // Create new object
    const object = try Object.init(self.allocator, key, data, metadata);
    self.objects[self.objects_len] = object;
    self.objects_len += 1;
}
```

**GrainStyle Principles:**

- **Explicit bounds**: All limits checked
- **Assertions**: Preconditions verified
- **Deterministic**: Same input = same output

## Hot Cache Management

### Promote to Hot Cache

```zig
pub fn promote_to_hot(
    self: *ObjectStorage,
    key: []const u8,
    cache_offset: u64
) !void {
    const object = self.get_object(key) orelse return error.ObjectNotFound;
    
    // Assert: Cache offset valid
    std.debug.assert(cache_offset + object.data_len <= self.hot_cache_size);
    std.debug.assert(self.hot_cache_used + object.data_len <= self.hot_cache_size);
    
    // Mark as hot
    object.is_hot = true;
    object.hot_cache_offset = cache_offset;
    self.hot_cache_used += object.data_len;
    
    // Copy data to hot cache (would integrate with Grain Field SRAM)
    // @memcpy(hot_cache[cache_offset..][0..object.data_len], object.data);
}
```

**Why Hot Cache?**

- **Fast access**: SRAM is faster than object storage
- **Frequently used**: Hot data accessed more often
- **Limited capacity**: Only frequently used data in SRAM

### Demote from Hot Cache

```zig
pub fn demote_from_hot(
    self: *ObjectStorage,
    key: []const u8
) void {
    const object = self.get_object(key) orelse return;
    
    if (object.is_hot) {
        // Update hot cache usage
        self.hot_cache_used -= object.data_len;
        
        // Mark as cold
        object.is_hot = false;
        object.hot_cache_offset = null;
    }
}
```

**Why Demote?**

- **Cache eviction**: Make room for new hot data
- **LRU policy**: Least recently used data demoted
- **Bounded cache**: Keep hot cache within capacity

## Object Lookup

### Get Object by Key

```zig
pub fn get_object(
    self: *ObjectStorage,
    key: []const u8
) ?*Object {
    // Iterative search (no recursion)
    var i: u32 = 0;
    while (i < self.objects_len) : (i += 1) {
        if (std.mem.eql(u8, self.objects[i].key, key)) {
            return &self.objects[i];
        }
    }
    return null;
}
```

**Why Iterative?**

- **Bounded**: Search limited by object count
- **Predictable**: O(n) worst case
- **No recursion**: Stack-safe

## Integration with Grain Field

### Hot Cache in SRAM

```zig
// Store object in Grain Silo
try silo.store_object("block-123", block_content, metadata);

// Promote to hot cache (Grain Field SRAM)
const cache_offset = try field_compute.allocate_sram(0, block_content.len);
try silo.promote_to_hot("block-123", cache_offset);

// Access hot data from SRAM
const hot_data = field_compute.sram_data[cache_offset..][0..block_content.len];
```

**Why Integration?**

- **Fast access**: Hot data in SRAM (Grain Field)
- **Cold storage**: Less frequently used data in Grain Silo
- **Automatic**: Promotion/demotion based on usage

## Use Cases

### 1. Block Storage Persistence

```zig
// Persist block to Grain Silo
try silo.store_object(
    "block-123",
    block.content,
    "title:My Block"
);

// Promote to hot cache for fast access
const cache_offset = try field_compute.allocate_sram(0, block.content.len);
try silo.promote_to_hot("block-123", cache_offset);
```

### 2. AI Model Data

```zig
// Store AI model weights
try silo.store_object(
    "model-weights-v1",
    weights_data,
    "model:glm-4.6,size:7B"
);

// Promote to hot cache for inference
const cache_offset = try field_compute.allocate_sram(0, weights_data.len);
try silo.promote_to_hot("model-weights-v1", cache_offset);
```

### 3. Browser Cache

```zig
// Store web page cache
try silo.store_object(
    "cache:https://example.com",
    page_html,
    "content-type:text/html"
);

// Promote to hot cache for fast rendering
const cache_offset = try field_compute.allocate_sram(0, page_html.len);
try silo.promote_to_hot("cache:https://example.com", cache_offset);
```

## Exercises

1. **Store Object**: Store an object in Grain Silo
2. **Promote to Hot**: Promote object to hot cache
3. **Demote from Hot**: Demote object from hot cache
4. **Lookup**: Find object by key

## Connections

- **Previous**: Grain Field (0016) - SRAM hot cache
- **Next**: Storage Integration (0020) - Integrating with block storage
- **Related**: Export/Import (0014) - Serializing objects

---

**Key Takeaway**: Grain Silo provides object storage with hot/cold separation. Integration with Grain Field enables fast access to frequently used data.

