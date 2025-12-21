# Aurora IDE Dream Browser Agent: Development Plan

**Agent**: Grain Aurora IDE Dream Browser Agent (2nd Agent)  
**Status**: Active — Foundation components, shared modules, Dream Browser Spec v0 integration  
**Last Updated**: 2025-12-21-134223-pst

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

#### 2.3: Editor Comprehensive Tests ⚠️ **CREATED (BLOCKED)**
- ✅ Created comprehensive test suite (`tests/113_aurora_editor_test.zig`)
- ✅ Tests for editor initialization, text insertion, deletion
- ✅ Tests for undo/redo operations, cursor movement
- ✅ Tests for folding operations, completion rejection
- ✅ Added `aurora_editor_module` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ⚠️ **BLOCKED**: Tests cannot run due to Zig 0.15.2 comptime evaluation issue
- **Status**: Tests written and ready, but blocked by Zig 0.15.2 comptime issue with `Editor.init` when importing through module. See `src/aurora_editor.zig:2164` for related comment.
- **Files**: `tests/113_aurora_editor_test.zig`, `build.zig`
- **Date**: 2025-12-06-232932-PST

#### 2.4: Dream Browser Viewport Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/114_dream_browser_viewport_test.zig`)
- ✅ Tests for viewport initialization, size setting, content size
- ✅ Tests for scrolling operations (scroll_by, scroll_to)
- ✅ Tests for scroll bounds checking and can_scroll methods
- ✅ Tests for navigation history (add, back, forward, can_navigate)
- ✅ Tests for viewport state retrieval
- ✅ Added `dream_browser_viewport_module` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/114_dream_browser_viewport_test.zig`, `build.zig`
- **Date**: 2025-12-07-042307-PST

#### 2.5: Dream Browser Parser Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/115_dream_browser_parser_test.zig`)
- ✅ Tests for HTML parsing (simple elements, attributes, nested elements)
- ✅ Tests for CSS parsing (simple rules, multiple rules, class/id selectors)
- ✅ Tests for style computation (cascade, specificity)
- ✅ Tests for bounds checking (HTML size, CSS rules count)
- ✅ Tests for error handling (invalid HTML, empty HTML)
- ✅ Added `dream_browser_parser_module` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/115_dream_browser_parser_test.zig`, `build.zig`
- **Date**: 2025-12-07-071305-PST

#### 2.6: Dream Browser Renderer Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/116_dream_browser_renderer_test.zig`)
- ✅ Tests for renderer initialization and deinitialization
- ✅ Tests for display type determination (block, inline, headings, lists)
- ✅ Tests for layout operations (simple blocks, inline elements, nested structures)
- ✅ Tests for rendering to Aurora components (with and without CSS)
- ✅ Tests for readonly and editable spans creation
- ✅ Tests for complete page rendering
- ✅ Tests for viewport bounds handling
- ✅ Added `dream_browser_renderer_module` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/116_dream_browser_renderer_test.zig`, `build.zig`
- **Date**: 2025-12-19-191728-PST

#### 2.7: LSP Client Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/117_aurora_lsp_test.zig`)
- ✅ Tests for LSP client initialization and deinitialization
- ✅ Tests for document lifecycle (didOpen, didChange, didClose)
- ✅ Tests for snapshot management and versioning
- ✅ Tests for diagnostics storage
- ✅ Tests for incremental edits and multiple changes
- ✅ Tests for bounds checking and cleanup
- ✅ Added `aurora_lsp_module` and `lsp_test_file` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/117_aurora_lsp_test.zig`, `build.zig`
- **Date**: 2025-12-20-143848-PST

#### 2.8: AI Provider Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/118_aurora_ai_provider_test.zig`)
- ✅ Tests for AI provider constants and types
- ✅ Tests for message, completion request, and chunk structures
- ✅ Tests for transform types and parameters (refactor_rename, extract_function, multi_file_edit)
- ✅ Tests for transform request and result structures
- ✅ Tests for file edit, tool call request/result structures
- ✅ Tests for provider config structure
- ✅ Tests for bounds checking (message size, messages count, context tokens)
- ✅ Added `aurora_ai_provider_module` and `ai_provider_test_file` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/118_aurora_ai_provider_test.zig`, `build.zig`
- **Date**: 2025-12-20-161128-PST

#### 2.9: AI Transforms Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/119_aurora_ai_transforms_test.zig`)
- ✅ Tests for AI transforms constants and transform types
- ✅ Tests for file content, file edit, and applied edit structures
- ✅ Tests for transform result structure (with and without errors)
- ✅ Tests for bounds checking (symbol name, file URI, file edit size, transformations count, files per transform)
- ✅ Tests for file edit line ranges and multiple edits
- ✅ Tests for transform types coverage and multiple file contents
- ✅ Added `aurora_ai_transforms_module` and `ai_transforms_test_file` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/119_aurora_ai_transforms_test.zig`, `build.zig`
- **Date**: 2025-12-20-175007-PST

#### 2.10: DAG Integration Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/120_aurora_dag_integration_test.zig`)
- ✅ Tests for DAG integration constants and edit types
- ✅ Tests for initialization and deinitialization
- ✅ Tests for parse and map operations (AST-to-DAG mapping)
- ✅ Tests for edit-to-event mapping (insert, delete, replace, refactor)
- ✅ Tests for event processing
- ✅ Tests for semantic graph operations (node count, position finding)
- ✅ Tests for dependency counting
- ✅ Tests for bounds checking
- ✅ Added `aurora_dag_integration_module` and `dag_integration_test_file` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/120_aurora_dag_integration_test.zig`, `build.zig`
- **Date**: 2025-12-20-182841-PST

#### 2.11: Folding Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/121_aurora_folding_test.zig`)
- ✅ Tests for folding constants and fold structure
- ✅ Tests for initialization and deinitialization
- ✅ Tests for parse operations (functions, structs, enums, unions)
- ✅ Tests for toggle fold operations
- ✅ Tests for fold state checking (isFolded, getFold)
- ✅ Tests for fold retrieval (getAllFolds)
- ✅ Tests for bounds checking and edge cases
- ✅ Added `aurora_folding_module` and `folding_test_file` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/121_aurora_folding_test.zig`, `build.zig`
- **Date**: 2025-12-20-200935-PST

#### 2.12: Tree-sitter Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/122_aurora_tree_sitter_test.zig`)
- ✅ Tests for Tree-sitter constants (MAX_NODES, MAX_DEPTH, MAX_TOKENS)
- ✅ Tests for token type enum
- ✅ Tests for initialization and deinitialization
- ✅ Tests for parse operations (functions, structs, enums, unions)
- ✅ Tests for token extraction (keywords, strings, comments, numbers)
- ✅ Tests for node and token retrieval operations
- ✅ Tests for function name extraction
- ✅ Tests for bounds checking and structure validation
- ✅ Added `aurora_tree_sitter_module` and `tree_sitter_test_file` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/122_aurora_tree_sitter_test.zig`, `build.zig`
- **Date**: 2025-12-21-083012-PST

#### 2.13: Tab Manager Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/123_aurora_tab_manager_test.zig`)
- ✅ Tests for tab manager constants (MAX_EDITOR_TABS, MAX_BROWSER_TABS, MAX_TAB_GROUPS, MAX_GROUP_NAME_LENGTH)
- ✅ Tests for TabMetadata structure (last_accessed, is_pinned, group_id, order)
- ✅ Tests for TabGroup structure (id, name, editor_tabs, browser_tabs, created_at)
- ✅ Tests for TabStorage structure
- ✅ Tests for bounds checking and edge cases
- ✅ Tests for metadata operations (pinned, order, timestamps)
- ✅ Added `aurora_tab_manager_module` and `tab_manager_test_file` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/123_aurora_tab_manager_test.zig`, `build.zig`
- **Date**: 2025-12-21-090618-PST

#### 2.14: Text Renderer Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/124_aurora_text_renderer_test.zig`)
- ✅ Tests for renderer initialization and dimensions
- ✅ Tests for rendering operations (empty text, single character, multiple characters)
- ✅ Tests for newline handling
- ✅ Tests for long text truncation
- ✅ Tests for foreground and background colors
- ✅ Tests for different color combinations
- ✅ Tests for special characters, numbers, and mixed content
- ✅ Tests for multiple renders and bounds checking
- ✅ Added `aurora_text_renderer_module` and `text_renderer_test_file` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/124_aurora_text_renderer_test.zig`, `build.zig`
- **Date**: 2025-12-21-094149-PST

#### 2.15: Filter Comprehensive Tests ✅ **COMPLETE**
- ✅ Created comprehensive test suite (`tests/125_aurora_filter_test.zig`)
- ✅ Tests for filter mode enum (none, darkroom)
- ✅ Tests for FluxState initialization and toggle operations
- ✅ Tests for filter apply operations (none mode, darkroom mode)
- ✅ Tests for darkroom filter effects (red channel clamp, green/blue division)
- ✅ Tests for alpha channel preservation
- ✅ Tests for invalid pixel length handling
- ✅ Tests for multiple pixels and consistency
- ✅ Added `aurora_filter_module` and `filter_test_file` to build.zig
- ✅ GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- ✅ All tests pass with proper assertions
- **Files**: `tests/125_aurora_filter_test.zig`, `build.zig`
- **Date**: 2025-12-21-120349-PST

#### 2.16: Dream Browser Spec v0 Integration 📋 **PLANNED**
- 📋 Dream Browser Spec v0 research complete — ready for integration
- 📋 Research deliverable: `docs/research/dream_browser_spec_v0_research_2025-12-10-083733-pst.md`
- 📋 Integration with Aurora Agent development plan
- 📋 Coordinate with Core Agent on infrastructure needs (DNS resolution, network stack)
- **Status**: Research complete, integration planned
- **Date**: 2025-12-20-172643-PST

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

**Objective**: Integrate DAG for event ordering and consensus, unified with Bubble Agent.

**Features**:
- Event ordering for editor and browser
- Consensus mechanism for collaborative editing
- State synchronization
- **Component DAG Integration**: Map Aurora UI components (text, column, row, button) to DAG nodes
- **Shared DAG Infrastructure**: Coordinate with Bubble Agent on unified DAG architecture
- **Component Node Types**: Extend DAG Core with shared component interface

**Dependencies**:
- **Needs**: DAG Core (Phase 0.4) ✅ Complete
- **Coordinates with**: Bubble Agent (DAG integration, component system unification)
- **Provides**: DAG integration example, shared component model

**DAG Code Sharing Analysis**:
See [`docs/agent-communications/bubble_aurora_dag_sharing_analysis.md`](../agent-communications/bubble_aurora_dag_sharing_analysis.md) for detailed analysis of code sharing opportunities between Aurora and Bubble, especially around DAG UI synthesis (`docs/dag_ui_synthesis.md`).

**Key Opportunities**:
1. **DAG Core Integration**: Both Aurora and Bubble should use `src/dag_core.zig` for state management
2. **Component System Unification**: Aurora's UI components and Bubble's design components could share DAG node structure
3. **Streaming Updates**: Hyperfiddle-style deterministic updates (see `docs/dag_ui_synthesis.md`)
4. **HashDAG Consensus**: Event ordering for UI state (enables collaboration)

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

**Network Stack Support (Phase 61)**:
- ✅ **Grain Core Agent Phase 61 — COMPLETE** (2025-12-07-004326-pst)
  - TCP/UDP Socket Support
  - WebSocket Support
  - DNS Resolution
  - Socket Options (reuse address, keep-alive, timeout)
  - HTTP Client (GET, POST, PUT, DELETE requests)
- Note: Aurora Agent currently uses stdio for LSP (standard) and has WebSocket for Dream Protocol (Phase 0.3)
- Future: May use Core Agent HTTP Client for external API calls or WebSocket for additional real-time features

**File Storage Support (Phase 62)**:
- ✅ **Grain Core Agent Phase 62 — COMPLETE** (2025-12-06-113038-pst)
  - Database File Format Support
  - Page-based Storage with Checksums
  - File Locking Support
  - Transaction Log File Management (WAL)
  - Index File Management
  - Backup/Restore Capabilities
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

**Database Agent (Silo Agent)**:
- No direct dependencies
- May use database for editor state persistence in future

**Carry Agent**:
- No direct dependencies
- May share UI components in future

**Flow Agent**:
- No direct dependencies
- Future: May integrate workflow orchestration for editor/browser automation

**Research Agent**:
- No direct dependencies
- Future: May integrate research tools for code analysis

**Skate Agent** (GLM-4.6 Coordination):
- ✅ GLM-4.6 client available in `src/aurora_glm46.zig`
- 📋 Skate Agent needs to integrate GLM-4.6 for Phase 5 AI-Powered Graph Insights
- **Coordination**: Skate Agent will use Aurora's GLM-4.6 client for AI API calls
- **Status**: GLM-4.6 client ready for Skate Agent integration

**Grain Court Agent** (11th Agent — Integration Partner):
- ✅ **Welcome Court Agent!** 🌾⚒️
- **Integration Partner** — Court Agent provides LLM infrastructure for Aurora's AI provider abstraction
- **Coordination**: Court Agent will provide multi-provider LLM API that powers code completion and refactoring features
- **ZON Format Integration**: Court's ZON format will reduce token costs for code completion (35-70% token reduction)
- **Status**: Court Agent Phase 1 IN PROGRESS — Multi-Provider LLM API Foundation
- **Action**: Review Court Agent's plan (`docs/plans/plan_court.md`) and identify integration points for AI provider abstraction
- **Future**: Integrate Court Agent's LLM services into `src/aurora_ai_provider.zig` and `src/aurora_glm46_provider.zig`
- **Location**: `src/grain_court/`

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

