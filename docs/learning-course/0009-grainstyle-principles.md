# GrainStyle Principles

**Prerequisites**: All previous documents (foundational concepts)  
**Focus**: GrainStyle coding discipline as applied throughout Grain OS  
**GrainStyle**: This document IS GrainStyle—patient, explicit, code that teaches

## What is GrainStyle?

GrainStyle is a coding discipline for building safety-first, long-lasting
systems code. It's not just style—it's a philosophy of explicit limits,
patient discipline, and code that teaches.

**Core Principle**: Code written once, read many times. Make the reading
experience excellent.

## Explicit Limits

### No Hidden Bounds

Every limit must be explicit:

```zig
// ❌ Bad: Hidden limit
for (items) |item| {
    process(item);
}

// ✅ Good: Explicit limit
const MAX_ITEMS: u32 = 100;
std.debug.assert(items.len <= MAX_ITEMS);
for (items) |item| {
    process(item);
}
```

**Why Explicit?**
- Makes constraints visible
- Enables bounds checking
- Documents design decisions

### Use Explicit Types

```zig
// ❌ Bad: Architecture-dependent
const size: usize = calculate_size();

// ✅ Good: Explicit size
const size: u32 = calculate_size();
std.debug.assert(size <= MAX_SIZE);
```

**Why u32/u64?**
- Portable across architectures
- Clear size limits
- No hidden assumptions

## Assertion Density

### Minimum 2 Assertions Per Function

```zig
pub fn process_data(data: []const u8) void {
    // Assertion 1: Precondition
    std.debug.assert(data.len > 0);
    std.debug.assert(data.len <= MAX_DATA_SIZE);
    
    // ... process data ...
    
    // Assertion 2: Postcondition
    std.debug.assert(result > 0);
    std.debug.assert(result <= data.len);
}
```

**Why 2+?**
- Catch bugs early
- Document invariants
- Enable fuzzing

### Pair Assertions

Assert both preconditions AND postconditions:

```zig
pub fn write_memory(addr: u64, value: u32) void {
    // Precondition: Address must be valid
    std.debug.assert(addr < MEMORY_SIZE);
    std.debug.assert(addr % 4 == 0);
    
    // ... write ...
    
    // Postcondition: Value must be written
    const read_back = read_memory(addr);
    std.debug.assert(read_back == value);
}
```

**Why Pair?**
- Catches bugs at boundaries
- Verifies operation succeeded
- Documents expected behavior

## Static Allocation

### All Memory at Startup

```zig
// ✅ Good: Static allocation
pub const VM = struct {
    memory: [VM_MEMORY_SIZE]u8 = [_]u8{0} ** VM_MEMORY_SIZE,
    // ...
};

// ❌ Bad: Dynamic allocation
pub const VM = struct {
    memory: std.ArrayList(u8),
};
```

**Why Static?**
- Predictable memory usage
- No allocator dependency
- Bounded execution guarantees

### Pre-allocate Collections

```zig
// ✅ Good: Pre-allocate
var cache = std.AutoHashMap(u64, usize).init(allocator);
try cache.ensureTotalCapacity(10_000);

// ❌ Bad: Grow dynamically
var cache = std.AutoHashMap(u64, usize).init(allocator);
// Grows on demand (unpredictable)
```

**Why Pre-allocate?**
- Bounded memory usage
- No allocation failures during execution
- Predictable performance

## Function Length Limit

### 70-Line Maximum

Functions must fit on a "graincard" (screen):

```zig
// ✅ Good: Under 70 lines
pub fn process_data(data: []const u8) void {
    // ... 50 lines of code ...
}

// ❌ Bad: Over 70 lines
pub fn process_data(data: []const u8) void {
    // ... 100 lines of code ...
    // Split into helper functions!
}
```

**Why 70 Lines?**
- Fits on screen
- Easier to understand
- Forces good structure

### Splitting Functions

When splitting, follow "push ifs up, fors down":

```zig
// Parent: Handles control flow
pub fn process_items(items: []Item) void {
    for (items) |item| {
        if (should_process(item)) {
            process_single_item(item);
        }
    }
}

// Child: Pure logic, no control flow
fn process_single_item(item: Item) void {
    // ... process item ...
}
```

**Why This Pattern?**
- Centralizes control flow
- Keeps leaf functions pure
- Easier to test

## No Recursion

### Bounded Execution Only

```zig
// ❌ Bad: Recursion (unbounded)
fn factorial(n: u32) u32 {
    if (n == 0) return 1;
    return n * factorial(n - 1);  // Unbounded depth
}

// ✅ Good: Iteration (bounded)
fn factorial(n: u32) u32 {
    std.debug.assert(n <= 20);  // Explicit limit
    var result: u32 = 1;
    var i: u32 = 1;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}
```

**Why No Recursion?**
- Unbounded stack growth
- Hard to verify termination
- Bounded execution is safer

## Code That Teaches

### Comments Explain "Why"

```zig
// ✅ Good: Explains why
// Why: RISC-V requires 4-byte alignment for word access
if (addr % 4 != 0) {
    return VMError.unaligned_memory_access;
}

// ❌ Bad: Explains what (obvious)
// Check if address is divisible by 4
if (addr % 4 != 0) {
    return VMError.unaligned_memory_access;
}
```

**Why "Why"?**
- Shares design rationale
- Helps future maintainers
- Documents decisions

### Self-Documenting Code

```zig
// ✅ Good: Clear names
const FRAMEBUFFER_BASE: u64 = 0x90000000;
const framebuffer_offset = calculate_pixel_offset(x, y);

// ❌ Bad: Unclear names
const fb_base: u64 = 0x90000000;
const off = calc_off(x, y);
```

**Why Clear Names?**
- Code reads like documentation
- Less need for comments
- Easier to understand

## Error Handling

### Explicit Error Types

```zig
// ✅ Good: Specific errors
pub const VMError = error{
    invalid_memory_access,
    unaligned_memory_access,
    invalid_instruction,
};

// ❌ Bad: Generic error
pub const VMError = error{
    error,
};
```

**Why Specific?**
- Clear error semantics
- Better error handling
- Easier debugging

### Distinguish Errors from Bugs

```zig
// Expected error: Use try/return error
if (addr >= memory_size) {
    return VMError.invalid_memory_access;  // Expected
}

// Unexpected bug: Use assert
std.debug.assert(ptr != null);  // Should never be null
```

**Why Distinguish?**
- Errors: Handle gracefully
- Bugs: Crash immediately (fail-fast)

## Memory Safety

### Bounds Checking

```zig
pub fn read_memory(self: *const VM, addr: u64) VMError!u32 {
    // Check bounds
    if (addr + 4 > self.memory_size) {
        return VMError.invalid_memory_access;
    }
    
    // Check alignment
    if (addr % 4 != 0) {
        return VMError.unaligned_memory_access;
    }
    
    // Safe to access
    const bytes = self.memory[@intCast(addr)..][0..4];
    return std.mem.readInt(u32, bytes, .little);
}
```

**Why Always Check?**
- Prevents memory corruption
- Catches bugs early
- Documents assumptions

## Testing Discipline

### Exhaustive Testing

Test both valid and invalid inputs:

```zig
test "read_memory valid" {
    var vm = VM.init(&[_]u8{}, 0);
    const value = try vm.read_memory(0);
    // ... verify ...
}

test "read_memory out of bounds" {
    var vm = VM.init(&[_]u8{}, 0);
    const result = vm.read_memory(VM_MEMORY_SIZE);
    try std.testing.expectError(VMError.invalid_memory_access, result);
}

test "read_memory unaligned" {
    var vm = VM.init(&[_]u8{}, 0);
    const result = vm.read_memory(1);  // Not 4-byte aligned
    try std.testing.expectError(VMError.unaligned_memory_access, result);
}
```

**Why Exhaustive?**
- Finds edge cases
- Documents behavior
- Prevents regressions

## GrainStyle Checklist

For every function, verify:

- [ ] Explicit limits (u32/u64, not usize)
- [ ] 2+ assertions (preconditions + postconditions)
- [ ] Under 70 lines (split if needed)
- [ ] No recursion (use iteration)
- [ ] "Why" comments (not "what")
- [ ] Clear names (self-documenting)
- [ ] Explicit error types
- [ ] Bounds checking
- [ ] Tests (valid + invalid inputs)

## Common Patterns

### Memory Access

```zig
pub fn safe_memory_access(addr: u64, size: u32) VMError!void {
    // 1. Check bounds
    if (addr + size > memory_size) {
        return VMError.invalid_memory_access;
    }
    
    // 2. Check alignment (if needed)
    if (size > 1 and addr % size != 0) {
        return VMError.unaligned_memory_access;
    }
    
    // 3. Assert: Address must be valid now
    std.debug.assert(addr < memory_size);
    std.debug.assert(addr + size <= memory_size);
    
    // 4. Perform access
    // ...
    
    // 5. Assert: Operation succeeded
    std.debug.assert(/* postcondition */);
}
```

### Loop with Bounds

```zig
pub fn process_items(items: []Item) void {
    const MAX_ITEMS: u32 = 1000;
    std.debug.assert(items.len <= MAX_ITEMS);
    
    var i: u32 = 0;
    while (i < items.len) : (i += 1) {
        process_item(items[i]);
    }
    
    std.debug.assert(i == items.len);
}
```

## Exercises

1. **Refactor**: Take a function over 70 lines and split it following
   "push ifs up, fors down".

2. **Add Assertions**: Find a function with < 2 assertions and add
   preconditions and postconditions.

3. **Explicit Limits**: Find uses of `usize` and replace with `u32`/`u64`
   with explicit bounds.

4. **Error Types**: Design error types for a new module.

## Key Takeaways

- **Explicit Limits**: All bounds are visible
- **Assertion Density**: 2+ assertions per function
- **Static Allocation**: All memory at startup
- **Function Length**: Max 70 lines
- **No Recursion**: Bounded execution only
- **Code That Teaches**: Comments explain "why"
- **Error Handling**: Explicit error types
- **Testing**: Exhaustive (valid + invalid)

## Next Document

**0010-grain-os-architecture.md**: See how all concepts come together in
Grain OS architecture.

---

*now == next + 1*

