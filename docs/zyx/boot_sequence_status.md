# Kernel Boot Sequence Status

**Date**: 2025-11-20  
**Status**: In Progress

## Current State ✅

### 1. Entry Point (`src/kernel/entry.S`)
- ✅ Sets up stack pointer (`_stack_top`)
- ✅ Disables interrupts (`csrw sie, zero`)
- ✅ Jumps to `kmain()` in Zig

### 2. Kernel Main (`src/kernel/main.zig`)
- ✅ Prints boot banner (ASCII art)
- ✅ Initializes `BasinKernel` instance
- ✅ Enters trap loop

### 3. VM Integration
- ✅ VM can load kernel ELF
- ✅ VM can execute kernel code
- ✅ JIT is integrated (`step_jit()`)
- ✅ Syscall handling wired up

## Missing Components ❌

### 1. Framebuffer Initialization
**Status**: Not implemented  
**Priority**: HIGH (required for GUI)

**What's Needed**:
- Define framebuffer memory region in VM (e.g., `0x90000000`)
- Initialize framebuffer in kernel boot sequence
- Set framebuffer dimensions (1024x768, 32-bit RGBA)
- Clear framebuffer to background color

**Memory Layout**:
```
0x80000000 - 0x8FFFFFFF: Kernel code/data (128MB)
0x90000000 - 0x900BBFFF: Framebuffer (1024x768x4 = 3MB)
```

### 2. Framebuffer Access
**Status**: Not implemented  
**Priority**: HIGH

**What's Needed**:
- MMIO region for framebuffer in VM
- Kernel framebuffer driver (simple pixel write functions)
- Test pattern rendering function

### 3. Framebuffer Sync to Host
**Status**: Partial (VM has memory, but no sync)  
**Priority**: MEDIUM (Day 3 task)

**What's Needed**:
- Map VM framebuffer region to host memory
- Dirty region tracking
- Update macOS window on framebuffer changes

## Implementation Plan

### Step 1: Define Framebuffer Memory Region
- Add `FRAMEBUFFER_BASE = 0x90000000` constant to VM
- Add `FRAMEBUFFER_SIZE = 1024 * 768 * 4` (3MB)
- Ensure VM memory is large enough (currently 4MB, need 7MB+)

### Step 2: Initialize Framebuffer in Kernel
- Add `framebuffer_init()` function in `main.zig`
- Set framebuffer base address
- Clear framebuffer to dark background (e.g., `0x1E1E2E`)
- Call from `kmain()` after kernel initialization

### Step 3: Add Framebuffer Driver
- Create `src/kernel/framebuffer.zig`
- Implement `draw_pixel(x, y, color)` function
- Implement `draw_rect(x, y, w, h, color)` function
- Implement `clear(color)` function

### Step 4: Display Test Pattern
- Draw simple test pattern in `kmain()`
- Colored rectangles, grid, or gradient
- Verify framebuffer is working

### Step 5: VM Framebuffer Access
- Add MMIO handler for framebuffer region
- Allow kernel to write directly to framebuffer memory
- Sync framebuffer to macOS window (Day 3)

## Next Actions

1. **Increase VM Memory**: 4MB → 8MB (to fit kernel + framebuffer)
2. **Add Framebuffer Constants**: Define base address and size
3. **Create Framebuffer Module**: `src/kernel/framebuffer.zig`
4. **Initialize in Boot**: Call `framebuffer_init()` in `kmain()`
5. **Draw Test Pattern**: Simple colored rectangles

## References

- **JIT Architecture**: `docs/zyx/jit_architecture.md` (Phase 9: Display Integration)
- **Plan**: `docs/plan.md` (Day 1-2: Kernel Boot Sequence)
- **Tasks**: `docs/tasks.md` (Phase 2: VM Integration)

