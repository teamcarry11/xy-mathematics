# Social Threading and Reply Systems

**Prerequisites**: Knowledge Graphs (0011)  
**Focus**: Reply relationships and thread management in Grain Skate  
**GrainStyle**: Explicit reply depth, bounded threading, iterative algorithms

## What is Social Threading?

Social threading enables blocks to reply to each other, creating conversation threads. Unlike simple links, replies have:

- **Parent-child relationships**: Each reply has a parent block
- **Depth tracking**: Replies can be nested (reply to a reply)
- **Thread navigation**: Can traverse entire conversation threads
- **Cyclic detection**: Prevents infinite reply loops

**Why Social Threading?**

- **Conversations**: Natural way to represent discussions
- **Context**: Replies maintain connection to original content
- **Navigation**: Easy to follow conversation flow
- **Social features**: Enables collaborative knowledge building

## Reply Structure

### Reply Relationship

```zig
pub const Reply = struct {
    reply_block_id: u32,    // Block that is the reply
    parent_block_id: u32,  // Block being replied to
    depth: u32,            // Depth in reply thread (0 = direct reply)
    created_at: u64,       // Reply creation timestamp
};
```

**Why These Fields?**

- **reply_block_id**: The block that contains the reply
- **parent_block_id**: The block being replied to
- **depth**: How many levels deep in the thread (for UI rendering)
- **created_at**: When the reply was created (for chronological ordering)

### Social Manager

```zig
pub const SocialManager = struct {
    block_storage: *Block.BlockStorage,
    replies: []Reply,           // Pre-allocated replies buffer
    replies_len: u32,
    transclusions: []Transclusion,
    transclusions_len: u32,
    allocator: std.mem.Allocator,
    
    pub const MAX_REPLIES: u32 = 10_000;
    pub const MAX_REPLY_DEPTH: u32 = 100;
};
```

**Why Bounded?**

- **MAX_REPLIES**: Maximum number of reply relationships
- **MAX_REPLY_DEPTH**: Maximum nesting depth (prevents stack overflow)

## Creating Replies

### Basic Reply Creation

```zig
pub fn create_reply(
    self: *SocialManager,
    reply_block_id: u32,
    parent_block_id: u32
) !void {
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
```

**GrainStyle Principles:**

- **Explicit bounds**: All limits checked
- **Assertions**: Preconditions verified
- **Iterative depth calculation**: No recursion

## Depth Calculation (Iterative)

### Why Iterative?

Recursive depth calculation can cause stack overflow:

```zig
// ❌ Bad: Recursive (can overflow)
fn calculate_depth_recursive(parent_id: u32) u32 {
    // Find parent reply
    const parent_reply = find_reply(parent_id);
    if (parent_reply) |reply| {
        return 1 + calculate_depth_recursive(reply.parent_block_id);
    }
    return 0;
}
```

**Problem**: Unbounded recursion depth

### Iterative Solution

```zig
fn calculate_reply_depth(
    self: *SocialManager,
    block_id: u32
) !u32 {
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
```

**Why This Works:**

- **Bounded iteration**: MAX_REPLY_DEPTH limit
- **Cycle detection**: Prevents infinite loops
- **No recursion**: Stack-safe

## Thread Navigation

### Getting Reply Thread

```zig
pub fn get_reply_thread(
    self: *SocialManager,
    block_id: u32,
    thread: []u32
) !u32 {
    // Assert: Thread buffer large enough
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
```

**Why Iterative?**

- **Bounded**: Thread size limited by buffer
- **Predictable**: Known maximum size
- **Safe**: No stack overflow risk

## Thread Visualization

### Thread Structure

```
Block A (depth 0)
├── Block B (depth 1, replies to A)
│   ├── Block D (depth 2, replies to B)
│   └── Block E (depth 2, replies to B)
└── Block C (depth 1, replies to A)
    └── Block F (depth 2, replies to C)
```

**Depth Calculation:**

- Block A: depth 0 (root)
- Block B: depth 1 (direct reply to A)
- Block D: depth 2 (reply to B, which is depth 1)

### Rendering Threads

```zig
pub fn render_thread(
    self: *SocialManager,
    root_id: u32,
    indent: u32
) !void {
    // Get block
    const block = self.block_storage.get_block(root_id) orelse return;
    
    // Render block with indent
    print_indent(indent);
    print_block(block);
    
    // Find direct replies
    var i: u32 = 0;
    while (i < self.replies_len) : (i += 1) {
        if (self.replies[i].parent_block_id == root_id) {
            // Recursively render reply (but bounded by depth)
            const reply_id = self.replies[i].reply_block_id;
            const depth = self.replies[i].depth;
            if (depth < MAX_REPLY_DEPTH) {
                try self.render_thread(reply_id, indent + 1);
            }
        }
    }
}
```

**Note**: This uses recursion, but depth is bounded by MAX_REPLY_DEPTH, so it's safe.

## Exercises

1. **Create Reply**: Create a reply relationship between two blocks
2. **Calculate Depth**: Implement iterative depth calculation
3. **Get Thread**: Retrieve all replies in a thread
4. **Cycle Detection**: Detect and prevent cyclic replies

## Connections

- **Previous**: Knowledge Graphs (0011) - Block structure and linking
- **Next**: Transclusion (0013) - Embedding blocks in other blocks
- **Related**: Export/Import (0014) - Serializing threads

---

**Key Takeaway**: Social threading enables conversations in knowledge graphs. Iterative algorithms ensure safety and bounded execution.

