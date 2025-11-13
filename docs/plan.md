# Grain Aurora GUI Plan — TigerStyle Execution

**Current Status**: Window rendering complete ✅, VM-GUI integration complete ✅, VM-syscall integration complete ✅. Focus: RISC-V SBI integration (CascadeOS/zig-sbi).

## macOS Tahoe GUI Foundation (Current Priority) 🎯

### 0. RISC-V Kernel Virtualization Layer 🔥 **HIGH PRIORITY** 🎯 **NEW** ✅ **CORE COMPLETE**
- **Vision**: Run Zig monolith kernel in virtualized RISC-V environment within macOS Tahoe IDE
- **Kernel Name**: **Grain Basin kernel** 🏞️ - "The foundation that holds everything"
- **Homebrew Bundle**: `grainbasin` (Brew package name)
- **Why**: Enable kernel development and testing without physical RISC-V hardware or external QEMU
- **RISC-V-First Development Strategy**:
  - **Primary Goal**: Develop RISC-V-targeted Zig code in macOS Tahoe VM, deploy to Framework 13 DeepComputing RISC-V mainboard with confidence
  - **VM-Hardware Parity**: Pure Zig emulator matches Framework 13 RISC-V mainboard behavior (RISC-V64 ISA, memory model, register semantics)
  - **Development Workflow**: Write RISC-V Zig code → Test in macOS Tahoe VM → Deploy to Framework 13 RISC-V hardware (no code changes needed)
  - **Compatibility Guarantee**: VM instruction semantics, memory layout, and register behavior match real RISC-V hardware exactly
- **Core VM Implementation** ✅ **COMPLETE**:
  - ✅ Pure Zig RISC-V64 emulator (`src/kernel_vm/vm.zig`): Register file (32 GP registers + PC), 4MB static memory, instruction decoding (LUI, ADDI, LW, SW, BEQ, ECALL)
  - ✅ ELF kernel loader (`src/kernel_vm/loader.zig`): RISC-V64 ELF parsing, program header loading, kernel image loading
  - ✅ Serial output (`src/kernel_vm/serial.zig`): 64KB circular buffer for kernel printf/debug output (will be replaced with SBI console)
  - ✅ VM-Syscall Integration: ECALL wired to Grain Basin kernel syscalls via callback handler ✅ **COMPLETE**
  - ✅ GUI Integration: VM pane rendering, kernel loading (Cmd+L), VM execution (Cmd+K), serial output display ✅ **COMPLETE**
  - ✅ Test suite (`src/kernel_vm/test.zig`): Comprehensive tests passing (VM init, register file, memory, instruction fetch, serial)
  - ✅ Build integration: `zig build kernel-vm-test` command
- **External Reference Repos** (Study, Don't Copy):
  - **CascadeOS/zig-sbi**: RISC-V SBI wrapper (CRITICAL - integrate into VM)
  - **CascadeOS/CascadeOS**: General-purpose Zig OS (RISC-V64 planned) - study RISC-V patterns
  - **ZystemOS/pluto**: Component-based Zig kernel (x86) - study Zig patterns
  - **Clone Location**: `~/github/{username}/{repo}/` (external to xy workspace)
  - **Reference**: See `docs/cascadeos_analysis.md`, `docs/pluto_analysis.md`, `docs/aero_analysis.md`
- **Grain Basin kernel Foundation** ✅ **COMPLETE**:
  - ✅ Kernel name: Grain Basin kernel 🏞️ - "The foundation that holds everything"
  - ✅ Homebrew bundle: `grainbasin` (Brew package name)
  - ✅ Syscall interface (`src/kernel/basin_kernel.zig`): All 17 core syscalls defined
  - ✅ Architecture: Type-safe monolithic kernel (performance priority, not microkernel)
  - ✅ Type-safe abstractions: `Handle` (not integer FDs), `MapFlags`, `OpenFlags`, `ClockId`, `SysInfo`, `BasinError`, `SyscallResult`
  - ✅ VM-Syscall Integration: ECALL wired to Grain Basin kernel syscalls ✅ **COMPLETE**
  - ✅ Build integration: `basin_kernel_module` added to `build.zig`
  - ✅ Tiger Style: All function names converted to snake_case ✅ **COMPLETE**
- **RISC-V SBI Integration** 🔥 **CRITICAL PRIORITY** 🎯 **NEW**:
  - **CascadeOS/zig-sbi**: Zig wrapper for RISC-V SBI (Supervisor Binary Interface)
  - **SBI Purpose**: Platform runtime services (timer, console, reset, IPI) - different from kernel syscalls
  - **Integration Steps**:
    1. Add CascadeOS/zig-sbi dependency to `build.zig.zon`
    2. Integrate SBI calls into VM ECALL handler (function ID < 10 → SBI, >= 10 → kernel)
    3. Replace serial output with SBI_CONSOLE_PUTCHAR (standard RISC-V approach)
    4. Add SBI timer support (SBI_SET_TIMER for kernel timers)
  - **Reference**: See `docs/cascadeos_analysis.md` for comprehensive SBI analysis
- **Next Steps** (Implementation Priority):
  - **SBI Integration**: Add CascadeOS/zig-sbi dependency, integrate SBI calls into VM ECALL handler
  - **SBI Console**: Replace serial output with SBI_CONSOLE_PUTCHAR, display in GUI VM pane
  - **Grain Basin kernel Syscall Implementation**: Implement syscall handlers incrementally (start with `exit`, `yield`, `map`)
  - **VM-Syscall Integration**: Wire Grain Basin kernel syscalls into RISC-V VM (handle ECALL → Basin syscall) ✅ **COMPLETE**
  - **SBI vs Kernel Syscalls**: SBI handles platform services (timer, console, reset) via ECALL function ID < 10, kernel syscalls handle kernel services (process, memory, I/O) via ECALL function ID >= 10
  - **Expanded ISA Support**: Add more RISC-V instructions (ADD, SUB, SLT, etc.)
  - **Debug Interface**: Register viewer, memory inspector, GDB stub (future)
- **Tiger Style Requirements**:
  - Static allocation for VM state structures where possible ✅
  - Comprehensive assertions for memory access, instruction decoding ✅
  - Deterministic execution: Same kernel state → same output ✅
  - No hidden state: All VM state explicitly tracked ✅
- Files: `src/kernel_vm/` (core complete), `src/kernel/basin_kernel.zig` (syscall interface complete), `src/tahoe_window.zig` (VM pane integration complete)
- Hardware Target: Framework 13 DeepComputing RISC-V Mainboard (RISC-V64, matches VM behavior)
- Development Environment: macOS Tahoe IDE with RISC-V VM (matches hardware behavior exactly)
- SBI Integration: Use CascadeOS/zig-sbi for platform services (timer, console, reset) - standard RISC-V approach

### 1. Input Handling 🔥 **IMMEDIATE PRIORITY** ✅ **COMPLETE**
- ✅ Created `TahoeView` class dynamically (extends NSView, handles events)
- ✅ Mouse events: `mouseDown:`, `mouseUp:`, `mouseDragged:`, `mouseMoved:` implemented
- ✅ Keyboard events: `keyDown:`, `keyUp:` implemented with key code, character, modifiers
- ✅ Window focus events: `windowDidBecomeKey:`, `windowDidResignKey:` implemented
- ✅ Event routing: Cocoa → C routing functions → Zig event handlers
- ✅ Tiger Style: Comprehensive assertions, pointer validation, bounds checking
- ✅ Static allocation: Minimal dynamic allocation, static class names
- ✅ View hierarchy: TahoeView (events) → NSImageView (rendering)
- ✅ Code quality: Comments explain "why", functions <70 lines, <100 columns (grainwrap/grainvalidate)
- Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`, `src/platform/events.zig`

### 2. Animation/Update Loop 🔥 **HIGH PRIORITY** ✅ **COMPLETE**
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

### 3. Window Resizing 🔥 **HIGH PRIORITY** ✅ **COMPLETE**
- ✅ Implemented `windowDidResize:` delegate method via `TahoeWindowDelegate` class (created dynamically)
- ✅ Resize events route to Zig `routeWindowDidResize` function
- ✅ Window dimensions updated on resize (buffer remains static 1024x768)
- ✅ NSImageView automatically scales image to fit window size
- ✅ Tiger Style assertions for pointer validation and dimension bounds checking
- Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`

### 4. Text Rendering Integration ⭐ **MEDIUM PRIORITY**
- Integrate existing `TextRenderer` into `tahoe_window.zig`
- Render text to RGBA buffer: fonts, basic layout, word wrapping
- Text input handling: keyboard → text buffer → render
- Cursor rendering: show text cursor position
- Files: `src/tahoe_window.zig`, `src/aurora_text_renderer.zig`

### 5. NSApplication Delegate ⭐ **MEDIUM PRIORITY**
- Implement `NSApplicationDelegate` protocol methods
- Handle `applicationShouldTerminate:` for clean shutdown
- Window delegate: `windowWillClose:`, `windowDidResize:`, etc.
- Menu bar integration: File, Edit, View menus
- Files: `src/platform/macos_tahoe/window.zig` (new delegate class), `src/tahoe_app.zig`

### 6. River Compositor Foundation ⭐ **MEDIUM PRIORITY**
- Multi-pane layout system: split windows horizontally/vertically
- Window tiling logic: deterministic layout algorithms
- Moonglow keybindings: `Cmd+Shift+H` (horizontal split), `Cmd+Shift+V` (vertical split)
- Workspace support: multiple workspaces with window groups
- Files: `src/tahoe_window.zig` (compositor logic), `src/platform/macos_tahoe/window.zig` (multi-window support)

## Tiger Style Code Quality Standards 🐅

**Enforcement**: All code must follow Tiger Style principles:
- **Comments**: Explain "why" not "what" (Tiger Style principle)
- **Assertions**: Comprehensive pointer validation, bounds checking, enum validation
- **Static Allocation**: Prefer static allocation over dynamic (maximal static allocation)
- **Function Length**: <70 lines per function (grainvalidate requirement)
- **Column Width**: <100 columns per line (Tiger Style, grainwrap for docs at 73)
- **Memory Safety**: Explicit pointer validation, alignment checks, suspicious address detection
- **Determinism**: Single-threaded, deterministic behavior, no hidden state

**Validation Tools**:
- `grainwrap`: Enforces 73-column limit for documentation
- `grainvalidate`: Enforces function length limits and naming conventions
- Manual review: Assertion coverage, static allocation usage, comment quality

## Completed Work ✅

### macOS Tahoe Input Handling ✅ **COMPLETE**
- Created `TahoeView` class dynamically using Objective-C runtime API (extends NSView)
- Implemented mouse event methods: `mouseDown:`, `mouseUp:`, `mouseDragged:`, `mouseMoved:`
- Implemented keyboard event methods: `keyDown:`, `keyUp:` with key code, character, modifiers
- Implemented `acceptsFirstResponder` method (returns YES for keyboard events)
- Added window delegate methods: `windowDidBecomeKey:`, `windowDidResignKey:`
- Event routing: Cocoa events → C routing functions → Zig event handlers
- Tiger Style: Comprehensive assertions, pointer validation, bounds checking
- Static allocation: Minimal dynamic allocation, static class names, associated objects
- View hierarchy: TahoeView (content view, handles events) → NSImageView (subview, renders images)
- Code quality: Comments explain "why" not "what", functions <70 lines, <100 columns
- Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`, `src/platform/events.zig`

### macOS Tahoe Window Resizing ✅ **COMPLETE**
- Implemented `windowDidResize:` delegate method via `TahoeWindowDelegate` class (created dynamically using Objective-C runtime API)
- Resize events route to Zig `routeWindowDidResize` function with Tiger Style assertions
- Window dimensions updated on resize (buffer remains static 1024x768 for now)
- NSImageView automatically scales image to fit window size (proportional scaling)
- Delegate set up automatically when window is created
- Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`

### macOS Tahoe Animation/Update Loop ✅ **COMPLETE**
- Platform VTable: `startAnimationLoop`, `stopAnimationLoop` methods added
- Window struct: `animation_timer`, `tick_callback`, `tick_user_data` fields added
- Tick callback routing: `routeTickCallback` implemented with Tiger Style assertions
- Integration: wired into `tahoe_app.zig` and `tahoe_window.zig`
- Timer infrastructure: `TahoeTimerTarget` class created dynamically using Objective-C runtime API
- Timer method implementation: `tahoeTimerTick:` method implemented using `class_addMethod` to call `routeTickCallback`
- NSTimer at 60fps (1/60 seconds interval) calls `tick()` continuously
- Files: `src/tahoe_app.zig`, `src/tahoe_window.zig`, `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`

### macOS Tahoe Window Rendering ✅ **COMPLETE**
- Rewrote `window.zig` from scratch to fix parser errors
- Fixed NSImage creation: use NSBitmapImageRep + NSImage instead of non-existent `imageWithCGImage:size:`
- Fixed struct return handling: added `objc_msgSend_returns_NSRect` for methods returning NSRect by value
- Switched to NSImageView: replaced manual drawing with `NSImageView.setImage:` for reliable rendering
- Window successfully displays 1024x768 RGBA buffer (dark blue-gray background with white rectangle)
- All compilation errors resolved, application runs successfully
- Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`, `src/platform/macos_tahoe/cocoa_bridge.zig`

### Cocoa Bridge Implementation ✅
- Implemented actual NSApplication, NSWindow, NSView calls
- Created `cocoa_bridge.zig` with typed `objc_msgSend` wrappers
- Build succeeds: `zig build tahoe` compiles successfully
- Executable runs: window shows, event loop implemented

### Experimental Randomized Fuzz Test 002 ✅
- Decoupled into `tests-experiments/002_macos.md` and `999_riscv.md`
- Implemented buffer content validation (FNV-1a checksum)
- Implemented memory leak detection (GeneralPurposeAllocator)
- Added error path coverage test
- Tests pass: validates platform abstraction boundaries

### Pre-VPS Launchpad ✅
- Scaffolded `src/kernel/` (`main.zig`, `syscall_table.zig`, `devx/abi.zig`)
- Extended `grain conduct` with `make kernel-rv64`, `run kernel-rv64`, `report kernel-rv64`

## Deferred Work (Lower Priority)

### Kernel Toolkit (paused)
- QEMU + rsync scripts are staged
- Resume once Framework 13 RISC-V board or VPS is available
- Focus on macOS Tahoe Aurora IDE work for now

### Grain Conductor & Pottery (future)
- Extend `grain conduct` (`brew|link|manifest|edit|make|ai|contracts|mmt|cdn`)
- Model Grain Pottery scheduling for CDN kilns, ledger mints, and AI copilots

### Grain Social Terminal (future)
- Keep social data typed in Zig, fuzz 11 `npub`s per run
- Share settlement encoders in `src/contracts.zig`; store secrets via `src/grainvault.zig`

### Onboarding & Care
- See `docs/get-started.md` for beginner guide
- Maintain onboarding scripts (Cursor Ultra, GitHub/Gmail/iCloud, 2FA, Ghostty setup)

### Poetry & Waterbending
- Thread ASCII bending art and Helen Atthowe quotes through docs/code

### Thread Weaver
- Regenerate `docs/ray_160.md` via `zig build thread`; enforce 160-character blocks

### Prompt Ledger
- Keep `docs/prompts.md` descending; append at index 0

### Timestamp Glow
- Maintain `src/ray.zig` timestamp grammar and fuzz coverage (`tests-experiments/000.md`)

### Archive Echoes
- Rotate `prototype_old/`, `prototype_older/`, and `prototype_oldest/`

### Delta Checks
- Run `zig build wrap-docs`, `zig build test`, and keep docs in sync

[^dcroma]: [DeepComputing DC-ROMA RISC-V Mainboard](https://deepcomputing.io/product/dc-roma-risc-v-mainboard/)
[^framework-mainboard]: [Framework Marketplace – DeepComputing RISC-V Mainboard](https://frame.work/products/deep-computing-risc-v-mainboard)
[^framework-blog]: [Framework Blog: RISC-V Mainboard for Framework Laptop 13](https://frame.work/blog/risc-v-mainboard-for-framework-laptop-13-is-now-available)
