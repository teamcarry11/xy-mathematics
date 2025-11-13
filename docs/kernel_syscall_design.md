# Grain Basin kernel: Core Syscall Design for RISC-V

**Date**: 2025-11-13  
**Operator**: Glow G2 (Stoic Aquarian cadence)  
**Target**: Framework 13 DeepComputing RISC-V Mainboard  
**Kernel Name**: Grain Basin kernel 🏞️ - "The foundation that holds everything"  
**Homebrew Bundle**: `grainbasin`  
**Philosophy**: Modern, minimal, non-POSIX, Tiger Style safety

## Design Principles

### 1. Minimal Syscall Surface
- **Principle**: Fewer syscalls = smaller attack surface, easier verification, better performance
- **Inspiration**: seL4's minimal kernel (4 syscalls), Theseus OS's capability-based design
- **Approach**: Essential operations only, user-space libraries handle complexity

### 2. Capability-Based Security (Optional Future Enhancement)
- **Current**: Traditional syscalls with explicit permissions
- **Future**: Object capabilities for fine-grained access control
- **Reference**: seL4's capability model, but adapted for Zig's type system

### 3. Type-Safe Abstractions
- **Zig Advantage**: Leverage comptime, error unions, explicit memory management
- **Avoid**: POSIX's string-based paths, file descriptors as integers
- **Use**: Strongly-typed handles, compile-time validated operations

### 4. RISC-V Native Design
- **Target**: RISC-V64 ISA (matches Framework 13 hardware)
- **Avoid**: x86-isms, legacy compatibility layers
- **Embrace**: RISC-V's clean instruction set, modern memory model

## Core Syscall Categories

### Category 1: Process & Thread Management (Essential)

#### `spawn(executable: Handle, args: []const []const u8) Handle`
- **Purpose**: Create new process (not fork/clone - avoid COW complexity)
- **Why**: Explicit process creation, no implicit copying
- **Return**: Process handle (strongly typed, not integer FD)
- **Tiger Style**: Validate executable handle, args bounds, memory allocation

#### `exit(status: u8) noreturn`
- **Purpose**: Terminate current process
- **Why**: Simple, explicit termination
- **Tiger Style**: Validate status code, cleanup resources deterministically

#### `yield() void`
- **Purpose**: Voluntary CPU yield (cooperative scheduling hint)
- **Why**: Enable user-space scheduling libraries, reduce kernel complexity
- **Tiger Style**: No-op if no other runnable processes

#### `wait(process: Handle) u8`
- **Purpose**: Wait for process termination, get exit status
- **Why**: Explicit synchronization, avoid complex signal handling
- **Tiger Style**: Validate handle, timeout mechanism

### Category 2: Memory Management (Essential)

#### `map(addr: ?u64, size: usize, flags: MapFlags) Handle`
- **Purpose**: Map memory region (virtual memory allocation)
- **Why**: Explicit memory management, no implicit heap
- **Flags**: READ, WRITE, EXECUTE, SHARED (capability-based)
- **Tiger Style**: Validate size, alignment, address bounds

#### `unmap(region: Handle) void`
- **Purpose**: Unmap memory region
- **Why**: Explicit deallocation, deterministic cleanup
- **Tiger Style**: Validate handle, ensure no dangling references

#### `protect(region: Handle, flags: MapFlags) void`
- **Purpose**: Change memory protection (mprotect equivalent)
- **Why**: Security-critical operation, explicit permissions
- **Tiger Style**: Validate handle, flags, ensure no privilege escalation

### Category 3: Inter-Process Communication (Essential)

#### `channel_create() (Handle, Handle)`
- **Purpose**: Create bidirectional communication channel
- **Why**: Explicit IPC, avoid shared memory complexity initially
- **Return**: Two handles (send, receive ends)
- **Tiger Style**: Validate handle creation, memory allocation

#### `channel_send(channel: Handle, data: []const u8) void`
- **Purpose**: Send data through channel
- **Why**: Type-safe message passing
- **Tiger Style**: Validate handle, data bounds, buffer size limits

#### `channel_recv(channel: Handle, buffer: []u8) usize`
- **Purpose**: Receive data from channel
- **Why**: Explicit receive, avoid blocking complexity initially
- **Return**: Bytes received (0 if no data available)
- **Tiger Style**: Validate handle, buffer bounds

### Category 4: I/O Operations (Essential)

#### `open(path: []const u8, flags: OpenFlags) Handle`
- **Purpose**: Open file/device (simplified, no POSIX complexity)
- **Why**: Essential for file system access
- **Flags**: READ, WRITE, CREATE, TRUNCATE (explicit, not POSIX O_*)
- **Tiger Style**: Validate path bounds, flags, path traversal prevention

#### `read(handle: Handle, buffer: []u8) usize`
- **Purpose**: Read from file/device
- **Why**: Essential I/O operation
- **Return**: Bytes read (0 on EOF)
- **Tiger Style**: Validate handle, buffer bounds, handle type

#### `write(handle: Handle, data: []const u8) usize`
- **Purpose**: Write to file/device
- **Why**: Essential I/O operation
- **Return**: Bytes written
- **Tiger Style**: Validate handle, data bounds, handle type

#### `close(handle: Handle) void`
- **Purpose**: Close file/device handle
- **Why**: Explicit resource cleanup
- **Tiger Style**: Validate handle, ensure no double-close

### Category 5: Time & Scheduling (Essential)

#### `clock_gettime(clock: ClockId) u64`
- **Purpose**: Get current time (nanoseconds since epoch)
- **Why**: Essential for timers, scheduling
- **ClockId**: MONOTONIC, REALTIME (explicit, not POSIX CLOCK_*)
- **Tiger Style**: Validate clock ID, ensure monotonicity guarantees

#### `sleep_until(timestamp: u64) void`
- **Purpose**: Sleep until absolute timestamp
- **Why**: Precise timing, avoid relative sleep complexity
- **Tiger Style**: Validate timestamp, ensure no time travel bugs

### Category 6: System Information (Essential)

#### `sysinfo() SysInfo`
- **Purpose**: Get system information (memory, CPU, etc.)
- **Why**: Essential for user-space libraries
- **Return**: Strongly-typed struct (not POSIX sysinfo)
- **Tiger Style**: Validate struct fields, ensure atomic reads

## Syscalls NOT Included (Avoid POSIX Legacy)

### Avoided for Simplicity
- **fork/clone**: Use `spawn` instead (explicit, no COW complexity)
- **execve**: Handled by `spawn` (simpler interface)
- **signal/sigaction**: Use channels/IPC instead (explicit communication)
- **mmap with MAP_SHARED**: Use explicit channels initially (simpler security model)
- **select/poll/epoll**: User-space libraries handle this (reduce kernel complexity)
- **fcntl**: Use explicit syscalls instead (no magic flags)
- **ioctl**: Use typed syscalls instead (type safety)

### Avoided for Security
- **ptrace**: Use explicit debugging interface (if needed)
- **setuid/setgid**: Use capability-based model (future)
- **chroot**: Use namespace syscalls (if needed, future)

## Implementation Strategy

### Phase 1: Minimal Viable Kernel (Current)
- **Syscalls**: `spawn`, `exit`, `yield`, `map`, `unmap`, `open`, `read`, `write`, `close`
- **Goal**: Boot kernel, run simple programs, basic I/O
- **Tiger Style**: Comprehensive assertions, static allocation where possible

### Phase 2: IPC & Scheduling
- **Add**: `channel_create`, `channel_send`, `channel_recv`, `wait`, `sleep_until`
- **Goal**: Multi-process support, inter-process communication
- **Tiger Style**: Validate all IPC operations, prevent deadlocks

### Phase 3: Advanced Features
- **Add**: `protect`, `clock_gettime`, `sysinfo`
- **Goal**: Security features, timing, system introspection
- **Tiger Style**: Capability-based permissions (future)

## References & Inspiration

### Modern Kernel Designs
- **Linux (Monolithic)**: High performance, proven scalability, but complex and legacy-heavy
- **Aero OS (Rust)**: Monolithic kernel, Linux-inspired, runs real applications (Alacritty, Git, GTK+, Xorg, DOOM), but x86_64 only (no RISC-V)
- **Theseus OS (Rust)**: Single Address Space (SAS) and Single Privilege Level (SPL) OS, type-safe, non-POSIX, excellent safety (NOT traditional monolithic)
- **Fuchsia (Zircon)**: Capability-based monolithic kernel, modern syscall design, good performance
- **seL4**: Microkernel with formal verification (excellent safety, but IPC overhead limits performance)
- **Redox OS**: Microkernel (good safety ideas, but IPC overhead makes it slower than monolithic)

### Zig-Specific Considerations
- **comptime**: Use for syscall validation, type checking
- **Error Unions**: Explicit error handling (no errno)
- **Static Allocation**: Prefer static buffers for syscall arguments
- **Tiger Style**: Assertions, bounds checking, deterministic behavior

### Matklad's Insights (from blog)
- **Simplicity**: "Write Less" - minimal syscall surface
- **Type Safety**: Leverage Zig's type system for safety
- **Performance**: Explicit control, no hidden allocations
- **Developer Experience**: Clear error messages, deterministic behavior

## Kernel Architecture: Monolithic vs Microkernel

### Decision: **Monolithic Kernel** (Grain Basin kernel)

**Why Monolithic:**
- **Performance**: Direct function calls, no IPC overhead, optimal for high-throughput workloads
- **Tiger Style Priority**: Performance is a core requirement (alongside safety)
- **Real-World Evidence**: Linux, FreeBSD, DragonFly BSD all use monolithic design for performance
- **Aero OS Model**: Monolithic Rust kernel proves modern type-safe monolithic kernels work (runs real apps)
- **RISC-V Targeting**: Aero doesn't target RISC-V; Grain Basin kernel fills this gap

**Why NOT Microkernel:**
- **Performance Cost**: IPC overhead (context switches, message passing) adds latency
- **seL4 Reality**: Formally verified but slower than Linux for real workloads
- **Redox Reality**: Good safety ideas but performance suffers from microkernel architecture
- **Tiger Style**: "10-year project in 3.5 years" requires performance, not academic purity

**Safety in Monolithic Kernel:**
- **Zig Type Safety**: Leverage Zig's type system, comptime checks, explicit memory management
- **Aero OS Approach**: Monolithic Rust kernel proves modern type-safe monolithic kernels work
- **Comprehensive Assertions**: Tiger Style assertions catch bugs at development time
- **Minimal Attack Surface**: Small syscall surface reduces vulnerability exposure
- **Capability-Based Design**: Use capabilities for fine-grained permissions (future)
- **RISC-V Native**: Design for RISC-V64 from ground up (not ported from x86)

### Modern I/O Design: io_uring-Inspired Async I/O

**Linux io_uring Principles:**
- **Submission/Completion Queues**: Separate queues for requests and completions
- **Zero-Copy**: Direct memory access, minimize copies
- **Batch Operations**: Submit multiple I/O operations atomically
- **Polling Mode**: Optional polling for ultra-low latency (bypass interrupts)

**Grain Basin Kernel Equivalent:**
- **Async I/O Syscalls**: `io_submit(queue: Handle, ops: []IOOp) usize`, `io_complete(queue: Handle, results: []IOResult) usize`
- **Queue-Based Design**: User-space queues, kernel processes asynchronously
- **Zero-Copy**: Direct memory mapping for I/O buffers
- **Batch Operations**: Submit multiple I/O operations in one syscall
- **Tiger Style**: Type-safe I/O operations, explicit error handling

### Linux Kernel Interfaces Worth Keeping

**Good Interfaces (Adapt for Grain Basin):**
1. **Memory Mapping**: `mmap` concept (but typed handles, not FDs)
2. **Event Notification**: `epoll`/`io_uring` async I/O model
3. **Process Management**: Process groups, namespaces (simplified)
4. **File System**: VFS abstraction (but type-safe, not POSIX paths)
5. **Scheduling**: CFS-like fair scheduler (but simpler, deterministic)

**Interfaces to Avoid (POSIX Legacy):**
1. **File Descriptors**: Use typed handles instead
2. **String Paths**: Use typed path handles or capability-based access
3. **Signal System**: Use channels/IPC instead
4. **fork/clone**: Use explicit `spawn` instead
5. **ioctl**: Use typed syscalls instead

### 30-Year Vision: Adapting Linux Concepts

**What to Keep:**
- **Monolithic Architecture**: Proven performance, scalable
- **Async I/O Model**: io_uring-style queues for high-performance I/O
- **Memory Management**: Virtual memory, page tables, but simplified
- **Process Model**: Processes + threads, but explicit and type-safe

**What to Modernize:**
- **Type Safety**: Zig's type system replaces C's weak typing
- **Explicit Errors**: Error unions instead of errno
- **Capability-Based Security**: Fine-grained permissions, not user/group
- **Non-POSIX**: Clean slate, no legacy compatibility burden
- **RISC-V Native**: Design for RISC-V64, not x86 legacy

**What to Add:**
- **Deterministic Scheduling**: Predictable behavior for real-time systems
- **Explicit Resource Management**: No hidden allocations, explicit cleanup
- **Comptime Validation**: Zig comptime for syscall validation
- **Formal Verification**: Where possible, prove correctness (selective, not full seL4)

## Notes

- **Monolithic Kernel**: Chosen for performance (Tiger Style priority)
- **Type-Safe Monolithic**: Theseus OS proves safety + performance is achievable
- **Non-POSIX**: Deliberately avoid POSIX compatibility layer
- **RISC-V Native**: Design for RISC-V64, not x86 legacy
- **30-Year Vision**: Design for next 30 years, not backward compatibility
- **Tiger Style**: Maximum safety, explicit operations, comprehensive assertions
- **Performance First**: High-performance async I/O (io_uring-inspired), zero-copy, batching

