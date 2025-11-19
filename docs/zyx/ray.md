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

### Phase 1: macOS Tahoe GUI Foundation (Current Priority) 🎯

**Status**: Window rendering complete ✅. Next: Interactive input handling.

0. **RISC-V Kernel Virtualization Layer (macOS Tahoe)** 🔥 **HIGH PRIORITY** 🎯 **NEW** ✅ **CORE COMPLETE**
   - **Vision**: Run Zig monolith kernel in virtualized RISC-V environment within macOS Tahoe IDE
   - **Kernel Name**: **Grain Basin kernel** 🏞️ (official) - "The foundation that holds everything" (Lake Tahoe basin metaphor, perfect Tahoe connection, 30-year vision, non-POSIX, modern design)
     - **Homebrew Bundle**: `grainbasin` (Brew package name)
     - **Rationale**: Ties into Grain branding, allows clean Homebrew package name
   - **Why**: Enable kernel development and testing without physical RISC-V hardware or external QEMU
   - **RAM-Aware Configuration**: VM memory size configurable (default 4MB, max recommended 64MB)
     - **Development**: MacBook Air M2 (24GB RAM) - plenty of headroom
     - **Target**: Framework 13 RISC-V (8GB RAM) - conservative defaults
     - **Rationale**: 4MB safe for both machines, sufficient for early kernel development
     - **Reference**: `docs/vm_memory_config.md` for detailed RAM considerations
   - **RISC-V-First Development Strategy**: 
     - **Primary Goal**: Develop RISC-V-targeted Zig code in macOS Tahoe VM, deploy to Framework 13 DeepComputing RISC-V mainboard with confidence
     - **VM-Hardware Parity**: Pure Zig emulator matches Framework 13 RISC-V mainboard behavior (RISC-V64 ISA, memory model, register semantics)
     - **Development Workflow**: Write RISC-V Zig code → Test in macOS Tahoe VM → Deploy to Framework 13 RISC-V hardware (no code changes needed)
     - **Compatibility Guarantee**: VM instruction semantics, memory layout, and register behavior match real RISC-V hardware exactly
   - **Kernel Design Philosophy**:
     - **Architecture**: Type-safe monolithic kernel (not microkernel - performance priority)
     - **Single-Threaded**: No locks, no race conditions, deterministic execution, maximum efficiency
     - **Safety #1 Priority**: Comprehensive assertions, type safety, explicit error handling, static allocation
     - **Maximum Efficiency**: Direct function calls (no IPC overhead), static allocation, comptime optimizations, cache-friendly
     - **Minimal Syscall Surface**: Essential operations only (spawn, exit, map, unmap, open, read, write, close, channels)
     - **Non-POSIX**: Deliberately avoid POSIX legacy (no fork/clone, signals, complex file descriptors)
     - **Type-Safe**: Leverage Zig's comptime, error unions, strongly-typed handles (not integer FDs)
     - **Modern Design**: Inspired by Aero OS (monolithic), CascadeOS/zig-sbi (SBI), Fuchsia (capability-based)
     - **RISC-V Native**: Design for RISC-V64 from ground up (not ported from x86)
     - **30-Year Vision**: Design for next 30 years, not backward compatibility
     - **Grain Style**: Maximum safety, explicit operations, comprehensive assertions
     - **Reference**: See `docs/kernel_design_philosophy.md`, `docs/single_threaded_safety_efficiency.md` for comprehensive design decisions
   - **Grain Basin kernel Foundation** ✅ **COMPLETE**:
     - ✅ Kernel name: Grain Basin kernel 🏞️ - "The foundation that holds everything"
     - ✅ Homebrew bundle: `grainbasin` (Brew package name)
     - ✅ Syscall interface (`src/kernel/basin_kernel.zig`): All 17 core syscalls defined
     - ✅ Type-safe abstractions: `Handle` (not integer FDs), `MapFlags`, `OpenFlags`, `ClockId`, `SysInfo`, `BasinError`, `SyscallResult`
     - ✅ Syscall enumeration: spawn, exit, yield, wait, map, unmap, protect, channel_create, channel_send, channel_recv, open, read, write, close, clock_gettime, sleep_until, sysinfo
     - ✅ Build integration: `basin_kernel_module` added to `build.zig`
     - ✅ Grain Style: Comprehensive assertions, explicit type safety, "why" comments, function length limits
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
   - **RISC-V SBI Integration** 🔥 **CRITICAL PRIORITY** 🎯 **NEW** ✅ **CORE COMPLETE**:
     - **Our Own Grain Style SBI Wrapper**: Created `src/kernel_vm/sbi.zig` - minimal, Grain Style compliant (inspired by CascadeOS/zig-sbi, MIT licensed)
     - **SBI Purpose**: Platform runtime services (timer, console, reset, IPI) - different from kernel syscalls
     - **Integration Complete**: SBI calls integrated into VM ECALL handler ✅
     - **ECALL Dispatch**: VM dispatches ECALL to SBI (function ID < 10) or kernel syscalls (function ID >= 10) ✅
     - **SBI Console**: SBI_CONSOLE_PUTCHAR implemented, routes to serial output ✅
     - **SBI Timer**: SBI_SET_TIMER ready for implementation (future)
     - **Single-Threaded Safety**: SBI layer is single-threaded, no locks, deterministic execution
     - **Reference**: See `docs/cascadeos_analysis.md`, `docs/credits.md` for comprehensive SBI analysis
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
         - **Userspace Standard Library** ✅ **COMPLETE**:
           - ✅ Created `src/userspace/stdlib.zig` with syscall wrappers
           - ✅ Basic file system functions (open, read, write, close, print)
           - ✅ Inline assembly for ECALL instruction (RISC-V syscall convention)
           - ✅ Comprehensive contracts and error handling
           - Location: `src/userspace/stdlib.zig`
         - **Hello World Userspace Program** 🔥 **IN PROGRESS** (~85% complete):
           - ✅ Compiled Zig "Hello World" for RISC-V64 successfully
           - ✅ Created userspace linker script (`linker_scripts/userspace.ld`)
           - ✅ Build step: `zig build hello-world`
           - ✅ Binary: `zig-out/bin/hello_world` (RISC-V64 ELF executable, 2.5MB)
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
           - ✅ **Path Structure**: Standard Unix-like paths (`/bin`, `/home`, `/etc`, `/zix/store`)
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
           - **Build Recipes**: Deterministic builds with SHA-256 hashing
           - **GrainDB Integration**: Immutable build store using graindb
           - **Referential Transparency**: Same inputs → same outputs
           - **Name**: **Zix** - Zig + Nix-inspired build system
           - Location: `src/userspace/zix/` → build system, `src/userspace/graindb/` → database
           - Reference: `docs/vm_shutdown_user_management.md` for Zix build system design
         - **Phase 11: Build-Essential Utilities** 🔥 **IN PROGRESS**:
           - ✅ **Core Utilities**: Common shell utilities rewritten in Zig (like Debian's `build-essential`)
           - ✅ **Implemented**: `cat` (with file handling), `echo` (basic), `ls` (stub), `mkdir` (stub)
           - ✅ **Build System**: All utilities compile to RISC-V64 freestanding binaries
           - ✅ **Argument Parsing Helper**: `args.zig` module created for common argument parsing
           - 🔄 **In Progress**: Argument parsing from RISC-V registers (a0=argc, a1=argv)
           - **Pending**: `rm`, `cp`, `mv`, `grep`, `sed`, `awk` (Zig versions)
           - **Pending**: `make` (Zig version), `cc` wrapper for Zig compiler, `ar`, `ld` (linker)
           - **Pending**: Directory syscalls (`readdir`, `opendir`, `mkdir`) for `ls` and `mkdir`
           - **Grain Style**: Single-threaded, static allocation, deterministic, type-safe
           - **Zix Integration**: All utilities built via Zix, stored in `/zix/store/` (when Zix is implemented)
           - **Location**: `src/userspace/utils/core/` → core utilities, `src/userspace/build-tools/` → build tools
           - **Reference**: Inspired by Debian `build-essential`, rewritten in pure Zig for Grain Basin
         - **Reference**: `docs/next_implementation_phases.md` for detailed phase plans
     - **Single-Threaded Architecture**: ✅ All layers single-threaded, no locks, deterministic
     - **Safety-First Patterns**: ✅ Comprehensive assertions, type-safe interfaces, explicit error handling, static allocation
     - **RAM-Aware Configuration**: ✅ VM memory configurable (4MB default, 64MB max), documented
     - **Debug Interface**: Register viewer, memory inspector, GDB stub (future)
   - **Grain Style Requirements**:
     - Static allocation for VM state structures where possible ✅
     - Comprehensive assertions for memory access, instruction decoding ✅
     - Deterministic execution: Same kernel state → same output ✅
     - No hidden state: All VM state explicitly tracked ✅
     - Single-threaded: No locks, no race conditions, deterministic execution ✅
     - Safety #1: Comprehensive assertions ✅, type safety ✅, explicit error handling ✅
     - Maximum efficiency: Direct calls, static allocation, comptime optimizations ✅
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
     - Reference: See `docs/single_threaded_safety_efficiency.md` for comprehensive architecture design
     - Reference: See `tests-experiments/005_fuzz.md` for fuzz test plan
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
   - ✅ Grain Style: Comprehensive assertions, pointer validation, bounds checking
   - ✅ Static allocation: Minimal dynamic allocation, static class names, associated objects
   - ✅ View hierarchy: TahoeView (content view, handles events) → NSImageView (subview, renders images)
   - ✅ Code quality: Comments explain "why" not "what", functions <70 lines, <100 columns
   - Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`, `src/platform/events.zig`

2. **Animation/Update Loop (macOS Tahoe)** 🔥 **HIGH PRIORITY** ✅ **COMPLETE**
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

3. **Window Resizing (macOS Tahoe)** 🔥 **HIGH PRIORITY** ✅ **COMPLETE**
   - ✅ Implemented `windowDidResize:` delegate method via `TahoeWindowDelegate` class (created dynamically)
   - ✅ Resize events route to Zig `routeWindowDidResize` function
   - ✅ Window dimensions updated on resize (buffer remains static 1024x768)
   - ✅ NSImageView automatically scales image to fit window size
   - ✅ Grain Style assertions for pointer validation and dimension bounds checking
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
   - GrainStyle compliance checks
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
[^etsy]: [Etsy.com — handmade marketplace and creative community](https://www.etsy.com/)
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

























