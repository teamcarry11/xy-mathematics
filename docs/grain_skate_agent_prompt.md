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

### Core Requirements

- **Zig-like syntax**: Familiar to Zig developers
- **Shell-like functionality**: Commands, pipes, redirection
- **Type safety**: Leverage Zig's type system
- **Performance**: Fast startup and execution
- **Integration**: Works with Grain Terminal

### Technical Specifications

- **Language**: Zig 0.15.2 (implementation language)
- **Target Language**: Grainscript (`.gr` files)
- **Architecture**: TigerBeetle TigerStyle + GrainStyle modifications
- **Parser**: May use Tree-sitter (similar to Aurora IDE)

### Implementation Priorities

#### Phase 1: Core Language

- Lexer and parser
- Basic command execution
- Variable handling
- Control flow

#### Phase 2: Shell Features

- Pipes and redirection
- Background jobs
- Signal handling
- Environment variables

#### Phase 3: Advanced Features

- Functions and modules
- Type system
- Standard library
- Integration with Grain Terminal

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

- **Status**: Working on Grain Basin Kernel, RISC-V VM, exception handling, memory protection
- **Current Focus**: Page fault statistics, memory stats, COW (Copy-on-Write)
- **Integration Points**:
  - Grain Terminal must target RISC-V and Grain Kernel
  - Grainscript must work with kernel syscalls
  - Grain Skate may use kernel features for persistence
- **Coordination**: Check in before making kernel-level changes

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

