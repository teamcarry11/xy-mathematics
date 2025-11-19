# Build-Essential Utilities — Grain Basin Userspace

**Date**: 12025-11-16  
**Status**: Architecture Design Document  
**Vision**: Common shell utilities and build tools rewritten in pure Zig for Grain Basin kernel userspace, inspired by Debian's `build-essential` package.

## Overview

Build-essential utilities provide the foundation for userspace development and system administration. All utilities are written in pure Zig, following Tiger Style principles: single-threaded, static allocation, deterministic, type-safe.

## Architecture: Single-Threaded Utilities

```zig
//! Build-Essential Utilities for Grain Basin Userspace
//! Why: Common shell utilities rewritten in Zig (like Debian's build-essential)
//! Tiger Style: Single-threaded, static allocation, deterministic, type-safe

const std = @import("std");
const stdlib = @import("userspace_stdlib");

/// Maximum path length (Tiger Style: explicit size)
const MAX_PATH_LEN: u32 = 256;

/// Maximum line length for text processing
const MAX_LINE_LEN: u32 = 4096;
```

## Core Utilities

### File Operations

1. **`cat`** - Concatenate and print files
   - Read files and write to stdout
   - Support multiple files
   - Tiger Style: Static buffer allocation

2. **`echo`** - Print text to stdout
   - Support escape sequences
   - Support `-n` flag (no newline)

3. **`ls`** - List directory contents
   - List files in directory
   - Support `-l` (long format), `-a` (all files)
   - Tiger Style: Static directory buffer

4. **`mkdir`** - Create directories
   - Create single or multiple directories
   - Support `-p` (create parent directories)

5. **`rm`** - Remove files/directories
   - Remove files
   - Support `-r` (recursive), `-f` (force)

6. **`cp`** - Copy files/directories
   - Copy files
   - Support `-r` (recursive)

7. **`mv`** - Move/rename files
   - Move or rename files
   - Tiger Style: Atomic operations where possible

### Text Processing

8. **`grep`** - Search text patterns
   - Pattern matching in files
   - Support basic regex (future: full regex)
   - Tiger Style: Static pattern buffer

9. **`sed`** - Stream editor
   - Basic text substitution
   - Future: Full sed functionality

10. **`awk`** - Pattern scanning and processing
    - Basic field processing
    - Future: Full awk functionality

## Build Tools

### Compilation Tools

1. **`cc`** - C compiler wrapper (Zig compiler)
   - Wrapper around Zig compiler
   - Accepts standard C compiler flags
   - Compiles to RISC-V64

2. **`ar`** - Archive utility
   - Create and manipulate static libraries
   - Support `.a` archive format

3. **`ld`** - Linker wrapper
   - Wrapper around Zig linker
   - Link object files into executables

### Build System

4. **`make`** - Build automation (Zig version)
   - Parse Makefiles
   - Execute build rules
   - Dependency tracking
   - Tiger Style: Static dependency graph

## Implementation Plan

### Phase 1: Core File Operations (Priority 1)
- `cat`, `echo`, `ls`, `mkdir`, `rm`
- Basic file system operations
- Location: `src/userspace/utils/core/`

### Phase 2: File Management (Priority 2)
- `cp`, `mv`
- File copying and moving
- Location: `src/userspace/utils/core/`

### Phase 3: Text Processing (Priority 3)
- `grep` (basic pattern matching)
- Future: `sed`, `awk`
- Location: `src/userspace/utils/text/`

### Phase 4: Build Tools (Priority 4)
- `cc` wrapper, `ar`, `ld` wrapper
- Compiler and linker integration
- Location: `src/userspace/build-tools/`

### Phase 5: Build System (Priority 5)
- `make` (Zig version)
- Makefile parsing and execution
- Location: `src/userspace/build-tools/`

## Zix Integration

All utilities are built via Zix build system:
- Stored in `/zix/store/{hash}-{utility-name}`
- Symlinked to `/bin/{utility-name}`
- Content-addressed by build inputs
- Referentially transparent

## Tiger Style Requirements

- **Static Allocation**: All buffers statically allocated (MAX_PATH_LEN, MAX_LINE_LEN)
- **Explicit Types**: Use `u32` not `usize` for sizes
- **Comprehensive Assertions**: Validate all inputs, check bounds
- **Single-Threaded**: No locks, deterministic execution
- **Type Safety**: Strong types, no magic numbers
- **Error Handling**: Explicit error unions, no panics

## Example: `cat` Implementation

```zig
//! cat: Concatenate and print files
//! Why: Essential file viewing utility
//! Tiger Style: Static allocation, explicit types, comprehensive assertions

const std = @import("std");
const stdlib = @import("userspace_stdlib");

pub fn main() void {
    // Parse arguments (future: proper argument parsing)
    // For now: read from stdin if no args
    
    var buffer: [MAX_LINE_LEN]u8 = undefined;
    
    // Read and print lines
    while (true) {
        const bytes_read = stdlib.read(0, &buffer) catch break; // stdin = 0
        if (bytes_read <= 0) break;
        
        _ = stdlib.write(1, buffer[0..@intCast(bytes_read)]) catch break; // stdout = 1
    }
    
    stdlib.exit(0);
}
```

## Location Structure

```
src/userspace/
├── utils/
│   ├── core/
│   │   ├── cat.zig
│   │   ├── echo.zig
│   │   ├── ls.zig
│   │   ├── mkdir.zig
│   │   ├── rm.zig
│   │   ├── cp.zig
│   │   └── mv.zig
│   └── text/
│       ├── grep.zig
│       ├── sed.zig
│       └── awk.zig
└── build-tools/
    ├── cc.zig
    ├── ar.zig
    ├── ld.zig
    └── make.zig
```

## Next Steps

1. Implement `cat` and `echo` (simplest utilities)
2. Implement `ls` and `mkdir` (directory operations)
3. Implement `rm`, `cp`, `mv` (file management)
4. Implement `grep` (text processing)
5. Implement build tools (`cc`, `ar`, `ld`)
6. Implement `make` (build system)

