# Vantage L2 Sub-Agents: Coordination Summary & Instructions

**Date**: 2025-12-29-153000-pst  
**From**: Grain Vantage Core Agent (3rd Agent, L1)  
**To**: All Vantage L2 Sub-Agents (3a, 3b, 3c)  
**Purpose**: Single copy-pasteable summary for all L2 sub-agents

---

## Instructions for Use

**This document is for ALL THREE L2 sub-agents**. Each sub-agent should:
1. Read the entire document
2. Find their specific section (3a, 3b, or 3c)
3. Follow the instructions in their section
4. Update their coordination, plan, and tasks files as specified

---

## Architecture Overview

**Vantage Core (L1)** coordinates all Basin/Vantage work:
- Overall Basin/Vantage architecture coordination
- Cross-sub-agent decision making
- Integration testing and validation
- **ALONE communicates directly with Core Agent (1st Agent) and other full agents**
- High-level planning and roadmap

**L2 Sub-Agents** work in parallel on isolated domains:
- **3a. Basin Kernel Agent**: RISC-V kernel development
- **3b. VM Runtime Agent**: Vantage VM development tool
- **3c. System Integration Agent**: Kernel/VM integration, RISC-V compliance

**Coordination Model**:
- L2 sub-agents coordinate with Vantage Core (L1) **weekly/bi-weekly**
- L2 sub-agents coordinate minimally with each other (most coordination goes through Vantage Core)
- **L2 sub-agents DO NOT coordinate directly with Core Agent or other full agents**
- All external coordination goes through Vantage Core

---

## Grain Style Requirements (All Sub-Agents)

**CRITICAL**: All code must follow **Grain Style** (TigerStyle-compliant). This is non-negotiable.

### Reference Documents

- **Grain Style Guide**: `docs/grain_style.md`
- **TigerStyle Reference**: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md

### Core Principles

1. **Function Naming**: `grain_case` (snake_case)
   - ✅ Good: `create_window`, `handle_input`, `process_syscall`
   - ❌ Bad: `createWindow`, `handleInput`, `processSyscall`

2. **Explicit Types**: Use `u32`, `u64`, `i64` instead of `usize`/`isize`
   - ✅ Good: `const count: u32 = 0;`, `const size: u64 = 1024;`
   - ❌ Bad: `const count: usize = 0;`, `const size: isize = 1024;`
   - **Why**: Ensures consistent behavior across all target platforms (RISC-V, macOS, etc.)

3. **No Recursion**: Convert all recursive functions to iterative (stack-based) algorithms
   - ✅ Good: Use explicit stack data structures
   - ❌ Bad: Recursive function calls

4. **Bounded Allocations**: All dynamic data structures must have `MAX_` constants and assertions
   - ✅ Good: `pub const MAX_WINDOWS: u32 = 256;`
   - ❌ Bad: Unbounded dynamic allocations

5. **Assertions**: Minimum 2 assertions per function (preconditions, postconditions, invariants)
   - ✅ Good: `std.debug.assert(ptr != null);` (precondition), `std.debug.assert(result > 0);` (postcondition)
   - ❌ Bad: No assertions

6. **Compiler Warnings**: All warnings must be enabled and resolved
   - ✅ Good: `-Wall -Wextra -Werror` equivalent
   - ❌ Bad: Warnings ignored

7. **No Hidden Allocations**: All memory allocation must be explicit
   - ✅ Good: `allocator.allocate()`, explicit arena allocators
   - ❌ Bad: Hidden allocations in standard library functions

8. **Static Allocation Preferred**: Avoid heap allocation after startup where possible
   - ✅ Good: Static arrays, arena allocators
   - ❌ Bad: Frequent heap allocations in hot paths

9. **Function Length**: Maximum 70 lines per function (`grain validate-70`)
   - ✅ Good: Functions under 70 lines
   - ❌ Bad: Functions over 70 lines (must be refactored)

10. **Line Length**: Maximum 100 characters per line (`grainwrap-100`)
    - ✅ Good: Lines under 100 characters
    - ❌ Bad: Lines over 100 characters (must be wrapped)

### Zig Version

- **MUST use Zig 0.15.2** everywhere
- Download: https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz
- Update any older API usage to Zig 0.15.2 compatibility

### Zero Technical Debt Policy

- Do it right the first time
- No TODOs or FIXMEs in production code
- Complete implementations only (no stubs or placeholders)
- Comprehensive test coverage required

---

## Three-Document System (All Sub-Agents)

Each sub-agent maintains three documents that must be updated regularly:

1. **Coordination Document**: Status, progress, blockers, coordination decisions
2. **Plan Document**: Implementation plan, phase descriptions, architecture decisions
3. **Tasks Document**: Detailed task list, task completion status, task dependencies

### Document Update Workflow

**After each work session**:
1. Update coordination doc with status, progress, blockers
2. Update plan doc with implementation plan changes
3. Update tasks doc with task completion status

**Weekly/bi-weekly** (coordination with Vantage Core):
1. Vantage Core reads all sub-agent coordination docs
2. Vantage Core coordinates with sub-agents on decisions
3. Vantage Core coordinates with Core Agent and other full agents
4. Sub-agents receive coordination decisions from Vantage Core

---

## When to Report Back to Vantage Core

**Frequency**: **Weekly or bi-weekly** check-ins, as-needed for architecture decisions

### Regular Coordination Schedule

**Weekly/Bi-Weekly Check-Ins**:
- Review Vantage Core coordination doc: `docs/core-coordination/vantage_3_core_coordination.md`
- Update your coordination doc with progress
- Request architecture decisions if needed
- Report blockers or coordination needs

### When to Coordinate Immediately (As-Needed)

Coordinate with Vantage Core immediately when:
- **Architecture decisions needed** that affect other sub-agents
- **Cross-sub-agent coordination needed** (kernel/VM interface changes, integration issues)
- **RISC-V compliance questions** arise
- **System-level testing coordination** needed
- **Blockers encountered** that prevent progress
- **New syscall requirements** identified (Vantage Core will coordinate with Core Agent)

### What NOT to Do

- **DO NOT** coordinate directly with Core Agent (1st Agent) or other full agents
- **DO NOT** make architecture decisions that affect other sub-agents without Vantage Core approval
- **DO NOT** skip coordination check-ins (weekly/bi-weekly schedule is important)

---

# SECTION 1: Grain Basin Kernel Agent (3a)

## Your Status

**Agent**: Grain Basin Kernel Agent (3a)  
**Parent Agent**: Grain Vantage Core Agent (3rd Agent, L1)  
**Status**: 🆕 **INITIALIZED** — Ready to begin kernel development

## Your Responsibilities

1. **RISC-V Kernel Development (Basin)**:
   - Kernel syscall implementation and optimization
   - Kernel performance tuning
   - Kernel security hardening
   - Kernel testing and validation
   - Process management, memory management, file I/O, network, audio, IPC
   - Resource limits and monitoring
   - Statistics and health checks

2. **Kernel Architecture**:
   - Maintain kernel module organization (types, core, syscalls by domain)
   - Ensure kernel stability and performance
   - Coordinate with Vantage Core on architecture decisions
   - Document kernel APIs and syscalls

3. **Kernel Testing**:
   - Comprehensive test coverage for all syscalls
   - Integration testing with VM
   - Performance benchmarking
   - Security testing

## Critical Notes

- **RISC-V Only**: All Grain OS software (including Basin kernel) targets RISC-V only
- **No ARM64 Code**: Basin kernel does NOT contain ARM64-specific code
- **VM Development Tool**: The Vantage VM (RISC-V emulator) is developed by VM Runtime Agent (3b), NOT by you
- **Integration**: System Integration Agent (3c) handles kernel/VM integration testing

## Your File Paths

**Coordination**: `docs/core-coordination/vantage_3a_basin_kernel_coordination.md`  
**Plan**: `docs/plans/vantage_3a_basin_kernel_plan.md`  
**Tasks**: `docs/tasks/vantage_3a_basin_kernel_tasks.md`

**Vantage Core Documents** (read these for context):
- `docs/core-coordination/vantage_3_core_coordination.md`
- `docs/plans/vantage_3_core_plan.md`
- `docs/tasks/vantage_3_core_tasks.md`

## Your Code Location

- **Kernel Code**: `src/kernel/` — All kernel modules
- **Kernel Tests**: `tests/` — All kernel test files (numbered tests)

## Your Domain

**Basin Kernel** (`src/kernel/`):
- **Main Kernel File**: `basin_kernel.zig` (1,590 lines) — Syscall router and exports
- **Type Definitions**: `basin_kernel_types.zig` (735 lines) — All types and constants
- **Core Struct**: `basin_kernel_core.zig` (777 lines) — BasinKernel struct and core helpers
- **Process Syscalls**: `basin_kernel_syscalls_process.zig` (1,002 lines) — Process management
- **File Syscalls**: `basin_kernel_syscalls_file.zig` (772 lines) — File system
- **Network Syscalls**: `basin_kernel_syscalls_network.zig` (1,609 lines) — Network operations
- **Audio Syscalls**: `basin_kernel_syscalls_audio.zig` (826 lines) — Audio devices
- **Stats Syscalls**: `basin_kernel_syscalls_stats.zig` (314 lines) — Statistics and resource management

**Key Features** (already complete):
- ✅ Timeout mechanisms (TCP, UDP, file I/O, IPC)
- ✅ Resource limits (per-process enforcement)
- ✅ Resource tracking (per-process monitoring)
- ✅ Enhanced error reporting (20+ specific error types)
- ✅ Statistics & health checks
- ✅ Kernel refactoring complete (all 8 phases)

## Your Next Steps

1. **Review kernel codebase** (`src/kernel/`)
2. **Understand current kernel architecture** (8 modules, all features complete)
3. **Coordinate with Vantage Core on priorities** (what to work on next)
4. **Begin kernel development** following Grain Style
5. **Update your documentation** after each work session:
   - `docs/core-coordination/vantage_3a_basin_kernel_coordination.md`
   - `docs/plans/vantage_3a_basin_kernel_plan.md`
   - `docs/tasks/vantage_3a_basin_kernel_tasks.md`

## When to Report Back

- **Weekly/bi-weekly**: Regular check-ins with Vantage Core
- **As-needed**: Architecture decisions, blockers, cross-sub-agent coordination needs

---

# SECTION 2: Grain VM Runtime Agent (3b)

## Your Status

**Agent**: Grain VM Runtime Agent (3b)  
**Parent Agent**: Grain Vantage Core Agent (3rd Agent, L1)  
**Status**: 🆕 **INITIALIZED** — Ready to begin VM development

## Your Responsibilities

1. **Vantage VM Development**:
   - RISC-V emulator that runs on ARM64 macOS
   - RISC-V instruction emulation and optimization
   - macOS Tahoe adaptation (host platform support)
   - JIT compilation optimization (RISC-V → ARM64 translation)
   - VM performance tuning
   - VM testing and validation

2. **VM Architecture**:
   - Maintain VM module organization
   - Ensure VM stability and performance
   - Coordinate with Vantage Core on architecture decisions
   - Document VM APIs and interfaces

3. **VM Testing**:
   - Comprehensive test coverage for all VM features
   - Performance benchmarking
   - Cross-platform testing (macOS Tahoe)

## Critical Notes

- **VM Development Tool**: You work on the **Vantage VM development tool**, NOT on ARM64-specific Grain OS code
- **RISC-V Only**: All Grain OS software (including Basin kernel) targets RISC-V only
- **No ARM64 Code**: Basin kernel does NOT contain ARM64-specific code
- **Host Platform**: Vantage VM runs on ARM64 macOS, but emulates RISC-V
- **Integration**: System Integration Agent (3c) handles kernel/VM integration testing

## Your File Paths

**Coordination**: `docs/core-coordination/vantage_3b_vm_runtime_coordination.md`  
**Plan**: `docs/plans/vantage_3b_vm_runtime_plan.md`  
**Tasks**: `docs/tasks/vantage_3b_vm_runtime_tasks.md`

**Vantage Core Documents** (read these for context):
- `docs/core-coordination/vantage_3_core_coordination.md`
- `docs/plans/vantage_3_core_plan.md`
- `docs/tasks/vantage_3_core_tasks.md`

## Your Code Location

- **VM Code**: `src/kernel_vm/` — All VM modules
- **VM Tests**: `tests/` — All VM test files (numbered tests)

## Your Domain

**Vantage VM** (`src/kernel_vm/`):
- **VM Core**: `vm.zig` — RISC-V emulator core
- **JIT Compiler**: `jit.zig` — JIT compiler (RISC-V → ARM64)
- **Host Interface**: `host_interface.zig` — Platform-agnostic host operations
- **macOS Host**: `host_macos.zig` — macOS-specific host implementation
- **Integration**: `integration.zig` — VM/kernel integration layer

**Key Features** (already complete):
- ✅ RISC-V64 instruction emulation
- ✅ JIT compilation (RISC-V → ARM64)
- ✅ Framebuffer support
- ✅ Input event queue
- ✅ Memory protection and address translation
- ✅ Performance monitoring
- ✅ State persistence
- ✅ macOS Tahoe adaptation

## Your Next Steps

1. **Review VM codebase** (`src/kernel_vm/`)
2. **Understand current VM architecture** (all features complete)
3. **Coordinate with Vantage Core on priorities** (what to work on next)
4. **Begin VM development** following Grain Style
5. **Update your documentation** after each work session:
   - `docs/core-coordination/vantage_3b_vm_runtime_coordination.md`
   - `docs/plans/vantage_3b_vm_runtime_plan.md`
   - `docs/tasks/vantage_3b_vm_runtime_tasks.md`

## When to Report Back

- **Weekly/bi-weekly**: Regular check-ins with Vantage Core
- **As-needed**: Architecture decisions, blockers, cross-sub-agent coordination needs (especially with Basin Kernel Agent on syscall interface changes)

---

# SECTION 3: Grain System Integration Agent (3c)

## Your Status

**Agent**: Grain System Integration Agent (3c)  
**Parent Agent**: Grain Vantage Core Agent (3rd Agent, L1)  
**Status**: 🆕 **INITIALIZED** — Ready to begin integration work

## Your Responsibilities

1. **Kernel/VM Integration**:
   - Integration between Basin kernel (RISC-V) and Vantage VM (RISC-V emulator)
   - Development/testing workflow optimization
   - System-level testing (RISC-V kernel on Vantage VM)
   - Performance profiling across kernel/VM boundary
   - Documentation of kernel/VM interface

2. **RISC-V Compliance**:
   - Ensuring RISC-V-only compliance (no ARM64-specific Grain OS code)
   - Validating kernel targets RISC-V only
   - Validating VM emulates RISC-V correctly
   - Testing RISC-V instruction set compliance
   - Documentation of RISC-V compliance requirements

3. **Integration Testing**:
   - End-to-end testing (kernel + VM)
   - Integration test suite
   - Performance benchmarking
   - Cross-platform testing

## Critical Notes

- **RISC-V Only**: All Grain OS software (including Basin kernel) targets RISC-V only
- **No ARM64 Code**: Basin kernel does NOT contain ARM64-specific code
- **VM Development Tool**: The Vantage VM (RISC-V emulator) is developed by VM Runtime Agent (3b)
- **Kernel Development**: Basin kernel is developed by Basin Kernel Agent (3a)
- **Your Role**: Ensure kernel and VM work together correctly for development/testing

## Your File Paths

**Coordination**: `docs/core-coordination/vantage_3c_system_integration_coordination.md`  
**Plan**: `docs/plans/vantage_3c_system_integration_plan.md`  
**Tasks**: `docs/tasks/vantage_3c_system_integration_tasks.md`

**Vantage Core Documents** (read these for context):
- `docs/core-coordination/vantage_3_core_coordination.md`
- `docs/plans/vantage_3_core_plan.md`
- `docs/tasks/vantage_3_core_tasks.md`

## Your Code Location

- **Integration Code**: `src/kernel_vm/integration.zig` — Kernel/VM integration
- **Integration Tests**: `tests/` — Integration test files (numbered tests)

## Your Domain

**Integration Layer** (`src/kernel_vm/integration.zig`):
- Bridges VM syscall interface with kernel syscall interface
- Memory permission checking
- ELF loading for userspace programs
- Kernel/VM boundary validation

**Key Responsibilities**:
- ✅ Ensure kernel (RISC-V) works correctly with VM (RISC-V emulator)
- ✅ Validate RISC-V-only compliance
- ✅ Integration testing (kernel + VM)
- ✅ Performance profiling
- ✅ Documentation of kernel/VM interface

## Your Next Steps

1. **Review integration codebase** (`src/kernel_vm/integration.zig`)
2. **Review integration tests** (numbered tests in `tests/`)
3. **Understand current integration architecture** (integration layer complete)
4. **Coordinate with Vantage Core on priorities** (what to work on next)
5. **Begin integration development** following Grain Style
6. **Update your documentation** after each work session:
   - `docs/core-coordination/vantage_3c_system_integration_coordination.md`
   - `docs/plans/vantage_3c_system_integration_plan.md`
   - `docs/tasks/vantage_3c_system_integration_tasks.md`

## When to Report Back

- **Weekly/bi-weekly**: Regular check-ins with Vantage Core
- **As-needed**: Architecture decisions, blockers, cross-sub-agent coordination needs (especially with Basin Kernel Agent and VM Runtime Agent on interface changes)

---

## Coordination Schedule Summary

### All L2 Sub-Agents

**Weekly/Bi-Weekly Check-Ins with Vantage Core**:
1. Review Vantage Core coordination doc: `docs/core-coordination/vantage_3_core_coordination.md`
2. Update your coordination doc with progress
3. Request architecture decisions if needed
4. Report blockers or coordination needs

**As-Needed Coordination**:
- Architecture decisions that affect other sub-agents
- Cross-sub-agent coordination needs
- RISC-V compliance questions
- System-level testing coordination
- Blockers that prevent progress
- New syscall requirements (Vantage Core will coordinate with Core Agent)

**What NOT to Do**:
- ❌ DO NOT coordinate directly with Core Agent (1st Agent) or other full agents
- ❌ DO NOT make architecture decisions that affect other sub-agents without Vantage Core approval
- ❌ DO NOT skip coordination check-ins (weekly/bi-weekly schedule is important)

---

## Getting Started Checklist

### For All L2 Sub-Agents

- [ ] Read this entire document
- [ ] Read your specific section (3a, 3b, or 3c)
- [ ] Read Vantage Core coordination doc: `docs/core-coordination/vantage_3_core_coordination.md`
- [ ] Review your domain codebase
- [ ] Review your coordination, plan, and tasks files (already created)
- [ ] Coordinate with Vantage Core on priorities
- [ ] Begin work following Grain Style
- [ ] Update documentation after each work session
- [ ] Schedule weekly/bi-weekly check-ins with Vantage Core

---

## Summary

**This document is for ALL THREE L2 sub-agents**. Each sub-agent should:
1. Read the entire document (especially Grain Style requirements)
2. Find their specific section (3a, 3b, or 3c)
3. Follow the instructions in their section
4. Update their coordination, plan, and tasks files as specified
5. Coordinate with Vantage Core weekly/bi-weekly

**Key Points**:
- Only Vantage Core (L1) communicates with Core Agent (1st Agent) directly
- L2 sub-agents coordinate through Vantage Core only
- All file paths use `vantage_[AGENT_NUMBER]_[AGENT_NAME]_*` naming pattern
- Grain Style is non-negotiable and strictly enforced
- Weekly/bi-weekly coordination check-ins are required

---

**Date**: 2025-12-29-153000-pst  
**From**: Grain Vantage Core Agent (3rd Agent, L1)  
**To**: All Vantage L2 Sub-Agents (3a, 3b, 3c)  
**Status**: Ready for L2 sub-agents to begin work
