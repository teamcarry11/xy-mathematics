# Kernel Fundamentals

**Prerequisites**: Virtual machine fundamentals (0003), memory management (0005)  
**Focus**: Kernel architecture patterns as used in Grain Basin Kernel  
**GrainStyle**: Explicit system calls, bounded execution, safety-first design

## What is a Kernel?

A kernel is the core of an operating system. It manages:

- **Memory**: Allocation, protection, virtual memory
- **Processes**: Creation, scheduling, termination
- **System Calls**: Interface between userspace and kernel
- **Devices**: Hardware access (framebuffer, keyboard, etc.)

**Grain Basin Kernel**: Minimal, safety-first, RISC-V64 kernel written in Zig.

## Kernel Architecture Patterns

### Monolithic Kernel

Grain Basin uses a **monolithic kernel**:

- All kernel code runs in single address space
- System calls are function calls (no context switch initially)
- Simpler than microkernel (no message passing)

**Why Monolithic?**
- Simpler to implement
- Faster system calls (no IPC overhead)
- Sufficient for our use case

### Single-Threaded Kernel

Grain Basin is **single-threaded**:

- One process at a time (initially)
- No preemptive scheduling
- Cooperative multitasking (future)

**Why Single-Threaded?**
- Simpler implementation
- No race conditions
- Can add threading later

## Boot Sequence

### Entry Point

Kernel starts at entry point (typically `0x80000000`):

```riscv
# src/kernel/entry.S
.section .text
.global _start
_start:
    # Set up stack pointer
    la sp, _stack_top
    
    # Disable interrupts
    csrw sie, zero
    
    # Jump to kernel main (Zig function)
    call kmain
```

**Why Assembly?**
- Lowest-level initialization
- Set up stack and interrupts
- Jump to high-level code (Zig)

### Kernel Main

```zig
// src/kernel/main.zig
pub export fn kmain() noreturn {
    // 1. Print boot banner
    Debug.kprint("Grain Basin Kernel v0.1.0\n", .{});
    
    // 2. Initialize kernel subsystems
    kernel = BasinKernel.init();
    
    // 3. Enter main loop (trap handler)
    Trap.loop();
}
```

**Why Noreturn?**
- Kernel never returns (runs forever)
- Trap loop handles all execution
- System calls, interrupts, etc.

## System Call Interface

### System Call Mechanism

System calls allow userspace to request kernel services:

1. **Userspace**: Load syscall number and arguments into registers
2. **Trap**: Execute `ECALL` instruction (environment call)
3. **Kernel**: Handle syscall, return result in register
4. **Userspace**: Read result from register

### ECALL Instruction

RISC-V `ECALL` instruction triggers system call:

```riscv
# System call: write(fd, buf, len)
# Syscall number in a7, arguments in a0-a6
li a7, 64        # SYS_write
li a0, 1         # stdout
la a1, buffer    # buffer address
li a2, 10        # length
ecall            # Trigger system call
# Result in a0
```

**GrainStyle**: Explicit syscall numbers, clear argument passing.

### Syscall Handler

```zig
// src/kernel/basin_kernel.zig
fn handle_syscall(self: *BasinKernel, syscall_num: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64 {
    std.debug.assert(syscall_num < 256);  // Valid syscall number
    
    return switch (syscall_num) {
        1 => self.syscall_exit(arg1),           // exit(status)
        64 => self.syscall_write(arg1, arg2, arg3),  // write(fd, buf, len)
        93 => self.syscall_exit(arg1),          // exit_group(status)
        else => BasinError.invalid_syscall,
    };
}
```

**GrainStyle**: Explicit syscall routing, bounded syscall numbers.

## Memory Management

### Kernel Memory Layout

```
Kernel Address Space:
  0x80000000: Entry point (_start)
  0x80001000: Kernel code
  0x80002000: Kernel data
  0x80003000: Stack (grows downward)
  0x90000000: Framebuffer (MMIO)
```

### Stack Management

Kernel has its own stack:

```zig
// Stack grows downward
const STACK_SIZE: u32 = 64 * 1024;  // 64KB
var kernel_stack: [STACK_SIZE]u8 align(16) = undefined;

// Stack pointer initialized in entry.S
// sp = _stack_top (end of stack array)
```

**Why Separate Stack?**
- Kernel needs its own stack
- Isolated from userspace
- Bounded size (64KB)

## Process Management

### Process Structure

```zig
pub const Process = struct {
    pid: u32,              // Process ID
    state: ProcessState,   // Running, blocked, etc.
    regs: RegisterFile,    // Saved registers
    memory: []u8,          // Process memory
};
```

**GrainStyle**: Explicit process state, bounded memory.

### Process Creation

```zig
fn create_process(self: *BasinKernel, program: []const u8) !u32 {
    // Allocate process slot
    const pid = self.allocate_pid() orelse {
        return BasinError.too_many_processes;
    };
    
    // Load program into process memory
    // ... load ELF ...
    
    // Initialize process state
    self.processes[pid].pid = pid;
    self.processes[pid].state = .ready;
    
    return pid;
}
```

**GrainStyle**: Explicit limits (max processes), error handling.

## Device Drivers

### Framebuffer Driver

Framebuffer is memory-mapped I/O (MMIO):

```zig
// Kernel writes to framebuffer via store instructions
// SW x5, 0(x3) where x3 = 0x90000000

// Framebuffer is just memory, no special driver needed
// But we can add helper functions:

fn framebuffer_write_pixel(x: u32, y: u32, color: u32) void {
    const FRAMEBUFFER_BASE: u64 = 0x90000000;
    const offset = (y * 1024 + x) * 4;
    const addr = FRAMEBUFFER_BASE + offset;
    
    // Write via inline assembly or store instruction
    asm volatile (
        "sw %[color], 0(%[addr])"
        : // no outputs
        : [color] "r" (color),
          [addr] "r" (addr)
        : "memory"
    );
}
```

**Why MMIO?**
- Simple: just memory writes
- Fast: direct access
- No device driver complexity

## Trap Handling

### Trap Types

RISC-V traps include:

- **Environment Call (ECALL)**: System call
- **Instruction Access Fault**: Invalid instruction address
- **Load/Store Fault**: Invalid memory access
- **Timer Interrupt**: Periodic timer

### Trap Handler

```zig
// src/kernel/trap.zig
pub fn handle_trap(cause: u64, pc: u64, regs: *RegisterFile) void {
    const trap_code = @as(u8, @truncate(cause));
    
    switch (trap_code) {
        8 => handle_ecall(regs),      // Environment call
        0 => handle_instruction_fault(pc),  // Instruction access fault
        4 => handle_load_fault(pc, regs),   // Load access fault
        6 => handle_store_fault(pc, regs),  // Store access fault
        else => panic("Unknown trap: {}", .{trap_code}),
    }
}
```

**GrainStyle**: Explicit trap routing, comprehensive handling.

## System Call Implementation

### Write Syscall

```zig
fn syscall_write(self: *BasinKernel, fd: u64, buf_ptr: u64, len: u64) u64 {
    // Assert: fd must be valid
    if (fd != 1) {  // Only stdout supported
        return BasinError.invalid_argument;
    }
    
    // Assert: buffer must be within memory bounds
    if (buf_ptr + len > VM_MEMORY_SIZE) {
        return BasinError.invalid_argument;
    }
    
    // Read from kernel memory (userspace buffer)
    const buffer = self.vm.memory[@intCast(buf_ptr)..][0..@intCast(len)];
    
    // Write to serial output (captured by host)
    self.serial_output.write(buffer);
    
    return len;  // Bytes written
}
```

**GrainStyle**: Explicit bounds checking, clear error handling.

### Exit Syscall

```zig
fn syscall_exit(self: *BasinKernel, status: u64) noreturn {
    // Log exit status
    Debug.log(.info, "Process exited with status: {}", .{status});
    
    // Halt VM (or terminate process)
    self.vm.stop();
    
    // Never returns
    unreachable;
}
```

## Kernel Initialization

### Initialization Order

```zig
pub export fn kmain() noreturn {
    // 1. Early initialization (before anything else)
    Debug.init();
    
    // 2. Print boot banner
    Debug.kprint("Grain Basin Kernel\n", .{});
    
    // 3. Initialize kernel subsystems
    kernel = BasinKernel.init();
    
    // 4. Initialize framebuffer (if kernel-side)
    // framebuffer_init();
    
    // 5. Enter trap loop (never returns)
    Trap.loop();
}
```

**Why This Order?**
- Debug first (for error reporting)
- Subsystems in dependency order
- Framebuffer after kernel (may need kernel services)

## Error Handling

### Kernel Errors

```zig
pub const BasinError = error{
    out_of_memory,
    invalid_argument,
    invalid_syscall,
    invalid_handle,
    permission_denied,
};
```

**GrainStyle**: Explicit error types, no generic errors.

### Error Propagation

```zig
fn syscall_open(self: *BasinKernel, path_ptr: u64, flags: u64) BasinError!u64 {
    // Validate arguments
    if (path_ptr == 0) {
        return BasinError.invalid_argument;
    }
    
    // ... open file ...
    
    return handle_id;
}
```

**Why Try?**
- Errors are expected (invalid paths, etc.)
- Caller can handle appropriately
- Distinguishes from assertions (bugs)

## Testing Kernel Code

### Unit Tests

```zig
test "syscall_write" {
    var kernel = BasinKernel.init();
    var vm = VM.init(&[_]u8{}, 0);
    kernel.vm = &vm;
    
    // Write "hello" to stdout
    const result = kernel.syscall_write(1, 0x80000000, 5);
    try std.testing.expectEqual(@as(u64, 5), result);
}
```

### Integration Tests

```zig
test "kernel boot sequence" {
    var vm = VM.init(&kernel_elf, 0x80000000);
    vm.start();
    
    // Execute until first syscall
    while (vm.state == .running) {
        try vm.step();
        if (vm.regs.pc == trap_handler_address) {
            break;  // Reached trap handler
        }
    }
    
    try std.testing.expect(vm.state == .running);
}
```

## Grain Basin Kernel Design

### Key Principles

1. **Safety First**: Comprehensive bounds checking
2. **Explicit Limits**: All resources bounded
3. **Static Allocation**: No dynamic allocation after init
4. **Clear Interfaces**: System calls are explicit

### Code Structure

```
src/kernel/
├── main.zig          # Kernel entry point
├── basin_kernel.zig  # Core kernel logic
├── trap.zig          # Trap handling
├── framebuffer.zig   # Framebuffer driver
└── debug.zig         # Debug output
```

## Exercises

1. **Syscall Design**: Design a `read()` syscall interface.

2. **Trap Handling**: What happens if kernel accesses invalid memory?

3. **Process Creation**: How would you create a process from an ELF file?

4. **Framebuffer Access**: How does kernel write to framebuffer?

## Key Takeaways

- Kernel manages memory, processes, and devices
- Monolithic, single-threaded design (simpler)
- Boot sequence: entry → init → trap loop
- System calls via ECALL instruction
- Trap handling for syscalls, faults, interrupts
- Explicit error handling and bounds checking
- GrainStyle: safety-first, explicit limits

## Next Document

**0007-framebuffer-graphics.md**: Learn framebuffer concepts, pixel formats,
and graphics primitives.

---

*now == next + 1*

