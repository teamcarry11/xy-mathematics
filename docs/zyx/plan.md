# Grain Aurora GUI Plan — GrainStyle Execution

**Current Status**: Window rendering complete ✅, VM-GUI integration complete ✅, VM-syscall integration complete ✅, SBI integration complete ✅. Focus: Single-threaded safety-first efficiency architecture, SBI console integration.

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
  - ✅ Grain Style: Explicit memory configuration, conservative defaults, RAM-aware design
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
  - ✅ Grain Style: All function names converted to snake_case ✅ **COMPLETE**
- **RISC-V SBI Integration** 🔥 **CRITICAL PRIORITY** 🎯 **NEW** ✅ **CORE COMPLETE**:
  - **Our Own Grain Style SBI Wrapper**: Created `src/kernel_vm/sbi.zig` - minimal, Grain Style compliant (inspired by CascadeOS/zig-sbi, MIT licensed)
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
    - ✅ Comprehensive assertions (Grain Style)
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
    - ✅ Comprehensive assertions (Grain Style)
    - Location: `src/kernel/basin_kernel.zig` → syscall functions
  - **Next Phase: Complete Phase 1 & Expand Foundation** 🔥 **IN PROGRESS**:
    - **Priority 4: Complete Phase 1 - Implement `spawn` Syscall** ✅ **COMPLETE**:
      - ✅ Validate executable pointer/length (ELF header size minimum)
      - ✅ Validate args pointer/length (can be zero for no args)
      - ✅ Return stub process ID (1)
      - ✅ Comprehensive assertions (Grain Style)
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
      - ✅ Comprehensive assertions (Grain Style)
      - ✅ **Phase 2 Complete: 8/8 syscalls implemented!**
      - Location: `src/kernel/basin_kernel.zig` → syscall functions
    - **Next Phase: Foundation Implementation** 🔥 **IN PROGRESS**:
      - **Phase 3: Memory Management Foundation** ✅ **COMPLETE**:
        - ✅ Implemented mapping table (static array, max 256 entries)
        - ✅ Updated map/unmap/protect syscalls to use actual table
        - ✅ Track memory mappings (address, size, flags)
        - ✅ Validate no overlaps, proper allocation/deallocation
        - ✅ Simple allocator for kernel-chosen addresses (next_alloc_addr)
        - ✅ Comprehensive assertions (Grain Style)
        - ✅ Zero compiler warnings, all tests passing
        - Location: `src/kernel/basin_kernel.zig` → `MemoryMapping` struct, `mappings` table
      - **Phase 4: File System Foundation** ✅ **COMPLETE**:
        - ✅ Implemented handle table (static array, max 64 entries)
        - ✅ Updated open/read/write/close syscalls to use actual table
        - ✅ In-memory file system (no disk yet)
        - ✅ Track file handles (path, flags, position, buffer)
        - ✅ Comprehensive assertions (Grain Style)
        - ✅ All fuzz tests passing (006, 007)
        - Location: `src/kernel/basin_kernel.zig` → `FileHandle` struct, `handles` table
      - **RISC-V Instruction Set Expansion** ✅ **COMPLETE**:
        - ✅ Load instructions: LB, LH, LW, LD, LBU, LHU, LWU (7 total)
        - ✅ Store instructions: SB, SH, SW, SD (4 total)
        - ✅ Jump instructions: JAL, JALR (2 total)
        - ✅ Branch instructions: BNE, BLT, BGE, BLTU, BGEU (5 total)
        - ✅ Total: 33 instructions (15 base + 18 new)
        - ✅ All instructions include comprehensive contracts (alignment, bounds checking, sign/zero extension)
        - ✅ Location: `src/kernel_vm/vm.zig` → instruction dispatch + execute functions
      - **VM-Kernel Integration Layer** ✅ **COMPLETE**:
        - ✅ Created `src/kernel_vm/integration.zig` with comprehensive contracts
        - ✅ Implemented `Integration` struct for VM-kernel coordination
        - ✅ Implemented syscall handler bridge (SyscallResult ↔ u64)
        - ✅ Implemented `loadUserspaceELF()` with stack setup and argv support
        - ✅ Module exports: `Integration` and `loadUserspaceELF` exported from `kernel_vm.zig`
        - ✅ Integration tests: 5/5 tests passing (`tests/011_integration_test.zig`)
        - ✅ Build integration: `zig build integration-test` command
        - Location: `src/kernel_vm/integration.zig`
      - **Next Steps: Userspace Readiness** ✅ **COMPLETE**:
        - **Priority 1: Complete argv string setup** (optional - basic argc/argv works):
          - Complete full argv string array setup on stack
          - Location: `src/kernel_vm/integration.zig` → `loadUserspaceELF`
        - **Priority 2: Create minimal stdlib** ✅ **COMPLETE**:
          - ✅ Created syscall wrappers for Zig programs (`src/userspace/stdlib.zig`)
          - ✅ Basic file system functions (open, read, write, close, print)
          - ✅ Inline assembly for ECALL instruction (RISC-V syscall convention)
          - ✅ Location: `src/userspace/stdlib.zig`
        - **Priority 3: Hello World compilation** 🔥 **IN PROGRESS** (~85% complete):
          - ✅ Compiled Zig "Hello World" for RISC-V64 successfully
          - ✅ Created userspace linker script (`linker_scripts/userspace.ld`)
          - ✅ Build step: `zig build hello-world`
          - ✅ Binary: `zig-out/bin/hello_world` (RISC-V64 ELF executable)
          - ✅ **Static Allocation Fix**: Changed VM allocation from stack to heap to avoid stack overflow (4MB struct)
          - ✅ **PIE Entry Point Fix**: Fixed ELF loader to handle position-independent executables (entry point 0x0 → first PT_LOAD vaddr 0x10000)
          - ✅ **VM Execution**: VM successfully starts and executes instructions
          - ⏳ **Current**: Debugging opcode 0x00 instruction (instruction `0x38231400` with funct3=1, funct7=0x1c)
          - ⏳ **Next**: Implement opcode 0x00 handling for Zig compiler compatibility
          - Location: `examples/hello_world.zig`
          - **Reference**: `docs/userspace_roadmap.md` for detailed progress tracking
      - **Next Steps: Hello World Execution** 🔥 **CURRENT PRIORITY** (Sequential Order):
        - **Step 1: Fix Opcode 0x00 Instruction Handling** ⏳ **IN PROGRESS**:
          - **Issue**: Instruction `0x38231400` has opcode 0x00 (invalid for 32-bit RISC-V)
          - **Analysis**: funct3=1 (SLL), funct7=0x1c (non-standard) - Zig compiler compatibility issue
          - **Solution**: Add opcode 0x00 handler that decodes as R-type instruction (treat funct3=1 as SLL)
          - **Location**: `src/kernel_vm/vm.zig` → instruction dispatch switch statement
          - **Status**: Implementing opcode 0x00 handler with R-type decoding fallback
        - **Step 2: Complete Hello World Execution**:
          - Run Hello World program to completion in VM
          - Capture syscall output (write syscall arguments)
          - Verify "Hello, World!" output
          - Location: `tests/012_hello_world_test.zig`
        - **Step 3: Verify RISC-V Zig Code Execution**:
          - Test more complex Zig programs in VM
          - Verify correct RISC-V instruction semantics
          - Validate VM matches Framework 13 RISC-V hardware behavior
        - **Reference**: `docs/userspace_roadmap.md` - Week 3 status, ~85% complete
      - **Phase 5: Process Management Foundation** 🔥 **MEDIUM PRIORITY**:
        - Implement process table (static array, max 16 entries)
        - Update spawn/wait syscalls to use actual table
        - Track processes (ID, executable, entry point, state, exit status)
        - Location: `src/kernel/basin_kernel.zig` → add process table structure
      - **Phase 6: IPC Foundation** 🔥 **MEDIUM PRIORITY**:
        - Implement channel table (static array, max 32 entries)
        - Update channel_create/send/recv syscalls to use actual table
        - Message queues (circular buffers)
        - Location: `src/kernel/basin_kernel.zig` → add channel table structure
      - **Phase 7: Timer Integration** 🔥 **MEDIUM PRIORITY**:
        - Integrate SBI timer for time operations
        - Update clock_gettime/sleep_until syscalls to use timer
        - Track system time (nanoseconds since boot)
        - Location: `src/kernel/basin_kernel.zig` → add timer state
      - **Phase 8: VM Shutdown & User Management** ✅ **COMPLETE**:
        - ✅ **VM Shutdown**: SBI LEGACY_SHUTDOWN (0x8) implemented, VM halts on shutdown
        - ✅ **User Management**: Root (uid=0) and `xy` user (uid=1000) implemented
        - ✅ **User Table**: Static allocation (max 256 users), `User` and `UserContext` structs
        - ✅ **User Functions**: `find_user_by_uid()`, `find_user_by_name()`, `set_current_user()`
        - ✅ **Path Structure**: Standard Unix-like paths (`/bin`, `/home/xy`, `/etc`, `/zix/store`)
        - ✅ **Sudo Permissions**: Capability-based sudo (CAPABILITY_SUDO, CAPABILITY_SHUTDOWN) - architecture defined
        - ✅ **Grain Style**: Explicit types (u32 not usize), static allocation, comprehensive assertions
        - Location: `src/kernel/basin_kernel.zig` → user management complete
        - Reference: `docs/vm_shutdown_user_management.md` for comprehensive design
      - **Phase 9: z6 Process Supervision** ✅ **COMPLETE**:
        - ✅ **z6 Supervisor**: s6-like process supervision daemon written in Zig
        - ✅ **Service Management**: Start/stop/restart services, dependency resolution
        - ✅ **Restart Policies**: always, never, on-failure with crash rate limiting (max 10/min)
        - ✅ **Service Directories**: `/etc/z6/service/` with `run` and `finish` scripts (architecture defined)
        - ✅ **Logging**: Capture stdout/stderr, route to kernel logging syscall (architecture defined)
        - ✅ **Grain Style**: Single-threaded, static allocation (64 services max), deterministic
        - ✅ **Core Implementation**: `Z6Supervisor`, `ServiceDef`, `ServiceInstance`, supervision loop
        - Location: `src/userspace/z6.zig` → supervisor daemon complete
        - Reference: `docs/vm_shutdown_user_management.md` for z6 architecture
      - **Phase 10: Zix Build System** 🔥 **LONG-TERM PRIORITY**:
        - **Build Store**: Content-addressed store (`/zix/store/{hash}-{name}`)
        - **Build Recipes**: Deterministic builds with SHA-256 hashing of inputs
        - **GrainDB Integration**: Immutable build store using graindb (referentially transparent)
        - **Referential Transparency**: Same inputs → same outputs (content-addressed)
        - **Build Syscalls**: `build`, `query_store` syscalls for package management
        - **Name**: **Zix** - Zig + Nix-inspired build system
        - Location: `src/userspace/zix/` → build system, `src/userspace/graindb/` → database
        - Reference: `docs/vm_shutdown_user_management.md` for Zix build system design
      - **Phase 11: Build-Essential Utilities** 🔥 **IN PROGRESS**:
        - ✅ **Core Utilities**: Common shell utilities rewritten in Zig (like Debian's `build-essential`)
        - ✅ **Implemented**: `cat` (with `cat_file()` helper for file handling), `echo` (basic output), `ls` (stub), `mkdir` (stub)
        - ✅ **Build System**: All utilities compile successfully to RISC-V64 freestanding binaries (`zig-out/bin/`)
        - ✅ **Argument Parsing Helper**: `src/userspace/utils/args.zig` module created for common argument parsing
        - ✅ **File Operations**: `cat` supports file opening via `open` syscall (ready for argument parsing)
        - 🔄 **In Progress**: Argument parsing from RISC-V registers (a0=argc, a1=argv) using inline assembly
        - **Pending**: `rm`, `cp`, `mv` (file management utilities)
        - **Pending**: `grep`, `sed`, `awk` (text processing utilities)
        - **Pending**: Directory syscalls (`readdir`, `opendir`, `mkdir`) for `ls` and `mkdir` implementation
        - **Pending**: `make` (Zig version), `cc` wrapper for Zig compiler, `ar`, `ld` (linker)
        - **Grain Style**: Single-threaded, static allocation (MAX_LINE_LEN=4096, MAX_ARGS=64), explicit types (u32 not usize), deterministic, type-safe
        - **Zix Integration**: All utilities built via Zix, stored in `/zix/store/` (when Zix is implemented)
        - **Location**: `src/userspace/utils/core/` → core utilities, `src/userspace/utils/text/` → text processing, `src/userspace/build-tools/` → build tools
        - **Reference**: Inspired by Debian `build-essential`, rewritten in pure Zig for Grain Basin
        - **Documentation**: `docs/build_essential_utilities.md` for architecture design
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
- **Grain Style Requirements**:
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
- ✅ Grain Style: Comprehensive assertions, pointer validation, bounds checking
- ✅ Static allocation: Minimal dynamic allocation, static class names
- ✅ View hierarchy: TahoeView (events) → NSImageView (rendering)
- ✅ Code quality: Comments explain "why", functions <70 lines, <100 columns (grainwrap/grainvalidate)
- Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`, `src/platform/events.zig`

### 2. Animation/Update Loop 🔥 **HIGH PRIORITY** ✅ **COMPLETE**
- ✅ Platform VTable: `startAnimationLoop`, `stopAnimationLoop` methods added
- ✅ Window struct: `animation_timer`, `tick_callback`, `tick_user_data` fields added
- ✅ Tick callback routing: `routeTickCallback` implemented with Grain Style assertions
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
- ✅ Grain Style assertions for pointer validation and dimension bounds checking
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

## Grain Style Code Quality Standards 🐅

**Enforcement**: All code must follow Grain Style principles:
- **Comments**: Explain "why" not "what" (Grain Style principle)
- **Assertions**: Comprehensive pointer validation, bounds checking, enum validation
- **Static Allocation**: Prefer static allocation over dynamic (maximal static allocation)
- **Function Length**: <70 lines per function (grainvalidate requirement)
- **Column Width**: <100 columns per line (Grain Style, grainwrap for docs at 73)
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
- Grain Style: Comprehensive assertions, pointer validation, bounds checking
- Static allocation: Minimal dynamic allocation, static class names, associated objects
- View hierarchy: TahoeView (content view, handles events) → NSImageView (subview, renders images)
- Code quality: Comments explain "why" not "what", functions <70 lines, <100 columns
- Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`, `src/platform/events.zig`

### macOS Tahoe Window Resizing ✅ **COMPLETE**
- Implemented `windowDidResize:` delegate method via `TahoeWindowDelegate` class (created dynamically using Objective-C runtime API)
- Resize events route to Zig `routeWindowDidResize` function with Grain Style assertions
- Window dimensions updated on resize (buffer remains static 1024x768 for now)
- NSImageView automatically scales image to fit window size (proportional scaling)
- Delegate set up automatically when window is created
- Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`

### macOS Tahoe Animation/Update Loop ✅ **COMPLETE**
- Platform VTable: `startAnimationLoop`, `stopAnimationLoop` methods added
- Window struct: `animation_timer`, `tick_callback`, `tick_user_data` fields added
- Tick callback routing: `routeTickCallback` implemented with Grain Style assertions
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
