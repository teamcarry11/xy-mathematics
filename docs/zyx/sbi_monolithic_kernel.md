# RISC-V SBI and Monolithic Kernel Architecture

**Date**: 2025-11-13  
**Purpose**: Explain how RISC-V SBI (Supervisor Binary Interface) fits into monolithic kernel design

## The Layered Architecture

### Three Layers in RISC-V Systems

```
┌─────────────────────────────────────────┐
│  User Applications (User Mode)          │
│  - User-space programs                  │
│  - Libraries, applications              │
└─────────────────────────────────────────┘
              ↕ (syscalls via ECALL)
┌─────────────────────────────────────────┐
│  Grain Basin Kernel (Supervisor Mode)   │
│  - Process management                   │
│  - Memory management                    │
│  - I/O, file systems                    │
│  - Device drivers                       │
│  - **Monolithic**: All kernel services  │
│    in one address space                 │
└─────────────────────────────────────────┘
              ↕ (SBI calls via ECALL)
┌─────────────────────────────────────────┐
│  Platform Firmware (Machine Mode)       │
│  - SBI implementation (OpenSBI, etc.)  │
│  - Hardware initialization              │
│  - Platform services                    │
└─────────────────────────────────────────┘
              ↕ (direct hardware access)
┌─────────────────────────────────────────┐
│  Hardware (RISC-V CPU, Memory, etc.)    │
└─────────────────────────────────────────┘
```

## What is SBI?

**SBI (Supervisor Binary Interface)** is the **firmware/platform layer**, not part of the kernel.

**SBI provides:**
- **Platform services**: Timer, console, reset, IPI (Inter-Processor Interrupts)
- **Hardware abstraction**: Standardized interface to platform firmware
- **Boot services**: System initialization, hardware discovery

**SBI is NOT:**
- Part of the kernel
- A microkernel service
- A user-space service
- Kernel code

**SBI is:**
- The firmware/platform API
- The interface between kernel and hardware platform
- Similar to BIOS/UEFI on x86, or IOKit on macOS

## How SBI Fits into Monolithic Kernel

### Monolithic Kernel Definition

**Monolithic kernel** means:
- All kernel services run in **supervisor mode**
- All kernel code runs in **one address space**
- Direct function calls between kernel modules (no IPC overhead)
- Kernel handles: process management, memory, I/O, drivers, file systems

**Monolithic does NOT mean:**
- The kernel does everything (it still uses firmware/platform services)
- The kernel doesn't use SBI (it does, for platform services)
- The kernel is "all-in-one" including firmware (firmware is separate)

### The Relationship

**SBI is BELOW the kernel:**
- SBI = Platform/Firmware layer (machine mode)
- Kernel = OS layer (supervisor mode)
- Applications = User space (user mode)

**The kernel uses SBI for platform services:**
- Timer: `SBI_SET_TIMER` - set timer interrupt
- Console: `SBI_CONSOLE_PUTCHAR` - write to debug console
- Reset: `SBI_SHUTDOWN` - system shutdown/reboot
- IPI: `SBI_SEND_IPI` - inter-processor interrupts

**The kernel provides syscalls for user applications:**
- Process: `spawn`, `exit`, `wait`
- Memory: `map`, `unmap`, `protect`
- I/O: `open`, `read`, `write`, `close`

### Both Use ECALL, Different Function IDs

**ECALL instruction** is used for both, but with different function IDs:

```
ECALL with function ID < 10  → SBI call (platform services)
ECALL with function ID >= 10 → Kernel syscall (kernel services)
```

**Example Flow:**

1. **User application** calls kernel syscall:
   ```
   Application → ECALL (function ID 10) → Kernel syscall handler
   ```

2. **Kernel** calls SBI for platform service:
   ```
   Kernel → ECALL (function ID 1) → SBI CONSOLE_PUTCHAR
   ```

3. **SBI** interacts with hardware:
   ```
   SBI → Hardware (serial port, timer, etc.)
   ```

## Why This Matters for Grain Basin Kernel

### Our Monolithic Kernel Design

**Grain Basin kernel is monolithic:**
- All kernel services in supervisor mode
- Direct function calls (no IPC overhead)
- Type-safe, modern design
- Non-POSIX, minimal syscall surface

**Grain Basin kernel uses SBI:**
- For platform services (timer, console, reset)
- Via ECALL with function ID < 10
- Standard RISC-V approach

**Grain Basin kernel provides syscalls:**
- For user applications
- Via ECALL with function ID >= 10
- Our own non-POSIX interface

### The Separation

**SBI = Platform Services (Firmware Layer):**
- Timer management
- Console output
- System reset
- Hardware initialization

**Kernel Syscalls = Kernel Services (OS Layer):**
- Process management
- Memory management
- I/O operations
- File systems

**Both are needed, but at different layers:**
- SBI is the **foundation** (firmware/platform)
- Kernel is the **OS layer** (supervisor mode)
- Applications are the **user layer** (user mode)

## Comparison to Other Architectures

### x86/x86_64

**Similar concept:**
- **BIOS/UEFI** = Platform firmware (like SBI)
- **Linux kernel** = Monolithic kernel (like Grain Basin)
- **Applications** = User space

**Difference:**
- x86 uses BIOS/UEFI calls (INT instructions, ACPI, etc.)
- RISC-V uses SBI calls (ECALL instructions)

### macOS

**Similar concept:**
- **IOKit** = Platform/hardware abstraction (like SBI)
- **XNU kernel** = Monolithic kernel (like Grain Basin)
- **Applications** = User space

**Difference:**
- macOS uses IOKit for hardware access
- RISC-V uses SBI for platform services

## Key Insight

**SBI is NOT part of the kernel architecture decision.**

**Monolithic vs Microkernel** is about:
- How kernel services are organized (one address space vs multiple)
- How kernel modules communicate (direct calls vs IPC)
- Performance characteristics (fast vs slower due to IPC)

**SBI is about:**
- Platform/firmware interface
- Hardware abstraction
- Boot services

**You can have:**
- Monolithic kernel + SBI ✅ (Grain Basin)
- Microkernel + SBI ✅ (Redox OS)
- Monolithic kernel + BIOS ✅ (Linux)
- Microkernel + BIOS ✅ (seL4)

**The kernel architecture (monolithic vs microkernel) is independent of the platform interface (SBI vs BIOS).**

## Conclusion

**SBI fits into monolithic kernel architecture as:**
- The **platform/firmware layer** below the kernel
- The **interface** the kernel uses for platform services
- **Not part of** the kernel itself
- **Standard RISC-V approach** for all kernels (monolithic or microkernel)

**Grain Basin kernel:**
- Is **monolithic** (all kernel services in supervisor mode, one address space)
- Uses **SBI** for platform services (timer, console, reset)
- Provides **syscalls** for user applications (process, memory, I/O)

**Both are needed, but serve different purposes:**
- SBI = Platform services (firmware layer)
- Kernel = OS services (supervisor mode)
- Applications = User services (user mode)

**This is the standard RISC-V architecture, regardless of kernel design (monolithic or microkernel).**

