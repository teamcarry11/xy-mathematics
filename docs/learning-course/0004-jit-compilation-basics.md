# JIT Compilation Basics

**Prerequisites**: Virtual machine fundamentals (0003), basic compiler concepts  
**Focus**: RISC-V to AArch64 translation as used in Grain OS  
**GrainStyle**: Explicit translation patterns, bounded code generation

## What is JIT Compilation?

Just-In-Time (JIT) compilation translates code at runtime from one
instruction set to another. Instead of interpreting instructions one-by-one,
JIT compiles blocks of instructions to native code, then executes that code
directly on the CPU.

**Why JIT for Grain OS?**
- **Performance**: 10x+ faster than interpreter
- **Native execution**: Runs directly on AArch64 CPU
- **Rosetta 2 analogy**: Like Rosetta 2 translating x86 to AArch64

## JIT vs Interpreter

### Interpreter (Slow)

```
RISC-V Instruction → Decode → Execute (Zig function) → Next instruction
     ↓                  ↓            ↓
  Fetch from      Extract      Update VM state
  VM memory       fields       (registers, memory)
```

**Speed**: ~1 instruction per function call (~100x slower than native)

### JIT Compiler (Fast)

```
RISC-V Instructions → Translate → AArch64 Code → Execute natively
     (block)            ↓            ↓
                    Generate      Run on CPU
                    machine code  (10x+ faster)
```

**Speed**: Near-native performance (within 10-20% of native code)

## Translation Process

### Step 1: Identify Basic Block

A basic block is a sequence of instructions with:

- **Single entry point**: First instruction
- **Single exit point**: Last instruction (branch/jump/return)
- **No branches in middle**: Linear execution

```zig
// Example basic block
block_start:
    ADD x5, x3, x4      // x5 = x3 + x4
    ADDI x5, x5, 1      // x5 = x5 + 1
    SW x5, 0(x2)        // Store x5 to memory[x2]
    BEQ x5, x6, label   // Branch (end of block)
```

**Why Blocks?**
- Compile entire block at once
- Optimize across instructions
- Cache compiled code for reuse

### Step 2: Translate Instructions

For each RISC-V instruction, emit equivalent AArch64 instructions:

```zig
// RISC-V: ADD x5, x3, x4
// AArch64: ADD w5, w3, w4  (w = 32-bit, x = 64-bit)

fn emit_add(rd: u5, rs1: u5, rs2: u5) void {
    // Load rs1 to AArch64 register
    emit_mov_from_guest(rs1, aarch64_temp1);
    // Load rs2 to AArch64 register
    emit_mov_from_guest(rs2, aarch64_temp2);
    // Emit ADD instruction
    emit_aarch64_add(aarch64_rd, aarch64_temp1, aarch64_temp2);
    // Store result back to guest state
    emit_mov_to_guest(rd, aarch64_rd);
}
```

### Step 3: Handle Control Flow

Branches and jumps require special handling:

```zig
// RISC-V: BEQ x3, x4, target
// AArch64: CMP w3, w4; B.EQ target_label

fn emit_beq(rs1: u5, rs2: u5, target_pc: u64) void {
    // Load registers
    emit_mov_from_guest(rs1, aarch64_temp1);
    emit_mov_from_guest(rs2, aarch64_temp2);
    
    // Compare
    emit_aarch64_cmp(aarch64_temp1, aarch64_temp2);
    
    // Branch (backpatch target later)
    const branch_patch = emit_aarch64_b_eq_placeholder();
    
    // If taken: jump to target_pc (may need to compile that block)
    // If not taken: fall through to next instruction
}
```

**Why Backpatching?**
- Target address may not be known yet
- Emit placeholder, fill in address later
- Or compile target block and patch jump

### Step 4: Generate Native Code

AArch64 instructions are encoded as 32-bit words:

```zig
// AArch64 ADD instruction encoding
// 31:24 = 0b00011011 (ADD opcode)
// 23:21 = 0b000 (ADD variant)
// 20:16 = destination register
// 15:10 = source register 1
// 9:5 = source register 2
// 4:0 = source register 3 (or immediate)

fn emit_aarch64_add(rd: u8, rn: u8, rm: u8) void {
    const inst: u32 = 0b00011011_000_00000_00000_000_00000;
    // ... set register fields ...
    write_code_word(inst);
}
```

## Register Mapping

### Guest Registers (RISC-V)

32 registers: x0-x31

- x0 is hardwired to 0
- x1-x31 are general-purpose

### Host Registers (AArch64)

31 general-purpose registers: x0-x30

- x0-x7: Argument/return registers
- x9-x15: Temporary registers
- x19-x28: Callee-saved registers
- x29: Frame pointer
- x30: Link register

### Mapping Strategy

**Option 1: Full Mapping**
- Map all 32 RISC-V registers to AArch64 registers
- Fast (no memory access)
- Limited by AArch64 register count

**Option 2: Spill to Memory**
- Map hot registers to AArch64 registers
- Spill cold registers to memory (guest state struct)
- More complex, but handles all registers

**Grain OS**: Uses Option 2 (spill to memory)

## Code Generation

### Guest State Structure

```zig
pub const GuestState = struct {
    regs: [32]u64,  // RISC-V registers
    pc: u64,        // Program counter
};

// AArch64 code accesses guest state via pointer
// x27 = pointer to GuestState (callee-saved register)
```

### Memory Access Translation

```zig
// RISC-V: LW x5, 8(x3)
// Translation:
//   1. Load base address: x3 value from guest state
//   2. Add offset: base + 8
//   3. Load from memory: guest_ram[base + 8]
//   4. Sign-extend to 64-bit
//   5. Store to x5 in guest state

fn emit_lw(rd: u5, rs1: u5, imm12: i32) void {
    // Load rs1 from guest state
    emit_ldr(aarch64_temp1, x27, offsetof(GuestState, regs) + rs1 * 8);
    
    // Add immediate
    emit_add_imm(aarch64_temp1, aarch64_temp1, imm12);
    
    // Load from guest RAM (x28 = guest_ram base)
    emit_ldr(aarch64_temp2, x28, aarch64_temp1);
    
    // Sign-extend (AArch64 LDRW sign-extends automatically)
    // Store to rd in guest state
    emit_str(aarch64_temp2, x27, offsetof(GuestState, regs) + rd * 8);
}
```

## Block Caching

### Cache Structure

```zig
pub const JitContext = struct {
    block_cache: std.AutoHashMap(u64, usize),  // PC → compiled code address
    code_buffer: []align(16384) u8,             // Executable memory
    cursor: usize,                               // Next write position
};
```

### Cache Lookup

```zig
pub fn compile_block(self: *JitContext, start_pc: u64) !usize {
    // Check if block already compiled
    if (self.block_cache.get(start_pc)) |code_addr| {
        return code_addr;  // Return cached code
    }
    
    // Compile new block
    const code_addr = self.cursor;
    // ... translate instructions ...
    self.cursor += code_size;
    
    // Cache for future use
    try self.block_cache.put(start_pc, code_addr);
    
    return code_addr;
}
```

**Why Cache?**
- Avoid recompiling same blocks
- Hot code paths compiled once, reused many times
- Significant performance win

## Control Flow Handling

### Direct Branches

If target block is already compiled:

```zig
// RISC-V: BEQ x3, x4, target_pc
// If target_pc is compiled, jump directly to compiled code
if (self.block_cache.get(target_pc)) |target_code| {
    emit_aarch64_b(target_code);  // Direct jump
} else {
    // Fall back to interpreter or compile target
    emit_call_interpreter(target_pc);
}
```

### Indirect Branches

For JALR (indirect calls/returns):

```zig
// RISC-V: JALR x0, 0(x1)
// Jump to address in x1
// Must look up target in cache at runtime

fn emit_jalr(rd: u5, rs1: u5, imm12: i32) void {
    // Load target address from rs1
    emit_mov_from_guest(rs1, aarch64_target);
    
    // Look up in cache (runtime call)
    emit_call_lookup_block(aarch64_target);
    
    // Jump to compiled code (or interpreter fallback)
    emit_indirect_jump(aarch64_result);
}
```

## Rosetta 2 Analogy

### Rosetta 2 (Apple)

```
x86-64 Instructions → Translate → AArch64 Code → Execute
     (macOS app)         (JIT)        (M-series CPU)
```

**Purpose**: Run x86 apps on Apple Silicon

### Grain OS JIT

```
RISC-V Instructions → Translate → AArch64 Code → Execute
     (Grain Kernel)      (JIT)        (M-series CPU)
```

**Purpose**: Run RISC-V kernel on macOS (AArch64)

**Similarities**:
- Both translate between instruction sets
- Both use JIT compilation
- Both target AArch64 (Apple Silicon)
- Both provide near-native performance

**Differences**:
- Rosetta 2: x86 → AArch64 (commercial, closed-source)
- Grain OS: RISC-V → AArch64 (open-source, our implementation)

## Performance Considerations

### JIT Overhead

JIT compilation has costs:

- **Compilation time**: Translate instructions to native code
- **Memory usage**: Store compiled code in buffer
- **Cache lookup**: Check if block already compiled

### When JIT Wins

JIT is faster when:

- **Hot code**: Blocks executed many times
- **Large blocks**: More instructions per compilation cost
- **Simple instructions**: Fast translation

**Typical Speedup**: 10-20x over interpreter for hot code

### When Interpreter Wins

Interpreter is better for:

- **Cold code**: Executed once or rarely
- **Complex instructions**: Slow to translate
- **Memory constraints**: JIT buffer is limited

**Grain OS Strategy**: Use JIT for hot paths, interpreter fallback for cold code

## Code Generation Patterns

### Simple Arithmetic

```zig
// RISC-V: ADDI x5, x3, 42
// AArch64: ADD w5, w3, #42

fn emit_addi(rd: u5, rs1: u5, imm12: i32) void {
    // Load rs1
    emit_ldr(aarch64_temp, x27, offsetof(GuestState, regs) + rs1 * 8);
    
    // Add immediate
    emit_add_imm(aarch64_temp, aarch64_temp, imm12);
    
    // Store to rd
    emit_str(aarch64_temp, x27, offsetof(GuestState, regs) + rd * 8);
}
```

### Memory Store

```zig
// RISC-V: SW x5, 8(x3)
// AArch64: STR w5, [x3, #8]

fn emit_sw(rs1: u5, rs2: u5, imm12: i32) void {
    // Load base address (rs1)
    emit_ldr(aarch64_base, x27, offsetof(GuestState, regs) + rs1 * 8);
    
    // Load value (rs2)
    emit_ldr(aarch64_value, x27, offsetof(GuestState, regs) + rs2 * 8);
    
    // Add offset to base (x28 = guest_ram)
    emit_add(aarch64_addr, x28, aarch64_base);
    emit_add_imm(aarch64_addr, aarch64_addr, imm12);
    
    // Store to memory
    emit_str(aarch64_value, aarch64_addr, 0);
}
```

## Address Translation in JIT

### Framebuffer Addresses

JIT-compiled code must also handle address translation:

```zig
// RISC-V: SW x5, 0(x3) where x3 = 0x90000000 (framebuffer)
// JIT must translate 0x90000000 to physical offset

fn emit_sw_with_translation(rs1: u5, rs2: u5, imm12: i32) void {
    // Load base address
    emit_ldr(aarch64_base, x27, offsetof(GuestState, regs) + rs1 * 8);
    
    // Check if framebuffer address (>= 0x90000000)
    emit_cmp_imm(aarch64_base, 0x90000000);
    emit_b_lt(normal_path);  // Branch if < 0x90000000
    
    // Framebuffer path: translate address
    emit_sub_imm(aarch64_base, aarch64_base, 0x90000000);
    emit_add(aarch64_base, x28, aarch64_base);  // x28 = guest_ram
    emit_add_imm(aarch64_base, aarch64_base, FRAMEBUFFER_OFFSET);
    emit_b(store_path);
    
    // Normal path: direct mapping
    normal_path:
    emit_add(aarch64_base, x28, aarch64_base);
    
    // Store
    store_path:
    emit_ldr(aarch64_value, x27, offsetof(GuestState, regs) + rs2 * 8);
    emit_str(aarch64_value, aarch64_base, imm12);
}
```

**Why Inline Translation?**
- Faster than function call
- JIT can optimize translation
- Still slower than direct access, but acceptable

## Safety Considerations

### W^X (Write XOR Execute)

Memory cannot be both writable and executable:

1. **Allocate memory**: `PROT_READ | PROT_WRITE`
2. **Write code**: Generate AArch64 instructions
3. **Make executable**: `mprotect(PROT_READ | PROT_EXEC)`
4. **Execute**: Call compiled code

**macOS Specific**: Use `pthread_jit_write_protect_np()`:

```zig
// Enable writing
pthread_jit_write_protect_np(0);
// ... write code ...
// Enable execution
pthread_jit_write_protect_np(1);
```

### Bounds Checking

JIT-compiled code should still check bounds:

```zig
// In JIT-compiled memory access
emit_cmp(aarch64_addr, memory_size);
emit_b_ge(bounds_error);  // Branch if out of bounds
// ... perform access ...
```

**Why?**
- Safety: Prevent memory corruption
- Consistency: Same checks as interpreter
- Debugging: Easier to catch bugs

## Grain OS JIT Implementation

### Architecture

```
JitContext
├── code_buffer: [64MB]u8          # Executable memory
├── block_cache: HashMap<PC, addr> # Compiled block cache
├── guest_state: *GuestState       # RISC-V register file
└── guest_ram: []u8                # VM memory
```

### Translation Flow

1. **Lookup**: Check if block already compiled
2. **Compile**: Translate RISC-V → AArch64
3. **Cache**: Store compiled code address
4. **Execute**: Call compiled code
5. **Sync**: Update guest state after execution

### Performance

**Measured Speedup**: 10-20x over interpreter for hot code

**Bottlenecks**:
- Register spilling to memory
- Address translation overhead
- Cache lookup on every block

**Optimizations**:
- Register allocation (keep hot registers in AArch64)
- Inline address translation
- Larger block sizes

## Exercises

1. **Translation**: Translate `ADD x5, x3, x4` to AArch64 assembly.

2. **Block Identification**: Identify basic blocks in a sequence of
   RISC-V instructions.

3. **Cache Strategy**: Why cache by PC? What are alternatives?

4. **Address Translation**: How should JIT handle framebuffer addresses
   (`0x90000000+`)?

## Key Takeaways

- JIT compiles blocks at runtime for performance
- Translation: RISC-V → AArch64 instructions
- Block caching avoids recompilation
- Register mapping: spill to memory for all 32 registers
- Control flow: direct branches when possible, indirect fallback
- Safety: W^X enforcement, bounds checking
- Performance: 10-20x speedup for hot code

## Next Document

**0005-memory-management.md**: Learn memory layout, address translation, and
bounds checking in detail.

---

*now == next + 1*

