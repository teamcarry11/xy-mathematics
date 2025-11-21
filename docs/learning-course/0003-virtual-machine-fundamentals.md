# Virtual Machine Fundamentals

**Prerequisites**: RISC-V architecture (0002), basic systems programming  
**Focus**: VM design patterns as used in Grain OS  
**GrainStyle**: Explicit state management, bounded execution, comprehensive assertions

## What is a Virtual Machine?

A virtual machine (VM) is software that emulates hardware. Instead of
executing instructions directly on CPU, a VM interprets instructions in
software.

**Why VMs for Kernel Development?**
- **Safety**: Bugs don't crash host system
- **Debugging**: Full control over execution state
- **Portability**: Run RISC-V kernel on any host (macOS, Linux, etc.)
- **Development speed**: No need for physical RISC-V hardware

## VM Architecture

### Core Components

```
┌─────────────────────────────────────┐
│         VM State                    │
│  - Register File (32 registers)     │
│  - Program Counter (PC)             │
│  - Memory (RAM)                     │
│  - Execution State                  │
└─────────────────────────────────────┘
           │
           │ fetch/decode/execute
           ▼
┌─────────────────────────────────────┐
│      Instruction Interpreter        │
│  - Fetch instruction from memory    │
│  - Decode opcode and operands       │
│  - Execute operation                │
│  - Update state                     │
└─────────────────────────────────────┘
```

### State Representation

**GrainStyle**: All state is explicit, no hidden variables.

```zig
pub const RegisterFile = struct {
    regs: [32]u64 = [_]u64{0} ** 32,  // 32 registers
    pc: u64 = 0,                       // Program counter
};

pub const VM = struct {
    regs: RegisterFile = .{},
    memory: [VM_MEMORY_SIZE]u8 = [_]u8{0} ** VM_MEMORY_SIZE,
    memory_size: usize = VM_MEMORY_SIZE,
    state: VMState = .halted,
};
```

**Why Static Allocation?**
- Predictable memory usage
- No allocator dependency
- Bounded execution guarantees

## Execution Loop

### Basic Pattern

```zig
pub fn step(self: *VM) !void {
    // 1. Fetch instruction
    const inst = try self.fetch_instruction();
    
    // 2. Decode opcode
    const opcode = @as(u7, @truncate(inst));
    
    // 3. Execute based on opcode
    switch (opcode) {
        0b0110011 => try self.execute_r_type(inst),  // R-type
        0b0010011 => try self.execute_i_type(inst),   // I-type
        0b0100011 => try self.execute_s_type(inst),   // S-type
        // ... more opcodes
        else => return VMError.invalid_instruction,
    }
    
    // 4. Advance PC (unless branch/jump)
    if (self.state == .running) {
        self.regs.pc += 4;  // Next instruction
    }
}
```

**GrainStyle**: Explicit state transitions, bounded execution.

### Fetch Phase

```zig
pub fn fetch_instruction(self: *const VM) VMError!u32 {
    const pc = self.regs.pc;
    
    // Assert: PC must be within memory bounds
    if (pc + 4 > self.memory_size) {
        return VMError.invalid_memory_access;
    }
    
    // Assert: PC must be 4-byte aligned
    if (pc % 4 != 0) {
        return VMError.unaligned_memory_access;
    }
    
    // Read 32-bit instruction (little-endian)
    const bytes = self.memory[@intCast(pc)..][0..4];
    const inst = std.mem.readInt(u32, bytes, .little);
    
    return inst;
}
```

**Why Assertions?**
- Catch bugs early (fail-fast)
- Document invariants
- Enable fuzzing to find edge cases

### Decode Phase

```zig
// Decode R-type instruction
fn decode_r_type(inst: u32) struct { rd: u5, rs1: u5, rs2: u5, funct3: u3, funct7: u7 } {
    std.debug.assert(inst != 0);  // Valid instruction
    
    return .{
        .funct7 = @as(u7, @truncate(inst >> 25)),
        .rs2 = @as(u5, @truncate(inst >> 20)),
        .rs1 = @as(u5, @truncate(inst >> 15)),
        .funct3 = @as(u3, @truncate(inst >> 12)),
        .rd = @as(u5, @truncate(inst >> 7)),
    };
}
```

**GrainStyle**: Explicit bit extraction, no magic numbers.

### Execute Phase

```zig
fn execute_add(self: *VM, rs1: u5, rs2: u5, rd: u5) void {
    // Assert: Register indices must be valid
    std.debug.assert(rs1 < 32);
    std.debug.assert(rs2 < 32);
    std.debug.assert(rd < 32);
    
    // Read source registers
    const val1 = self.regs.get(rs1);
    const val2 = self.regs.get(rs2);
    
    // Execute: rd = rs1 + rs2
    const result = val1 +% val2;  // Wrapping add
    
    // Write result (x0 writes are ignored)
    self.regs.set(rd, result);
    
    // Assert: Result must be written (unless x0)
    std.debug.assert(rd == 0 or self.regs.get(rd) == result);
}
```

**Why Wrapping Add (`+%`)?**
- RISC-V arithmetic wraps on overflow
- Matches hardware behavior
- Explicit about overflow semantics

## Memory Access

### Load Operations

```zig
fn execute_lw(self: *VM, rd: u5, rs1: u5, imm12: i32) !void {
    // Calculate effective address
    const base = self.regs.get(rs1);
    const offset: u64 = @bitCast(@as(i64, imm12));
    const addr = base +% offset;
    
    // Assert: Address must be 4-byte aligned
    if (addr % 4 != 0) {
        return VMError.unaligned_memory_access;
    }
    
    // Assert: Address must be within bounds
    if (addr + 4 > self.memory_size) {
        return VMError.invalid_memory_access;
    }
    
    // Read 32-bit word (sign-extend to 64-bit)
    const bytes = self.memory[@intCast(addr)..][0..4];
    const word = std.mem.readInt(u32, bytes, .little);
    const word64: u64 = @as(i64, @as(i32, @bitCast(word)));
    
    // Write to destination register
    self.regs.set(rd, word64);
}
```

**GrainStyle**: Explicit bounds checking, alignment validation.

### Store Operations

```zig
fn execute_sw(self: *VM, rs1: u5, rs2: u5, imm12: i32) !void {
    // Calculate effective address
    const base = self.regs.get(rs1);
    const offset: u64 = @bitCast(@as(i64, imm12));
    const addr = base +% offset;
    
    // Assert: Address must be 4-byte aligned
    if (addr % 4 != 0) {
        return VMError.unaligned_memory_access;
    }
    
    // Assert: Address must be within bounds
    if (addr + 4 > self.memory_size) {
        return VMError.invalid_memory_access;
    }
    
    // Read source register (truncate to 32-bit)
    const val = self.regs.get(rs2);
    const word = @as(u32, @truncate(val));
    
    // Write to memory (little-endian)
    const bytes = self.memory[@intCast(addr)..][0..4];
    std.mem.writeInt(u32, bytes, word, .little);
}
```

**Why Little-Endian?**
- RISC-V is little-endian
- Host (AArch64) is little-endian
- Matches hardware behavior

## Control Flow

### Branch Instructions

```zig
fn execute_beq(self: *VM, rs1: u5, rs2: u5, imm13: i32) void {
    const val1 = self.regs.get(rs1);
    const val2 = self.regs.get(rs2);
    
    if (val1 == val2) {
        // Take branch: PC = PC + sign-extended immediate
        const offset: u64 = @bitCast(@as(i64, imm13));
        self.regs.pc = self.regs.pc +% offset;
    } else {
        // Fall through: PC += 4 (handled by step loop)
    }
}
```

**Why PC Update in Branch?**
- Branches conditionally update PC
- Non-branch instructions advance PC by 4
- Centralized PC update in step loop (except branches)

### Jump Instructions

```zig
fn execute_jal(self: *VM, rd: u5, imm21: i32) void {
    // Save return address (PC + 4)
    const return_addr = self.regs.pc + 4;
    self.regs.set(rd, return_addr);
    
    // Jump: PC = PC + sign-extended immediate
    const offset: u64 = @bitCast(@as(i64, imm21));
    self.regs.pc = self.regs.pc +% offset;
}
```

**Why Save PC + 4?**
- RISC-V convention: return address is next instruction
- Enables function calls: `JAL x1, function` saves return address

## State Management

### Execution States

```zig
pub const VMState = enum {
    halted,   // VM is stopped
    running,  // VM is executing
    errored,  // VM encountered an error
};
```

**GrainStyle**: Explicit state machine, no implicit states.

### State Transitions

```zig
pub fn start(self: *VM) void {
    std.debug.assert(self.state == .halted or self.state == .errored);
    self.state = .running;
    self.last_error = null;
}

pub fn stop(self: *VM) void {
    self.state = .halted;
}

// Error handling
if (some_error) {
    self.state = .errored;
    self.last_error = VMError.invalid_memory_access;
    return VMError.invalid_memory_access;
}
```

**Why Explicit States?**
- Clear execution model
- Easy to debug (check state)
- Enables pause/resume functionality

## Memory Layout

### Flat Memory Model

Grain OS VM uses flat memory (no paging initially):

```
0x00000000 - 0x7FFFFFFF: Reserved (not used)
0x80000000 - 0x8FFFFFFF: Kernel code/data
0x90000000 - 0x900BBFFF: Framebuffer (3MB)
```

**Why This Layout?**
- Simple to implement
- Matches RISC-V kernel conventions
- Clear separation: kernel vs framebuffer

### Address Translation

Kernel sees virtual addresses (`0x80000000+`), VM maps to physical offsets:

```zig
fn translate_address(self: *const VM, virt_addr: u64) ?usize {
    const KERNEL_BASE: u64 = 0x80000000;
    const FRAMEBUFFER_BASE: u64 = 0x90000000;
    
    if (virt_addr >= FRAMEBUFFER_BASE) {
        // Framebuffer: map to end of VM memory
        const fb_offset = self.memory_size - FRAMEBUFFER_SIZE;
        return fb_offset + (virt_addr - FRAMEBUFFER_BASE);
    } else if (virt_addr >= KERNEL_BASE) {
        // Kernel: map directly (0x80000000 -> 0)
        return virt_addr - KERNEL_BASE;
    } else {
        // Low memory: direct mapping
        return virt_addr;
    }
}
```

**Why Translation?**
- Kernel expects specific addresses
- VM memory is flat array starting at 0
- Translation bridges the gap

## Error Handling

### Error Types

```zig
pub const VMError = error{
    invalid_memory_access,
    unaligned_memory_access,
    invalid_instruction,
    division_by_zero,
};
```

**GrainStyle**: Explicit error types, no generic "error".

### Error Propagation

```zig
pub fn step(self: *VM) VMError!void {
    const inst = try self.fetch_instruction();  // May return error
    // ... decode and execute
}
```

**Why Try?**
- Errors are expected (invalid addresses, etc.)
- Caller can handle errors appropriately
- Distinguishes from assertions (unexpected bugs)

## Performance Considerations

### Interpreter Overhead

Interpreter executes ~1 instruction per function call:

- **Fetch**: Memory read
- **Decode**: Bit manipulation
- **Execute**: Function call + operation
- **Update**: State modification

**Typical Speed**: 10-100x slower than native code

### Optimization Strategies

1. **JIT Compilation**: Translate to native code (covered in 0004)
2. **Instruction Caching**: Cache decoded instructions
3. **Block Execution**: Execute multiple instructions per loop
4. **Register Caching**: Keep hot registers in CPU registers

**Grain OS**: Uses JIT for performance (10x+ speedup)

## Testing Strategies

### Unit Tests

```zig
test "ADD instruction" {
    var vm = VM.init(&[_]u8{}, 0);
    vm.regs.set(3, 10);
    vm.regs.set(4, 20);
    
    // Encode ADD x5, x3, x4
    const inst: u32 = encode_add(5, 3, 4);
    try vm.execute_add(3, 4, 5);
    
    try std.testing.expectEqual(@as(u64, 30), vm.regs.get(5));
}
```

### Fuzz Testing

```zig
test "fuzz memory access" {
    var rng = std.rand.DefaultPrng.init(0);
    var vm = VM.init(&kernel_image, 0x80000000);
    
    for (0..1000) |_| {
        const addr = rng.random().intRangeAtMost(u64, 0, vm.memory_size - 4);
        const value = rng.random().int(u32);
        
        // Write and read back
        try vm.write32(addr, value);
        const read = try vm.read32(addr);
        try std.testing.expectEqual(value, read);
    }
}
```

**GrainStyle**: Exhaustive testing, including invalid inputs.

## Grain OS VM Implementation

### Key Design Decisions

1. **Static Allocation**: All memory allocated at startup
2. **Explicit State**: No hidden variables
3. **Comprehensive Assertions**: 2+ assertions per function
4. **Bounded Execution**: All loops have fixed upper bounds
5. **Error Handling**: Explicit error types, no panics

### Code Structure

```
src/kernel_vm/
├── vm.zig          # Core VM state and execution loop
├── loader.zig      # ELF loading and initialization
├── jit.zig         # JIT compiler (RISC-V → AArch64)
└── integration.zig # VM + Kernel integration
```

## Exercises

1. **Implement ADD**: Write `execute_add()` function with assertions.

2. **Memory Bounds**: Why must we check `addr + 4` instead of just `addr`?

3. **PC Update**: When should PC be updated in the step loop vs in the
   instruction execution function?

4. **Error vs Assert**: When should we use `return error` vs
   `std.debug.assert`?

## Key Takeaways

- VM interprets instructions in software
- State is explicit: registers, PC, memory, execution state
- Execution loop: fetch → decode → execute → update
- Memory access requires bounds checking and alignment
- Control flow updates PC conditionally
- Error handling distinguishes expected errors from bugs
- GrainStyle: explicit, bounded, asserted

## Next Document

**0004-jit-compilation-basics.md**: Learn how JIT compilation translates
RISC-V to AArch64 for near-native performance.

---

*now == next + 1*

