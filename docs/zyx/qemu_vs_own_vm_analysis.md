# QEMU vs Our Own VM: Tiger Style Analysis

**Date**: 2025-11-13  
**Purpose**: Evaluate QEMU vs rolling our own RISC-V emulator for Tiger Style compliance

## Current Situation

**What We Have:**
- Pure Zig RISC-V64 instruction emulator
- Focused on kernel development (not full hardware emulation)
- Lightweight, simple, Tiger Style compliant
- Integrated into macOS Tahoe GUI

**What QEMU Provides:**
- Full hardware emulation (CPU, memory, devices, interrupts)
- Battle-tested, widely used
- Supports many RISC-V platforms and devices
- Decades of development, millions of lines of code

## Is QEMU Anti-Tiger Style?

### Arguments FOR QEMU Being Anti-Tiger Style

**1. External Dependency:**
- QEMU is a massive external dependency (C codebase)
- No Tiger Style guarantees (no assertions, no Zig type safety)
- No control over code quality, style, architecture
- Dependency on external project's maintenance

**2. Complexity:**
- QEMU is extremely complex (millions of lines of code)
- Hard to understand, modify, debug
- Overkill for kernel development (we don't need full hardware emulation)
- Violates "simplicity" principle of Tiger Style

**3. Focus:**
- QEMU emulates everything (CPU, memory, devices, interrupts, etc.)
- We only need instruction emulation for kernel development
- QEMU's complexity distracts from kernel development
- Violates "focus" principle of Tiger Style

**4. Control:**
- Can't modify QEMU easily (C codebase, complex build system)
- Can't enforce Tiger Style in QEMU code
- Can't add custom features easily
- Violates "control" principle of Tiger Style

### Arguments AGAINST QEMU Being Anti-Tiger Style

**1. Hardware Parity:**
- QEMU provides full hardware emulation parity
- Our VM might miss hardware quirks, edge cases
- QEMU is battle-tested on real hardware
- Better for testing kernel on "real" hardware

**2. Time:**
- Building full emulator would take years
- QEMU already exists, works, is maintained
- Focus time on kernel development, not emulator development
- "Don't reinvent the wheel" principle

**3. Compatibility:**
- QEMU supports many RISC-V platforms
- Our VM only supports what we implement
- QEMU is standard (used by Linux, other OSes)
- Better compatibility with existing tools (GDB, etc.)

**4. Testing:**
- QEMU is extensively tested
- Our VM needs extensive testing
- QEMU catches hardware bugs we might miss
- Better for finding kernel bugs

## Good Reasons NOT to Roll Our Own Full Emulator

### 1. Complexity Explosion

**Full Hardware Emulation Requires:**
- CPU emulation (instructions, registers, exceptions)
- Memory management (MMU, page tables, TLB)
- Interrupt controller (PLIC, CLINT)
- Timer (RTC, timer interrupts)
- Serial/UART (console I/O)
- Block devices (disk emulation)
- Network devices (network emulation)
- PCI/PCIe bus
- Device tree (DTB) parsing
- Boot process (SBI, bootloader)

**Our Current VM:**
- CPU emulation (instructions, registers) ✅
- Memory (simple linear memory) ✅
- SBI calls (console, shutdown) ✅
- ELF loading ✅

**Gap:**
- MMU (memory management unit)
- Interrupts (PLIC, CLINT)
- Timer (RTC, timer interrupts)
- Devices (disk, network, etc.)

**Verdict:** Full emulator is **massively more complex**. Our VM is focused on kernel development, not full hardware emulation.

### 2. Time Investment

**QEMU Development:**
- Decades of development
- Millions of lines of code
- Thousands of contributors
- Extensive testing

**Our VM Development:**
- Weeks/months of development
- Hundreds of lines of code
- Focused on kernel development needs
- Minimal but sufficient

**Verdict:** Building full emulator would take **years**, distract from kernel development.

### 3. Testing Burden

**QEMU Testing:**
- Extensively tested on real hardware
- Used by Linux, other OSes
- Catches hardware bugs, edge cases
- Well-maintained test suite

**Our VM Testing:**
- We write our own tests
- Focused on kernel development needs
- Might miss hardware quirks
- Limited to what we implement

**Verdict:** QEMU's testing is **extensive**, ours is **focused but limited**.

### 4. Maintenance Burden

**QEMU Maintenance:**
- Maintained by QEMU team
- Regular updates, bug fixes
- Hardware support updates
- Security patches

**Our VM Maintenance:**
- We maintain it ourselves
- Updates as kernel needs change
- Limited hardware support
- Full control but full responsibility

**Verdict:** QEMU maintenance is **shared**, ours is **our responsibility**.

## Good Reasons TO Roll Our Own (Focused VM)

### 1. Tiger Style Compliance

**Our VM:**
- Pure Zig, Tiger Style compliant
- Comprehensive assertions
- Static allocation where possible
- Clear "why" comments
- <70 line functions, <100 columns

**QEMU:**
- C codebase, no Tiger Style
- No assertions (or minimal)
- Dynamic allocation everywhere
- Complex, hard to understand
- Functions can be thousands of lines

**Verdict:** Our VM is **Tiger Style compliant**, QEMU is **not**.

### 2. Focus and Simplicity

**Our VM:**
- Focused on kernel development
- Simple, easy to understand
- Only what we need
- Clear architecture

**QEMU:**
- Full hardware emulation
- Complex, hard to understand
- Everything (even what we don't need)
- Complex architecture

**Verdict:** Our VM is **focused and simple**, QEMU is **comprehensive but complex**.

### 3. Control and Customization

**Our VM:**
- Full control over code
- Easy to modify, extend
- Custom features (GUI integration, etc.)
- Tiger Style enforcement

**QEMU:**
- Limited control (external dependency)
- Hard to modify (C codebase)
- Standard features only
- No Tiger Style enforcement

**Verdict:** Our VM gives us **full control**, QEMU gives us **limited control**.

### 4. Integration

**Our VM:**
- Integrated into macOS Tahoe GUI
- Custom serial output display
- VM pane rendering
- Seamless development workflow

**QEMU:**
- Separate process, separate window
- Standard serial output
- No GUI integration
- Separate development workflow

**Verdict:** Our VM is **integrated**, QEMU is **separate**.

## Recommendation: Hybrid Approach

### Strategy: Focused VM + QEMU for Validation

**Primary Development:**
- Use our **focused VM** for daily kernel development
- Tiger Style compliant, integrated, simple
- Fast iteration, easy debugging
- Custom features (GUI integration, etc.)

**Validation and Testing:**
- Use **QEMU** for final validation
- Test on "real" hardware (QEMU emulation)
- Catch hardware quirks, edge cases
- Ensure compatibility with real RISC-V hardware

**Benefits:**
- **Best of both worlds**: Tiger Style development + hardware validation
- **Focused development**: Our VM for daily work
- **Confidence**: QEMU for final testing
- **No compromise**: Tiger Style compliance + hardware parity

### Implementation Plan

**Phase 1: Enhance Our VM (Current)**
- Add more RISC-V instructions (as needed)
- Add MMU support (for kernel memory management)
- Add interrupt support (for kernel interrupts)
- Keep it focused, Tiger Style compliant

**Phase 2: QEMU Integration (Future)**
- Add QEMU as optional validation tool
- Run kernel in QEMU for final testing
- Compare VM vs QEMU behavior
- Ensure compatibility

**Phase 3: Hardware Testing (Future)**
- Test on Framework 13 RISC-V mainboard
- Validate VM and QEMU against real hardware
- Ensure all three match (VM ≈ QEMU ≈ Hardware)

## Conclusion

**Is QEMU Anti-Tiger Style?**

**Yes, if used as primary development tool:**
- External dependency (no Tiger Style guarantees)
- Complexity (violates simplicity principle)
- Lack of control (can't enforce Tiger Style)
- Distraction from kernel development

**No, if used as validation tool:**
- External tool for final testing (not primary development)
- Hardware parity validation (not daily development)
- Complementary to our VM (not replacement)

**Recommendation:**
- **Primary**: Our focused VM (Tiger Style compliant, integrated, simple)
- **Validation**: QEMU (hardware parity, final testing)
- **Future**: Real hardware (Framework 13 RISC-V mainboard)

**Result**: Tiger Style development + hardware validation = Best of both worlds

