# Basin Kernel Specification Freeze

**Date**: 2025-12-21-163457-pst  
**Agent**: Grain Vantage Agent (1st Agent)  
**Status**: SPECIFICATION FREEZE — Basin Kernel API Stable  
**Purpose**: Freeze Basin kernel specification to enable stable userspace development while allowing Vantage VM adaptation for macOS Tahoe beta versions

---

## Specification Freeze Policy

**Core Principle**: Basin kernel specification (syscall interface, data structures, behavior) is **FROZEN**. Vantage VM (macOS host implementation) can adapt to new macOS Tahoe beta versions without changing Basin spec.

**Separation of Concerns**:
- **Basin Kernel** (RISC-V64): Stable specification, runs on RISC-V hardware
- **Vantage VM** (macOS host): Development tool, adapts to macOS changes

---

## FROZEN: Basin Kernel Specification

### 1. Syscall Interface (FROZEN)

**Status**: ✅ **FROZEN** — No changes to syscall numbers, signatures, or behavior

**Frozen Components**:
- **Syscall Numbers**: All syscall enum values are frozen (see `src/kernel/basin_kernel.zig`)
- **Syscall Signatures**: Argument types, return types, error codes are frozen
- **Syscall Behavior**: Semantics, side effects, error conditions are frozen

**Syscall Categories** (All Frozen):

1. **Process & Thread Management** (1-4):
   - `spawn = 1`
   - `exit = 2`
   - `yield = 3`
   - `wait = 4`

2. **Memory Management** (10-12):
   - `map = 10`
   - `unmap = 11`
   - `protect = 12`

3. **Inter-Process Communication** (20-22):
   - `channel_create = 20`
   - `channel_send = 21`
   - `channel_recv = 22`

4. **I/O Operations** (30-39):
   - `open = 30`, `read = 31`, `write = 32`, `close = 33`
   - `unlink = 34`, `rename = 35`
   - `mkdir = 36`, `opendir = 37`, `readdir = 38`, `closedir = 39`

5. **Time & Scheduling** (40-41):
   - `clock_gettime = 40`
   - `sleep_until = 41`

6. **System Information** (50-59):
   - `sysinfo = 50`, `enumerate_processes = 51`, `get_process_info = 52`
   - `read_kernel_log = 53`
   - `set_priority = 54`, `get_priority = 55`
   - `setpgid = 56`, `getpgid = 57`, `setsid = 58`, `getsid = 59`

7. **Input Events** (60):
   - `read_input_event = 60`

8. **Framebuffer Operations** (70-72):
   - `fb_clear = 70`, `fb_draw_pixel = 71`, `fb_draw_text = 72`

9. **Signal Operations** (80-82):
   - `kill = 80`, `signal = 81`, `sigaction = 82`

10. **Network Operations** (90-93):
    - `network_create_interface = 90`, `network_set_state = 91`
    - `network_set_ipv4 = 92`, `network_get_interface = 93`

11. **TCP Socket Operations** (100-107):
    - `tcp_socket = 100`, `tcp_bind = 101`, `tcp_listen = 102`
    - `tcp_accept = 103`, `tcp_connect = 104`
    - `tcp_send = 105`, `tcp_recv = 106`, `tcp_close = 107`

12. **UDP Socket Operations** (110-114):
    - `udp_socket = 110`, `udp_bind = 111`
    - `udp_sendto = 112`, `udp_recvfrom = 113`, `udp_close = 114`

13. **Audio Device Operations** (120-131):
    - `audio_create_device = 120`, `audio_set_volume = 121`, `audio_set_mute = 122`
    - `audio_set_state = 123`, `audio_set_active_output = 124`, `audio_set_active_input = 125`
    - `audio_set_master_volume = 126`, `audio_set_master_mute = 127`
    - `audio_get_device = 128`, `audio_set_format = 129`
    - `audio_read = 130`, `audio_write = 131`

**Change Policy**: 
- ❌ **NO NEW SYSCALLS** without major version bump
- ❌ **NO CHANGES TO EXISTING SYSCALLS** (numbers, signatures, behavior)
- ✅ **ALLOWED**: Bug fixes that don't change behavior
- ✅ **ALLOWED**: Performance optimizations that preserve behavior

---

### 2. Data Structures (FROZEN)

**Status**: ✅ **FROZEN** — No changes to public data structures

**Frozen Components**:
- **Syscall Result Types**: Error codes, return value formats
- **Memory Mapping Flags**: `MapFlags` enum values
- **Process Handles**: Handle types and validation
- **File Handles**: Handle types and validation
- **Channel Handles**: Handle types and validation
- **Network Interface Types**: Interface structure definitions
- **Audio Device Types**: Device structure definitions

**Change Policy**:
- ❌ **NO CHANGES** to public data structure layouts
- ✅ **ALLOWED**: Internal implementation changes (not visible to userspace)

---

### 3. Error Codes (FROZEN)

**Status**: ✅ **FROZEN** — No changes to error code values or meanings

**Frozen Components**:
- Error code enum values
- Error code semantics
- Error code return conventions

**Change Policy**:
- ❌ **NO CHANGES** to error code values or meanings
- ✅ **ALLOWED**: New error codes for new syscalls (requires major version bump)

---

### 4. Memory Model (FROZEN)

**Status**: ✅ **FROZEN** — RISC-V64 memory model is stable

**Frozen Components**:
- Memory layout (kernel space, userspace)
- Page size (4KB)
- Memory protection flags
- Address space layout

**Change Policy**:
- ❌ **NO CHANGES** to memory model
- ✅ **ALLOWED**: Performance optimizations that preserve memory model

---

## ADAPTABLE: Vantage VM Implementation

### 1. macOS Host Adaptation (ADAPTABLE)

**Status**: ✅ **ADAPTABLE** — Vantage VM can adapt to macOS Tahoe beta versions

**Adaptable Components**:
- **macOS API Calls**: Can use new macOS APIs as they become available
- **Host Memory Management**: Can adapt to macOS memory management changes
- **Host I/O Operations**: Can adapt to macOS I/O API changes
- **Host Network Operations**: Can adapt to macOS network API changes
- **Host Audio Operations**: Can adapt to macOS audio API changes
- **Host Input Events**: Can adapt to macOS input API changes
- **Host Framebuffer**: Can adapt to macOS graphics API changes

**Adaptation Strategy**:
1. **Isolation Layer**: Vantage VM uses isolation layer between Basin kernel and macOS host
2. **Version Detection**: Detect macOS version and adapt accordingly
3. **Feature Flags**: Use feature flags for macOS-specific optimizations
4. **Fallback Support**: Maintain fallback for older macOS versions

---

### 2. JIT Compilation (ADAPTABLE)

**Status**: ✅ **ADAPTABLE** — JIT can adapt to macOS changes

**Adaptable Components**:
- **JIT Memory Protection**: Can adapt to macOS JIT API changes
- **JIT Code Generation**: Can adapt to macOS code signing requirements
- **JIT Performance**: Can optimize for macOS-specific features

**Adaptation Strategy**:
1. **Version-Specific JIT**: Use macOS version-specific JIT optimizations
2. **Feature Detection**: Detect macOS JIT capabilities at runtime
3. **Fallback Modes**: Maintain interpreter fallback for compatibility

---

### 3. VM Statistics & Profiling (ADAPTABLE)

**Status**: ✅ **ADAPTABLE** — Statistics can adapt to macOS changes

**Adaptable Components**:
- **Performance Counters**: Can use macOS-specific performance counters
- **Profiling Tools**: Can integrate with macOS profiling tools
- **Debugging Interface**: Can adapt to macOS debugging APIs

**Adaptation Strategy**:
1. **Platform-Specific Stats**: Use macOS-specific performance metrics
2. **Tool Integration**: Integrate with macOS development tools
3. **Fallback Metrics**: Maintain generic metrics for compatibility

---

## Versioning Strategy

### Basin Kernel Versioning

**Format**: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes to syscall interface (frozen, no changes expected)
- **MINOR**: New syscalls (requires coordination, major decision)
- **PATCH**: Bug fixes, performance optimizations (allowed)

**Current Version**: `1.0.0` (Specification Freeze)

---

### Vantage VM Versioning

**Format**: `MAJOR.MINOR.PATCH-macos-VERSION`

- **MAJOR**: Breaking changes to VM interface
- **MINOR**: New features, macOS version support
- **PATCH**: Bug fixes, macOS compatibility updates
- **macOS VERSION**: Supported macOS version (e.g., `26.3-beta`)

**Current Version**: `1.0.0-macos-26.3-beta` (macOS Tahoe 26.3 Beta)

---

## Coordination Points

### With Grain Core Agent

**Basin Spec Freeze**:
- ✅ Basin syscall interface is frozen — Core Agent can build on stable foundation
- ✅ Basin data structures are frozen — Core Agent can rely on stable types
- ✅ Basin error codes are frozen — Core Agent can handle errors consistently

**Vantage Adaptation**:
- ⏳ Vantage VM adapts to macOS changes transparently
- ⏳ Core Agent doesn't need to know about Vantage adaptation
- ⏳ Basin kernel behavior is consistent regardless of Vantage version

**Coordination**:
- ✅ Core Agent builds on frozen Basin spec
- ⏳ Vantage Agent adapts Vantage VM to macOS changes
- ✅ No coordination needed for Basin spec changes (frozen)

---

### With Other Agents

**Basin Spec Freeze**:
- ✅ All agents can build on stable Basin syscall interface
- ✅ All agents can rely on stable Basin data structures
- ✅ All agents can handle Basin errors consistently

**Vantage Adaptation**:
- ⏳ Vantage VM adaptation is transparent to all agents
- ⏳ Agents don't need to know about Vantage version
- ⏳ Basin kernel behavior is consistent for all agents

**Coordination**:
- ✅ All agents build on frozen Basin spec
- ⏳ Vantage Agent handles macOS adaptation independently
- ✅ No coordination needed for Basin spec changes (frozen)

---

## Testing Strategy

### Basin Spec Verification

**Tests**: All Basin spec tests must pass on:
- ✅ RISC-V64 hardware (Framework 13 DeepComputing RISC-V Mainboard)
- ✅ Vantage VM (macOS Tahoe 26.3 Beta)
- ✅ Future Vantage VM versions (macOS Tahoe future versions)

**Test Coverage**:
- ✅ All syscalls tested (validation + integration)
- ✅ All data structures tested
- ✅ All error codes tested
- ✅ Memory model tested

---

### Vantage Adaptation Testing

**Tests**: Vantage VM adaptation tests must verify:
- ✅ Basin spec compliance (all Basin tests pass)
- ✅ macOS version compatibility
- ✅ Performance benchmarks (60fps, sub-ms latency)
- ✅ Feature detection and fallback

**Test Coverage**:
- ✅ macOS version detection
- ✅ Feature flag behavior
- ✅ Fallback mode behavior
- ✅ Performance on new macOS versions

---

## Next Steps

### IMMEDIATE: Basin Spec Documentation

1. **IMMEDIATE**: Document all frozen Basin spec components
   - Complete syscall interface documentation
   - Complete data structure documentation
   - Complete error code documentation
   - Complete memory model documentation

2. **IMMEDIATE**: Create Basin spec versioning document
   - Define versioning policy
   - Define change approval process
   - Define breaking change policy

### SHORT-TERM: Vantage Adaptation Framework

1. **SHORT-TERM**: Create Vantage adaptation framework
   - macOS version detection
   - Feature flag system
   - Fallback mode support
   - Isolation layer design

2. **SHORT-TERM**: Test Vantage adaptation on macOS Tahoe 26.3 Beta
   - Verify all Basin tests pass
   - Verify performance benchmarks
   - Verify feature detection

### MEDIUM-TERM: macOS Version Support

1. **MEDIUM-TERM**: Support future macOS Tahoe beta versions
   - Detect new macOS versions
   - Adapt to new macOS APIs
   - Maintain backward compatibility
   - Test on new macOS versions

---

**Date**: 2025-12-21-163457-pst  
**Status**: Basin Kernel Specification Freeze — Vantage VM Adaptation Strategy
