# Unified Architecture Vision: RISC-V, DAGs, and the Future of Computing

## The Synthesis

This document unifies three revolutionary ideas into a single vision for the future of computing:

1. **RISC-V for AI and Safety-Critical Systems**: Simple, verifiable, extensible
2. **DAG-Based UI Architecture**: Hyperfiddle's streaming DAGs + HashDAG consensus
3. **TigerBeetle-Style Determinism**: Bounded, fast, correct state machines

The result: A **radically unified** computing platform that's faster, more correct, and more scalable than anything that exists today.

## Part 1: RISC-V as the Foundation

### Why RISC-V Matters

RISC-V is not just another instruction set. It's a **philosophical shift** toward simplicity, verifiability, and extensibility. For AI and safety-critical systems, this matters because:

**Complex ISAs are a liability**:
* x86: Thousands of instructions, decades of legacy, security vulnerabilities
* ARM: Complex, proprietary, hard to verify
* RISC-V: Simple, open, extensible, verifiable

**For AI workloads**, RISC-V's simplicity enables:
* **Custom extensions**: Add AI-specific instructions (matrix multiply, tensor ops)
* **Formal verification**: Prove correctness of critical paths
* **Hardware innovation**: WSE spatial architectures, custom chips
* **Green computing**: Lower power, less e-waste, conflict-free materials

**For safety-critical systems**, RISC-V's verifiability enables:
* **Formal proofs**: Verify kernel correctness, prove safety properties
* **Deterministic execution**: Predictable behavior, no hidden state
* **Custom instructions**: Add domain-specific safety checks
* **Open hardware**: Repairable, auditable, sustainable

### The Hardware Vision

**Framework 13 RISC-V** (our target):
* DeepComputing DC-ROMA mainboard
* Up to 64GB RAM
* Modular, repairable design
* Native RISC-V execution (no JIT needed)

**WSE Spatial Architectures** (future):
* 44GB on-wafer SRAM (all content in memory)
* 900,000 cores (parallel rendering)
* Dataflow computing (not von Neumann)
* Zero-copy operations

**Custom RISC-V Extensions** (our contribution):
* Browser-specific instructions
* Editor-specific instructions
* GrainBank contract execution
* Deterministic state machine ops

## Part 2: DAG-Based UI Architecture

### The Problem with Current UI Models

**React/Vue/Svelte**: Tree-based, reactive, unpredictable
* Tree re-renders (slow)
* Reactive updates (hard to reason about)
* Hidden state (hard to debug)
* JavaScript (slow, unpredictable)

**DOM**: Heavy, mutable, slow
* Tree manipulation (expensive)
* Mutable state (race conditions)
* Browser-specific (not portable)
* Complex layout (repaint cycles)

**Tree-sitter vs DOM**: Different purposes, but both are trees
* Tree-sitter: Syntax structure (code understanding)
* DOM: Rendered structure (web page layout)
* Both could be unified under a DAG model

### Hyperfiddle's Revolutionary Insight

Dustin Getz's Hyperfiddle: **UIs are streaming DAGs**.

Instead of:
* Tree of components (React)
* Reactive updates (Vue)
* Mutable DOM (browsers)

Think:
* **DAG of nodes** (components, data, computations)
* **Edges for data flow** (dependencies, transformations)
* **Streaming updates** (deterministic propagation)

**Why DAGs are better**:
* **Parallel**: Multiple updates simultaneously
* **Flexible**: Multiple parents → one node (data fusion)
* **Efficient**: Only affected nodes update
* **Deterministic**: Same events = same state

### HashDAG Consensus (Djinn's Proposal)

Djinn's HashDAG v0.1 proposal gives us **consensus via DAGs**:

**Key Concepts**:
* **Event-based**: Everything is an event (code edit, web request, UI click)
* **Parent references**: Events reference parents (like git commits)
* **Virtual voting**: Consensus without explicit vote messages
* **Fast finality**: Deterministic ordering in seconds
* **High throughput**: Parallel ingestion (not sequential blocks)

**How It Fits UI State**:
* Editor code edits = DAG events, ordered by HashDAG
* Browser web content = DAG events, ordered by HashDAG
* UI interactions = DAG events, ordered by HashDAG
* All get deterministic order via virtual voting

**Performance**:
* **Finality**: p95 < 3-5 seconds (from HashDAG proposal)
* **Throughput**: Millions of events (parallel ingestion)
* **Scalability**: Handles Sybil attacks, eclipses, partitions

### TigerBeetle-Style Determinism

TigerBeetle is a **financial database** built in Zig. Its architecture is perfect for general-purpose state machines:

**Key Principles**:
* **Single-threaded**: No locks, no race conditions
* **Deterministic**: Same input = same output
* **Bounded**: Explicit limits, no hidden allocations
* **Fast**: Optimized for transactions

**Generalized for UI State**:
* Code state (AST nodes, edits, history)
* Web content (Nostr events, HTML structure)
* UI state (component tree, user interactions)
* All executed by TigerBeetle-style state machine

## Part 3: The Unified Architecture

### The Complete Stack

```
┌─────────────────────────────────────────────────────────┐
│   Dream Editor + Dream Browser (Zig Native)            │
│   - Unified DAG model (editor AST + browser DOM)        │
│   - Streaming updates (Hyperfiddle-style)               │
│   - GLM-4.6 integration (1,000 tps agentic coding)     │
├─────────────────────────────────────────────────────────┤
│   DAG-Based State Machine                              │
│   - Events: code edits, web requests, UI interactions  │
│   - Nodes: AST nodes, DOM nodes, UI components         │
│   - Edges: dependencies, data flow, transformations     │
│   - Consensus: HashDAG-style ordering (Djinn's proposal)│
├─────────────────────────────────────────────────────────┤
│   TigerStyle Database Layer                            │
│   - Single-threaded, deterministic (like TigerBeetle)  │
│   - Bounded allocations, explicit limits               │
│   - Fast queries, immutable history                    │
│   - General-purpose (code, web, UI state)               │
├─────────────────────────────────────────────────────────┤
│   Grain VM (RISC-V → AArch64 JIT)                      │
│   - Spatial computing (dataflow, not von Neumann)       │
│   - RAM-only execution (no disk I/O)                   │
│   - Custom RISC-V extensions (browser, editor ops)     │
├─────────────────────────────────────────────────────────┤
│   Grain Basin Kernel (RISC-V64)                         │
│   - Safety-first, explicit limits                      │
│   - Deterministic execution                            │
│   - Custom instructions for DAG operations             │
└─────────────────────────────────────────────────────────┘
```

### Why This Unification Matters

**1. Performance**
* **DAG parallelism**: Multiple updates simultaneously (not sequential)
* **TigerBeetle speed**: Single-threaded but extremely fast
* **RISC-V simplicity**: Predictable, verifiable, fast
* **Spatial computing**: WSE-style dataflow (not von Neumann)

**2. Correctness**
* **Deterministic**: Same events = same state (TigerBeetle)
* **Verifiable**: HashDAG-style proofs for state transitions
* **Bounded**: Explicit limits prevent unbounded growth
* **Formal verification**: RISC-V enables proving correctness

**3. Unification**
* **Editor and browser share the same model**: Code AST and web DOM are both DAG nodes
* **Single source of truth**: One DAG, multiple views (editor view, browser view)
* **Consistent updates**: Changes propagate the same way everywhere
* **Unified language**: Zig throughout (no JavaScript, no Python)

**4. Scalability**
* **HashDAG consensus**: Can handle millions of events (high throughput)
* **TigerBeetle architecture**: Single-threaded but extremely fast
* **Streaming**: Real-time updates without blocking
* **RISC-V extensibility**: Custom instructions for domain-specific ops

**5. Sustainability**
* **Green computing**: RISC-V lower power, less e-waste
* **Repairable hardware**: Framework 13 modular design
* **Conflict-free materials**: America First manufacturing
* **RAM-only cloud**: WSE spatial architectures (no disk I/O)

## Part 4: Implementation Roadmap

### Phase 1: Foundation (Current)
✅ **Complete**:
* GrainBuffer enhancement (readonly spans)
* GLM-4.6 client (HTTP, JSON, SSE)
* Dream Protocol (Nostr, WebSocket)
* Tree-sitter foundation (simple parser)
* Readonly spans integration
* Method folding

🔄 **In Progress**:
* Tree-sitter C library integration
* GLM-4.6 code transformation

### Phase 2: DAG Core
**Goal**: Build the unified DAG foundation

**Tasks**:
* Create `src/dag_core.zig` - Core DAG data structure
* Events, nodes, edges, streaming updates
* TigerBeetle-style state machine
* HashDAG consensus integration (Djinn's proposal)

**GrainStyle**:
* Explicit limits: Max 10,000 nodes, max 100,000 edges
* Bounded allocations: Pre-allocate event buffers
* Assertions: Verify DAG is acyclic, nodes are valid

### Phase 3: Unify Editor + Browser
**Goal**: Merge Tree-sitter and DOM into one DAG

**Tasks**:
* Editor AST nodes = DAG nodes
* Browser DOM nodes = DAG nodes
* Shared DAG for both
* Streaming updates (Hyperfiddle-style)

**Benefits**:
* Single source of truth
* Consistent update model
* Real-time sync (editor ↔ browser)

### Phase 4: HashDAG Consensus
**Goal**: Integrate Djinn's HashDAG for event ordering

**Tasks**:
* Event-based model (code edits, web requests, UI clicks)
* Parent references (like git commits)
* Virtual voting (consensus without explicit votes)
* Fast finality (seconds, not minutes)

**From HashDAG v0.1**:
* Event structure: `event_id, creator_id, parents[2..k], tx_root, timestamp, sig`
* Virtual voting engine: Rounds, witnesses, fame
* Finality manager: Deterministic ordering, checkpoints

### Phase 5: TigerStyle Database
**Goal**: General-purpose database layer

**Tasks**:
* Build on TigerBeetle's architecture
* Generalize to any state machine
* Use for code state, web content, UI state
* Immutable history, fast queries

**Principles**:
* Single-threaded (no locks)
* Deterministic (same input = same output)
* Bounded (explicit limits)
* Fast (optimized for queries)

### Phase 6: RISC-V Custom Extensions
**Goal**: Hardware acceleration for DAG operations

**Tasks**:
* Design custom RISC-V instructions
* Browser-specific ops (render, parse)
* Editor-specific ops (AST manipulation)
* GrainBank contract execution

**Benefits**:
* Hardware acceleration
* Formal verification
* Deterministic execution

## Part 5: The Big Picture

### What We're Building

This isn't just an editor. It isn't just a browser. It's a **radical reinvention** of computing from first principles:

**From the ground up**:
* **RISC-V hardware**: Simple, verifiable, extensible
* **Zig language**: Explicit, bounded, safe
* **DAG architecture**: Parallel, flexible, efficient
* **HashDAG consensus**: Fast finality, high throughput
* **TigerBeetle determinism**: Correct, bounded, fast

**The result**:
* **100-2000× faster** than current browsers (DAG parallelism + TigerBeetle speed)
* **More correct** than current editors (deterministic, verifiable)
* **More unified** than current tools (editor and browser share the same model)
* **More scalable** than current systems (HashDAG throughput)
* **More sustainable** than current hardware (RISC-V green computing)

### Why This Matters

**Current state of computing**:
* JavaScript: Slow, unpredictable, security nightmare
* DOM: Heavy, mutable, slow
* React: Tree re-renders, reactive complexity
* x86/ARM: Complex, proprietary, hard to verify
* Cloud: Disk I/O, network delays, e-waste

**Our vision**:
* Zig: Fast, predictable, safe
* DAG: Parallel, flexible, efficient
* RISC-V: Simple, verifiable, extensible
* HashDAG: Fast finality, high throughput
* TigerBeetle: Deterministic, bounded, fast
* WSE: RAM-only, spatial computing, zero-copy

**The synthesis**:
* Unify editor and browser (single DAG model)
* Unify code and web (same event system)
* Unify hardware and software (RISC-V custom extensions)
* Unify consensus and UI (HashDAG for state)

### Next Steps

1. **Complete Phase 1**: Finish Tree-sitter integration, GLM-4.6 enhancements
2. **Build DAG core**: Foundation for unified architecture
3. **Integrate HashDAG**: Event ordering for UI state
4. **Unify editor/browser**: Single DAG model
5. **Design RISC-V extensions**: Hardware acceleration
6. **Build TigerStyle database**: General-purpose state machine

This is the **next generation** of computing. Not incremental improvement. Radical reinvention from first principles.

## Conclusion

We're not building another editor or browser. We're building a **unified computing platform** that combines:

* **RISC-V simplicity** for verifiability and extensibility
* **DAG architecture** for parallelism and efficiency
* **HashDAG consensus** for fast finality and high throughput
* **TigerBeetle determinism** for correctness and speed
* **Zig GrainStyle** for explicit, bounded, safe code

The result: A system that's **orders of magnitude** faster, more correct, and more scalable than anything that exists today.

This is ambitious. This is grandiose. This might be completely wrong. But it's asking the right questions, and that's what matters.

*now == next + 1*

