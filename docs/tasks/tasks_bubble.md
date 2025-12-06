# Grain Bubble Agent: Task List

**Agent**: Grain Bubble Agent (8th Agent)  
**Status**: Phase 1 Starting — Core Canvas (SLC v1.0)  
**Last Updated**: 2025-12-05-172143-pst

---

## Phase 1: Core Canvas (SLC v1.0) ⏳ **IN PROGRESS**

**Priority**: **HIGHEST** — Foundation for all features  
**Status**: **STARTING**  
**Estimated Time**: 4-6 weeks  
**Date Started**: 2025-12-05-143400-pst

### Tasks

#### Module Structure & Build System

- [ ] Create `src/grain_bubble/` directory structure
- [ ] Create `src/grain_bubble/root.zig` module exports
- [ ] Update `build/modules.zig` to add `grain_bubble` module
- [ ] Update `build.zig` to include grain_bubble module and tests
- [ ] Verify build system integration

#### Canvas Engine (`canvas.zig`)

- [ ] Create `src/grain_bubble/canvas.zig` module structure
- [ ] Implement infinite canvas data structure
- [ ] Implement zoom/pan functionality (mouse wheel, drag)
- [ ] Implement viewport transformation (world to screen coordinates)
- [ ] Implement canvas bounds checking
- [ ] Implement canvas state management (zoom level, pan offset)
- [ ] Add comprehensive assertions (minimum 2 per function)
- [ ] Follow Grain Style (grain_case, u32/u64, bounded allocations)

#### Bubble Renderer (`bubble_renderer.zig`)

- [ ] Create `src/grain_bubble/bubble_renderer.zig` module structure
- [ ] Implement rounded rectangle rendering ("bubbles")
- [ ] Implement circle rendering
- [ ] Implement rectangle rendering
- [ ] Implement shape fill rendering
- [ ] Implement shape stroke rendering
- [ ] Integrate with Grain OS framebuffer renderer
- [ ] Add comprehensive assertions
- [ ] Follow Grain Style

#### Shape System

- [ ] Define shape data structures (Rectangle, Circle, RoundedRectangle)
- [ ] Implement shape creation (position, size, color, corner radius)
- [ ] Implement shape selection (hit testing)
- [ ] Implement shape manipulation (drag, resize, rotate)
- [ ] Implement shape z-ordering (layer management)
- [ ] Implement shape grouping
- [ ] Add bounded allocations (MAX_SHAPES, MAX_LAYERS)
- [ ] Add comprehensive assertions
- [ ] Follow Grain Style

#### Text Tool

- [ ] Implement text data structure (position, content, font, size, color)
- [ ] Implement text rendering (using Grain OS font renderer)
- [ ] Implement text editing (insert, delete, select)
- [ ] Implement text selection (hit testing)
- [ ] Implement text manipulation (drag, resize)
- [ ] Add bounded allocations (MAX_TEXT_LEN, MAX_TEXT_ITEMS)
- [ ] Add comprehensive assertions
- [ ] Follow Grain Style

#### Layer Management

- [ ] Implement layer data structure (name, visibility, lock, z-order)
- [ ] Implement layer creation/deletion
- [ ] Implement layer reordering (move up/down)
- [ ] Implement layer grouping
- [ ] Implement layer visibility toggle
- [ ] Implement layer locking
- [ ] Add bounded allocations (MAX_LAYERS)
- [ ] Add comprehensive assertions
- [ ] Follow Grain Style

#### Selection & Manipulation

- [ ] Implement single selection (click to select)
- [ ] Implement multi-selection (shift+click, drag selection box)
- [ ] Implement selection manipulation (drag, resize, rotate)
- [ ] Implement selection bounds calculation
- [ ] Implement selection deletion
- [ ] Implement selection grouping
- [ ] Add bounded allocations (MAX_SELECTION)
- [ ] Add comprehensive assertions
- [ ] Follow Grain Style

#### PDF Export (`export_pdf.zig`)

- [ ] Create `src/grain_bubble/export_pdf.zig` module structure
- [ ] Implement PDF document structure
- [ ] Implement vector graphics to PDF conversion
- [ ] Implement shape rendering to PDF (rectangles, circles, rounded rectangles)
- [ ] Implement text rendering to PDF
- [ ] Implement multi-page support (if needed)
- [ ] Implement high-quality output (vector graphics, not raster)
- [ ] Add comprehensive assertions
- [ ] Follow Grain Style

#### Integration with Grain OS

- [ ] Integrate with Grain Core compositor (window management)
- [ ] Integrate with Grain OS framebuffer renderer (canvas rendering)
- [ ] Integrate with Grain OS input handler (mouse, keyboard)
- [ ] Integrate with Grain OS font renderer (text rendering)
- [ ] Integrate with Grain OS layout system (if needed)
- [ ] Test integration points
- [ ] Verify all dependencies work correctly

#### Testing

- [ ] Create `tests/125_grain_bubble_canvas_test.zig` for canvas tests
- [ ] Create `tests/126_grain_bubble_renderer_test.zig` for renderer tests
- [ ] Create `tests/127_grain_bubble_export_test.zig` for export tests
- [ ] Test canvas zoom/pan functionality
- [ ] Test shape creation and manipulation
- [ ] Test text tool functionality
- [ ] Test layer management
- [ ] Test selection and manipulation
- [ ] Test PDF export (verify output quality)
- [ ] Test integration with Grain Core modules
- [ ] Ensure all tests pass with grainwrap-100 and grainvalidate-70

#### Documentation

- [ ] Update `docs/plans/plan_bubble.md` with Phase 1 completion
- [ ] Update `docs/tasks/tasks_bubble.md` with Phase 1 completion
- [ ] Update `docs/plan.md` with Bubble Agent status
- [ ] Update `docs/tasks.md` with Bubble Agent status
- [ ] Document API contracts for future phases

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations: `MAX_SHAPES`, `MAX_LAYERS`, `MAX_TEXT_LEN`, `MAX_TEXT_ITEMS`, `MAX_SELECTION`
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line (graincard compatibility: 73 chars)
- No recursion (iterative algorithms only)
- All compiler warnings enabled
- Use `u32`/`u64` types (no `usize` unless necessary)

### Dependencies

- **Needs**: Grain Core compositor (`grain_core/compositor.zig`)
- **Needs**: Grain OS framebuffer renderer (`grain_core/framebuffer_renderer.zig`)
- **Needs**: Grain OS input handler (`grain_core/input_handler.zig`)
- **Needs**: Grain OS font renderer (`grain_core/font_renderer.zig`)
- **Needs**: Grain OS layout system (`grain_core/layout.zig`)
- **Provides**: Design canvas foundation for future phases

---

## Phase 2: Component System (PLANNED)

**Priority**: **HIGH** — Reusable design components  
**Status**: **PLANNED**  
**Estimated Time**: 3-4 weeks

### Tasks

- [ ] Create `src/grain_bubble/component.zig` module structure
- [ ] Implement component creation and editing
- [ ] Implement component variants (states, sizes, themes)
- [ ] Implement design tokens (colors, typography, spacing)
- [ ] Implement component library UI
- [ ] Implement component export
- [ ] Create comprehensive tests
- [ ] Update build system
- [ ] Update documentation

---

## Phase 3: Silo/Court Integration (PLANNED)

**Priority**: **MEDIUM** — Intelligent design features  
**Status**: **PLANNED**  
**Estimated Time**: 4-5 weeks

### Tasks

- [ ] Create `src/grain_bubble/silo_integration.zig` module structure
- [ ] Create `src/grain_bubble/court_integration.zig` module structure
- [ ] Create `src/grain_bubble/dag_integration.zig` module structure
- [ ] Implement design asset storage (Grain Silo)
- [ ] Implement vector search for component matching (Grain Court)
- [ ] Implement LLM design suggestions
- [ ] Implement design graph storage (DAG)
- [ ] Implement design version history
- [ ] Create comprehensive tests
- [ ] Update build system
- [ ] Update documentation

---

## Phase 4: Export Pipeline (PLANNED)

**Priority**: **HIGH** — Complete export capabilities  
**Status**: **PLANNED**  
**Estimated Time**: 3-4 weeks

### Tasks

- [ ] Create `src/grain_bubble/export_html.zig` module structure
- [ ] Create `src/grain_bubble/export_framework.zig` module structure
- [ ] Create `src/grain_bubble/export_slc.zig` module structure
- [ ] Implement responsive HTML export
- [ ] Implement framework bundle generation (React/Vue/Svelte)
- [ ] Implement SLC asset bundles (self-contained demos)
- [ ] Implement export optimization
- [ ] Implement export preview
- [ ] Create comprehensive tests
- [ ] Update build system
- [ ] Update documentation

---

## Phase 5: Agent Flow Design (PLANNED)

**Priority**: **MEDIUM** — Visual agent workflow design  
**Status**: **PLANNED**  
**Estimated Time**: 4-5 weeks

### Tasks

- [ ] Create `src/grain_bubble/agent_flow.zig` module structure
- [ ] Implement flow chart editor (bubbles and connections)
- [ ] Implement agent node configuration
- [ ] Implement flow execution visualization
- [ ] Implement flow export
- [ ] Implement agent integration
- [ ] Create comprehensive tests
- [ ] Update build system
- [ ] Update documentation

---

## Coordination Tasks

### With Grain Core Agent

**Integration Tasks**:
- [ ] Coordinate on compositor integration
- [ ] Share GUI component patterns
- [ ] Coordinate on window management APIs
- [ ] Test integration points

**Shared Components**:
- Compositor for window management
- Framebuffer renderer for canvas rendering
- Input handler for mouse/keyboard input
- Font renderer for text rendering
- Layout system for design layout algorithms

### With Database Agent

**Integration Tasks**:
- [ ] Coordinate on design project storage
- [ ] Integrate with database query capabilities
- [ ] Test integration points

### With Carry Agent

**Integration Tasks**:
- [ ] Coordinate on export formats (mobile-responsive HTML)
- [ ] Share design token systems
- [ ] Test integration points

### With Skate Agent

**Integration Tasks**:
- [ ] Coordinate on DAG integration (if applicable)
- [ ] Share graph storage patterns
- [ ] Test integration points

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Proposal**: [`docs/proposals/grain_bubble_proposal.md`](../proposals/grain_bubble_proposal.md)
- **Master Plan**: [`docs/plan.md`](../plan.md)
- **Master Tasks**: [`docs/tasks.md`](../tasks.md)
- **Grain Bubble Agent Plan**: [`docs/plans/plan_bubble.md`](plan_bubble.md)

---

**Note**: This task list focuses on building Grain Bubble as a native Grain OS application following the SLC philosophy. All tasks follow Grain Style guidelines strictly and integrate with existing Grain Core modules.

**Important Rule**: Never use trademark names (Figma, Framer, etc.) in code, documentation, or anywhere. Describe the product from first principles as if visual design tools never existed before. Focus on what Grain Bubble is, not what it's similar to.

