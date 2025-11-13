# 004 Fuzz Test: Randomized Testing for RISC-V VM Execution Pipeline

Date: 2025-11-12  
Operator: Glow G2 (Stoic Aquarian cadence)

## Objective
Validate RISC-V VM instruction execution, memory access, register state, and ELF loading under randomized inputs. Tests focus on VM core functionality without requiring GUI or kernel files, ensuring TigerStyle safety: deterministic execution, comprehensive assertions, and proper error handling for invalid inputs.

## Method
- Added a Zig test harness (`test "004 fuzz: ..."`) in `tests/004_fuzz.zig`.
- Custom LCG PRNG (SimpleRng, wrap-safe math) generates random inputs:
  - Random RISC-V instructions (LUI, ADDI, ECALL)
  - Random memory addresses (aligned, within bounds)
  - Random register values and operations
  - Synthetic ELF kernel files
- Uses Arena allocator + `ArrayListUnmanaged` to minimize heap noise.
- Executed via `zig build test`.

## Test Categories

### 1. VM Instruction Execution with Random Sequences
- **Iterations**: 50 randomized instruction sequences
- **Inputs**: 
  - Random instruction sequences (10-100 instructions)
  - Random instruction types (LUI, ADDI, ECALL)
  - Random operands (registers, immediates)
- **Validations**:
  - VM initializes correctly with kernel data
  - VM state transitions (halted → running → halted/errored)
  - PC updates correctly after each instruction
  - x0 register always remains zero
  - VM handles invalid instructions gracefully (errors, doesn't panic)
  - Execution stops at end of kernel or on error

### 2. VM Memory Access Patterns with Random Addresses
- **Iterations**: 100 random memory operations
- **Inputs**:
  - Random aligned addresses (8-byte aligned, within 4MB memory)
  - Random 64-bit values
- **Validations**:
  - Memory writes succeed for valid addresses
  - Memory reads return correct values
  - Out-of-bounds access returns `error.InvalidMemoryAccess`
  - Memory alignment is enforced (8-byte aligned)
  - No memory corruption between operations

### 3. VM Register File Behavior (x0 Hardwired)
- **Iterations**: 200 random register operations
- **Inputs**:
  - Random register indices (0-31)
  - Random 64-bit values
- **Validations**:
  - x0 register always returns zero (hardwired)
  - Writes to x0 are ignored (no effect)
  - Other registers (x1-x31) store and retrieve values correctly
  - Register indices are validated (0-31 range)

### 4. VM State Transitions (Running → Halted → Errored)
- **Iterations**: 30 state transition sequences
- **Inputs**:
  - Random instruction sequences
  - Random step counts
- **Validations**:
  - Initial state is `halted`
  - `start()` transitions to `running`
  - `stop()` transitions to `halted`
  - Invalid instructions/accesses transition to `errored`
  - State transitions are deterministic and consistent
  - Final state is always `halted` or `errored` (never `running`)

### 5. Synthetic ELF Kernel Loading
- **Iterations**: 20 synthetic ELF files
- **Inputs**:
  - Minimal valid ELF64 headers
  - Random entry points (0x1000-0x10000)
  - Single program header (PT_LOAD)
  - Minimal kernel code (single NOP instruction)
- **Validations**:
  - ELF magic number validation (0x7F 'E' 'L' 'F')
  - ELF class validation (64-bit)
  - ELF endianness validation (little-endian)
  - Entry point is set correctly in VM PC
  - Program headers are parsed correctly
  - Kernel segments are loaded into VM memory
  - Invalid ELF files are rejected gracefully

## Assertions Added

### VM State Validation
- State transitions are valid (halted ↔ running ↔ errored)
- State consistency after operations
- No invalid state combinations

### Register Validation
- x0 always returns zero (hardwired)
- Register indices are valid (0-31)
- Register values are stored correctly (except x0)

### Memory Validation
- Address alignment (8-byte aligned for 64-bit operations)
- Address bounds checking (within 4MB static memory)
- Memory read/write consistency
- Out-of-bounds access detection

### Instruction Validation
- Instruction decoding (LUI, ADDI, ECALL)
- PC updates correctly after execution
- Invalid instructions trigger errors (not panics)
- Instruction fetch bounds checking

### ELF Validation
- ELF magic number matching
- ELF structure validation (header, program headers)
- Entry point validation
- Segment loading validation

## Results
```
$ zig build test
... (pending execution)
```

## Notes
- Tests focus on VM core functionality, not GUI integration
- VM uses static allocation (4MB memory buffer)
- All assertions use `std.debug.assert` for compile-time and runtime checks
- Fuzz test uses deterministic seeds for reproducible results
- Instruction generation focuses on implemented instructions (LUI, ADDI, ECALL)
- Future extensions:
  - Test more RISC-V instructions (load/store, branches, arithmetic)
  - Test multi-segment ELF loading
  - Test VM serial output capture
  - Test VM error recovery
  - Test concurrent VM instances
  - Test VM performance under load
  - Test VM with real kernel ELF files

