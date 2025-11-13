# Single-Threaded Safety-First Efficiency: Hardware → SBI → Kernel → Userspace

**Date**: 2025-11-13  
**Purpose**: Design optimal single-threaded architecture for maximum efficiency with safety as #1 priority

## Architecture Overview

```
┌─────────────────────────────────────────┐
│  Userspace (Single Thread)              │
│  - Applications, libraries              │
│  - Direct syscall interface            │
└─────────────────────────────────────────┘
              ↕ (direct function call, no IPC)
┌─────────────────────────────────────────┐
│  Grain Basin Kernel (Single Thread)     │
│  - Process management                   │
│  - Memory management                    │
│  - I/O, file systems                   │
│  - Direct function calls (no IPC)       │
└─────────────────────────────────────────┘
              ↕ (direct function call, no IPC)
┌─────────────────────────────────────────┐
│  SBI Layer (Single Thread)              │
│  - Platform services                    │
│  - Direct hardware access               │
└─────────────────────────────────────────┘
              ↕ (direct hardware access)
┌─────────────────────────────────────────┐
│  Hardware (RISC-V CPU, Memory)          │
└─────────────────────────────────────────┘
```

## Core Principles

### 1. Single-Threaded = No Concurrency Overhead

**Benefits:**
- **No locks**: No mutexes, no atomics, no synchronization overhead
- **No race conditions**: Deterministic execution, easier to reason about
- **No context switching**: No thread switching overhead
- **No cache coherency**: No cache line bouncing between cores
- **Deterministic**: Same input → same output, easier to debug

**Zig Advantages:**
- **No hidden threads**: Zig doesn't spawn threads unless you explicitly do so
- **Explicit concurrency**: If you need it, you add it explicitly (async/await)
- **Single-threaded by default**: Perfect for our use case

### 2. Safety as #1 Priority

**Zig Safety Features:**
- **Type safety**: Strong typing, no implicit conversions
- **Memory safety**: Explicit allocation, no hidden allocations
- **Error handling**: Explicit error unions, no exceptions
- **Bounds checking**: Array bounds, pointer validation
- **Comptime safety**: Compile-time checks, no runtime surprises

**Our Safety Practices:**
- **Comprehensive assertions**: Validate all assumptions
- **Explicit error handling**: No silent failures
- **Static allocation**: Where possible, avoid dynamic allocation
- **Type-safe interfaces**: Strong types for syscalls, handles, etc.

### 3. Maximum Efficiency

**Efficiency Strategies:**
- **Direct function calls**: No IPC overhead (monolithic kernel)
- **Static allocation**: Where possible, avoid heap allocation
- **Comptime optimizations**: Zig's comptime for zero-cost abstractions
- **Minimal indirection**: Direct calls, no function pointer overhead
- **Cache-friendly**: Sequential memory access, predictable patterns

## Layer-by-Layer Design

### Layer 1: Hardware → SBI

**Design:**
- **Direct hardware access**: SBI functions directly access hardware
- **Minimal abstraction**: Thin wrapper around hardware operations
- **Static allocation**: SBI state is statically allocated
- **No dynamic allocation**: All SBI operations are allocation-free

**Zig Implementation:**
```zig
// SBI console putchar - direct hardware access
pub fn console_putchar(character: u8) void {
    // Assert: character must be valid (always true for u8)
    _ = character;
    
    // Direct hardware access (in real hardware, this would be inline assembly)
    // In VM, this routes to serial output (static allocation)
    
    // No allocation, no locks, no synchronization
    // Single-threaded: deterministic execution
}
```

**Safety:**
- **Assertions**: Validate all inputs
- **Type safety**: Strong types for all parameters
- **No panics**: Explicit error handling (if needed)

**Efficiency:**
- **Zero allocation**: Static allocation only
- **Direct calls**: No indirection
- **Minimal overhead**: Thin wrapper around hardware

### Layer 2: SBI → Kernel

**Design:**
- **Direct function calls**: Kernel calls SBI functions directly
- **No IPC**: Monolithic kernel, same address space
- **Static allocation**: Kernel state is statically allocated
- **Type-safe interface**: Strong types for SBI calls

**Zig Implementation:**
```zig
// Kernel calls SBI console putchar
pub fn kernel_printf(format: []const u8, args: ...) void {
    // Assert: format must be valid
    std.debug.assert(format.len > 0);
    
    // Format string (static buffer, no allocation)
    var buffer: [256]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buffer, format, args) catch return;
    
    // Call SBI directly (no IPC, no indirection)
    for (formatted) |byte| {
        sbi.console_putchar(byte);
    }
    
    // No allocation, no locks, no synchronization
    // Single-threaded: deterministic execution
}
```

**Safety:**
- **Type safety**: Strong types for SBI interface
- **Assertions**: Validate all inputs
- **Explicit error handling**: No silent failures

**Efficiency:**
- **Direct calls**: No IPC overhead
- **Static allocation**: Buffer is stack-allocated
- **Minimal indirection**: Direct function calls

### Layer 3: Kernel → Userspace

**Design:**
- **Direct syscall interface**: Userspace calls kernel syscalls directly
- **No IPC**: Monolithic kernel, same address space (in supervisor mode)
- **Type-safe syscalls**: Strong types for all syscall parameters
- **Static allocation**: Kernel syscall handlers use static allocation

**Zig Implementation:**
```zig
// Userspace calls kernel syscall
pub fn userspace_spawn(path: []const u8) Handle {
    // Assert: path must be valid
    std.debug.assert(path.len > 0);
    std.debug.assert(path.len <= 256);
    
    // ECALL to kernel (function ID >= 10)
    // In real hardware: inline assembly ECALL
    // In VM: VM handles ECALL, routes to kernel
    
    // Kernel syscall handler (direct function call, no IPC)
    const handle = basin_kernel.syscall_spawn(path);
    
    // Return handle (type-safe, no integer FDs)
    return handle;
}
```

**Safety:**
- **Type safety**: Strong types for syscalls (Handle, not int)
- **Assertions**: Validate all inputs
- **Explicit error handling**: Error unions, no exceptions

**Efficiency:**
- **Direct calls**: No IPC overhead (monolithic kernel)
- **Static allocation**: Syscall handlers use static allocation
- **Minimal indirection**: Direct function calls

### Layer 4: Userspace Applications

**Design:**
- **Single-threaded**: No concurrency, no locks
- **Static allocation**: Where possible, avoid heap allocation
- **Type-safe interfaces**: Strong types for all APIs
- **Explicit error handling**: Error unions, no exceptions

**Zig Implementation:**
```zig
// Userspace application
pub fn main() !void {
    // Static allocation: stack-allocated buffers
    var buffer: [1024]u8 = undefined;
    
    // Type-safe syscall interface
    const handle = userspace_spawn("init") catch |err| {
        // Explicit error handling
        return err;
    };
    
    // Assert: handle must be valid
    std.debug.assert(handle.is_valid());
    
    // No allocation, no locks, no synchronization
    // Single-threaded: deterministic execution
}
```

**Safety:**
- **Type safety**: Strong types throughout
- **Assertions**: Validate all assumptions
- **Explicit error handling**: No silent failures

**Efficiency:**
- **Static allocation**: Stack-allocated buffers
- **Direct calls**: No indirection
- **Minimal overhead**: Zero-cost abstractions

## Safety-First Design Patterns

### 1. Comprehensive Assertions

**Pattern:**
```zig
pub fn syscall_map(addr: u64, size: u64, flags: MapFlags) !u64 {
    // Assert: address must be page-aligned
    std.debug.assert(addr % 4096 == 0);
    
    // Assert: size must be page-aligned
    std.debug.assert(size % 4096 == 0);
    
    // Assert: size must be non-zero
    std.debug.assert(size > 0);
    
    // Assert: flags must be valid
    std.debug.assert(@intFromEnum(flags) < 8);
    
    // Implementation...
}
```

**Why:**
- **Fail fast**: Catch bugs immediately
- **Documentation**: Assertions document assumptions
- **Safety**: Validate all inputs, prevent undefined behavior

### 2. Type-Safe Interfaces

**Pattern:**
```zig
// Type-safe handle (not integer FD)
pub const Handle = struct {
    value: u64,
    
    pub fn is_valid(self: Handle) bool {
        return self.value != 0;
    }
};

// Type-safe syscall result
pub const SyscallResult = union(enum) {
    ok: u64,
    err: BasinError,
};
```

**Why:**
- **Type safety**: Compiler catches type errors
- **No magic numbers**: Handles are types, not integers
- **Explicit**: Clear what each type represents

### 3. Explicit Error Handling

**Pattern:**
```zig
pub fn syscall_open(path: []const u8, flags: OpenFlags) SyscallResult {
    // Validate inputs
    if (path.len == 0) {
        return .{ .err = .InvalidParameter };
    }
    
    // Explicit error handling (no exceptions)
    const handle = open_file(path, flags) catch |err| {
        return .{ .err = map_error(err) };
    };
    
    return .{ .ok = handle.value };
}
```

**Why:**
- **Explicit**: All errors are visible in type system
- **No exceptions**: No hidden control flow
- **Type-safe**: Error types are part of function signature

### 4. Static Allocation

**Pattern:**
```zig
// Static allocation: VM memory
pub const VM = struct {
    memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024),
    regs: RegisterFile = .{},
    // No heap allocation
};

// Static allocation: Serial output buffer
pub const SerialOutput = struct {
    buffer: [64 * 1024]u8 = [_]u8{0} ** (64 * 1024),
    write_pos: usize = 0,
    // No heap allocation
};
```

**Why:**
- **Predictable**: No allocation failures
- **Fast**: No heap allocation overhead
- **Safe**: No memory leaks, no use-after-free

## Efficiency Optimizations

### 1. Direct Function Calls

**Monolithic Kernel Advantage:**
- **No IPC**: Kernel services are direct function calls
- **No message passing**: No serialization/deserialization overhead
- **No context switching**: Same address space, same thread

**Example:**
```zig
// Userspace → Kernel: Direct function call (no IPC)
const result = basin_kernel.syscall_map(addr, size, flags);

// Kernel → SBI: Direct function call (no IPC)
sbi.console_putchar(byte);

// SBI → Hardware: Direct access (no abstraction overhead)
// (In real hardware: inline assembly)
```

### 2. Comptime Optimizations

**Zig Comptime:**
```zig
// Comptime function: Zero-cost abstraction
pub fn Syscall(comptime syscall_num: u32) type {
    return struct {
        pub fn call(arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64 {
            // Comptime-known syscall number
            return ecall(syscall_num, arg1, arg2, arg3, arg4);
        }
    };
}

// Usage: Comptime specialization
const spawn_syscall = Syscall(10);
const handle = spawn_syscall.call(path_ptr, 0, 0, 0);
```

**Why:**
- **Zero-cost**: Comptime code is eliminated at compile time
- **Type-safe**: Comptime checks catch errors early
- **Efficient**: No runtime overhead

### 3. Cache-Friendly Data Structures

**Pattern:**
```zig
// Sequential memory access (cache-friendly)
pub const RegisterFile = struct {
    regs: [32]u64 = [_]u64{0} ** 32,
    pc: u64 = 0,
    // Sequential array: cache-friendly
};

// Sequential memory access (cache-friendly)
pub const VM = struct {
    memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024),
    // Sequential array: cache-friendly
};
```

**Why:**
- **Cache-friendly**: Sequential access patterns
- **Predictable**: Deterministic memory access
- **Fast**: CPU cache hits, not misses

### 4. Minimal Indirection

**Pattern:**
```zig
// Direct function calls (no indirection)
pub fn handle_syscall(syscall_num: u32, args: SyscallArgs) u64 {
    // Direct switch (no function pointer overhead)
    return switch (syscall_num) {
        10 => syscall_spawn(args.arg1, args.arg2, args.arg3, args.arg4),
        11 => syscall_exit(args.arg1),
        12 => syscall_yield(),
        // ...
        else => return_error(.InvalidSyscall),
    };
}
```

**Why:**
- **Fast**: Direct calls, no function pointer overhead
- **Predictable**: Compiler can inline
- **Efficient**: Minimal indirection

## Single-Threaded Safety Guarantees

### 1. No Race Conditions

**Guarantee:**
- **Single thread**: Only one execution context
- **No concurrent access**: No shared mutable state conflicts
- **Deterministic**: Same input → same output

**Example:**
```zig
// Single-threaded: No race conditions
pub var global_counter: u64 = 0;

pub fn increment() void {
    // Safe: Single-threaded, no concurrent access
    global_counter += 1;
}
```

### 2. No Deadlocks

**Guarantee:**
- **No locks**: Single-threaded, no synchronization needed
- **No waiting**: No blocking operations (or explicit async/await)
- **Deterministic**: No lock ordering issues

**Example:**
```zig
// Single-threaded: No deadlocks
pub fn syscall_map(addr: u64, size: u64) !u64 {
    // No locks needed: Single-threaded
    // Direct memory access: No synchronization
    return map_memory(addr, size);
}
```

### 3. No Use-After-Free

**Guarantee:**
- **Static allocation**: Where possible, avoid dynamic allocation
- **Explicit lifetimes**: Zig's type system tracks lifetimes
- **No hidden allocations**: All allocations are explicit

**Example:**
```zig
// Static allocation: No use-after-free
pub const VM = struct {
    memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024),
    // Static: Lifetime is entire program
};
```

### 4. No Buffer Overflows

**Guarantee:**
- **Bounds checking**: Zig checks array bounds (in debug mode)
- **Type safety**: Strong types prevent type confusion
- **Explicit sizes**: All buffers have explicit sizes

**Example:**
```zig
// Bounds checking: No buffer overflows
pub fn read_memory(vm: *VM, addr: u64, size: usize) ![]u8 {
    // Assert: address + size must be within bounds
    std.debug.assert(addr + size <= vm.memory_size);
    
    // Bounds-checked access
    return vm.memory[@intCast(addr)..][0..size];
}
```

## Implementation Strategy

### Phase 1: Core Stack (Current)

**Status:** ✅ Complete
- **VM**: Pure Zig RISC-V64 emulator
- **SBI**: Tiger Style SBI wrapper
- **Kernel**: Syscall interface defined
- **Userspace**: (Future)

**Safety:**
- Comprehensive assertions ✅
- Type-safe interfaces ✅
- Explicit error handling ✅
- Static allocation ✅

**Efficiency:**
- Direct function calls ✅
- Static allocation ✅
- Minimal indirection ✅
- Single-threaded ✅

### Phase 2: Enhanced Safety

**Next Steps:**
- **Comptime validation**: Validate syscall numbers at compile time
- **Type-safe handles**: Strong types for all handles
- **Explicit lifetimes**: Track resource lifetimes explicitly
- **Bounds checking**: Comprehensive bounds checking

### Phase 3: Enhanced Efficiency

**Next Steps:**
- **Comptime optimizations**: Use comptime for zero-cost abstractions
- **Cache-friendly layouts**: Optimize data structure layouts
- **Minimal indirection**: Reduce function pointer overhead
- **Static allocation**: Expand static allocation usage

## Conclusion

**Single-Threaded Safety-First Efficiency:**

1. **Single-threaded**: No concurrency overhead, deterministic execution
2. **Safety first**: Comprehensive assertions, type safety, explicit error handling
3. **Maximum efficiency**: Direct calls, static allocation, comptime optimizations
4. **Layered architecture**: Hardware → SBI → Kernel → Userspace, each layer optimized

**Zig Advantages:**
- **Type safety**: Strong typing, no implicit conversions
- **Explicit allocation**: No hidden allocations
- **Comptime**: Zero-cost abstractions
- **Error handling**: Explicit error unions
- **Single-threaded by default**: Perfect for our use case

**Result:**
- **Safe**: Comprehensive assertions, type safety, explicit error handling
- **Efficient**: Direct calls, static allocation, minimal indirection
- **Simple**: Single-threaded, deterministic, easy to reason about
- **Tiger Style**: All principles applied throughout the stack

