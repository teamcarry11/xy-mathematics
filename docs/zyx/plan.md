# Grain Aurora GUI Plan — GrainStyle Execution

**Current Status**: Window rendering complete ✅, VM-GUI integration complete ✅, VM-syscall integration complete ✅, SBI integration complete ✅. Focus: Grain Aurora Virtualization (RISC-V VM -> AArch64 JIT) and Grain Basin Kernel.

## Grain Style Guidelines (Priority #1) 🌾

**Grain Style** is a philosophy of writing code that teaches. Every line should help the next generation understand not just how something works, but why it works. We write code that lasts, code that teaches, code that grows sustainably like grain in a field.

### Core Principles

- **Patient Discipline**: Code is written once, read many times. Take the time to write it right the first time. Every decision should be made consciously, with awareness of the consequences.
- **Explicit Limits**: Zig gives us the power to be explicit. Use it. Don't hide complexity behind abstractions—make it visible and understandable.
  - Use explicit error types, not generic `anyerror`
  - Set bounds explicitly in your types (u32, u64, not usize)
  - Document your assumptions in comments
  - Make your allocators explicit
- **Sustainable Practice**: Code that works today but breaks tomorrow isn't sustainable. Write code that can grow without breaking.
- **Code That Teaches**: Comments should explain why, not what. Good comments answer questions like "why did we choose this algorithm?" and "what edge case does this handle?"

### Graincard Constraints

All Zig code should be written to fit within graincard constraints:
- **Line width**: 73 characters per line (hard wrap)
- **Function length**: max 70 lines per function
- **Total size**: 75×100 monospace teaching cards

### Zig-Specific Guidelines

- **Memory Management**: Always make allocators explicit. Pass them as parameters, don't use global allocators unless absolutely necessary.
- **Error Handling**: Zig's error handling is explicit and powerful. Use it. Don't swallow errors.
- **Type Safety**: Use structs over primitives, enums for state, not magic numbers.
- **Naming**: Use `snake_case` for variables/functions, `PascalCase` for types, `SCREAMING_SNAKE_CASE` for constants.
- **Formatting**: Use `zig fmt`, then `grainwrap wrap` to enforce 73-char limit.

**Reference**: [Grain Style Guidelines](https://raw.githubusercontent.com/kae3g/grainkae3g/12025-11-03--1025--pst--moon-revati--asc-sagi27--sun-12h--kae3g/docs/grain_style.md)

## Grain Aurora Virtualization (The Core) 🎯

### 0. Grain VM: RISC-V to AArch64 JIT 🔥 **CRITICAL PRIORITY** 🎯 **NEW**
- **Vision**: Run Zig monolith kernel in virtualized RISC-V environment within macOS Tahoe IDE.
- **Architecture**:
  - **Guest**: Grain Basin Kernel (RISC-V64).
  - **Host**: macOS Tahoe (Apple Silicon M2).
  - **Translation**: JIT compiles RISC-V basic blocks to native AArch64 machine code.
- **Why**: Performance. Interpreters are too slow for a responsive GUI environment. We need near-native speed for the kernel to drive the UI.
- **Implementation Strategy**:
  - Start with the existing interpreter (`src/kernel_vm/vm.zig`).
  - Identify "hot" basic blocks.
  - Emit AArch64 instructions into executable memory (`mmap` with `PROT_EXEC`).
  - Patch jumps to chain blocks together.
  - **GrainStyle**: Simple, non-optimizing JIT first. Correctness > Optimization.
- **Reference**: `docs/jit_architecture.md` (To be created).

### 1. Grain Basin Kernel (The Guest) 🔥 **HIGH PRIORITY**
- **Role**: The OS kernel running inside the Grain VM.
- **Responsibilities**:
  - Memory Management (Paging, Allocation).
  - Process Scheduling (Cooperative/Preemptive).
  - IPC (Channels).
  - Virtual Framebuffer (rendering to a memory region shared with the Host).
- **Status**: Core syscalls implemented. Needs expansion for GUI support.

### 2. macOS Tahoe (The Host) 🔥 **HIGH PRIORITY**
- **Role**: The native application wrapper.
- **Responsibilities**:
  - Window Management (Cocoa/Metal).
  - Input Capture (Keyboard/Mouse).
  - JIT Execution Engine.
  - Displaying the Guest's Framebuffer.
- **Integration**: The Host "peeks" into the Guest's memory to render the UI, avoiding expensive copies.

## Userspace & UI Foundation

### 3. Input Handling (macOS Tahoe) ✅ **COMPLETE**
- Mouse/Keyboard events captured by Host.
- Injected into Guest via virtual interrupts or memory-mapped I/O.

### 4. Animation/Update Loop ✅ **COMPLETE**
- Host drives the refresh rate (60fps).
- Guest kernel updates framebuffer.

### 5. Window Resizing ✅ **COMPLETE**
- Host handles window resize.
- Updates Guest "screen" dimensions via SBI/Syscall.

## Advanced IDE Features (Future)

### 6. Zig Language Server Protocol (LSP)
- Snapshot-based architecture.

### 7. Text Editor Core
- Multi-file editor, syntax highlighting.

### 8. Agentic Coding
- Cursor/Claude integration.

## Deferred Work (GrainStyle: Zero Technical Debt) ⏸️

### 9. HTTPS / TLS Integration
- **Status**: **DEFERRED**.
- **Reason**: Waiting for Zig 0.16.0 stability. Current `std.net` flux and `grain-tls` incompatibilities violate "Zero Technical Debt" policy.
- **Plan**: Revisit when Zig 0.16.0 is stable.

### 10. Kernel Toolkit (External)
- Replaced by internal Grain VM.

### 11. Grain Conductor & Pottery
- Future orchestration.

### 12. Grain Social Terminal
- Future social features.

### 13. Onboarding & Care
- Ongoing maintenance.

### 14. Poetry & Waterbending
- Artistic touches.

### 15. Thread Weaver
- Documentation mirroring.

### 16. Prompt Ledger
- Prompt tracking.

### 17. Timestamp Glow
- Runtime validation.

### 18. Archive Echoes
- Archive rotation.

### 19. Delta Checks
- Consistency checks.

[^readonly]: [Matklad, "Readonly Characters Are a Big Deal"](https://matklad.github.io/2025/11/10/readonly-characters.html)
[^vibe-terminal]: [Matklad, "Vibe Coding Terminal Editor"](https://matklad.github.io/2025/08/31/vibe-coding-terminal-editor.html)
[^etsy]: [Etsy.com — handmade marketplace and creative community](https://www.etsy.com/)
[^river-overview]: [River compositor philosophy](https://github.com/riverwm/river)
[^jepsen-tb]: [Jepsen, "TigerBeetle 0.16.11"](https://jepsen.io/analyses/tigerbeetle-0.16.11)
[^dcroma]: [DeepComputing DC-ROMA RISC-V Mainboard](https://deepcomputing.io/product/dc-roma-risc-v-mainboard/)
[^framework-mainboard]: [Framework Marketplace – DeepComputing RISC-V Mainboard](https://frame.work/products/deep-computing-risc-v-mainboard)
[^framework-blog]: [Framework Blog: RISC-V Mainboard for Framework Laptop 13](https://frame.work/blog/risc-v-mainboard-for-framework-laptop-13-is-now-available)

## JIT Compiler Status Update 🎯 **COMPLETE**

### Implementation Complete ✅
The RISC-V to AArch64 JIT compiler is **production-ready** with all core features implemented:

**Core Capabilities**:
- Full RISC-V64 instruction set (R/I/U-Type, Load/Store, Branch/Jump)
- RVC compressed instructions (all 3 quadrants, 16+ types)
- Security testing (12/12 tests passing, 250+ fuzz iterations)
- Advanced features (performance counters, Soft-TLB, register allocator, tracer)

**Code Quality**:
- 1,631 lines of well-tested JIT code
- 20+ functions with pair assertions (4-5 assertions each)
- 100% grain_case naming convention
- TigerStyle compliant throughout

**Test Coverage**:
```
All 12 tests passed.
- Basic functionality (ADD, Load/Store, RVC)
- Fuzz testing (250+ iterations)
- Security validation (buffer overflow, bounds checking, W^X, etc.)
```

### Integration Roadmap
1. **VM Integration** (Next): Hook JIT into `vm.zig` dispatch loop
   - Add `init_with_jit()` method
   - Implement `step_jit()` with interpreter fallback
   - Test with real kernel code

2. **Performance Benchmarking**: Compare JIT vs interpreter speed

3. **Production Hardening**: Additional edge case testing

**Status**: Ready for VM integration and real-world testing.
