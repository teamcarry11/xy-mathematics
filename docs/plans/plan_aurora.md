# Aurora IDE Dream Browser Agent: Development Plan

**Agent**: Grain Aurora IDE Dream Browser Agent (2nd Agent)  
**Status**: Active — Foundation components, shared modules  
**Last Updated**: 2025-12-06-045220-pst

---

## Overview

Grain Aurora IDE Dream Browser Agent is responsible for building the unified IDE combining Matklad-inspired editor with Nostr-native browser, using GLM-4.6 for agentic coding at 1,000 tokens/second.

**Key Goals**:
- Unified IDE combining editor and browser in multi-pane layout
- LSP (Language Server Protocol) integration for code intelligence
- AI provider abstraction for code completion and refactoring
- Shared module refactoring (font renderer, text buffer, DAG, UI rendering)
- DAG integration for event ordering and consensus

---

## Completed Phases

### Phase 0: Shared Foundation ✅ **COMPLETE**

**Objective**: Build shared components for both editor and browser.

#### 0.1: GrainBuffer Enhancement ✅ **COMPLETE**
- ✅ Increased readonly segments from 64 to 1000
- ✅ Added span query functions (`isReadOnly`, `getReadonlySpans`)
- ✅ Binary search optimization for large segment lists
- ✅ Comprehensive assertions (GrainStyle compliance)
- **Files**: `src/grain_buffer.zig`

#### 0.2: GLM-4.6 Client ✅ **COMPLETE**
- ✅ Client structure created
- ✅ HTTP client foundation created
- ✅ HTTP implementation (JSON serialization, SSE streaming)
- ✅ Integration with Cerebras API
- **Files**: `src/aurora_glm46.zig`, `src/dream_http_client.zig`

#### 0.3: Dream Protocol ✅ **COMPLETE**
- ✅ Nostr event structure (Zig-native)
- ✅ WebSocket client (low-latency, frame parsing)
- ✅ State machine foundation (TigerBeetle-style)
- ✅ Event streaming structure (real-time ready)
- **Files**: `src/dream_protocol.zig`, `src/dream_nostr.zig`, `src/dream_websocket.zig`

#### 0.4: DAG Core Foundation ✅ **COMPLETE**
- ✅ Core DAG data structure (`src/dag_core.zig`)
- ✅ Nodes, edges, events (HashDAG-style)
- ✅ TigerBeetle-style state machine execution
- ✅ Bounded allocations (max 10,000 nodes, 100,000 edges)
- ✅ Comprehensive assertions (GrainStyle compliance)
- ✅ Tests for initialization, node/edge/event operations

### Phase 1: Dream Editor Core ✅ **COMPLETE**

**Objective**: Matklad-inspired editor with GLM-4.6 integration.

#### 1.1: Readonly Spans Integration ✅ **COMPLETE**
- ✅ Integrated enhanced GrainBuffer into editor
- ✅ Edit protection (prevents modifications to readonly spans)
- ✅ Visual rendering (readonly spans returned in render result)
- ✅ Cursor handling (insert checks for readonly violations)
- **Files**: `src/aurora_editor.zig`, `src/grain_buffer.zig`

#### 1.2: Method Folding ✅ **COMPLETE**
- ✅ Parse code structure (regex-based for Zig functions/structs)
- ✅ Identify method/function boundaries
- ✅ Fold bodies by default, show signatures
- ✅ Toggle folding (keyboard shortcut ready)
- ✅ Visual indicators (fold state tracking)
- **Files**: `src/aurora_folding.zig`, `src/aurora_editor.zig`

#### 1.3: GLM-4.6 Integration ✅ **COMPLETE**
- ✅ Code completion (ghost text at 1,000 tps integrated)
- ✅ Editor integration (GLM-4.6 client optional, falls back to LSP)
- ✅ Code transformation (refactor, extract, inline)
- ✅ AI Provider Abstraction
- ✅ Tool calling (run `zig build`, `jj status`)
- ✅ Multi-file edits (context-aware)
- **Files**: `src/aurora_glm46.zig`, `src/aurora_ai_provider.zig`, `src/aurora_glm46_provider.zig`, `src/aurora_ai_transforms.zig`

#### 1.4: Complete LSP Implementation ✅ **COMPLETE**
- ✅ JSON-RPC 2.0 serialization/deserialization
- ✅ Snapshot model (incremental updates, Matklad-style)
- ✅ Cancellation support for pending requests
- ✅ Server communication (stdin/stdout with Content-Length headers)
- ✅ Document lifecycle (didOpen, didChange with incremental edits)
- ✅ GrainStyle compliance (u32 types, assertions, bounded allocations)
- **Files**: `src/aurora_lsp.zig`, `src/aurora_editor.zig`

#### 1.5: LSP Visual Rendering Features ✅ **COMPLETE**
- ✅ Diagnostics visual rendering (error/warning/info/hint squiggles)
- ✅ Inlay hints visual rendering (parameter names, type hints)
- ✅ Code lens visual rendering (references, test commands)
- ✅ Document highlights visual rendering (symbol occurrences)
- ✅ Semantic tokens visual rendering (fine-grained syntax highlighting)
- ✅ Folding ranges visual rendering (code folding indicators)
- ✅ Selection ranges visual rendering (expand text selection)
- ✅ Document links visual rendering (clickable hyperlinks)
- **Files**: `src/aurora_editor.zig`, `src/grain_aurora.zig`

#### 1.6: RenderResult Grain/Tiger Style Refactoring ✅ **COMPLETE**
- ✅ Refactored `RenderResult` to use fixed-size arrays instead of dynamic allocations
- ✅ Defined `MAX_` constants for span counts and string lengths
- ✅ Modified span structs to use fixed-size `[N]u8` arrays for strings
- ✅ Removed `deinit` method (no dynamic allocations)
- ✅ Added helper methods for accessing spans as slices
- ✅ Updated `render()` method to use fixed-size arrays with bounds checking
- ✅ GrainStyle compliance (bounded allocations, u32 types, assertions)
- **Files**: `src/grain_aurora.zig`, `src/aurora_editor.zig`

#### 1.7: Grain/Tiger Style Compliance (usize → u32) ✅ **COMPLETE**
- ✅ Replaced all `usize` types with `u32` in span structures
- ✅ Updated `GrainAurora.Span`, `DiagnosticSpan`, `InlayHintSpan`, etc.
- ✅ Updated `GrainBuffer.Segment` to use `u32` for start/end
- ✅ Fixed `ghost_end` calculation to use `u32`
- ✅ GrainStyle compliance (explicit types, no platform-specific `usize`)
- **Files**: `src/grain_aurora.zig`, `src/grain_buffer.zig`, `src/aurora_editor.zig`

#### 1.8: Magit-Style VCS ✅ **COMPLETE**
- ✅ Generate `.jj/status.jj` (readonly metadata, editable hunks)
- ✅ Generate `.jj/commit/*.diff` (readonly commit info, editable diff)
- ✅ Watch for edits, invoke `jj` commands
- ✅ Readonly spans for commit hashes, parent info, file paths, diff headers
- ✅ Parse `jj status` and `jj diff` output
- **Files**: `src/aurora_vcs.zig`, `src/aurora_vfs.zig`

#### 1.9: Editor Enhancements ✅ **COMPLETE**
- ✅ File save/load functionality
- ✅ Enhanced error handling
- ✅ Undo/redo functionality (bounded history: MAX_UNDO_HISTORY: 1024)
- ✅ Go-to-definition support
- ✅ Hover support
- ✅ Ghost text rendering (AI completions)
- **Files**: `src/aurora_editor.zig`

### Phase 2: Shared Module Refactoring ✅ **IN PROGRESS**

**Objective**: Unify shared components across applications (Grain Skate, Aurora, Grain Core).

#### 2.1: Font Renderer Unification (Phase 1.2) ✅ **COMPLETE**
- ✅ Migrated `src/aurora_text_renderer.zig` to use shared font renderer
- ✅ Replaced custom `getCharPattern()` with shared font renderer API
- ✅ Updated `TextRenderer` to use `shared.FontRenderer` (8x8 font, ASCII basic)
- ✅ Added `init()` method for proper initialization
- ✅ Updated `draw_char()` to use `render_char_to_pixels()` from shared module
- ✅ Removed duplicate font pattern code (195 lines removed)
- ✅ Updated test to use `TextRenderer.init()` API
- ✅ Added shared module import to build.zig test configuration
- ✅ GrainStyle compliance (grain_case, u32 types, max 70 lines per function, max 73 chars per line)
- **Files**: `src/aurora_text_renderer.zig`, `build.zig`
- **Date**: 2025-12-03-162659-PST

#### 2.2: Layout System Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/112_aurora_layout_test.zig`)
- ✅ Tests for workspace creation, pane splitting (horizontal/vertical)
- ✅ Tests for focus navigation, pane resizing, workspace switching
- ✅ Tests for bounded allocations (MAX_PANES, MAX_WORKSPACES)
- ✅ Tests for pane tree structure and focus management
- ✅ Added `aurora_layout_module` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/112_aurora_layout_test.zig`, `build.zig`
- **Date**: 2025-12-04-095411-PST

---

## Current Work: Phase 2 - Shared Module Refactoring (Continued)

**Priority**: **HIGH** — Code deduplication, shared maintenance  
**Status**: **IN PROGRESS** — Phase 1.2 (Font Renderer) Complete  
**Estimated Time**: Ongoing (multi-phase)

### Why This Phase

Shared module refactoring eliminates code duplication and enables shared maintenance. Font renderer migration (Phase 1.2) is complete, removing 195 lines of duplicate code.

### Features

- **Font Renderer Unification** (Phase 1.2) ✅ Complete
- **Text Buffer Unification** (Phase 2) — Planned
- **DAG Integration** (Phase 3) — Planned
- **UI Rendering Unification** (Phase 4) — Planned

### Deliverables

- ✅ Shared font renderer migration (Phase 1.2)
- 📋 Text buffer unification (Phase 2)
- 📋 DAG integration (Phase 3)
- 📋 UI rendering unification (Phase 4)

### Dependencies

- **Needs**: Shared font renderer from Grain Skate Agent (Phase 1) ✅ Complete
- **Provides**: Font renderer migration example for Grain Core Agent (Phase 1.3)
- **Coordinates with**: Grain Skate Agent (shared module plan), Grain Core Agent (font renderer migration)

---

## Planned Phases

### Phase 3: Text Buffer Unification (Planned)

**Objective**: Migrate Grain Skate editor to use `GrainBuffer` from `src/grain_buffer.zig`.

**Features**:
- Grain Skate gets readonly spans support
- Unified text buffer API across applications
- Shared maintenance benefits

**Dependencies**:
- **Needs**: Grain Skate Agent coordination
- **Provides**: `GrainBuffer` API for Grain Skate

**Grain Style Compliance**:
- ✅ **GrainBuffer u32/u64 Compliance** (2025-12-06-004609-pst) — Complete
- Updated all `usize`/`isize` to `u32`/`u64`/`i64` in `GrainBuffer`
- Updated `Segment` struct to use `u32` for `start` and `end`
- Updated all function signatures to use `u32`/`u64`/`i64`
- Updated `aurora_editor.zig` to use `u32` for GrainBuffer operations
- All tests updated to use `u32`
- **Unblocks**: Phase 2 Text Buffer Unification (no adapter layer needed)

### Phase 4: DAG Integration (Planned)

**Objective**: Integrate DAG for event ordering and consensus.

**Features**:
- Event ordering for editor and browser
- Consensus mechanism for collaborative editing
- State synchronization

**Dependencies**:
- **Needs**: DAG Core (Phase 0.4) ✅ Complete
- **Provides**: DAG integration example

### Phase 5: UI Rendering Unification (Planned)

**Objective**: Evaluate `GrainAurora` component-first rendering for Grain Skate.

**Features**:
- Component-based UI rendering
- Unified rendering API
- Shared UI components

**Dependencies**:
- **Needs**: Grain Skate Agent evaluation
- **Provides**: `GrainAurora` component API

---

## Coordination Points

### With Grain Core Agent

**Shared Components**:
- Font renderer (Phase 1.2 complete, Phase 1.3 pending for Grain Core)
- Text buffer (planned)
- DAG (planned)
- UI rendering (planned)

**Integration Points**:
- Shared font renderer API (`src/shared/font_renderer.zig`)
- Build system integration (`build.zig`)
- WebSocket support (Phase 61 complete) — Available for future use

**WebSocket Support**:
- ✅ Grain Core Agent Phase 61 (WebSocket Support) — Complete
- Note: Aurora Agent currently uses stdio for LSP (standard) and has WebSocket for Dream Protocol (Phase 0.3)
- Future: May use Core Agent WebSocket for additional real-time features

**File Storage Support**:
- ✅ Grain Core Agent Phase 62 (File Storage Core) — Complete
- ✅ Grain Core Agent Phase 62 (Transaction Log/WAL) — Complete
- ✅ Grain Core Agent Phase 62 (Index Manager) — Complete
- Note: Aurora Agent does not directly use file storage (uses in-memory buffers)
- Future: May use file storage for editor state persistence if needed

**Grain Style u32/u64 Enforcement**:
- ✅ **Aurora Agent Fully Compliant** (2025-12-06-004609-pst)
- ✅ GrainBuffer updated to use `u32`/`u64` instead of `usize`/`isize`
- ✅ All Aurora Agent code uses explicit types (`u32`/`u64`, no `usize`/`isize`)
- ✅ Remaining `usize` in GrainBuffer are only for `std.ArrayListUnmanaged` conversions (acceptable)
- ✅ Verified: No `usize`/`isize` in `src/aurora/` directory

**Coordination Tasks**:
- ✅ Font renderer migration (Phase 1.2) — Complete
- 📋 Grain Core Agent font renderer migration (Phase 1.3) — Pending
- 📋 Text buffer unification coordination — Planned
- 📋 DAG integration coordination — Planned
- 📋 UI rendering unification coordination — Planned

### With Grain Skate Agent

**Shared Components**:
- Font renderer (Phase 1 complete, Phase 1.4 pending for Grain Skate)
- Text buffer (Phase 2 planned)
- DAG (Phase 3 planned)
- UI rendering (Phase 4 planned)

**Integration Points**:
- Shared module refactoring plan (`docs/grain_skate_future_enhancements.md`)
- Shared font renderer API

**Coordination Tasks**:
- ✅ Font renderer creation (Phase 1) — Complete
- 📋 Grain Skate Agent font renderer migration (Phase 1.4) — Pending
- 📋 Text buffer unification (Phase 2) — Planned
- 📋 DAG integration (Phase 3) — Planned
- 📋 UI rendering unification (Phase 4) — Planned

### With Other Agents

**Vantage Agent**:
- No direct dependencies
- May use kernel syscalls for file I/O in future

**Database Agent**:
- No direct dependencies
- May use database for editor state persistence in future

**Carry Agent**:
- No direct dependencies
- May share UI components in future

**Grain Court (formerly Grain Field)**:
- No current references to Grain Field/Court in Aurora Agent codebase
- Verified: No imports, no documentation references
- Future: May use Grain Court for vector search or LLM integration
- Note: If integrated in future, will use `grain_court` module name

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Master Plan**: [`docs/plan.md`](../plan.md)
- **Grain Core Agent Plan**: [`docs/plans/plan_core.md`](plan_core.md)
- **Grain Skate Future Enhancements**: [`docs/grain_skate_future_enhancements.md`](../grain_skate_future_enhancements.md)
- **Shared Module Coordination**: [`docs/grain_os_font_renderer_coordination.md`](../grain_os_font_renderer_coordination.md)
- **AI Provider Refactoring**: [`docs/ai_provider_refactoring.md`](../ai_provider_refactoring.md)

---

**Note**: This is a detailed development plan for the Aurora IDE Dream Browser Agent. For high-level overview, see [`docs/plan.md`](../plan.md).

