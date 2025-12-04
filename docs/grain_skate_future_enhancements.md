# Grain Skate Future Enhancements and Integration Plan

**Date**: 2025-12-02-183358-pst  
**Agent**: Grain Skate Terminal Silo Field Agent

## Future Optional Enhancements

### 1. Language-Specific Syntax Highlighting
- File type detection (extension-based, shebang-based)
- Language-specific keyword sets (Zig, Rust, C, Python, JavaScript, etc.)
- Language-specific syntax rules (string delimiters, comment styles)
- Tree-sitter integration for accurate parsing (optional, depends on Aurora Tree-sitter module)
- Customizable color schemes (user-defined syntax colors)
- Syntax highlighting performance optimization (incremental parsing)

### 2. Advanced Rendering Features
- ✅ Text labels on graph nodes (block titles, descriptions) - **COMPLETE** (2025-12-04-095210-pst)
- Node icons (customizable per block type)
- Graph zoom controls (mouse wheel, keyboard shortcuts)
- Graph pan controls (drag, arrow keys)
- Graph minimap (overview of entire graph)
- Graph search (find nodes by title/ID)
- Graph filtering (show/hide nodes by type)
- Graph export (PNG, SVG, PDF)

### 3. Editor Enhancements
- Multiple cursors (multi-edit support)
- Code folding (collapse/expand code blocks)
- ✅ Bracket matching (highlight matching brackets) - **COMPLETE** (2025-12-03-162613-pst)
- Auto-indentation (language-aware indentation)
- Code snippets (template expansion)
- Macro recording/playback (vim-style macros)
- Search and replace (regex support)
- Find in files (search across all blocks)

### 4. DAG Integration (Shared with Aurora/Dream)
- Event ordering for editor operations (undo/redo via DAG)
- Collaborative editing (multi-user via DAG consensus)
- Block dependency tracking (DAG edges for block links)
- Event replay (deterministic operation replay)
- Conflict resolution (DAG-based merge strategies)

### 5. Performance Optimizations
- Incremental syntax highlighting (only re-parse changed lines)
- Viewport culling (only render visible text)
- Text rendering cache (cache rendered glyphs)
- Graph layout optimization (faster force-directed algorithm)
- Memory usage optimization (reduce allocations)

### 6. Integration Enhancements
- Grain OS compositor integration (run as Grain OS application)
- Grain Terminal integration (embed terminal in editor)
- Aurora IDE integration (share editor components)
- Dream Browser integration (embed web content in blocks)
- Kernel syscall integration (file I/O, process management)

## Integration Dependencies

### From Grain OS Agent

#### Compositor Integration (Optional)
- Window management API (create, destroy, resize windows)
- Input event routing (keyboard, mouse events)
- Framebuffer rendering (if running on Grain OS)
- Workspace management (multi-workspace support)
- Window decorations (title bar, borders, controls)
- **Status**: Grain OS compositor is ready, integration pending
- **Coordination**: Check with Grain OS agent before integration

#### System Services (Optional)
- File manager integration (open files from file manager)
- Clipboard integration (copy/paste between applications)
- Notification system (show save notifications)
- System tray integration (background operation indicator)
- **Status**: Grain OS services are ready, integration pending
- **Coordination**: Check with Grain OS agent before integration

### From Vantage VM Basin Kernel Agent

#### Kernel Syscalls (Required for Grain OS target)
- File I/O syscalls (open, read, write, close, unlink, rename)
- Process management (spawn, exit, wait, kill)
- IPC channels (channel_create, channel_send, channel_recv)
- Input events (read_input_event syscall #60)
- Framebuffer operations (fb_clear, fb_draw_pixel, fb_draw_text)
- **Status**: All required syscalls are implemented and ready
- **Coordination**: See `docs/grain_terminal_kernel_ready.md` for API contracts
- **Integration**: Use syscall function pointers (similar to Grain OS compositor)

#### VM Integration (Required for RISC-V target)
- RISC-V64 compilation target
- VM framebuffer API (1024x768, 32-bit RGBA)
- VM input event queue (keyboard and mouse events)
- VM memory management (address translation, protection)
- **Status**: VM is ready for terminal integration
- **Coordination**: See `docs/terminal_kernel_integration_api.md` for integration guide
- **Integration**: Grain Skate can run in VM for testing (macOS native for development)

### From Aurora IDE / Dream Browser Agent

#### Shared Modules (Optional, but recommended)
- `dag_core.zig` - DAG foundation for event ordering
- `grain_buffer.zig` - Text buffer with readonly spans
- `grain_aurora.zig` - Component-first UI rendering
- **Status**: All modules are implemented and ready
- **Coordination**: See shared module refactoring plan below
- **Integration**: Refactor Grain Skate to use shared modules

## Shared Module Refactoring Plan

### Problem Statement

Currently, Grain Skate, Aurora IDE, and Dream Browser have duplicate implementations of:
- Font rendering (5x7 bitmap in Grain Skate, 8x8 bitmap in Aurora/Grain OS)
- Text rendering (custom implementations in each)
- Pixel buffer rendering (custom implementations in each)
- Event ordering (Grain Skate uses simple undo/redo, Aurora/Dream use DAG)

### Refactoring Goals

1. **Reduce code duplication** - Share common rendering and text handling code
2. **Improve maintainability** - Fix bugs once, benefit all applications
3. **Enable new features** - Shared modules enable features like DAG-based collaboration
4. **Consistent behavior** - All applications use same rendering and text handling

### Refactoring Plan

#### Phase 1: Font Rendering Unification (Priority: High)

**Current State**:
- Grain Skate: `src/grain_skate/editor_renderer.zig` - 5x7 bitmap font (A-Z, 0-9)
- Aurora: `src/aurora_text_renderer.zig` - 8x8 bitmap font (ASCII 32-126)
- Grain OS: `src/grain_os/font_renderer.zig` - 8x8 bitmap font (ASCII 32-126)

**Proposed Solution**:
- Create `src/shared/font_renderer.zig` - Unified font renderer
- Support multiple font sizes (5x7, 8x8, 16x16, etc.)
- Support multiple character sets (ASCII, Unicode, custom)
- GrainStyle compliant (u32 types, bounded allocations, assertions)
- All applications use shared font renderer

**Migration Steps**:
1. Create `src/shared/font_renderer.zig` with unified API
2. Migrate Aurora to use shared font renderer
3. Migrate Grain OS to use shared font renderer
4. Migrate Grain Skate to use shared font renderer (upgrade from 5x7 to 8x8)
5. Remove duplicate font rendering code

#### Phase 2: Text Buffer Unification (Priority: High)

**Current State**:
- Grain Skate: `src/grain_skate/editor.zig` - Custom `TextBuffer` implementation
- Aurora/Dream: `src/grain_buffer.zig` - `GrainBuffer` with readonly spans

**Proposed Solution**:
- Migrate Grain Skate editor to use `GrainBuffer` from `src/grain_buffer.zig`
- Benefit: Grain Skate gets readonly spans support (useful for collaborative editing)
- Benefit: Consistent text buffer API across all applications
- Benefit: Shared bug fixes and performance improvements

**Migration Steps**:
1. Review `GrainBuffer` API and ensure it meets Grain Skate needs
2. Create adapter layer if needed (wrap `GrainBuffer` for Grain Skate API)
3. Migrate Grain Skate editor to use `GrainBuffer`
4. Remove duplicate `TextBuffer` implementation
5. Test thoroughly (undo/redo, visual mode, etc.)

#### Phase 3: DAG Integration (Priority: Medium)

**Current State**:
- Grain Skate: Simple undo/redo stack (no DAG)
- Aurora/Dream: DAG-based event ordering (`dag_core.zig`)

**Proposed Solution**:
- Integrate `dag_core.zig` into Grain Skate for event ordering
- Benefit: Deterministic undo/redo (DAG-based)
- Benefit: Foundation for collaborative editing
- Benefit: Event replay and conflict resolution

**Migration Steps**:
1. Review `DagCore` API and understand event ordering model
2. Create adapter layer to map Grain Skate operations to DAG events
3. Migrate Grain Skate undo/redo to use DAG
4. Test thoroughly (undo/redo, edge cases)
5. Future: Add collaborative editing support

#### Phase 4: UI Rendering Unification (Priority: Low)

**Current State**:
- Grain Skate: Custom pixel buffer rendering (`editor_renderer.zig`, `graph_renderer.zig`)
- Aurora/Dream: `GrainAurora` component-first rendering

**Proposed Solution**:
- Evaluate if `GrainAurora` can replace Grain Skate's custom rendering
- If yes: Migrate Grain Skate to use `GrainAurora`
- If no: Keep custom rendering but share font/text utilities
- Benefit: Consistent UI rendering across applications
- Benefit: Shared UI components and styling

**Migration Steps**:
1. Evaluate `GrainAurora` API for Grain Skate use case
2. Prototype migration (editor rendering via `GrainAurora`)
3. If successful: Migrate graph rendering (may need custom components)
4. If not successful: Keep custom rendering, share utilities only
5. Test thoroughly (performance, visual correctness)

#### Phase 5: Shared Utilities (Priority: Low)

**Current State**:
- Multiple implementations of common utilities (color constants, coordinate transformation, etc.)

**Proposed Solution**:
- Create `src/shared/` directory for shared utilities
- Move common utilities to shared modules:
  - Color constants (`shared/colors.zig`)
  - Coordinate transformation (`shared/coords.zig`)
  - Math utilities (`shared/math.zig`)
  - String utilities (`shared/strings.zig`)
- All applications use shared utilities

**Migration Steps**:
1. Identify common utilities across applications
2. Create shared utility modules
3. Migrate applications to use shared utilities
4. Remove duplicate utility code

### Refactoring Timeline

- **Phase 1 (Font Rendering)**: 1-2 weeks
- **Phase 2 (Text Buffer)**: 1-2 weeks
- **Phase 3 (DAG Integration)**: 2-3 weeks
- **Phase 4 (UI Rendering)**: 2-4 weeks (evaluation dependent)
- **Phase 5 (Shared Utilities)**: 1 week

**Total Estimated Time**: 7-12 weeks (can be done incrementally)

### Coordination Requirements

- **With Aurora/Dream Agent**: Coordinate on shared module APIs, ensure backward compatibility
- **With Grain OS Agent**: Coordinate on font renderer migration, ensure no conflicts
- **With Vantage VM Agent**: No coordination needed (refactoring is userspace only)

### Benefits After Refactoring

1. **Reduced Code Duplication**: ~30-40% reduction in duplicate code
2. **Improved Maintainability**: Fix bugs once, benefit all applications
3. **New Features Enabled**: DAG-based collaboration, shared UI components
4. **Consistent Behavior**: All applications use same rendering and text handling
5. **Easier Testing**: Shared modules have comprehensive tests
6. **Better Performance**: Shared modules can be optimized once for all applications

