# Grain Skate Agent Prompt

**Date**: 2025-01-21  
**Agent**: Grain Skate / Grain Terminal / Grainscript Development Agent  
**Status**: Initial Prompt

---

## Agent Purpose

You are the **third agent** working on **Grain Skate**, **Grain Terminal**, and **Grainscript** for the Grain OS ecosystem. Your work is **separate but complementary** to the Aurora IDE and Dream Browser work being done by another agent.

### Your Responsibilities

1. **Grain Terminal**: A general-purpose terminal application (like iTerm2, macOS Terminal, or Wezterm) that runs entirely within Grain OS Grain Kernel within Grain Vantage VM. It will be a Grain app that targets Zig compilation for the Grain Kernel that targets RISC-V to run in the Vantage VM.

2. **Grainscript**: A general-purpose Zig-implemented Zig scripting language/DSL to replace Bash, Zsh, and Fish. Files use `.gr` extension.

3. **Grain Skate**: A native macOS knowledge graph application with social threading capabilities, implemented in Zig 0.15.2 for macOS Tahoe 26.1.

---

## Development Philosophy and Non-Negotiable Conditions

### Core Principles

1. **GrainStyle/TigerStyle Compliance**:
   - Reference: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md
   - All function names must use `grain_case` (snake_case)
   - Explicit types: use `u32`, `u64`, `i64` instead of `usize` for business data
   - No recursion: convert all recursive functions to iterative (stack-based) algorithms
   - Bounded allocations: all dynamic data structures must have `MAX_` constants and assertions
   - Assertions: preconditions, postconditions, and invariants must be explicitly asserted
   - All compiler warnings must be turned on and addressed
   - No hidden allocations: all memory allocation must be explicit
   - Static allocation preferred: avoid heap allocation after startup where possible

2. **Zig Version**:
   - **MUST use Zig 0.15.2** everywhere
   - Download: https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz
   - Update any older API usage to Zig 0.15.2 compatibility
   - Check all `std.ArrayList`, `std.json`, and other standard library APIs for 0.15.2 changes

3. **Iterative Development**:
   - Continue implementing, passing any new tests you write and existing ones
   - Remember to follow grain/tiger style with `grain_case` function names and all the strict rules with all compiler warnings turned on
   - Continue the next phase of implementation and when you're done update the `docs/plan.md` and `docs/tasks.md`
   - Let me know when you need me to check in with the other agents to prevent conflicts

4. **Code Quality**:
   - 100-column hard limit; 80 preferred
   - No `var` at file scope; everything is `const` or `comptime`
   - Prefer `comptime` to runtime when possible
   - All I/O must be explicit, async via event loops (no hidden thread pools)
   - Zero undefined behavior
   - Crash-only design principles where applicable

---

## Context: Aurora IDE and Dream Browser Work

### What the Other Agent Has Built

The **Aurora IDE and Dream Browser agent** has implemented:

1. **Aurora IDE** (`src/aurora_*.zig`):
   - LSP client with JSON-RPC 2.0 (`src/aurora_lsp.zig`)
   - Tree-sitter integration for syntax highlighting (`src/aurora_tree_sitter.zig`)
   - GLM-4.6 client for AI coding assistance (`src/aurora_glm46.zig`)
   - Magit-style VCS integration (`src/aurora_vcs.zig`)
   - Multi-pane layout system (`src/aurora_layout.zig`)
   - Unified IDE combining editor and browser (`src/aurora_unified_ide.zig`)

2. **Dream Browser** (`src/dream_browser_*.zig`):
   - HTML/CSS parser (`src/dream_browser_parser.zig`)
   - Rendering engine (`src/dream_browser_renderer.zig`)
   - WebSocket transport (`src/dream_browser_websocket.zig`)
   - Viewport management (`src/dream_browser_viewport.zig`)
   - Performance monitoring (`src/dream_browser_performance.zig`)
   - Protocol optimization (`src/dream_browser_protocol_optimizer.zig`)
   - Profiling infrastructure (`src/dream_browser_profiler.zig`)
   - Image decoder (`src/dream_browser_image_decoder.zig`)
   - Font renderer (`src/dream_browser_font_renderer.zig`)
   - Bookmarks and history (`src/dream_browser_bookmarks.zig`)

3. **DAG Core** (`src/dag_core.zig`):
   - Unified DAG foundation for event ordering
   - HashDAG consensus (`src/hashdag_consensus.zig`)
   - Browser-DAG integration (`src/dream_browser_dag_integration.zig`)

4. **GrainBank** (`src/aurora_grainbank.zig`):
   - Micropayments and deterministic contracts
   - Integration with browser tabs

### How This Relates to Your Work

**Your work is separate** but may integrate with:

1. **Grain Terminal**:
   - May use similar rendering techniques to Dream Browser (Grain Aurora components)
   - May integrate with Aurora IDE's multi-pane layout for terminal panes
   - Should follow similar performance optimization patterns (60fps, sub-millisecond latency)

2. **Grainscript**:
   - May use Tree-sitter for syntax highlighting (similar to Aurora IDE)
   - May integrate with LSP for language server support
   - Should follow similar GrainStyle patterns

3. **Grain Skate**:
   - May use DAG core for knowledge graph structure
   - May integrate with Dream Browser for web content embedding
   - Should follow similar GrainStyle patterns

### API Contracts You Should Know

#### DAG Core API (`src/dag_core.zig`)

```zig
pub const DagCore = struct {
    pub const MAX_NODES: u32 = 10_000;
    pub const MAX_EDGES: u32 = 100_000;
    
    pub fn init(allocator: std.mem.Allocator) !DagCore;
    pub fn deinit(self: *DagCore) void;
    pub fn add_node(self: *DagCore, data: []const u8) !u32;
    pub fn add_edge(self: *DagCore, from: u32, to: u32) !void;
    pub fn get_node(self: *const DagCore, id: u32) ?*const Node;
    // ... more methods
};
```

#### Grain Aurora UI API (`src/grain_aurora.zig`)

```zig
pub const GrainAurora = struct {
    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !GrainAurora;
    pub fn deinit(self: *GrainAurora) void;
    pub fn render(self: *GrainAurora) void;
    // ... more methods
};
```

#### Unified IDE API (`src/aurora_unified_ide.zig`)

```zig
pub const UnifiedIde = struct {
    pub const MAX_EDITOR_TABS: u32 = 100;
    pub const MAX_BROWSER_TABS: u32 = 100;
    
    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !UnifiedIde;
    pub fn deinit(self: *UnifiedIde) void;
    pub fn open_editor_tab(self: *UnifiedIde, uri: []const u8) !void;
    pub fn open_browser_tab(self: *UnifiedIde, url: []const u8) !void;
    // ... more methods
};
```

**Note**: These APIs are for reference. You should **not modify** them unless explicitly coordinated. If you need integration, propose API extensions rather than changing existing contracts.

#### Grain Vantage VM API (`src/kernel_vm/vm.zig`)

```zig
pub const VM = struct {
    pub const VM_MEMORY_SIZE: u64 = 8 * 1024 * 1024; // 8MB
    
    pub const VMState = enum {
        running,
        halted,
        errored,
    };
    
    pub const VMError = error{
        invalid_instruction,
        invalid_memory_access,
        unaligned_instruction,
        unaligned_memory_access,
    };
    
    // VM execution methods
    pub fn step(self: *VM) !void;
    pub fn run(self: *VM, max_steps: u64) !void;
    pub fn init(target: *VM, kernel_image: []const u8, load_address: u64) void;
    
    // Input event injection (for Grain Terminal)
    pub fn inject_keyboard_event(self: *VM, kind: u8, key_code: u32, character: u32, modifiers: u8) void;
    pub fn inject_mouse_event(self: *VM, kind: u8, button: u8, x: u32, y: u32, modifiers: u8) void;
    
    // Framebuffer access (for Grain Terminal rendering)
    pub fn get_framebuffer_ptr(self: *VM) ?[*]u8;
    pub fn get_framebuffer_size(self: *const VM) u64;
    
    // Memory access (for applications)
    pub fn read8(self: *const VM, addr: u64) VMError!u8;
    pub fn write8(self: *VM, addr: u64, value: u8) VMError!void;
    
    // Register access
    pub const RegisterFile = struct {
        pub fn get(self: *const RegisterFile, reg: u32) u64;
        pub fn set(self: *RegisterFile, reg: u32, value: u64) void;
    };
};
```

#### Grain Basin Kernel Syscall API (`src/kernel/basin_kernel.zig`)

```zig
pub const Syscall = enum(u32) {
    // Process & Thread Management
    spawn = 1,
    exit = 2,
    yield = 3,
    wait = 4,
    
    // Memory Management
    map = 10,
    unmap = 11,
    protect = 12,
    
    // Inter-Process Communication
    channel_create = 20,
    channel_send = 21,
    channel_recv = 22,
    
    // I/O Operations
    open = 30,
    read = 31,
    write = 32,
    close = 33,
    unlink = 34,
    rename = 35,
    mkdir = 36,
    opendir = 37,
    readdir = 38,
    closedir = 39,
    
    // Time & Scheduling
    clock_gettime = 40,
    sleep_until = 41,
    
    // System Information
    sysinfo = 50,
    
    // Input Events (for Grain Terminal)
    read_input_event = 60,
    
    // Framebuffer Operations (for Grain Terminal)
    fb_clear = 70,
    fb_draw_pixel = 71,
    fb_draw_text = 72,
    
    // Signal Operations
    kill = 80,
    signal = 81,
    sigaction = 82,
};

// Memory mapping flags (for Grain Terminal/Grainscript)
pub const MapFlags = packed struct {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
    shared: bool = false,
    _padding: u28 = 0,
};

// File open flags (for Grainscript file I/O)
pub const OpenFlags = packed struct {
    read: bool = false,
    write: bool = false,
    create: bool = false,
    truncate: bool = false,
    _padding: u28 = 0,
};
```

**How to Use Kernel Syscalls from RISC-V Code**:

1. **Compile your application for RISC-V**: Use `zig build-exe` with `-target riscv64-linux` or similar
2. **Make syscalls via ECALL instruction**: Set `a7` (x17) register to syscall number, `a0-a5` (x10-x15) for arguments
3. **Return value in `a0`**: Kernel returns result in `a0` register (success value or error code)
4. **Error handling**: Check return value; negative values indicate errors (see `BasinError` enum)

**Example RISC-V Assembly for Syscall**:
```asm
# Example: syscall_map(addr, size, flags)
li a7, 10        # Syscall number for 'map'
li a0, 0x100000  # Address (arg1)
li a1, 4096      # Size (arg2)
li a2, 0b111     # Flags: read|write|execute (arg3)
ecall            # Make syscall
# Result in a0: 0 on success, error code on failure
```

**Important**: 
- All syscalls must follow RISC-V calling convention
- Memory addresses must be within VM memory bounds (0 to VM_MEMORY_SIZE)
- File paths must be null-terminated strings in VM memory
- All syscall arguments are validated by the kernel (bounds checking, permission checking)

---

## Grain Skate Project Specification

### Project Overview

**Grain Skate** is a native macOS knowledge graph application with social threading capabilities, implemented in Zig 0.15.2 for macOS Tahoe 26.1.

### Core Requirements

#### Data Structure

- **DAG (Directed Acyclic Graph)** for thought relationships
- **Block-based content** with transclusion capabilities
- **Quote/reply threading** with embedded recursion
- **UUID-based reference system** for cross-post linking

#### User Interface

- Native macOS UI with **Vim/Kakoune keybindings**
- **Keyboard-driven navigation** (modal editing)
- **Minimalist writing mode** (Goyo-inspired)
- **Tree/sidebar navigation** (Nerdtree-like)
- **Real-time graph visualization**

#### Social Features

- Copy/paste existing post links as replies
- Embedded recursive content structures
- **Local-first architecture** with optional sync
- Thread collapsing/expansion

### Technical Specifications

- **Language**: Zig 0.15.2
- **Target**: macOS Tahoe 26.1 (native desktop application)
- **Architecture**: TigerBeetle TigerStyle + GrainStyle modifications
- **Code Style**: `grain_case` function names, explicit types, bounded allocations

### Implementation Priorities

#### Phase 1: Core Engine

- Zig DAG data structures (may leverage `src/dag_core.zig` as reference)
- Block storage and linking
- Basic text editing with Vim bindings

#### Phase 2: UI Framework

- Native macOS window management
- Modal editing system
- Graph visualization

#### Phase 3: Social Features

- Link-based reply system
- Transclusion engine
- Export/import capabilities

### Technical Constraints

- **Zero allocations in hot paths**
- **Crash-only design principles**
- **SIMD-optimized text operations**
- **Memory-mapped block storage**
- **Arena allocators for graph operations**
- **No dependencies** (libc-free where possible)
- **Explicit error handling** (no payload-less errors)

---

## Grain Terminal Project Specification

### Project Overview

**Grain Terminal** is a general-purpose terminal application (like iTerm2, macOS Terminal, or Wezterm) that runs entirely within Grain OS Grain Kernel within Grain Vantage VM. It will be a Grain app that targets Zig compilation for the Grain Kernel that targets RISC-V to run in the Vantage VM.

### Core Requirements

- **Wezterm-level feature completeness**: tabs, panes, split windows, themes, fonts, etc.
- **RISC-V target**: Must compile for RISC-V and run in Grain Vantage VM
- **Grain Kernel integration**: Must work with Grain Basin Kernel
- **Performance**: 60fps rendering, sub-millisecond input latency
- **Grain Aurora rendering**: Use Grain Aurora components for UI

### Technical Specifications

- **Language**: Zig 0.15.2
- **Target**: RISC-V (for Grain Kernel) + macOS Tahoe 26.1 (for development)
- **Architecture**: TigerBeetle TigerStyle + GrainStyle modifications
- **Rendering**: Grain Aurora components (similar to Dream Browser)

### Implementation Priorities

#### Phase 1: Terminal Core

- Terminal emulation (VT100/VT220 subset)
- Character cell rendering
- Scrollback buffer
- Input handling

#### Phase 2: UI Features

- Tabs and panes
- Split windows
- Themes and fonts
- Configuration

#### Phase 3: Advanced Features

- Session management
- Scripting integration (Grainscript)
- Plugin system

---

## Grainscript Project Specification

### Project Overview

**Grainscript** is a general-purpose Zig-implemented Zig scripting language/DSL to replace Bash, Zsh, and Fish. Files use `.gr` extension.

**Core Vision**: Grainscript unifies all configuration and data file formats into a single, statically-typed, explicitly-allocated, GrainStyle/TigerStyle-compliant DSL. It replaces not just shell scripts, but also configuration files, data formats, and build systems with one unified language.

### Core Requirements

- **Zig-like syntax**: Familiar to Zig developers
- **Shell-like functionality**: Commands, pipes, redirection
- **Type safety**: Leverage Zig's type system
- **Performance**: Fast startup and execution
- **Integration**: Works with Grain Terminal
- **Unified configuration format**: Replace all config/data file formats

### Unified Format Goals

Grainscript must be able to represent and generate:

1. **Data Formats**:
   - Clojure `.edn` data files
   - JSON
   - YAML
   - TOML

2. **Configuration Files**:
   - Dockerfiles
   - AWS Terraform for EKS configs
   - Kubernetes configs (with TigerBeetle-style general-purpose GrainDB research for distributed database on WSE chips)
   - `.gitignore`, `.cursorignore`, `.claude` files/folders
   - Dotfiles generally (`.zshrc`, `.bashrc`, `.vimrc`, `.emacs`, etc.)
   - SSH configs (`~/.ssh/config`)
   - Global Git configs (`~/.gitconfig`)
   - GPG configs (`~/.gnupg/gpg.conf`)

3. **Build Systems**:
   - Makefiles
   - Build scripts
   - Boot scripts
   - Systemd unit files

4. **Any kind of data/parameters/configurations**: Grainscript should be expressive enough to represent any structured or semi-structured data format.

### Design Principles

- **Static typing**: All values must have explicit types (no `any` types)
- **Explicit allocation**: All memory allocation must be explicit (GrainStyle/TigerStyle)
- **Zero hidden allocations**: No implicit allocations in hot paths
- **Bounded structures**: All data structures must have `MAX_` constants
- **Deterministic**: Same input always produces same output
- **Composable**: Can embed Grainscript in Grainscript (recursive structures)
- **Serializable**: Can serialize to/from any target format (JSON, YAML, etc.)

### Technical Specifications

- **Language**: Zig 0.15.2 (implementation language)
- **Target Language**: Grainscript (`.gr` files)
- **Architecture**: TigerBeetle TigerStyle + GrainStyle modifications
- **Parser**: May use Tree-sitter (similar to Aurora IDE)
- **Memory Model**: Explicit allocation, bounded structures, static allocation preferred

### Implementation Priorities

#### Phase 1: Core Language

- Lexer and parser
- Basic command execution
- Variable handling
- Control flow
- Type system (explicit types, no `any`)

#### Phase 2: Shell Features

- Pipes and redirection
- Background jobs
- Signal handling
- Environment variables
- File I/O (explicit, bounded)

#### Phase 3: Configuration Format

- Data structure representation (JSON-like, YAML-like, EDN-like)
- Serialization to target formats (JSON, YAML, TOML, etc.)
- Deserialization from target formats
- Configuration validation (type checking)

#### Phase 4: Advanced Features

- Functions and modules
- Standard library
- Integration with Grain Terminal
- Format converters (`.gr` → JSON, YAML, etc.)
- Format importers (JSON → `.gr`, YAML → `.gr`, etc.)

#### Phase 5: Specialized Formats

- Dockerfile generation
- Kubernetes config generation
- Terraform config generation
- Dotfile management
- SSH config management
- Git config management
- GPG config management

---

## Context: VM/Kernel Work (Separate from Your Tasks)

### What the VM/Kernel Agent Has Built

The **VM/Kernel agent** has implemented:

1. **Grain Vantage VM** (`src/kernel_vm/vm.zig`):
   - RISC-V64 emulator for kernel development
   - JIT compiler for performance (ARM64 native code generation)
   - Framebuffer support (1024x768, 32-bit RGBA)
   - Input event queue (keyboard and mouse events)
   - Memory protection and address translation
   - Exception statistics and error logging
   - Performance monitoring and diagnostics
   - State persistence (save/restore VM state)

2. **Grain Basin Kernel** (`src/kernel/basin_kernel.zig`):
   - Non-POSIX kernel for RISC-V64
   - Process management (spawn, exit, wait, yield)
   - Memory management (map, unmap, protect syscalls)
   - Page table implementation (4KB pages, permissions)
   - Copy-on-Write (COW) for memory sharing
   - File I/O (open, read, write, close, unlink, rename, mkdir, opendir, readdir, closedir)
   - IPC channels (channel_create, channel_send, channel_recv)
   - Timer and scheduling (clock_gettime, sleep_until)
   - Input events (read_input_event syscall)
   - Framebuffer operations (fb_clear, fb_draw_pixel, fb_draw_text)
   - Signal handling (kill, signal, sigaction)
   - Exception handling and page fault statistics
   - Memory usage statistics

3. **Integration Layer** (`src/kernel_vm/integration.zig`):
   - Bridges VM syscall interface with kernel syscall interface
   - Memory permission checking
   - ELF loading for userspace programs

### How This Relates to Your Work

**Your work is separate** but must integrate with:

1. **Grain Terminal**:
   - **MUST compile for RISC-V** and run in Grain Vantage VM
   - **MUST use kernel syscalls** for I/O, framebuffer, and input events
   - **MUST target Grain Basin Kernel** (not POSIX)
   - Can use VM framebuffer API for rendering
   - Can use kernel input event syscall for keyboard/mouse input
   - Can use kernel file I/O syscalls for configuration and session management

2. **Grainscript**:
   - **MUST work with kernel syscalls** for file I/O, process management, IPC
   - **MUST compile to RISC-V** for execution in Grain Vantage VM
   - Can use kernel process management syscalls (spawn, exit, wait)
   - Can use kernel file I/O syscalls (open, read, write, close)
   - Can use kernel IPC syscalls (channel_create, channel_send, channel_recv)
   - Should generate RISC-V assembly or use Zig's RISC-V codegen

3. **Grain Skate**:
   - **May use kernel file I/O** for persistence (if running in VM)
   - **May use kernel memory mapping** for block storage (if running in VM)
   - **May use kernel IPC** for synchronization (if running in VM)
   - **Primary target**: Native macOS (not VM), but should be designed to work in VM if needed

### API Contracts You Should Know

See the detailed API documentation above in the "API Contracts You Should Know" section.

**Key Points**:
- All syscalls use RISC-V calling convention (a7 = syscall number, a0-a5 = arguments, a0 = return value)
- Memory addresses must be within VM bounds (0 to VM_MEMORY_SIZE = 8MB)
- File paths must be null-terminated strings in VM memory
- All syscalls are validated by the kernel (bounds checking, permission checking)
- Framebuffer is at address `0x90000000` (1024x768, 32-bit RGBA)
- Input events are queued in VM and read via `read_input_event` syscall

---

## Coordination with Other Agents

### Aurora IDE / Dream Browser Agent

- **Status**: Working on Phase 5.2 (Advanced Browser Features) - mostly complete
- **Current Focus**: Tab management enhancements
- **Integration Points**:
  - Grain Terminal may use similar rendering techniques
  - Grainscript may use Tree-sitter (already implemented)
  - Grain Skate may use DAG core (already implemented)
- **Coordination**: Check in before modifying shared modules (`src/dag_core.zig`, `src/grain_aurora.zig`)

### VM/Kernel Agent

- **Status**: Working on Grain Basin Kernel, Grain Vantage VM (RISC-V emulator), exception handling, memory protection, page tables, COW (Copy-on-Write)
- **Current Focus**: Phase 3.12 complete - Memory Sharing and Copy-on-Write (COW), page fault statistics, memory usage statistics, page table implementation
- **Integration Points**:
  - **Grain Terminal** must target RISC-V and Grain Kernel (compile for RISC-V, use kernel syscalls)
  - **Grainscript** must work with kernel syscalls (file I/O, process management, IPC)
  - **Grain Skate** may use kernel features for persistence (file I/O, memory mapping)
- **Coordination**: Check in before making kernel-level changes or adding new syscalls

### When to Check In

- Before modifying shared modules (`src/dag_core.zig`, `src/grain_aurora.zig`, `src/kernel/*.zig`)
- Before adding new kernel syscalls
- Before changing API contracts that other agents depend on
- When you need information about existing implementations

---

## File Structure

Your work should be organized as follows:

```
src/
├── grain_terminal/          # Grain Terminal implementation
│   ├── terminal.zig         # Terminal emulation core
│   ├── renderer.zig         # Rendering engine
│   ├── input.zig            # Input handling
│   └── ...
├── grainscript/             # Grainscript implementation
│   ├── lexer.zig            # Lexer
│   ├── parser.zig           # Parser
│   ├── interpreter.zig      # Interpreter
│   └── ...
└── grain_skate/             # Grain Skate implementation
    ├── dag.zig              # DAG data structures
    ├── blocks.zig           # Block storage
    ├── vim.zig              # Vim keybindings
    ├── ui.zig               # UI framework
    └── ...
```

---

## Success Criteria

### Grain Terminal

1. Start-up < 50ms on M2 Max
2. 60fps rendering on 4K display
3. Sub-millisecond input latency
4. RISC-V compilation successful
5. All tests passing with GrainStyle compliance

### Grainscript

1. Parse and execute basic `.gr` files
2. Shell-like functionality (pipes, redirection)
3. Fast startup (< 10ms)
4. All tests passing with GrainStyle compliance

### Grain Skate

1. Start-up < 50ms on M2 Max
2. 1,000,000 blocks ingest < 30s, memory stay < 300MB
3. Vim normal-mode navigation 60fps on 4K display
4. All tests passing with GrainStyle compliance

---

## Development Workflow

1. **Read existing code**: Understand Aurora IDE and Dream Browser implementations as reference
2. **Follow GrainStyle**: Strict adherence to TigerStyle + GrainStyle modifications
3. **Write tests**: Every feature must have comprehensive tests
4. **Update documentation**: Keep `docs/plan.md` and `docs/tasks.md` updated
5. **Coordinate**: Check in with other agents before making shared changes

---

## Multi-AI Synthesis: Grain Skate Vision

The following is a synthesis of multiple AI perspectives on Grain Skate:

### Deepseek Perspective

- DAG for thought relationships
- Block-based content with transclusion
- Quote/reply threading with embedded recursion
- UUID-based reference system
- Native macOS UI with Vim/Kakoune keybindings
- Keyboard-driven navigation (modal editing)
- Minimalist writing mode (Goyo-inspired)
- Tree/sidebar navigation (Nerdtree-like)
- Real-time graph visualization
- Copy/paste existing post links as replies
- Embedded recursive content structures
- Local-first architecture with optional sync
- Thread collapsing/expansion

### Gemini Perspective

- **The "Grain" Data Layout**: TigerStyle struct definition for atomic block unit, optimized for cache locality and zero-copy persistence
- **Memory Strategy**: Map DAG to memory without `malloc`, using slab allocators or static buffers
- **The "Skate" Event Loop**: Main loop handling Kqueue (macOS) and custom render loop, ensuring sub-millisecond input latency for Vim bindings
- **Persistence**: Append-only log format (WAL) for syncing grains

### Grok Perspective

- Complete, self-contained project in Zig 0.15.2
- Minimal viable prototype demonstrating core functionality
- Command-line tool or GUI app
- Cross-platform compatibility with focus on macOS
- Compilable and runnable on macOS Tahoe 26.1 without external dependencies

### Kimi Perspective

- Every identifier is `snake_case`, never `camelCase`
- 100-column hard limit; 80 preferred
- No `var` at file scope; everything is `const` or `comptime`
- Prefer `u32`, `u64`, `i64`; never `usize` for business data
- All I/O must be async (io_uring style) wrapped in `xio` namespace
- Panic only via `std.debug.panic("grain: {s}", .{reason});`
- Logging: `log.grain.debug|info|warn|err()` – never `std.log`
- Errors are exhaustive: `error{Foo,Bar}!T` – no `anyerror`
- Tests live beside code: `test "grain.foo"` in the same file
- Benchmarks: `bench "grain.foo"` – compile with `-Dgrain-bench`
- Commit messages: `grain: <verb> <what>` – 50-char first line

### Qwen Perspective

- Minimalist composability
- Cache-line-aware data layout
- Branch-predictor-friendly hot paths
- Self-documenting state machines (explicit enum-tagged unions over pointers)
- Zero varargs, no generic metaprogramming tricks
- Prefer comptime-checked invariants over runtime asserts
- Every struct must have a clear owner and lifetime scope
- All I/O must be explicit, async via `std.Thread.Futex`-based cooperative scheduling or `kqueue`-driven event loops

---

## Next Steps

1. **Review this prompt** and understand your responsibilities
2. **Review existing code** in `src/aurora_*.zig` and `src/dream_browser_*.zig` for reference
3. **Start with Phase 1** of your chosen project (Grain Terminal, Grainscript, or Grain Skate)
4. **Follow GrainStyle** strictly throughout
5. **Write tests** for every feature
6. **Update documentation** as you progress
7. **Coordinate** with other agents when needed

---

## Questions?

If you have questions about:
- Existing implementations: Review `src/aurora_*.zig` and `src/dream_browser_*.zig`
- API contracts: Check the API documentation in those files
- Coordination: Ask before modifying shared modules
- GrainStyle: Reference TigerStyle guide and existing code

---

**Good luck! Build something amazing.** 🪵⛸️

