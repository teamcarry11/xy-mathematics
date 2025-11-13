# 005 Fuzz Test: SBI + Kernel Syscall Integration

**Date**: 2025-11-13  
**Objective**: Randomized fuzz testing for full stack integration (Hardware → SBI → Kernel → Userspace)

## Objective

Validate the complete execution pipeline:
- **SBI calls**: Platform services (console, shutdown, timer)
- **Kernel syscalls**: Kernel services (spawn, exit, yield, map)
- **VM integration**: ECALL dispatch (function ID < 10 → SBI, >= 10 → kernel)
- **Serial output**: SBI_CONSOLE_PUTCHAR routing to serial output
- **State transitions**: VM state, kernel state, serial output state

## Method

**Randomized Input Generation:**
- Random SBI function IDs (0-9)
- Random kernel syscall numbers (10-50)
- Random syscall arguments (addresses, sizes, flags, handles)
- Random character sequences for SBI_CONSOLE_PUTCHAR
- Random VM state transitions (running, halted)

**Test Categories:**

### 1. SBI Call Fuzzing
- **Random SBI EIDs**: Generate random EID values (0-9)
- **Random arguments**: Generate random arguments for each SBI function
- **Assertions**: Validate SBI call handling, error codes, state transitions
- **Edge cases**: Invalid EIDs, out-of-range arguments, null serial output

### 2. Kernel Syscall Fuzzing
- **Random syscall numbers**: Generate random syscall numbers (10-50)
- **Random arguments**: Generate random arguments for each syscall
- **Assertions**: Validate syscall handling, error codes, return values
- **Edge cases**: Invalid syscall numbers, invalid arguments, unaligned addresses

### 3. ECALL Dispatch Fuzzing
- **Random function IDs**: Generate random function IDs (0-50)
- **Dispatch validation**: Verify correct dispatch (SBI vs kernel)
- **Assertions**: Validate dispatch logic, function ID ranges
- **Edge cases**: Boundary values (9, 10), invalid function IDs

### 4. Serial Output Fuzzing
- **Random characters**: Generate random character sequences
- **SBI_CONSOLE_PUTCHAR**: Test console output routing
- **Assertions**: Validate serial output buffer, write positions, character encoding
- **Edge cases**: Null serial output, buffer overflow, circular buffer wrapping

### 5. State Transition Fuzzing
- **VM state**: Random state transitions (running → halted, etc.)
- **Kernel state**: Random kernel state changes
- **Assertions**: Validate state transitions, state invariants
- **Edge cases**: Invalid transitions, state corruption

### 6. Combined Execution Fuzzing
- **Mixed SBI + kernel calls**: Random sequence of SBI and kernel syscalls
- **State persistence**: Validate state across multiple calls
- **Assertions**: Validate combined execution, state consistency
- **Edge cases**: Interleaved calls, state conflicts

## Assertions

### SBI Call Assertions
- EID must be < 10 (legacy SBI functions)
- EID must match known SBI function IDs
- Character arguments must fit in u8 (for CONSOLE_PUTCHAR)
- Serial output pointer must be valid if set
- VM state must remain valid after SBI call (unless shutdown)
- Return values must match SBI specification

### Kernel Syscall Assertions
- Syscall number must be >= 10 (kernel syscalls, not SBI)
- Syscall number must be valid enum value
- Arguments must be validated (addresses aligned, sizes valid, flags valid)
- Return values must be type-safe (Handle, not integer)
- Error codes must be valid BasinError enum values

### ECALL Dispatch Assertions
- Function ID < 10 → SBI call
- Function ID >= 10 → Kernel syscall
- Dispatch must be correct (no misrouting)
- Function ID must be within valid range

### Serial Output Assertions
- Buffer must be non-empty
- Write position must be within buffer bounds
- Characters must be valid (u8)
- Circular buffer wrapping must be correct
- Total written count must be accurate

### State Transition Assertions
- VM state transitions must be valid
- State invariants must be maintained
- No state corruption across calls
- State must be deterministic (same input → same state)

## Implementation Plan

**Phase 1: SBI Call Fuzzing**
- Generate random SBI EIDs and arguments
- Test SBI_CONSOLE_PUTCHAR with random characters
- Test SBI_SHUTDOWN state transition
- Validate error codes for unknown SBI functions

**Phase 2: Kernel Syscall Fuzzing**
- Generate random kernel syscall numbers and arguments
- Test implemented syscalls (exit, yield, map)
- Validate error handling for invalid syscalls
- Test type-safe return values

**Phase 3: ECALL Dispatch Fuzzing**
- Generate random function IDs across boundary (9, 10)
- Validate correct dispatch (SBI vs kernel)
- Test edge cases (boundary values, invalid IDs)

**Phase 4: Serial Output Fuzzing**
- Generate random character sequences
- Test SBI_CONSOLE_PUTCHAR routing
- Validate buffer management (circular buffer, overflow)
- Test null serial output handling

**Phase 5: Combined Execution Fuzzing**
- Generate random sequences of SBI + kernel calls
- Validate state persistence across calls
- Test interleaved execution patterns
- Validate state consistency

## Expected Results

**All assertions must pass:**
- SBI calls handled correctly
- Kernel syscalls handled correctly
- ECALL dispatch correct
- Serial output routing correct
- State transitions valid
- No crashes, no undefined behavior

**Edge cases handled:**
- Invalid function IDs → error codes
- Invalid arguments → error codes
- Null serial output → graceful handling
- Buffer overflow → circular buffer wrapping
- State corruption → assertions catch immediately

## Notes

- **Single-threaded**: All tests run in single thread (no concurrency)
- **Deterministic**: Same seed → same test sequence
- **Tiger Style**: Comprehensive assertions, explicit error handling
- **Safety #1**: All edge cases must be handled explicitly

