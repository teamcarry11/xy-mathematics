# Next Implementation Phases

**Date**: 2025-11-13  
**Status**: Planning after Phase 1 & 2 syscall completion

## Current Status Summary

### Completed ✅
- **Phase 1**: 9/9 core syscalls ✅ COMPLETE
- **Phase 2**: 8/8 syscalls ✅ COMPLETE
- **Total**: 17/17 syscalls implemented (100% complete!)
- **ISA**: 15 instructions (LUI, ADDI, ADD, SUB, SLT, OR, AND, XOR, SLL, SRL, SRA, LW, SW, BEQ, ECALL)
- **Tests**: 14 VM tests passing
- **Tiger Style**: Zero warnings, comprehensive assertions

### Current State
- **Syscalls**: All stubs with comprehensive validation
- **Memory Management**: Stubs (map/unmap/protect return addresses/success, no actual tracking)
- **I/O**: Stubs (open/read/write/close return handles/zeros, no file system)
- **IPC**: Stubs (channel_create/send/recv return IDs/zeros, no message queues)
- **Process Management**: Stubs (spawn/wait return IDs/status, no process table)
- **Timer**: Stubs (clock_gettime/sleep_until return zeros, no timer integration)

## Recommended Next Phases

### Phase 3: Memory Management Foundation 🔥 **HIGH PRIORITY**
**Purpose**: Replace memory management stubs with actual implementation.

**Implementation**:
1. **Mapping Table Structure**:
   - Static array of memory mappings (max 256 entries for 4MB VM)
   - Each entry: address, size, flags, allocated flag
   - Tiger Style: Static allocation, comprehensive assertions

2. **Update `map` syscall**:
   - Allocate entry in mapping table
   - Track mapping (address, size, flags)
   - Return mapping address
   - Validate no overlaps

3. **Update `unmap` syscall**:
   - Look up mapping in table
   - Verify mapping exists
   - Free entry (mark as unused)
   - Return error if not found

4. **Update `protect` syscall**:
   - Look up mapping in table
   - Update flags for mapping
   - Return error if not found

**Rationale**:
- Foundation for all memory operations
- Needed before file system (file buffers need memory)
- Needed before process management (process memory spaces)
- Straightforward implementation (static table)

**Location**: `src/kernel/basin_kernel.zig` → add mapping table structure

### Phase 4: File System Foundation 🔥 **HIGH PRIORITY**
**Purpose**: Replace I/O stubs with basic file system.

**Implementation**:
1. **Handle Table Structure**:
   - Static array of file handles (max 64 entries)
   - Each entry: handle ID, file path, flags, position, buffer
   - Tiger Style: Static allocation, comprehensive assertions

2. **Update `open` syscall**:
   - Allocate handle in handle table
   - Store file path, flags
   - Return handle ID
   - For now: in-memory files only (no disk)

3. **Update `read` syscall**:
   - Look up handle in table
   - Read from file buffer (in-memory)
   - Update position
   - Return bytes read

4. **Update `write` syscall**:
   - Look up handle in table
   - Write to file buffer (in-memory)
   - Update position
   - Return bytes written

5. **Update `close` syscall**:
   - Look up handle in table
   - Free handle entry
   - Return error if not found

**Rationale**:
- Foundation for I/O operations
- Needed for kernel/user communication
- Simple in-memory file system first (no disk yet)

**Location**: `src/kernel/basin_kernel.zig` → add file system structures

### Phase 5: Process Management Foundation 🔥 **MEDIUM PRIORITY**
**Purpose**: Replace process management stubs with basic implementation.

**Implementation**:
1. **Process Table Structure**:
   - Static array of processes (max 16 entries)
   - Each entry: process ID, executable pointer, entry point, state, exit status
   - Tiger Style: Static allocation, comprehensive assertions

2. **Update `spawn` syscall**:
   - Allocate process in process table
   - Store executable pointer, entry point
   - Return process ID
   - For now: single process execution (no actual spawning)

3. **Update `wait` syscall**:
   - Look up process in table
   - Return exit status (stub: 0)
   - Return error if not found

**Rationale**:
- Foundation for multi-process kernel (future)
- Needed for process lifecycle management
- Simple implementation first (single process)

**Location**: `src/kernel/basin_kernel.zig` → add process table structure

### Phase 6: IPC Foundation 🔥 **MEDIUM PRIORITY**
**Purpose**: Replace IPC stubs with basic channel implementation.

**Implementation**:
1. **Channel Table Structure**:
   - Static array of channels (max 32 entries)
   - Each entry: channel ID, message queue (circular buffer), senders/receivers
   - Tiger Style: Static allocation, comprehensive assertions

2. **Update `channel_create` syscall**:
   - Allocate channel in channel table
   - Initialize message queue
   - Return channel ID

3. **Update `channel_send` syscall**:
   - Look up channel in table
   - Copy message to queue
   - Wake up waiting receivers (if any)
   - Return error if queue full

4. **Update `channel_recv` syscall**:
   - Look up channel in table
   - Wait for message (if queue empty)
   - Copy message from queue to buffer
   - Return bytes received

**Rationale**:
- Foundation for inter-process communication
- Needed for process coordination
- Simple message queue first (no blocking yet)

**Location**: `src/kernel/basin_kernel.zig` → add channel table structure

### Phase 7: Timer Integration 🔥 **MEDIUM PRIORITY**
**Purpose**: Integrate SBI timer for time operations.

**Implementation**:
1. **Timer State**:
   - Track system time (nanoseconds since boot)
   - Update via SBI timer interrupts (future)
   - For now: simple counter

2. **Update `clock_gettime` syscall**:
   - Get current time from timer state
   - Write to timespec structure
   - Handle different clock types (monotonic vs realtime)

3. **Update `sleep_until` syscall**:
   - Get current time
   - Calculate sleep duration
   - Sleep until timestamp (for now: immediate return)
   - Return error if timestamp in past

**Rationale**:
- Foundation for time-based operations
- Needed for scheduling, timeouts
- Simple counter first (no interrupts yet)

**Location**: `src/kernel/basin_kernel.zig` → add timer state

### Phase 8: Additional ISA Instructions 🔥 **LOW PRIORITY**
**Purpose**: Expand ISA for more complete kernel support.

**Candidates**:
- **JAL** (Jump And Link): Function calls
- **JALR** (Jump And Link Register): Return from functions
- **AUIPC** (Add Upper Immediate to PC): PC-relative addressing
- **Load/Store variants**: LB, LH, LBU, LHU, SB, SH (byte/halfword operations)
- **Branch variants**: BNE, BLT, BGE, BLTU, BGEU (more comparisons)

**Rationale**:
- Needed for more complex kernel code
- Function calls essential for structured code
- More load/store variants for data manipulation

**Location**: `src/kernel_vm/vm.zig` → instruction dispatch + execute functions

## Recommended Sequential Order

**Immediate Next Steps** (This Phase):
1. **Phase 3**: Memory Management Foundation (mapping table)
2. **Phase 4**: File System Foundation (handle table, in-memory files)
3. **Phase 5**: Process Management Foundation (process table)
4. **Phase 6**: IPC Foundation (channel table, message queues)
5. **Phase 7**: Timer Integration (SBI timer, time operations)

**Future Phases**:
- **Phase 8**: Additional ISA Instructions (JAL, JALR, AUIPC, etc.)
- **Phase 9**: Debug Interface (register viewer, memory inspector)
- **Phase 10**: ELF Loader Enhancement (full ELF support for spawn)
- **Phase 11**: Page Allocator (actual page management for map/unmap)

## Success Criteria

**Phase Complete When**:
- ✅ Mapping table implemented (map/unmap/protect work with actual tracking)
- ✅ Handle table implemented (open/read/write/close work with in-memory files)
- ✅ Process table implemented (spawn/wait work with process tracking)
- ✅ Channel table implemented (channel_create/send/recv work with message queues)
- ✅ Timer state implemented (clock_gettime/sleep_until work with time tracking)
- ✅ All tests passing
- ✅ Zero compiler warnings
- ✅ Tiger Style compliance maintained

## Notes

- **Stub Level**: Current implementations validate inputs but don't track state
- **Foundation First**: Build data structures before complex features
- **Tiger Style**: All implementations include comprehensive assertions, static allocation
- **Single-Threaded**: All implementations remain single-threaded (no locks)
- **Incremental**: Each phase builds on previous phases

