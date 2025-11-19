# Aero OS Kernel Module Analysis: Applicability to Grain Basin Kernel

**Date**: 2025-11-13  
**Source**: [Aero Kernel Documentation](https://andypy.dev/aero/x86_64-unknown-none/doc/aero_kernel/index.html)  
**Target**: Grain Basin kernel (Zig, RISC-V64)

## Aero Kernel Module Structure

Based on Aero's documentation, the kernel is organized into these modules:

### Architecture-Specific Modules (Need RISC-V Adaptation)

**1. `arch` - Architecture-Specific Code**
- **Aero**: x86_64 specific (long mode, 5-level paging, SMP)
- **Grain Basin**: Need RISC-V64 equivalent
- **Applicability**: ✅ **HIGH PRIORITY**
- **Adaptation**: 
  - RISC-V64 boot code (OpenSBI/SBI calls)
  - RISC-V page tables (Sv39/Sv48 paging)
  - RISC-V interrupt handling (PLIC, CLINT)
  - RISC-V SMP support (hart management)
- **Tiger Style**: Explicit RISC-V architecture abstraction layer

**2. `acpi` - ACPI Tables**
- **Aero**: x86_64 ACPI (Advanced Configuration and Power Interface)
- **Grain Basin**: RISC-V uses Device Tree (DTB) instead
- **Applicability**: ❌ **NOT APPLICABLE** (x86-specific)
- **Alternative**: Device Tree parsing for RISC-V hardware discovery
- **Tiger Style**: Type-safe device tree parser, explicit hardware discovery

### Core Kernel Modules (Directly Applicable)

**3. `syscall` - System Calls**
- **Aero**: System call interface (Linux-compatible)
- **Grain Basin**: Our core module (`basin_kernel.zig`)
- **Applicability**: ✅ **CORE MODULE** (already implemented)
- **Difference**: 
  - Aero: Linux-compatible syscalls (many syscalls)
  - Grain Basin: Minimal syscall surface (17 core syscalls)
- **Learning**: Study Aero's syscall dispatch mechanism
- **Tiger Style**: Type-safe syscall handlers, explicit error unions

**4. `mem` - Memory Management**
- **Aero**: Virtual memory, page tables, memory allocation
- **Grain Basin**: Essential for kernel operation
- **Applicability**: ✅ **HIGH PRIORITY**
- **Adaptation**:
  - RISC-V page tables (Sv39/Sv48)
  - Physical memory management
  - Virtual memory mapping
  - Kernel heap allocator
- **Tiger Style**: Static allocation where possible, explicit memory management

**5. `fs` - File System**
- **Aero**: Virtual file system (VFS) abstraction
- **Grain Basin**: Essential for storage I/O
- **Applicability**: ✅ **HIGH PRIORITY**
- **Adaptation**:
  - VFS abstraction (type-safe, not POSIX strings)
  - File system drivers (ext4, FAT32, custom)
  - Path handling (typed handles, not strings)
- **Tiger Style**: Type-safe file handles, explicit permissions

**6. `drivers` - Device Drivers**
- **Aero**: Device driver framework
- **Grain Basin**: Essential for hardware support
- **Applicability**: ✅ **HIGH PRIORITY**
- **Adaptation**:
  - RISC-V device drivers (UART, disk, network)
  - Device Tree-based driver discovery
  - Type-safe driver interface
- **Tiger Style**: Explicit driver registration, type-safe device handles

**7. `net` - Networking Stack**
- **Aero**: Network protocol stack
- **Grain Basin**: Essential for network I/O
- **Applicability**: ✅ **MEDIUM PRIORITY** (Phase 2)
- **Adaptation**:
  - TCP/IP stack (or use smoltcp library)
  - Network device drivers
  - Socket interface (type-safe, not POSIX)
- **Tiger Style**: Type-safe socket handles, explicit error handling

**8. `socket` - Socket Implementation**
- **Aero**: Socket abstraction layer
- **Grain Basin**: Part of networking stack
- **Applicability**: ✅ **MEDIUM PRIORITY** (Phase 2)
- **Adaptation**:
  - Type-safe socket handles
  - Non-POSIX socket interface
  - Async I/O support (io_uring-inspired)
- **Tiger Style**: Explicit socket operations, type-safe handles

### Supporting Modules (Applicable)

**9. `cmdline` - Command Line Parsing**
- **Aero**: Kernel command line argument parsing
- **Grain Basin**: Useful for boot-time configuration
- **Applicability**: ✅ **LOW PRIORITY** (nice to have)
- **Adaptation**: Simple command line parser for kernel options
- **Tiger Style**: Type-safe option parsing, explicit validation

**10. `logger` - Logging System**
- **Aero**: Kernel logging infrastructure
- **Grain Basin**: Essential for debugging
- **Applicability**: ✅ **HIGH PRIORITY**
- **Adaptation**:
  - Serial output (already have `serial.zig`)
  - Log levels (debug, info, warn, error)
  - Format string support
- **Tiger Style**: Explicit log levels, type-safe formatting

**11. `modules` - Kernel Modules**
- **Aero**: Loadable kernel modules (LKM)
- **Grain Basin**: Optional (adds complexity)
- **Applicability**: ⚠️ **LOW PRIORITY** (Phase 3, if at all)
- **Consideration**: 
  - Adds security complexity
  - May not be needed for minimal kernel
  - Can be added later if needed
- **Tiger Style**: If implemented, type-safe module interface

**12. `userland` - Userland Support**
- **Aero**: User-space program support
- **Grain Basin**: Essential for running applications
- **Applicability**: ✅ **HIGH PRIORITY**
- **Adaptation**:
  - Process management (already have `spawn` syscall)
  - ELF loader (already have in VM)
  - User-space memory management
  - System call interface
- **Tiger Style**: Type-safe process handles, explicit resource management

**13. `unwind` - Stack Unwinding**
- **Aero**: Stack unwinding for debugging/panics
- **Grain Basin**: Useful for debugging
- **Applicability**: ✅ **MEDIUM PRIORITY** (Phase 2)
- **Adaptation**:
  - RISC-V stack unwinding (DWARF debug info)
  - Panic handler with stack traces
  - Debug symbol support
- **Tiger Style**: Explicit unwinding, type-safe debug info

**14. `utils` - Utilities**
- **Aero**: General utility functions
- **Grain Basin**: Always useful
- **Applicability**: ✅ **ONGOING**
- **Adaptation**: Various utility functions as needed
- **Tiger Style**: Explicit utility functions, type-safe helpers

**15. `prelude` - Prelude/Imports**
- **Aero**: Common imports and re-exports
- **Grain Basin**: Zig module organization
- **Applicability**: ✅ **APPLICABLE**
- **Adaptation**: Zig `@import` organization, module structure
- **Tiger Style**: Clear module boundaries, explicit exports

**16. `rendy` - Graphics Rendering**
- **Aero**: Graphics rendering (likely for GUI)
- **Grain Basin**: Not needed for kernel (user-space concern)
- **Applicability**: ❌ **NOT APPLICABLE** (user-space)
- **Note**: Graphics should be in user-space, not kernel

## Recommended Module Structure for Grain Basin Kernel

### Phase 1: Core Kernel (Current Priority)

```
src/kernel/
├── basin_kernel.zig      # Syscall interface (✅ DONE)
├── arch/                 # RISC-V64 architecture code
│   ├── boot.zig         # Boot code (OpenSBI/SBI)
│   ├── paging.zig       # Page tables (Sv39/Sv48)
│   ├── interrupts.zig   # Interrupt handling (PLIC, CLINT)
│   └── smp.zig          # SMP support (hart management)
├── mem/                  # Memory management
│   ├── pmm.zig          # Physical memory manager
│   ├── vmm.zig          # Virtual memory manager
│   └── allocator.zig    # Kernel heap allocator
├── syscall/              # System call handlers
│   └── handlers.zig     # Syscall dispatch (already in basin_kernel.zig)
└── logger.zig           # Logging system
```

### Phase 2: I/O and Userland

```
src/kernel/
├── drivers/              # Device drivers
│   ├── uart.zig         # Serial/UART driver
│   ├── disk.zig         # Disk driver
│   └── device_tree.zig  # Device Tree parser
├── fs/                   # File system
│   ├── vfs.zig          # Virtual file system
│   └── ext4.zig         # ext4 driver (or FAT32)
├── userland/             # User-space support
│   ├── process.zig      # Process management
│   └── elf.zig          # ELF loader (already in VM)
└── unwind.zig           # Stack unwinding
```

### Phase 3: Networking (Future)

```
src/kernel/
├── net/                  # Network stack
│   ├── ip.zig           # IP protocol
│   ├── tcp.zig          # TCP protocol
│   └── udp.zig          # UDP protocol
└── socket.zig           # Socket interface
```

## Key Differences: Aero vs Grain Basin

### Architecture

| Aspect | Aero | Grain Basin |
|--------|------|-------------|
| **Architecture** | x86_64 | RISC-V64 |
| **Boot** | Multiboot2, UEFI | OpenSBI/SBI |
| **Paging** | 5-level paging | Sv39/Sv48 paging |
| **Interrupts** | APIC, PIC | PLIC, CLINT |
| **Hardware Discovery** | ACPI | Device Tree |

### Design Philosophy

| Aspect | Aero | Grain Basin |
|--------|------|-------------|
| **Syscall Surface** | Linux-compatible (many) | Minimal (17 core) |
| **POSIX Compatibility** | Source-level Linux compatibility | Non-POSIX, clean slate |
| **Type Safety** | Rust type system | Zig type system + comptime |
| **Memory Management** | Rust ownership | Zig explicit allocation |
| **Error Handling** | Rust Result | Zig error unions |

## Action Items

### Immediate (Phase 1)

1. **Create `arch/` module**: RISC-V64 architecture abstraction
   - Boot code (OpenSBI/SBI)
   - Page tables (Sv39/Sv48)
   - Interrupt handling (PLIC, CLINT)
   - SMP support (hart management)

2. **Create `mem/` module**: Memory management
   - Physical memory manager
   - Virtual memory manager
   - Kernel heap allocator

3. **Enhance `logger.zig`**: Logging system
   - Serial output integration
   - Log levels
   - Format string support

### Short-Term (Phase 2)

4. **Create `drivers/` module**: Device drivers
   - Device Tree parser
   - UART driver
   - Disk driver

5. **Create `fs/` module**: File system
   - VFS abstraction
   - File system drivers

6. **Create `userland/` module**: User-space support
   - Process management
   - ELF loader (integrate with VM)

### Long-Term (Phase 3)

7. **Create `net/` module**: Networking stack
8. **Create `socket.zig`**: Socket interface
9. **Add `unwind.zig`**: Stack unwinding for debugging

## Conclusion

**Aero's module structure is excellent** and directly applicable to Grain Basin kernel, with these adaptations:

- **Architecture**: Replace x86_64 with RISC-V64
- **Hardware Discovery**: Replace ACPI with Device Tree
- **Syscall Surface**: Minimal instead of Linux-compatible
- **Type System**: Zig instead of Rust
- **Design Philosophy**: Non-POSIX instead of Linux compatibility

**Recommendation**: Study Aero's module organization, adapt for RISC-V and Zig, maintain our minimal syscall surface and non-POSIX design.

**Result**: Grain Basin kernel can benefit from Aero's proven monolithic kernel structure while maintaining our unique RISC-V native, non-POSIX, minimal syscall surface approach.

