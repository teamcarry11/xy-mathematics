# Grain Handbook — Glow G2 Edition

## Current Roadmap: Grain Aurora Virtualization 🎯

**Status**: JIT Compiler complete ✅. Next: VM Integration & Kernel Development.

### Immediate Priorities

0. **Grain VM: RISC-V to AArch64 JIT** ✅ **COMPLETE**
   - **Vision**: Run Zig monolith kernel in virtualized RISC-V environment within macOS Tahoe IDE.
   - **Status**: Production-ready JIT compiler implemented (1,631 lines)
   - **Features**:
     - Full RISC-V64 instruction set + RVC compressed
     - Security testing (12/12 tests passing)
     - Advanced features (perf counters, TLB, register allocator, tracer)
   - **Next**: VM integration, performance benchmarking

1. **VM Integration** 🔥 **CRITICAL PRIORITY** �� **NEW**
   - Hook JIT into `vm.zig` dispatch loop
   - Add `init_with_jit()` and `step_jit()` methods
   - Implement interpreter fallback for JIT failures
   - Test with Grain Basin kernel code

2. **Input Handling** ✅ **COMPLETE**
   - Mouse events (clicks, movement, drag)
   - Keyboard events (key presses, modifiers)
   - Window focus events
   - Event routing to Aurora's event system

3. **Animation/Update Loop** ✅ **COMPLETE**
   - Timer-based updates (60fps target)
   - Continuous redraw via `tick()` calls
   - Window resize handling
   - Event-driven updates

4. **Window Resizing** ✅ **COMPLETE**
   - `windowDidResize:` delegate implementation
   - Dynamic buffer resizing or scaling
   - CGImage/NSImage recreation on resize

5. **Text Rendering Integration** ⭐ **MEDIUM PRIORITY**
   - Integrate `TextRenderer` into `tahoe_window.zig`
   - Render text to RGBA buffer
   - Text input handling
   - Cursor rendering

6. **NSApplication Delegate** ⭐ **MEDIUM PRIORITY**
   - Proper app lifecycle handling
   - Clean shutdown support
   - Window delegate methods
   - Menu bar integration

7. **River Compositor Foundation** ⭐ **MEDIUM PRIORITY**
   - Multi-pane layout system
   - Window tiling logic
   - Moonglow keybindings

## Architecture Overview

### Grain Aurora Stack
```
┌─────────────────────────────────────┐
│   macOS Tahoe (Native Cocoa App)   │
├─────────────────────────────────────┤
│   Grain Aurora IDE (Zig GUI)       │
├─────────────────────────────────────┤
│   Grain VM (RISC-V → AArch64 JIT)  │ ✅ COMPLETE
├─────────────────────────────────────┤
│   Grain Basin Kernel (RISC-V64)    │
└─────────────────────────────────────┘
```

### JIT Compiler Architecture
- **Translation**: RISC-V → Instruction struct → AArch64 machine code
- **Memory**: W^X enforcement, 64MB code buffer
- **Caching**: 10,000 block capacity
- **Safety**: Pair assertions, comprehensive bounds checking

## Development Philosophy

### GrainStyle Principles
- **Patient Discipline**: Code written once, read many times
- **Explicit Limits**: No hidden complexity
- **Sustainable Practice**: Code that grows without breaking
- **Code That Teaches**: Comments explain why, not what

### Graincard Constraints
- Line width: 103 characters
- Function length: max 70 lines
- Total size: 103×80 monospace teaching cards (content-only, optimized for portrait 8.5×11" paper)

## GrainStyle Development Guidelines

### Safety & Assertions
- **Crash Early**: Use `assert` for programmer errors
- **Pair Assertions**: Assert preconditions AND postconditions
- **Density**: Minimum 2 assertions per function
- **Negative Space**: Assert what *cannot* happen

### Memory Management
- **Startup Only**: Allocate everything in `init`
- **No Hidden Allocations**: Avoid functions that allocate implicitly
- **Pre-allocate Collections**: Call `ensureTotalCapacity` on HashMaps/Lists

### Control Flow
- **70-Line Limit**: Hard limit. Break it down.
- **No Recursion**: Iteration only
- **Explicit Types**: Use `u32` over `usize` for data protocols
- **Push Ifs Up, Fors Down**: Centralize control flow

### Documentation
- **"Why", not "What"**: Comments explain reasoning
- **Graincards**: Think of every file as a 103×80 teaching card

## References
- **JIT Architecture**: `docs/jit_architecture.md`
- **Grain Style**: `docs/zyx/grain_style.md`
- **Tasks**: `docs/tasks.md`
- **Browser Spec**: `docs/browser_prompt.md`
