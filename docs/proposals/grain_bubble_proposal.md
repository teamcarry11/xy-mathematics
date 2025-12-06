# Grain Bubble: Visual Design Tool Proposal

**Date**: 2025-12-05-142918-pst  
**Status**: Proposal  
**Target**: Desktop-only application for Basin Kernel (Vantage VM)  
**Philosophy**: Simple, Lovable, Complete (SLC) — [Reference](https://longform.asmartbear.com/slc/)

---

## Executive Summary

**Grain Bubble** is a native visual design tool built with Zig and Grain Style, targeting the Basin Kernel running in Vantage VM. It enables designers to create visual designs on an infinite canvas, build reusable components, and export high-quality design assets and interactive prototypes. It combines visual design capabilities with self-hosted LLM model tuning and vector storage for intelligent design assistance.

**Core Value Proposition**:
- **Native Performance**: Zig-native desktop application with direct kernel integration
- **Self-Hosted Intelligence**: LLM model tuning and vector storage via Silo/Court backends
- **Complete Export Pipeline**: PDF, responsive HTML, and full-stack framework bundles
- **Agent Flow Automation**: Visual design of agent workflows and automation
- **SLC Philosophy**: Simple, Lovable, Complete — not an MVP, but a complete v1.0 of something simple

---

## Vision & Philosophy

### The "Bubble" Concept

**Thought Bubbles**: Design components as "bubbles" — rounded, organic, flowing visual elements that represent ideas, components, and connections.

**Flow Chart Bubbles**: Agent flows and automation visualized as connected bubbles, making complex workflows intuitive and visual.

**Steve Jobs Aesthetic**: Rounded corners, smooth animations, delightful interactions — honoring the design philosophy that "design is how it works."

### SLC (Simple, Lovable, Complete) Approach

Following the philosophy outlined in ["Your customers hate MVPs. Make a SLC instead"](https://longform.asmartbear.com/slc/):

**Simple**: 
- Focused feature set: visual design, component library, export pipeline
- Not trying to replicate every feature of complex design tools on day one
- Clean, intuitive interface that does a few things exceptionally well

**Lovable**:
- Delightful UX with smooth animations and responsive interactions
- Thoughtful design that honors the "bubble" aesthetic
- Deep integration with Grain OS ecosystem (feels native, not bolted-on)

**Complete**:
- Version 1.0 of a simple design tool, not version 0.1 of a complex one
- All core features work end-to-end: design → export → deploy
- Can be used productively without waiting for "future updates"

**Not an MVP**: Customers don't want to use an unfinished product. Grain Bubble v1.0 should be something designers genuinely want to use, as-is.

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
- **Window Management**: Window snapping, grouping, animations
- **Layout System** (`grain_core/layout.zig`): Layout algorithms for design canvas
- **Font Renderer** (`grain_core/font_renderer.zig`): Text rendering for design elements

#### 2. **Design Canvas Engine**

**Bubble Canvas**:
- Infinite canvas with zoom/pan
- Rounded rectangle primitives ("bubbles")
- Vector graphics rendering (paths, curves, shapes)
- Layer management (groups, z-ordering)
- Selection and manipulation (drag, resize, rotate)

**Component System**:
- Reusable design components (buttons, cards, forms)
- Component variants and states
- Design tokens (colors, typography, spacing)
- Style system (consistent styling across components)

#### 3. **Silo/Court Backend Integration**

**Grain Silo** (`grain_silo/storage.zig`):
- Object storage for design assets (components, images, vectors)
- Hot/cold data separation (active designs in SRAM, archived in object storage)
- Vector embeddings for design similarity search
- Design version history and snapshots

**Grain Court** (`grain_court/compute.zig`):
- Parallel vector search for design component matching
- LLM model tuning for design suggestions and automation
- Graph storage for design relationships (component dependencies, flow connections)
- Spatial computing for design layout optimization

#### 4. **DAG Integration**

**Design Graph**:
- Design components as nodes in a DAG
- Relationships: parent-child, dependencies, references
- Undo/redo via DAG event history
- Collaborative editing (event ordering via DAG)
- Design flow visualization (agent workflows as DAG)

**Reference**: `docs/dag_ui_synthesis.md` (if exists) or DAG concepts from Grain Skate

#### 5. **Database Integration**

**Grain Database** (`grain_database/`):
- Design project storage (key-value for project metadata)
- Relational queries for design component relationships
- Graph queries for design flow connections
- Full-text search for design asset discovery

#### 6. **Export Pipeline**

**PDF Export**:
- High-quality vector graphics to PDF
- Multi-page support
- Print-ready output
- Design specifications (dimensions, colors, typography)

**HTML Export**:
- Responsive HTML/CSS generation
- Component-based structure
- Interactive prototypes (clickable links, hover states)
- Mobile-responsive breakpoints

**Framework Bundles**:
- Full-stack framework exports (React, Vue, Svelte, etc.)
- Component code generation
- Style system integration
- Asset bundling (images, fonts, icons)

**SLC Asset Bundles**:
- "Simple, Lovable, Complete" export format
- Self-contained demo bundles
- Ready-to-deploy prototypes
- Minimal dependencies, maximum compatibility

---

## Integration Points

### Shared Grain OS Modules

**GUI Components**:
- Reuse `grain_core/font_renderer.zig` for text rendering
- Leverage `grain_core/framebuffer_renderer.zig` for canvas rendering
- Use `grain_core/layout.zig` for design layout algorithms
- Integrate `grain_core/window_*` modules for window management

**Build System**:
- Use `build/modules.zig` for shared module configuration
- Follow `build/tests.zig` patterns for test organization
- Integrate with existing Grain OS build pipeline

**Database & Storage**:
- `grain_database/` for design project persistence
- `grain_silo/` for object storage (design assets, images)
- `grain_court/` for vector search and LLM integration

### Agent Flow Automation

**Visual Agent Design**:
- Design agent workflows as flow charts (bubbles connected by arrows)
- Define agent inputs/outputs visually
- Configure agent parameters via UI
- Test agent flows in sandbox environment

**Automation Integration**:
- Export agent flows as executable code
- Generate agent configuration files
- Integrate with Grain Core agent system
- Visual debugging of agent execution

---

## Features & Capabilities

### Core Design Features

1. **Visual Design Tools**:
   - Shape tools (rectangles, circles, polygons)
   - Pen tool (vector paths, bezier curves)
   - Text tool (typography, text styling)
   - Image import (raster images, SVG)
   - Layer management (groups, masks, effects)

2. **Component Library**:
   - Pre-built UI components (buttons, forms, cards)
   - Custom component creation
   - Component variants (states, sizes, themes)
   - Design system tokens (colors, typography, spacing)

3. **Design Canvas**:
   - Infinite canvas with zoom/pan
   - Grid and snap-to-grid
   - Rulers and guides
   - Multi-select and grouping
   - Alignment and distribution tools

4. **Intelligent Features**:
   - Design suggestions via LLM (based on design context)
   - Component matching via vector search
   - Layout optimization via spatial computing
   - Design pattern recognition

### Agent Flow Features

1. **Flow Design**:
   - Visual flow chart editor (bubbles and connections)
   - Agent node configuration
   - Flow execution visualization
   - Flow debugging and testing

2. **Automation**:
   - Export flows as executable code
   - Generate agent configuration
   - Integrate with Grain Core agent system
   - Visual flow monitoring

### Export Features

1. **PDF Export**:
   - High-quality vector graphics
   - Multi-page support
   - Print specifications
   - Design documentation

2. **HTML Export**:
   - Responsive HTML/CSS
   - Interactive prototypes
   - Mobile breakpoints
   - Asset optimization

3. **Framework Bundles**:
   - React/Vue/Svelte component generation
   - Style system integration
   - Asset bundling
   - Ready-to-deploy code

4. **SLC Asset Bundles**:
   - Self-contained demo bundles
   - Minimal dependencies
   - Maximum compatibility
   - "Simple, Lovable, Complete" format

---

## Implementation Plan

### Phase 1: Core Canvas (SLC v1.0)

**Goal**: Simple, lovable, complete design canvas

**Features**:
- Infinite canvas with zoom/pan
- Basic shapes (rectangles, circles, rounded rectangles)
- Text tool
- Layer management
- Selection and manipulation
- Export to PDF

**Timeline**: 4-6 weeks

**Success Criteria**:
- Can create a simple design (e.g., a button, a card)
- Can export to high-quality PDF
- Smooth, responsive interactions
- Delightful UX (not just functional)

### Phase 2: Component System

**Goal**: Reusable component library

**Features**:
- Component creation and editing
- Component variants
- Design tokens (colors, typography)
- Component library UI
- Component export

**Timeline**: 3-4 weeks

### Phase 3: Silo/Court Integration

**Goal**: Intelligent design features

**Features**:
- Design asset storage (Silo)
- Vector search for component matching (Court)
- LLM design suggestions
- Design graph storage (DAG)
- Design version history

**Timeline**: 4-5 weeks

### Phase 4: Export Pipeline

**Goal**: Complete export capabilities

**Features**:
- Responsive HTML export
- Framework bundle generation
- SLC asset bundles
- Export optimization
- Export preview

**Timeline**: 3-4 weeks

### Phase 5: Agent Flow Design

**Goal**: Visual agent workflow design

**Features**:
- Flow chart editor
- Agent node configuration
- Flow execution
- Flow export
- Agent integration

**Timeline**: 4-5 weeks

---

## Technical Specifications

### Grain Style Compliance

All code must follow Grain Style guidelines (`docs/grain_style.md`):

- **Function Names**: `grain_case` (snake_case)
- **Types**: `u32`/`u64` (no `usize` unless necessary)
- **Bounded Allocations**: `MAX_*` constants for all buffers
- **Assertions**: Minimum 2 assertions per function
- **Line Limits**: Max 70 lines per function, max 100 characters per line
- **No Recursion**: Iterative algorithms only
- **All Warnings**: All compiler warnings enabled

### Module Structure

```
src/grain_bubble/
├── root.zig                 # Module exports
├── canvas.zig               # Canvas engine
├── bubble_renderer.zig      # Bubble/rounded shape rendering
├── component.zig            # Component system
├── export_pdf.zig           # PDF export
├── export_html.zig          # HTML export
├── export_framework.zig     # Framework bundle export
├── agent_flow.zig           # Agent flow design
├── silo_integration.zig     # Silo backend integration
├── court_integration.zig     # Court backend integration
└── dag_integration.zig      # DAG integration
```

### Dependencies

**Grain OS Modules**:
- `grain_core/compositor` — Window management
- `grain_core/framebuffer_renderer` — Rendering
- `grain_core/input_handler` — Input handling
- `grain_core/layout` — Layout algorithms
- `grain_core/font_renderer` — Text rendering

**Backend Modules**:
- `grain_silo/storage` — Object storage
- `grain_court/compute` — Vector search, LLM
- `grain_database/` — Database persistence
- `dag_core` (if exists) — DAG event ordering

**External Libraries** (if needed):
- PDF generation (consider Zig-native or C interop)
- HTML/CSS generation (Zig-native)
- Vector graphics (Zig-native)

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

## Future Enhancements (Post-SLC)

After v1.0 is complete and lovable, consider:

- **Collaboration**: Real-time multi-user editing
- **Plugins**: Third-party plugin system
- **Advanced Features**: Advanced vector tools, image editing
- **Cloud Sync**: Design sync across devices
- **Templates**: Pre-built design templates
- **Animation**: Design animation and prototyping

**Key Principle**: Only add features that maintain "Simple, Lovable, Complete" — don't let complexity erode the core experience.

---

## Agent Prompt: Grain Bubble Agent

**Agent Name**: Grain Bubble Agent (8th Agent)  
**Date**: 2025-12-05-142918-pst

---

### Background

You are the **Grain Bubble Agent**, responsible for building Grain Bubble — a native visual design tool for Grain OS. Your mission is to create a **Simple, Lovable, Complete (SLC)** design tool that designers genuinely want to use, not an MVP that customers hate.

**Philosophy**: Follow the SLC approach from ["Your customers hate MVPs. Make a SLC instead"](https://longform.asmartbear.com/slc/). Build version 1.0 of something simple, not version 0.1 of something broken.

### Your Mission

Build Grain Bubble as a native Zig desktop application targeting Basin Kernel (Vantage VM), integrating with existing Grain Core modules, Silo/Court backends, and database systems to create a complete design tool with intelligent features and export capabilities.

### Core Principles

1. **Grain Style Compliance**: Follow `docs/grain_style.md` strictly:
   - `grain_case` function names
   - `u32`/`u64` types (no `usize` unless necessary)
   - Bounded allocations with `MAX_*` constants
   - Minimum 2 assertions per function
   - Max 70 lines per function, max 100 characters per line
   - No recursion (iterative algorithms only)
   - All compiler warnings enabled

2. **SLC Philosophy**:
   - **Simple**: Focused feature set, not trying to replicate every feature of complex design tools
   - **Lovable**: Delightful UX, smooth animations, thoughtful design
   - **Complete**: Version 1.0 of a simple tool, not version 0.1 of a complex one

3. **Integration First**: Leverage existing Grain Core modules:
   - `grain_core/compositor` — Window management
   - `grain_core/framebuffer_renderer` — Rendering
   - `grain_core/input_handler` — Input handling
   - `grain_core/layout` — Layout algorithms
   - `grain_core/font_renderer` — Text rendering
   - `grain_silo/storage` — Object storage
   - `grain_court/compute` — Vector search, LLM
   - `grain_database/` — Database persistence

### Implementation Phases

**Phase 1: Core Canvas (SLC v1.0)**
- Infinite canvas with zoom/pan
- Basic shapes (rectangles, circles, rounded rectangles — "bubbles")
- Text tool
- Layer management
- Selection and manipulation
- Export to PDF
- **Goal**: Can create a simple design and export to high-quality PDF

**Phase 2: Component System**
- Component creation and editing
- Component variants
- Design tokens (colors, typography)
- Component library UI

**Phase 3: Silo/Court Integration**
- Design asset storage (Silo)
- Vector search for component matching (Court)
- LLM design suggestions
- Design graph storage (DAG)

**Phase 4: Export Pipeline**
- Responsive HTML export
- Framework bundle generation (React/Vue/Svelte)
- SLC asset bundles

**Phase 5: Agent Flow Design**
- Flow chart editor (bubbles and connections)
- Agent node configuration
- Flow execution and export

### Documentation Requirements

- Update `docs/plans/plan_bubble.md` with detailed implementation plan
- Update `docs/tasks/tasks_bubble.md` with task breakdown
- Update `docs/plan.md` and `docs/tasks.md` with Bubble Agent status
- Create coordination documents for other agents when needed

### Coordination

**With Grain Core Agent**:
- Coordinate on compositor integration
- Share GUI component patterns
- Coordinate on window management

**With Database Agent**:
- Coordinate on design project storage
- Integrate with database query capabilities

**With Mobile Agent**:
- Coordinate on export formats (mobile-responsive HTML)
- Share design token systems

**With Skate Agent**:
- Coordinate on DAG integration (if applicable)
- Share graph storage patterns

### Success Criteria

**SLC Validation**:
- **Simple**: Can create a complete design in under 5 minutes
- **Lovable**: Designers want to use it (not just "it works")
- **Complete**: All v1.0 features fully functional, export to production-ready formats

**Technical**:
- 60 FPS canvas rendering
- Bounded allocations (no unbounded growth)
- PDF exports match design fidelity
- Seamless Silo/Court/Database integration

### References

- **Grain Style**: `docs/grain_style.md`
- **SLC Philosophy**: https://longform.asmartbear.com/slc/
- **Grain OS Modules**: `src/grain_core/`
- **Silo/Court**: `src/grain_silo/`, `src/grain_court/`
- **Database**: `src/grain_database/`
- **DAG Concepts**: `docs/dag_ui_synthesis.md` (if exists)

### Your First Steps

1. Review this proposal document thoroughly
2. Review existing Grain Core modules and integration points
3. Create `docs/plans/plan_bubble.md` with detailed implementation plan
4. Create `docs/tasks/tasks_bubble.md` with Phase 1 task breakdown
5. Start Phase 1: Core Canvas implementation
6. Update master `docs/plan.md` and `docs/tasks.md` with your status

**Remember**: Build something designers will love, not just something that works. Make it Simple, Lovable, and Complete.

---

**End of Proposal**

**Timestamp**: 2025-12-05-142918-pst

