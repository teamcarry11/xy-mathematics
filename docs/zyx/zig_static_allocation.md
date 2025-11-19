# Zig Static Allocation: Size Limits and Zero-Copy Patterns

**Date**: 2025-11-15  
**Purpose**: Document Zig static allocation capabilities and zero-copy patterns for large structs

## Static Allocation in Zig

### What is Static Allocation?

Static allocation in Zig means memory that is allocated at compile-time and lives for the entire program lifetime. This includes:
- Global variables
- Struct fields with compile-time known sizes
- Arrays with compile-time known sizes

### Size Limits

**No Hard Limit**: Zig doesn't impose a hard limit on static allocation size, but practical limits exist:

1. **Executable Size**: Large static allocations increase binary size
2. **Memory Mapping**: OS may limit memory-mapped sections
3. **Linker Limits**: Some linkers have limits on section sizes
4. **Virtual Memory**: Must fit in process virtual address space

**Practical Limits**:
- **Small allocations** (< 1MB): Always fine, stored in `.data` or `.bss` section
- **Medium allocations** (1MB - 100MB): Usually fine, but increases binary size
- **Large allocations** (> 100MB): May cause issues with some linkers/toolchains

### Fixed Size

**Yes, static allocations are always fixed size**:
- Size must be known at compile time
- Cannot be resized at runtime
- Perfect for our VM's 4MB memory array

### Zero-Copy Patterns

**Yes, static allocations can be cast from raw bytes for zero-copy**:

```zig
// Example: Zero-copy pattern for large struct
const LargeStruct = struct {
    data: [4 * 1024 * 1024]u8, // 4MB array
    // ... other fields
};

// Option 1: Static global (zero-copy, but global state)
var global_vm: LargeStruct = undefined;

// Option 2: Stack allocation (copies on assignment - our current issue)
var vm: LargeStruct = undefined;
var vm2 = vm; // Copies 4MB!

// Option 3: Pointer to static allocation (zero-copy)
var vm_storage: LargeStruct = undefined;
var vm_ptr: *LargeStruct = &vm_storage; // No copy, just pointer

// Option 4: Raw bytes cast (zero-copy, but loses type safety)
var vm_bytes: [@sizeOf(LargeStruct)]u8 align(@alignOf(LargeStruct)) = undefined;
var vm_ptr2: *LargeStruct = @ptrCast(@alignCast(&vm_bytes));
```

## Our VM Struct Case

### Current Implementation

```zig
pub const VM = struct {
    memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024), // 4MB static array
    regs: RegisterFile = .{},
    state: VMState = .halted,
    // ...
};
```

**Properties**:
- ✅ **Static allocation**: `memory` array is compile-time known size (4MB)
- ✅ **Fixed size**: Always exactly 4MB
- ❌ **Copy overhead**: Assigning `var vm2 = vm` copies entire 4MB struct

### The Problem

When we do:
```zig
var integration = Integration{
    .vm = vm,  // This copies the entire 4MB VM struct!
};
```

**Solution**: Store pointer instead of value:
```zig
pub const Integration = struct {
    vm: *VM,  // Pointer - no copy, just 8 bytes
    // ...
};
```

### Zero-Copy Alternatives

#### Option 1: Static Global Storage (Current Approach)
```zig
// In test or Integration:
var vm_storage: VM = undefined;
loadUserspaceELF(&vm_storage, ...);
var integration = Integration{ .vm = &vm_storage };
```

**Pros**: Simple, type-safe, zero-copy  
**Cons**: Requires storage to outlive Integration

#### Option 2: Heap Allocation
```zig
// Allocate VM on heap
var vm = try allocator.create(VM);
defer allocator.destroy(vm);
loadUserspaceELF(vm, ...);
var integration = Integration{ .vm = vm };
```

**Pros**: Flexible lifetime, zero-copy  
**Cons**: Requires allocator, dynamic allocation

#### Option 3: Raw Bytes Cast (Advanced)
```zig
// Allocate raw bytes, cast to VM
var vm_bytes = try allocator.alignedAlloc(u8, @alignOf(VM), @sizeOf(VM));
defer allocator.free(vm_bytes);
var vm: *VM = @ptrCast(@alignCast(vm_bytes.ptr));
loadUserspaceELF(vm, ...);
```

**Pros**: Maximum control, zero-copy  
**Cons**: Loses type safety, error-prone

## Best Practices for Large Static Allocations

### 1. Use Pointers for Large Structs

**Rule**: If struct size > ~1KB, prefer pointers over values

```zig
// ❌ Bad: Copies large struct
var vm: VM = undefined;
var vm2 = vm; // Copies 4MB!

// ✅ Good: Uses pointer
var vm: VM = undefined;
var vm_ptr: *VM = &vm; // Just 8 bytes
```

### 2. In-Place Initialization (TigerStyle)

**Pattern**: Initialize large structs in-place to avoid stack allocation

```zig
// ✅ TigerStyle: In-place initialization
pub fn init(target: *VM, ...) void {
    target.* = .{
        .memory = [_]u8{0} ** VM_MEMORY_SIZE,
        // ...
    };
}

// Usage:
var vm: VM = undefined;
VM.init(&vm, ...); // No copy, initialized in-place
```

### 3. Avoid Returning Large Structs by Value

```zig
// ❌ Bad: Returns large struct by value
pub fn createVM() VM {
    var vm: VM = undefined;
    // ...
    return vm; // Copies 4MB!
}

// ✅ Good: Returns pointer or uses out parameter
pub fn createVM(target: *VM) void {
    // Initialize in-place
}
```

### 4. Static vs. Dynamic Allocation

**Static Allocation** (compile-time):
- ✅ Zero runtime overhead
- ✅ Predictable memory usage
- ✅ No allocation failures
- ❌ Fixed size (must be compile-time known)
- ❌ Increases binary size

**Dynamic Allocation** (runtime):
- ✅ Flexible size
- ✅ Smaller binary size
- ❌ Runtime overhead
- ❌ Can fail (out of memory)
- ❌ Requires allocator

## Our Current Solution

We refactored `Integration` to store `vm: *VM` instead of `vm: VM`:

```zig
pub const Integration = struct {
    vm: *VM,  // Pointer - avoids copying 4MB struct
    kernel: BasinKernel,
    initialized: bool,
};
```

**Why This Works**:
- ✅ Zero-copy: Only pointer is stored (8 bytes)
- ✅ Type-safe: Still have full type information
- ✅ TigerStyle: In-place initialization pattern
- ✅ No stack overflow: No large struct copying

## Summary

1. **Static allocations can be very large** (no hard limit, but practical limits exist)
2. **They are always fixed size** (compile-time known)
3. **They can be cast from raw bytes** for zero-copy, but prefer pointers for type safety
4. **For large structs (>1KB)**: Use pointers, not values
5. **TigerStyle pattern**: In-place initialization with out pointers

## References

- [Zig Language Reference: Memory](https://ziglang.org/documentation/master/#Memory)
- [TigerStyle Guide](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md)
- Our VM implementation: `src/kernel_vm/vm.zig`

