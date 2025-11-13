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
- **seL4**: Minimal syscall surface (4 syscalls), formal verification
- **Theseus OS (Rust)**: Type-safe kernel, capability-based, non-POSIX
- **Fuchsia (Zircon)**: Capability-based, modern syscall design
- **Redox OS**: Microkernel (too slow, but good IPC ideas)

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

## Notes

- **Non-POSIX**: Deliberately avoid POSIX compatibility layer
- **RISC-V Native**: Design for RISC-V64, not x86 legacy
- **30-Year Vision**: Design for next 30 years, not backward compatibility
- **Tiger Style**: Maximum safety, explicit operations, comprehensive assertions

