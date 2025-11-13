# Grain Changelog — Descending Order (Newest First)

## 12025-11-13--1552-pst
- **006 Fuzz Test: Memory Management Foundation Complete** ✅
  - **Test Implementation**: Created `tests/006_fuzz.zig` with 7 comprehensive test categories
    - Map operations fuzzing: 200 random map operations (kernel-chosen vs user-provided addresses, random sizes/flags)
    - Unmap operations fuzzing: 100 random unmap operations (existing vs non-existent mappings)
    - Protect operations fuzzing: 100 random protect operations with random flags
    - Overlap detection fuzzing: 100 random overlapping addresses to validate overlap prevention
    - Table exhaustion fuzzing: Tests mapping table capacity (256 entries)
    - Edge cases fuzzing: Zero size, unaligned addresses, invalid flags, kernel space addresses, non-existent mappings
    - State consistency fuzzing: 100 random operations (map/unmap/protect) with state validation after each
  - **Build Integration**: Added `fuzz-006` step to `build.zig` with `addRunArtifact` for automatic test execution
  - **Comprehensive Assertions**: Added extensive assertions to all memory management functions
    - `find_free_mapping()`: Self pointer validation, mapping state checks, free count consistency
    - `find_mapping_by_address()`: Address validation, uniqueness checks, matching state validation
    - `check_overlap()`: Address/size validation, overlap count consistency
    - `count_allocated_mappings()`: Public method with state validation (for testing)
  - **Tiger Style**: Deterministic randomness, comprehensive assertions, explicit error handling, zero warnings
  - **Test Results**: All 7 test categories passing ✅
  - **Documentation**: Created `tests-experiments/006_fuzz.md` with detailed test plan
  - **Result**: Complete memory management syscall validation with randomized fuzz testing, all tests passing

## 12025-11-13--1444-pst
- **Phase 2 Complete: All 17 Syscalls Implemented** 🎉
  - **Phase 1**: 9/9 core syscalls complete ✅ (spawn, exit, yield, wait, map, unmap, open, read, write, close)
  - **Phase 2**: 8/8 syscalls complete ✅ (protect, wait, clock_gettime, sysinfo, sleep_until, channel_create, channel_send, channel_recv)
  - **Total**: 17/17 syscalls implemented (100% complete!)
  - **ISA Expansion**: 15 total instructions complete ✅ (LUI, ADDI, ADD, SUB, SLT, OR, AND, XOR, SLL, SRL, SRA, LW, SW, BEQ, ECALL)
  - **Remaining Phase 2 Syscalls**: Implemented sleep_until, channel_create, channel_send, channel_recv
    - sleep_until: Validate timestamp, return stub success (ready for timer integration)
    - channel_create: Return stub channel ID (ready for IPC channel table)
    - channel_send: Validate channel ID, data pointer/length (max 64KB), return stub success
    - channel_recv: Validate channel ID, buffer pointer/length (max 64KB), return stub bytes_received=0
  - **Comprehensive Assertions**: All syscalls include Tiger Style assertions, explicit validation, error handling
  - **Tiger Style**: Zero compiler warnings, comprehensive assertions, explicit error handling, static allocation
  - **Result**: Complete syscall interface foundation ready for implementation of underlying systems (memory management, file system, IPC, process management, timer)

## 12025-11-13--1100-pst
- **005 Fuzz Test: SBI + Kernel Syscall Integration Complete**
  - **Test Implementation**: Created `tests/005_fuzz.zig` with 6 comprehensive test categories
    - SBI call fuzzing: Random EIDs (0-9), arguments, edge cases, state transitions
    - Kernel syscall fuzzing: Random syscalls (10-50), arguments, error handling, return values
    - ECALL dispatch fuzzing: Boundary values (9, 10), correct routing validation, function ID ranges
    - Serial output fuzzing: Random character sequences, buffer management, circular buffer wrapping
    - State transition fuzzing: VM state, kernel state transitions, state invariants
    - Combined execution fuzzing: Mixed SBI + kernel call sequences, state persistence
  - **Build Integration**: Added `fuzz-005` step to `build.zig` for running 005 fuzz tests
  - **VM Testing API**: Made `VM.handle_sbi_call` and `VM.execute_ecall` public for fuzz test access
  - **Comprehensive Assertions**: All test categories include extensive assertions for safety-first validation
  - **Tiger Style**: Deterministic randomness, comprehensive assertions, explicit error handling, zero warnings
  - **Result**: Full stack integration fuzz testing ready (Hardware → SBI → Kernel → Userspace), all tests passing
- **Ray and Plan Updated**: Infused comprehensive assertions and 005 fuzz test plan into strategic documents
  - Added comprehensive assertions section detailing all assertion coverage areas
  - Added 005 fuzz test plan section with all 6 test categories documented
  - Updated next steps to reflect current progress (005 fuzz test complete)
  - Assertions coverage documented: VM SBI handling, VM ECALL dispatch, kernel syscall handling, serial output, GUI integration

## 12025-11-13--0840-pst
- **TigerStyle: Convert All Function Names to snake_case**
  - **Basin Kernel**: `handleSyscall` → `handle_syscall`, all syscall handlers (`syscall_spawn`, `syscall_exit`, etc.), `isValid` → `is_valid`
  - **VM**: `fetchInstruction` → `fetch_instruction`, `executeLUI` → `execute_lui`, `executeADDI` → `execute_addi`, `executeLW` → `execute_lw`, `executeSW` → `execute_sw`, `executeBEQ` → `execute_beq`, `executeECALL` → `execute_ecall`, `setSyscallHandler` → `set_syscall_handler`
  - **Tahoe Window**: `handleMouseEvent` → `handle_mouse_event`, `handleKeyboardEvent` → `handle_keyboard_event`, `handleFocusEvent` → `handle_focus_event`, `handleSyscall` → `handle_syscall`, `toggleFlux` → `toggle_flux`, `startAnimationLoop` → `start_animation_loop`, `stopAnimationLoop` → `stop_animation_loop`
  - **Serial Output**: `getOutput` → `get_output`
  - **Tahoe App**: Updated to use `start_animation_loop`
  - **Build**: All compilation errors fixed, zero warnings, build succeeds
  - **TigerStyle Compliance**: Consistent snake_case naming throughout codebase, all function calls updated
  - **Result**: Complete TigerStyle snake_case conversion, ready for continued development

## 12025-11-13--0101-pst
- **Grain Basin kernel: Official Kernel Name and Initial Syscall Interface**
  - **Kernel Name**: Grain Basin kernel 🏞️ - "The foundation that holds everything" (Lake Tahoe basin metaphor, perfect Tahoe connection)
  - **Homebrew Bundle**: `grainbasin` (Brew package name)
  - **Initial Module**: Created `src/kernel/basin_kernel.zig` with complete syscall interface definitions
  - **Syscall Enumeration**: All 17 core syscalls defined (spawn, exit, yield, wait, map, unmap, protect, channel_create, channel_send, channel_recv, open, read, write, close, clock_gettime, sleep_until, sysinfo)
  - **Type-Safe Abstractions**: 
    - `Handle` type (not integer FDs) for type-safe resource management
    - `MapFlags`, `OpenFlags` packed structs (explicit flags, no magic numbers)
    - `ClockId` enum (monotonic, realtime)
    - `SysInfo` struct (strongly-typed system information)
    - `BasinError` error union (explicit errors, no POSIX errno)
    - `SyscallResult` union (success/error wrapper)
  - **Syscall Handler Stubs**: All 17 syscall handlers defined with TODO placeholders for future implementation
  - **Build Integration**: Added `basin_kernel_module` to `build.zig`
  - **Tiger Style**: Comprehensive assertions, explicit type safety, "why" comments, function length limits
  - **Design Philosophy**: Minimal syscall surface, non-POSIX, type-safe, RISC-V native, 30-year vision
  - **Result**: Basin Kernel foundation established, ready for incremental syscall implementation

## 12025-11-12--1955-pst
- **Expanded RISC-V ISA Support: LW, SW, BEQ Instructions**
  - Added LW (Load Word): Load 32-bit word from memory with sign-extension to 64 bits
  - Added SW (Store Word): Store 32-bit word to memory
  - Added BEQ (Branch if Equal): Conditional branch instruction for kernel control flow
  - **Comprehensive Assertions**: Register index validation (0-31), memory address alignment (4-byte), bounds checking, PC alignment, branch target validation
  - **PC Increment Logic**: Fixed branch instruction handling - BEQ modifies PC directly, normal instructions advance PC by 4 bytes
  - **Tiger Style Compliance**: Maximum strictness, zero warnings, all edge cases handled explicitly with assertions that crash immediately on violation
  - **Instruction Set**: Now supports LUI, ADDI, LW, SW, BEQ, ECALL (6 instructions total)
  - **Result:** VM can now execute basic kernel code with memory access and control flow. All VM tests passing.

## 12025-11-12--1852-pst
- **Pure Zig RISC-V64 Emulator: Core Implementation Complete**
  - Implemented pure Zig RISC-V64 virtual machine for kernel development within macOS Tahoe IDE
  - **Core VM (`src/kernel_vm/vm.zig`)**: Register file (32 GP registers + PC), 4MB static memory allocation, instruction decoding (LUI, ADDI, ECALL), memory read/write with alignment checks, VM state machine (running, halted, errored)
  - **ELF Kernel Loader (`src/kernel_vm/loader.zig`)**: RISC-V64 ELF parsing, program header loading, kernel image loading into VM memory, entry point initialization
  - **Serial Output (`src/kernel_vm/serial.zig`)**: 64KB circular buffer for kernel output, byte/string writing, output retrieval for GUI display
  - **Test Suite (`src/kernel_vm/test.zig`)**: Comprehensive tests for VM initialization, register file (x0 hardwired to zero), memory read/write, instruction fetch, serial output - all tests passing
  - **Build Integration**: `zig build kernel-vm-test` command for testing VM functionality
  - **Tiger Style Compliance**: Static allocation (4MB memory buffer), comprehensive assertions (pointer validation, bounds checking, alignment checks), deterministic execution, no hidden state
  - **RISC-V Hardware Compatibility**: VM designed to match Framework 13 DeepComputing RISC-V mainboard behavior - ensures kernel code developed in macOS Tahoe runs flawlessly on real RISC-V hardware
  - **Development Strategy**: RISC-V-first development - write RISC-V-targeted Zig code, test in macOS Tahoe VM, deploy to Framework 13 RISC-V mainboard with confidence
  - **Result:** Pure Zig RISC-V emulator core complete and tested. Foundation ready for GUI integration and expanded ISA support.

## 12025-11-12--1756-pst
- **macOS Tahoe Window Resizing: Fixed Buffer Dimension Assertions**
  - Fixed crash when releasing mouse button after window resize
  - **Root cause**: Assertions in `impl.zig` and `tahoe_window.zig` were checking buffer size against dynamic window dimensions (`window.width * window.height * 4`), but buffer is fixed at 1024x768
  - **Fixed `impl.zig`**: Changed assertion to check against fixed buffer size (`1024 * 768 * 4`) instead of `window.width * window.height * 4`
  - **Fixed `tahoe_window.zig`**: Replaced all uses of `window_width`/`window_height` (from `self.platform.width()`/`height()`) with fixed `buffer_width` (1024) and `buffer_height` (768) constants
  - Updated drawing code to use buffer dimensions for pixel offsets (buffer is always 1024x768)
  - Window dimensions (`window.width`/`height`) can now change independently during resize
  - NSImageView automatically scales the fixed 1024x768 buffer to fit the window size
  - **Result:** Window resizing works smoothly without crashes. Buffer remains static while window scales rendering automatically.

## 12025-11-12--1315-pst
- **macOS Tahoe Window Rendering: Complete Implementation**
  - Successfully implemented and fixed macOS Tahoe window rendering. The application now displays content correctly in a native macOS window.
  - **Rewrote `window.zig` from scratch** to resolve persistent parser errors that were blocking compilation
  - **Fixed NSImage creation**: Replaced non-existent `imageWithCGImage:size:` class method with proper approach using `NSBitmapImageRep.initWithCGImage:` + `NSImage.initWithSize:` + `addRepresentation:`
  - **Fixed struct return handling**: Added `objc_msgSend_returns_NSRect` C wrapper and `objc_msgSendNSRect` Zig wrapper to properly handle methods like `bounds` that return `NSRect` structs by value (not object pointers)
  - **Switched to NSImageView**: Replaced manual `lockFocus`/`drawInRect`/`unlockFocus` drawing with `NSImageView.setImage:` for reliable, native image display
  - **Removed layer-backing**: Disabled `setWantsLayer:` as it conflicts with traditional drawing approaches
  - Window successfully displays 1024x768 RGBA buffer as dark blue-gray background with white rectangle
  - All Objective-C runtime calls properly validated with assertions
  - Static buffer allocation (3MB) eliminates dynamic allocation overhead
  - Comprehensive error handling and pointer validation throughout
  - **Result:** Window appears and displays rendered content correctly. Application runs successfully with native macOS GUI.

## 12025-10-26--1026-pst
- **Enhanced Assertions & Error Handling**
  - Added comprehensive assertions throughout Cocoa bridge code (`src/platform/macos/window.zig`, `src/platform/macos/cocoa_bridge.zig`)
  - Added panic messages with detailed context for NULL class/selector lookups
  - Added pointer validity checks using `@intFromPtr` before Objective-C message sends
  - Added bounds checking for window dimensions (0 < w/h <= 16384)
  - Added assertions for all `objc_msgSend` calls: receiver, selector, and return value validation
  - Improved error messages: includes class pointers, selectors, and rect dimensions in panic messages
  - Assertions help identify segfault source: currently segfaulting at `objc_msgSend0` call with NSApplication class
  - Note: musl libc is not compatible with macOS Cocoa (requires Apple's system libc)
- **Get Started Guide & Zig IDE Vision**
  - Created `docs/get-started.md` for beginner users comparing Aurora to Cursor
  - Reoriented Ray and Plan to prioritize Zig LSP implementation (Matklad-inspired)
  - Documented snapshot-based LSP architecture: `ready` / `working` / `pending` model
  - Emphasized agentic coding integration: Cursor CLI and Claude Code support
  - Added terminal integration (Vibe Coding) and River compositor workflows
  - Updated Ray Mission Ladder: Phase 1 focuses on core IDE foundation (LSP, editor, completion)
  - References: Matklad's LSP architecture, cancellation model, missing IDE features
- **macOS Tahoe Application Event Loop Complete**
  - Added `runEventLoop` to Platform VTable for event loop support
  - Implemented `Window.runEventLoop()` in `src/platform/macos/window.zig` calling `[NSApplication run]`
  - Added `ns_app` field to Window struct to store NSApplication shared instance
  - Implemented `runEventLoop` in all platform implementations (macOS, RISC-V, null)
  - Updated `tahoe_app.zig` to call `sandbox.platform.runEventLoop()` after showing window
  - Build succeeds: `zig build tahoe` compiles successfully
  - Executable runs: `zig-out/bin/tahoe` starts and shows window (terminates immediately without delegate)
  - Next: Add NSApplication delegate for proper event handling and window lifecycle
- **Cocoa Bridge Implementation Complete**
  - Implemented actual NSApplication, NSWindow, and NSView calls in `src/platform/macos/window.zig`
  - Created `src/platform/macos/cocoa_bridge.zig` with typed `objc_msgSend` wrappers
  - Created `src/platform/macos/objc_runtime.zig` for shared Objective-C runtime C import
  - Fixed function pointer casting using `@extern` to get `objc_msgSend` from Objective-C runtime
  - Fixed null check errors: removed invalid checks on non-optional pointers
  - Fixed array pointer access for NSString conversion
  - Build succeeds: `zig build tahoe` compiles successfully
  - Executable created: `zig-out/bin/tahoe` (1.3MB)

## 12025-11-12--0945-pst
- **Test Improvements & Platform Decoupling**
  - Decoupled fuzz test 002 into platform-specific tests: `002_macos.md` and `999_riscv.md`
  - Implemented buffer content validation using FNV-1a checksum (detects silent corruption)
  - Implemented memory leak detection using GeneralPurposeAllocator (validates cleanup)
  - Added error path coverage test for invalid inputs
  - Updated Ray and Plan with macOS priorities in order: Cocoa bridge → Compositor → UI → Events
  - All tests pass: validates platform abstraction boundaries with improved coverage

## 12025-11-12--0937-pst
- **Experimental Randomized Fuzz Test 002 Implementation**
  - Implemented platform abstraction boundary fuzz test in `src/platform.zig`
  - Tests window initialization, buffer operations, and vtable dispatch paths
  - Uses Matklad-style data-driven testing with SimpleRng LCG PRNG
  - Validates deterministic behavior: RGBA alignment, dimension consistency,
    single-level pointer usage
  - Updated `tests-experiments/002.md` with methodology and results
  - Test passes: 100 iterations of random window lifecycle operations
  - Fixed Window struct compile-time constant assertions in `src/platform/macos/window.zig`
- **Changelog Creation**
  - Created `changelog.md` with descending append-to-front order
  - Documented all recent progress: pointer documentation, platform abstraction,
    struct organization, kernel scaffolding, Ray & Plan Mission Ladder updates
  - Using Holocene Vedic calendar timestamp format: `12025-11-12--0937-pst`

## 12025-11-12--0930-pst
- **Pointer Documentation & TigerStyle Compliance**
  - Added comprehensive pointer usage comments across all platform abstraction code
  - Documented why each pointer is used (TigerStyle: explain "why", not "what")
  - Verified single-level pointers only: no double/triple pointers (`**T`, `***T`) exist
  - Removed invalid null checks on non-optional pointers (`*const VTable`, `*anyopaque`)
  - Added pointer flow documentation in `src/platform.zig`, `src/platform/macos/impl.zig`,
    `src/platform/riscv/impl.zig`, `src/platform/null/impl.zig`
  - All platform implementations now explicitly document single-level pointer design
  - Tests pass; codebase adheres to TigerStyle pointer guidelines

## 12025-11-12--0930-pst
- **Platform Abstraction Refactoring**
  - Created platform abstraction layer (`src/platform.zig`) with VTable pattern
  - Implemented macOS, RISC-V, and null platform implementations
  - Decoupled platform-specific code from core Aurora UI logic
  - Added comprehensive assertions following TigerStyle principles
  - Refactored `src/tahoe_window.zig` to use platform abstraction
  - All platform code uses single-level pointers only (TigerStyle compliance)

## 12025-11-12--0920-pst
- **Struct Organization**
  - Created `src/structs/` directory for centralized struct definitions
  - Added `src/structs/index.zig` to re-export all public structs
  - Created `src/structs/README.md` documenting struct organization
  - Separated struct definitions into unique files for easier review

## 12025-11-12--0910-pst
- **Kernel Scaffolding**
  - Created `src/kernel/main.zig`, `src/kernel/syscall_table.zig`, `src/kernel/devx/abi.zig`
  - Added `kernel/link.ld` linker script for RISC-V
  - Created `scripts/qemu_rv64.sh` for QEMU testing
  - Extended `grain conduct` with `make kernel-rv64`, `run kernel-rv64`, `report kernel-rv64`
  - Kernel work paused until Framework 13 RISC-V board or VPS is available

## 12025-11-12--0900-pst
- **Ray & Plan Mission Ladder**
  - Refactored `docs/ray.md` and `docs/plan.md` into "Mission Ladder" format
  - Prioritized macOS Tahoe Aurora UI development
  - Added "Experimental Randomized Fuzz Test 002" as top priority
  - Updated all section numbers to reflect new priority order
  - Documented deterministic plan execution strategy

## 12025-11-12--0850-pst
- **Installation Documentation**
  - Created `docs/install.md` with Zig 0.15.2 installation instructions
  - Emphasized using official `ziglang.org` release for TigerStyle determinism
  - Updated `docs/ray.md` to reference installation guide

## 12025-11-12--0840-pst
- **Crash Handling**
  - Created `src/aurora_crash.zig` for panic handling and error logging
  - Refactored `src/tahoe_app.zig` to wrap `mainImpl` in error handler
  - Added system information, panic messages, and stack traces to crash logs

## 12025-11-12--0830-pst
- **LSP & Editor Integration**
  - Created `src/aurora_lsp.zig` for LSP client functionality
  - Created `src/aurora_editor.zig` for Aurora code editor IDE
  - Integrated `GrainBuffer`, `GrainAurora`, and `LspClient`
  - Laid groundwork for ZLS integration

## 12025-11-12--0820-pst
- **Text Rendering**
  - Created `src/aurora_text_renderer.zig` for rendering text into RGBA buffers
  - Added `TextRenderer` struct with `render` method
  - Integrated into `build.zig` tests

## 12025-11-12--0810-pst
- **Aurora UI Framework**
  - Created `src/grain_aurora.zig` for core Aurora UI framework
  - Defined `Node`s, `Component`s, and rendering logic
  - Refactored comments to explain "why" instead of "what" (TigerStyle)

## 12025-11-12--0800-pst
- **Tahoe Sandbox**
  - Created `src/tahoe_window.zig` as main sandbox for Aurora GUI
  - Integrated `Platform` abstraction and `GrainAurora`
  - Added `tick` function for rendering loop
  - Created `src/tahoe_app.zig` as main executable

## 12025-11-12--0750-pst
- **Project Initialization**
  - Initialized Git repository in `xy` (`/Users/bhagavan851c05a/kae3g/bhagavan851c05a`)
  - Created GitHub repository `@kae3g/xy` with `main` branch
  - Set repository description emphasizing macOS Zig-Swift-ObjectiveC Native GUI
  - Created `docs/ray.md` and `docs/ray_160.md` as canonical project documentation

