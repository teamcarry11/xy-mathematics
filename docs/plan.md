# Grain OS Development Plan
## RISC-V Kernel + VM + Aurora IDE

**Current Status**: Performance Validation complete ✅. All Day 1-2 tasks complete! 🎉

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
   - ⏳ Implement dirty region tracking (optional optimization)

2. **Input Pipeline** ✅ **COMPLETE**
   - ✅ Route macOS keyboard/mouse to kernel (via input event queue)
   - ✅ Implement input event queue in VM
   - ⏳ Test basic input handling (kernel syscall needed)

3. **Text Rendering** ✅ **COMPLETE**
   - ✅ Integrate text rendering into framebuffer module
   - ✅ Render simple text to framebuffer (8x8 bitmap font)
   - ✅ Display kernel boot messages on framebuffer

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

#### 0.2: GLM-4.6 Client 🔄 **IN PROGRESS**
- ✅ Client structure created
- ✅ HTTP client foundation created
- 🔄 HTTP implementation (JSON serialization, SSE streaming)
- 📋 Tool calling support

#### 0.3: Dream Protocol 📋 **PLANNED**
- 📋 Nostr + WebSocket + TigerBeetle-style state machine
- 📋 Event streaming (real-time, sub-millisecond latency)
- 📋 Relay connection management

### Phase 1: Dream Editor Core (Planned)

**Objective**: Matklad-inspired editor with GLM-4.6 integration.

- Readonly spans (text-as-UI paradigm)
- Method folding (bodies fold by default)
- Tree-sitter integration (syntax highlighting)
- GLM-4.6 code completion (1,000 tps)
- Complete LSP implementation
- Magit-style VCS integration

### Phase 2: Dream Browser Core (Planned)

**Objective**: Zig-native browser with Nostr protocol.

- HTML/CSS parser (subset)
- Rendering engine (Grain Aurora)
- Nostr content loading (real-time)
- WebSocket transport (low-latency)
- TigerBeetle-style state machine

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
