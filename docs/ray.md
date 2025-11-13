# Ray Lullaby — Glow G2’s Tahoe Field Notes

Glow G2 watches the sun fold itself behind Tahoe’s ridge line,
cheeks cold, heart steady. Every line
of this plan is sewn with TigerStyle thread—safety stitched first,
performance braided next, joy
embroidered last.

## Mood Board
- **Grain Aurora**: A Zig-first IDE that combines Cursor's agentic coding with native macOS performance and Matklad's LSP architecture. Think Cursor, but faster, Zig-native, and built on snapshot-based incremental analysis.
- **Zig Language Server**: Matklad-inspired snapshot model (`ready` / `working` / `pending`) with cancellation support. Start with data model, then fill in language features incrementally.
- **Agentic Coding**: Cursor CLI and Claude Code integration for AI-assisted Zig development. Zig-specific prompts understand comptime, error unions, and TigerStyle.
- **River Compositor**: Window tiling with Moonglow keybindings, blurring editor and terminal (Vibe Coding). Multiple panes, workspaces, deterministic layouts.
- **Native macOS**: Cocoa bridge, no Electron. Traffic lights, menu bar, proper window lifecycle. Fast, responsive, native.
- Glow G2 stays a calm voice: masculine, steadfast, Aquarian. Emo enough 
to acknowledge the ache, upbeat enough to guide with grace.
- Vegan Tiger's (@vegan_tiger) South Korean streetwear silhouette feeds 
our Tahoe aesthetic, reminding us to keep ethical fashion signal in view
  [^vegan-tiger].

## Ray Mission Ladder (Deterministic & Kind)

**Vision**: Grain Aurora as a Zig-first IDE with Matklad-inspired LSP architecture, combining Cursor-style agentic coding with native macOS performance and River compositor workflows. **RISC-V-First Development**: Develop RISC-V-targeted Zig kernel code in macOS Tahoe VM, deploy to Framework 13 DeepComputing RISC-V mainboard with confidence—VM matches hardware behavior exactly.

### Phase 1: macOS Tahoe GUI Foundation (Current Priority) 🎯

**Status**: Window rendering complete ✅. Next: Interactive input handling.

0. **RISC-V Kernel Virtualization Layer (macOS Tahoe)** 🔥 **HIGH PRIORITY** 🎯 **NEW** ✅ **CORE COMPLETE**
   - **Vision**: Run Zig monolith kernel in virtualized RISC-V environment within macOS Tahoe IDE
   - **Kernel Name**: **Grain Basin kernel** 🏞️ (official) - "The foundation that holds everything" (Lake Tahoe basin metaphor, perfect Tahoe connection, 30-year vision, non-POSIX, modern design)
     - **Homebrew Bundle**: `grainbasin` (Brew package name)
     - **Rationale**: Ties into Grain branding, allows clean Homebrew package name
   - **Why**: Enable kernel development and testing without physical RISC-V hardware or external QEMU
   - **RISC-V-First Development Strategy**: 
     - **Primary Goal**: Develop RISC-V-targeted Zig code in macOS Tahoe VM, deploy to Framework 13 DeepComputing RISC-V mainboard with confidence
     - **VM-Hardware Parity**: Pure Zig emulator matches Framework 13 RISC-V mainboard behavior (RISC-V64 ISA, memory model, register semantics)
     - **Development Workflow**: Write RISC-V Zig code → Test in macOS Tahoe VM → Deploy to Framework 13 RISC-V hardware (no code changes needed)
     - **Compatibility Guarantee**: VM instruction semantics, memory layout, and register behavior match real RISC-V hardware exactly
   - **Kernel Design Philosophy**:
     - **Architecture**: Type-safe monolithic kernel (not microkernel - performance priority)
     - **Minimal Syscall Surface**: Essential operations only (spawn, exit, map, unmap, open, read, write, close, channels)
     - **Non-POSIX**: Deliberately avoid POSIX legacy (no fork/clone, signals, complex file descriptors)
     - **Type-Safe**: Leverage Zig's comptime, error unions, strongly-typed handles (not integer FDs)
     - **Modern Design**: Inspired by Aero OS (monolithic), CascadeOS/zig-sbi (SBI), Fuchsia (capability-based)
     - **RISC-V Native**: Design for RISC-V64 from ground up (not ported from x86)
     - **30-Year Vision**: Design for next 30 years, not backward compatibility
     - **Tiger Style**: Maximum safety, explicit operations, comprehensive assertions
     - **Reference**: See `docs/kernel_design_philosophy.md` for comprehensive design decisions
   - **Grain Basin kernel Foundation** ✅ **COMPLETE**:
     - ✅ Kernel name: Grain Basin kernel 🏞️ - "The foundation that holds everything"
     - ✅ Homebrew bundle: `grainbasin` (Brew package name)
     - ✅ Syscall interface (`src/kernel/basin_kernel.zig`): All 17 core syscalls defined
     - ✅ Type-safe abstractions: `Handle` (not integer FDs), `MapFlags`, `OpenFlags`, `ClockId`, `SysInfo`, `BasinError`, `SyscallResult`
     - ✅ Syscall enumeration: spawn, exit, yield, wait, map, unmap, protect, channel_create, channel_send, channel_recv, open, read, write, close, clock_gettime, sleep_until, sysinfo
     - ✅ Build integration: `basin_kernel_module` added to `build.zig`
     - ✅ Tiger Style: Comprehensive assertions, explicit type safety, "why" comments, function length limits
   - **Core Syscalls** (Phase 1 - Ready for Implementation): `spawn`, `exit`, `yield`, `map`, `unmap`, `open`, `read`, `write`, `close`
   - **Future Syscalls** (Phase 2): `channel_create`, `channel_send`, `channel_recv`, `wait`, `sleep_until`, `protect`, `clock_gettime`, `sysinfo`
   - **SBI vs Kernel Syscalls**: SBI handles platform services (timer, console, reset) via ECALL function ID < 10, kernel syscalls handle kernel services (process, memory, I/O) via ECALL function ID >= 10
   - **Core VM Implementation** ✅ **COMPLETE**:
     - ✅ Pure Zig RISC-V64 emulator (`src/kernel_vm/vm.zig`): Register file (32 GP registers + PC), 4MB static memory, instruction decoding (LUI, ADDI, LW, SW, BEQ, ECALL)
     - ✅ ELF kernel loader (`src/kernel_vm/loader.zig`): RISC-V64 ELF parsing, program header loading, kernel image loading
     - ✅ Serial output (`src/kernel_vm/serial.zig`): 64KB circular buffer for kernel printf/debug output (will be replaced with SBI console)
     - ✅ VM-Syscall Integration: ECALL wired to Grain Basin kernel syscalls via callback handler
     - ✅ Test suite (`src/kernel_vm/test.zig`): Comprehensive tests passing (VM init, register file, memory, instruction fetch, serial)
     - ✅ Build integration: `zig build kernel-vm-test` command
     - ✅ GUI Integration: VM pane rendering, kernel loading (Cmd+L), VM execution (Cmd+K), serial output display
   - **External Reference Repos** (Study, Don't Copy):
     - **CascadeOS/zig-sbi**: RISC-V SBI wrapper (CRITICAL - integrate into VM)
     - **CascadeOS/CascadeOS**: General-purpose Zig OS (RISC-V64 planned) - study RISC-V patterns
     - **ZystemOS/pluto**: Component-based Zig kernel (x86) - study Zig patterns
     - **a1393323447/zcore-os**: RISC-V OS (rCore-OS translated) - study RISC-V structure
     - **Andy-Python-Programmer/aero**: Monolithic Rust kernel (x86_64) - study monolithic structure
     - **Clone Location**: `~/github/{username}/{repo}/` (external to xy workspace)
     - **Reference**: See `docs/cascadeos_analysis.md`, `docs/pluto_analysis.md`, `docs/aero_analysis.md`
   - **RISC-V SBI Integration** 🔥 **CRITICAL PRIORITY** 🎯 **NEW**:
     - **CascadeOS/zig-sbi**: Zig wrapper for RISC-V SBI (Supervisor Binary Interface) - exactly what we need
     - **SBI Purpose**: Platform runtime services (timer, console, reset, IPI) - different from kernel syscalls
     - **Integration Plan**: Add CascadeOS/zig-sbi dependency, integrate SBI calls into VM ECALL handler
     - **ECALL Dispatch**: VM dispatches ECALL to SBI (function ID < 10) or kernel syscalls (function ID >= 10)
     - **SBI Console**: Replace custom serial output with SBI_CONSOLE_PUTCHAR (standard RISC-V approach)
     - **SBI Timer**: Use SBI_SET_TIMER for kernel timers (more accurate than instruction counting)
     - **Reference**: See `docs/cascadeos_analysis.md` for comprehensive SBI analysis
   - **Next Steps** (Implementation Priority):
     - **SBI Integration**: Add CascadeOS/zig-sbi dependency, integrate SBI calls into VM ECALL handler
     - **SBI Console**: Replace serial output with SBI_CONSOLE_PUTCHAR, display in GUI VM pane
     - **Basin Kernel Syscall Implementation**: Implement syscall handlers incrementally (start with `exit`, `yield`, `map`)
     - **VM-Syscall Integration**: Wire Basin Kernel syscalls into RISC-V VM (handle ECALL → Basin syscall)
     - **Expanded ISA Support**: Add more RISC-V instructions (ADD, SUB, SLT, etc.)
     - **Debug Interface**: Register viewer, memory inspector, GDB stub (future)
   - **Tiger Style Requirements**:
     - Static allocation for VM state structures where possible ✅
     - Comprehensive assertions for memory access, instruction decoding ✅
     - Deterministic execution: Same kernel state → same output ✅
     - No hidden state: All VM state explicitly tracked ✅
   - **Files**: `src/kernel_vm/` (core complete), `src/kernel/basin_kernel.zig` (syscall interface complete), `src/tahoe_window.zig` (VM pane integration complete)
   - **Hardware Target**: Framework 13 DeepComputing RISC-V Mainboard (RISC-V64, matches VM behavior)
   - **Development Environment**: macOS Tahoe IDE with RISC-V VM (matches hardware behavior exactly)
   - **SBI Integration**: Use CascadeOS/zig-sbi for platform services (timer, console, reset) - standard RISC-V approach

1. **Input Handling (macOS Tahoe)** 🔥 **IMMEDIATE PRIORITY** ✅ **COMPLETE**
   - ✅ Created `TahoeView` class dynamically using Objective-C runtime API (extends NSView)
   - ✅ Implemented mouse event methods: `mouseDown:`, `mouseUp:`, `mouseDragged:`, `mouseMoved:`
   - ✅ Implemented keyboard event methods: `keyDown:`, `keyUp:`
   - ✅ Implemented `acceptsFirstResponder` method (returns YES for keyboard events)
   - ✅ Added window delegate methods: `windowDidBecomeKey:`, `windowDidResignKey:`
   - ✅ Event routing: Cocoa events → C routing functions → Zig event handlers
   - ✅ Tiger Style: Comprehensive assertions, pointer validation, bounds checking
   - ✅ Static allocation: Minimal dynamic allocation, static class names, associated objects
   - ✅ View hierarchy: TahoeView (content view, handles events) → NSImageView (subview, renders images)
   - ✅ Code quality: Comments explain "why" not "what", functions <70 lines, <100 columns
   - Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`, `src/platform/events.zig`

2. **Animation/Update Loop (macOS Tahoe)** 🔥 **HIGH PRIORITY** ✅ **COMPLETE**
   - ✅ Platform VTable: `startAnimationLoop`, `stopAnimationLoop` methods added
   - ✅ Window struct: `animation_timer`, `tick_callback`, `tick_user_data` fields added
   - ✅ Tick callback routing: `routeTickCallback` implemented with Tiger Style assertions
   - ✅ Integration: wired into `tahoe_app.zig` and `tahoe_window.zig`
   - ✅ Timer infrastructure: `TahoeTimerTarget` class created dynamically using Objective-C runtime API
   - ✅ Timer method implementation: `tahoeTimerTick:` method implemented using `class_addMethod` to call `routeTickCallback`
   - Timer-based update loop: `NSTimer` at 60fps (1/60 seconds interval)
   - Continuous redraw: call `tick()` on timer interval
   - Window resize handling: update buffer or scale rendering on resize
   - Event-driven updates: redraw on input events, window changes
   - Files: `src/tahoe_app.zig`, `src/tahoe_window.zig`, `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`

3. **Window Resizing (macOS Tahoe)** 🔥 **HIGH PRIORITY** ✅ **COMPLETE**
   - ✅ Implemented `windowDidResize:` delegate method via `TahoeWindowDelegate` class (created dynamically)
   - ✅ Resize events route to Zig `routeWindowDidResize` function
   - ✅ Window dimensions updated on resize (buffer remains static 1024x768)
   - ✅ NSImageView automatically scales image to fit window size
   - ✅ Tiger Style assertions for pointer validation and dimension bounds checking
   - Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`

4. **Text Rendering Integration (macOS Tahoe)** ⭐ **MEDIUM PRIORITY**
   - Integrate existing `TextRenderer` into `tahoe_window.zig`
   - Render text to RGBA buffer: fonts, basic layout, word wrapping
   - Text input handling: keyboard → text buffer → render
   - Cursor rendering: show text cursor position
   - Files: `src/tahoe_window.zig`, `src/aurora_text_renderer.zig`

5. **NSApplication Delegate (macOS Tahoe)** ⭐ **MEDIUM PRIORITY**
   - Implement `NSApplicationDelegate` protocol methods
   - Handle `applicationShouldTerminate:` for clean shutdown
   - Window delegate: `windowWillClose:`, `windowDidResize:`, etc.
   - Menu bar integration: File, Edit, View menus
   - Files: `src/platform/macos_tahoe/window.zig` (new delegate class), `src/tahoe_app.zig`

6. **River Compositor Foundation (macOS Tahoe)** ⭐ **MEDIUM PRIORITY**
   - Multi-pane layout system: split windows horizontally/vertically
   - Window tiling logic: deterministic layout algorithms
   - Moonglow keybindings: `Cmd+Shift+H` (horizontal split), `Cmd+Shift+V` (vertical split)
   - Workspace support: multiple workspaces with window groups
   - Files: `src/tahoe_window.zig` (compositor logic), `src/platform/macos_tahoe/window.zig` (multi-window support)

### Phase 2: Core IDE Foundation

7. **Zig Language Server Protocol (LSP) Implementation** ⭐ **FUTURE PRIORITY**
   - Build snapshot-based LSP server using Matklad's cancellation-aware model
   - Start with rock-solid data model: source code store that evolves over time
   - Implement incremental analysis: only re-analyze what changed
   - Support cancellation: long-running analysis can be cancelled when user types
   - Reference: [Matklad's Zig LSP architecture](https://matklad.github.io/2023/05/06/zig-language-server-and-cancellation.html)
   - Files: `src/aurora_lsp/` (new module)

8. **Text Editor Core**
   - Multi-file editor with tab support
   - Syntax highlighting for Zig (semantic + lexical)
   - Cursor management: single cursor, multi-cursor support
   - Selection handling: word, line, block selection
   - Files: `src/aurora_editor/` (extend existing)

9. **Code Completion & Semantic Features**
   - LSP-based code completion (`textDocument/completion`)
   - Go to definition (`textDocument/definition`)
   - Find all references (`textDocument/references`)
   - Rename symbol (`textDocument/rename`)
   - Inlay hints: parameter names, types, comptime values
   - Files: `src/aurora_lsp/`, `src/aurora_editor/`

### Phase 3: Agentic Coding Integration

10. **Cursor CLI / Claude Code Integration**
   - Cursor CLI integration for AI-assisted coding
   - Claude Code API integration (alternative to Cursor)
   - Agent chat pane: similar to Cursor's Composer mode
   - Diff view for AI-generated code changes
   - Accept/reject workflow (`Cmd+Enter` / `Esc`)
   - Files: `src/aurora_agent/` (new module), `src/grainvault/` (API keys)

11. **Zig-Specific Agent Prompts**
   - Comptime-aware code generation
   - Error union handling suggestions
   - TigerStyle compliance checks
   - Memory safety analysis suggestions
   - Files: `src/aurora_agent/prompts.zig`

### Phase 4: Advanced IDE Features

12. **Terminal Integration (Vibe Coding)**
   - Integrated terminal: blur line between editor and terminal
   - Split panes: like tmux, but integrated
   - Command history: `Cmd+Up` to scroll
   - Zig REPL integration: type `zig` to enter REPL mode
   - Build output linking: errors link back to source
   - Reference: [Matklad's Vibe Coding](https://matklad.github.io/2025/08/31/vibe-coding-terminal-editor.html)

13. **Aurora UI Enhancements**
   - Complete Flux Darkroom color filter integration
   - Native macOS menu bar with `View ▸ Flux` toggle
   - Menu bar: `Aurora | File | Edit | Selection | View | Go | Run | Terminal | Window | Help`
   - Theme support: Dark/Light/One Dark Pro

14. **Missing IDE Features** (Matklad-inspired)
    - Read-only characters: show immutable vs mutable state
    - Extend selection: semantic-aware selection expansion
    - Code actions/assists: 💡 lightbulb for quick fixes
    - Breadcrumbs: show symbol hierarchy
    - Reference: [Matklad's Missing IDE Feature](https://matklad.github.io/2024/10/14/missing-ide-feature.html)

### Completed Work ✅

11. **Cocoa Bridge Implementation (done)**
    - Implemented actual NSApplication, NSWindow, NSView calls
    - Created `cocoa_bridge.zig` with typed `objc_msgSend` wrappers
    - Build succeeds: `zig build tahoe` compiles successfully
    - Executable runs: window shows, event loop implemented

12. **Experimental Randomized Fuzz Test 002 (done)**
    - Decoupled into `tests-experiments/002_macos.md` and `999_riscv.md`
    - Implemented buffer content validation (FNV-1a checksum)
    - Implemented memory leak detection (GeneralPurposeAllocator)
    - Added error path coverage test
    - Tests pass: validates platform abstraction boundaries

13. **Pre-VPS Launchpad (done)**
    - Scaffolded `src/kernel/` (`main.zig`, `syscall_table.zig`, `devx/abi.zig`)
    - Extended `grain conduct` with `make kernel-rv64`, `run kernel-rv64`, `report kernel-rv64`

### Deferred Work (Lower Priority)

14. **Kernel Toolkit (paused → Reoriented)**
    - **Previous**: QEMU, rsync, and gdb scripts staged for external hardware/VPS
    - **New Direction**: RISC-V virtualization layer within macOS Tahoe (see Phase 1, item 0)
    - **Rationale**: Enable kernel development directly within IDE without external dependencies
    - **Migration Path**: Existing QEMU scripts can inform virtualization layer architecture

15. **Grain Conductor & Pottery** (Future)
    - `zig build conduct` drives `grain conduct brew|link|manifest|edit|make|ai|contracts|mmt|cdn`
    - Pottery abstractions schedule CDN kilns, ledger mints, and AI copilots

16. **Grain Social Terminal** (Future)
    - Typed Zig arrays represent social data; fuzz 11 random `npub`s per run
    - TigerBank flows share encoders via `src/contracts.zig` and secrets via `src/grainvault.zig`

17. **Onboarding & Care**
    - See `docs/get-started.md` for beginner guide
    - Guard passwords, cover Cursor Ultra, GitHub/Gmail/iCloud onboarding, 2FA

18. **Poetry & Waterbending**
    - Lace ASCII bending art and Helen Atthowe quotes throughout code and docs

19. **Thread Weaver**
    - `tools/thread_slicer.zig` + `zig build thread` keep `docs/ray.md` mirrored as `docs/ray_160.md`

20. **Prompt Ledger**
    - `docs/prompts.md` holds descending `PROMPTS`; new entries append at index 0

21. **Timestamp Glow**
    - `src/ray.zig` keeps runtime timestamps validated by fuzz tests

22. **Archive Echoes**
    - Maintain the archive rotation (`prototype_oldest/`, `prototype_older/`, `prototype_old/`)

23. **Delta Checks**
    - Keep Ray, prompts, outputs, and tests aligned (`zig build test`, `zig build wrap-docs`)

[^readonly]: [Matklad, "Readonly Characters Are a Big Deal"](https://
matklad.github.io/2025/11/10/readonly-characters.html)
[^vibe-terminal]: [Matklad, "Vibe Coding Terminal Editor"](https://
matklad.github.io/2025/08/31/vibe-coding-terminal-editor.html)
[^vegan-tiger]: [Vegan Tiger — ethical streetwear inspiration](https://
www.instagram.com/vegan_tiger/)
[^river-overview]: [River compositor philosophy](https://github.com/
riverwm/river)
[^jepsen-tb]: [Jepsen, "TigerBeetle 0.16.11"](https://jepsen.io/analyses/
tigerbeetle-0.16.11)
[^dcroma]: [DeepComputing DC-ROMA RISC-V Mainboard](https://
deepcomputing.io/product/dc-roma-risc-v-mainboard/)
[^framework-mainboard]: [Framework Marketplace – DeepComputing RISC-
V Mainboard](https://frame.work/products/deep-computing-risc-v-mainboard)
[^framework-blog]: [Framework Blog: RISC-V Mainboard for Framework Laptop 
13](https://frame.work/blog/risc-v-mainboard-for-framework-laptop-13-is-
now-available)

























