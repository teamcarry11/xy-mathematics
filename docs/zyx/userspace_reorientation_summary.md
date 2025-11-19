# Userspace Reorientation Summary

**Date**: 2025-01-XX  
**Action**: Infused userspace readiness assessment into Ray envelope and project plan

## Changes Made

### 1. Ray Envelope Updated (`src/ray.zig`)

#### Expedition Data Module
**Before**: Generic Grain expedition description  
**After**: "Grain Basin Userspace Expedition"
- Current status: 40-60% userspace ready
- VM infrastructure: Pure Zig emulator with instruction execution
- Kernel syscalls: All 17 syscalls implemented and tested
- Next phase: VM-kernel integration → RISC-V instruction expansion → Userspace ELF loader → Hello World in 2-3 weeks
- Goal: Run Zig-compiled RISC-V64 programs in VM to verify correctness before Framework 13 deployment

#### Audit/Goals Module
**Before**: Generic audit and goals  
**After**: "Userspace Readiness Goals"
- Current status: Kernel foundation complete, VM infrastructure ready, syscalls tested
- Critical path: VM-kernel integration → RISC-V instruction expansion → Userspace ELF loading → Process spawn implementation
- MVP target: Hello World Zig program running in VM (2-3 weeks)
- Full userspace: Real Zig programs with stdlib (6-8 weeks)
- Vision: RISC-V-first development—write Zig code, test in macOS VM, deploy to Framework 13 with confidence

### 2. TODO List Updated

Added 8 new userspace-focused TODOs:
- ✅ Userspace MVP: VM-kernel integration layer
- ✅ Userspace ELF Loader: Extend loader for userspace programs
- ✅ RISC-V Instruction Expansion: Loads/stores, jumps, branches
- ✅ Process Spawn Implementation: Complete syscall_spawn
- ✅ Minimal stdlib: Create syscall wrappers
- ✅ Hello World Test: End-to-end verification

### 3. Documentation Created

#### `docs/userspace_readiness_assessment.md`
Comprehensive assessment covering:
- What we have (VM, kernel, syscalls, ELF loader)
- What's missing (integration layer, instruction expansion, userspace loader)
- Timeline estimates (MVP: 2-3 weeks, Full: 6-8 weeks)
- Recommended path forward

#### `docs/userspace_roadmap.md`
Detailed roadmap with:
- Phase 1: Basic Userspace Execution (2-3 weeks)
- Phase 2: Real Zig Programs (2-3 weeks)
- Phase 3: Production Features (ongoing)
- Week-by-week breakdown
- Success criteria
- Key files to create/modify

## Project Direction

**New Focus**: Userspace readiness  
**Previous Focus**: Kernel foundation and syscall implementation  
**Rationale**: Kernel foundation is complete (40-60% of userspace goal). Next logical step is to enable running actual userspace programs.

## Next Steps

1. **Week 1**: VM-kernel integration layer
   - Create `src/kernel_vm/integration.zig`
   - Connect VM and BasinKernel
   - Register syscall handler
   - Create execution loop

2. **Week 1-2**: Userspace ELF loader
   - Extend `src/kernel_vm/loader.zig`
   - Add userspace address support
   - Set up stack pointer
   - Handle program arguments

3. **Week 2**: Critical RISC-V instructions
   - Implement loads (LB, LH, LW, LD, LBU, LHU, LWU)
   - Implement stores (SB, SH, SW, SD)
   - Implement jumps (JAL, JALR)

4. **Week 3**: Hello World
   - Minimal stdlib
   - Basic file system stub
   - Compile and run Hello World

## Verification

- ✅ Ray module compiles (`zig test src/ray.zig`)
- ✅ All Ray tests pass (2/2)
- ✅ No lint errors
- ✅ TODO list updated
- ✅ Documentation created

## References

- `src/ray.zig` - Updated Ray envelope
- `docs/userspace_readiness_assessment.md` - Detailed assessment
- `docs/userspace_roadmap.md` - Detailed roadmap
- `docs/userspace_reorientation_summary.md` - This document

