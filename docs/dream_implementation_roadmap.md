# Dream Editor + Browser: Unified Implementation Roadmap

**Goal**: Implement both Dream Editor and Dream Browser together, leveraging shared components and parallel development streams.

**Status**: Planning phase, ready to begin implementation.

## Shared Foundation Components

### Core Infrastructure (Build First)

These components are shared between editor and browser:

1. **GrainBuffer** (✅ Already exists)
   - Text buffer with readonly spans
   - Used by: Editor (code), Browser (web content)
   - Status: Exists, needs enhancement (1000 segments)

2. **GrainAurora UI** (✅ Already exists)
   - Component-first rendering
   - Readonly spans support
   - Used by: Editor (UI), Browser (rendering)
   - Status: Exists, needs multi-pane layout

3. **Dream Protocol** (🔄 To build)
   - Nostr + WebSocket + State machine
   - Used by: Editor (collaboration), Browser (content)
   - Status: Foundation needed

4. **GLM-4.6 Client** (🔄 Started)
   - Cerebras API integration
   - Used by: Editor (agentic coding), Browser (content generation)
   - Status: Foundation created, needs HTTP implementation

## Implementation Phases

### Phase 0: Shared Foundation (Week 1-2)

**Goal**: Build shared components that both editor and browser need.

#### 0.1: Enhance GrainBuffer

**Files**: `src/grain_buffer.zig`

**Tasks**:
- [ ] Increase `max_segments` from 64 to 1000
- [ ] Add visual rendering support (color/background for readonly)
- [ ] Add span query functions (`isReadonly`, `getReadonlySpans`)
- [ ] Performance optimization (binary search for span lookup)

**GrainStyle**:
- Explicit limits: Max 1000 segments
- Assertions: Verify spans don't overlap, are within bounds
- Bounded: Pre-allocate segment array

**Estimated**: 2-3 days

#### 0.2: Complete GLM-4.6 Client

**Files**: `src/aurora_glm46.zig`

**Tasks**:
- [ ] Implement HTTP client (use `std.http` or `zig-fetch`)
- [ ] JSON serialization/deserialization
- [ ] SSE streaming parser (for 1,000 tps)
- [ ] Error handling and retry logic
- [ ] Connection pooling

**GrainStyle**:
- Explicit API calls: No hidden network state
- Bounded: Max 200K token context, 8KB message size
- Assertions: Verify API responses are valid

**Estimated**: 3-4 days

#### 0.3: Dream Protocol Foundation

**Files**: `src/dream_protocol.zig`, `src/dream_nostr.zig`, `src/dream_websocket.zig`

**Tasks**:
- [ ] Nostr event structure (Zig-native)
- [ ] WebSocket client (low-latency)
- [ ] State machine (TigerBeetle-style)
- [ ] Event streaming (real-time)
- [ ] Relay connection management

**GrainStyle**:
- Explicit state: No hidden protocol state
- Bounded: Max 100 relays, 1MB message size
- Assertions: Verify events are valid, state is consistent

**Estimated**: 5-7 days

**Total Phase 0**: ~2 weeks

---

### Phase 1: Dream Editor Core (Week 3-4)

**Goal**: Build core editor features using shared foundation.

#### 1.1: Readonly Spans Enhancement

**Files**: `src/aurora_editor.zig`, `src/grain_buffer.zig`

**Tasks**:
- [ ] Integrate enhanced GrainBuffer (1000 segments)
- [ ] Visual rendering (different color for readonly)
- [ ] Edit protection (prevent modifications)
- [ ] Cursor handling (skip readonly regions)

**Dependencies**: Phase 0.1 (GrainBuffer enhancement)

**Estimated**: 2-3 days

#### 1.2: Method Folding

**Files**: `src/aurora_folding.zig`, `src/aurora_editor.zig`

**Tasks**:
- [ ] Parse code structure (simple regex or Tree-sitter)
- [ ] Identify method/function boundaries
- [ ] Fold bodies by default, show signatures
- [ ] Toggle folding (keyboard shortcut)
- [ ] Visual indicators (fold markers)

**GrainStyle**:
- Explicit parsing: No hidden state
- Bounded: Max 1000 foldable regions
- Assertions: Verify fold boundaries are valid

**Estimated**: 3-4 days

#### 1.3: GLM-4.6 Integration

**Files**: `src/aurora_editor.zig`, `src/aurora_glm46.zig`

**Tasks**:
- [ ] Code completion (ghost text at 1,000 tps)
- [ ] Code transformation (refactor, extract, inline)
- [ ] Tool calling (run `zig build`, `jj status`)
- [ ] Multi-file edits (context-aware)

**Dependencies**: Phase 0.2 (GLM-4.6 client)

**Estimated**: 4-5 days

**Total Phase 1**: ~2 weeks

---

### Phase 2: Dream Browser Core (Week 3-5, Parallel)

**Goal**: Build core browser features using shared foundation.

#### 2.1: HTML/CSS Parser

**Files**: `src/dream_browser_parser.zig`

**Tasks**:
- [ ] HTML parser (subset of HTML5)
- [ ] CSS parser (subset of CSS3)
- [ ] DOM tree construction
- [ ] Style computation

**GrainStyle**:
- Explicit tree nodes: No hidden parsing state
- Bounded: Max tree depth 100, max 10,000 nodes
- Assertions: Verify tree is valid after parsing

**Estimated**: 5-7 days

#### 2.2: Rendering Engine

**Files**: `src/dream_browser_renderer.zig`, `src/grain_aurora.zig`

**Tasks**:
- [ ] Layout engine (block/inline flow)
- [ ] Render to Grain Aurora components
- [ ] Readonly spans for metadata (event ID, timestamp)
- [ ] Editable spans for content

**Dependencies**: Phase 0.1 (GrainBuffer), Phase 2.1 (Parser)

**Estimated**: 4-5 days

#### 2.3: Nostr Content Loading

**Files**: `src/dream_browser.zig`, `src/dream_protocol.zig`

**Tasks**:
- [ ] Parse Nostr URLs (`nostr:note1...`, `nostr:npub1...`)
- [ ] Subscribe to Nostr events
- [ ] Receive events (streaming, real-time)
- [ ] Render events to browser

**Dependencies**: Phase 0.3 (Dream Protocol)

**Estimated**: 3-4 days

**Total Phase 2**: ~2-3 weeks (can overlap with Phase 1)

---

### Phase 3: Integration & Advanced Features (Week 6-8)

**Goal**: Integrate editor and browser, add advanced features.

#### 3.1: Unified UI

**Files**: `src/dream_ide.zig`, `src/aurora_layout.zig`

**Tasks**:
- [ ] Multi-pane layout (editor + browser)
- [ ] River compositor integration
- [ ] Tab management (editor tabs, browser tabs)
- [ ] Workspace management

**Dependencies**: Phase 1 (Editor), Phase 2 (Browser)

**Estimated**: 5-7 days

#### 3.2: Live Preview

**Files**: `src/dream_ide.zig`, `src/dream_browser.zig`

**Tasks**:
- [ ] Editor edits → Browser preview (real-time)
- [ ] Nostr event updates → Editor sync
- [ ] Bidirectional sync (editor ↔ browser)

**Dependencies**: Phase 3.1 (Unified UI)

**Estimated**: 3-4 days

#### 3.3: VCS Integration

**Files**: `src/aurora_vcs.zig`, `src/aurora_vfs.zig`

**Tasks**:
- [ ] Generate `.jj/status.jj` (readonly metadata, editable hunks)
- [ ] Generate `.jj/commit/*.diff` (readonly commit info, editable diff)
- [ ] Watch for edits, invoke `jj` commands
- [ ] VCS integration for web content (Nostr events)

**Estimated**: 4-5 days

#### 3.4: Tree-sitter Integration

**Files**: `src/aurora_tree_sitter.zig`, `src/aurora_editor.zig`

**Tasks**:
- [ ] Tree-sitter C library bindings
- [ ] Zig grammar integration
- [ ] Syntax highlighting
- [ ] Structural navigation
- [ ] Code actions (extract function, rename symbol)

**Dependencies**: External (Tree-sitter C library)

**Estimated**: 5-7 days

**Total Phase 3**: ~3 weeks

---

### Phase 4: Performance & Polish (Week 9-10)

**Goal**: Optimize performance, add polish.

#### 4.1: Performance Optimization

**Files**: All

**Tasks**:
- [ ] Profile and optimize hot paths
- [ ] Reduce allocations in hot paths
- [ ] Optimize rendering (60fps guaranteed)
- [ ] Optimize protocol (sub-millisecond latency)

**Estimated**: 3-4 days

#### 4.2: Complete LSP Implementation

**Files**: `src/aurora_lsp.zig`

**Tasks**:
- [ ] JSON-RPC 2.0 serialization/deserialization
- [ ] Snapshot model (incremental updates)
- [ ] Cancellation support
- [ ] Zig-specific features (comptime analysis)

**Estimated**: 4-5 days

#### 4.3: GrainBank Integration

**Files**: `src/dream_browser.zig`, `src/grainbank_client.zig`

**Tasks**:
- [ ] Micropayments in browser
- [ ] Deterministic contracts
- [ ] Peer-to-peer payments
- [ ] State machine execution

**Dependencies**: Existing GrainBank client

**Estimated**: 3-4 days

**Total Phase 4**: ~2 weeks

---

## Parallel Work Streams

### Stream A: Editor-Focused (Can work in parallel with Stream B)

**Week 1-2**: Phase 0.1, 0.2 (GrainBuffer, GLM-4.6)
**Week 3-4**: Phase 1 (Editor core)
**Week 5-6**: Phase 3.4 (Tree-sitter)
**Week 7-8**: Phase 4.2 (Complete LSP)

### Stream B: Browser-Focused (Can work in parallel with Stream A)

**Week 1-2**: Phase 0.3 (Dream Protocol)
**Week 3-5**: Phase 2 (Browser core)
**Week 6-7**: Phase 3.3 (VCS integration)
**Week 8-9**: Phase 4.3 (GrainBank integration)

### Stream C: Integration (Requires both A and B)

**Week 6-8**: Phase 3.1, 3.2 (Unified UI, Live Preview)
**Week 9-10**: Phase 4.1 (Performance optimization)

## Dependency Graph

```
Phase 0 (Foundation)
├── 0.1: GrainBuffer Enhancement
│   └── Used by: Editor (1.1), Browser (2.2)
├── 0.2: GLM-4.6 Client
│   └── Used by: Editor (1.3), Browser (future)
└── 0.3: Dream Protocol
    └── Used by: Browser (2.3), Editor (future collaboration)

Phase 1 (Editor Core)
├── 1.1: Readonly Spans (depends on 0.1)
├── 1.2: Method Folding
└── 1.3: GLM-4.6 Integration (depends on 0.2)

Phase 2 (Browser Core)
├── 2.1: HTML/CSS Parser
├── 2.2: Rendering Engine (depends on 0.1, 2.1)
└── 2.3: Nostr Content Loading (depends on 0.3)

Phase 3 (Integration)
├── 3.1: Unified UI (depends on Phase 1, Phase 2)
├── 3.2: Live Preview (depends on 3.1)
├── 3.3: VCS Integration
└── 3.4: Tree-sitter Integration

Phase 4 (Polish)
├── 4.1: Performance Optimization (depends on Phase 3)
├── 4.2: Complete LSP
└── 4.3: GrainBank Integration
```

## File Structure

```
src/
├── grain_buffer.zig          # ✅ Exists, needs enhancement
├── grain_aurora.zig          # ✅ Exists, needs multi-pane
├── aurora_editor.zig         # ✅ Exists, needs enhancement
├── aurora_lsp.zig            # ✅ Exists, needs completion
├── aurora_text_renderer.zig  # ✅ Exists
│
├── aurora_glm46.zig          # 🔄 Started, needs HTTP
├── aurora_folding.zig        # 📋 To create
├── aurora_tree_sitter.zig    # 📋 To create
├── aurora_vcs.zig            # 📋 To create
├── aurora_vfs.zig            # 📋 To create
├── aurora_layout.zig         # 📋 To create
│
├── dream_protocol.zig        # 📋 To create
├── dream_nostr.zig           # 📋 To create
├── dream_websocket.zig       # 📋 To create
├── dream_browser.zig         # 📋 To create
├── dream_browser_parser.zig  # 📋 To create
├── dream_browser_renderer.zig # 📋 To create
│
└── dream_ide.zig             # 📋 To create (unified entry point)
```

## GrainStyle Requirements

### Explicit Limits (All Components)

- GrainBuffer: Max 1000 readonly segments
- GLM-4.6: Max 200K token context, 8KB message size
- Dream Protocol: Max 100 relays, 1MB message size
- HTML Parser: Max tree depth 100, max 10,000 nodes
- Folding: Max 1000 foldable regions
- VFS: Max 1000 files
- Layout: Max 100 panes per workspace

### Assertions (All Components)

- Verify readonly spans don't overlap
- Verify API responses are valid
- Verify protocol events are valid
- Verify parse trees are valid
- Verify fold boundaries are valid
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

### Phase 0 Complete When

- GrainBuffer supports 1000 readonly segments
- GLM-4.6 client connects to Cerebras (1,000 tps)
- Dream Protocol connects to Nostr relays (<1ms latency)
- All tests pass

### Phase 1 Complete When

- Editor has readonly spans (visual distinction)
- Method folding works (bodies fold by default)
- GLM-4.6 provides code completion (1,000 tps)
- All tests pass

### Phase 2 Complete When

- Browser parses HTML/CSS (subset)
- Browser renders to Grain Aurora (readonly spans)
- Browser loads Nostr content (real-time)
- All tests pass

### Phase 3 Complete When

- Unified UI works (editor + browser)
- Live preview works (real-time sync)
- VCS integration works (Magit-style)
- Tree-sitter works (syntax highlighting)
- All tests pass

### Phase 4 Complete When

- Performance targets met (60fps, <1ms latency)
- LSP complete (JSON-RPC, snapshot model)
- GrainBank integration works (micropayments)
- All tests pass

## Timeline Summary

| Phase | Duration | Parallel Work | Dependencies |
|-------|----------|---------------|--------------|
| **Phase 0** | 2 weeks | A: GrainBuffer, GLM-4.6<br>B: Dream Protocol | None |
| **Phase 1** | 2 weeks | Editor core | Phase 0.1, 0.2 |
| **Phase 2** | 2-3 weeks | Browser core | Phase 0.1, 0.3 |
| **Phase 3** | 3 weeks | Integration | Phase 1, Phase 2 |
| **Phase 4** | 2 weeks | Polish | Phase 3 |
| **Total** | **11-12 weeks** | | |

## Next Immediate Steps

1. **Start Phase 0.1**: Enhance GrainBuffer (2-3 days)
   - Increase max_segments to 1000
   - Add visual rendering support
   - Add span query functions

2. **Start Phase 0.2**: Complete GLM-4.6 client (3-4 days)
   - Implement HTTP client
   - JSON serialization
   - SSE streaming parser

3. **Start Phase 0.3**: Dream Protocol foundation (5-7 days)
   - Nostr event structure
   - WebSocket client
   - State machine

**These can all be done in parallel by different agents or sequentially.**

## Coordination Notes

- **No conflicts with VM/kernel work**: Different files, different purpose
- **Shared components**: GrainBuffer, GrainAurora (coordinate enhancements)
- **Independent streams**: Editor and Browser can develop in parallel
- **Integration point**: Phase 3 requires both streams complete

---

**This roadmap provides a clear path to implement both Dream Editor and Dream Browser together, leveraging shared components and parallel development.**

*now == next + 1*

