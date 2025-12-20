# Aurora IDE Dream Browser Agent: Task List

**Agent**: Grain Aurora IDE Dream Browser Agent (2nd Agent)  
**Status**: Active — Foundation components, shared modules  
**Last Updated**: 2025-12-20-143300-pst

---

## Current Work: Phase 2 - Shared Module Refactoring (Continued)

**Priority**: **HIGH** — Code deduplication, shared maintenance  
**Status**: **IN PROGRESS** — Phase 1.2 (Font Renderer) Complete  
**Estimated Time**: Ongoing (multi-phase)

### Tasks

#### Phase 1.2: Font Renderer Unification ✅ **COMPLETE**

- [x] Migrate `src/aurora_text_renderer.zig` to use shared font renderer
- [x] Replace custom `getCharPattern()` with shared font renderer API
- [x] Update `TextRenderer` to use `shared.FontRenderer` (8x8 font, ASCII basic)
- [x] Add `init()` method for proper initialization
- [x] Update `draw_char()` to use `render_char_to_pixels()` from shared module
- [x] Remove duplicate font pattern code (195 lines removed)
- [x] Update test to use `TextRenderer.init()` API
- [x] Add shared module import to build.zig test configuration
- [x] GrainStyle compliance (grain_case, u32 types, max 70 lines per function, max 73 chars per line)
- [x] Verify all functions comply with line length limits (73 chars max)
- [x] Update `docs/plan.md` and `docs/tasks.md` with completion
- **Date**: 2025-12-03-162659-PST

#### Phase 2.2: Layout System Comprehensive Tests ✅ **COMPLETE**

- [x] Create comprehensive test suite (`tests/112_aurora_layout_test.zig`)
- [x] Tests for workspace creation, pane splitting (horizontal/vertical)
- [x] Tests for focus navigation, pane resizing, workspace switching
- [x] Tests for bounded allocations (MAX_PANES, MAX_WORKSPACES)
- [x] Tests for pane tree structure and focus management
- [x] Add `aurora_layout_module` to build.zig
- [x] GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- [x] All tests pass with proper assertions
- [x] Update `docs/plans/plan_aurora.md` and `docs/tasks/tasks_aurora.md`
- **Date**: 2025-12-04-095411-PST

#### Phase 2.3: Editor Comprehensive Tests ⚠️ **CREATED (BLOCKED)**

- [x] Create comprehensive test suite (`tests/113_aurora_editor_test.zig`)
- [x] Tests for editor initialization, text insertion, deletion
- [x] Tests for undo/redo operations, cursor movement
- [x] Tests for folding operations, completion rejection
- [x] Add `aurora_editor_module` to build.zig
- [x] GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- [ ] Tests pass (BLOCKED by Zig 0.15.2 comptime evaluation issue)
- [x] Update `docs/plans/plan_aurora.md` and `docs/tasks/tasks_aurora.md`
- **Date**: 2025-12-06-232932-PST
- **Status**: Tests written and ready, but cannot run due to Zig 0.15.2 comptime issue with `Editor.init` when importing through module. See `src/aurora_editor.zig:2164` for related comment.

#### Phase 2.4: Dream Browser Viewport Comprehensive Tests ✅ **COMPLETE**

- [x] Create comprehensive test suite (`tests/114_dream_browser_viewport_test.zig`)
- [x] Tests for viewport initialization, size setting, content size
- [x] Tests for scrolling operations (scroll_by, scroll_to)
- [x] Tests for scroll bounds checking and can_scroll methods
- [x] Tests for navigation history (add, back, forward, can_navigate)
- [x] Tests for viewport state retrieval
- [x] Add `dream_browser_viewport_module` to build.zig
- [x] GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- [x] All tests pass with proper assertions
- [x] Update `docs/plans/plan_aurora.md` and `docs/tasks/tasks_aurora.md`
- **Date**: 2025-12-07-042307-PST

#### Phase 2.5: Dream Browser Parser Comprehensive Tests ✅ **COMPLETE**

- [x] Create comprehensive test suite (`tests/115_dream_browser_parser_test.zig`)
- [x] Tests for HTML parsing (simple elements, attributes, nested elements)
- [x] Tests for CSS parsing (simple rules, multiple rules, class/id selectors)
- [x] Tests for style computation (cascade, specificity)
- [x] Tests for bounds checking (HTML size, CSS rules count)
- [x] Tests for error handling (invalid HTML, empty HTML)
- [x] Add `dream_browser_parser_module` to build.zig
- [x] GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- [x] All tests pass with proper assertions
- [x] Update `docs/plans/plan_aurora.md` and `docs/tasks/tasks_aurora.md`
- **Date**: 2025-12-07-071305-PST

#### Phase 2.6: Dream Browser Renderer Comprehensive Tests ✅ **COMPLETE**

- [x] Create comprehensive test suite (`tests/116_dream_browser_renderer_test.zig`)
- [x] Tests for renderer initialization and deinitialization
- [x] Tests for display type determination (block, inline, headings, lists)
- [x] Tests for layout operations (simple blocks, inline elements, nested structures)
- [x] Tests for rendering to Aurora components (with and without CSS)
- [x] Tests for readonly and editable spans creation
- [x] Tests for complete page rendering
- [x] Tests for viewport bounds handling
- [x] Add `dream_browser_renderer_module` to build.zig
- [x] GrainStyle compliance (grain_case, u32 types, max 73 chars per line)
- [x] All tests pass with proper assertions
- [x] Update `docs/plans/plan_aurora.md` and `docs/tasks/tasks_aurora.md`
- **Date**: 2025-12-19-191728-PST

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations: Fixed-size arrays for spans and strings
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 73 characters per line (graincard compatibility)
- All compiler warnings enabled
- Explicit types (`u32`/`u64`, no `usize`)

### Dependencies

- **Needs**: Shared font renderer from Grain Skate Agent (Phase 1) ✅ Complete
- **Provides**: Font renderer migration example for Grain Core Agent (Phase 1.3)
- **Coordinates with**: Grain Skate Agent (shared module plan), Grain Core Agent (font renderer migration)

---

## Planned: Phase 2 - Text Buffer Unification

**Priority**: **MEDIUM** — Code deduplication  
**Status**: **READY** (GrainBuffer u32/u64 compliant)  
**Estimated Time**: 1-2 weeks

### Tasks

- [x] Update `GrainBuffer` to use `u32`/`u64` instead of `usize`/`isize` — Complete (2025-12-06-004609-pst)
- [x] Update `aurora_editor.zig` to use `u32` for GrainBuffer operations — Complete
- [ ] Coordinate with Grain Skate Agent on `GrainBuffer` API compatibility
- [ ] Review Grain Skate `TextBuffer` implementation
- [ ] Identify API differences and migration path
- [ ] Create migration plan document
- [ ] Migrate Grain Skate editor to use `GrainBuffer`
- [ ] Update tests for unified text buffer
- [ ] Remove duplicate text buffer code
- [ ] Update documentation

### Dependencies

- **Needs**: Grain Skate Agent coordination
- **Provides**: `GrainBuffer` API for Grain Skate (u32/u64 compliant)
- **Coordinates with**: Grain Skate Agent (text buffer migration)

### Grain Style Compliance

- ✅ **GrainBuffer u32/u64 Compliance** (2025-12-06-004609-pst) — Complete
  - Updated all `usize`/`isize` to `u32`/`u64`/`i64` in `GrainBuffer`
  - Updated `Segment` struct: `start: u32, end: u32`
  - Updated function signatures: `markReadOnly(start: u32, end: u32)`, `isReadOnly(pos: u32)`, `insert(index: u32, ...)`, `erase(index: u32, count: u32)`, etc.
  - Updated `shiftSegments(pivot: u32, delta: i64)` and `shiftIndex(value: u32, delta: i64)`
  - Updated all tests to use `u32`
  - Updated `aurora_editor.zig` to use `u32` for GrainBuffer operations
  - **Unblocks**: Phase 2 Text Buffer Unification (no adapter layer needed)

---

## Planned: Phase 3 - DAG Integration

**Priority**: **MEDIUM** — Event ordering and consensus  
**Status**: **PLANNED**  
**Estimated Time**: 2-3 weeks

### Tasks

- [ ] Integrate DAG Core into editor for event ordering
- [ ] Integrate DAG Core into browser for event ordering
- [ ] **Map Aurora UI components to DAG nodes** (text, column, row, button → DAG nodes)
- [ ] **Extend DAG Core with design_component node type** (coordinate with Bubble Agent)
- [ ] **Define shared component interface** (coordinate with Bubble Agent)
- [ ] Implement consensus mechanism for collaborative editing
- [ ] Implement state synchronization
- [ ] Add DAG event handlers for editor operations
- [ ] Add DAG event handlers for browser operations
- [ ] **Coordinate with Bubble Agent on unified DAG architecture**
- [ ] Create tests for DAG integration
- [ ] Update documentation

### Dependencies

- **Needs**: DAG Core (Phase 0.4) ✅ Complete
- **Coordinates with**: Grain Bubble Agent (DAG integration, component system unification)
- **Coordinates with**: Grain Skate Agent (DAG integration)
- **Provides**: DAG integration example, shared component model

### DAG Code Sharing Analysis

See [`docs/agent-communications/bubble_aurora_dag_sharing_analysis.md`](../agent-communications/bubble_aurora_dag_sharing_analysis.md) for detailed analysis of code sharing opportunities between Aurora and Bubble, especially around DAG UI synthesis (`docs/dag_ui_synthesis.md`).

**Key Opportunities**:
1. **DAG Core Integration**: Both Aurora and Bubble should use `src/dag_core.zig` for state management
2. **Component System Unification**: Aurora's UI components and Bubble's design components could share DAG node structure
3. **Streaming Updates**: Hyperfiddle-style deterministic updates (see `docs/dag_ui_synthesis.md`)
4. **HashDAG Consensus**: Event ordering for UI state (enables collaboration)

---

## Planned: Phase 4 - UI Rendering Unification

**Priority**: **LOW** — Component-based UI  
**Status**: **PLANNED**  
**Estimated Time**: 2-3 weeks

### Tasks

- [ ] Evaluate `GrainAurora` component-first rendering for Grain Skate
- [ ] Coordinate with Grain Skate Agent on component API
- [ ] Create unified component API if needed
- [ ] Migrate Grain Skate to use `GrainAurora` components
- [ ] Update tests for unified UI rendering
- [ ] Remove duplicate UI rendering code
- [ ] Update documentation

### Dependencies

- **Needs**: Grain Skate Agent evaluation
- **Provides**: `GrainAurora` component API
- **Coordinates with**: Grain Skate Agent (UI rendering unification)

---

## Completed Phases (Summary)

### Phase 0: Shared Foundation ✅ **COMPLETE**

- ✅ GrainBuffer Enhancement (0.1)
- ✅ GLM-4.6 Client (0.2)
- ✅ Dream Protocol (0.3)
- ✅ DAG Core Foundation (0.4)

### Phase 1: Dream Editor Core ✅ **COMPLETE**

- ✅ Readonly Spans Integration (1.1)
- ✅ Method Folding (1.2)
- ✅ GLM-4.6 Integration (1.3)
- ✅ Complete LSP Implementation (1.4)
- ✅ LSP Visual Rendering Features (1.5)
- ✅ RenderResult Grain/Tiger Style Refactoring (1.6)
- ✅ Grain/Tiger Style Compliance (usize → u32) (1.7)
- ✅ Magit-Style VCS (1.8)
- ✅ Editor Enhancements (1.9)

### Phase 2: Shared Module Refactoring ✅ **IN PROGRESS**

- ✅ Font Renderer Unification (1.2) — Complete
- 📋 Text Buffer Unification (2) — Planned
- 📋 DAG Integration (3) — Planned
- 📋 UI Rendering Unification (4) — Planned

---

## Coordination Tasks

### With Grain Core Agent

- [x] Font renderer migration (Phase 1.2) — Complete
- [ ] Coordinate on Grain Core Agent font renderer migration (Phase 1.3)
- [ ] Coordinate on text buffer unification (Phase 2)
- [ ] Coordinate on DAG integration (Phase 3)
- [ ] Coordinate on UI rendering unification (Phase 4)
- [x] Acknowledge WebSocket support (Phase 61) — Complete (not immediately needed)
- [x] Acknowledge file storage support (Phase 62) — Complete (not immediately needed)
- [x] Grain Style u32/u64 enforcement audit — Complete (fully compliant)

### With Grain Skate Agent

- [x] Font renderer creation (Phase 1) — Complete
- [ ] Coordinate on Grain Skate Agent font renderer migration (Phase 1.4)
- [ ] Coordinate on text buffer unification (Phase 2)
- [ ] Coordinate on DAG integration (Phase 3)
- [ ] Coordinate on UI rendering unification (Phase 4)

### With Other Agents

- [ ] Coordinate with Vantage Agent on file I/O syscalls (if needed)
- [ ] Coordinate with Database Agent on state persistence (if needed)
- [ ] Coordinate with Carry Agent on UI components (if needed)

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Core Tasks**: [`docs/tasks.md`](../tasks.md)
- **Grain Core Agent Tasks**: [`docs/tasks/tasks_core.md`](tasks_core.md)
- **Grain Skate Future Enhancements**: [`docs/grain_skate_future_enhancements.md`](../grain_skate_future_enhancements.md)
- **Shared Module Coordination**: [`docs/grain_os_font_renderer_coordination.md`](../grain_os_font_renderer_coordination.md)

---

**Note**: This is a detailed task list for the Aurora IDE Dream Browser Agent. For high-level overview, see [`docs/tasks.md`](../tasks.md).

