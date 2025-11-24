# Grain OS: River-Inspired Design (Clean-Room Implementation)

**Date**: 2025-11-23  
**Status**: Design Document  
**License**: MIT + Apache 2.0 + CC-BY (Grain OS standard)

## ⚠️ License Compliance

**Critical**: River Compositor is GPL-3.0 licensed. This document describes a **clean-room implementation** inspired by River's architecture, but implemented independently without copying GPL code.

**Approach**:
- Study River's architecture and features (reference only)
- Implement similar functionality from scratch in Grain Style
- Use permissive-licensed Wayland protocol definitions (MIT/X11)
- Follow clean-room design principles

## 🎯 River Features to Implement (Independently)

### 1. Dynamic Window Management (Tiling)

**River Feature**: Automatic tiling of windows in layouts  
**Grain Implementation**: Independent tiling algorithm

**Design**:
- Layout generators (separate from compositor core)
- Policy vs. implementation separation
- Window arrangement algorithms (master-stack, grid, etc.)

**Files to Create**:
- `src/grain_os/layout/tiler.zig` - Tiling algorithms
- `src/grain_os/layout/generator.zig` - Layout generator interface
- `src/grain_os/layout/policy.zig` - Layout policies (master-stack, grid, etc.)

**GrainStyle Requirements**:
- Bounded window arrays (MAX_WINDOWS: 256)
- Explicit u32/u64 types
- No recursion (iterative algorithms)
- Assertions for bounds checking

### 2. Workspace Management

**River Feature**: Multiple workspaces with River-style switching  
**Grain Implementation**: Independent workspace system

**Design**:
- Multiple workspaces (bounded: MAX_WORKSPACES: 10)
- Workspace switching (keyboard shortcuts)
- Window assignment to workspaces
- Workspace state persistence

**Files to Create**:
- `src/grain_os/workspace/manager.zig` - Workspace management
- `src/grain_os/workspace/state.zig` - Workspace state tracking

**GrainStyle Requirements**:
- Bounded workspace array (MAX_WORKSPACES: 10)
- Explicit workspace IDs (u32)
- Assertions for workspace bounds

### 3. Runtime Configuration (riverctl-like)

**River Feature**: `riverctl` command-line interface for runtime configuration  
**Grain Implementation**: Independent configuration system

**Design**:
- IPC-based configuration interface
- Command parsing and execution
- Configuration state management
- Hot-reloadable configuration

**Files to Create**:
- `src/grain_os/config/ipc.zig` - IPC configuration interface
- `src/grain_os/config/parser.zig` - Command parser
- `src/grain_os/config/state.zig` - Configuration state

**GrainStyle Requirements**:
- Bounded command buffer (MAX_COMMAND_LEN: 1024)
- Explicit command types (enum)
- Assertions for command validation

### 4. Layout Generator Separation

**River Feature**: Layout generators as separate processes  
**Grain Implementation**: Independent layout generator architecture

**Design**:
- Layout generator interface (protocol)
- Generator process communication
- Policy vs. implementation separation
- Generator lifecycle management

**Files to Create**:
- `src/grain_os/layout/generator_interface.zig` - Generator protocol
- `src/grain_os/layout/generator_manager.zig` - Generator process management

**GrainStyle Requirements**:
- Bounded generator array (MAX_GENERATORS: 16)
- Explicit generator IDs (u32)
- Assertions for generator bounds

### 5. Input Handling

**River Feature**: Keyboard and mouse input routing  
**Grain Implementation**: Independent input system

**Design**:
- Input event routing to windows
- Focus management
- Keyboard shortcut handling
- Mouse pointer tracking

**Files to Create**:
- `src/grain_os/input/router.zig` - Input event routing
- `src/grain_os/input/focus.zig` - Focus management
- `src/grain_os/input/shortcuts.zig` - Keyboard shortcuts

**GrainStyle Requirements**:
- Bounded input queue (MAX_INPUT_EVENTS: 256)
- Explicit event types (enum)
- Assertions for event validation

## 📋 Implementation Phases

### Phase 1: Workspace Management (Foundation)

**Goal**: Implement basic workspace switching and window assignment

**Tasks**:
1. Create workspace manager (`src/grain_os/workspace/manager.zig`)
2. Implement workspace switching
3. Window assignment to workspaces
4. Workspace state tracking
5. Tests (`tests/053_grain_os_workspace_test.zig`)

**Estimated**: 2-3 days

### Phase 2: Basic Tiling Layout

**Goal**: Implement master-stack tiling layout

**Tasks**:
1. Create tiler module (`src/grain_os/layout/tiler.zig`)
2. Implement master-stack algorithm
3. Window arrangement logic
4. Layout updates on window changes
5. Tests (`tests/054_grain_os_tiler_test.zig`)

**Estimated**: 3-4 days

### Phase 3: Layout Generator Interface

**Goal**: Separate layout generators from compositor core

**Tasks**:
1. Create generator interface (`src/grain_os/layout/generator_interface.zig`)
2. Implement generator protocol
3. Generator process management
4. Policy vs. implementation separation
5. Tests (`tests/055_grain_os_generator_test.zig`)

**Estimated**: 4-5 days

### Phase 4: Runtime Configuration

**Goal**: Implement riverctl-like configuration interface

**Tasks**:
1. Create IPC configuration interface (`src/grain_os/config/ipc.zig`)
2. Command parser (`src/grain_os/config/parser.zig`)
3. Configuration state management
4. Hot-reloadable configuration
5. Tests (`tests/056_grain_os_config_test.zig`)

**Estimated**: 3-4 days

### Phase 5: Input Handling

**Goal**: Implement input routing and focus management

**Tasks**:
1. Create input router (`src/grain_os/input/router.zig`)
2. Focus management (`src/grain_os/input/focus.zig`)
3. Keyboard shortcuts (`src/grain_os/input/shortcuts.zig`)
4. Mouse pointer tracking
5. Tests (`tests/057_grain_os_input_test.zig`)

**Estimated**: 3-4 days

## 🔍 Clean-Room Design Principles

### 1. Independent Implementation

- **No code copying**: All code written from scratch
- **Reference only**: Study River's architecture, not implementation
- **Original algorithms**: Develop our own tiling algorithms
- **Grain Style**: Follow GrainStyle/TigerStyle guidelines

### 2. Permissive-Licensed Dependencies

- **Wayland protocols**: Use MIT/X11 licensed protocol definitions
- **No GPL dependencies**: Avoid any GPL-licensed libraries
- **Zig standard library**: Use only stdlib and permissive-licensed crates

### 3. Documentation

- **Design documents**: Document architecture decisions
- **Algorithm descriptions**: Explain tiling algorithms independently
- **API documentation**: Comprehensive API docs

### 4. Testing

- **Comprehensive tests**: Test all features independently
- **Edge cases**: Test boundary conditions
- **Performance**: Benchmark against requirements

## 📚 Reference Materials (Study Only)

### River Compositor (GPL-3.0 - Reference Only)

- **Repository**: https://codeberg.org/river/river
- **License**: GPL-3.0-or-later ⚠️ (cannot copy code)
- **Purpose**: Study architecture and features
- **Action**: Mirror for reference, implement independently

### Wayland Protocol (MIT/X11 - Can Use)

- **Source**: wayland-protocols
- **License**: MIT/X11 ✅ (permissive)
- **Purpose**: Protocol definitions
- **Action**: Can use protocol XML files directly

### wlroots (MIT - Can Use)

- **Repository**: https://gitlab.freedesktop.org/wlroots/wlroots
- **License**: MIT ✅ (permissive)
- **Purpose**: Reference for Wayland compositor patterns
- **Action**: Can study and reference (but prefer Zig-native)

## 🎯 Success Criteria

1. **Functionality**: Match River's core features (tiling, workspaces, configuration)
2. **Performance**: Comparable performance to River
3. **License**: All code MIT + Apache 2.0 + CC-BY
4. **GrainStyle**: Full compliance with GrainStyle/TigerStyle
5. **Testing**: Comprehensive test coverage

## 📝 Next Steps

1. **Start Phase 1**: Implement workspace management
2. **Document algorithms**: Write independent algorithm descriptions
3. **Create tests**: Comprehensive test suite
4. **Update documentation**: Keep plan.md and tasks.md updated

## 🔗 Related Documents

- `docs/grain_os_library_recommendations.md` - Library recommendations
- `docs/plan.md` - Overall Grain OS plan
- `docs/tasks.md` - Detailed task list

---

**Note**: This is a design document. Implementation will follow clean-room principles, ensuring all code is written independently without copying GPL-licensed code.
