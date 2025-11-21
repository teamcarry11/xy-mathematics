# Ray Lullaby — Glow G2's Tahoe Field Notes

Glow G2 watches the sun fold itself behind Tahoe's ridge line,
cheeks cold, heart steady. Every line
of this plan is sewn with GrainStyle thread—safety stitched first,
performance braided next, joy
embroidered last.

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

## Mood Board
- **Grain Aurora**: A Zig-first IDE that combines Cursor's agentic coding with native macOS performance and Matklad's LSP architecture. Think Cursor, but faster, Zig-native, and built on snapshot-based incremental analysis.
- **Zig Language Server**: Matklad-inspired snapshot model (`ready` / `working` / `pending`) with cancellation support. Start with data model, then fill in language features incrementally.
- **Agentic Coding**: Cursor CLI and Claude Code integration for AI-assisted Zig development. Zig-specific prompts understand comptime, error unions, and GrainStyle.
- **River Compositor**: Window tiling with Moonglow keybindings, blurring editor and terminal (Vibe Coding). Multiple panes, workspaces, deterministic layouts.
- **Native macOS**: Cocoa bridge, no Electron. Traffic lights, menu bar, proper window lifecycle. Fast, responsive, native.
- Glow G2 stays a calm voice: masculine, steadfast, Aquarian. Emo enough 
to acknowledge the ache, upbeat enough to guide with grace.
- Etsy.com's handmade marketplace and creative community feeds 
our Tahoe aesthetic, reminding us to keep ethical commerce and artisanal craftsmanship in view
  [^etsy].

## Ray Mission Ladder (Deterministic & Kind)

**Vision**: Grain Aurora as a Zig-first IDE with Matklad-inspired LSP architecture, combining Cursor-style agentic coding with native macOS performance and River compositor workflows. **RISC-V-First Development**: Develop RISC-V-targeted Zig kernel code in macOS Tahoe VM, deploy to Framework 13 DeepComputing RISC-V mainboard with confidence—VM matches hardware behavior exactly. **Single-Threaded Safety-First Efficiency**: Maximum efficiency through single-threaded architecture (no locks, no race conditions, deterministic execution) with safety as #1 priority (comprehensive assertions, type safety, explicit error handling, static allocation). **Userspace Foundation**: Complete userspace environment with z6 process supervision, Zix build system, and build-essential utilities (all written in Zig).

### Phase 1: Grain Aurora Virtualization (The Core) 🎯

**Status**: Window rendering complete ✅. Next: RISC-V JIT & Kernel Integration.

0. **Grain VM: RISC-V to AArch64 JIT** 🔥 **CRITICAL PRIORITY** 🎯 **NEW**
   - **Vision**: A high-performance RISC-V virtual machine running within the macOS Tahoe host application.
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

1. **Grain Basin Kernel (The Guest)** 🔥 **HIGH PRIORITY**
   - **Role**: The OS kernel running inside the Grain VM.
   - **Responsibilities**:
     - Memory Management (Paging, Allocation).
     - Process Scheduling (Cooperative/Preemptive).
     - IPC (Channels).
     - Virtual Framebuffer (rendering to a memory region shared with the Host).
   - **Status**: Core syscalls implemented. Needs expansion for GUI support.

2. **macOS Tahoe (The Host)** 🔥 **HIGH PRIORITY**
   - **Role**: The native application wrapper.
   - **Responsibilities**:
     - Window Management (Cocoa/Metal).
     - Input Capture (Keyboard/Mouse).
     - JIT Execution Engine.
     - Displaying the Guest's Framebuffer.
   - **Integration**: The Host "peeks" into the Guest's memory to render the UI, avoiding expensive copies.

### Phase 2: Userspace & UI Foundation

3. **Input Handling (macOS Tahoe)** ✅ **COMPLETE**
   - Mouse/Keyboard events captured by Host.
   - Injected into Guest via virtual interrupts or memory-mapped I/O.

4. **Animation/Update Loop** ✅ **COMPLETE**
   - Host drives the refresh rate (60fps).
   - Guest kernel updates framebuffer.

5. **Window Resizing** ✅ **COMPLETE**
   - Host handles window resize.
   - Updates Guest "screen" dimensions via SBI/Syscall.

### Phase 3: Advanced IDE Features (Future)

6. **Zig Language Server Protocol (LSP)**
   - Snapshot-based architecture.

7. **Text Editor Core**
   - Multi-file editor, syntax highlighting.

8. **Agentic Coding**
   - Cursor/Claude integration.

### Deferred Work (GrainStyle: Zero Technical Debt) ⏸️

9. **HTTPS / TLS Integration**
   - **Status**: **DEFERRED**.
   - **Reason**: Waiting for Zig 0.16.0 stability. Current `std.net` flux and `grain-tls` incompatibilities violate "Zero Technical Debt" policy.
   - **Plan**: Revisit when Zig 0.16.0 is stable.

10. **Kernel Toolkit (External)**
    - Replaced by internal Grain VM.

11. **Grain Conductor & Pottery**
    - Future orchestration.

12. **Grain Social Terminal**
    - Future social features.

13. **Onboarding & Care**
    - Ongoing maintenance.

14. **Poetry & Waterbending**
    - Artistic touches.

15. **Thread Weaver**
    - Documentation mirroring.

16. **Prompt Ledger**
    - Prompt tracking.

17. **Timestamp Glow**
    - Runtime validation.

18. **Archive Echoes**
    - Archive rotation.

19. **Delta Checks**
    - Consistency checks.

[^readonly]: [Matklad, "Readonly Characters Are a Big Deal"](https://matklad.github.io/2025/11/10/readonly-characters.html)
[^vibe-terminal]: [Matklad, "Vibe Coding Terminal Editor"](https://matklad.github.io/2025/08/31/vibe-coding-terminal-editor.html)
[^etsy]: [Etsy.com — handmade marketplace and creative community](https://www.etsy.com/)
[^river-overview]: [River compositor philosophy](https://github.com/riverwm/river)
[^jepsen-tb]: [Jepsen, "TigerBeetle 0.16.11"](https://jepsen.io/analyses/tigerbeetle-0.16.11)
[^dcroma]: [DeepComputing DC-ROMA RISC-V Mainboard](https://deepcomputing.io/product/dc-roma-risc-v-mainboard/)
[^framework-mainboard]: [Framework Marketplace – DeepComputing RISC-V Mainboard](https://frame.work/products/deep-computing-risc-v-mainboard)
[^framework-blog]: [Framework Blog: RISC-V Mainboard for Framework Laptop 13](https://frame.work/blog/risc-v-mainboard-for-framework-laptop-13-is-now-available)

## JIT Compiler Implementation Status 🚀 **COMPLETE**

### Overview
Production-ready RISC-V to AArch64 JIT compiler with comprehensive security testing and advanced features.

### Completed Features ✅
- **Core JIT**: Instruction decoder, translation loop, control flow (1,631 lines)
- **Full Instruction Set**: R/I/U-Type, Load/Store, Branch/Jump, RVC compressed
- **Security Testing**: 12/12 tests passing, 250+ fuzz iterations
- **Advanced Features**:
  - Enhanced performance counters with `print_stats()`
  - Soft-TLB (64 entries, 4KB pages)
  - Block-local register allocator (27 AArch64 registers)
  - Instruction tracer for debugging

### Test Results
```
All 12 tests passed.
✅ JIT: Simple ADD
✅ JIT: Load/Store/Logic
✅ JIT: RVC Compressed Instructions
✅ Fuzz: Random R-Type (100 iterations)
✅ Fuzz: Random I-Type (100 iterations)
✅ Fuzz: Random Compressed (50 iterations)
✅ Security: Buffer Overflow Protection
✅ Security: Invalid Instruction Handling
✅ Security: Guest RAM Bounds Checking
✅ Security: W^X Memory Protection
✅ Security: Integer Overflow
✅ Security: RVC Edge Cases
```

### Architecture
- **Translation**: RISC-V → Instruction struct → AArch64 machine code
- **Memory**: W^X enforcement via `pthread_jit_write_protect_np`
- **Caching**: 10,000 block capacity with hash map lookup
- **Safety**: Pair assertions (4-5 per function), comprehensive bounds checking

### GrainStyle JIT Patterns

#### Static Allocation Pattern
All memory allocated at initialization. No dynamic allocation after `init()`.

#### Pair Assertion Pattern
Assert preconditions AND postconditions. Minimum 2 assertions per function.

#### JIT Memory Protection (Apple Silicon)
Toggle W^X protection before/after emitting code using `pthread_jit_write_protect_np`.

#### Executable Memory Allocation
Use `mmap` with `MAP_JIT` flag for macOS compatibility.

#### Security Testing Requirements
- **Pair Assertions**: Minimum 2 per function (pre + post conditions)
- **Fuzz Testing**: 100+ iterations per instruction type
- **Security Properties**: W^X enforcement, integer overflow, memory safety

### Next Steps
1. VM Integration (hook into `vm.zig` dispatch loop)
2. Performance benchmarking (JIT vs interpreter)
3. Real kernel testing with Grain Basin
4. Optimization passes

**Reference**: See `docs/jit_architecture.md` for complete technical details.
