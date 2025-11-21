# Grain Vantage VM API Reference

> Complete API reference for Grain Vantage RISC-V64 emulator.
> GrainStyle: Explicit types, comprehensive contracts, deterministic behavior.

## Overview

Grain Vantage is a pure Zig RISC-V64 emulator designed for kernel development
and safety-critical systems. It provides a complete RISC-V64 instruction set
implementation with JIT acceleration, performance monitoring, error handling,
and state persistence.

## Core Types

### `VM`

The main virtual machine structure. Encapsulates all VM state including
registers, memory, execution state, and subsystems.

```zig
pub const VM = struct {
    regs: RegisterFile,
    memory: [VM_MEMORY_SIZE]u8,
    memory_size: u64,
    state: VMState,
    // ... subsystems
};
```

### `VMState`

VM execution state enumeration.

```zig
pub const VMState = enum {
    running,  // VM is executing instructions
    halted,   // VM has stopped (normal termination)
    errored,  // VM encountered an error
};
```

### `VMError`

VM error types.

```zig
pub const VMError = error{
    invalid_instruction,
    invalid_memory_access,
    unaligned_instruction,
    unaligned_memory_access,
};
```

## Initialization

### `init()`

Initialize VM with kernel image loaded at address.

**Signature:**
```zig
pub fn init(target: *Self, kernel_image: []const u8, load_address: u64) void
```

**Contract:**
- Input: `target` must point to uninitialized VM struct
- Input: `load_address` must be 4-byte aligned
- Input: `kernel_image` must fit in VM memory
- Output: Initialized VM in halted state, PC set to load_address

**Example:**
```zig
var vm: VM = undefined;
const program = [_]u8{0x13, 0x00, 0x00, 0x00}; // NOP
VM.init(&vm, &program, 0x80000000);
```

### `init_with_jit()`

Initialize VM with JIT support enabled.

**Signature:**
```zig
pub fn init_with_jit(
    target: *Self,
    allocator: std.mem.Allocator,
    kernel_image: []const u8,
    load_address: u64
) !void
```

**Contract:**
- Input: Same as `init()`, plus allocator for JIT code buffer
- Output: Initialized VM with JIT enabled, ready for accelerated execution
- Errors: Memory allocation failure

**Example:**
```zig
var vm: VM = undefined;
try VM.init_with_jit(&vm, allocator, &program, 0x80000000);
defer vm.deinit_jit(allocator);
```

## Execution Control

### `start()`

Start VM execution (set state to running).

**Signature:**
```zig
pub fn start(self: *Self) void
```

**Contract:**
- Precondition: VM must be in halted or errored state
- Postcondition: VM state is running, last_error is cleared

**Example:**
```zig
vm.start();
```

### `stop()`

Stop VM execution (set state to halted).

**Signature:**
```zig
pub fn stop(self: *Self) void
```

**Contract:**
- Precondition: VM must be in running state
- Postcondition: VM state is halted

**Example:**
```zig
vm.stop();
```

### `step()`

Execute single instruction (interpreter mode).

**Signature:**
```zig
pub fn step(self: *Self) VMError!void
```

**Contract:**
- Precondition: VM must be in running state
- Postcondition: One instruction executed, PC advanced (unless branch)
- Errors: Invalid instruction, memory access error

**Example:**
```zig
vm.start();
while (vm.state == .running) {
    vm.step() catch |err| {
        std.debug.print("Error: {}\n", .{err});
        break;
    }
}
```

### `step_jit()`

Execute with JIT (if enabled), fall back to interpreter if JIT fails.

**Signature:**
```zig
pub fn step_jit(self: *Self) VMError!void
```

**Contract:**
- Precondition: VM must be in running or halted state
- Postcondition: Instruction executed via JIT or interpreter
- Errors: Invalid instruction, memory access error

**Example:**
```zig
vm.start();
while (vm.state == .running) {
    vm.step_jit() catch |err| {
        std.debug.print("Error: {}\n", .{err});
        break;
    }
}
```

## Memory Operations

### `read64()`

Read 64-bit value from memory (little-endian).

**Signature:**
```zig
pub fn read64(self: *const Self, addr: u64) VMError!u64
```

**Contract:**
- Precondition: Address must be within memory bounds, 8-byte aligned
- Postcondition: Returns 64-bit value from memory
- Errors: Unaligned access, invalid memory access

**Example:**
```zig
const value = try vm.read64(0x80000000);
```

### `write64()`

Write 64-bit value to memory (little-endian).

**Signature:**
```zig
pub fn write64(self: *Self, addr: u64, value: u64) VMError!void
```

**Contract:**
- Precondition: Address must be within memory bounds, 8-byte aligned
- Postcondition: Value written to memory
- Errors: Unaligned access, invalid memory access

**Example:**
```zig
try vm.write64(0x80000000, 0x1234567890ABCDEF);
```

### `translate_address()`

Translate virtual address to physical offset in VM memory.

**Signature:**
```zig
pub fn translate_address(self: *const Self, virt_addr: u64) ?u64
```

**Contract:**
- Input: Virtual address (0x80000000+ for kernel, 0x90000000+ for framebuffer)
- Output: Physical offset in VM memory, or null if invalid
- Memory Layout:
  - 0x80000000+: Kernel code/data → offset 0+
  - 0x90000000+: Framebuffer → offset (memory_size - framebuffer_size)+

**Example:**
```zig
const phys_offset = vm.translate_address(0x90000000);
if (phys_offset) |offset| {
    // Access framebuffer at offset
}
```

### `get_framebuffer_memory()`

Get framebuffer memory slice.

**Signature:**
```zig
pub fn get_framebuffer_memory(self: *Self) []u8
```

**Contract:**
- Precondition: VM must be initialized
- Postcondition: Returns slice of VM memory at framebuffer base address
- Note: Framebuffer is at 0x90000000, mapped to end of VM memory

**Example:**
```zig
const fb_memory = vm.get_framebuffer_memory();
// fb_memory is 1024x768x4 = 3MB
```

## Syscall Handling

### `set_syscall_handler()`

Set syscall handler callback.

**Signature:**
```zig
pub fn set_syscall_handler(
    self: *Self,
    handler: *const fn (syscall_num: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64,
    user_data: ?*anyopaque
) void
```

**Contract:**
- Input: Handler function pointer, optional user data
- Postcondition: Syscall handler is set, ECALL instructions will call handler
- Note: Handler receives syscall number in a7 (x17), arguments in a0-a3 (x10-x13)

**Example:**
```zig
fn my_syscall_handler(
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64
) u64 {
    // Handle syscall
    return 0; // Success
}

vm.set_syscall_handler(my_syscall_handler, null);
```

## Input Events

### `inject_mouse_event()`

Inject mouse event into VM input queue.

**Signature:**
```zig
pub fn inject_mouse_event(
    self: *Self,
    kind: u8,
    button: u8,
    x: f64,
    y: f64,
    modifiers: u8
) void
```

**Contract:**
- Input: Event kind (0=down, 1=up, 2=move, 3=drag), button (0=left, 1=right, 2=middle), coordinates, modifiers
- Postcondition: Event enqueued in input event queue
- Note: Coordinates are automatically scaled to framebuffer (1024x768)

**Example:**
```zig
vm.inject_mouse_event(0, 0, 100.0, 200.0, 0); // Left button down at (100, 200)
```

### `inject_keyboard_event()`

Inject keyboard event into VM input queue.

**Signature:**
```zig
pub fn inject_keyboard_event(
    self: *Self,
    kind: u8,
    key_code: u32,
    character: u32,
    modifiers: u8
) void
```

**Contract:**
- Input: Event kind (0=down, 1=up), key code, Unicode character, modifiers
- Postcondition: Event enqueued in input event queue

**Example:**
```zig
vm.inject_keyboard_event(0, 36, 'A', 0); // Key 'A' pressed
```

## Performance Monitoring

### `print_performance()`

Print performance metrics summary.

**Signature:**
```zig
pub fn print_performance(self: *const Self) void
```

**Contract:**
- Precondition: VM must be initialized
- Postcondition: Performance metrics printed to stdout

**Example:**
```zig
vm.print_performance();
// Output:
// === VM Performance Metrics ===
// Instructions executed: 1000
// Cycles simulated: 1000
// IPC: 1.000
// ...
```

### `get_diagnostics()`

Get diagnostics snapshot.

**Signature:**
```zig
pub fn get_diagnostics(self: *const Self) DiagnosticsSnapshot
```

**Contract:**
- Precondition: VM must be initialized
- Postcondition: Returns snapshot with VM state and metrics

**Example:**
```zig
const snapshot = vm.get_diagnostics();
snapshot.print();
```

## State Persistence

### `save_state()`

Save VM state to snapshot.

**Signature:**
```zig
pub fn save_state(self: *const Self, memory_buffer: []u8) !VMStateSnapshot
```

**Contract:**
- Precondition: VM must be initialized, memory_buffer must be large enough
- Postcondition: Returns snapshot with complete VM state
- Errors: Memory buffer too small

**Example:**
```zig
var memory_buffer: [VM_MEMORY_SIZE]u8 = undefined;
const snapshot = try vm.save_state(&memory_buffer);
```

### `restore_state()`

Restore VM state from snapshot.

**Signature:**
```zig
pub fn restore_state(self: *Self, snapshot: *const VMStateSnapshot) !void
```

**Contract:**
- Precondition: VM must be initialized, snapshot must be valid
- Postcondition: VM state restored to snapshot state
- Errors: Invalid snapshot, memory size mismatch

**Example:**
```zig
try vm.restore_state(&snapshot);
```

## Framebuffer Operations

### `init_framebuffer()`

Initialize framebuffer from host-side code.

**Signature:**
```zig
pub fn init_framebuffer(self: *Self) void
```

**Contract:**
- Precondition: VM must be initialized
- Postcondition: Framebuffer cleared to background color, test pattern drawn
- Note: Called automatically by Integration.finish_init()

**Example:**
```zig
vm.init_framebuffer();
```

## JIT Management

### `enable_jit()`

Enable JIT on an already-initialized VM.

**Signature:**
```zig
pub fn enable_jit(self: *Self, allocator: std.mem.Allocator) !void
```

**Contract:**
- Precondition: VM must be initialized, JIT must not already be enabled
- Postcondition: JIT enabled, ready for accelerated execution
- Errors: Memory allocation failure

**Example:**
```zig
try vm.enable_jit(allocator);
```

### `deinit_jit()`

Deinitialize JIT (if enabled).

**Signature:**
```zig
pub fn deinit_jit(self: *Self, allocator: std.mem.Allocator) void
```

**Contract:**
- Precondition: VM must be initialized
- Postcondition: JIT deinitialized, memory freed

**Example:**
```zig
vm.deinit_jit(allocator);
```

## Memory Layout

### Virtual Address Space

```
0x00000000 - 0x7FFFFFFF: Reserved (not used)
0x80000000 - 0x8FFFFFFF: Kernel code/data (128MB virtual, 4MB physical)
0x90000000 - 0x900BBFFF: Framebuffer (1024x768x4 = 3MB)
```

### Physical Memory Layout

```
Offset 0+              : Kernel code/data
Offset (size-3MB)+     : Framebuffer
```

## Constants

### `VM_MEMORY_SIZE`

Total VM memory size (8MB default).

```zig
pub const VM_MEMORY_SIZE: u64 = 8 * 1024 * 1024; // 8MB
```

### Framebuffer Constants

```zig
pub const FRAMEBUFFER_WIDTH: u32 = 1024;
pub const FRAMEBUFFER_HEIGHT: u32 = 768;
pub const FRAMEBUFFER_BPP: u32 = 4; // 32-bit RGBA
pub const FRAMEBUFFER_SIZE: u32 = FRAMEBUFFER_WIDTH * FRAMEBUFFER_HEIGHT * FRAMEBUFFER_BPP; // 3MB
```

## Error Handling

VM errors are returned via `VMError` enum. Common errors:

- `invalid_instruction`: Unsupported or malformed instruction
- `invalid_memory_access`: Address out of bounds
- `unaligned_instruction`: PC not 4-byte aligned
- `unaligned_memory_access`: Memory access not properly aligned

Error logging is available via `error_log` field. Recent errors can be
retrieved using `error_log.get_recent()`.

## Performance Considerations

- **JIT Acceleration**: Use `step_jit()` for 10x+ speedup on hot paths
- **Dirty Region Tracking**: Framebuffer sync only copies changed regions
- **Performance Metrics**: Track execution via `performance` field
- **State Persistence**: Save/restore state for debugging and testing

## Example: Complete VM Usage

```zig
const std = @import("std");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize VM with JIT
    var vm: VM = undefined;
    const program = [_]u8{
        0x93, 0x00, 0xA0, 0x02, // ADDI x1, x0, 42
    };
    try VM.init_with_jit(&vm, allocator, &program, 0x80000000);
    defer vm.deinit_jit(allocator);
    
    // Set up syscall handler
    vm.set_syscall_handler(my_syscall_handler, null);
    
    // Initialize framebuffer
    vm.init_framebuffer();
    
    // Start execution
    vm.start();
    
    // Execute until halted
    while (vm.state == .running) {
        vm.step_jit() catch |err| {
            std.debug.print("Error: {}\n", .{err});
            break;
        }
    }
    
    // Print performance metrics
    vm.print_performance();
    
    // Get diagnostics
    const diagnostics = vm.get_diagnostics();
    diagnostics.print();
}

fn my_syscall_handler(
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64
) u64 {
    std.debug.print("Syscall: {}\n", .{syscall_num});
    return 0;
}
```

## See Also

- `docs/plan.md`: High-level development plan
- `docs/tasks.md`: Detailed task list
- `src/kernel_vm/vm.zig`: VM implementation
- `tests/`: Comprehensive test suite

