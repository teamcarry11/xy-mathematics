# VM-Kernel Integration Contracts

**Purpose**: Define input/output contracts for VM-kernel integration layer and userspace ELF loader.

**Date**: 12025-11-15

## Overview

The integration layer bridges the VM's syscall interface (returns `u64`) with the kernel's syscall interface (returns `BasinError!SyscallResult`). All functions have explicit contracts defining:
- **Input validation**: What inputs are accepted/rejected
- **Output guarantees**: What outputs are guaranteed
- **Error handling**: What errors can occur and when
- **Type safety**: Explicit types (no `usize`), TigerStyle compliance

## Integration Layer Contracts

### `Integration.init(elf_data: []const u8) !Integration`

**Purpose**: Initialize VM-kernel integration with kernel ELF.

**Input Contract**:
- `elf_data` must be non-empty (`len > 0`)
- `elf_data` must be at least 64 bytes (minimum ELF header size)
- `elf_data` must be valid RISC-V64 ELF format (validated by `loadKernel`)

**Output Contract**:
- Returns `Integration` instance with:
  - `vm` in halted state
  - `kernel` initialized
  - `initialized = false` (must call `finish_init()` to complete)

**Error Contract**:
- `error.EmptyElfData`: `elf_data.len == 0`
- `error.InvalidElfHeader`: `elf_data.len < 64`
- Errors from `loadKernel`: Invalid ELF format, memory allocation failure

**Postconditions**:
- `vm.state == .halted`
- `kernel` is valid BasinKernel instance
- `initialized == false`

### `Integration.finish_init(self: *Integration) void`

**Purpose**: Complete initialization (set up syscall handler).

**Input Contract**:
- `self` must be partially initialized (`vm` and `kernel` set)
- `self.initialized == false`

**Output Contract**:
- `self.initialized == true`
- `global_kernel_ptr` set to `&self.kernel`
- VM syscall handler registered

**Error Contract**:
- Panics if `self.initialized == true` (double initialization)
- Panics if `global_kernel_ptr != null` (multiple integration instances)

**Postconditions**:
- `self.initialized == true`
- `global_kernel_ptr == &self.kernel`
- `self.vm.syscall_handler != null`

### `Integration.run(self: *Integration) !void`

**Purpose**: Run VM execution loop until halted or error.

**Input Contract**:
- `self.initialized == true`
- `self.vm.state == .halted`

**Output Contract**:
- VM execution completes (`vm.state == .halted` or `.errored`)

**Error Contract**:
- Errors from `vm.step()`: Invalid instruction, memory access violation

**Postconditions**:
- `vm.state == .halted` or `vm.state == .errored`
- If `vm.state == .errored`, `vm.last_error` contains error details

### `syscall_handler_wrapper(syscall_num: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64`

**Purpose**: Bridge VM syscall interface (u64) with kernel interface (SyscallResult).

**Input Contract**:
- `syscall_num >= 10` (kernel syscalls, not SBI)
- `global_kernel_ptr != null` (set by `Integration.finish_init()`)

**Output Contract**:
- Returns `u64`:
  - Negative values: Error codes (-1 to -11)
  - Non-negative values: Success values

**Error Contract**:
- Panics if `global_kernel_ptr == null` (called before `finish_init()`)
- Panics if `syscall_num < 10` (invalid syscall number)

**RISC-V Convention**:
- Negative `u64` values (when interpreted as `i64`) = error codes
- Non-negative `u64` values = success return values

**Error Code Mapping**:
- `-1`: `BasinError.invalid_handle`
- `-2`: `BasinError.invalid_argument`
- `-3`: `BasinError.permission_denied`
- `-4`: `BasinError.not_found`
- `-5`: `BasinError.out_of_memory`
- `-6`: `BasinError.would_block`
- `-7`: `BasinError.interrupted`
- `-8`: `BasinError.invalid_syscall`
- `-9`: `BasinError.invalid_address`
- `-10`: `BasinError.unaligned_access`
- `-11`: `BasinError.out_of_bounds`

**Postconditions**:
- Result is valid `u64` (can be negative when interpreted as `i64`)
- If result < 0, corresponds to valid `BasinError`
- If result >= 0, corresponds to success value from kernel

## Userspace ELF Loader Contracts

### `loadUserspaceELF(allocator: std.mem.Allocator, elf_data: []const u8, load_address: u64) !VM`

**Purpose**: Load userspace ELF program into VM memory.

**Input Contract**:
- `elf_data` must be non-empty (`len > 0`)
- `elf_data` must be at least 64 bytes (minimum ELF header size)
- `elf_data` must be valid RISC-V64 ELF executable
- `load_address` must be page-aligned (`load_address % 4096 == 0`)
- `load_address` must be within VM memory bounds (`load_address < 4MB`)

**Output Contract**:
- Returns `VM` instance with:
  - Userspace program loaded at `load_address`
  - `vm.regs.pc` set to ELF entry point
  - `vm.regs.sp` (x2) set to stack address (top of memory, page-aligned)
  - `vm.state == .halted`

**Error Contract**:
- `error.EmptyElfData`: `elf_data.len == 0`
- `error.InvalidElfHeader`: `elf_data.len < 64`
- `error.UnalignedAddress`: `load_address % 4096 != 0`
- `error.AddressOutOfBounds`: `load_address >= 4MB`
- Errors from `loadKernel`: Invalid ELF format, memory allocation failure

**Postconditions**:
- `vm.state == .halted`
- `vm.regs.pc == elf_entry_point`
- `vm.regs.get(2) == STACK_ADDRESS` (SP register)
- `vm.regs.pc % 4 == 0` (instruction alignment)
- `vm.regs.get(2) % 4096 == 0` (stack alignment)

**Stack Setup**:
- Stack address: `VM_MEMORY_SIZE - PAGE_SIZE` (top of memory, page-aligned)
- Stack grows downward (standard RISC-V convention)

## Type Safety Contracts

### Explicit Types (No `usize`)
- All addresses: `u64` (RISC-V64 addresses)
- All sizes: `u64` (memory sizes)
- All counts: `u32` (array indices, counts)
- All register values: `u64` (RISC-V64 registers)

### Pointer Validation
- All pointer parameters validated for:
  - Non-null (`ptr != null`)
  - Alignment (`ptr % alignOf(T) == 0`)
  - Validity (within valid memory range)

### Error Handling
- All errors are explicit (`error` union types)
- No silent failures
- All error cases documented in contracts

## Assertion Contracts

### Preconditions (Input Validation)
- All function inputs validated with assertions
- Invalid inputs cause panic (debug) or return error (release)

### Postconditions (Output Guarantees)
- All function outputs validated with assertions
- Outputs guaranteed to satisfy postconditions

### Invariants (State Consistency)
- Integration state invariants maintained:
  - `initialized == true` → `global_kernel_ptr != null`
  - `initialized == true` → `vm.syscall_handler != null`
  - `vm.state == .running` → `initialized == true`

## Testing Contracts

### Unit Tests
- Test all input validation (empty data, invalid addresses, etc.)
- Test all error cases (error code mapping, error propagation)
- Test all postconditions (state consistency, register values)

### Integration Tests
- Test VM-kernel integration end-to-end
- Test syscall dispatch (VM → kernel → result)
- Test userspace ELF loading and execution

### Fuzz Tests
- Random input generation
- Contract violation detection
- State consistency checks

## References

- `src/kernel_vm/integration.zig` - Implementation
- `src/kernel/basin_kernel.zig` - Kernel syscall interface
- `src/kernel_vm/vm.zig` - VM implementation
- `src/kernel_vm/loader.zig` - ELF loader implementation
- `docs/userspace_readiness_assessment.md` - Userspace readiness assessment

