# Grain OS Task List

> "A complete roadmap for Grain OS development, from JIT compiler to production IDE."

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
- [/] **Performance Benchmarking** <!-- id: 21.5 -->
    - [x] Create benchmark suite (`benchmark_jit.zig`)
    - [/] Run benchmarks and collect metrics (Blocked by environment/stack overflow debugging)
    - [ ] Optimize hot paths based on results
- [ ] Profile hot paths
- [ ] Optimize block compilation
- [ ] Measure cache hit rate

### 2.3 Testing
- [ ] Integration tests with real kernel code
- [ ] Stress testing (long-running programs)
- [ ] Edge case validation
- [ ] Memory leak detection

## 📋 Phase 3: Grain Basin Kernel

### 3.1 Kernel Core
- [ ] Boot sequence
- [ ] Memory management
- [ ] Process management
- [ ] System calls

### 3.2 Device Drivers
- [ ] Serial console
- [ ] Timer
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

## 🚀 Phase 5: Production

### 5.1 Performance
- [ ] Optimize JIT compilation
- [ ] Reduce memory footprint
- [ ] Improve startup time
- [ ] Profile and optimize hot paths

### 5.2 Stability
- [ ] Comprehensive error handling
- [ ] Crash recovery
- [ ] Auto-save
- [ ] State persistence

### 5.3 Documentation
- [ ] User guide
- [ ] API documentation
- [ ] Architecture overview
- [ ] Contributing guide

### 5.4 Distribution
- [ ] macOS app bundle
- [ ] Code signing
- [ ] Notarization
- [ ] Update mechanism

## 📊 Current Status

**Completed**: JIT Compiler (Phase 1) ✅
**In Progress**: VM Integration (Phase 2) 🔄
**Next Up**: Grain Basin Kernel (Phase 3)

**Test Results**: 12/12 JIT tests passing
**Code Quality**: 1,631 lines, TigerStyle compliant
**Documentation**: Complete (jit_architecture.md, cursor_prompt.md)

## 🎯 Immediate Next Steps

1. **VM Integration**: Hook JIT into `vm.zig` dispatch loop
2. **Performance Benchmarking**: Compare JIT vs interpreter
3. **Kernel Development**: Start Grain Basin kernel implementation
4. **Text Rendering**: Integrate TextRenderer into Aurora

## 📚 References

- **JIT Architecture**: `docs/jit_architecture.md`
- **Grain Style**: `docs/zyx/grain_style.md`
- **Plan**: `docs/zyx/plan.md`
- **Ray Notes**: `docs/zyx/ray.md`
- **Cursor Prompt**: `docs/cursor_prompt.md`
