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

#### 2.3 Performance Validation
- [ ] Benchmark JIT vs interpreter
- [ ] Verify 10x+ speedup on hot paths
- [ ] Profile memory usage
- [ ] Measure cache hit rate

### Day 3: GUI Integration

#### 2.4 Framebuffer Sync ✅ **COMPLETE**
- [x] Map kernel framebuffer to host memory
- [x] Update macOS window on changes
- [x] Optimize copy performance (direct memcpy)
- [ ] Implement dirty region tracking (optional optimization)

#### 2.5 Input Pipeline ✅ **COMPLETE**
- [x] Route macOS keyboard events to kernel (via VM input queue)
- [x] Route macOS mouse events to kernel (via VM input queue)
- [x] Implement input event queue in VM (bounded circular buffer)
- [ ] Test basic input handling (requires kernel syscall to read events)

#### 2.6 Text Rendering ✅ **COMPLETE**
- [x] Integrate text rendering into framebuffer module
- [x] Render simple text to framebuffer (8x8 bitmap font)
- [x] Display kernel boot messages on framebuffer
- [ ] Font loading and rendering (advanced: can use TTF/OTF later)

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

### 2.2 Performance
- [x] Create benchmark suite (`benchmark_jit.zig`)
- [ ] Run benchmarks and collect metrics
- [ ] Optimize hot paths based on results
- [ ] Profile hot paths
- [ ] Optimize block compilation

### 2.3 Testing
- [ ] Integration tests with real kernel code
- [ ] Stress testing (long-running programs)
- [ ] Edge case validation
- [ ] Memory leak detection

## 📋 Phase 3: Grain Basin Kernel

### 3.1 Kernel Core
- [ ] Boot sequence
- [ ] Memory management (paging, allocation)
- [ ] Process management (scheduling, IPC)
- [ ] System calls (POSIX subset)

### 3.2 Device Drivers
- [ ] Framebuffer driver
- [ ] Keyboard driver
- [ ] Mouse driver
- [ ] Timer driver
- [ ] Interrupt controller
- [ ] Storage (virtio-blk)

### 3.3 Userspace Support
- [ ] ELF loader
- [ ] System call interface
- [ ] Process creation/termination
- [ ] IPC mechanisms

## 🎨 Phase 4: Grain Aurora IDE

### 4.1 Window System (COMPLETE)
- [x] Window rendering
- [x] Input handling (mouse, keyboard)
- [x] Animation/update loop
- [x] Window resizing

### 4.2 Text Rendering
- [ ] Integrate TextRenderer
- [ ] Font loading
- [ ] Cursor rendering
- [ ] Text input handling

### 4.3 Editor Core
- [ ] Buffer management
- [ ] Syntax highlighting
- [ ] Code completion
- [ ] Go-to-definition

### 4.4 River Compositor
- [ ] Multi-pane layout
- [ ] Window tiling
- [ ] Moonglow keybindings
- [ ] Workspace management

### 4.5 LSP Integration
- [ ] Matklad-inspired snapshot model
- [ ] Incremental analysis
- [ ] Cancellation support
- [ ] Zig-specific features

## 🌐 Phase 5: GrainView Browser

### 5.1 Core Engine
- [ ] HTML parser (subset of HTML5)
- [ ] CSS parser (subset of CSS3)
- [ ] DOM tree construction
- [ ] Layout engine (block/inline flow)
- [ ] Basic rendering to Grain Aurora framebuffer

### 5.2 Networking
- [ ] HTTP/1.1 client (no TLS initially)
- [ ] URL parsing and resolution
- [ ] Resource fetching (HTML, CSS, images)
- [ ] Basic caching

### 5.3 JavaScript Engine
- [ ] ECMAScript 5 subset parser
- [ ] Interpreter (or JIT via Grain VM)
- [ ] DOM API bindings
- [ ] Event system

### 5.4 Advanced Features
- [ ] TLS/HTTPS support
- [ ] Image decoding (PNG, JPEG)
- [ ] Font rendering
- [ ] Scrolling and navigation
- [ ] Bookmarks and history

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

**In Progress**: Performance Validation (Phase 2.3) 🔄
**Next Up**: Framework 13 Hardware (Phase 6), Advanced Features

**Test Results**: 12/12 JIT tests passing
**Code Quality**: 1,631 lines, GrainStyle compliant
**Documentation**: Complete (jit_architecture.md, plan.md)

## 🎯 Immediate Next Steps

1. **VM Integration**: Hook JIT into `vm.zig` dispatch loop
2. **Kernel Boot**: Implement basic boot sequence
3. **GUI Integration**: Connect framebuffer to macOS window
4. **Hardware Research**: Evaluate Framework 13 RISC-V mainboard

## 📚 References

- **JIT Architecture**: `docs/zyx/jit_architecture.md`
- **Grain Style**: `docs/zyx/grain_style.md`
- **Plan**: `docs/plan.md`
- **Ray Notes**: `docs/zyx/ray.md`
- **Browser Spec**: `docs/zyx/browser_prompt.md`
- **Development Strategy**: `docs/zyx/development_strategy_2025.md`
