# RISC-V Architecture Fundamentals

**Prerequisites**: Basic computer architecture (CPU, registers, memory)  
**Focus**: RISC-V64 instruction set as used in Grain OS  
**GrainStyle**: Explicit instruction encoding, bounded execution

## What is RISC-V?

RISC-V is an open-source instruction set architecture (ISA). Unlike x86 or
ARM, RISC-V is not proprietary—anyone can implement it without licensing.

**Why RISC-V for Grain OS?**
- Open-source (aligns with Grain philosophy)
- Simple, clean design (easier to implement VM)
- Growing ecosystem (Framework 13 hardware target)
- Well-documented specification

## RISC-V Design Principles

### Reduced Instruction Set

RISC-V follows RISC (Reduced Instruction Set Computer) principles:

- **Small instruction set**: ~50 base instructions
- **Fixed-length encoding**: 32-bit instructions (16-bit compressed)
- **Load/store architecture**: Only load/store access memory
- **Register-based**: Operations work on registers, not memory

### Modular Design

RISC-V is modular—you implement only what you need:

- **RV32I**: 32-bit base integer instructions
- **RV64I**: 64-bit base integer instructions (Grain OS uses this)
- **RV64M**: Multiply/divide extensions
- **RVC**: Compressed instructions (16-bit)
- **RV64A**: Atomic operations
- **RV64F/D**: Floating-point

**Grain OS uses**: RV64I + RVC (compressed instructions)

## Register File

### 32 General-Purpose Registers

RISC-V has 32 registers, named `x0` through `x31`:

```
x0  = zero (hardwired to 0, writes ignored)
x1  = ra  (return address)
x2  = sp  (stack pointer)
x3  = gp  (global pointer)
x4  = tp  (thread pointer)
x5  = t0  (temporary)
x6  = t1  (temporary)
x7  = t2  (temporary)
x8  = s0/fp (saved register / frame pointer)
x9  = s1  (saved register)
x10 = a0  (argument / return value)
x11 = a1  (argument / return value)
x12-x17 = a2-a7 (arguments)
x18-x27 = s2-s11 (saved registers)
x28-x31 = t3-t6 (temporaries)
```

**Key Rules**:
- `x0` is always 0 (hardwired)
- Writes to `x0` are ignored
- All other registers are general-purpose

### Program Counter (PC)

Separate from register file, PC holds the current instruction address.

**GrainStyle Note**: In our VM, PC is separate from registers for clarity.

## Instruction Formats

RISC-V instructions are 32 bits, encoded in several formats:

### R-Type (Register)

```
31        25 24    20 19    15 14    12 11     7 6      0
+-----------+-------+-------+-------+-------+-----------+
|   funct7  |  rs2  |  rs1  | funct3|   rd  |  opcode  |
+-----------+-------+-------+-------+-------+-----------+
```

**Example**: `ADD x5, x3, x4` (x5 = x3 + x4)
- `rd = 5` (destination)
- `rs1 = 3` (first source)
- `rs2 = 4` (second source)
- `opcode = 0110011` (OP)
- `funct3 = 000` (ADD)
- `funct7 = 0000000` (ADD)

### I-Type (Immediate)

```
31                20 19    15 14    12 11     7 6      0
+------------------+-------+-------+-------+-----------+
|      imm[11:0]   |  rs1  | funct3|   rd  |  opcode  |
+------------------+-------+-------+-------+-----------+
```

**Example**: `ADDI x5, x3, 42` (x5 = x3 + 42)
- `rd = 5`
- `rs1 = 3`
- `imm = 42` (12-bit signed immediate)
- `opcode = 0010011` (OP-IMM)

### S-Type (Store)

```
31        25 24    20 19    15 14    12 11     7 6      0
+-----------+-------+-------+-------+-------+-----------+
|  imm[11:5]|  rs2  |  rs1  | funct3|imm[4:0]|  opcode  |
+-----------+-------+-------+-------+-------+-----------+
```

**Example**: `SW x5, 8(x3)` (store x5 to memory at x3 + 8)
- `rs1 = 3` (base address)
- `rs2 = 5` (source register)
- `imm = 8` (offset, split across instruction)

### B-Type (Branch)

```
31    25 24    20 19    15 14    12 11     7 6      0
+------+-------+-------+-------+-------+-----------+
|imm[12|  rs2  |  rs1  | funct3|imm[11|  opcode  |
|:10]  |       |       |       |:5]   |         |
+------+-------+-------+-------+-------+-----------+
```

**Example**: `BEQ x3, x4, label` (branch if x3 == x4)
- `rs1 = 3`, `rs2 = 4`
- `imm` is sign-extended, PC-relative offset

### U-Type (Upper Immediate)

```
31                             12 11     7 6      0
+------------------------------+-------+-----------+
|         imm[31:12]           |   rd  |  opcode  |
+------------------------------+-------+-----------+
```

**Example**: `LUI x5, 0x12345` (x5 = 0x12345000)
- Loads upper 20 bits into register
- Lower 12 bits become 0

### J-Type (Jump)

```
31    20 19    15 14    12 11     7 6      0
+------+-------+-------+-------+-----------+
|imm[20|  rs1  | funct3|   rd  |  opcode  |
|:10]  |       |       |       |         |
+------+-------+-------+-------+-----------+
```

**Example**: `JAL x1, label` (jump and link)
- Saves PC+4 to `rd` (usually x1)
- Jumps to PC + sign-extended immediate

## Common Instructions

### Arithmetic

```zig
// ADD: rd = rs1 + rs2
// ADDI: rd = rs1 + imm (12-bit signed)
// SUB: rd = rs1 - rs2
// LUI: rd = imm << 12 (load upper immediate)
// AUIPC: rd = PC + (imm << 12) (add upper immediate to PC)
```

### Load/Store

```zig
// LB: Load byte (sign-extended)
// LH: Load halfword (sign-extended)
// LW: Load word (32-bit, sign-extended to 64)
// LD: Load doubleword (64-bit, RV64 only)
// SB: Store byte
// SH: Store halfword
// SW: Store word (32-bit)
// SD: Store doubleword (64-bit, RV64 only)
```

**Memory Access Rules**:
- Loads read from memory: `rd = memory[rs1 + imm]`
- Stores write to memory: `memory[rs1 + imm] = rs2`
- Addresses must be aligned (word = 4-byte, doubleword = 8-byte)

### Control Flow

```zig
// BEQ: Branch if rs1 == rs2
// BNE: Branch if rs1 != rs2
// BLT: Branch if rs1 < rs2 (signed)
// BGE: Branch if rs1 >= rs2 (signed)
// JAL: Jump and link (call function)
// JALR: Jump and link register (return/indirect call)
```

## RISC-V64 vs RISC-V32

### Key Differences

- **Register Width**: 64-bit vs 32-bit
- **Address Space**: 64-bit addresses vs 32-bit
- **Instructions**: `LD`/`SD` (64-bit load/store) in RV64

### Grain OS Choice: RV64I

We use RISC-V64 because:

- **Future-proof**: 64-bit address space
- **Hardware target**: Framework 13 RISC-V is 64-bit
- **Simplicity**: One architecture for kernel and VM

## Compressed Instructions (RVC)

RISC-V includes 16-bit compressed instructions for code density:

- **C.ADDI**: Add immediate (compressed)
- **C.LW**: Load word (compressed)
- **C.SW**: Store word (compressed)
- **C.J**: Jump (compressed)
- **C.BEQZ**: Branch if zero (compressed)

**Grain OS Support**: Full RVC support in JIT and interpreter

## Memory Model

### Address Space

RISC-V64 uses 64-bit addresses, but typically only 48 bits are used:

- **Virtual addresses**: 48-bit effective (upper 16 bits sign-extended)
- **Physical addresses**: Implementation-defined (we use flat 8MB in VM)

### Alignment

RISC-V requires natural alignment:

- **Byte**: 1-byte aligned (any address)
- **Halfword**: 2-byte aligned
- **Word**: 4-byte aligned
- **Doubleword**: 8-byte aligned

**GrainStyle**: We assert alignment in VM memory access functions.

### Endianness

RISC-V is **little-endian**:

- Least significant byte at lowest address
- Matches x86, AArch64 (host architecture)

## Instruction Encoding in Zig

### Decoding Example

```zig
// Decode R-type instruction
const funct7 = @as(u7, @truncate(inst >> 25));
const rs2 = @as(u5, @truncate(inst >> 20));
const rs1 = @as(u5, @truncate(inst >> 15));
const funct3 = @as(u3, @truncate(inst >> 12));
const rd = @as(u5, @truncate(inst >> 7));
const opcode = @as(u7, @truncate(inst));

// Decode I-type immediate (sign-extend)
const imm12_raw = @as(u12, @truncate(inst >> 20));
const imm12 = @as(i32, @truncate(@as(i64, @as(i12, @bitCast(imm12_raw)))));
```

**GrainStyle**: Explicit bit extraction, no magic numbers.

## Common Patterns

### Function Call

```riscv
# Caller:
JAL x1, function_label  # Save return address to x1, jump

# Callee (prologue):
ADDI sp, sp, -16        # Allocate stack frame
SW x1, 8(sp)            # Save return address
SW x8, 0(sp)            # Save frame pointer

# Callee (epilogue):
LW x1, 8(sp)            # Restore return address
LW x8, 0(sp)            # Restore frame pointer
ADDI sp, sp, 16         # Deallocate stack frame
JALR x0, 0(x1)          # Return (x0 = discard)
```

### Memory Access

```riscv
# Load word from array:
LUI x5, 0x80000         # Load base address (upper bits)
ADDI x5, x5, 0x100      # Add lower bits
LW x6, 0(x5)            # Load word from x5

# Store word to framebuffer:
LUI x5, 0x90000         # Framebuffer base (0x90000000)
ADDI x5, x5, offset     # Add pixel offset
SW x6, 0(x5)            # Store pixel color
```

## Grain OS Implementation

### VM Instruction Execution

Our VM decodes and executes instructions:

1. **Fetch**: Read 32-bit instruction from memory[PC]
2. **Decode**: Extract opcode, registers, immediates
3. **Execute**: Perform operation (arithmetic, memory, branch)
4. **Update PC**: Advance to next instruction (or branch target)

### JIT Translation

JIT compiler translates RISC-V to AArch64:

- **RISC-V ADD** → **AArch64 ADD**
- **RISC-V LW** → **AArch64 LDR**
- **RISC-V BEQ** → **AArch64 CMP + B.EQ**

We'll cover JIT in detail in document 0004.

## Exercises

1. **Decode by hand**: Given instruction `0x00A58533` (ADD x10, x11, x10),
   extract all fields.

2. **Encode by hand**: Encode `ADDI x5, x3, 42` as 32-bit instruction.

3. **Memory layout**: If kernel loads at `0x80000000` and framebuffer at
   `0x90000000`, what's the address difference? How does this map to VM
   memory offsets?

4. **Alignment**: Why must `LW` addresses be 4-byte aligned? What happens
   if they're not?

## Key Takeaways

- RISC-V is open-source, modular, and simple
- 32 registers (x0-x31), x0 is hardwired to 0
- Fixed 32-bit instruction encoding (16-bit compressed)
- Load/store architecture (only load/store access memory)
- Little-endian, natural alignment required
- Grain OS uses RV64I + RVC

## Next Document

**0003-virtual-machine-fundamentals.md**: Learn how to implement a VM that
executes RISC-V instructions.

---

*now == next + 1*

