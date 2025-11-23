# Grain OS Task List

> "A complete roadmap for Grain OS development, from JIT compiler to production IDE and repairable hardware."

## 🎯 Immediate Priorities (Next 3 Days)

### Day 1-2: VM Integration & Kernel Boot 🔥 **CRITICAL**

#### 2.1 Complete VM Integration
- [ ] Hook JIT into `vm.zig` dispatch loop
- [ ] Add `init_with_jit()` method to VM struct
- [ ] Implement `step_jit()` with interpreter fallback
- [ ] Sync guest state between JIT and VM
- [ ] Test with minimal kernel boot sequence

#### 2.2 Kernel Boot Sequence ✅ **COMPLETE**
- [x] Implement basic boot loader
- [x] Set up initial memory layout
- [x] Initialize framebuffer for GUI (host-side initialization)
- [x] Display simple test pattern

#### 2.3 Performance Validation ✅ **COMPLETE**
- [x] Benchmark JIT vs interpreter (enhanced benchmark suite)
- [x] Verify 10x+ speedup on hot paths (automatic verification in benchmark)
- [x] Profile memory usage (JIT: ~64MB code buffer, documented)
- [x] Measure cache hit rate (tracked in JIT perf counters, printed in stats)

### Day 3: GUI Integration

#### 2.4 Framebuffer Sync ✅ **COMPLETE**
- [x] Map kernel framebuffer to host memory
- [x] Update macOS window on changes
- [x] Optimize copy performance (direct memcpy)
- [x] Implement dirty region tracking (optimization complete)

#### 2.5 Input Pipeline ✅ **COMPLETE**
- [x] Route macOS keyboard events to kernel (via VM input queue)
- [x] Route macOS mouse events to kernel (via VM input queue)
- [x] Implement input event queue in VM (bounded circular buffer)
- [x] Kernel syscall for reading input events (read_input_event = 60)
- [x] Integration layer handles input event syscall (reads from VM queue)
- [x] Event serialization (32-byte structure with mouse/keyboard data)

#### 2.6 Text Rendering ✅ **COMPLETE**
- [x] Integrate text rendering into framebuffer module
- [x] Render simple text to framebuffer (8x8 bitmap font)
- [x] Display kernel boot messages on framebuffer
- [ ] Font loading and rendering (advanced: can use TTF/OTF later)

#### 2.7 Framebuffer Syscalls ✅ **COMPLETE**
- [x] Kernel syscall for clearing framebuffer (fb_clear = 70)
- [x] Kernel syscall for drawing pixels (fb_draw_pixel = 71)
- [x] Kernel syscall for drawing text (fb_draw_text = 72)
- [x] Integration layer handles framebuffer operations (VM memory access)
- [x] Kernel stub handlers (integration layer handles actual implementation)
- [x] Userspace programs can render to framebuffer via syscalls

#### 2.8 Userspace Framebuffer Program ✅ **COMPLETE**
- [x] Created fb_demo.zig userspace program (calls fb_clear, fb_draw_pixel, fb_draw_text)
- [x] Added build target for fb_demo (zig build fb-demo)
- [x] Created end-to-end test (tests/013_fb_demo_test.zig)
- [x] Full stack validated: Userspace -> VM -> Kernel -> Framebuffer -> Display

#### 2.9 Integration Testing ✅ **COMPLETE**
- [x] Created comprehensive kernel integration tests (tests/014_kernel_integration_test.zig)
- [x] Kernel boot sequence validation (load, initialize, execute)
- [x] Stress testing (long-running programs, 2000+ steps)
- [x] Edge case validation (memory bounds, state transitions, error handling)
- [x] Memory leak detection (state consistency, framebuffer consistency)
- [x] All tests follow TigerStyle principles (bounded loops, explicit types, pair assertions)

#### 2.10 Framebuffer Optimization ✅ **COMPLETE**
- [x] Implemented dirty region tracking (FramebufferDirtyRegion struct)
- [x] Mark dirty regions in framebuffer operations (fb_clear, fb_draw_pixel, fb_draw_text)
- [x] Optimized sync_framebuffer (only copy dirty regions)
- [x] Clear dirty regions after sync (reset tracking)
- [x] Created comprehensive tests (tests/015_dirty_region_test.zig)
- [x] Performance improvement: reduces memory bandwidth for small updates

#### 2.11 Error Handling and Recovery ✅ **COMPLETE**
- [x] Created error logging system (ErrorLog struct with circular buffer)
- [x] Integrated error logging into VM (logs invalid instruction, memory access errors)
- [x] Error statistics tracking (count by type, total errors)
- [x] Error recovery mechanisms (VM can restart after error)
- [x] Created comprehensive tests (tests/016_error_handling_test.zig)
- [x] Bounded error log (256 entries, prevents memory growth)

#### 2.12 Performance Monitoring and Diagnostics ✅ **COMPLETE**
- [x] Created performance metrics system (PerformanceMetrics struct)
- [x] Track instruction execution, memory operations, syscalls
- [x] Track JIT performance (cache hits, misses, fallbacks)
- [x] Calculate IPC (instructions per cycle) and cache hit rate
- [x] Created diagnostics snapshot system (DiagnosticsSnapshot)
- [x] Integrated performance tracking into VM (step, memory ops, syscalls)
- [x] Created comprehensive tests (tests/017_performance_monitoring_test.zig)
- [x] Performance metrics summary printing

#### 2.13 VM State Persistence ✅ **COMPLETE**
- [x] Created VM state snapshot system (VMStateSnapshot struct)
- [x] Save complete VM state (registers, memory, flags, performance metrics)
- [x] Restore VM state from snapshot (reproducible execution)
- [x] Snapshot validation (verify snapshot consistency)
- [x] Integrated save_state() and restore_state() into VM
- [x] Created comprehensive tests (tests/018_state_persistence_test.zig)
- [x] Enables debugging, testing, and checkpointing

#### 2.14 VM API Documentation ✅ **COMPLETE**
- [x] Created comprehensive VM API reference (docs/vm_api_reference.md)
- [x] Documented all VM methods with contracts and examples
- [x] Created example programs (examples/vm_basic_usage.zig, vm_jit_usage.zig, vm_state_persistence.zig)
- [x] Documented memory layout, constants, and error handling
- [x] Verified API consistency and naming conventions
- [x] Complete reference for VM usage patterns

## ✅ Phase 1: JIT Compiler (COMPLETE)

### 1.1 Core JIT Implementation
- [x] Instruction decoder (RISC-V → Instruction struct)
- [x] Translation loop (`compile_block`)
- [x] Control flow (Branch/Jump/Return with backpatching)
- [x] Memory management (W^X enforcement, 64MB code buffer)

### 1.2 Instruction Set
- [x] R-Type: ADD, SUB, SLL, SRL, SRA, XOR, OR, AND
- [x] I-Type: ADDI, SLLI, SRLI, SRAI, XORI, ORI, ANDI
- [x] U-Type: LUI, AUIPC
- [x] Load: LB, LH, LW, LBU, LHU, LWU, LD
- [x] Store: SB, SH, SW, SD
- [x] Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
- [x] Jump: JAL, JALR

### 1.3 RVC (Compressed Instructions)
- [x] Quadrant 0: C.ADDI4SPN, C.LW, C.SW
- [x] Quadrant 1: C.ADDI, C.JAL, C.LI, C.LUI, C.ADDI16SP, C.SRLI, C.SRAI, C.ANDI, C.SUB, C.XOR, C.OR, C.AND, C.J, C.BEQZ, C.BNEZ
- [x] Quadrant 2: C.SLLI, C.LWSP, C.JR, C.MV, C.JALR, C.ADD, C.SWSP

### 1.4 Security & Testing
- [x] Pair assertions (20+ functions, 4-5 assertions each)
- [x] Fuzz testing (250+ iterations)
- [x] Security tests (12/12 passing)
- [x] grain_case naming convention

### 1.5 Advanced Features
- [x] Enhanced performance counters
- [x] Soft-TLB (64 entries, 4KB pages)
- [x] Block-local register allocator
- [x] Instruction tracer

## 🔄 Phase 2: VM Integration (IN PROGRESS)

### 2.1 JIT Integration
- [x] Add `init_with_jit()` to VM struct
- [x] Implement `step_jit()` with interpreter fallback
- [x] Sync guest state between JIT and VM
- [x] Add JIT enable/disable flag

### 2.2 Performance ✅ **COMPLETE**
- [x] Create benchmark suite (`benchmark_jit.zig`)
- [x] Run benchmarks and collect metrics (enhanced with multiple runs, statistics)
- [x] Verify 10x+ speedup requirement (benchmark validates automatically)
- [x] Profile memory usage (JIT uses ~64MB code buffer, documented)
- [x] Measure cache hit rate (tracked in JIT perf counters)

### 2.3 Testing ✅ **COMPLETE**
- [x] Integration tests with real kernel code (tests/014_kernel_integration_test.zig)
- [x] Stress testing (long-running programs, 2000+ steps)
- [x] Edge case validation (memory bounds, state transitions, error handling)
- [x] Memory leak detection (state consistency, framebuffer consistency)

## 📋 Phase 3: Grain Basin Kernel

### 3.1 Kernel Core
- [x] Boot sequence ✅ **COMPLETE**
  - [x] Boot sequence module (`src/kernel/boot.zig`)
  - [x] Boot phase enumeration (early, timer, interrupt, memory, storage, scheduler, channels, input, users, complete)
  - [x] Boot sequence tracking (start time, completion time, duration)
  - [x] Subsystem initialization order validation
  - [x] Boot sequence execution (`boot_kernel()` function)
  - [x] Kernel main integration (boot sequence called in `kmain()`)
  - [x] Comprehensive TigerStyle tests (`tests/028_boot_sequence_test.zig`)
- [x] Memory management (paging, allocation) ✅ **COMPLETE**
  - [x] Memory allocator module (`src/kernel/memory.zig`)
  - [x] Page-based allocation (4KB pages, 1024 pages max)
  - [x] Memory pool (4MB max, static allocation)
  - [x] Page allocation and deallocation
  - [x] Contiguous page allocation (first-fit algorithm)
  - [x] Byte-based allocation (convenience functions with page rounding)
  - [x] Memory pool integration with kernel (BasinKernel.memory_pool)
  - [x] Comprehensive TigerStyle tests (`tests/027_memory_allocator_test.zig`)
- [x] Process management (scheduling, IPC) ✅ **COMPLETE**
  - [x] Process scheduler module (`src/kernel/scheduler.zig`)
  - [x] Round-robin scheduling
  - [x] Current process tracking
  - [x] Process state transitions (spawn/exit)
  - [x] Wait syscall enhancement (polling-based)
  - [x] Scheduler integration with kernel
  - [x] Comprehensive TigerStyle tests (`tests/022_process_scheduler_test.zig`)
- [x] System calls (POSIX subset) ✅ **COMPLETE**
  - [x] All syscalls implemented with comprehensive validation
  - [x] Enhanced sysinfo syscall (returns actual system information)
  - [x] Memory management syscalls (map, unmap, protect)
  - [x] Process management syscalls (spawn, exit, yield, wait)
  - [x] IPC syscalls (channel_create, channel_send, channel_recv)
  - [x] File I/O syscalls (open, read, write, close, unlink, rename, mkdir, opendir, readdir, closedir)
  - [x] Time syscalls (clock_gettime, sleep_until)
  - [x] Input syscalls (read_input_event)
  - [x] Framebuffer syscalls (fb_clear, fb_draw_pixel, fb_draw_text)
  - [x] Comprehensive error handling and validation
  - [x] GrainStyle compliance (u32/u64 types, assertions, bounded allocations)

### 3.2 Device Drivers
- [x] Framebuffer driver ✅ **COMPLETE**
- [x] Keyboard driver ✅ **COMPLETE**
  - [x] Keyboard driver module (`src/kernel/keyboard.zig`)
  - [x] Key state tracking (256 keys max, pressed/released)
  - [x] Last key code tracking
  - [x] Key press/release handling
  - [x] Keyboard integration with kernel (BasinKernel.keyboard)
  - [x] Comprehensive TigerStyle tests (`tests/026_keyboard_mouse_driver_test.zig`)
- [x] Mouse driver ✅ **COMPLETE**
  - [x] Mouse driver module (`src/kernel/mouse.zig`)
  - [x] Position tracking (X, Y coordinates, max 65535 each)
  - [x] Button state tracking (5 buttons max, pressed/released)
  - [x] Last button tracking
  - [x] Button press/release handling
  - [x] Mouse integration with kernel (BasinKernel.mouse)
  - [x] Comprehensive TigerStyle tests (`tests/026_keyboard_mouse_driver_test.zig`)
- [x] Timer driver ✅ **COMPLETE**
  - [x] Timer driver module (`src/kernel/timer.zig`)
  - [x] Monotonic clock (nanoseconds since boot)
  - [x] Realtime clock (nanoseconds since epoch)
  - [x] Uptime tracking
  - [x] SBI timer integration (set_timer)
  - [x] Kernel timer integration (BasinKernel.timer)
  - [x] clock_gettime syscall (handled in integration layer)
  - [x] sleep_until syscall (timer-based validation)
  - [x] Comprehensive TigerStyle tests (`tests/020_timer_driver_test.zig`)
- [x] Interrupt controller ✅ **COMPLETE**
  - [x] Interrupt controller module (`src/kernel/interrupt.zig`)
  - [x] Interrupt types (timer, external, software)
  - [x] Handler registration (timer, external, software)
  - [x] Interrupt dispatch and routing
  - [x] Pending interrupt tracking
  - [x] Process pending interrupts
  - [x] Kernel interrupt controller integration
  - [x] Comprehensive TigerStyle tests (`tests/021_interrupt_controller_test.zig`)
- [x] Storage (in-memory filesystem) ✅ **COMPLETE**
  - [x] Storage filesystem module (`src/kernel/storage.zig`)
  - [x] File operations (create, read, write, delete)
  - [x] Directory operations (create, list)
  - [x] File table (128 files max, 64KB per file)
  - [x] Directory table (32 directories max)
  - [x] Storage integration with kernel (BasinKernel.storage)
  - [x] File I/O syscall integration (open/read/write/close)
  - [x] Comprehensive TigerStyle tests (`tests/025_storage_filesystem_test.zig`)
  - [ ] virtio-blk backend (future: persistent storage)
- [x] Signal handling ✅ **COMPLETE**
  - [x] Signal handling module (`src/kernel/signal.zig`)
  - [x] Signal types (SIGTERM, SIGKILL, SIGINT, SIGUSR1, SIGUSR2, etc.)
  - [x] Signal table per process (SignalTable struct)
  - [x] Signal handler registration (SignalAction)
  - [x] Pending signal tracking (bitmap)
  - [x] Blocked signal tracking (bitmap)
  - [x] Signal delivery and processing
  - [x] kill syscall (send signal to process by PID)
  - [x] signal syscall (register signal handler)
  - [x] sigaction syscall (POSIX-compatible signal action)
  - [x] SIGKILL immediate termination (cannot be caught or blocked)
  - [x] Signal integration with Process struct (Process.signals)
  - [x] Comprehensive assertions (GrainStyle compliance)
- [x] Exception Statistics Tracking ✅ **COMPLETE**
  - [x] Exception statistics module (`src/kernel_vm/exception_stats.zig`)
  - [x] Exception count tracking by type (16 exception types)
  - [x] Total exception count tracking
  - [x] Exception statistics summary (ExceptionSummary struct)
  - [x] VM integration (exception_stats field in VM struct)
  - [x] Automatic exception recording (VM errors mapped to RISC-V codes)
  - [x] Exception recording in VM error paths
  - [x] Statistics query interface (get_count, get_total_count, get_summary)
  - [x] Statistics reset capability
  - [x] Comprehensive TigerStyle tests (`tests/030_exception_stats_test.zig`)
  - [x] GrainStyle compliance (u32 types, assertions, bounded counters)
- [x] Exception Statistics in State Snapshot ✅ **COMPLETE**
  - [x] Exception statistics snapshot type (ExceptionStatsSnapshot struct)
  - [x] Exception statistics capture in VM state snapshot
  - [x] Exception statistics restoration from snapshot
  - [x] Exception statistics persistence (save/restore complete state)
  - [x] Enhanced state persistence tests (exception statistics verification)
  - [x] Comprehensive TigerStyle tests (`tests/031_exception_stats_snapshot_test.zig`)
  - [x] GrainStyle compliance (u32 types, assertions, bounded arrays)

### 3.3 Userspace Support
- [x] ELF loader ✅ **COMPLETE**
  - [x] loadUserspaceELF function in integration layer
  - [x] ELF parsing and segment loading
  - [x] Stack setup and argv/argc initialization
- [x] System call interface ✅ **COMPLETE**
  - [x] Syscall enumeration and routing
  - [x] Integration layer syscall handler
  - [x] Error code mapping
- [x] Process creation/termination ✅ **COMPLETE**
  - [x] Process scheduler with round-robin
  - [x] Process state transitions (spawn/exit)
  - [x] Process context tracking (PC, SP, entry point)
  - [x] Enhanced spawn syscall with ELF support
  - [x] Wait syscall enhancement
  - [x] Comprehensive TigerStyle tests
- [x] IPC mechanisms ✅ **COMPLETE**
  - [x] IPC channel module (`src/kernel/channel.zig`)
  - [x] Message queue (bounded, 32 messages max, 4KB per message)
  - [x] Channel table (64 channels max)
  - [x] channel_create/send/recv syscalls
  - [x] Comprehensive TigerStyle tests

## 🎨 Phase 4: Dream Editor + Browser

### 4.0 Shared Foundation (IN PROGRESS)

#### 4.0.1 GrainBuffer Enhancement ✅ **COMPLETE**
- [x] Increase readonly segments from 64 to 1000
- [x] Add `isReadOnly()` function
- [x] Add `getReadonlySpans()` function
- [x] Add `intersectsReadonlyRange()` with binary search
- [x] Comprehensive assertions (GrainStyle compliance)
- [x] All tests pass

#### 4.0.2 GLM-4.6 Client ✅ **COMPLETE**
- [x] Client structure created
- [x] Message types defined
- [x] Bounds checking implemented
- [x] HTTP client foundation created
- [x] HTTP implementation (JSON serialization)
- [x] SSE streaming parser (1,000 tps ready)
- [x] Integration with Cerebras API
- [ ] Tool calling support (future enhancement)

#### 4.0.3 Dream Protocol ✅ **COMPLETE**
- [x] Nostr event structure (Zig-native)
- [x] WebSocket client (low-latency, frame parsing)
- [x] State machine foundation (TigerBeetle-style)
- [x] Event streaming structure (real-time ready)
- [ ] Relay connection management (integration pending)

#### 4.0.4 DAG Core Foundation ✅ **COMPLETE**
- [x] Core DAG data structure (`src/dag_core.zig`)
- [x] Nodes, edges, events (HashDAG-style)
- [x] TigerBeetle-style state machine execution
- [x] Bounded allocations (max 10,000 nodes, 100,000 edges)
- [x] Comprehensive assertions (GrainStyle compliance)
- [x] Tests for initialization, node/edge/event operations
- [x] Acyclic verification (basic checks)

### 4.1 Dream Editor Core (PLANNED)

#### 4.1.1 Readonly Spans Integration ✅ **COMPLETE**
- [x] Integrate enhanced GrainBuffer into editor
- [x] Visual rendering (readonly spans in render result)
- [x] Edit protection (prevent modifications)
- [x] Cursor handling (insert checks for readonly violations)

#### 4.1.2 Method Folding ✅ **COMPLETE**
- [x] Parse code structure (regex-based for Zig)
- [x] Identify method/function boundaries
- [x] Fold bodies by default, show signatures
- [x] Toggle folding (keyboard shortcut ready)
- [x] Visual indicators (fold state tracking)

#### 4.1.3 GLM-4.6 Integration 🔄 **IN PROGRESS**
- [x] Code completion (ghost text at 1,000 tps)
- [x] Editor integration (optional GLM-4.6, falls back to LSP)
- [ ] Code transformation (refactor, extract, inline)
- [ ] Tool calling (run `zig build`, `jj status`)
- [ ] Multi-file edits (context-aware)

#### 4.1.4 Tree-sitter Integration ✅ **ENHANCED**
- [x] Foundation created (simple regex-based parser)
- [x] Tree structure with nodes (functions, structs)
- [x] Node lookup at positions (for hover, navigation)
- [x] Editor integration (parse and query syntax tree)
- [x] Syntax token extraction (keywords, strings, comments, numbers, operators)
- [x] Iterative node search (no recursion, GrainStyle compliant)
- [x] Token lookup at positions for syntax highlighting
- [ ] Tree-sitter C library bindings (future)
- [ ] Zig grammar integration (future)
- [ ] Code actions (extract function, rename symbol) (future)

#### 4.1.5 Complete LSP Implementation ✅ **COMPLETE**
- [x] JSON-RPC 2.0 serialization/deserialization
- [x] Snapshot model (incremental updates, Matklad-style)
- [x] Cancellation support for pending requests
- [x] Server communication (stdin/stdout with Content-Length headers)
- [x] Document lifecycle (didOpen, didChange with incremental edits)
- [x] GrainStyle compliance (u32 types, assertions, bounded allocations)
- [ ] Zig-specific features (comptime analysis) - pending

#### 4.1.6 Magit-Style VCS ✅ **COMPLETE**
- [x] Generate `.jj/status.jj` (readonly metadata, editable hunks)
- [x] Generate `.jj/commit/*.diff` (readonly commit info, editable diff)
- [x] Watch for edits, invoke `jj` commands
- [x] Readonly spans for commit hashes, parent info, file paths, diff headers
- [x] Parse `jj status` and `jj diff` output
- [x] Virtual file system with bounded allocations
- [x] GrainStyle compliance (u32 types, assertions, no recursion)

#### 4.1.7 Multi-Pane Layout ✅ **COMPLETE**
- [x] Split panes (horizontal/vertical)
- [x] Tile windows (editor, terminal, VCS status, browser)
- [x] Workspace management (max 10 workspaces, River-style switching)
- [x] Focus navigation (next pane, iterative traversal)
- [x] Pane closing and merging
- [x] Layout resizing (recalculate rectangles on resize)
- [x] Iterative tree traversal (no recursion, GrainStyle compliant)
- [x] GrainStyle compliance (u32 types, assertions, bounded allocations)
- [ ] River compositor integration (future: full Wayland compositor)
- [ ] Moonglow keybindings (future: keybinding system)

### 4.2 DAG Integration (IN PROGRESS)

#### 4.2.1 Editor-DAG Integration ✅ **COMPLETE**
- [x] Map Tree-sitter AST nodes to DAG nodes (`src/aurora_dag_integration.zig`)
- [x] Map code edits to DAG events (HashDAG-style with parent references)
- [x] Streaming updates (Hyperfiddle-style, TigerBeetle state machine)
- [x] Project-wide semantic graph (Matklad vision, AST node tracking)
- [x] Node lookup by position (for navigation, hover)
- [x] Dependency tracking (parent-child relationships in DAG)
- [ ] Incremental compilation integration (majjit) - future enhancement

#### 4.2.2 Browser-DAG Integration ✅ **COMPLETE**
- [x] Map DOM nodes to DAG nodes (`src/dream_browser_dag_integration.zig`)
- [x] Map web requests to DAG events (HashDAG-style with parent references)
- [x] Streaming updates (real-time, `processStreamingUpdates()`)
- [x] Unified state (editor + browser share same DAG)
- [x] Dependency tracking (parent-child relationships in DOM)
- [x] URL node reuse (unique nodes per URL)
- [x] Comprehensive tests (tests/019_browser_dag_integration_test.zig)

#### 4.2.3 HashDAG Consensus ✅ **COMPLETE**
- [x] Event ordering (Djinn's HashDAG proposal, `src/hashdag_consensus.zig`)
- [x] Virtual voting (consensus without explicit votes, witness determination)
- [x] Fast finality (seconds, not minutes, round-based finality)
- [x] High throughput (parallel ingestion, deterministic ordering)
- [x] Round determination (max parent round + 1)
- [x] Witness identification (first event per creator per round)
- [x] Fame determination (witness events are famous)
- [x] Finality manager (events in rounds N-2 or earlier are finalized)

### 4.3 Dream Browser Core (PLANNED)

#### 4.3.1 HTML/CSS Parser ✅ **COMPLETE**
- [x] HTML parser (subset of HTML5, `src/dream_browser_parser.zig`)
- [x] CSS parser (subset of CSS3, basic rule parsing)
- [x] DOM tree construction (bounded depth, explicit nodes)
- [x] Style computation (cascade, specificity - basic implementation)
- [x] DAG integration (HTML node → DOM node conversion)
- [ ] Full HTML5/CSS3 parser (future enhancement)

#### 4.3.2 Rendering Engine ✅ **COMPLETE**
- [x] Layout engine (block/inline flow, `src/dream_browser_renderer.zig`)
- [x] Render to Grain Aurora components (DOM → Aurora Node conversion)
- [x] Readonly spans for metadata (event ID, timestamp, author)
- [x] Editable spans for content (text content is editable)
- [x] DAG-based rendering pipeline (DOM nodes from DAG)

#### 4.3.3 Nostr Content Loading ✅ **COMPLETE**
- [x] Parse Nostr URLs (`nostr:note1...`, `nostr:npub1...`, `src/dream_browser_nostr.zig`)
- [x] Subscribe to Nostr events (via DreamProtocol, filter by URL type)
- [x] Receive events (streaming, real-time, WebSocket integration)
- [x] Render events to browser (DOM nodes with readonly spans for metadata)
- [x] DAG event integration (map events to DAG via browser-DAG integration)

#### 4.3.4 WebSocket Transport ✅ **COMPLETE**
- [x] WebSocket client (low-latency, `src/dream_browser_websocket.zig`)
- [x] Bidirectional communication (send/receive messages via WebSocketClient)
- [x] Connection management (connection pool, state tracking, max 10 connections)
- [x] Error handling and reconnection (exponential backoff, max 10 attempts, max 60s delay)
- [x] Connection pooling (multiple relay connections, URL parsing)
- [x] Health monitoring (ping/pong handling, connection statistics)

### 4.3 Editor-Browser Integration 🔄 **IN PROGRESS**

#### 4.3.1 Unified UI ✅ **COMPLETE**
- [x] Multi-pane layout (editor + browser integrated)
- [x] Tab management (editor tabs, browser tabs, max 100 each)
- [x] Workspace management (River-style switching)
- [x] Shared Grain Aurora UI
- [x] Split panes and open editor/browser in new panes
- [x] Focus navigation and pane closing
- [x] Title extraction from URIs and URLs
- [x] GrainStyle compliance (u32 types, assertions, bounded allocations)

#### 4.3.2 Live Preview ✅ **COMPLETE**
- [x] Editor edits → Browser preview (real-time propagation)
- [x] Nostr event updates → Editor sync (bidirectional)
- [x] Bidirectional sync (editor ↔ browser)
- [x] Sync subscriptions (editor-to-browser, browser-to-editor, bidirectional)
- [x] DAG-based event propagation (HashDAG-style ordering)
- [x] Streaming updates (Hyperfiddle-style, TigerBeetle state machine)
- [x] Update queue with bounded allocations (max 1,000 updates/second)
- [x] GrainStyle compliance (u32 types, assertions, bounded allocations)

#### 4.3.3 GrainBank Integration ✅ **COMPLETE**
- [x] Micropayments in browser (automatic payments for content)
- [x] Deterministic contracts (TigerBeetle-style state machine)
- [x] Peer-to-peer payments (direct Nostr-based transfers)
- [x] State machine execution (bounded, deterministic)
- [x] Contract management (create, execute actions: mint, burn, transfer, collect_tax)
- [x] Payment processing (batch processing, deterministic execution)
- [x] DAG integration (contracts and payments as DAG events)
- [x] GrainStyle compliance (u32 types, assertions, bounded allocations)

#### 4.3.4 GrainBank Browser Integration ✅ **COMPLETE**
- [x] Integrate GrainBank into unified IDE
- [x] Browser tabs can have associated GrainBank contracts
- [x] Automatic micropayments triggered when viewing paid content
- [x] Payment detection from URL/content (Nostr event parsing)
- [x] Enable/disable payments per tab
- [x] Associate contracts with browser tabs
- [x] Process payments via deterministic state machine
- [x] GrainStyle compliance (u32 types, assertions, bounded allocations)

### 4.4 Window System (COMPLETE - Legacy)
- [x] Window rendering
- [x] Input handling (mouse, keyboard)
- [x] Animation/update loop
- [x] Window resizing

## 🌐 Phase 5: Dream Browser Advanced Features (IN PROGRESS)

**Status**: 🔄 Zig 0.15 API compatibility fixes complete ✅ | Next: Performance optimization

**Note**: Core browser features are now in Phase 4.2 (Dream Browser Core). This phase covers advanced features.

### 5.1 Performance Optimization
- [x] Fix Zig 0.15 API compatibility issues (ArrayList, JSON serialization, flush)
- [x] Convert recursive functions to iterative (stack-based) for GrainStyle compliance
- [ ] Profile and optimize hot paths
- [ ] Reduce allocations in hot paths
- [ ] Optimize rendering (60fps guaranteed)
- [ ] Optimize protocol (sub-millisecond latency)

### 5.2 Advanced Browser Features
- [x] Scrolling and navigation ✅ **COMPLETE**
  - [x] Viewport state management (scroll position, dimensions, content size)
  - [x] Scrolling (relative `scroll_by`, absolute `scroll_to`)
  - [x] Navigation history (back/forward, history entries with scroll positions)
  - [x] Bounds checking (prevent out-of-bounds scrolling)
  - [x] Integration with UnifiedIde (viewport per browser tab)
  - [x] Scrolling and navigation methods for browser tabs
  - [x] Comprehensive tests for viewport functionality
- [ ] Image decoding (PNG, JPEG)
- [ ] Font rendering (TTF/OTF)
- [ ] Bookmarks and history UI
- [ ] Tab management enhancements

### 5.3 WSE Hardware Integration (Future)
- [ ] RAM-only storage (44GB SRAM)
- [ ] Spatial computing (dataflow)
- [ ] Parallel rendering (900k cores)
- [ ] Zero-copy operations

### 5.4 RISC-V Custom Instructions (Future)
- [ ] Browser-specific extensions
- [ ] Hardware acceleration
- [ ] Formal verification
- [ ] Performance optimization

## 🔧 Phase 6: Framework 13 RISC-V Hardware

### 6.1 Hardware Acquisition
- [ ] Research DeepComputing DC-ROMA mainboard
- [ ] Acquire Framework 13 RISC-V mainboard
- [ ] Set up development environment
- [ ] Test hardware compatibility

### 6.2 Native RISC-V Port
- [ ] Port Grain Basin Kernel to native RISC-V
- [ ] Remove JIT layer (native execution)
- [ ] Optimize for hardware
- [ ] Boot on real hardware

### 6.3 Display Integration
- [ ] Research repairable display options
- [ ] Design custom display module
- [ ] Integrate with Framework 13 chassis
- [ ] Create open-source documentation

### 6.4 Driver Development
- [ ] Display driver for custom module
- [ ] Power management
- [ ] Peripheral support (USB, audio, networking)
- [ ] Hardware-specific optimizations

## 🚀 Phase 7: Production

### 7.1 Performance
- [ ] Optimize JIT compilation
- [ ] Reduce memory footprint
- [ ] Improve startup time
- [ ] Profile and optimize hot paths

### 7.2 Stability
- [ ] Comprehensive error handling
- [ ] Crash recovery
- [ ] Auto-save
- [ ] State persistence

### 7.3 Documentation
- [ ] User guide
- [ ] API documentation
- [ ] Architecture overview
- [ ] Contributing guide
- [ ] Hardware repair guides

### 7.4 Distribution
- [ ] macOS app bundle
- [ ] Code signing
- [ ] Notarization
- [ ] Update mechanism
- [ ] Hardware distribution

## 📊 Current Status

**Completed**: 
- JIT Compiler (Phase 1) ✅
- VM Integration (Phase 2) ✅
- Framebuffer Initialization & Sync (Phase 2.2, 2.4) ✅
- Input Pipeline (Phase 2.5) ✅
- Text Rendering (Phase 2.6) ✅
- Framebuffer Syscalls (Phase 2.7) ✅
- Userspace Framebuffer Program (Phase 2.8) ✅
- Integration Testing (Phase 2.9) ✅
- Framebuffer Optimization (Phase 2.10) ✅
- Error Handling and Recovery (Phase 2.11) ✅
- Performance Monitoring and Diagnostics (Phase 2.12) ✅
- VM State Persistence (Phase 2.13) ✅
- VM API Documentation (Phase 2.14) ✅
- Dream Editor Foundation - GrainBuffer Enhancement (Phase 4.0.1) ✅
- Dream Editor Foundation - GLM-4.6 Client (Phase 4.0.2) ✅
- Dream Editor Foundation - Dream Protocol (Phase 4.0.3) ✅
- Dream Editor Core - Readonly Spans Integration (Phase 4.1.1) ✅
- Dream Editor Core - Method Folding (Phase 4.1.2) ✅

**In Progress**: 
- Dream Editor Core - GLM-4.6 Integration (Phase 4.1.3) 🔄

**Next Up**: 
- Userspace program execution (IDE/Browser in Grain Vantage)
- Dream Editor Core (Phase 4.1): Tree-sitter, LSP enhancements, VCS integration
- Dream Browser Core (Phase 4.2): HTML/CSS parser, Nostr content loading
- Dream Browser Core (Phase 4.2)
- Framework 13 Hardware (Phase 6)

**Test Results**: 12/12 JIT tests passing
**Code Quality**: 1,631 lines, GrainStyle compliant
**Documentation**: Complete (jit_architecture.md, plan.md)

## 🎯 Immediate Next Steps

1. **VM Integration**: Hook JIT into `vm.zig` dispatch loop
2. **Kernel Boot**: Implement basic boot sequence
3. **GUI Integration**: Connect framebuffer to macOS window
4. **Hardware Research**: Evaluate Framework 13 RISC-V mainboard

## 👥 Parallel Development Opportunities

**Current Agent Focuses**:
1. **VM/Kernel Agent**: Grain Vantage & Kernel Boot Integration
   - **Active Modules**: `src/kernel_vm/`, `src/kernel/`, `src/platform/macos_tahoe/`
   - **Status**: Day 1-2 tasks complete, boot pipeline functional
   - **See**: `docs/agent_work_summary.md`

2. **Dream Editor/Browser Agent**: Foundation Components
   - **Active Modules**: `src/aurora_*.zig`, `src/dream_*.zig`, `src/grain_buffer.zig`
   - **Status**: Phase 0.1 complete, Phase 0.2 in progress
   - **See**: `docs/dream_editor_agent_summary.md`

**Available for Parallel Work** (low conflict risk):
- **Dream Editor/Browser** (`src/aurora_*.zig`, `src/dream_*.zig`) - 🔄 Active (Phase 0)
- **Userspace Tools** (`src/userspace/`) - Utilities, browser, build tools
- **Grain Ecosystem** (`src/graincard/`, `grainseed*.zig`) - Graincard, seeds
- **TLS/Networking** (`src/grain_tls/`, `nostr.zig`) - TLS, protocols
- **Platform Implementations** (`src/platform/riscv/`) - Native RISC-V
- **Kernel Advanced Features** - Memory, processes (design in parallel)
- **Documentation** (`docs/learning-course/`) - Course content

**See**: 
- `docs/agent_work_summary.md` - VM/Kernel agent work
- `docs/dream_editor_agent_summary.md` - Dream Editor/Browser agent work
- `docs/dream_implementation_roadmap.md` - Complete Dream Editor/Browser roadmap

## 📚 References

- **JIT Architecture**: `docs/zyx/jit_architecture.md`
- **Grain Style**: `docs/zyx/grain_style.md`
- **Plan**: `docs/plan.md`
- **Agent Work Summary**: `docs/agent_work_summary.md` (VM/Kernel agent)
- **Dream Editor Agent Summary**: `docs/dream_editor_agent_summary.md` (Dream Editor/Browser agent)
- **Dream Implementation Roadmap**: `docs/dream_implementation_roadmap.md`
- **Dream Browser Vision**: `docs/dream_browser_vision.md`
- **Dream Editor Plan**: `docs/dream_editor_plan.md`
- **Ray Notes**: `docs/zyx/ray.md`
- **Browser Spec**: `docs/zyx/browser_prompt.md`
- **Development Strategy**: `docs/zyx/development_strategy_2025.md`
