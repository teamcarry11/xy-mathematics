# Grain OS River-Inspired Features Plan

**Date**: 2025-11-24-105002-pst  
**Agent**: Grain OS (Fourth Agent)  
**Status**: Planning - River Study & Implementation  
**Grainorder Prefix**: zyxspl

---

## Overview

Implement River-like dynamic tiling and window management features for Grain OS, **written from scratch in Zig** to maintain permissive licensing (MIT + Apache + Creative Commons). River is GPL v3, so we study its architecture and design patterns but implement our own code.

## River Study Location

- **External**: `~/github/codeberg/river/river-0.3.12/`
- **Mirrored**: `grainstore/codeberg/river/river-0.3.12/` (for study, not committed)
- **Version**: River 0.3.12
- **License**: GPL v3 (we cannot copy code, only study architecture)

## Key River Features to Implement

### 1. Dynamic Tiling
- **River Feature**: Automatic window tiling based on layout
- **Grain Implementation**: Custom tiling algorithm in Zig
- **Files**: `src/grain_os/tiling.zig`
- **Grain Style**: Bounded allocations, explicit types (u32/u64), no recursion

### 2. Layout Generators
- **River Feature**: Modular layout generators (separate processes)
- **Grain Implementation**: Layout generator API, built-in layouts
- **Files**: `src/grain_os/layout.zig`, `src/grain_os/layouts/`
- **Grain Style**: Static allocation, bounded operations

### 3. Runtime Configuration (riverctl-like)
- **River Feature**: `riverctl` command-line tool for runtime configuration
- **Grain Implementation**: `grainctl` or IPC-based configuration API
- **Files**: `src/grain_os/config.zig`, `src/grain_os/ipc.zig`
- **Grain Style**: Explicit types, bounded message sizes

### 4. Window Management Policy Separation
- **River Feature**: Policy separated from compositor core (0.4.0 roadmap)
- **Grain Implementation**: Clean separation from the start
- **Files**: `src/grain_os/policy.zig`, `src/grain_os/compositor.zig`
- **Grain Style**: Single responsibility, explicit interfaces

### 5. Moonglow Keybindings
- **River Feature**: Customizable keybindings
- **Grain Implementation**: Keybinding system with Moonglow defaults
- **Files**: `src/grain_os/keybindings.zig`
- **Grain Style**: Static keybinding table, bounded operations

## Implementation Phases

### Phase 2.1: Dynamic Tiling Foundation ✅ **COMPLETE**
- ✅ Basic compositor structure (`src/grain_os/compositor.zig`)
- ✅ Wayland protocol structures (`src/grain_os/wayland/protocol.zig`)
- ✅ Tiling algorithm (vertical/horizontal splits) (`src/grain_os/tiling.zig`)
- ✅ Window tree structure (container-based, not binary tree - more flexible)
- ✅ Layout calculation (iterative, stack-based traversal - no recursion)
- ✅ Tag system (bitmask-based, 32 tags max)
- ✅ Comprehensive tests (`tests/053_grain_os_tiling_test.zig`)

### Phase 2.2: Layout Generators ✅ **COMPLETE**
- ✅ Layout generator API (`src/grain_os/layout.zig`)
- ✅ Built-in layouts (tall, wide, grid, monocle)
- ✅ Layout registry (manages available layouts)
- ✅ Layout function interface (vtable-style function pointers)
- ✅ Comprehensive tests (`tests/053_grain_os_layout_test.zig`)
- [ ] Layout switching (pending integration with compositor)

### Phase 2.3: Configuration System
- [ ] IPC channel for configuration
- [ ] Configuration message format
- [ ] Runtime configuration updates
- [ ] Configuration persistence (optional)

### Phase 2.4: Keybinding System
- [ ] Keybinding parser
- [ ] Keybinding action dispatch
- [ ] Moonglow default keybindings
- [ ] Keybinding customization

### Phase 2.5: Policy Separation
- [ ] Policy interface definition
- [ ] Compositor core (no policy)
- [ ] Policy implementation (separate module)
- [ ] Policy IPC communication

## Architecture Decisions

### Tiling Algorithm

**River Approach** (study, don't copy):
- Binary tree of splits (vertical/horizontal)
- Leaf nodes are windows
- Recursive layout calculation

**Grain Implementation**:
- **Iterative algorithm** (no recursion, Grain Style requirement)
- Stack-based tree traversal
- Bounded tree depth (MAX_TREE_DEPTH: 32)
- Explicit stack allocation

### Layout Generators

**River Approach** (study, don't copy):
- Separate processes (IPC-based)
- Modular, swappable layouts

**Grain Implementation**:
- **Built-in layouts first** (no separate processes initially)
- Layout function pointers (vtable-style)
- Future: IPC-based external layouts (optional)

### Configuration

**River Approach** (study, don't copy):
- `riverctl` command-line tool
- Unix socket IPC
- Text-based protocol

**Grain Implementation**:
- **Kernel channel IPC** (use existing channel syscalls)
- Binary message format (efficient, type-safe)
- `grainctl` command-line tool (optional, userspace)

## Grain Style Requirements

All code must follow **Grain Style**:
- ✅ **Function names**: `grain_case` (snake_case)
- ✅ **Types**: Explicit `u32`/`u64`, avoid `usize`
- ✅ **Function length**: Max 70 lines (enforced by `grainvalidate-70`)
- ✅ **Line length**: Max 100 characters (enforced by `grainwrap-100`)
- ✅ **No recursion**: Iterative algorithms only (critical for tiling)
- ✅ **Static allocation**: Prefer static buffers
- ✅ **Bounded operations**: All loops have explicit bounds
- ✅ **Comprehensive assertions**: Validate all assumptions
- ✅ **All compiler warnings**: `-Wall -Wextra -Werror` equivalent

## Key Differences from River

1. **No Recursion**: River uses recursive algorithms; Grain uses iterative
2. **Kernel Integration**: Grain uses kernel channels for IPC, not Unix sockets
3. **Built-in First**: Grain starts with built-in layouts, external layouts later
4. **RISC-V Target**: Grain targets RISC-V, River targets x86_64/ARM64
5. **Permissive License**: Grain is MIT+Apache+CC, River is GPL v3

## Study Plan

1. **Read River Source** (for understanding, not copying):
   - `river-0.3.12/src/` - Core compositor code
   - `river-0.3.12/doc/` - Documentation
   - Focus on: architecture, data structures, algorithms

2. **Document Key Patterns**:
   - Tiling algorithm structure
   - Layout generator interface
   - Configuration protocol
   - Window management flow

3. **Implement from Scratch**:
   - Write own code in Zig
   - Follow Grain Style
   - Maintain permissive licensing

## Next Steps

1. **Study River Architecture**:
   - Review River source code structure
   - Document key algorithms and patterns
   - Identify core concepts to reimplement

2. **Implement Tiling Algorithm**:
   - Create window tree structure (iterative)
   - Implement split calculation
   - Test with simple layouts

3. **Add Layout Generators**:
   - Define layout interface
   - Implement built-in layouts
   - Test layout switching

## References

- River Compositor: https://codeberg.org/river/river
- River 0.3.12 Release: https://codeberg.org/river/river/releases/tag/v0.3.12
- River Source (Study): `grainstore/codeberg/river/river-0.3.12/`
- Wayland Protocol: https://wayland.freedesktop.org/
- Grain Style: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md

---

**Agent**: Grain OS (Fourth Agent)  
**Grainorder**: zyxspl  
**Status**: Planning - River Study  
**Date**: 2025-11-24-105002-pst

