# Userspace Readiness Assessment

**Question**: How far are we from being able to use our kernel VM runtime with Zig installed in a userspace on it so we can verify the correct outputs of RISC-V compiled Zig code?

**Date**: 2025-01-XX

## Executive Summary

We are **approximately 40-60%** of the way there. The core infrastructure exists (VM, kernel syscalls, ELF loader), but several critical integration pieces are missing to run real userspace Zig programs.

## What We Have ✅

### 1. VM Infrastructure (`src/kernel_vm/vm.zig`)
- ✅ RISC-V64 emulator with register file (32 GP registers + PC)
- ✅ 4MB memory space (configurable up to 64MB)
- ✅ Instruction execution loop (`step()`)
- ✅ ECALL handling with syscall dispatch
- ✅ SBI (Supervisor Binary Interface) support (timer, console, shutdown)
- ✅ Basic instruction set: ADD, SUB, SLT, OR, AND, XOR, LUI, ADDI, BEQ

### 2. Kernel Syscalls (`src/kernel/basin_kernel.zig`)
- ✅ All syscalls implemented: spawn, exit, yield, wait, map, unmap, protect, open, read, write, close, channel_create, channel_send, channel_recv, clock_gettime, sleep_until, sysinfo
- ✅ Handle table for file operations
- ✅ Mapping table for memory management
- ✅ Process table for process management
- ✅ Channel table for IPC
- ✅ Comprehensive validation and error handling

### 3. ELF Loader (`src/kernel_vm/loader.zig`)
- ✅ Can parse RISC-V64 ELF headers
- ✅ Can load ELF segments into VM memory
- ✅ Sets VM PC to entry point

### 4. Testing Infrastructure
- ✅ Fuzz tests for syscalls (006, 007, 008, 009)
- ✅ VM unit tests
- ✅ Comprehensive assertion coverage

## What's Missing ❌

### 1. **VM-Kernel Integration Layer** (Critical)
**Status**: Missing  
**Impact**: High  
**Effort**: Medium (1-2 weeks)

We have:
- VM that can execute instructions and handle ECALLs
- Kernel with syscall handlers

We need:
- A main program that:
  1. Creates a VM instance
  2. Creates a BasinKernel instance
  3. Registers kernel as VM's syscall handler
  4. Loads a userspace ELF program into VM memory
  5. Runs VM execution loop
  6. Handles syscalls via kernel

**Example integration code needed**:
```zig
// src/kernel_vm/integration.zig or similar
pub fn runUserspaceProgram(elf_data: []const u8) !void {
    var kernel = BasinKernel.init();
    var vm = VM.init(&[_]u8{}, 0);
    
    // Load userspace ELF
    vm = try loadUserspaceELF(elf_data);
    
    // Register kernel as syscall handler
    vm.set_syscall_handler(kernelSyscallWrapper, &kernel);
    
    // Run VM
    vm.start();
    while (vm.state == .running) {
        try vm.step();
    }
}
```

### 2. **Userspace ELF Loader** (Critical)
**Status**: Partial (loader exists but designed for kernel)  
**Impact**: High  
**Effort**: Low-Medium (3-5 days)

Current `loadKernel()` function loads ELF at fixed addresses. For userspace:
- Need to load at userspace addresses (e.g., 0x10000+)
- Need to set up stack pointer (SP register)
- Need to handle dynamic linking (or static linking only initially)
- Need to handle program arguments (argv)

### 3. **Process Execution (`syscall_spawn`)** (Critical)
**Status**: Stub (returns PID 1, doesn't actually spawn)  
**Impact**: High  
**Effort**: Medium (1 week)

Current `syscall_spawn`:
- Validates inputs
- Returns stub PID
- Doesn't load ELF
- Doesn't create process
- Doesn't set up memory space

Needed:
- Parse ELF executable header
- Load executable into process memory space
- Create process structure in process table
- Set up process registers (PC, SP, argv)
- Return actual process ID

### 4. **Expanded RISC-V Instruction Set** (High Priority)
**Status**: Partial (basic instructions only)  
**Impact**: High  
**Effort**: Medium-High (2-3 weeks)

Current instructions: ADD, SUB, SLT, OR, AND, XOR, LUI, ADDI, BEQ

Zig programs need:
- **Loads**: LB, LH, LW, LD, LBU, LHU, LWU (load from memory)
- **Stores**: SB, SH, SW, SD (store to memory)
- **Jumps**: JAL, JALR (function calls)
- **Branches**: BNE, BLT, BGE, BLTU, BGEU (more comparisons)
- **Arithmetic**: SUBI, SLLI, SRLI, SRAI, SLTI, SLTIU, XORI, ORI, ANDI
- **More ALU**: SLL, SRL, SRA, SLTU, BGE, BGEU, BLT, BLTU

**Note**: Without loads/stores, Zig programs can't access memory. Without JAL/JALR, they can't call functions. This is blocking.

### 5. **File System Backend** (Medium Priority)
**Status**: Handle table exists, no actual storage  
**Impact**: Medium  
**Effort**: Medium (1 week)

Current state:
- Handle table tracks open files
- `syscall_open` allocates handles
- No actual file storage or filesystem

For Zig stdlib to work:
- Need at least a simple in-memory filesystem
- Or stub filesystem that returns empty files
- Or integration with host filesystem (for development)

### 6. **Standard Library Integration** (Medium Priority)
**Status**: Not started  
**Impact**: Medium  
**Effort**: High (2-4 weeks)

Zig programs need:
- `std` library compiled for RISC-V64
- Syscall wrappers that match our kernel syscalls
- Or custom minimal stdlib that uses our syscalls

Options:
- **Option A**: Use Zig's stdlib, add syscall wrappers
- **Option B**: Create minimal stdlib subset (faster, more control)
- **Option C**: Stub stdlib functions (for testing only)

### 7. **Memory Protection & Isolation** (Low Priority for MVP)
**Status**: Not implemented  
**Impact**: Low (for single-process testing)  
**Effort**: High (3-4 weeks)

For production:
- Page tables
- Process isolation
- Memory protection

For MVP/testing:
- Can run single process without isolation
- Can add later

### 8. **Context Switching** (Low Priority for MVP)
**Status**: Not implemented  
**Impact**: Low (for single-process testing)  
**Effort**: Medium (1-2 weeks)

For multi-process:
- Save/restore register state
- Switch process memory spaces
- Handle process scheduling

For MVP:
- Can run single process sequentially
- Can add later

## Recommended Path Forward

### Phase 1: Basic Userspace Execution (2-3 weeks)
**Goal**: Run a minimal Zig program that prints "Hello, World"

1. **Week 1**: VM-Kernel Integration + Userspace ELF Loader
   - Create integration layer
   - Extend ELF loader for userspace
   - Test with minimal assembly program

2. **Week 2**: Critical RISC-V Instructions
   - Implement loads (LB, LH, LW, LD, LBU, LHU, LWU)
   - Implement stores (SB, SH, SW, SD)
   - Implement jumps (JAL, JALR)
   - Test with simple C/Zig program

3. **Week 3**: Basic stdlib + Hello World
   - Create minimal syscall wrappers
   - Stub file system (or in-memory)
   - Compile Zig "Hello World" for RISC-V64
   - Run in VM

### Phase 2: Real Zig Programs (2-3 weeks)
**Goal**: Run actual Zig programs with stdlib

1. **Week 4-5**: Complete Instruction Set
   - Implement remaining branches (BNE, BLT, BGE, etc.)
   - Implement remaining arithmetic (SUBI, shifts, etc.)
   - Test with more complex programs

2. **Week 6**: File System + Process Spawn
   - Implement basic in-memory filesystem
   - Complete `syscall_spawn` implementation
   - Test with multi-file Zig programs

### Phase 3: Production Features (Ongoing)
- Memory protection
- Multi-process support
- Context switching
- Full stdlib integration

## Estimated Timeline

**Minimum Viable Product (MVP)**: 2-3 weeks
- Can run simple Zig programs
- Basic syscalls work
- Single process only

**Full Userspace Support**: 6-8 weeks
- Can run real Zig programs
- File system works
- Multi-process support
- Most stdlib functions work

**Production Ready**: 3-6 months
- Memory protection
- Full isolation
- Performance optimizations
- Comprehensive testing

## Conclusion

We have solid foundations (VM, kernel, syscalls), but need integration work and expanded instruction set to run real userspace programs. The biggest blockers are:

1. **VM-Kernel integration** (no code connecting them)
2. **Missing RISC-V instructions** (loads/stores/jumps are critical)
3. **Userspace ELF loading** (loader exists but needs adaptation)

With focused effort, we could have a minimal "Hello World" running in **2-3 weeks**, and real Zig programs in **6-8 weeks**.

