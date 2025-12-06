# Grain Bubble Agent: Development Plan

**Agent**: Grain Bubble Agent (8th Agent)  
**Status**: Phase 1 Starting — Core Canvas (SLC v1.0)  
**Last Updated**: 2025-12-05-143400-pst

---

## Overview

Grain Bubble Agent is responsible for building Grain Bubble — a native visual design tool for Grain OS. Following the SLC (Simple, Lovable, Complete) philosophy, we're building version 1.0 of a simple design tool, not version 0.1 of a complex one.

**Key Goals**:
- Native desktop design tool with infinite canvas
- Rounded "bubble" design elements (thought bubbles, flow charts)
- Complete export pipeline (PDF, HTML, framework bundles)
- Agent flow automation (visual workflow design)
- Deep integration with Grain OS ecosystem

**Philosophy**: Simple, Lovable, Complete — not an MVP. Customers don't want to use an unfinished product. Grain Bubble v1.0 should be something designers genuinely want to use, as-is.

**Design Principles** (from first principles):
- **Infinite Canvas**: Design space without boundaries, with zoom and pan navigation
- **Vector Graphics**: Shapes and text rendered as scalable vector graphics
- **Layer System**: Organized design elements in layers with z-ordering
- **Component Reusability**: Create once, reuse many times with variants
- **Native Integration**: Feels like part of Grain OS, not a separate application
- **Export Everything**: Design once, export to multiple formats (PDF, HTML, code)

---

## Implementation Phases

### Phase 1: Core Canvas (SLC v1.0) ⏳ **IN PROGRESS**

**Priority**: **HIGHEST** — Foundation for all features  
**Status**: **STARTING**  
**Estimated Time**: 4-6 weeks  
**Date Started**: 2025-12-05-143400-pst

**Goal**: Simple, lovable, complete design canvas

**Features**:
- Infinite canvas with zoom/pan
- Basic shapes (rectangles, circles, rounded rectangles — "bubbles")
- Text tool (typography, text styling)
- Layer management (groups, z-ordering)
- Selection and manipulation (drag, resize, rotate)
- Export to PDF (high-quality vector graphics)

**Success Criteria**:
- Can create a simple design (e.g., a button, a card) in under 5 minutes
- Can export to high-quality PDF
- Smooth, responsive interactions (60 FPS)
- Delightful UX (not just functional)

**Dependencies**:
- **Needs**: Grain Core compositor (`grain_core/compositor.zig`)
- **Needs**: Grain OS framebuffer renderer (`grain_core/framebuffer_renderer.zig`)
- **Needs**: Grain OS input handler (`grain_core/input_handler.zig`)
- **Needs**: Grain OS font renderer (`grain_core/font_renderer.zig`)
- **Needs**: Grain OS layout system (`grain_core/layout.zig`)
- **Provides**: Design canvas foundation for future phases

**Module Structure**:
```
src/grain_bubble/
├── root.zig                 # Module exports
├── canvas.zig               # Canvas engine (infinite canvas, zoom/pan)
├── bubble_renderer.zig      # Bubble/rounded shape rendering
└── export_pdf.zig           # PDF export (Phase 1)
```

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize` unless necessary)
- Bounded allocations (MAX_LAYERS, MAX_SHAPES, MAX_TEXT_LEN, etc.)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line (graincard compatibility: 73 chars)
- No recursion (iterative algorithms only)
- All compiler warnings enabled

---

### Phase 2: Component System (PLANNED)

**Priority**: **HIGH** — Reusable design components  
**Status**: **PLANNED**  
**Estimated Time**: 3-4 weeks

**Goal**: Reusable component library

**Features**:
- Component creation and editing
- Component variants (states, sizes, themes)
- Design tokens (colors, typography, spacing)
- Component library UI
- Component export

**Dependencies**:
- **Needs**: Phase 1 complete
- **Needs**: Grain Core compositor for UI
- **Provides**: Reusable design components

**Module Structure**:
```
src/grain_bubble/
├── component.zig            # Component system
└── design_tokens.zig        # Design tokens (colors, typography)
```

---

### Phase 3: Silo/Court Integration (PLANNED)

**Priority**: **MEDIUM** — Intelligent design features  
**Status**: **PLANNED**  
**Estimated Time**: 4-5 weeks

**Goal**: Intelligent design features

**Features**:
- Design asset storage (Grain Silo)
- Vector search for component matching (Grain Court)
- LLM design suggestions
- Design graph storage (DAG)
- Design version history

**Dependencies**:
- **Needs**: Phase 1 complete
- **Needs**: Grain Silo (`grain_silo/storage.zig`)
- **Needs**: Grain Court (`grain_court/compute.zig`)
- **Needs**: DAG core (if exists)
- **Provides**: Intelligent design assistance

**Module Structure**:
```
src/grain_bubble/
├── silo_integration.zig     # Silo backend integration
├── court_integration.zig    # Court backend integration
└── dag_integration.zig      # DAG integration
```

---

### Phase 4: Export Pipeline (PLANNED)

**Priority**: **HIGH** — Complete export capabilities  
**Status**: **PLANNED**  
**Estimated Time**: 3-4 weeks

**Goal**: Complete export capabilities

**Features**:
- Responsive HTML export
- Framework bundle generation (React/Vue/Svelte)
- SLC asset bundles (self-contained demos)
- Export optimization
- Export preview

**Dependencies**:
- **Needs**: Phase 1 complete (PDF export)
- **Needs**: Phase 2 complete (components)
- **Provides**: Production-ready exports

**Module Structure**:
```
src/grain_bubble/
├── export_html.zig          # HTML export
├── export_framework.zig     # Framework bundle export
└── export_slc.zig           # SLC asset bundles
```

---

### Phase 5: Agent Flow Design (PLANNED)

**Priority**: **MEDIUM** — Visual agent workflow design  
**Status**: **PLANNED**  
**Estimated Time**: 4-5 weeks

**Goal**: Visual agent workflow design

**Features**:
- Flow chart editor (bubbles and connections)
- Agent node configuration
- Flow execution visualization
- Flow export
- Agent integration

**Dependencies**:
- **Needs**: Phase 1 complete (canvas, shapes)
- **Needs**: Phase 3 complete (DAG integration)
- **Provides**: Visual agent workflow design

**Module Structure**:
```
src/grain_bubble/
└── agent_flow.zig           # Agent flow design
```

---

## Technical Architecture

### Target Platform

- **Kernel**: Basin Kernel (RISC-V64)
- **Runtime**: Vantage VM (RISC-V → AArch64 JIT for macOS development)
- **Desktop-Only**: Native desktop application, no web version
- **Language**: Zig (Grain Style compliant)

### Core Modules

#### 1. **Grain OS Integration**

Leverage existing Grain Core modules:

- **Compositor** (`grain_core/compositor.zig`): Window management, surface rendering
- **Framebuffer Renderer** (`grain_core/framebuffer_renderer.zig`): Pixel-level rendering
- **Input Handler** (`grain_core/input_handler.zig`): Mouse, keyboard, touch input
- **Layout System** (`grain_core/layout.zig`): Layout algorithms for design canvas
- **Font Renderer** (`grain_core/font_renderer.zig`): Text rendering for design elements

#### 2. **Design Canvas Engine**

**Bubble Canvas**:
- Infinite canvas with zoom/pan
- Rounded rectangle primitives ("bubbles")
- Vector graphics rendering (paths, curves, shapes)
- Layer management (groups, z-ordering)
- Selection and manipulation (drag, resize, rotate)

#### 3. **Backend Integration** (Phase 3+)

- **Grain Silo** (`grain_silo/storage.zig`): Object storage for design assets
- **Grain Court** (`grain_court/compute.zig`): Vector search, LLM model tuning
- **Grain Database** (`grain_database/`): Database persistence for design projects
- **DAG Core** (if exists): DAG event ordering for design history

---

## Coordination Points

### With Grain Core Agent

**Shared Components**:
- Compositor for window management
- Framebuffer renderer for canvas rendering
- Input handler for mouse/keyboard input
- Font renderer for text rendering
- Layout system for design layout algorithms

**Integration Points**:
- Grain Bubble uses Grain Core compositor for window management
- Canvas rendering uses Grain Core framebuffer renderer
- Input events routed through Grain Core input handler
- Text rendering uses Grain Core font renderer

**Coordination Tasks**:
- Coordinate on compositor integration
- Share GUI component patterns
- Coordinate on window management APIs

### With Database Agent

**Integration Points**:
- Design project storage (key-value for project metadata)
- Relational queries for design component relationships
- Graph queries for design flow connections
- Full-text search for design asset discovery

**Coordination Tasks**:
- Coordinate on design project storage
- Integrate with database query capabilities

### With Carry Agent

**Integration Points**:
- Export formats (mobile-responsive HTML)
- Design token systems (shared color palettes, typography)

**Coordination Tasks**:
- Coordinate on export formats (mobile-responsive HTML)
- Share design token systems

### With Skate Agent

**Integration Points**:
- DAG integration (if applicable)
- Graph storage patterns

**Coordination Tasks**:
- Coordinate on DAG integration (if applicable)
- Share graph storage patterns

---

## Success Metrics

### SLC Validation

**Simple**: 
- Can a designer create a complete design in under 5 minutes?
- Is the interface intuitive without training?
- Are there fewer than 10 core features in v1.0?

**Lovable**:
- Do designers want to use it (not just "it works")?
- Are interactions smooth and delightful?
- Does it feel native to Grain OS?

**Complete**:
- Can designs be exported to production-ready formats?
- Are all v1.0 features fully functional?
- Can it be used productively without waiting for updates?

### Technical Metrics

- **Performance**: 60 FPS canvas rendering
- **Memory**: Bounded allocations (no unbounded growth)
- **Export Quality**: PDF exports match design fidelity
- **Integration**: Seamless Silo/Court/Database integration

---

## Important Rules

**Trademark Policy**: Never use trademark names (Figma, Framer, etc.) in code, documentation, comments, or anywhere in the codebase. Describe Grain Bubble from first principles as if visual design tools never existed before. Focus on what Grain Bubble is and what it enables, not what it's similar to.

**Examples of Good Descriptions**:
- "Infinite canvas with zoom and pan navigation"
- "Vector graphics design tool with layer management"
- "Native desktop application for visual design"
- "Design tool with component reusability and export capabilities"

**Examples to Avoid**:
- "Figma-like design tool"
- "Similar to Framer"
- "Inspired by [trademark]"

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Proposal**: [`docs/proposals/grain_bubble_proposal.md`](../proposals/grain_bubble_proposal.md)
- **Master Plan**: [`docs/plan.md`](../plan.md)
- **Grain OS Modules**: `src/grain_core/`
- **Silo/Court**: `src/grain_silo/`, `src/grain_court/`
- **Database**: `src/grain_database/`
- **SLC Philosophy**: https://longform.asmartbear.com/slc/

---

**Note**: This plan focuses on building Grain Bubble as a native Grain OS application following the SLC philosophy. All phases integrate with existing Grain Core modules and follow Grain Style guidelines strictly. Descriptions are written from first principles without referencing external trademarked products.
