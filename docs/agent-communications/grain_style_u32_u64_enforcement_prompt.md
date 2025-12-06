# Grain Style Enforcement: u32/u64 Instead of usize

**Date**: 2025-12-05-231800-pst  
**Status**: CRITICAL STYLE ENFORCEMENT  
**Purpose**: Ensure all agents strictly follow Grain Style regarding explicit integer types

---

## Executive Summary

This document provides a **mandatory enforcement prompt** for all Grain agents to strictly follow Grain Style guidelines regarding the use of explicit integer types (`u32`, `u64`) instead of architecture-specific `usize`/`isize`.

**Reference**: [`docs/grain_style.md`](grain_style.md) - Line 100: "Use explicitly-sized types like `u32` for everything, avoid architecture-specific `usize`."

---

## Critical Rule

### ❌ FORBIDDEN: `usize` and `isize`

**Rule**: **NEVER use `usize` or `isize` in Grain OS code.**

**Why**:
- `usize`/`isize` are architecture-dependent (32-bit vs 64-bit)
- Makes code non-portable across architectures
- Hides explicit size requirements
- Violates Grain Style's "explicit limits" principle
- Prevents static analysis and bounds checking

### ✅ REQUIRED: `u32` and `u64`

**Rule**: **Always use explicit integer types: `u32`, `u64`, `i32`, `i64`.**

**Why**:
- Explicit size guarantees across all architectures
- Clear intent and limits
- Enables static bounds checking
- Portable code (RISC-V 32-bit, RISC-V 64-bit, AArch64, x86_64)
- Aligns with Grain Style's "explicit limits" principle

---

## Guidelines

### When to Use `u32`

Use `u32` for:
- Array indices and lengths
- Loop counters
- Counts and sizes (when < 4GB)
- Buffer sizes
- String lengths
- Collection sizes
- Most bounded allocations

**Examples**:
```zig
// ✅ Good
pub const MAX_WINDOWS: u32 = 256;
pub fn get_window_count(self: *const WindowManager) u32 { }
var index: u32 = 0;
while (index < items_len) : (index += 1) { }

// ❌ Bad
pub const MAX_WINDOWS: usize = 256;  // NO!
pub fn get_window_count(self: *const WindowManager) usize { }  // NO!
var index: usize = 0;  // NO!
```

### When to Use `u64`

Use `u64` for:
- Timestamps
- File sizes (when > 4GB possible)
- Memory addresses (when needed)
- Large counters (> 4GB)
- Time durations
- Large offsets

**Examples**:
```zig
// ✅ Good
pub const MAX_FILE_SIZE: u64 = 1024 * 1024 * 1024 * 1024;  // 1TB
pub fn get_timestamp(self: *const TimeManager) u64 { }
var file_size: u64 = 0;

// ❌ Bad
pub const MAX_FILE_SIZE: usize = ...;  // NO!
pub fn get_timestamp(self: *const TimeManager) usize { }  // NO!
```

### When to Use `i32` and `i64`

Use signed types only when:
- Values can be negative
- Differences/offsets can be negative
- Explicitly needed for arithmetic

**Examples**:
```zig
// ✅ Good
pub fn calculate_offset(start: u32, end: u32) i32 {
    return @as(i32, @intCast(end)) - @as(i32, @intCast(start));
}

// ❌ Bad
pub fn calculate_offset(start: usize, end: usize) isize { }  // NO!
```

---

## Conversion Guidelines

### Converting from `usize` to `u32`/`u64`

When interfacing with Zig standard library or external APIs that return `usize`:

```zig
// ✅ Good: Explicit conversion with bounds checking
const len: usize = some_slice.len;
std.debug.assert(len <= std.math.maxInt(u32));
const len_u32: u32 = @intCast(len);

// ✅ Good: Use u64 if value might exceed u32
const large_size: usize = some_large_value;
const size_u64: u64 = @intCast(large_size);
std.debug.assert(size_u64 <= MAX_SIZE);
```

### Converting between `u32` and `u64`

```zig
// ✅ Good: Explicit conversion
const small: u32 = 100;
const large: u64 = @as(u64, small);

const large_val: u64 = 1000;
std.debug.assert(large_val <= std.math.maxInt(u32));
const small_val: u32 = @intCast(large_val);
```

---

## Audit Checklist

All agents must audit their code for `usize`/`isize` usage:

### 1. Search for `usize`/`isize`

```bash
# Find all usize usage
grep -r "usize" src/your_module/
grep -r "isize" src/your_module/

# Find in tests
grep -r "usize" tests/
grep -r "isize" tests/
```

### 2. Replace with Explicit Types

For each occurrence:
- **Array indices, lengths, counts**: Replace with `u32`
- **Large values (> 4GB)**: Replace with `u64`
- **Signed values**: Replace with `i32` or `i64`
- **Add explicit conversions**: Use `@intCast()` with bounds checking

### 3. Update Function Signatures

```zig
// ❌ Before
pub fn process_items(items: []const Item, count: usize) void { }

// ✅ After
pub fn process_items(items: []const Item, count: u32) void {
    std.debug.assert(count <= MAX_ITEMS);
    std.debug.assert(items.len <= MAX_ITEMS);
    // ...
}
```

### 4. Update Struct Fields

```zig
// ❌ Before
pub const Buffer = struct {
    data: []u8,
    len: usize,
    capacity: usize,
};

// ✅ After
pub const Buffer = struct {
    data: []u8,
    len: u32,
    capacity: u32,
};
```

### 5. Update Constants

```zig
// ❌ Before
pub const MAX_ITEMS: usize = 256;
pub const BUFFER_SIZE: usize = 4096;

// ✅ After
pub const MAX_ITEMS: u32 = 256;
pub const BUFFER_SIZE: u32 = 4096;
```

### 6. Update Loop Variables

```zig
// ❌ Before
var i: usize = 0;
while (i < items.len) : (i += 1) { }

// ✅ After
var i: u32 = 0;
const items_len: u32 = @intCast(items.len);
std.debug.assert(items_len <= MAX_ITEMS);
while (i < items_len) : (i += 1) { }
```

---

## Enforcement Actions

### Immediate Actions Required

1. **Audit Your Module**: Search for all `usize`/`isize` usage
2. **Replace with Explicit Types**: Convert to `u32`/`u64`/`i32`/`i64`
3. **Add Bounds Checking**: Add assertions for conversions
4. **Update Tests**: Ensure tests use explicit types
5. **Verify Compilation**: Ensure all code compiles with explicit types
6. **Update Documentation**: Update any docs referencing `usize`/`isize`

### Code Review Checklist

Before committing code, verify:
- ✅ No `usize` or `isize` in function signatures
- ✅ No `usize` or `isize` in struct fields
- ✅ No `usize` or `isize` in constants
- ✅ No `usize` or `isize` in loop variables
- ✅ All conversions use `@intCast()` with bounds checking
- ✅ All bounds checks use explicit `u32`/`u64` limits
- ✅ All tests use explicit types

---

## Examples: Before and After

### Example 1: Function Signature

```zig
// ❌ Before
pub fn find_item(items: []const Item, target_id: usize) ?usize {
    var i: usize = 0;
    while (i < items.len) : (i += 1) {
        if (items[i].id == target_id) {
            return i;
        }
    }
    return null;
}

// ✅ After
pub fn find_item(items: []const Item, target_id: u32) ?u32 {
    std.debug.assert(items.len <= MAX_ITEMS);
    std.debug.assert(target_id > 0);
    var i: u32 = 0;
    const items_len: u32 = @intCast(items.len);
    while (i < items_len) : (i += 1) {
        if (items[i].id == target_id) {
            return i;
        }
    }
    return null;
}
```

### Example 2: Struct Definition

```zig
// ❌ Before
pub const WindowManager = struct {
    windows: [MAX_WINDOWS]Window,
    windows_len: usize,
    active_window: ?usize,
};

// ✅ After
pub const WindowManager = struct {
    windows: [MAX_WINDOWS]Window,
    windows_len: u32,
    active_window: ?u32,
};
```

### Example 3: Loop with Bounds

```zig
// ❌ Before
pub fn process_buffer(buffer: []const u8) void {
    var i: usize = 0;
    while (i < buffer.len) : (i += 1) {
        process_byte(buffer[i]);
    }
}

// ✅ After
pub fn process_buffer(buffer: []const u8) void {
    std.debug.assert(buffer.len <= MAX_BUFFER_SIZE);
    var i: u32 = 0;
    const buffer_len: u32 = @intCast(buffer.len);
    while (i < buffer_len) : (i += 1) {
        process_byte(buffer[i]);
    }
}
```

---

## Standard Agent Prompt Addition

Add this to your standard agent prompt:

```
CRITICAL GRAIN STYLE ENFORCEMENT: You MUST use explicit integer types (u32, u64, i32, i64) 
instead of usize/isize. This is a non-negotiable requirement.

Before committing any code:
1. Search for all usize/isize usage: grep -r "usize\|isize" src/your_module/
2. Replace with explicit types (u32 for indices/counts, u64 for large values)
3. Add @intCast() conversions with bounds checking
4. Add assertions for all bounds checks
5. Verify all tests use explicit types

Reference: docs/grain_style.md line 100: "Use explicitly-sized types like u32 for 
everything, avoid architecture-specific usize."
```

---

## Coordination

### All Agents Must:

1. **Audit Immediately**: Search your module for `usize`/`isize`
2. **Replace Systematically**: Convert all occurrences to explicit types
3. **Test Thoroughly**: Ensure all tests pass with explicit types
4. **Document Changes**: Update any affected documentation
5. **Coordinate**: Check in before large refactorings to prevent conflicts

### Reporting

When completing the audit, report:
- Number of `usize`/`isize` occurrences found
- Number of replacements made
- Any edge cases or questions
- Completion status

---

## Questions and Edge Cases

### Q: What about standard library functions that return `usize`?

**A**: Convert immediately with bounds checking:
```zig
const std_len: usize = std.mem.len(slice);
std.debug.assert(std_len <= std.math.maxInt(u32));
const len: u32 = @intCast(std_len);
```

### Q: What about pointer arithmetic?

**A**: Use `u64` for addresses, `u32` for offsets:
```zig
const address: u64 = @intFromPtr(ptr);
const offset: u32 = @intCast(byte_offset);
```

### Q: What about array indexing with `[]const u8`?

**A**: Convert slice length to `u32`:
```zig
const slice: []const u8 = get_slice();
const len: u32 = @intCast(slice.len);
std.debug.assert(len <= MAX_LEN);
var i: u32 = 0;
while (i < len) : (i += 1) {
    process_byte(slice[i]);
}
```

---

## Success Criteria

Code is compliant when:
- ✅ Zero `usize` or `isize` in your module
- ✅ All function signatures use `u32`/`u64`/`i32`/`i64`
- ✅ All struct fields use explicit types
- ✅ All constants use explicit types
- ✅ All loop variables use explicit types
- ✅ All conversions use `@intCast()` with bounds checking
- ✅ All tests pass with explicit types
- ✅ All compiler warnings resolved

---

## Reference

- **Grain Style Guide**: [`docs/grain_style.md`](../grain_style.md) - Line 100
- **Tiger Style (Source)**: [TigerBeetle Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md)

---

**End of Enforcement Prompt**

**All agents must complete this audit and report completion status.**

