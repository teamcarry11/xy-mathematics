# Grain OS Architecture

**Prerequisites**: All previous documents (complete foundation)  
**Focus**: How all components integrate in Grain OS  
**GrainStyle**: Explicit architecture, clear boundaries, documented design

## Architecture Overview

### Complete Stack

```
┌─────────────────────────────────────────┐
│   macOS Tahoe 26.1 (Native Cocoa)     │
│   - NSWindow, NSImageView              │
│   - Event handling (keyboard, mouse)   │
├─────────────────────────────────────────┤
│   Grain Aurora IDE (Zig GUI)          │
│   - Window management                  │
│   - Framebuffer display                │
│   - VM integration                     │
├─────────────────────────────────────────┤
│   Grain VM (RISC-V → AArch64 JIT)     │
│   - Instruction interpretation         │
│   - JIT compilation                    │
│   - Memory management                  │
│   - Address translation                │
├─────────────────────────────────────────┤
│   Grain Basin Kernel (RISC-V64)        │
│   - Boot sequence                      │
│   - System calls                       │
│   - Framebuffer driver                 │
│   - Process management                 │
└─────────────────────────────────────────┘
```

## Component Interactions

### Boot Sequence

```
1. macOS App Starts
   └──> Create NSWindow
        └──> Initialize VM
             └──> Load Kernel ELF
                  └──> Set PC to entry point
                       └──> Enable JIT
                            └──> Start VM
                                 └──> Kernel Boots
                                      └──> Initialize Framebuffer
                                           └──> Enter Trap Loop
```

### Execution Flow

```
VM Step Loop:
  1. Fetch instruction from memory[PC]
  2. Decode opcode and operands
  3. Execute (interpreter or JIT)
  4. Update state (registers, memory, PC)
  5. Check for traps (ECALL, faults)
  6. Handle traps (syscalls, interrupts)
  7. Update framebuffer display
  8. Repeat
```

### Framebuffer Update

```
Kernel Writes Pixel:
  1. Kernel executes: SW x5, 0(x3)  (x3 = 0x90000000)
  2. VM translates: 0x90000000 → physical offset (5MB)
  3. VM writes: memory[5MB] = pixel color
  4. macOS app reads: get_framebuffer_memory()
  5. Convert: framebuffer → CGImage → NSImage
  6. Update: NSImageView.setImage()
  7. Cocoa renders to screen
```

## Memory Architecture

### Complete Memory Layout

```
Virtual Address Space (Kernel View):
  0x00000000 - 0x7FFFFFFF: Reserved
  0x80000000 - 0x8FFFFFFF: Kernel code/data
  0x90000000 - 0x900BBFFF: Framebuffer (3MB)

Physical Memory (VM Array, 8MB):
  [0, 5MB):     Kernel (mapped from 0x80000000+)
  [5MB, 8MB):   Framebuffer (mapped from 0x90000000+)
```

### Address Translation Flow

```
Kernel Instruction: SW x5, 0(x3)  (x3 = 0x90000000)
  ↓
VM calculates: eff_addr = x3 + 0 = 0x90000000
  ↓
VM translates: translate_address(0x90000000)
  ├──> Check: >= 0x90000000? Yes (framebuffer)
  ├──> Calculate: offset = 0x90000000 - 0x90000000 = 0
  └──> Return: 5MB + 0 = 0x00500000
  ↓
VM writes: memory[0x00500000] = x5 value
  ↓
Framebuffer updated!
```

## JIT Integration

### JIT Compilation Flow

```
VM Step (JIT Enabled):
  1. Check block cache: Is PC already compiled?
     ├──> Yes: Jump to compiled code
     └──> No: Compile block
            ├──> Translate RISC-V → AArch64
            ├──> Generate native code
            ├──> Cache compiled code
            └──> Execute compiled code
  2. Sync guest state (registers, memory)
  3. Continue execution
```

### JIT vs Interpreter

```
Hot Code (executed many times):
  JIT: Compile once, execute many times (fast)
  Interpreter: Interpret every time (slow)

Cold Code (executed once):
  JIT: Compile overhead (slower)
  Interpreter: No overhead (faster)

Grain OS Strategy:
  - Use JIT for hot paths (kernel main loop)
  - Fall back to interpreter for cold code
  - Best of both worlds
```

## System Call Flow

### ECALL Handling

```
Userspace (or Kernel):
  1. Load syscall number: li a7, 64  (SYS_write)
  2. Load arguments: li a0, 1; la a1, buf; li a2, len
  3. Execute: ecall
     ↓
VM Trap Handler:
  1. Detect ECALL (trap code 8)
  2. Extract syscall number from a7
  3. Extract arguments from a0-a6
  4. Call kernel syscall handler
     ↓
Kernel Syscall Handler:
  1. Route to appropriate syscall function
  2. Validate arguments
  3. Perform operation
  4. Return result in a0
     ↓
VM:
  1. Set a0 register to result
  2. Advance PC (return to caller)
  3. Continue execution
```

## Framebuffer Architecture

### Dual Access Pattern

```
Kernel Access (via RISC-V):
  SW x5, 0(x3)  → VM translates → memory[5MB] = pixel

Host Access (via Zig):
  fb_memory = vm.get_framebuffer_memory()
  → Direct access to memory[5MB..8MB]
  → Convert to NSImage
  → Display in window
```

**Why Dual Access?**
- Kernel: Writes pixels via instructions
- Host: Reads pixels for display
- Same memory, different access paths

## Development Workflow

### Build and Run

```bash
# Build
zig build tahoe

# Run
zig build tahoe  # Builds and runs

# Or separately
zig build tahoe-build  # Just build
./zig-out/bin/tahoe    # Run manually
```

### Debugging

```zig
// Add debug prints
std.debug.print("PC: 0x{x}, Instruction: 0x{x}\n", .{pc, inst});

// Check VM state
std.debug.print("Registers: x3=0x{x}, x5=0x{x}\n", .{vm.regs.get(3), vm.regs.get(5)});

// Inspect framebuffer
const fb = vm.get_framebuffer_memory();
std.debug.print("First pixel: 0x{x}\n", .{std.mem.readInt(u32, fb[0..4], .little)});
```

## Testing Strategy

### Unit Tests

Test individual components:

```zig
test "VM address translation" {
    var vm = VM.init(&[_]u8{}, 0);
    const phys = vm.translate_address(0x90000000);
    try std.testing.expectEqual(@as(usize, 0x00500000), phys.?);
}
```

### Integration Tests

Test component interactions:

```zig
test "kernel boot and framebuffer" {
    var vm = VM.init(&kernel_elf, 0x80000000);
    vm.start();
    
    // Execute until framebuffer initialized
    // ... run VM ...
    
    // Verify framebuffer contains test pattern
    const fb = vm.get_framebuffer_memory();
    // ... check pixels ...
}
```

### Visual Tests

Manual verification:

- Run application
- Verify window appears
- Check test pattern displays
- Test keyboard input

## Performance Characteristics

### Interpreter Performance

- **Speed**: ~1 instruction per function call
- **Overhead**: Decode + execute + state update
- **Use Case**: Cold code, debugging

### JIT Performance

- **Speed**: Near-native (10-20x faster than interpreter)
- **Overhead**: Compilation time (amortized over many executions)
- **Use Case**: Hot code paths

### Memory Usage

- **VM Memory**: 8MB (static allocation)
- **JIT Buffer**: 64MB (executable code)
- **Total**: ~72MB (predictable, bounded)

## Design Decisions

### Why These Choices?

**Monolithic Kernel**: Simpler, faster system calls

**Single-Threaded**: No race conditions, easier to reason about

**Flat Memory**: Simple addressing, can add paging later

**Static Allocation**: Predictable, bounded, no allocator dependency

**JIT Compilation**: Performance for hot code, interpreter for cold

**Framebuffer MMIO**: Simple, fast, direct pixel access

## Future Extensions

### Potential Additions

- **Paging**: Virtual memory with page tables
- **Multithreading**: Multiple processes, scheduling
- **Device Drivers**: Keyboard, mouse, storage
- **File System**: Persistent storage
- **Networking**: Network stack and protocols

**GrainStyle**: Add features incrementally, maintain explicit limits.

## Exercises

1. **Trace Execution**: Trace a complete system call from ECALL to return.

2. **Memory Flow**: Trace a framebuffer write from kernel instruction to
   screen display.

3. **JIT Flow**: Explain when JIT is faster vs when interpreter is better.

4. **Architecture Design**: Design a new component following GrainStyle.

## Key Takeaways

- **Layered Architecture**: macOS → IDE → VM → Kernel
- **Clear Boundaries**: Each layer has well-defined interface
- **Explicit Design**: All limits and constraints are visible
- **GrainStyle Throughout**: Every component follows principles
- **Integration**: Components work together seamlessly
- **Performance**: JIT for hot code, interpreter for cold
- **Safety**: Bounds checking, assertions, explicit errors

## Course Completion

You now understand:

1. ✅ RISC-V architecture and instruction encoding
2. ✅ Virtual machine implementation patterns
3. ✅ JIT compilation (RISC-V → AArch64)
4. ✅ Memory management and address translation
5. ✅ Kernel architecture and system calls
6. ✅ Framebuffer graphics and pixel formats
7. ✅ macOS integration (Cocoa/AppKit)
8. ✅ GrainStyle coding discipline
9. ✅ Complete Grain OS architecture

## Next Steps

1. **Read Implementation**: Study `src/kernel_vm/vm.zig`, `src/kernel/main.zig`
2. **Run Examples**: Build and run Grain OS, see it in action
3. **Modify Code**: Add features, experiment with changes
4. **Apply GrainStyle**: Use principles in your own code

## Resources

- **GrainStyle Guide**: `docs/zyx/grain_style.md`
- **JIT Architecture**: `docs/zyx/jit_architecture.md`
- **Boot Sequence**: `docs/zyx/boot_sequence_status.md`
- **Tasks**: `docs/tasks.md`
- **Plan**: `docs/plan.md`

---

**Congratulations!** You've completed the Grain OS learning course. You now
have the foundation to understand and contribute to Grain OS development.

*now == next + 1*

