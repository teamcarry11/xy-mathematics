# Grain Aurora GUI Plan — TigerStyle Execution

**Current Status**: Window rendering complete ✅, VM-GUI integration complete ✅, VM-syscall integration complete ✅, SBI integration complete ✅. Focus: Single-threaded safety-first efficiency architecture, SBI console integration.

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
- **RAM-Aware Configuration** ✅ **COMPLETE**:
  - ✅ VM memory size configurable via `VM_MEMORY_SIZE` constant (default 4MB, max recommended 64MB)
  - ✅ Development machine: MacBook Air M2 (24GB RAM) - plenty of headroom
  - ✅ Target hardware: Framework 13 RISC-V (8GB RAM) - conservative defaults
  - ✅ Rationale: 4MB safe for both machines, sufficient for early kernel development
  - ✅ Documentation: `docs/vm_memory_config.md` with detailed RAM considerations
  - ✅ Tiger Style: Explicit memory configuration, conservative defaults, RAM-aware design
- **Core VM Implementation** ✅ **COMPLETE**:
  - ✅ Pure Zig RISC-V64 emulator (`src/kernel_vm/vm.zig`): Register file (32 GP registers + PC), configurable static memory (default 4MB), instruction decoding (LUI, ADDI, ADD, SUB, SLT, LW, SW, BEQ, ECALL)
  - ✅ ELF kernel loader (`src/kernel_vm/loader.zig`): RISC-V64 ELF parsing, program header loading, kernel image loading
  - ✅ Serial output (`src/kernel_vm/serial.zig`): 64KB circular buffer for kernel printf/debug output (routes to SBI console)
  - ✅ VM-Syscall Integration: ECALL wired to Grain Basin kernel syscalls via callback handler ✅ **COMPLETE**
  - ✅ GUI Integration: VM pane rendering, kernel loading (Cmd+L), VM execution (Cmd+K), serial output display ✅ **COMPLETE**
  - ✅ Test suite (`src/kernel_vm/test.zig`): Comprehensive tests passing (VM init, register file, memory, instruction fetch, serial, ADD, SUB, SLT)
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
- **RISC-V SBI Integration** 🔥 **CRITICAL PRIORITY** 🎯 **NEW** ✅ **CORE COMPLETE**:
  - **Our Own Tiger Style SBI Wrapper**: Created `src/kernel_vm/sbi.zig` - minimal, Tiger Style compliant (inspired by CascadeOS/zig-sbi, MIT licensed)
  - **SBI Purpose**: Platform runtime services (timer, console, reset, IPI) - different from kernel syscalls
  - **Integration Complete**: SBI calls integrated into VM ECALL handler ✅
  - **ECALL Dispatch**: VM dispatches ECALL to SBI (function ID < 10) or kernel syscalls (function ID >= 10) ✅
  - **SBI Console**: SBI_CONSOLE_PUTCHAR implemented, routes to serial output ✅
  - **SBI Timer**: SBI_SET_TIMER ready for implementation (future)
  - **Single-Threaded Safety**: SBI layer is single-threaded, no locks, deterministic execution
  - **Reference**: See `docs/cascadeos_analysis.md`, `docs/credits.md` for comprehensive SBI analysis
- **Single-Threaded Safety-First Efficiency** 🔥 **ARCHITECTURE PRIORITY** 🎯 **NEW**:
  - **Architecture**: Hardware → SBI → Kernel → Userspace, all single-threaded
  - **Safety #1**: Comprehensive assertions, type safety, explicit error handling, static allocation
  - **Maximum Efficiency**: Direct function calls (no IPC), static allocation, comptime optimizations, cache-friendly
  - **Single-Threaded Benefits**: No locks, no race conditions, deterministic execution, no context switching overhead
  - **Zig Advantages**: Type safety, explicit allocation, comptime, error unions, single-threaded by default
  - **Reference**: See `docs/single_threaded_safety_efficiency.md` for comprehensive architecture design
- **Next Steps** (Implementation Priority - Sequential Order):
  - **005 Fuzz Test** ✅ **COMPLETE**: SBI + kernel syscall integration fuzz test implemented and passing
  - **Priority 1: Implement `unmap` Syscall** ✅ **COMPLETE**:
    - ✅ Validate region address (page-aligned, user space, VM memory bounds)
    - ✅ Return success/error appropriately
    - ✅ Comprehensive assertions (Tiger Style)
    - Location: `src/kernel/basin_kernel.zig` → `syscall_unmap`
  - **Priority 2: Expand ISA with Bitwise Operations** ✅ **COMPLETE**:
    - ✅ OR instruction (funct3=0b110): execute_or function + dispatch + test
    - ✅ AND instruction (funct3=0b111): execute_and function + dispatch + test
    - ✅ XOR instruction (funct3=0b100): execute_xor function + dispatch + test
    - ✅ Tests: Test 9-11 added for OR/AND/XOR
    - Current: 12 instructions (LUI, ADDI, ADD, SUB, SLT, OR, AND, XOR, LW, SW, BEQ, ECALL)
  - **Priority 3: Implement I/O Syscall Stubs** ✅ **COMPLETE**:
    - ✅ `open`: Validate path pointer/length, flags, return stub handle
    - ✅ `read`: Validate handle, buffer pointer/length, return stub bytes_read=0
    - ✅ `write`: Validate handle, data pointer/length, return stub bytes_written=0
    - ✅ `close`: Validate handle, return stub success
    - ✅ Comprehensive assertions (Tiger Style)
    - Location: `src/kernel/basin_kernel.zig` → syscall functions
  - **Next Phase: Complete Phase 1 & Expand Foundation** 🔥 **IN PROGRESS**:
    - **Priority 4: Complete Phase 1 - Implement `spawn` Syscall** ✅ **COMPLETE**:
      - ✅ Validate executable pointer/length (ELF header size minimum)
      - ✅ Validate args pointer/length (can be zero for no args)
      - ✅ Return stub process ID (1)
      - ✅ Comprehensive assertions (Tiger Style)
      - ✅ **Phase 1 Complete: 9/9 core syscalls implemented!**
      - Location: `src/kernel/basin_kernel.zig` → `syscall_spawn`
    - **Priority 5: Expand ISA - Shift Operations** ✅ **COMPLETE**:
      - ✅ SLL instruction (funct3=0b001): execute_sll function + dispatch + test
      - ✅ SRL instruction (funct3=0b101, funct7=0b0000000): execute_srl function + dispatch + test
      - ✅ SRA instruction (funct3=0b101, funct7=0b0100000): execute_sra function + dispatch + test
      - ✅ Tests: Test 12-14 added for SLL/SRL/SRA
      - ✅ **ISA Expanded: 15 total instructions!** (LUI, ADDI, ADD, SUB, SLT, OR, AND, XOR, SLL, SRL, SRA, LW, SW, BEQ, ECALL)
      - Location: `src/kernel_vm/vm.zig` → instruction dispatch + execute functions
    - **Priority 6: Implement Phase 2 Syscalls (Simpler Ones)** ✅ **COMPLETE**:
      - ✅ `protect`: Validate region address (page-aligned, user space), flags, return stub success
      - ✅ `wait`: Validate process ID, return stub exit status (0)
      - ✅ `clock_gettime`: Validate clock_id, timespec_ptr, return stub zero timestamp
      - ✅ `sysinfo`: Validate info_ptr, return stub success
      - ✅ `sleep_until`: Validate timestamp, return stub success
      - ✅ `channel_create`: Return stub channel ID (1)
      - ✅ `channel_send`: Validate channel ID, data pointer/length, return stub success
      - ✅ `channel_recv`: Validate channel ID, buffer pointer/length, return stub bytes_received=0
      - ✅ Comprehensive assertions (Tiger Style)
      - ✅ **Phase 2 Complete: 8/8 syscalls implemented!**
      - Location: `src/kernel/basin_kernel.zig` → syscall functions
    - **Foundation Implementation** ✅ **ALL PHASES COMPLETE** 🎉:
      - **Phase 3: Memory Management Foundation** ✅ **COMPLETE**:
        - ✅ Implemented mapping table (static array, max 256 entries)
        - ✅ Updated map/unmap/protect syscalls to use actual table
        - ✅ Track memory mappings (address, size, flags)
        - ✅ Validate no overlaps, proper allocation/deallocation
        - ✅ Simple allocator for kernel-chosen addresses (next_alloc_addr)
        - ✅ Comprehensive assertions (Tiger Style)
        - ✅ Zero compiler warnings, all tests passing
        - Location: `src/kernel/basin_kernel.zig` → `MemoryMapping` struct, `mappings` table
      - **Phase 4: File System Foundation** ✅ **COMPLETE**:
        - ✅ Implemented handle table (static array, max 64 entries)
        - ✅ Updated open/read/write/close syscalls to use actual table
        - ✅ In-memory file system (no disk yet)
        - ✅ Track file handles (path, flags, position, buffer)
        - ✅ Simple allocator for handle IDs (next_handle_id, 1-based)
        - ✅ Comprehensive assertions (Tiger Style)
        - ✅ Zero compiler warnings, all tests passing
        - Location: `src/kernel/basin_kernel.zig` → `FileHandle` struct, `handles` table
      - **Phase 5: Process Management Foundation** ✅ **COMPLETE**:
        - ✅ Implemented process table (static array, max 16 entries)
        - ✅ Updated spawn/wait syscalls to use actual table
        - ✅ Track processes (ID, executable, entry point, state, exit status)
        - ✅ Simple allocator for process IDs (next_process_id, 1-based)
        - ✅ Comprehensive assertions (Tiger Style)
        - ✅ Zero compiler warnings, all tests passing
        - Location: `src/kernel/basin_kernel.zig` → `ProcessEntry` struct, `processes` table
      - **Phase 6: IPC Foundation** ✅ **COMPLETE**:
        - ✅ Implemented channel table (static array, max 32 entries)
        - ✅ Updated channel_create/send/recv syscalls to use actual table
        - ✅ Message queues (circular buffers, max 32 messages, 64KB per message)
        - ✅ Simple allocator for channel IDs (next_channel_id, 1-based)
        - ✅ Comprehensive assertions (Tiger Style)
        - ✅ Zero compiler warnings, all tests passing
        - Location: `src/kernel/basin_kernel.zig` → `ChannelEntry` struct, `channels` table, `MessageQueue` struct
      - **Phase 7: Timer Integration** ✅ **COMPLETE**:
        - ✅ Implemented timer state tracking (system_time_ns)
        - ✅ Updated clock_gettime syscall to use timer state
        - ✅ Updated sleep_until syscall to use timer state
        - ✅ Comprehensive assertions (Tiger Style)
        - ✅ Zero compiler warnings, all tests passing
        - Location: `src/kernel/basin_kernel.zig` → `system_time_ns` field
      - **Foundation Summary**: All 5 foundation phases complete (Phase 3-7) ✅
        - **Total Syscalls**: 17/17 implemented with actual table-based operations
        - **Total Tables**: 4 static tables (mappings, handles, processes, channels)
        - **Total Instructions**: 15 RISC-V instructions implemented
        - **Total Tests**: 005 fuzz (6 categories), 006 fuzz (7 categories), VM tests (14 tests)
        - **Status**: Kernel foundation complete, ready for further development
    - **Next Phase: Testing & Enhancement** 🔥 **IN PROGRESS** 🎯 **CURRENT PRIORITY**:
      - **007 Fuzz Test: File System Foundation** 🔥 **HIGH PRIORITY**:
        - Create randomized fuzz test for open/read/write/close operations
        - Test handle table operations, edge cases, state consistency
        - Follow same pattern as 006 fuzz test
        - **Location**: `tests/007_fuzz.zig` → file system fuzz testing
      - **008 Fuzz Test: Process Management Foundation** 🔥 **MEDIUM PRIORITY**:
        - Create randomized fuzz test for spawn/wait operations
        - Test process table operations, edge cases, state consistency
        - **Location**: `tests/008_fuzz.zig` → process management fuzz testing
      - **009 Fuzz Test: IPC Foundation** 🔥 **MEDIUM PRIORITY**:
        - Create randomized fuzz test for channel_create/send/recv operations
        - Test channel table operations, message queues, edge cases
        - **Location**: `tests/009_fuzz.zig` → IPC fuzz testing
      - **010 Fuzz Test: Timer Integration** 🔥 **MEDIUM PRIORITY**:
        - Create randomized fuzz test for clock_gettime/sleep_until operations
        - Test timer state tracking, time conversions, edge cases
        - **Location**: `tests/010_fuzz.zig` → timer fuzz testing
    - **Future Enhancements** 🔥 **NEXT PRIORITY**:
      - **ISA Expansion**: Additional RISC-V instructions (MUL, DIV, etc.)
      - **ELF Loader**: Parse ELF headers for process spawning
      - **SBI Timer Integration**: Real hardware timer support
      - **Debug Interface**: Register viewer, memory inspector, GDB stub
      - **Reference**: `docs/next_implementation_phases.md` for detailed phase plans
  - **Single-Threaded Architecture**: ✅ All layers single-threaded, no locks, deterministic
  - **Safety-First Patterns**: ✅ Comprehensive assertions, type-safe interfaces, explicit error handling, static allocation
  - **RAM-Aware Configuration**: ✅ VM memory configurable (4MB default, 64MB max), documented
  - **Debug Interface**: Register viewer, memory inspector, GDB stub (future)
- **Comprehensive Assertions** ✅ **COMPLETE**:
  - ✅ VM SBI handling: Pointer validation, EID bounds, state transitions, serial output validation
  - ✅ VM ECALL dispatch: VM state validation, dispatch logic, handler pointer validation, result validation
  - ✅ Kernel syscall handling: Self pointer validation, syscall number bounds, enum validation, parameter validation
  - ✅ Serial output: Pointer validation, buffer bounds, circular buffer wrapping, position advancement
  - ✅ GUI integration: VM initialization validation, handler setup validation, state consistency
- **005 Fuzz Test Plan** ✅ **DOCUMENTED**:
  - ✅ SBI call fuzzing: Random EIDs, arguments, edge cases
  - ✅ Kernel syscall fuzzing: Random syscalls, arguments, error handling
  - ✅ ECALL dispatch fuzzing: Boundary values, correct routing
  - ✅ Serial output fuzzing: Character sequences, buffer management
  - ✅ State transition fuzzing: VM state, kernel state
  - ✅ Combined execution fuzzing: Mixed SBI + kernel calls
  - Reference: See `tests-experiments/005_fuzz.md` for comprehensive fuzz test plan
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
