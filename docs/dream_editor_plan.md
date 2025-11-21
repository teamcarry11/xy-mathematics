# Dream Editor Implementation Plan

**Goal**: Build the Zig-native IDE described in learning course 0001, inspired by Matklad's vision, with GLM-4.6 integration.

**Status**: Starting implementation, working in parallel with VM/kernel boot work (zero conflict).

## Foundation: Current Aurora State

### Existing Components ✅

- `aurora_editor.zig` - Basic editor with buffer, LSP client, cursor
- `aurora_lsp.zig` - LSP client stub (needs JSON-RPC completion)
- `grain_aurora.zig` - UI component system with readonly span support
- `aurora_text_renderer.zig` - Text rendering with 8x8 bitmap font
- `grain_buffer.zig` - Text buffer implementation

### What's Missing

1. **Readonly Character Spans** - Matklad's core feature (text-as-UI)
2. **Method Folding** - Fold method bodies by default, keep signatures
3. **Tree-sitter Integration** - Syntax highlighting, structural editing
4. **GLM-4.6 Client** - Cerebras API integration (1,000 tps)
5. **Complete LSP** - JSON-RPC implementation, snapshot model
6. **Magit-Style VCS** - Virtual files (`.jj/status.jj`), readonly metadata
7. **Multi-Pane Layout** - River compositor integration

## Implementation Phases

### Phase 1: Readonly Spans (Matklad Core Feature)

**Goal**: Enable readonly character ranges in text buffers for interactive UIs.

**Files to Modify**:
- `src/grain_buffer.zig` - Add readonly span tracking
- `src/aurora_editor.zig` - Use readonly spans in render

**Features**:
- Mark text ranges as readonly (cannot be edited)
- Visual distinction (different color/background)
- Edit protection (prevent modifications to readonly ranges)
- Support for VCS status buffers, terminal output, etc.

**GrainStyle**:
- Explicit span tracking: `(start: usize, end: usize, flags: u32)`
- Bounded: Max 1000 readonly spans per buffer
- Assertions: Verify spans don't overlap, are within buffer bounds

### Phase 2: Method Folding

**Goal**: Fold method bodies by default, keep signatures visible.

**Files to Create**:
- `src/aurora_folding.zig` - Folding logic

**Files to Modify**:
- `src/aurora_editor.zig` - Integrate folding

**Features**:
- Parse code structure (Tree-sitter or simple regex)
- Identify method/function boundaries
- Fold bodies by default, show signatures
- Toggle folding with keyboard shortcut
- Visual indicators (fold markers)

**GrainStyle**:
- Explicit parsing: No hidden state
- Bounded: Max 1000 foldable regions
- Assertions: Verify fold boundaries are valid

### Phase 3: Tree-sitter Integration

**Goal**: Syntax highlighting and structural editing.

**Files to Create**:
- `src/aurora_tree_sitter.zig` - Tree-sitter wrapper

**Dependencies**:
- Tree-sitter C library (via `@cImport` or bindings)
- Zig grammar (tree-sitter-zig)

**Features**:
- Parse code into syntax tree
- Syntax highlighting (colorize tokens)
- Structural navigation (move by syntax node)
- Code actions (extract function, rename symbol)

**GrainStyle**:
- Explicit tree nodes: No hidden parsing state
- Bounded: Max tree depth 100
- Assertions: Verify tree is valid after edits

### Phase 4: GLM-4.6 Client

**Goal**: Integrate Cerebras GLM-4.6 for agentic coding (1,000 tokens/second).

**Files to Create**:
- `src/aurora_glm46.zig` - GLM-4.6 client

**API**:
- Cerebras OpenAI-compatible endpoint: `https://api.cerebras.ai/v1`
- Model: `glm-4.6`
- Streaming: SSE (Server-Sent Events) for 1,000 tps

**Features**:
- Code completion (ghost text at 1,000 tps)
- Code transformation (refactor, extract, inline)
- Tool calling (run `zig build`, `jj status`, etc.)
- Multi-file edits (context-aware changes)

**GrainStyle**:
- Explicit API calls: No hidden network state
- Bounded: Max 200K token context window
- Assertions: Verify API responses are valid

### Phase 5: Complete LSP Implementation

**Goal**: Full JSON-RPC LSP client with Matklad snapshot model.

**Files to Modify**:
- `src/aurora_lsp.zig` - Complete JSON-RPC implementation

**Features**:
- JSON-RPC 2.0 serialization/deserialization
- Snapshot model (incremental updates, not full reparse)
- Cancellation support (cancel in-flight requests)
- Zig-specific features (comptime analysis, build integration)

**GrainStyle**:
- Explicit message types: No hidden JSON parsing
- Bounded: Max 8KB message size
- Assertions: Verify JSON is valid before parsing

### Phase 6: Magit-Style VCS

**Goal**: Virtual file system for VCS status (`.jj/status.jj`, `.jj/commit/*.diff`).

**Files to Create**:
- `src/aurora_vcs.zig` - VCS integration
- `src/aurora_vfs.zig` - Virtual file system

**Features**:
- Generate `.jj/status.jj` file (readonly metadata, editable hunks)
- Generate `.jj/commit/*.diff` files (readonly commit info, editable diff)
- Watch for edits, invoke `jj` commands via tool calls
- Readonly spans for commit hashes, parent info
- Editable spans for commit messages, diff hunks

**GrainStyle**:
- Explicit file generation: No hidden VCS state
- Bounded: Max 1000 files in VFS
- Assertions: Verify VCS commands succeed

### Phase 7: Multi-Pane Layout

**Goal**: River compositor integration for multi-pane editor.

**Files to Create**:
- `src/aurora_layout.zig` - Layout engine
- `src/aurora_river.zig` - River compositor integration

**Features**:
- Split panes (horizontal/vertical)
- Tile windows (editor, terminal, VCS status)
- Moonglow keybindings
- Workspace management

**GrainStyle**:
- Explicit layout tree: No hidden layout state
- Bounded: Max 100 panes per workspace
- Assertions: Verify layout is valid

## Architecture

```
┌─────────────────────────────────────┐
│   Dream Editor (Zig Native)        │
├─────────────────────────────────────┤
│   - Readonly Spans (Matklad)        │
│   - Method Folding                  │
│   - Tree-sitter (Syntax)            │
│   - GLM-4.6 Client (1,000 tps)      │
│   - LSP Client (Complete)           │
│   - Magit VCS (Virtual Files)       │
│   - Multi-Pane Layout (River)       │
└─────────────────────────────────────┘
```

## Dependencies

### External

- **Tree-sitter**: C library (via `@cImport`)
- **Cerebras API**: HTTP client (use `std.http` or `zig-fetch`)
- **ZLS**: Zig Language Server (spawn as subprocess)

### Internal

- **GrainBuffer**: Text buffer (already exists)
- **GrainAurora**: UI components (already exists)
- **macOS Window**: Platform integration (already exists)

## GrainStyle Requirements

### Explicit Limits

- Max 1000 readonly spans per buffer
- Max 1000 foldable regions per buffer
- Max tree depth 100
- Max 200K token context window
- Max 8KB LSP message size
- Max 1000 files in VFS
- Max 100 panes per workspace

### Assertions

- Verify readonly spans don't overlap
- Verify fold boundaries are valid
- Verify syntax tree is valid after edits
- Verify API responses are valid
- Verify JSON is valid before parsing
- Verify VCS commands succeed
- Verify layout is valid

### Function Length

- Max 70 lines per function
- Split complex functions into helpers

### Static Allocation

- Pre-allocate message buffers
- Pre-allocate span arrays
- No dynamic allocation in hot paths

## Success Criteria

### Phase 1 Complete When

- Readonly spans work in text buffers
- Visual distinction (different color)
- Edit protection (cannot modify readonly ranges)
- Tests pass

### Phase 2 Complete When

- Method bodies fold by default
- Signatures remain visible
- Toggle folding works
- Visual indicators show

### Phase 3 Complete When

- Syntax highlighting works
- Structural navigation works
- Code actions work
- Tests pass

### Phase 4 Complete When

- GLM-4.6 client connects to Cerebras
- Ghost text appears at 1,000 tps
- Code transformations work
- Tool calling works

### Phase 5 Complete When

- LSP JSON-RPC works
- Snapshot model works
- Cancellation works
- Zig-specific features work

### Phase 6 Complete When

- Virtual files generate correctly
- Readonly spans protect metadata
- Editable spans allow edits
- VCS commands invoked correctly

### Phase 7 Complete When

- Multi-pane layout works
- River compositor integrated
- Moonglow keybindings work
- Workspace management works

## Next Steps

1. **Start with Phase 1**: Readonly spans (foundational feature)
2. **Then Phase 4**: GLM-4.6 client (high-value, enables agentic coding)
3. **Then Phase 2**: Method folding (Matklad feature)
4. **Then Phase 3**: Tree-sitter (syntax highlighting)
5. **Then Phase 5**: Complete LSP (language features)
6. **Then Phase 6**: Magit VCS (VCS integration)
7. **Finally Phase 7**: Multi-pane layout (UI polish)

---

**This work is completely independent of VM/kernel boot work. Zero conflicts.**

