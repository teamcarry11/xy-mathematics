# Pluto OS Analysis: Zig Kernel for x86

**Date**: 2025-11-13  
**Source**: [Pluto OS GitHub](https://github.com/ZystemOS/pluto)  
**Language**: Zig (96% Zig, 3.8% Assembly)  
**Target**: x86 (i386-freestanding), aarch64 and x64 planned  
**Status**: Active (693 stars, 32 forks)

## Pluto OS Overview

**Architecture**: Component-based kernel (not pure monolithic)  
**Language**: Zig (almost entirely, minimal assembly)  
**Status**: Active development  
**Target**: x86 (i386-freestanding), aarch64 and x64 planned  
**License**: Unknown (need to check)

### Pluto's Goals

1. **Written in Zig as much as possible**: Assembly only where required
2. **Light and performant**: Usable on embedded and desktop CPUs
3. **Modular**: Lightweight and modular design
4. **Easy to port**: Architecture-oblivious, ports implement defined interface
5. **Basic utilities in Zig**: Text editor and shell (filesystem external to kernel)

### Pluto's Architecture: Component-Based

**Key Insight**: Pluto uses a **component-based architecture**, not pure monolithic.

**Component-Based vs Monolithic:**
- **Component-Based**: Kernel organized into independent components/modules
- **Monolithic**: All kernel code in single address space, direct function calls
- **Pluto**: Components communicate through defined interfaces (more modular than pure monolithic)

**Advantages of Component-Based:**
- **Modularity**: Easier to test and maintain individual components
- **Portability**: Architecture-oblivious design (easy to port)
- **Flexibility**: Components can be swapped or replaced
- **Still Fast**: Components communicate directly (no IPC overhead like microkernel)

**Disadvantages:**
- **Complexity**: More abstraction layers than pure monolithic
- **Overhead**: Interface calls (though minimal compared to IPC)

## Applicability to Grain Basin Kernel

### What We Can Learn from Pluto

**1. Zig-First Approach:**
- **Pluto**: 96% Zig, minimal assembly
- **Grain Basin**: Already Zig-first (Tiger Style)
- **Learning**: Study Pluto's Zig patterns, comptime usage, error handling

**2. Architecture Abstraction:**
- **Pluto**: Architecture-oblivious, ports implement interface
- **Grain Basin**: RISC-V native, but can learn abstraction patterns
- **Learning**: How to structure architecture-specific code cleanly

**3. Modular Design:**
- **Pluto**: Component-based, modular
- **Grain Basin**: Can adopt modular structure while maintaining monolithic performance
- **Learning**: How to organize kernel code into clean modules

**4. Build System:**
- **Pluto**: Uses Zig build system (`build.zig`)
- **Grain Basin**: Already using Zig build system
- **Learning**: Study Pluto's build configuration, target handling

**5. Testing Infrastructure:**
- **Pluto**: Unit tests, runtime tests, test modes
- **Grain Basin**: Can adopt similar testing approach
- **Learning**: How to structure kernel tests in Zig

### What's Different

**1. Architecture:**
- **Pluto**: x86 (i386-freestanding), aarch64/x64 planned
- **Grain Basin**: RISC-V64 native (our differentiator)

**2. Design Philosophy:**
- **Pluto**: Component-based (more modular)
- **Grain Basin**: Monolithic (more direct, higher performance)

**3. Goals:**
- **Pluto**: General-purpose, architecture-oblivious
- **Grain Basin**: RISC-V native, non-POSIX, minimal syscall surface

## RISC-V Zig OS Projects Analysis

### From awesome-zig List

**1. `eastonman/zesty-core` - RISC-V OS in Zig**
- **Status**: Unknown (need to check)
- **Learning**: RISC-V-specific Zig patterns
- **Value**: Direct RISC-V experience in Zig

**2. `a1393323447/zcore-os` - RISC-V OS (rCore-OS translated)**
- **Status**: Active (translation of rCore-OS to Zig)
- **Learning**: RISC-V OS structure, rCore-OS patterns
- **Value**: Proven RISC-V OS design in Zig

**3. `ZeeBoppityZagZiggity/ZBZZ.OS` - RISC-V + Zig OS**
- **Status**: Unknown (need to check)
- **Learning**: RISC-V OS patterns
- **Value**: Another RISC-V Zig OS reference

**4. `leecannon/zig-sbi` - RISC-V SBI Wrapper**
- **Status**: Active (Zig wrapper for RISC-V SBI)
- **Learning**: RISC-V SBI (Supervisor Binary Interface) usage
- **Value**: **DIRECTLY APPLICABLE** - SBI is what we need for RISC-V boot
- **Action**: Study this for RISC-V boot code

**5. `kivikakk/daintree` - ARMv8-A/RISC-V Kernel with UEFI**
- **Status**: Active (UEFI bootloader + kernel)
- **Learning**: RISC-V kernel structure, UEFI boot
- **Value**: RISC-V kernel + bootloader patterns

**6. `nmeum/zig-riscv-embedded` - HiFive1 RISC-V Board**
- **Status**: Embedded RISC-V (not full OS)
- **Learning**: RISC-V embedded patterns
- **Value**: RISC-V hardware interaction

**7. `lupyuen/zig-bl602-nuttx` - RISC-V BL602 with NuttX RTOS**
- **Status**: RTOS (not full OS)
- **Learning**: RISC-V RTOS patterns
- **Value**: RISC-V hardware abstraction

## Recommendation: Clone Repos Externally

### Suggested Structure

```
~/github/
├── ZystemOS/
│   └── pluto/              # Component-based Zig kernel (x86)
├── eastonman/
│   └── zesty-core/         # RISC-V OS in Zig
├── a1393323447/
│   └── zcore-os/           # RISC-V OS (rCore-OS translated)
├── leecannon/
│   └── zig-sbi/            # RISC-V SBI wrapper (CRITICAL)
├── kivikakk/
│   └── daintree/           # ARMv8-A/RISC-V kernel with UEFI
└── Andy-Python-Programmer/
    └── aero/               # Monolithic Rust kernel (x86_64)
```

### Why External Cloning

**1. Separation of Concerns:**
- **xy workspace**: Our Grain Basin kernel development
- **External repos**: Reference implementations, learning resources
- **Benefit**: Clean separation, no confusion

**2. Easy Updates:**
- **External repos**: Can pull updates independently
- **xy workspace**: Focused on our implementation
- **Benefit**: Easy to sync reference repos without affecting our work

**3. Multiple Projects:**
- **External repos**: Can study multiple approaches
- **xy workspace**: Single focused implementation
- **Benefit**: Compare approaches without cluttering workspace

**4. Git History:**
- **External repos**: Preserve original git history
- **xy workspace**: Our own git history
- **Benefit**: Can track upstream changes, contribute back if needed

## Priority Repos to Clone

### Critical (Clone First)

**1. `CascadeOS/zig-sbi`** ⭐ **HIGHEST PRIORITY** ⚠️ **UPDATED**
- **Why**: RISC-V SBI wrapper - directly applicable to our VM and boot code
- **Note**: CascadeOS maintains zig-sbi (more active than leecannon/zig-sbi)
- **Learning**: How to use RISC-V SBI (Supervisor Binary Interface)
- **Action**: Integrate into VM for platform services (console, timer, reset)
- **Integration**: Add SBI support to VM ECALL handler

**2. `a1393323447/zcore-os`** ⭐ **HIGH PRIORITY**
- **Why**: Proven RISC-V OS design (rCore-OS translated to Zig)
- **Learning**: RISC-V OS structure, proven patterns
- **Action**: Study RISC-V kernel organization

**3. `ZystemOS/pluto`** ⭐ **HIGH PRIORITY**
- **Why**: Component-based Zig kernel, architecture abstraction
- **Learning**: Zig kernel patterns, modular design, build system
- **Action**: Study component organization, Zig patterns

### High Value (Clone Second)

**4. `eastonman/zesty-core`**
- **Why**: RISC-V OS in Zig
- **Learning**: RISC-V-specific Zig patterns
- **Action**: Study RISC-V implementation details

**5. `kivikakk/daintree`**
- **Why**: RISC-V kernel with UEFI bootloader
- **Learning**: RISC-V boot process, UEFI integration
- **Action**: Study bootloader + kernel integration

**6. `Andy-Python-Programmer/aero`**
- **Why**: Monolithic Rust kernel (already analyzed)
- **Learning**: Monolithic kernel structure
- **Action**: Study module organization (already documented)

### Reference (Clone as Needed)

**7. `ZeeBoppityZagZiggity/ZBZZ.OS`**
- **Why**: Another RISC-V Zig OS
- **Learning**: Alternative RISC-V patterns
- **Action**: Compare approaches

**8. `nmeum/zig-riscv-embedded`**
- **Why**: Embedded RISC-V (HiFive1)
- **Learning**: RISC-V hardware interaction
- **Action**: Study hardware-specific code

## Action Plan

### Immediate Actions

1. **Clone Critical Repos:**
   ```bash
   mkdir -p ~/github/{ZystemOS,CascadeOS,a1393323447,eastonman,kivikakk,Andy-Python-Programmer}
   cd ~/github/ZystemOS && git clone https://github.com/ZystemOS/pluto.git
   cd ~/github/CascadeOS && git clone https://github.com/CascadeOS/zig-sbi.git
   cd ~/github/CascadeOS && git clone https://github.com/CascadeOS/CascadeOS.git
   cd ~/github/a1393323447 && git clone https://github.com/a1393323447/zcore-os.git
   cd ~/github/eastonman && git clone https://github.com/eastonman/zesty-core.git
   cd ~/github/kivikakk && git clone https://github.com/kivikakk/daintree.git
   cd ~/github/Andy-Python-Programmer && git clone https://github.com/Andy-Python-Programmer/aero.git
   ```

2. **Study Priority Order:**
   - **First**: `CascadeOS/zig-sbi` (RISC-V SBI wrapper - integrate into VM)
   - **Second**: `CascadeOS/CascadeOS` (RISC-V64 OS implementation, planned)
   - **Third**: `zcore-os` (Proven RISC-V OS structure)
   - **Fourth**: `pluto` (Zig kernel patterns, component organization)
   - **Fifth**: `zesty-core` (RISC-V Zig patterns)
   - **Sixth**: `daintree` (RISC-V bootloader + kernel)

3. **Document Learnings:**
   - Create analysis docs for each repo (like `aero_analysis.md`)
   - Extract applicable patterns for Grain Basin kernel
   - Document RISC-V-specific learnings

### Integration Strategy

**1. Study, Don't Copy:**
- Learn from these repos
- Adapt patterns for Grain Basin kernel
- Maintain our unique design (RISC-V native, non-POSIX, minimal syscalls)

**2. Focus on RISC-V:**
- Prioritize RISC-V repos (`zig-sbi`, `zcore-os`, `zesty-core`)
- Learn RISC-V-specific patterns
- Adapt x86 repos (`pluto`, `aero`) for RISC-V

**3. Maintain Tiger Style:**
- Study their patterns but maintain our Tiger Style principles
- Explicit allocation, comprehensive assertions, type safety
- Minimal syscall surface, non-POSIX design

## Conclusion

**Pluto OS is valuable** for:
- **Zig-First Approach**: 96% Zig, minimal assembly
- **Component-Based Architecture**: Modular design (can adapt for monolithic)
- **Architecture Abstraction**: Clean portability patterns
- **Build System**: Zig build system usage
- **Testing**: Test infrastructure patterns

**RISC-V Zig OS Projects are critical** for:
- **RISC-V SBI**: `zig-sbi` wrapper (boot code)
- **Proven Patterns**: `zcore-os` (rCore-OS translated)
- **RISC-V Structure**: `zesty-core`, `ZBZZ.OS`
- **Boot Process**: `daintree` (UEFI + kernel)

**Recommendation**: Clone repos externally (`~/github/{username}/{repo}/`), study them, adapt patterns for Grain Basin kernel, maintain our unique RISC-V native, non-POSIX, minimal syscall surface design.

