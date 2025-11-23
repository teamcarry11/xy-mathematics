# Transclusion and Content Embedding

**Prerequisites**: Knowledge Graphs (0011), Social Threading (0012)  
**Focus**: Transclusion (embedding blocks in other blocks) in Grain Skate  
**GrainStyle**: Explicit transclusion depth, bounded embedding, iterative expansion

## What is Transclusion?

Transclusion is the inclusion of one block's content within another block. Unlike copying, transclusion maintains a reference to the source block:

- **Live references**: Changes to source block can update transcluded content
- **Composition**: Build complex documents from smaller blocks
- **Reusability**: Write once, include many times
- **Depth tracking**: Prevents infinite transclusion loops

**Why Transclusion?**

- **DRY principle**: Don't repeat yourself—write content once, reuse it
- **Modularity**: Build complex documents from simple blocks
- **Consistency**: Single source of truth for shared content
- **Social features**: Quote blocks in replies (like blockquotes)

## Transclusion Structure

### Transclusion Relationship

```zig
pub const Transclusion = struct {
    source_block_id: u32,   // Block being transcluded
    target_block_id: u32,   // Block that transcludes
    offset: u32,            // Offset in target block content
    length: u32,            // Length of transcluded content
    depth: u32,             // Transclusion depth (0 = direct)
};
```

**Why These Fields?**

- **source_block_id**: The block whose content is being embedded
- **target_block_id**: The block that contains the transclusion
- **offset**: Where in the target block's content the transclusion appears
- **length**: How much content is transcluded
- **depth**: How many levels deep (for cycle detection)

### Transclusion Limits

```zig
pub const MAX_TRANSCLUSION_DEPTH: u32 = 50;
pub const MAX_TRANSCLUSIONS_PER_BLOCK: u32 = 32;
pub const MAX_TRANSCLUSIONS: u32 = 10_000;
```

**Why Bounded?**

- **MAX_TRANSCLUSION_DEPTH**: Prevents infinite nesting
- **MAX_TRANSCLUSIONS_PER_BLOCK**: Limits complexity per block
- **MAX_TRANSCLUSIONS**: Total system limit

## Creating Transclusions

### Basic Transclusion

```zig
pub fn create_transclusion(
    self: *SocialManager,
    source_block_id: u32,
    target_block_id: u32,
    offset: u32,
    length: u32
) !void {
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
```

**GrainStyle Principles:**

- **Explicit bounds**: All limits checked
- **Assertions**: Preconditions verified
- **Iterative depth calculation**: No recursion

## Depth Calculation (Iterative)

### Why Iterative?

Recursive depth calculation can cause stack overflow with deep transclusion chains:

```zig
// ❌ Bad: Recursive (can overflow)
fn calculate_depth_recursive(block_id: u32) u32 {
    // Find parent transclusion
    const parent = find_transclusion(block_id);
    if (parent) |trans| {
        return 1 + calculate_depth_recursive(trans.target_block_id);
    }
    return 0;
}
```

### Iterative Solution

```zig
fn calculate_transclusion_depth(
    self: *SocialManager,
    block_id: u32
) !u32 {
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
```

**Why This Works:**

- **Bounded iteration**: MAX_TRANSCLUSION_DEPTH limit
- **Cycle detection**: Prevents infinite loops
- **No recursion**: Stack-safe

## Expanding Transcluded Content

### Getting Transcluded Content

```zig
pub fn get_transcluded_content(
    self: *SocialManager,
    block_id: u32,
    output: []u8
) !u32 {
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
            const transcluded_block = self.block_storage.get_block(
                transclusion.source_block_id
            ) orelse continue;
            
            // Insert transcluded content at offset
            if (output_len + transcluded_block.content_len > output.len) {
                return error.OutputTooSmall;
            }
            
            // For simplicity, append transcluded content
            // Full implementation would insert at offset
            @memcpy(
                output[output_len..][0..transcluded_block.content_len],
                transcluded_block.content
            );
            output_len += transcluded_block.content_len;
        }
    }
    
    return output_len;
}
```

**Why Iterative?**

- **Bounded**: Output size limited by buffer
- **Predictable**: Known maximum size
- **Safe**: No stack overflow risk

## Transclusion Patterns

### Simple Transclusion

```
Block A: "Hello"
Block B: "World" (transcludes A)
Result: "Hello World"
```

### Nested Transclusion

```
Block A: "Hello"
Block B: "World" (transcludes A)
Block C: "!" (transcludes B)
Result: "Hello World!"
```

**Depth Calculation:**

- Block B transcludes A: depth 0 (direct)
- Block C transcludes B: depth 1 (B is depth 0, so C is depth 1)

### Cycle Detection

```
Block A transcludes B
Block B transcludes C
Block C transcludes A  // ❌ Cycle detected!
```

**Why Detect Cycles?**

- **Infinite expansion**: Cycles cause infinite loops
- **Stack overflow**: Recursive expansion would overflow
- **Performance**: Bounded execution time

## Use Cases

### 1. Blockquotes in Replies

```zig
// User replies to Block A, quoting Block B
const reply_id = try block_storage.create_block(
    "Reply to A",
    "I think..."
);
try social.create_reply(reply_id, block_a_id);

// Quote Block B in the reply
try social.create_transclusion(
    block_b_id,  // Source: Block B
    reply_id,    // Target: Reply block
    0,           // Offset: Start of content
    block_b.content_len
);
```

### 2. Modular Documents

```zig
// Create chapter blocks
const intro_id = try block_storage.create_block("Introduction", "...");
const body_id = try block_storage.create_block("Body", "...");
const conclusion_id = try block_storage.create_block("Conclusion", "...");

// Compose book from chapters
const book_id = try block_storage.create_block("Book", "");
try social.create_transclusion(intro_id, book_id, 0, intro.content_len);
try social.create_transclusion(body_id, book_id, intro.content_len, body.content_len);
try social.create_transclusion(conclusion_id, book_id, intro.content_len + body.content_len, conclusion.content_len);
```

### 3. Reusable Templates

```zig
// Create template block
const template_id = try block_storage.create_block(
    "Template",
    "Name: {{name}}\nDate: {{date}}"
);

// Use template in multiple blocks
try social.create_transclusion(template_id, block_1_id, 0, template.content_len);
try social.create_transclusion(template_id, block_2_id, 0, template.content_len);
```

## Exercises

1. **Create Transclusion**: Create a transclusion relationship
2. **Calculate Depth**: Implement iterative depth calculation
3. **Expand Content**: Get expanded content with transclusions
4. **Cycle Detection**: Detect and prevent cyclic transclusions

## Connections

- **Previous**: Social Threading (0012) - Reply relationships
- **Next**: Export/Import (0014) - Serializing transcluded content
- **Related**: Storage Integration (0020) - Persisting transclusions

---

**Key Takeaway**: Transclusion enables modular, reusable content. Iterative algorithms and cycle detection ensure safe, bounded expansion.

