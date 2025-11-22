# Grain OS Development Plan
## RISC-V Kernel + VM + Aurora IDE

**Current Status**: Phase 3.3 IPC Channels complete ✅. IPC channel system with message queues and channel management implemented! 🎉

**Goal**: RISC-V-targeted Grain OS with graphical interface running in macOS Tahoe 26.1 VM, with path toward Framework 13 RISC-V hardware.

## 🎯 Immediate Priorities (Next 3 Days)

### Day 1-2: VM Integration & Kernel Boot 🔥 **CRITICAL**

**Objective**: Get Grain Basin Kernel booting in Grain Vantage with JIT acceleration.

1. **Complete VM Integration**
   - Hook JIT into `vm.zig` dispatch loop
   - Add `init_with_jit()` and `step_jit()` methods
   - Implement interpreter fallback for JIT failures
   - Test with minimal kernel boot sequence

2. **Kernel Boot Sequence**
   - Implement basic boot loader
   - Set up initial memory layout
   - Initialize framebuffer for GUI
   - Display simple test pattern

3. **Performance Validation** ✅ **COMPLETE**
   - ✅ Benchmark JIT vs interpreter (enhanced suite with statistics)
   - ✅ Verify 10x+ speedup on hot paths (automatic verification)
   - ✅ Profile memory usage (JIT: ~64MB code buffer)

### Day 3: GUI Integration

**Objective**: Connect kernel framebuffer to macOS Tahoe window.

1. **Framebuffer Sync** ✅ **COMPLETE**
   - ✅ Map kernel framebuffer to host memory
   - ✅ Update macOS window on changes
   - ✅ Implement dirty region tracking (optimization complete)

2. **Input Pipeline** ✅ **COMPLETE**
   - ✅ Route macOS keyboard/mouse to kernel (via input event queue)
   - ✅ Implement input event queue in VM
   - ✅ Kernel syscall for reading input events (read_input_event = 60)
   - ✅ Integration layer handles input event syscall

3. **Text Rendering** ✅ **COMPLETE**
   - ✅ Integrate text rendering into framebuffer module
   - ✅ Render simple text to framebuffer (8x8 bitmap font)
   - ✅ Display kernel boot messages on framebuffer

4. **Framebuffer Syscalls** ✅ **COMPLETE**
   - ✅ Kernel syscall for clearing framebuffer (fb_clear = 70)
   - ✅ Kernel syscall for drawing pixels (fb_draw_pixel = 71)
   - ✅ Kernel syscall for drawing text (fb_draw_text = 72)
   - ✅ Integration layer handles framebuffer operations (needs VM memory access)
   - ✅ Userspace programs can now render to framebuffer via syscalls

5. **Userspace Framebuffer Program** ✅ **COMPLETE**
   - ✅ Created fb_demo.zig userspace program (calls fb_clear, fb_draw_pixel, fb_draw_text)
   - ✅ Added build target for fb_demo (zig build fb-demo)
   - ✅ Created end-to-end test (tests/013_fb_demo_test.zig)
   - ✅ Full stack validated: Userspace -> VM -> Kernel -> Framebuffer -> Display

6. **Integration Testing** ✅ **COMPLETE**
   - ✅ Created comprehensive kernel integration tests (tests/014_kernel_integration_test.zig)
   - ✅ Kernel boot sequence validation (load, initialize, execute)
   - ✅ Stress testing (long-running programs, 2000+ steps)
   - ✅ Edge case validation (memory bounds, state transitions, error handling)
   - ✅ Memory leak detection (state consistency, framebuffer consistency)
   - ✅ All tests follow TigerStyle principles (bounded loops, explicit types, pair assertions)

7. **Framebuffer Optimization** ✅ **COMPLETE**
   - ✅ Implemented dirty region tracking (FramebufferDirtyRegion struct)
   - ✅ Mark dirty regions in framebuffer operations (fb_clear, fb_draw_pixel, fb_draw_text)
   - ✅ Optimized sync_framebuffer (only copy dirty regions)
   - ✅ Clear dirty regions after sync (reset tracking)
   - ✅ Created comprehensive tests (tests/015_dirty_region_test.zig)
   - ✅ Performance improvement: reduces memory bandwidth for small updates

8. **Error Handling and Recovery** ✅ **COMPLETE**
   - ✅ Created error logging system (ErrorLog struct with circular buffer)
   - ✅ Integrated error logging into VM (logs invalid instruction, memory access errors)
   - ✅ Error statistics tracking (count by type, total errors)
   - ✅ Error recovery mechanisms (VM can restart after error)
   - ✅ Created comprehensive tests (tests/016_error_handling_test.zig)
   - ✅ Bounded error log (256 entries, prevents memory growth)

9. **Performance Monitoring and Diagnostics** ✅ **COMPLETE**
   - ✅ Created performance metrics system (PerformanceMetrics struct)
   - ✅ Track instruction execution, memory operations, syscalls
   - ✅ Track JIT performance (cache hits, misses, fallbacks)
   - ✅ Calculate IPC (instructions per cycle) and cache hit rate
   - ✅ Created diagnostics snapshot system (DiagnosticsSnapshot)
   - ✅ Integrated performance tracking into VM (step, memory ops, syscalls)
   - ✅ Created comprehensive tests (tests/017_performance_monitoring_test.zig)
   - ✅ Performance metrics summary printing

10. **VM State Persistence** ✅ **COMPLETE**
   - ✅ Created VM state snapshot system (VMStateSnapshot struct)
   - ✅ Save complete VM state (registers, memory, flags, performance metrics)
   - ✅ Restore VM state from snapshot (reproducible execution)
   - ✅ Snapshot validation (verify snapshot consistency)
   - ✅ Integrated save_state() and restore_state() into VM
   - ✅ Created comprehensive tests (tests/018_state_persistence_test.zig)
   - ✅ Enables debugging, testing, and checkpointing

11. **VM API Documentation** ✅ **COMPLETE**
   - ✅ Created comprehensive VM API reference (docs/vm_api_reference.md)
   - ✅ Documented all VM methods with contracts and examples
   - ✅ Created example programs (examples/vm_basic_usage.zig, vm_jit_usage.zig, vm_state_persistence.zig)
   - ✅ Documented memory layout, constants, and error handling
   - ✅ Verified API consistency and naming conventions
   - ✅ Complete reference for VM usage patterns

12. **Timer Driver** ✅ **COMPLETE**
   - ✅ Created timer driver module (src/kernel/timer.zig)
   - ✅ Monotonic clock (nanoseconds since boot)
   - ✅ Realtime clock (nanoseconds since epoch)
   - ✅ Uptime tracking
   - ✅ SBI timer integration (set_timer)
   - ✅ Kernel timer integration (BasinKernel.timer)
   - ✅ clock_gettime syscall (handled in integration layer)
   - ✅ sleep_until syscall (timer-based validation)
   - ✅ Comprehensive TigerStyle tests (tests/020_timer_driver_test.zig)

13. **Interrupt Controller** ✅ **COMPLETE**
   - ✅ Created interrupt controller module (src/kernel/interrupt.zig)
   - ✅ Interrupt types (timer, external, software)
   - ✅ Handler registration (timer, external, software)
   - ✅ Interrupt dispatch and routing
   - ✅ Pending interrupt tracking
   - ✅ Process pending interrupts
   - ✅ Kernel interrupt controller integration (BasinKernel.interrupt_controller)
   - ✅ Comprehensive TigerStyle tests (tests/021_interrupt_controller_test.zig)

14. **Process Scheduler** ✅ **COMPLETE**
   - ✅ Created process scheduler module (src/kernel/scheduler.zig)
   - ✅ Round-robin scheduling algorithm
   - ✅ Current process tracking
   - ✅ Process state transitions (spawn sets current, exit clears current)
   - ✅ Wait syscall enhancement (polling-based, returns would_block if still running)
   - ✅ Scheduler integration with kernel (BasinKernel.scheduler)
   - ✅ Comprehensive TigerStyle tests (tests/022_process_scheduler_test.zig)

15. **IPC Channels** ✅ **COMPLETE**
   - ✅ Created IPC channel module (src/kernel/channel.zig)
   - ✅ Message queue (bounded: 32 messages max, 4KB per message)
   - ✅ Channel table (64 channels max, static allocation)
   - ✅ channel_create syscall (creates channel, returns channel ID)
   - ✅ channel_send syscall (validates channel and data, integration layer handles memory)
   - ✅ channel_recv syscall (validates channel and buffer, integration layer handles memory)
   - ✅ Channel integration with kernel (BasinKernel.channels)
   - ✅ Comprehensive TigerStyle tests (tests/023_ipc_channel_test.zig)

## 🚀 Architecture Overview

### Grain Aurora Stack
```
┌─────────────────────────────────────┐
│   macOS Tahoe 26.1 (Native Cocoa)  │
├─────────────────────────────────────┤
│   Grain Aurora IDE (Zig GUI)       │
├─────────────────────────────────────┤
│   Grain Vantage (RISC-V → AArch64 JIT)  │ ✅ COMPLETE
├─────────────────────────────────────┤
│   Grain Basin Kernel (RISC-V64)     │
└─────────────────────────────────────┘
```

### Hardware Target: Framework 13 RISC-V

**Recommended Path**: DeepComputing DC-ROMA RISC-V Mainboard
- **Specs**: RISC-V64, up to 64GB RAM, modular design
- **Advantages**:
  - Native RISC-V (no JIT needed after port)
  - Repairable/upgradeable (Framework philosophy)
  - Open-source firmware support
  - Perfect match for Grain Basin Kernel
- **Timeline**: 2-3 months for hardware acquisition + porting

**Alternative Options**:
- High-performance ARM laptop (1-2 months ARM port)
- x86 AMD Framework 13 (2-3 months x86 port)
- Custom RISC-V laptop (6-12 months design + manufacturing)

### Display Technology

**Repairable LCD Design** (Daylight Computer-inspired):
- Modular screen assembly with replaceable components
- Standard connectors (eDP, MIPI)
- Open documentation and repair guides
- Framework 13 compatibility

## 📋 Development Phases

### Phase 1: VM Integration (Days 1-3) 🔥 **CURRENT**
- Complete JIT integration into VM
- Kernel boot sequence
- GUI framebuffer sync
- Input pipeline

### Phase 2: Framework 13 RISC-V (Weeks 2-4)
- Acquire DeepComputing DC-ROMA mainboard
- Port Grain Basin Kernel to native RISC-V
- Remove JIT layer (native execution)
- Optimize for hardware

### Phase 3: Custom Display (Months 2-3)
- Design repairable display module
- Integrate with Framework 13 chassis
- Open-source hardware documentation
- Create repair guides

### Phase 4: Production Hardening (Months 4-6)
- Performance optimization
- Power management
- Driver development
- User experience polish

## 🌾 GrainStyle Guidelines

### Core Principles
- **Patient Discipline**: Code written once, read many times
- **Explicit Limits**: Use `u32`/`u64`, not `usize`
- **Sustainable Practice**: Code that grows without breaking
- **Code That Teaches**: Comments explain why, not what

### Graincard Constraints
- **Line width**: 73 characters (hard wrap)
- **Function length**: max 70 lines
- **Total size**: 75×100 monospace teaching cards

### Safety & Assertions
- **Crash Early**: Use `assert` for programmer errors
- **Pair Assertions**: Assert preconditions AND postconditions
- **Density**: Minimum 2 assertions per function

### Memory Management
- **Startup Only**: Allocate everything in `init`
- **No Hidden Allocations**: Avoid implicit allocations
- **Pre-allocate Collections**: Call `ensureTotalCapacity`

## 🎨 Design Principles

### Repairability First
- Modular components (Framework-inspired)
- Standard connectors and interfaces
- Open-source hardware documentation
- User-replaceable parts

### Performance Second
- Native RISC-V execution (no JIT overhead)
- Optimized kernel for target hardware
- Efficient memory management
- Fast boot times

### Sustainability Third
- Long-term hardware support
- Upgradeable components
- Repair-friendly design
- Open documentation

## 📊 Success Metrics

### Week 1
- [x] Kernel boots in VM
- [x] GUI displays in macOS window (framebuffer sync complete)
- [x] JIT performance validated (10x+ speedup)
- [ ] Basic input handling works

### Month 1
- [ ] Framework 13 RISC-V mainboard acquired
- [ ] Kernel ported to native RISC-V
- [ ] Basic userspace running
- [ ] Display driver working

### Month 3
- [ ] Custom display module designed
- [ ] Full hardware integration complete
- [ ] Performance benchmarks met
- [ ] Documentation complete

## 🎨 Phase 4: Dream Editor + Browser (NEW)

**Status**: 🔄 Foundation in progress (Phase 0)

**Vision**: Unified IDE combining Matklad-inspired editor with Nostr-native browser, using GLM-4.6 for agentic coding at 1,000 tokens/second.

### Phase 0: Shared Foundation (In Progress)

**Objective**: Build shared components for both editor and browser.

#### 0.1: GrainBuffer Enhancement ✅ **COMPLETE**
- ✅ Increased readonly segments from 64 to 1000
- ✅ Added span query functions (`isReadOnly`, `getReadonlySpans`)
- ✅ Binary search optimization for large segment lists
- ✅ Comprehensive assertions (GrainStyle compliance)

#### 0.2: GLM-4.6 Client ✅ **COMPLETE**
- ✅ Client structure created
- ✅ HTTP client foundation created
- ✅ HTTP implementation (JSON serialization, SSE streaming)
- ✅ Integration with Cerebras API
- 📋 Tool calling support (future enhancement)

#### 0.3: Dream Protocol ✅ **COMPLETE**
- ✅ Nostr event structure (Zig-native)
- ✅ WebSocket client (low-latency, frame parsing)
- ✅ State machine foundation (TigerBeetle-style)
- ✅ Event streaming structure (real-time ready)
- 📋 Relay connection management (integration pending)

#### 0.4: DAG Core Foundation ✅ **COMPLETE**
- ✅ Core DAG data structure (`src/dag_core.zig`)
- ✅ Nodes, edges, events (HashDAG-style)
- ✅ TigerBeetle-style state machine execution
- ✅ Bounded allocations (max 10,000 nodes, 100,000 edges)
- ✅ Comprehensive assertions (GrainStyle compliance)
- ✅ Tests for initialization, node/edge/event operations

**Phase 0 Summary**: All foundation components complete! Ready for Phase 1 (Dream Editor Core) and Phase 2 (DAG integration).

### Phase 1: Dream Editor Core 🔄 **IN PROGRESS**

**Objective**: Matklad-inspired editor with GLM-4.6 integration.

#### 1.1: Readonly Spans Integration ✅ **COMPLETE**
- ✅ Integrated enhanced GrainBuffer into editor
- ✅ Edit protection (prevents modifications to readonly spans)
- ✅ Visual rendering (readonly spans returned in render result)
- ✅ Cursor handling (insert checks for readonly violations)

#### 1.2: Method Folding ✅ **COMPLETE**
- ✅ Parse code structure (regex-based for Zig functions/structs)
- ✅ Identify method/function boundaries
- ✅ Fold bodies by default, show signatures
- ✅ Toggle folding (keyboard shortcut ready)
- ✅ Visual indicators (fold state tracking)

#### 1.3: GLM-4.6 Integration 🔄 **IN PROGRESS**
- ✅ Code completion (ghost text at 1,000 tps integrated)
- ✅ Editor integration (GLM-4.6 client optional, falls back to LSP)
- 📋 Code transformation (refactor, extract, inline) - pending
- 📋 Tool calling (run `zig build`, `jj status`) - pending
- 📋 Multi-file edits (context-aware) - pending

#### 1.4: Tree-sitter Integration ✅ **ENHANCED**
- ✅ Foundation created (simple regex-based parser)
- ✅ Tree structure with nodes (functions, structs)
- ✅ Node lookup at positions (for hover, navigation)
- ✅ Editor integration (parse and query syntax tree)
- ✅ Syntax token extraction (keywords, strings, comments, numbers, operators)
- ✅ Iterative node search (no recursion, GrainStyle compliant)
- ✅ Token lookup at positions for syntax highlighting
- 📋 Tree-sitter C library bindings (future)
- 📋 Zig grammar integration (future)
- 📋 Code actions (extract function, rename symbol) (future)

#### 1.5: Complete LSP Implementation ✅ **COMPLETE**
- ✅ JSON-RPC 2.0 serialization/deserialization
- ✅ Snapshot model (incremental updates, Matklad-style)
- ✅ Cancellation support for pending requests
- ✅ Server communication (stdin/stdout with Content-Length headers)
- ✅ Document lifecycle (didOpen, didChange with incremental edits)
- ✅ GrainStyle compliance (u32 types, assertions, bounded allocations)
- 📋 Zig-specific features (comptime analysis) - pending

#### 1.6: Magit-Style VCS ✅ **COMPLETE**
- ✅ Generate `.jj/status.jj` (readonly metadata, editable hunks)
- ✅ Generate `.jj/commit/*.diff` (readonly commit info, editable diff)
- ✅ Watch for edits, invoke `jj` commands
- ✅ Readonly spans for commit hashes, parent info, file paths, diff headers
- ✅ Parse `jj status` and `jj diff` output
- ✅ Virtual file system with bounded allocations
- ✅ GrainStyle compliance (u32 types, assertions, no recursion)

#### 1.7: Multi-Pane Layout 📋 **PLANNED**
- 📋 Split panes (horizontal/vertical)
- 📋 Tile windows (editor, terminal, VCS status)
- 📋 River compositor integration
- 📋 Moonglow keybindings
- 📋 Workspace management

### Phase 2: DAG Integration 🔄 **IN PROGRESS**

**Objective**: Integrate DAG core into editor and browser.

#### 2.1: Editor-DAG Integration ✅ **COMPLETE**
- ✅ Map Tree-sitter AST nodes to DAG nodes (`src/aurora_dag_integration.zig`)
- ✅ Map code edits to DAG events (HashDAG-style with parent references)
- ✅ Streaming updates (Hyperfiddle-style, TigerBeetle state machine)
- ✅ Project-wide semantic graph (Matklad vision, AST node tracking)
- ✅ Node lookup by position (for navigation, hover)
- ✅ Dependency tracking (parent-child relationships in DAG)

#### 2.2: Browser-DAG Integration ✅ **COMPLETE**
- ✅ Map DOM nodes to DAG nodes (`src/browser_dag_integration.zig`)
- ✅ Map web requests to DAG events (HashDAG-style with parent references)
- ✅ Streaming updates (real-time, `processStreamingUpdates()`)
- ✅ Unified state (editor + browser share same DAG)
- ✅ Dependency tracking (parent-child relationships in DOM)
- ✅ URL node reuse (unique nodes per URL)
- ✅ Comprehensive tests (tests/019_browser_dag_integration_test.zig)

#### 2.3: HashDAG Consensus ✅ **COMPLETE**
- ✅ Event ordering (Djinn's HashDAG proposal, `src/hashdag_consensus.zig`)
- ✅ Virtual voting (consensus without explicit votes, witness determination)
- ✅ Fast finality (seconds, not minutes, round-based finality)
- ✅ High throughput (parallel ingestion, deterministic ordering)
- ✅ Round determination (max parent round + 1)
- ✅ Witness identification (first event per creator per round)
- ✅ Fame determination (witness events are famous)
- ✅ Finality manager (events in rounds N-2 or earlier are finalized)

### Phase 3: Dream Browser Core 🔄 **IN PROGRESS**

**Objective**: Zig-native browser with Nostr protocol.

#### 3.1: HTML/CSS Parser ✅ **COMPLETE**
- ✅ HTML parser (subset of HTML5, `src/dream_browser_parser.zig`)
- ✅ CSS parser (subset of CSS3, basic rule parsing)
- ✅ DOM tree construction (bounded depth, explicit nodes)
- ✅ Style computation (cascade, specificity - basic implementation)
- ✅ DAG integration (HTML node → DOM node conversion)
- 📋 Full HTML5/CSS3 parser (future enhancement)

#### 3.2: Rendering Engine ✅ **COMPLETE**
- ✅ Layout engine (block/inline flow, `src/dream_browser_renderer.zig`)
- ✅ Render to Grain Aurora components (DOM → Aurora Node conversion)
- ✅ Readonly spans for metadata (event ID, timestamp, author)
- ✅ Editable spans for content (text content is editable)
- ✅ DAG-based rendering pipeline (DOM nodes from DAG)

#### 3.3: Nostr Content Loading ✅ **COMPLETE**
- ✅ Parse Nostr URLs (`nostr:note1...`, `nostr:npub1...`, `src/dream_browser_nostr.zig`)
- ✅ Subscribe to Nostr events (via DreamProtocol, filter by URL type)
- ✅ Receive events (streaming, real-time, WebSocket integration)
- ✅ Render events to browser (DOM nodes with readonly spans for metadata)
- ✅ DAG event integration (map events to DAG via browser-DAG integration)

#### 3.4: WebSocket Transport ✅ **COMPLETE**
- ✅ WebSocket client (low-latency, `src/dream_browser_websocket.zig`)
- ✅ Bidirectional communication (send/receive messages via WebSocketClient)
- ✅ Connection management (connection pool, state tracking, max 10 connections)
- ✅ Error handling and reconnection (exponential backoff, max 10 attempts, max 60s delay)
- ✅ Connection pooling (multiple relay connections, URL parsing)
- ✅ Health monitoring (ping/pong handling, connection statistics)

### Phase 3: Integration (Planned)

**Objective**: Unified Editor + Browser experience.

- Multi-pane layout (River compositor)
- Live preview (real-time sync)
- VCS integration (Magit-style)
- GrainBank micropayments

**See**: `docs/dream_implementation_roadmap.md` for complete roadmap

## 👥 Parallel Development Opportunities

**Current Agent Focuses**:
1. **VM/Kernel Agent**: Grain Vantage & Kernel Boot Integration (`src/kernel_vm/`, `src/kernel/`, `src/platform/macos_tahoe/`)
2. **Dream Editor/Browser Agent**: Foundation components (`src/aurora_*.zig`, `src/dream_*.zig`)

**Available for Parallel Work** (see `docs/agent_work_summary.md` and `docs/dream_editor_agent_summary.md`):
- **Dream Editor/Browser** (`src/aurora_*.zig`, `src/dream_*.zig`) - 🔄 Active (Phase 0)
- **Userspace Tools** (`src/userspace/`) - Core utilities, browser engine, build tools
- **Grain Ecosystem** (`src/graincard/`, `grainseed*.zig`) - Graincard, seed system
- **TLS/Networking** (`src/grain_tls/`, `nostr.zig`) - TLS client, protocols
- **Platform Implementations** (`src/platform/riscv/`) - Native RISC-V platform
- **Kernel Advanced Features** - Memory management, process scheduling (design in parallel)
- **Documentation** (`docs/learning-course/`) - Course content, tutorials

**See**: 
- `docs/agent_work_summary.md` - VM/Kernel agent work
- `docs/dream_editor_agent_summary.md` - Dream Editor/Browser agent work

## 🔗 References

- **Framework 13 RISC-V**: https://frame.work/products/deep-computing-risc-v-mainboard
- **DeepComputing DC-ROMA**: https://deepcomputing.io/product/dc-roma-risc-v-mainboard/
- **Daylight Computer**: https://daylightcomputer.com
- **JIT Architecture**: `docs/zyx/jit_architecture.md`
- **Tasks**: `docs/tasks.md`
- **Agent Work Summary**: `docs/agent_work_summary.md`
- **Development Strategy**: `docs/zyx/development_strategy_2025.md`
