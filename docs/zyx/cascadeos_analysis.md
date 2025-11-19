# CascadeOS Analysis: General-Purpose Zig OS with RISC-V Support

**Date**: 2025-11-13  
**Source**: [CascadeOS GitHub](https://github.com/CascadeOS/CascadeOS)  
**Language**: Zig (98.8% Zig)  
**Target**: x64, ARM64, **RISC-V64** (planned)  
**Status**: Active (100 stars, 2,466 commits)

## CascadeOS Overview

**Architecture**: General-purpose operating system  
**Language**: Zig (98.8% Zig, 1.2% Other)  
**Status**: Active development  
**Target**: x64 (current), ARM64 and **RISC-V64** (planned)  
**License**: MIT

### CascadeOS Goals

**Short Term:**
- Good enough x64 support for QEMU (virtio drivers)
- Userspace, no GUI
- ext2 on NVMe

**Planned Features:**
- x64, ARM64 and **RISC-V64** ✅ (exactly our target!)
- First class Zig support
- Userspace with GUI

### Key Finding: CascadeOS/zig-sbi

**Repository**: [CascadeOS/zig-sbi](https://github.com/CascadeOS/zig-sbi)  
**Purpose**: Zig wrapper around RISC-V SBI specification  
**Compatibility**: SBI Specification v3.0-rc1  
**Language**: 100% Zig  
**License**: MIT

**This is EXACTLY what we need!**

## RISC-V SBI (Supervisor Binary Interface) Explained

### What is SBI?

**SBI (Supervisor Binary Interface)** is a standardized interface between:
- **Operating System** (supervisor mode)
- **Platform Firmware** (machine mode, like OpenSBI)

**Purpose**: Provides platform runtime services for RISC-V operating systems.

### SBI Services

**Core Services:**
1. **System Reset**: Reboot, shutdown, power off
2. **Timer**: Set timer, read time
3. **Interrupt Controller**: IPI (Inter-Processor Interrupt) management
4. **Remote Fence**: Memory ordering across harts
5. **Hart State Management**: Start/stop harts (CPUs)
6. **System Suspend**: Suspend/resume system
7. **Performance Monitoring**: Counter access
8. **Debug Console**: Console output (printf equivalent)

### How SBI Works

**SBI Calls:**
- **ECALL Instruction**: OS calls SBI functions via ECALL
- **Function ID**: Specified in register a7 (x17)
- **Arguments**: Passed in registers a0-a6 (x10-x16)
- **Return Value**: Returned in register a0 (x10)

**Example SBI Call:**
```zig
// SBI console_putchar (function ID 1)
// Write character to debug console
// a7 = 1 (function ID)
// a0 = character (argument)
// ECALL instruction triggers SBI call
```

### SBI vs Our Current VM Approach

**Current VM Approach:**
- We're emulating RISC-V instructions directly
- We handle ECALL ourselves (syscall handling)
- We manage memory, registers, execution

**SBI-Enhanced Approach:**
- Use SBI for platform services (timer, console, reset)
- Our VM can call SBI functions via ECALL
- SBI handles platform-level operations
- We focus on kernel syscalls (not platform services)

**Key Insight**: SBI is for **platform services**, our syscalls are for **kernel services**.

## QEMU and RISC-V Virtualization

### QEMU RISC-V Support

**QEMU virt Machine:**
- Emulates standard RISC-V platform
- Includes PLIC (Platform-Level Interrupt Controller)
- Includes CLINT (Core Local Interruptor)
- Includes VirtIO devices (disk, network)
- Supports SBI (via OpenSBI firmware)

**QEMU on macOS:**
- **Available**: Via Homebrew (`brew install qemu`)
- **Works on Apple Silicon**: Dynamic binary translation (ARM → RISC-V)
- **No Nested Virtualization Needed**: QEMU handles translation
- **Proven**: Users boot RISC-V Ubuntu on M1 Macs

### QEMU vs Our macOS Tahoe VM

**QEMU Approach:**
- Full hardware emulation
- Runs OpenSBI firmware
- Supports full RISC-V platform
- Heavyweight (full emulator)

**Our macOS Tahoe VM Approach:**
- Lightweight RISC-V instruction emulator
- Focused on kernel development
- Integrated into macOS Tahoe IDE
- Can use SBI for platform services

**Key Difference**: QEMU emulates hardware, our VM emulates instructions.

## Should We Scrap Everything? **NO**

### Why Keep Our Current Work

**1. VM Foundation is Solid:**
- RISC-V64 instruction emulator ✅
- Register file, memory, instruction decoding ✅
- ELF loader ✅
- Serial output ✅
- Syscall handling ✅

**2. Kernel Foundation is Solid:**
- Syscall interface defined ✅
- Type-safe abstractions ✅
- Tiger Style compliance ✅
- Build integration ✅

**3. Integration is Complete:**
- VM-GUI integration ✅
- Kernel loading (Cmd+L) ✅
- VM execution (Cmd+K) ✅
- Serial output rendering ✅

### What We Should Do Instead

**1. Integrate SBI into Our VM:**
- Use CascadeOS/zig-sbi for SBI calls
- Add SBI function dispatch to VM
- Handle platform services via SBI
- Keep our kernel syscalls separate

**2. Study CascadeOS Structure:**
- Learn from their RISC-V64 implementation
- Study their kernel organization
- Adapt patterns for Grain Basin kernel

**3. Enhance VM with SBI:**
- Add SBI console output (debug printf)
- Add SBI timer support
- Add SBI system reset
- Keep our instruction emulation

## RISC-V SBI Integration Plan

### Phase 1: Add SBI Support to VM

**1. Add CascadeOS/zig-sbi Dependency:**
```zig
// build.zig.zon
.{
    .name = "sbi",
    .url = "https://github.com/CascadeOS/zig-sbi/archive/...",
    .hash = "...",
}
```

**2. Integrate SBI into VM:**
```zig
// src/kernel_vm/vm.zig
const sbi = @import("sbi");

// In execute_ecall:
// Check if ECALL is SBI call (function ID in a7)
// If SBI call: dispatch to SBI handler
// If kernel syscall: dispatch to kernel handler
```

**3. SBI Function Dispatch:**
- Function ID 0: SBI_SET_TIMER
- Function ID 1: SBI_CONSOLE_PUTCHAR
- Function ID 2: SBI_CONSOLE_GETCHAR
- Function ID 3: SBI_CLEAR_IPI
- Function ID 4: SBI_SEND_IPI
- Function ID 5: SBI_REMOTE_FENCE_I
- Function ID 6: SBI_REMOTE_SFENCE_VMA
- Function ID 7: SBI_REMOTE_SFENCE_VMA_ASID
- Function ID 8: SBI_SHUTDOWN
- etc.

### Phase 2: SBI Console Integration

**Replace Serial Output with SBI Console:**
- Use SBI_CONSOLE_PUTCHAR for kernel printf
- Integrate with macOS Tahoe GUI (display in VM pane)
- More standard than our custom serial output

### Phase 3: SBI Timer Integration

**Add Timer Support:**
- Use SBI_SET_TIMER for kernel timers
- Use SBI timer for scheduling
- More accurate than instruction counting

## CascadeOS Structure Analysis

### Directory Structure

```
CascadeOS/
├── kernel/          # Kernel code
├── lib/             # Kernel libraries
├── user/            # User-space programs
├── tool/            # Build tools
└── build/           # Build artifacts
```

### What We Can Learn

**1. Kernel Organization:**
- Study their kernel structure
- Learn from their RISC-V64 implementation
- Adapt patterns for Grain Basin kernel

**2. Build System:**
- Study their `build.zig` for multi-arch support
- Learn how they handle x64/ARM64/RISC-V64
- Adapt for our RISC-V64 focus

**3. SBI Integration:**
- See how they use zig-sbi
- Learn SBI call patterns
- Apply to our VM

## Recommendation: Enhance, Don't Scrap

### Action Items

**1. Integrate CascadeOS/zig-sbi:**
- Add as dependency to `build.zig.zon`
- Integrate SBI calls into VM ECALL handler
- Use SBI for platform services

**2. Study CascadeOS:**
- Clone to `~/github/CascadeOS/CascadeOS/`
- Study their RISC-V64 implementation
- Learn from their kernel structure

**3. Enhance VM with SBI:**
- Add SBI console output
- Add SBI timer support
- Keep our instruction emulation

**4. Continue Kernel Development:**
- Keep our syscall interface
- Keep our type-safe abstractions
- Keep our Tiger Style compliance

### Key Insight

**SBI is for Platform Services, Our Syscalls are for Kernel Services:**

- **SBI**: Timer, console, reset, IPI (platform-level)
- **Our Syscalls**: Process management, memory, I/O (kernel-level)
- **Both**: Use ECALL instruction, but different function IDs
- **Integration**: VM dispatches ECALL to SBI or kernel based on function ID

## Conclusion

**CascadeOS is excellent**, but:
- **Different Goals**: General-purpose OS vs our RISC-V kernel focus
- **Different Approach**: Full OS vs kernel development environment
- **Different Stage**: Planned RISC-V64 vs our active RISC-V64 development

**CascadeOS/zig-sbi is CRITICAL:**
- **Exactly what we need**: Zig wrapper for RISC-V SBI
- **Directly applicable**: Can integrate into our VM immediately
- **Standard approach**: Uses official SBI specification

**Grain Basin Kernel Strategy:**
- **Don't Scrap**: Our foundation is solid
- **Integrate SBI**: Use CascadeOS/zig-sbi for platform services
- **Study CascadeOS**: Learn from their RISC-V64 implementation
- **Continue Development**: Build on existing foundation

**Result**: Enhance our VM with SBI support, study CascadeOS for RISC-V patterns, continue Grain Basin kernel development with SBI integration.

