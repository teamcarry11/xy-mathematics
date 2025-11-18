# Userspace Roadmap — Grain Basin Kernel

**Goal**: Run Zig-compiled RISC-V64 programs in our VM to verify correctness before Framework 13 deployment.

**Current Status**: 40-60% complete. Kernel foundation ready, VM infrastructure ready, syscalls tested.

## Phase 1: Basic Userspace Execution (2-3 weeks)
**Target**: Run a minimal Zig program that prints "Hello, World"

### Week 1: VM-Kernel Integration + Userspace ELF Loader
- [ ] **VM-Kernel Integration Layer** (`src/kernel_vm/integration.zig`)
  - Create `runUserspaceProgram()` function
  - Initialize VM and BasinKernel instances
  - Register kernel as VM syscall handler
  - Create execution loop (VM.step() until halted)
  - Handle syscall dispatch (ECALL → kernel.handle_syscall)
  
- [ ] **Userspace ELF Loader** (extend `src/kernel_vm/loader.zig`)
  - Add `loadUserspaceELF()` function
  - Load at userspace addresses (0x10000+)
  - Set up stack pointer (SP register = 0x400000)
  - Handle program arguments (argv setup)
  - Support static linking only (initially)

- [ ] **Integration Test**
  - Create minimal assembly program (just ECALL exit)
  - Test VM-kernel integration
  - Verify syscall dispatch works

### Week 2: Critical RISC-V Instructions
- [ ] **Load Instructions**
  - LB (Load Byte)
  - LH (Load Halfword)
  - LW (Load Word)
  - LD (Load Doubleword)
  - LBU (Load Byte Unsigned)
  - LHU (Load Halfword Unsigned)
  - LWU (Load Word Unsigned)

- [ ] **Store Instructions**
  - SB (Store Byte)
  - SH (Store Halfword)
  - SW (Store Word)
  - SD (Store Doubleword)

- [ ] **Jump Instructions**
  - JAL (Jump and Link) - function calls
  - JALR (Jump and Link Register) - return addresses

- [ ] **Test with Simple C/Zig Program**
  - Compile minimal program (no stdlib)
  - Test memory access (loads/stores)
  - Test function calls (JAL/JALR)

### Week 3: Basic stdlib + Hello World
- [ ] **Minimal Syscall Wrappers** (`src/userspace/syscalls.zig`)
  - Wrap kernel syscalls for Zig stdlib
  - Map POSIX-style calls to Grain Basin syscalls
  - Or create custom minimal stdlib subset

- [ ] **Basic File System Stub**
  - In-memory filesystem (or stub)
  - Support stdin/stdout/stderr
  - Basic file operations

- [ ] **Hello World Compilation**
  - Compile Zig "Hello World" for RISC-V64
  - Link with minimal stdlib
  - Run in VM
  - Verify output

## Phase 2: Real Zig Programs (2-3 weeks)
**Target**: Run actual Zig programs with stdlib

### Week 4-5: Complete Instruction Set
- [ ] **Remaining Branches**
  - BNE (Branch Not Equal)
  - BLT (Branch Less Than)
  - BGE (Branch Greater or Equal)
  - BLTU (Branch Less Than Unsigned)
  - BGEU (Branch Greater or Equal Unsigned)

- [ ] **Remaining Arithmetic**
  - SUBI (Subtract Immediate)
  - SLLI, SRLI, SRAI (Shift Immediate)
  - SLTI, SLTIU (Set Less Than Immediate)
  - XORI, ORI, ANDI (Bitwise Immediate)
  - SLL, SRL, SRA (Shifts)
  - SLTU (Set Less Than Unsigned)

- [ ] **Test with Complex Programs**
  - Multi-file Zig programs
  - Function calls, loops, conditionals
  - Memory operations

### Week 6: File System + Process Spawn
- [ ] **Basic In-Memory File System**
  - File storage (in-memory)
  - Directory structure (simple)
  - File operations (open, read, write, close)

- [ ] **Complete syscall_spawn Implementation**
  - Parse ELF executable header
  - Load executable into process memory space
  - Create process structure in process table
  - Set up process registers (PC, SP, argv)
  - Return actual process ID

- [ ] **Test Multi-File Programs**
  - Programs that spawn processes
  - File I/O operations
  - Inter-process communication (channels)

## Phase 3: Production Features (Ongoing)
- [ ] Memory protection (page tables)
- [ ] Multi-process support (context switching)
- [ ] Full stdlib integration
- [ ] Performance optimizations
- [ ] Comprehensive testing

## Success Criteria

### MVP (Phase 1 Complete)
- ✅ Simple Zig program compiles for RISC-V64
- ✅ Program runs in VM
- ✅ Program can call syscalls
- ✅ Program can print output
- ✅ Program exits cleanly

### Full Userspace (Phase 2 Complete)
- ✅ Real Zig programs run (with stdlib)
- ✅ File system works
- ✅ Multi-process support
- ✅ Most stdlib functions work

### Production Ready
- ✅ Memory protection
- ✅ Full isolation
- ✅ Performance optimized
- ✅ Comprehensive test coverage

## Key Files

- `src/kernel_vm/integration.zig` - VM-kernel integration (NEW)
- `src/kernel_vm/loader.zig` - ELF loader (EXTEND)
- `src/kernel_vm/vm.zig` - VM core (EXTEND with instructions)
- `src/kernel/basin_kernel.zig` - Kernel syscalls (EXTEND spawn)
- `src/userspace/syscalls.zig` - Syscall wrappers (NEW)
- `src/userspace/stdlib.zig` - Minimal stdlib (NEW)

## References

- `docs/userspace_readiness_assessment.md` - Detailed assessment
- `src/kernel_vm/vm.zig` - VM implementation
- `src/kernel/basin_kernel.zig` - Kernel implementation
- RISC-V Instruction Set Manual - For instruction specifications

