# Knowledge Graphs and Block-Based Content

**Prerequisites**: GrainStyle principles (0009), Grain OS architecture (0010)  
**Focus**: Block-based knowledge graph architecture as used in Grain Skate  
**GrainStyle**: Explicit block structure, bounded storage, iterative algorithms

## What is a Knowledge Graph?

A knowledge graph is a data structure that represents information as nodes (blocks) connected by edges (links). Unlike traditional documents, knowledge graphs enable:

- **Bidirectional linking**: Blocks can link to each other, creating a web of relationships
- **Non-linear navigation**: Follow links to explore related concepts
- **Social threading**: Blocks can reply to each other, creating conversation threads
- **Transclusion**: Blocks can embed other blocks, creating composite content

**Why Knowledge Graphs for Grain Skate?**

- **Local-first**: All data stored locally, no cloud dependency
- **Social**: Built-in reply and threading capabilities
- **Flexible**: Blocks can represent thoughts, notes, conversations, or any content
- **GrainStyle**: Explicit limits, bounded storage, deterministic operations

## Block Structure

### Core Block Data

```zig
pub const BlockData = struct {
    id: u32,                    // Unique block identifier
    title: []const u8,          // Block title (bounded: MAX_BLOCK_TITLE = 512)
    title_len: u32,
    content: []const u8,         // Block content (bounded: MAX_BLOCK_CONTENT = 1MB)
    content_len: u32,
    created_at: u64,            // Creation timestamp (Unix epoch)
    updated_at: u64,            // Last update timestamp
    links: []u32,               // Linked block IDs (bounded: MAX_LINKS_PER_BLOCK = 256)
    links_len: u32,
    backlinks: []u32,            // Blocks that link to this block
    backlinks_len: u32,
    dag_node_id: ?u32,          // Associated DAG node ID (optional)
    allocator: std.mem.Allocator,
};
```

**Why These Fields?**

- **ID**: Unique identifier for block lookup
- **Title/Content**: Text content with explicit size limits
- **Links/Backlinks**: Bidirectional linking (links = outgoing, backlinks = incoming)
- **Timestamps**: Track creation and updates
- **DAG Node ID**: Optional integration with DAG-based UI architecture

### Bounded Storage

Every limit is explicit:

```zig
pub const MAX_BLOCK_CONTENT: u32 = 1_048_576;  // 1 MB
pub const MAX_LINKS_PER_BLOCK: u32 = 256;
pub const MAX_BLOCK_TITLE: u32 = 512;
```

**Why Bounded?**

- **Memory safety**: Prevents unbounded allocations
- **Predictable performance**: Known maximum sizes
- **Explicit constraints**: Design decisions visible in code

## Block Storage Manager

### Storage Structure

```zig
pub const BlockStorage = struct {
    blocks: []BlockData,         // Pre-allocated blocks buffer
    blocks_len: u32,             // Number of active blocks
    next_block_id: u32,          // Next available block ID
    allocator: std.mem.Allocator,
    
    pub const MAX_BLOCKS: u32 = 100_000;
};
```

**Why Pre-allocated?**

- **Bounded**: Fixed maximum number of blocks
- **Predictable**: No dynamic allocation during operations
- **Fast**: No allocation overhead for block creation

### Block Operations

#### Create Block

```zig
pub fn create_block(
    self: *BlockStorage,
    title: []const u8,
    content: []const u8
) !u32 {
    // Assert: Bounds checking
    std.debug.assert(title.len <= MAX_BLOCK_TITLE);
    std.debug.assert(content.len <= MAX_BLOCK_CONTENT);
    std.debug.assert(self.blocks_len < MAX_BLOCKS);
    
    // Allocate block data
    const block_id = self.next_block_id;
    const block = try BlockData.init(
        self.allocator,
        block_id,
        title,
        content
    );
    
    // Store block
    self.blocks[self.blocks_len] = block;
    self.blocks_len += 1;
    self.next_block_id += 1;
    
    return block_id;
}
```

**GrainStyle Principles Applied:**

- **Explicit bounds**: All limits checked before allocation
- **Assertions**: Preconditions verified
- **Deterministic**: Same input = same output

#### Link Blocks (Bidirectional)

```zig
pub fn link_blocks(
    self: *BlockStorage,
    source_id: u32,
    target_id: u32
) !void {
    // Get blocks
    const source = self.get_block(source_id) orelse return error.BlockNotFound;
    const target = self.get_block(target_id) orelse return error.BlockNotFound;
    
    // Assert: Link limits
    std.debug.assert(source.links_len < MAX_LINKS_PER_BLOCK);
    std.debug.assert(target.backlinks_len < MAX_LINKS_PER_BLOCK);
    
    // Add link (source → target)
    source.links[source.links_len] = target_id;
    source.links_len += 1;
    
    // Add backlink (target ← source)
    target.backlinks[target.backlinks_len] = source_id;
    target.backlinks_len += 1;
}
```

**Why Bidirectional?**

- **Fast traversal**: Can navigate in both directions
- **Social features**: Enables reply threading
- **Graph algorithms**: Supports both forward and backward traversal

## Iterative Algorithms (No Recursion)

### Finding Block by ID

```zig
pub fn get_block(self: *BlockStorage, block_id: u32) ?*BlockData {
    // Iterative search (no recursion)
    var i: u32 = 0;
    while (i < self.blocks_len) : (i += 1) {
        if (self.blocks[i].id == block_id) {
            return &self.blocks[i];
        }
    }
    return null;
}
```

**Why Iterative?**

- **Stack safety**: No recursion depth limits
- **Predictable**: Bounded iteration count
- **GrainStyle**: Explicit loop bounds

### Traversing Links

```zig
pub fn get_linked_blocks(
    self: *BlockStorage,
    block_id: u32,
    output: []u32
) !u32 {
    const block = self.get_block(block_id) orelse return error.BlockNotFound;
    
    // Assert: Output buffer large enough
    std.debug.assert(output.len >= block.links_len);
    
    // Copy links (iterative)
    var i: u32 = 0;
    while (i < block.links_len) : (i += 1) {
        output[i] = block.links[i];
    }
    
    return block.links_len;
}
```

## Knowledge Graph Patterns

### Graph Traversal

**Depth-First Search (Iterative)**:

```zig
pub fn traverse_depth_first(
    self: *BlockStorage,
    start_id: u32,
    visitor: *const fn (block_id: u32) void
) !void {
    // Stack-based traversal (no recursion)
    var stack: [MAX_BLOCKS]u32 = undefined;
    var stack_len: u32 = 0;
    var visited: [MAX_BLOCKS]bool = undefined;
    @memset(&visited, false);
    
    stack[stack_len] = start_id;
    stack_len += 1;
    
    while (stack_len > 0) {
        // Pop from stack
        stack_len -= 1;
        const current_id = stack[stack_len];
        
        // Skip if visited
        if (visited[current_id]) continue;
        visited[current_id] = true;
        
        // Visit block
        visitor(current_id);
        
        // Push linked blocks
        const block = self.get_block(current_id) orelse continue;
        var i: u32 = 0;
        while (i < block.links_len) : (i += 1) {
            if (!visited[block.links[i]]) {
                stack[stack_len] = block.links[i];
                stack_len += 1;
            }
        }
    }
}
```

**Why Stack-Based?**

- **No recursion**: Bounded stack size
- **Explicit**: Stack size is visible (MAX_BLOCKS)
- **Safe**: Cannot overflow (bounded by design)

## Exercises

1. **Block Creation**: Create a block with title "Hello" and content "World"
2. **Linking**: Link two blocks together (bidirectional)
3. **Traversal**: Implement breadth-first search (iterative, queue-based)
4. **Backlinks**: Find all blocks that link to a given block

## Connections

- **Next**: Social Threading (0012) - How blocks reply to each other
- **Related**: DAG-Based Architectures (0015) - UI representation of graphs
- **Related**: Storage Integration (0020) - Persisting blocks to Grain Silo

---

**Key Takeaway**: Knowledge graphs enable non-linear, social content. GrainStyle ensures they're bounded, safe, and deterministic.

