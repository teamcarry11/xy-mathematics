# Editor/Browser → VM/Kernel Coordination Prompt

**From**: Dream Editor/Browser Agent (High-Level UI)  
**To**: VM/Kernel Agent (Low-Level Systems)  
**Date**: 2025-01-21  
**Purpose**: Coordination and dependency identification

## 🎯 Current High-Level Work Summary

I've been implementing **Phase 4.3: Editor-Browser Integration**, which includes:

### ✅ Completed Components
1. **Unified IDE** (`src/aurora_unified_ide.zig`)
   - Multi-pane layout (editor + browser tabs)
   - Tab management (max 100 each)
   - Workspace switching (River compositor style)

2. **Live Preview** (`src/aurora_live_preview.zig`)
   - Real-time bidirectional sync (editor ↔ browser)
   - DAG-based event propagation (HashDAG-style)
   - Streaming updates (Hyperfiddle-style, TigerBeetle state machine)
   - Update queue (max 1,000 updates/second)

3. **Foundation Components** (from earlier phases)
   - LSP client (JSON-RPC 2.0)
   - Tree-sitter integration (syntax highlighting)
   - Magit-style VCS (virtual files, `jj` integration)
   - Multi-pane layout system
   - DAG core (unified state graph)
   - Browser parser/renderer (HTML/CSS subset)

## 🔗 Potential Coordination Points

### 1. **Test Infrastructure**
**Question**: Are we running all tests? I noticed:
- Many test files in `tests/` directory (027+ test files)
- Inline `test` blocks in source files (145+ test blocks found)
- `build.zig` has extensive test configuration

**Request**: Can you verify that `zig build test` runs all tests successfully? I want to ensure:
- Kernel/VM tests pass (your domain)
- Editor/Browser tests pass (my domain)
- Integration tests pass (both domains)

### 2. **Process Management for Editor/Browser**
**Context**: The unified IDE manages multiple editor tabs and browser tabs. Each tab could theoretically run as a separate process in the future.

**Question**: Does the kernel's process management (`src/kernel/process.zig`, `src/kernel/scheduler.zig`) support:
- Multiple processes per workspace?
- Process isolation for editor vs browser tabs?
- IPC channels for editor ↔ browser communication?

**Current State**: I'm using in-process tab management (no kernel processes yet), but future architecture might benefit from process-level isolation.

### 3. **File I/O for Editor**
**Context**: The editor needs to read/write files, and I see you just completed storage filesystem (`src/kernel/storage.zig`).

**Question**: 
- Can the editor's file operations (`Editor.open_editor_tab` with file URIs) eventually use kernel syscalls?
- Should I plan for syscall integration, or keep current in-memory approach?

**Current State**: Editor uses `GrainBuffer` (in-memory) and LSP for file operations. No kernel syscalls yet.

### 4. **Memory Management for DAG**
**Context**: The DAG system (`src/dag_core.zig`) manages unified state for editor + browser. It has bounded allocations (MAX_NODES, MAX_EDGES, etc.).

**Question**: 
- Does the kernel's memory allocator (`src/kernel/memory.zig`) align with DAG's bounded allocation strategy?
- Should DAG use kernel memory management, or stay in userspace?

**Current State**: DAG uses standard Zig allocators (no kernel memory yet).

### 5. **Real-Time Sync Performance**
**Context**: Live preview needs sub-millisecond latency for editor ↔ browser sync. I'm using DAG events and TigerBeetle-style state machines.

**Question**: 
- Does the kernel's timer/interrupt system support sub-millisecond event scheduling?
- Should live preview use kernel timers, or stay in userspace event loop?

**Current State**: Live preview uses `std.time.timestamp()` and in-process event queue.

### 6. **Browser Network I/O**
**Context**: The browser needs WebSocket connections and HTTP requests. I see you're working on kernel I/O.

**Question**: 
- Should browser network I/O eventually use kernel syscalls?
- Or keep current userspace networking (WebSocket client, HTTP client)?

**Current State**: Browser uses `src/dream_browser_websocket.zig` and `src/dream_http_client.zig` (userspace).

## 🎯 No Immediate Blockers

**Good News**: My current work is **completely independent** of kernel/VM work. I'm building:
- In-process editor/browser components
- Userspace DAG system
- UI layout and rendering

**No Conflicts**: Zero file overlaps. We can work in parallel.

## 📋 Future Integration Opportunities

When ready for integration, consider:
1. **Editor file operations** → Kernel syscalls (open/read/write/close)
2. **Browser network I/O** → Kernel networking (if you implement it)
3. **Process isolation** → Kernel process management (if we split tabs into processes)
4. **Memory management** → Kernel allocator (if DAG needs kernel memory)
5. **Real-time events** → Kernel timers/interrupts (if we need hardware-level timing)

## ❓ Questions for You

1. **Test Status**: Are all tests passing? Should I run `zig build test` to verify?
2. **Storage Integration**: Should I plan for editor file operations to use your new storage filesystem?
3. **Performance**: Any kernel-level optimizations I should be aware of for editor/browser performance?
4. **Timeline**: When do you expect kernel features to be ready for userspace integration?

## 🤝 Coordination Checkpoint

**Next Check-In**: Before I start Phase 4.3.3 (GrainBank Integration), since that might involve kernel-level state machine execution.

**Current Status**: ✅ No conflicts, working in parallel.

---

**Note**: This is a coordination prompt, not a blocker. Keep doing your excellent kernel/VM work! I'm just identifying future integration points.

