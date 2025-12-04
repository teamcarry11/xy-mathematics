# Grain Skate Terminal Silo Field Agent: Development Plan

**Agent**: Grain Skate Terminal Silo Field Agent (3rd Agent)  
**Status**: Core Features Complete, Shared Module Refactoring In Progress  
**Last Updated**: 2025-12-03-175019-pst

---

## Overview

Grain Skate Terminal Silo Field Agent is responsible for building Grain Skate (knowledge graph editor), Grain Terminal (terminal emulator), and Grainscript (scripting language). This includes text editing, graph visualization, block storage, and terminal emulation.

**Key Goals**:
- Knowledge graph editor with Vim-like keybindings
- Terminal emulator for Grain OS
- Scripting language (Grainscript) for automation
- Shared module refactoring (font renderer, text buffer, DAG integration)
- Integration with Grain OS compositor and kernel syscalls

---

## Completed Phases

### Phase 1.1: Shared Font Renderer ✅ **COMPLETE**

**Date**: 2025-12-02-183358-pst

**Completed Work**:
1. **Shared font renderer module** (`src/shared/font_renderer.zig`):
   - Created unified font renderer for all applications
   - Support for multiple font sizes (5x7, 8x8)
   - Support for multiple character sets (ASCII alphanumeric, ASCII basic)
   - Character rendering API (`render_char_to_pixels`)
   - Pixel buffer rendering API
   - GrainStyle compliant (grain_case, u32/u64, bounded allocations, assertions)

2. **Build system integration**:
   - Added shared module to build system
   - Tests created (`tests/060_shared_font_renderer_test.zig`)
   - Comprehensive test coverage

3. **Benefits**:
   - Code deduplication: single font renderer for all applications
   - Shared maintenance: font rendering bugs fixed once benefit all
   - Consistency: all applications use same font renderer
   - Flexibility: can switch font sizes/character sets via shared API

**Coordination**:
- Phase 1.1: Shared font renderer created ✅ (Grain Skate Agent)
- Phase 1.2: Aurora Agent migrated ✅ (2025-12-03-162659-PST)
- Phase 1.3: Grain OS Agent ready to migrate (see `docs/grain_os_font_renderer_coordination.md`)
- Phase 1.4: Grain Skate Agent to migrate `src/grain_skate/editor_renderer.zig` (PLANNED)

---

### Phase 2: Grain Skate Core Editor ✅ **COMPLETE**

**Date**: 2025-11-23-114146-pst

**Completed Work**:
1. **Text buffer management** (`src/grain_skate/editor.zig`):
   - Immutable line-based text buffer
   - Bounded allocations (MAX_BUFFER_SIZE, MAX_LINE_LEN, MAX_UNDO_HISTORY)
   - Line insertion, deletion, replacement
   - Undo/redo system (stack-based, no recursion)
   - Yank buffer for copy/paste operations
   - Search pattern management
   - GrainStyle compliant (grain_case, u32 types, assertions)

2. **Modal editor** (`src/grain_skate/modal_editor.zig`):
   - Vim/Kakoune-style modal editing
   - All editing modes (normal, insert, visual, visual_line, visual_block, command, search)
   - Keybinding system (all Vim commands mapped)
   - Command mode parsing (w, q, wq, q!, x, s/.../)
   - Search functionality (/, ?, n, N)
   - Find/replace (s/old/new/, s/old/new/g)
   - Comprehensive tests (`tests/058_grain_skate_modal_editor_test.zig`)

3. **Editor features**:
   - Cursor movement (h/j/k/l, word movement w/b/e, line/file movement 0/$/^/gg/G)
   - Text operations (insert, delete, replace, yank, paste)
   - Visual mode operations (character, line, block selection)
   - Undo/redo system (full support for all operations)
   - Search and replace functionality

---

### Phase 3: Graph Visualization ✅ **COMPLETE**

**Date**: 2025-11-23-170000-pst

**Completed Work**:
1. **Graph visualization** (`src/grain_skate/graph_viz.zig`):
   - Force-directed layout algorithm (iterative, no recursion)
   - Node and edge management (MAX_NODES: 1024, MAX_EDGES: 4096)
   - View controls (pan, zoom, select)
   - Hit testing (find node at pixel coordinates)
   - Click handling (open block when node clicked)
   - Comprehensive tests (`tests/054_grain_skate_graph_viz_test.zig`)

2. **Graph rendering** (`src/grain_skate/graph_renderer.zig`):
   - Pixel buffer rendering (RGBA format)
   - Node and edge drawing (Bresenham line algorithm, filled circles)
   - Coordinate transformation (normalized to pixel)
   - Color management (background, nodes, edges, selection)
   - Node label rendering (block IDs as numbers, 5x7 bitmap font)
   - Title label rendering (block titles with ASCII font)
   - Block storage integration for title lookup
   - Comprehensive tests (`tests/056_grain_skate_graph_renderer_test.zig`)

---

### Phase 4: Storage Integration ✅ **COMPLETE**

**Date**: 2025-11-23-114146-pst

**Completed Work**:
1. **Block storage** (`src/grain_skate/block.zig`):
   - Block data structure (id, title, content, links, backlinks)
   - Block storage management (create, get, update, delete)
   - Block linking (bidirectional links)
   - Grain Silo integration (object storage)
   - Grain Field integration (hot cache promotion/demotion)
   - Comprehensive tests (`tests/048_grain_skate_core_test.zig`)

2. **Storage integration** (`src/grain_skate/storage_integration.zig`):
   - Block-to-object mapping (Grain Silo integration)
   - Hot cache promotion/demotion (Grain Field SRAM integration)
   - Persist/load blocks from Grain Silo
   - Block storage lifecycle management

---

### Phase 5: Editor Rendering ✅ **COMPLETE**

**Date**: 2025-12-02-142853-pst

**Completed Work**:
1. **Editor renderer** (`src/grain_skate/editor_renderer.zig`):
   - Text rendering (monospace font, line rendering)
   - Cursor rendering (vertical line cursor indicator)
   - Selection highlighting (visual mode selections)
   - Status line rendering (mode indicator, line/column info, block title, save status)
   - Command line rendering (command mode input display)
   - Search pattern display (search mode input display)
   - Viewport management (scrolling, panning for large files)
   - Line numbers (dedicated column with background)
   - Error message display (with timeout)
   - 5x7 bitmap font rendering (A-Z, 0-9, basic punctuation)

2. **Window integration** (`src/grain_skate/window.zig`):
   - Native macOS window management
   - Editor rendering integration
   - Graph rendering integration
   - Split pane layout (graph left, editor right, divider line)
   - Window resize handling
   - Event routing (keyboard, mouse)
   - Comprehensive tests (`tests/057_grain_skate_window_graph_test.zig`)

---

### Phase 6: Syntax Highlighting ✅ **COMPLETE**

**Date**: 2025-12-03-141818-pst

**Completed Work**:
1. **Language detection** (`src/grain_skate/language_detector.zig`):
   - File type detection (extension-based, shebang-based)
   - Support for 15+ languages (Zig, Rust, C, C++, Python, JavaScript, TypeScript, Go, Java, Markdown, JSON, YAML, Shell, HTML, CSS)
   - Combined detection (prioritizes shebang, falls back to extension)
   - GrainStyle compliant (u32 types, bounded allocations, assertions)

2. **Language keywords** (`src/grain_skate/language_keywords.zig`):
   - Language-specific keyword sets
   - Keyword lookup by language
   - Extensible for new languages
   - GrainStyle compliant

3. **Syntax highlighting integration**:
   - Syntax color constants (keywords, strings, comments, numbers)
   - Syntax-aware text rendering
   - Language-aware keyword highlighting
   - Automatic language detection from block title/filename and content
   - Enable/disable syntax highlighting

---

### Phase 7: Bracket Matching ✅ **COMPLETE**

**Date**: 2025-12-03-162613-pst

**Completed Work**:
1. **Bracket matching module** (`src/grain_skate/bracket_matching.zig`):
   - Bracket type detection (parentheses, brackets, braces, angle brackets)
   - Matching bracket finding (iterative, stack-based algorithm, no recursion)
   - Forward search for closing brackets
   - Backward search for opening brackets
   - Nested bracket support (handles nested structures correctly)
   - Multi-line bracket matching
   - Bounded allocations (MAX_BRACKET_STACK_DEPTH: 1024)
   - GrainStyle compliant (grain_case, u32 types, assertions, max 70 lines per function)

2. **Editor renderer integration**:
   - Bracket match highlighting (yellow highlight on matching bracket)
   - Automatic bracket matching when cursor is on bracket
   - Viewport-aware rendering (only highlights visible brackets)
   - Comprehensive tests (`tests/073_grain_skate_bracket_matching_test.zig`)

---

### Phase 8: Main Entry Point ✅ **COMPLETE**

**Date**: Recent

**Completed Work**:
1. **Main entry point** (`src/grain_skate_main.zig`):
   - Application initialization (block storage, window, app)
   - Graph loading and rendering
   - Event loop integration
   - Keyboard event handling
   - Window resize handling
   - Auto-save functionality

2. **Build configuration**:
   - `grain-skate` executable target
   - macOS framework linking (AppKit, Foundation, CoreGraphics, QuartzCore)
   - Build steps: `grain-skate-build` and `grain-skate`

---

## Current Work: Phase 1.4 - Font Renderer Migration

**Priority**: **MEDIUM** — Code deduplication and consistency  
**Status**: **PLANNED**  
**Estimated Time**: 1 week

### Why This Phase

- **Code Deduplication**: Remove duplicate font rendering code from Grain Skate
- **Consistency**: Use shared font renderer for all applications
- **Maintenance**: Font rendering bugs fixed once benefit all applications
- **Flexibility**: Can switch font sizes/character sets via shared API

### Tasks

- [ ] Review shared font renderer API (`src/shared/font_renderer.zig`)
- [ ] Migrate `src/grain_skate/editor_renderer.zig` to use shared font renderer
- [ ] Update font size from 5x7 to 8x8 (upgrade to ASCII 32-126 character set)
- [ ] Update all font rendering calls to use shared API
- [ ] Remove duplicate font rendering code from editor renderer
- [ ] Update tests to use shared font renderer
- [ ] Verify visual correctness (font rendering matches previous behavior)
- [ ] Update `build.zig` if needed
- [ ] Update `docs/plans/plan_skate.md` and `docs/tasks/tasks_skate.md` with completion

### Dependencies

- **Needs**: Shared font renderer (Phase 1.1) ✅ Complete
- **Provides**: Consistent font rendering across all applications
- **Coordinates with**: Aurora Agent (already migrated), Grain OS Agent (ready to migrate)

---

## Planned Phases

### Phase 2: Text Buffer Unification (Priority: High)

**Status**: **PLANNED**  
**Estimated Time**: 1-2 weeks

**Objective**: Migrate Grain Skate editor to use `GrainBuffer` from `src/grain_buffer.zig`

**Benefits**:
- Grain Skate gets readonly spans support (useful for collaborative editing)
- Consistent text buffer API across all applications
- Shared bug fixes and performance improvements

**Migration Steps**:
1. Review `GrainBuffer` API and ensure it meets Grain Skate needs
2. Create adapter layer if needed (wrap `GrainBuffer` for Grain Skate API)
3. Migrate Grain Skate editor to use `GrainBuffer`
4. Remove duplicate `TextBuffer` implementation
5. Test thoroughly (undo/redo, visual mode, etc.)

**Dependencies**:
- **Needs**: `GrainBuffer` from Aurora Agent (exists)
- **Coordinates with**: Aurora Agent (API compatibility)

---

### Phase 3: DAG Integration (Priority: Medium)

**Status**: **PLANNED**  
**Estimated Time**: 2-3 weeks

**Objective**: Integrate `dag_core.zig` into Grain Skate for event ordering

**Benefits**:
- Deterministic undo/redo (DAG-based)
- Foundation for collaborative editing
- Event replay and conflict resolution

**Migration Steps**:
1. Review `DagCore` API and understand event ordering model
2. Create adapter layer to map Grain Skate operations to DAG events
3. Migrate Grain Skate undo/redo to use DAG
4. Test thoroughly (undo/redo, edge cases)
5. Future: Add collaborative editing support

**Dependencies**:
- **Needs**: `dag_core.zig` from Aurora Agent (exists)
- **Coordinates with**: Aurora Agent (DAG API)

---

### Phase 4: UI Rendering Unification (Priority: Low)

**Status**: **PLANNED**  
**Estimated Time**: 2-4 weeks (evaluation dependent)

**Objective**: Evaluate if `GrainAurora` can replace Grain Skate's custom rendering

**Migration Steps**:
1. Evaluate `GrainAurora` API for Grain Skate use case
2. Prototype migration (editor rendering via `GrainAurora`)
3. If successful: Migrate graph rendering (may need custom components)
4. If not successful: Keep custom rendering, share utilities only
5. Test thoroughly (performance, visual correctness)

**Dependencies**:
- **Needs**: `GrainAurora` from Aurora Agent (exists)
- **Coordinates with**: Aurora Agent (component API)

---

### Phase 5: Shared Utilities (Priority: Low)

**Status**: **PLANNED**  
**Estimated Time**: 1 week

**Objective**: Create shared utility modules for common functionality

**Migration Steps**:
1. Identify common utilities across applications
2. Create shared utility modules:
   - Color constants (`shared/colors.zig`)
   - Coordinate transformation (`shared/coords.zig`)
   - Math utilities (`shared/math.zig`)
   - String utilities (`shared/strings.zig`)
3. Migrate applications to use shared utilities
4. Remove duplicate utility code

---

## Coordination Points

### With Grain OS Agent

**Shared Module Refactoring**:
- **Phase 1.1**: Shared font renderer created ✅ (Grain Skate Agent)
- **Phase 1.2**: Aurora Agent migrated ✅
- **Phase 1.3**: Grain OS Agent ready to migrate (coordination document created)
- **Phase 1.4**: Grain Skate Agent to migrate `src/grain_skate/editor_renderer.zig` (PLANNED)

**Coordination Notes**:
- Grain Skate Agent created shared font renderer
- Aurora Agent completed migration
- Grain OS Agent is aware and ready (see `docs/grain_os_font_renderer_coordination.md`)
- Grain Skate Agent should migrate its own editor renderer next

**Future Coordination**:
- **Compositor Integration**: Grain Skate needs to register its window with the Grain OS compositor
- **System Services**: Potential integration with Grain OS system services (file manager, notifications)

---

### With Aurora IDE Dream Browser Agent

**Shared Modules**:
- **Font Renderer**: Shared implementation (`src/shared/font_renderer.zig`) — Grain Skate Agent Phase 1.1 ✅
- **Text Buffer**: `GrainBuffer` from `src/grain_buffer.zig` — Aurora Agent uses, Grain Skate Agent to migrate (Phase 2)
- **DAG Core**: `dag_core.zig` — Aurora Agent uses, Grain Skate Agent to integrate (Phase 3)
- **UI Rendering**: `GrainAurora` — Aurora Agent uses, Grain Skate Agent to evaluate (Phase 4)

**Coordination Notes**:
- Aurora Agent completed font renderer migration (Phase 1.2) ✅
- Grain Skate Agent created shared font renderer (Phase 1.1) ✅
- Future phases require coordination on API compatibility

**Reference**: See [`docs/grain_skate_future_enhancements.md`](../grain_skate_future_enhancements.md) for full shared module refactoring plan.

---

### With Vantage VM Basin Kernel Agent

**Kernel Syscalls (Required for Grain OS target)**:
- File I/O syscalls (open, read, write, close, unlink, rename)
- Process management (spawn, exit, wait, kill)
- IPC channels (channel_create, channel_send, channel_recv)
- Input events (read_input_event syscall #60)
- Framebuffer operations (fb_clear, fb_draw_pixel, fb_draw_text)

**Status**: All required syscalls are implemented and ready

**Coordination**: See `docs/grain_terminal_kernel_ready.md` for API contracts

**Integration**: Use syscall function pointers (similar to Grain OS compositor)

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Master Plan**: [`docs/plan.md`](../plan.md)
- **Future Enhancements**: [`docs/grain_skate_future_enhancements.md`](../grain_skate_future_enhancements.md)
- **Integration Readiness**: [`docs/grain_skate_integration_readiness.md`](../grain_skate_integration_readiness.md)
- **Shared Module Plan**: [`docs/grain_skate_future_enhancements.md`](../grain_skate_future_enhancements.md#shared-module-refactoring-plan)

