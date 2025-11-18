# Zig Parallelism: Options and Strategies for Grain Basin Kernel

**Date**: 2025-11-15  
**Purpose**: Document Zig's parallelism options and how they relate to Grain Basin kernel's single-threaded architecture

## Overview

Zig provides several parallelism options, each with different trade-offs:

1. **async/await** - Cooperative concurrency (single-threaded event loop)
2. **std.Thread** - OS threads (true parallelism)
3. **std.Thread.Pool** - Thread pool for parallel work
4. **std.Thread.Mutex** - Synchronization primitives

## Grain Basin Kernel Context

**Current Architecture**: Single-threaded safety-first efficiency
- **Kernel**: Single-threaded, no locks, deterministic execution
- **Userspace**: Single-threaded by default, but can use parallelism if needed
- **Design Philosophy**: Maximum efficiency through single-threaded architecture

**When to Use Parallelism**:
- **Userspace Programs**: Applications that need parallelism (e.g., parallel computation, I/O multiplexing)
- **Kernel**: Remains single-threaded (no parallelism in kernel itself)
- **VM**: Single-threaded (deterministic execution)

## Option 1: async/await (Cooperative Concurrency)

**What**: Single-threaded event loop with cooperative multitasking  
**Use Case**: I/O multiplexing, concurrent operations without true parallelism  
**Benefits**: No locks needed, deterministic, efficient  
**Drawbacks**: No true parallelism (single CPU core)

### Example: async/await for I/O

```zig
const std = @import("std");

// Async I/O example (userspace)
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create async frame for concurrent I/O
    var read_frame = async read_file(allocator, "file1.txt");
    var write_frame = async write_file(allocator, "file2.txt", "data");

    // Wait for both to complete (cooperative, not parallel)
    const read_result = try await read_frame;
    const write_result = try await write_frame;

    std.debug.print("Read: {s}\n", .{read_result});
    std.debug.print("Write: {}\n", .{write_result});
}

fn read_file(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

fn write_file(allocator: std.mem.Allocator, path: []const u8, data: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(data);
}
```

### How It Works

1. **async**: Creates an async frame (suspended coroutine)
2. **await**: Suspends current function, resumes when async operation completes
3. **Event Loop**: Single-threaded event loop manages all async operations
4. **Cooperative**: Functions yield control explicitly (no preemption)

### Benefits for Grain Basin

- **No Locks**: Single-threaded, no synchronization needed
- **Deterministic**: Same input → same output
- **Efficient**: No context switching overhead
- **Safe**: No race conditions (single thread)

## Option 2: std.Thread (OS Threads)

**What**: True parallelism using OS threads  
**Use Case**: CPU-intensive parallel computation  
**Benefits**: True parallelism (multiple CPU cores)  
**Drawbacks**: Requires synchronization (mutexes, atomics), non-deterministic

### Example: Parallel Computation

```zig
const std = @import("std");

// Parallel computation example (userspace)
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const num_threads = 4;
    const work_per_thread = 1000;

    // Shared result (requires synchronization)
    var shared_result: u64 = 0;
    var mutex = std.Thread.Mutex{};

    // Spawn threads
    var threads: [num_threads]std.Thread = undefined;
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, compute_work, .{
            i * work_per_thread,
            (i + 1) * work_per_thread,
            &shared_result,
            &mutex,
        });
    }

    // Wait for all threads
    for (threads) |thread| {
        thread.join();
    }

    std.debug.print("Result: {}\n", .{shared_result});
}

fn compute_work(start: u64, end: u64, result: *u64, mutex: *std.Thread.Mutex) void {
    var local_sum: u64 = 0;
    var i = start;
    while (i < end) : (i += 1) {
        local_sum += i;
    }

    // Synchronize access to shared result
    mutex.lock();
    defer mutex.unlock();
    result.* += local_sum;
}
```

### Synchronization Primitives

```zig
// Mutex for shared mutable state
var mutex = std.Thread.Mutex{};
mutex.lock();
defer mutex.unlock();
// Critical section

// Atomic operations (lock-free)
var counter = std.atomic.Value(u64).init(0);
_ = counter.fetchAdd(1, .seq_cst); // Atomic increment

// Condition variable (for waiting)
var cond = std.Thread.Condition{};
cond.wait(&mutex); // Wait for signal
cond.signal(); // Signal one waiter
cond.broadcast(); // Signal all waiters
```

### When to Use Threads

**Good For**:
- CPU-intensive parallel computation
- Independent work that can run in parallel
- When true parallelism is needed (multiple CPU cores)

**Not Good For**:
- Kernel code (Grain Basin kernel is single-threaded)
- When determinism is required
- When locks would add significant overhead

## Option 3: std.Thread.Pool (Thread Pool)

**What**: Managed thread pool for parallel work  
**Use Case**: Parallel computation with controlled thread count  
**Benefits**: Efficient thread reuse, controlled parallelism  
**Drawbacks**: Still requires synchronization

### Example: Thread Pool

```zig
const std = @import("std");

// Thread pool example (userspace)
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create thread pool (4 threads)
    var pool = std.Thread.Pool.init(.{ .allocator = allocator });
    defer pool.deinit();

    // Submit work to pool
    const num_tasks = 10;
    var results: [num_tasks]u64 = undefined;
    var tasks: [num_tasks]std.Thread.Pool.Task = undefined;

    for (&tasks, 0..) |*task, i| {
        task.* = std.Thread.Pool.Task{
            .callback = compute_task,
            .data = .{ .index = i, .result = &results[i] },
        };
        try pool.spawn(task);
    }

    // Wait for all tasks to complete
    pool.waitAndWork();

    // Use results
    for (results, 0..) |result, i| {
        std.debug.print("Task {}: {}\n", .{ i, result });
    }
}

const TaskData = struct {
    index: usize,
    result: *u64,
};

fn compute_task(data: *TaskData) void {
    // Compute work
    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < 1000) : (i += 1) {
        sum += i;
    }
    data.result.* = sum;
}
```

### Benefits

- **Thread Reuse**: Efficient thread management
- **Controlled Parallelism**: Fixed number of threads
- **Task Queue**: Automatic work distribution

## Option 4: Hybrid Approach (async + Threads)

**What**: Combine async/await for I/O with threads for CPU work  
**Use Case**: Mixed I/O and CPU-intensive workloads  
**Benefits**: Best of both worlds  
**Drawbacks**: More complex

### Example: Hybrid

```zig
const std = @import("std");

// Hybrid async + threads (userspace)
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Async I/O (cooperative)
    var io_frame = async read_file_async(allocator, "data.txt");

    // Parallel CPU work (threads)
    var pool = std.Thread.Pool.init(.{ .allocator = allocator });
    defer pool.deinit();

    var result: u64 = 0;
    var task = std.Thread.Pool.Task{
        .callback = compute_heavy,
        .data = &result,
    };
    try pool.spawn(&task);

    // Wait for both
    const file_data = try await io_frame;
    pool.waitAndWork();

    std.debug.print("File: {s}, Compute: {}\n", .{ file_data, result });
}

fn read_file_async(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    // Async I/O (cooperative)
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

fn compute_heavy(data: *u64) void {
    // CPU-intensive work (parallel)
    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < 1000000) : (i += 1) {
        sum += i;
    }
    data.* = sum;
}
```

## Recommendations for Grain Basin Kernel

### Kernel Layer: Single-Threaded ✅

**Keep kernel single-threaded**:
- No `std.Thread` in kernel code
- No mutexes, no atomics
- Deterministic execution
- Maximum efficiency

**Rationale**:
- Kernel is already efficient (direct function calls)
- Single-threaded eliminates race conditions
- Deterministic execution is valuable for kernel code
- No context switching overhead

### Userspace Layer: Parallelism When Needed ✅

**Allow parallelism in userspace**:
- Applications can use `std.Thread` for parallel computation
- Applications can use `async/await` for I/O multiplexing
- Kernel provides syscalls, userspace manages parallelism

**Example Userspace Program**:

```zig
// userspace/parallel_app.zig
const std = @import("std");
const stdlib = @import("userspace_stdlib");

// Userspace program using parallelism
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parallel computation (userspace)
    const num_threads = 4;
    var threads: [num_threads]std.Thread = undefined;
    var results: [num_threads]u64 = undefined;

    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, compute_chunk, .{
            i * 1000,
            (i + 1) * 1000,
            &results[i],
        });
    }

    for (threads) |thread| {
        thread.join();
    }

    // Use syscalls (kernel remains single-threaded)
    var sum: u64 = 0;
    for (results) |result| {
        sum += result;
    }

    stdlib.print("Sum: {}\n", .{sum});
    stdlib.exit(0);
}

fn compute_chunk(start: u64, end: u64, result: *u64) void {
    var sum: u64 = 0;
    var i = start;
    while (i < end) : (i += 1) {
        sum += i;
    }
    result.* = sum;
}
```

### VM Layer: Single-Threaded ✅

**Keep VM single-threaded**:
- VM executes RISC-V instructions sequentially
- Deterministic execution (valuable for testing)
- No parallelism in VM itself

**Rationale**:
- VM is for testing/debugging (determinism is valuable)
- Single-threaded matches kernel architecture
- Simpler implementation

## Summary

| Layer | Parallelism | Rationale |
|-------|-------------|-----------|
| **Kernel** | ❌ Single-threaded | Maximum efficiency, no locks, deterministic |
| **Userspace** | ✅ Optional | Applications can use threads/async as needed |
| **VM** | ❌ Single-threaded | Deterministic execution, matches kernel |

## Best Practices

1. **Kernel**: Always single-threaded, no parallelism
2. **Userspace**: Use parallelism when needed (CPU-intensive work)
3. **I/O**: Prefer `async/await` for I/O multiplexing (cooperative)
4. **Computation**: Use `std.Thread` for CPU-intensive parallel work
5. **Synchronization**: Use mutexes/atomics only in userspace, never in kernel

## Future Considerations

**If Kernel Parallelism is Needed** (unlikely):
- Would require redesigning architecture
- Would lose single-threaded benefits
- Would need synchronization primitives
- **Recommendation**: Keep kernel single-threaded, allow userspace parallelism

**Userspace Parallelism Support**:
- Kernel syscalls remain single-threaded (no changes needed)
- Userspace programs can use Zig's threading APIs
- Kernel provides process isolation (via `spawn` syscall)
- Each process can have its own threads

## References

- [Zig std.Thread documentation](https://ziglang.org/documentation/master/std/#A;std:Thread)
- [Zig async/await documentation](https://ziglang.org/documentation/master/#Async-Functions)
- `docs/single_threaded_safety_efficiency.md` - Kernel architecture rationale

