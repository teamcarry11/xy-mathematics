# Grain Field: WSE Compute Abstraction

**Prerequisites**: Grain OS Architecture (0010), GrainStyle Principles (0009)  
**Focus**: WSE (Wafer-Scale Engine) RAM-only spatial computing abstraction  
**GrainStyle**: Explicit SRAM management, bounded cores, iterative parallel operations

## What is Grain Field?

Grain Field is an abstraction for WSE (Wafer-Scale Engine) RAM-only spatial computing. It represents:

- **44GB+ on-wafer SRAM**: Massive on-chip memory (no DRAM needed)
- **900k cores**: Parallel processing cores in a 2D grid
- **Field topology**: 2D grid with wrap-around (toroidal topology)
- **Spatial computing**: Data flows through cores, not fetched from memory

**Why Grain Field?**

- **Future hardware**: Targets open-hardware WSE equivalents
- **RAM-only**: No DRAM latency—everything in SRAM
- **Massive parallelism**: 900k cores for parallel operations
- **Spatial computing**: Data flows spatially, not temporally

## Field Compute Structure

### Core Structure

```zig
pub const Core = struct {
    id: u32,                    // Core ID (unique identifier)
    state: CoreState,           // Core state (idle, active, waiting, error_state)
    sram_offset: u64,           // SRAM offset for this core's data
    sram_size: u64,             // SRAM size allocated to this core
    neighbors: []u32,            // Neighboring core IDs (field topology)
    neighbors_len: u32,
};
```

**Why These Fields?**

- **id**: Unique identifier for core lookup
- **state**: Current execution state
- **sram_offset/size**: SRAM allocation for this core
- **neighbors**: Adjacent cores in 2D grid (for dataflow)

### Field Compute Manager

```zig
pub const FieldCompute = struct {
    cores: []Core,              // Pre-allocated cores buffer
    cores_len: u32,             // Number of cores
    sram_capacity: u64,         // Total SRAM capacity (bytes)
    sram_used: u64,             // SRAM used (bytes)
    sram_data: []u8,            // SRAM data buffer
    parallel_ops: []ParallelOp, // Parallel operations queue
    parallel_ops_len: u32,
    allocator: std.mem.Allocator,
    
    pub const MAX_CORES: u32 = 1_000_000;        // 900k + headroom
    pub const MAX_SRAM_CAPACITY: u64 = 47_185_920_000;  // 44GB + headroom
    pub const MAX_PARALLEL_OPS: u32 = 10_000;
};
```

**Why Bounded?**

- **MAX_CORES**: Maximum number of cores (900k + headroom)
- **MAX_SRAM_CAPACITY**: Maximum SRAM capacity (44GB + headroom)
- **MAX_PARALLEL_OPS**: Maximum concurrent operations

## SRAM Allocation

### Allocating SRAM for Core

```zig
pub fn allocate_sram(
    self: *FieldCompute,
    core_id: u32,
    size: u64
) !u64 {
    // Assert: Core must exist
    std.debug.assert(core_id < self.cores_len);
    
    // Assert: Size must be bounded
    std.debug.assert(size <= MAX_SRAM_CAPACITY);
    std.debug.assert(self.sram_used + size <= self.sram_capacity);
    
    // Get core
    const core = &self.cores[core_id];
    
    // Allocate SRAM (simple linear allocator)
    const offset = self.sram_used;
    self.sram_used += size;
    
    // Update core
    core.sram_offset = offset;
    core.sram_size = size;
    core.state = .active;
    
    return offset;
}
```

**Why Linear Allocation?**

- **Simple**: No fragmentation
- **Fast**: O(1) allocation
- **Bounded**: Total capacity is fixed

## Field Topology (2D Grid)

### Calculating Neighbors

```zig
fn calculate_neighbors(
    self: *FieldCompute,
    core_id: u32,
    grid_width: u32,
    grid_height: u32
) void {
    const core = &self.cores[core_id];
    
    // Calculate 2D position
    const x = core_id % grid_width;
    const y = core_id / grid_width;
    
    // Calculate neighbors (with wrap-around)
    var neighbors: [4]u32 = undefined;
    var neighbors_len: u32 = 0;
    
    // North (wrap-around)
    const north_y = if (y == 0) grid_height - 1 else y - 1;
    neighbors[neighbors_len] = north_y * grid_width + x;
    neighbors_len += 1;
    
    // South (wrap-around)
    const south_y = if (y == grid_height - 1) 0 else y + 1;
    neighbors[neighbors_len] = south_y * grid_width + x;
    neighbors_len += 1;
    
    // West (wrap-around)
    const west_x = if (x == 0) grid_width - 1 else x - 1;
    neighbors[neighbors_len] = y * grid_width + west_x;
    neighbors_len += 1;
    
    // East (wrap-around)
    const east_x = if (x == grid_width - 1) 0 else x + 1;
    neighbors[neighbors_len] = y * grid_width + east_x;
    neighbors_len += 1;
    
    // Store neighbors
    core.neighbors = neighbors[0..neighbors_len];
    core.neighbors_len = neighbors_len;
}
```

**Why Toroidal Topology?**

- **No edges**: Every core has 4 neighbors
- **Uniform**: Same connectivity everywhere
- **Dataflow**: Data can flow in any direction

## Parallel Operations

### Operation Types

```zig
pub const OpType = enum(u8) {
    vector_search,      // Vector similarity search
    fulltext_search,    // Full-text search (BM25)
    matrix_multiply,    // Matrix multiplication
    data_transform,     // Data transformation
};
```

### Executing Parallel Operations

```zig
pub fn execute_parallel(
    self: *FieldCompute,
    op_type: OpType,
    core_ids: []const u32,
    data_offset: u64,
    data_size: u64
) !u32 {
    // Assert: Bounds checking
    std.debug.assert(core_ids.len <= MAX_CORES);
    std.debug.assert(self.parallel_ops_len < MAX_PARALLEL_OPS);
    
    // Create operation
    const op_id = self.parallel_ops_len;
    self.parallel_ops[op_id] = ParallelOp{
        .op_id = op_id,
        .op_type = op_type,
        .core_ids = try self.allocator.dupe(u32, core_ids),
        .core_ids_len = @as(u32, @intCast(core_ids.len)),
        .data_offset = data_offset,
        .data_size = data_size,
        .status = .pending,
    };
    self.parallel_ops_len += 1;
    
    // Execute on cores (iterative, no recursion)
    var i: u32 = 0;
    while (i < core_ids.len) : (i += 1) {
        const core = self.get_core(core_ids[i]) orelse continue;
        core.state = .active;
        // Execute operation on core
    }
    
    return op_id;
}
```

**Why Parallel?**

- **Massive parallelism**: 900k cores can work simultaneously
- **Spatial computing**: Data flows through cores
- **No memory bottleneck**: Everything in SRAM

## Use Cases

### 1. Vector Search

```zig
// Search for similar vectors across 900k cores
const op_id = try field_compute.execute_parallel(
    .vector_search,
    &core_ids,      // All cores
    vector_offset,  // Vector data in SRAM
    vector_size
);
```

### 2. Full-Text Search

```zig
// BM25 search across cores
const op_id = try field_compute.execute_parallel(
    .fulltext_search,
    &core_ids,
    text_offset,
    text_size
);
```

### 3. Matrix Multiplication

```zig
// Parallel matrix multiply
const op_id = try field_compute.execute_parallel(
    .matrix_multiply,
    &core_ids,
    matrix_offset,
    matrix_size
);
```

## Exercises

1. **Allocate SRAM**: Allocate SRAM for a core
2. **Calculate Neighbors**: Implement toroidal neighbor calculation
3. **Execute Operation**: Execute a parallel operation
4. **Track State**: Monitor core states during execution

## Connections

- **Related**: Grain Silo (0017) - Object storage integration
- **Related**: Storage Integration (0020) - Hot cache in SRAM
- **Future**: WSE hardware implementation

---

**Key Takeaway**: Grain Field abstracts WSE RAM-only spatial computing. Bounded cores and SRAM ensure predictable, safe parallel operations.

