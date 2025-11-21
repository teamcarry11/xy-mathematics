# Getting Started with Grain OS
## RISC-V Kernel + VM + Aurora IDE

Welcome to Grain OS—a minimal, safety-first operating system built in pure Zig. We're building a RISC-V-targeted kernel with a graphical interface, running first in a macOS Tahoe VM, with a clear path toward Framework 13 RISC-V hardware.

## What is Grain OS?

Grain OS is a **zero-dependency** operating system that combines:

- **Grain Basin Kernel**: A monolithic, single-threaded, safety-first RISC-V64 kernel
- **Grain VM**: A userspace RISC-V virtual machine with JIT compiler (RISC-V → AArch64)
- **Grain Aurora IDE**: A native macOS IDE for developing Grain OS itself
- **Framework 13 Target**: Native RISC-V hardware deployment (DeepComputing DC-ROMA)

## Current Status

**✅ Complete**: JIT Compiler (Phase 1)
- Full RISC-V64 instruction set + RVC compressed
- Security testing (12/12 tests passing)
- Advanced features (perf counters, TLB, register allocator)

**🔄 In Progress**: VM Integration (Phase 2)
- JIT integration into VM dispatch loop
- Kernel boot sequence
- GUI framebuffer sync

**📋 Next**: Kernel Development (Phase 3)
- Memory management
- Process scheduling
- Device drivers

## Architecture Overview

### Grain Aurora Stack

```
┌─────────────────────────────────────┐
│   macOS Tahoe 26.1 (Native Cocoa)  │
├─────────────────────────────────────┤
│   Grain Aurora IDE (Zig GUI)       │
├─────────────────────────────────────┤
│   Grain VM (RISC-V → AArch64 JIT)  │ ✅ COMPLETE
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

## Installation

### Prerequisites

- **macOS**: Sequoia 15.1 (Tahoe) or later
- **Hardware**: MacBook Air M2 (2022) or compatible Apple Silicon
- **Zig**: 0.15.2+ (install from [ziglang.org](https://ziglang.org))
- **QEMU**: For RISC-V emulation testing (`brew install qemu`)

### Step 1: Install Zig

```bash
# Download Zig 0.15.2 from ziglang.org
# Extract to /usr/local/zig or ~/zig
# Add to PATH in ~/.zshrc:
export PATH="$HOME/zig:$PATH"
```

### Step 2: Clone Repository

```bash
git clone https://github.com/teamcarry11/xy-mathematics.git
cd xy-mathematics
```

### Step 3: Build Grain VM

```bash
# Build the JIT compiler and VM
zig build

# Run the Tahoe window (macOS GUI)
zig build tahoe
```

You should see:
- Native macOS window with "Grain Aurora" title
- Dark blue-gray background
- Window ready for kernel framebuffer display

## Development Workflow

### Phase 1: VM Integration (Current Focus)

**Objective**: Get Grain Basin Kernel booting in Grain VM.

1. **Complete JIT Integration**
   ```bash
   # Edit src/kernel_vm/vm.zig
   # Add init_with_jit() and step_jit() methods
   ```

2. **Kernel Boot Sequence**
   ```bash
   # Edit src/kernel/basin_kernel.zig
   # Implement basic boot loader
   ```

3. **Test in VM**
   ```bash
   zig build tahoe
   # Kernel should boot and display test pattern
   ```

### Phase 2: Framework 13 RISC-V (Weeks 2-4)

**Objective**: Port to native RISC-V hardware.

1. **Acquire Hardware**
   - Purchase DeepComputing DC-ROMA mainboard
   - Install in Framework 13 chassis

2. **Port Kernel**
   ```bash
   # Remove JIT layer (native execution)
   # Optimize for hardware
   ```

3. **Boot on Hardware**
   ```bash
   # Flash kernel to mainboard
   # Boot from USB or network
   ```

## GrainStyle Guidelines

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

## Design Principles

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

## Project Structure

```
xy-mathematics/
├── src/
│   ├── kernel/              # Grain Basin Kernel
│   ├── kernel_vm/           # Grain VM (JIT + interpreter)
│   ├── platform/           # macOS Tahoe host
│   └── tahoe_window.zig    # GUI window system
├── docs/
│   ├── plan.md             # Development plan
│   ├── tasks.md            # Task list
│   └── zyx/                # Detailed documentation
└── archaeology/            # Historical files
```

## Next Steps

### Immediate (Next 3 Days)

1. **VM Integration**: Hook JIT into `vm.zig` dispatch loop
2. **Kernel Boot**: Implement basic boot sequence
3. **GUI Integration**: Connect framebuffer to macOS window

### Short-Term (Weeks 2-4)

1. **Framework 13 Research**: Evaluate DC-ROMA mainboard
2. **Hardware Acquisition**: Purchase and set up development board
3. **Native Port**: Remove JIT layer, optimize for hardware

### Long-Term (Months 2-6)

1. **Custom Display**: Design repairable display module
2. **Production Hardening**: Performance, power management, drivers
3. **Documentation**: User guides, API docs, repair guides

## References

- **Development Plan**: `docs/plan.md`
- **Task List**: `docs/tasks.md`
- **JIT Architecture**: `docs/zyx/jit_architecture.md`
- **Grain Style**: `docs/zyx/grain_style.md`
- **Framework 13 RISC-V**: https://frame.work/products/deep-computing-risc-v-mainboard
- **DeepComputing DC-ROMA**: https://deepcomputing.io/product/dc-roma-risc-v-mainboard/

## Getting Help

- **Documentation**: `docs/` directory
- **GitHub Issues**: Report bugs or request features
- **Discussions**: Ask questions and share ideas

Welcome to Grain OS. Let's build something that lasts. 🌾
