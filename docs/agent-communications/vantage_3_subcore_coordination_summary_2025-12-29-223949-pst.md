# Vantage 3 Subcore Agent: Coordination Summary for L2 Sub-Agents

**Date**: 2025-12-29-223949-pst  
**From**: Grain Vantage 3 Subcore Agent (3rd Agent, L1)  
**To**: All Vantage L2 Sub-Agents (3a, 3b, 3c)  
**Purpose**: Comprehensive coordination summary for copy-paste to each sub-agent

---

## Instructions for Use

**This document is for ALL THREE L2 sub-agents**. Each sub-agent should:
1. Read the entire document
2. Find their specific section (3a, 3b, or 3c)
3. Follow the instructions in their section
4. Update their coordination, plan, and tasks files as specified
5. Continue as you and they best recommend, given the context

---

## Previous Next Steps Status

### Completed from Previous Coordination (2025-12-29-214643-pst)

**3a. Basin Kernel Agent**:
- ✅ **COMPLETE**: Began kernel development work (performance optimization priority)
- ✅ **COMPLETE**: Created syscall performance profiler infrastructure
  - Profiler module: `src/kernel/syscall_performance_profiler.zig`
  - Kernel integration: Added to `BasinKernel` struct and syscall router
  - Test suite: `tests/143_syscall_performance_profiler_test.zig`
  - Documentation: `docs/kernel/syscall_performance_profiler_usage.md`
  - All tests pass, Grain Style compliant, zero technical debt
- ✅ **COMPLETE**: Profiler ready for use (disabled by default, zero overhead when not in use)

**3b. VM Runtime Agent**:
- ✅ **COMPLETE**: Priorities confirmed from Vantage 3 Subcore
- ⏳ **IN PROGRESS**: Phase 1 codebase review (~30% complete, ~70% remaining)
  - Reviewed: `vm.zig` core (in progress), `jit.zig` JIT compiler (in progress), `integration.zig` (in progress)
  - Remaining: Complete review of all 37 VM modules, document architecture, identify improvements

**3c. System Integration Agent**:
- ✅ **COMPLETE**: Began RISC-V compliance validation (Priority 1, HIGH)
- ✅ **COMPLETE**: Created RISC-V compliance test suite
  - Test file: `tests/riscv_compliance_validation_test.zig`
  - 10+ comprehensive test cases covering RISC-V instruction set compliance
  - Tests for: x0 register, ADDI, ADD, LUI, JAL, BEQ, instruction alignment, memory alignment, calling convention, instruction encoding, memory model
  - Follows Grain Style (explicit u32/u64 types, comprehensive assertions, bounded operations)
- ⚠️ **COORDINATION NEEDED**: Found AArch64 code in kernel (contradicts "RISC-V only" requirement)
  - Files: `src/kernel/platform_aarch64.zig`, `src/kernel/main_aarch64.zig`, `src/kernel/entry_aarch64.S`
  - Build target: `build.zig` has `kernel-aarch64` build target
  - **Question**: Should AArch64 code be removed per "RISC-V only" requirement, or has requirement changed?

---

## New Next Steps (This Coordination Plan)

**All Sub-Agents**: Continue implementation work on priorities, following Grain Style strictly.

**3a. Basin Kernel Agent**: Continue kernel performance optimization (collect performance data, identify hot paths, optimize syscall handlers).

**3b. VM Runtime Agent**: Continue Phase 1 codebase review, complete remaining ~70%, then proceed to Phase 2 (VM Maintenance and Stability).

**3c. System Integration Agent**: **IMMEDIATE**: Coordinate with Vantage 3 Subcore on AArch64 code finding, then continue RISC-V compliance validation.

---

## Grain Style Requirements (CRITICAL - ALL SUB-AGENTS)

**ALL code must follow Grain Style** (TigerStyle-compliant). This is non-negotiable.

### Reference Documents

- **Grain Style Guide**: `docs/grain_style.md` (or `~/xy-mathematics/docs/grain_style.md`)
- **TigerStyle Reference**: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md

### Core Principles (ALL 10 MUST BE FOLLOWED)

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
   - **ENFORCEMENT**: Use `grain validate-70` to check function length

10. **Line Length**: Maximum 100 characters per line (`grainwrap-100`)
    - ✅ Good: Lines under 100 characters
    - ❌ Bad: Lines over 100 characters (must be wrapped)
    - **ENFORCEMENT**: Use `grainwrap-100` to check line length

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

## Three-Document System (ALL SUB-AGENTS)

Each sub-agent maintains three documents that must be updated regularly:

1. **Coordination Document**: Status, progress, blockers, coordination decisions
2. **Plan Document**: Implementation plan, phase descriptions, architecture decisions
3. **Tasks Document**: Detailed task list, task completion status, task dependencies

### Document Update Workflow

**After each work session**:
1. Update coordination doc with status, progress, blockers
2. Update plan doc with implementation plan changes
3. Update tasks doc with task completion status

**Weekly/bi-weekly** (coordination with Vantage 3 Subcore):
1. Vantage 3 Subcore reads all sub-agent coordination docs
2. Vantage 3 Subcore coordinates with sub-agents on decisions
3. Vantage 3 Subcore coordinates with Core Agent and other full agents
4. Sub-agents receive coordination decisions from Vantage 3 Subcore

### General Summary Updates

**When you're done with the next phase of implementation**, update your sub-agent system-integration docs and plans and tasks, informing Vantage 3 Subcore Agent how to update the general Grain OS summary:
- `~/xy-mathematics/docs/plan.md` — General project plan summary
- `~/xy-mathematics/docs/tasks.md` — General project tasks summary

**Vantage 3 Subcore will update** these general summaries based on your sub-agent documentation updates.

---

## When to Coordinate with Vantage 3 Subcore

**Frequency**: **Weekly or bi-weekly** check-ins, as-needed for architecture decisions

### Regular Coordination Schedule

**Weekly/Bi-Weekly Check-Ins**:
- Review Vantage 3 Subcore coordination doc: `docs/core-coordination/vantage_3_subcore_coordination.md`
- Update your coordination doc with progress
- Request architecture decisions if needed
- Report blockers or coordination needs

### When to Coordinate Immediately (As-Needed)

Coordinate with Vantage 3 Subcore immediately when:
- **Architecture decisions needed** that affect other sub-agents
- **Cross-sub-agent coordination needed** (kernel/VM interface changes, integration issues)
- **RISC-V compliance questions** arise
- **System-level testing coordination** needed
- **Blockers encountered** that prevent progress
- **New syscall requirements** identified (Vantage 3 Subcore will coordinate with Core Agent)
- **Critical findings that contradict stated requirements** (e.g., AArch64 code finding)

### What NOT to Do

- **DO NOT** coordinate directly with Core Agent (1st Agent) or other full agents
- **DO NOT** make architecture decisions that affect other sub-agents without Vantage 3 Subcore approval
- **DO NOT** skip coordination check-ins (weekly/bi-weekly schedule is important)

---

## Testing Requirements (ALL SUB-AGENTS)

**CRITICAL**: All tests must pass before merging any code.

**Requirements**:
- All existing tests must pass
- All new tests must pass
- All integration tests must pass
- All agent-specific tests must pass
- All API contract tests must pass

**Test Coverage**:
- Comprehensive test coverage for all new code
- Edge case testing
- Error handling testing
- Integration testing (where applicable)
- Performance testing (where applicable)

**Test Validation**:
- Run all tests before committing
- Fix any failing tests immediately
- Document test coverage
- Coordinate with Vantage 3 Subcore if test failures indicate architecture issues

**Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement your API contracts.**

---

## Integration Coordination (ALL SUB-AGENTS)

**Let us know when you need to check in with me about upcoming integration steps via Vantage 3 Subcore and core-coordination generally with the other agents so that we prevent accidental conflicts.**

### Cross-Sub-Agent Coordination

**3a (Basin Kernel) ↔ 3b (VM Runtime)**:
- Coordinate on syscall interface changes
- Coordinate on VM/kernel boundary optimizations
- Most coordination goes through Vantage 3 Subcore

**3a (Basin Kernel) ↔ 3c (System Integration)**:
- Coordinate on integration testing needs
- Coordinate on RISC-V compliance validation
- Most coordination goes through Vantage 3 Subcore

**3b (VM Runtime) ↔ 3c (System Integration)**:
- Coordinate on VM/kernel integration testing
- Coordinate on RISC-V compliance validation
- Most coordination goes through Vantage 3 Subcore

### External Coordination

**All external coordination goes through Vantage 3 Subcore**:
- Core Agent (1st Agent) coordination
- Other full agents coordination
- New syscall requirements
- Architecture decisions affecting other agents

---

# SECTION 1: Grain Basin Kernel Agent (3a)

## Your Status

**Agent**: Grain Basin Kernel Agent (3a)  
**Parent Agent**: Grain Vantage 3 Subcore Agent (3rd Agent, L1)  
**Status**: ✅ **PROFILER INFRASTRUCTURE COMPLETE** — Ready for performance data collection and optimization

## Previous Next Steps Status

**Completed**:
- ✅ Created syscall performance profiler infrastructure
  - Profiler module: `src/kernel/syscall_performance_profiler.zig`
  - Kernel integration: Added to `BasinKernel` struct and syscall router
  - Test suite: `tests/143_syscall_performance_profiler_test.zig`
  - Documentation: `docs/kernel/syscall_performance_profiler_usage.md`
  - All tests pass, Grain Style compliant, zero technical debt
- ✅ Profiler ready for use (disabled by default, zero overhead when not in use)

## New Next Steps

**Immediate Priorities**:

1. **Performance Data Collection** (HIGH priority, NEXT STEP)
   - Enable profiler in test scenarios
   - Run comprehensive syscall benchmarks
   - Collect performance data for all syscalls
   - Identify hot paths (most frequently called syscalls)
   - Identify slow paths (syscalls with highest execution time)

2. **Performance Analysis** (HIGH priority, after data collection)
   - Analyze profiler data to identify optimization opportunities
   - Profile individual syscall handlers for bottlenecks
   - Identify common syscall patterns
   - Document performance characteristics

3. **Performance Optimization** (HIGH priority, after analysis)
   - Optimize hot path syscalls
   - Optimize slow path syscalls
   - Improve syscall handler efficiency
   - Reduce syscall overhead
   - Benchmark performance improvements

4. **Kernel Security Hardening** (MEDIUM priority, ongoing)
   - Additional input validation review
   - Security audit of syscall handlers
   - Capability-based access control enhancements
   - Memory protection improvements
   - Security testing

## Your Instructions

**Continue as you and they best recommend, given the context.**

**Remember to follow Grain Style** (`~/xy-mathematics/docs/grain_style.md`) with:
- `grain_case` function names
- All strict rules with all compiler warnings turned on
- **Specifically enforce `grainwrap-100` and `grain validate-70`**
- Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms

**Continue the next phase of implementation** and when you're done update your sub-agent system-integration docs and plans and tasks, informing Vantage 3 Subcore Agent how to update the general Grain OS summary `~/xy-mathematics/docs/plan.md` and `~/xy-mathematics/docs/tasks.md` in thinking.

**Let us know when you need to check in with me about upcoming integration steps via Vantage 3 Subcore and core-coordination generally with the other agents so that we prevent accidental conflicts.**

**Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement your API contracts.**

## Your File Paths

**Coordination**: `docs/core-coordination/vantage_3a_basin_kernel_coordination.md`  
**Plan**: `docs/plans/vantage_3a_basin_kernel_plan.md`  
**Tasks**: `docs/tasks/vantage_3a_basin_kernel_tasks.md`

**Vantage 3 Subcore Documents** (read these for context):
- `docs/core-coordination/vantage_3_subcore_coordination.md`
- `docs/plans/vantage_3_subcore_plan.md`
- `docs/tasks/vantage_3_subcore_tasks.md`

**Coordination Plan**: `docs/agent-communications/vantage_3_subcore_coordination_plan_2025-12-29-223949-pst.md`

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
- **Profiler**: `syscall_performance_profiler.zig` — Performance profiling infrastructure

**Key Features** (already complete):
- ✅ Timeout mechanisms (TCP, UDP, file I/O, IPC)
- ✅ Resource limits (per-process enforcement)
- ✅ Resource tracking (per-process monitoring)
- ✅ Enhanced error reporting (20+ specific error types)
- ✅ Statistics & health checks
- ✅ Kernel refactoring complete (all 8 phases)
- ✅ Syscall performance profiler infrastructure

## When to Report Back

- **Weekly/bi-weekly**: Regular check-ins with Vantage 3 Subcore
- **As-needed**: Architecture decisions, blockers, cross-sub-agent coordination needs

---

# SECTION 2: Grain VM Runtime Agent (3b)

## Your Status

**Agent**: Grain VM Runtime Agent (3b)  
**Parent Agent**: Grain Vantage 3 Subcore Agent (3rd Agent, L1)  
**Status**: ⏳ **PHASE 1 IN PROGRESS** — Codebase review ~30% complete, ~70% remaining

## Previous Next Steps Status

**Completed**:
- ✅ Priorities confirmed from Vantage 3 Subcore
- ⏳ **IN PROGRESS**: Phase 1 codebase review (~30% complete, ~70% remaining)
  - Reviewed: `vm.zig` core (in progress), `jit.zig` JIT compiler (in progress), `integration.zig` (in progress)
  - Remaining: Complete review of all 37 VM modules, document architecture, identify improvements

## New Next Steps

**Immediate Priorities**:

1. **Complete Phase 1: VM Codebase Review** (HIGH priority, IN PROGRESS)
   - Finish reviewing all VM modules (37 total files, ~70% remaining)
   - Complete review of `vm.zig` core emulator (3,817 lines)
   - Complete review of `jit.zig` JIT compiler (2,228 lines)
   - Complete review of `integration.zig` kernel integration (1,241 lines)
   - Review remaining modules: `host_interface.zig`, `host_macos.zig`, statistics modules, debugging modules, advanced features
   - Document architecture and module dependencies
   - Identify improvement opportunities
   - Complete codebase review notes
   - Coordinate with Vantage 3 Subcore on findings

2. **Phase 2: VM Maintenance and Stability** (HIGH priority, after Phase 1)
   - Monitor test failures and fix issues
   - Ensure all code follows Grain Style (grainwrap-100, grain validate-70)
   - Review and refactor code that doesn't follow Grain Style
   - Keep documentation up to date
   - Maintain VM stability and correctness

3. **Phase 3: JIT Compilation Optimization** (MEDIUM priority, after Phase 2)
   - Analyze current JIT implementation
   - Optimize hot path detection
   - Improve code generation quality
   - Benchmark JIT vs interpreter performance
   - Coordinate with Vantage 3 Subcore on performance goals

4. **Phase 6: VM Testing and Validation** (ONGOING priority)
   - Maintain comprehensive test coverage
   - Add tests for uncovered code paths
   - Add integration tests with Basin kernel
   - Validate RISC-V instruction emulation correctness
   - Ensure all tests pass

## Your Instructions

**Continue as you and they best recommend, given the context.**

**Remember to follow Grain Style** (`~/xy-mathematics/docs/grain_style.md`) with:
- `grain_case` function names
- All strict rules with all compiler warnings turned on
- **Specifically enforce `grainwrap-100` and `grain validate-70`**
- Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms

**Continue the next phase of implementation** and when you're done update your sub-agent system-integration docs and plans and tasks, informing Vantage 3 Subcore Agent how to update the general Grain OS summary `~/xy-mathematics/docs/plan.md` and `~/xy-mathematics/docs/tasks.md` in thinking.

**Let us know when you need to check in with me about upcoming integration steps via Vantage 3 Subcore and core-coordination generally with the other agents so that we prevent accidental conflicts.**

**Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement your API contracts.**

## Your File Paths

**Coordination**: `docs/core-coordination/vantage_3b_vm_runtime_coordination.md`  
**Plan**: `docs/plans/vantage_3b_vm_runtime_plan.md`  
**Tasks**: `docs/tasks/vantage_3b_vm_runtime_tasks.md`

**Vantage 3 Subcore Documents** (read these for context):
- `docs/core-coordination/vantage_3_subcore_coordination.md`
- `docs/plans/vantage_3_subcore_plan.md`
- `docs/tasks/vantage_3_subcore_tasks.md`

**Coordination Plan**: `docs/agent-communications/vantage_3_subcore_coordination_plan_2025-12-29-223949-pst.md`

## Your Code Location

- **VM Code**: `src/kernel_vm/` — All VM modules
- **VM Tests**: `tests/` — All VM test files (numbered tests)

## Your Domain

**Vantage VM** (`src/kernel_vm/`):
- **VM Core**: `vm.zig` (3,817 lines) — RISC-V emulator core
- **JIT Compiler**: `jit.zig` (2,228 lines) — JIT compiler (RISC-V → ARM64)
- **Host Interface**: `host_interface.zig` — Platform-agnostic host operations
- **macOS Host**: `host_macos.zig` — macOS-specific host implementation
- **Integration**: `integration.zig` (1,241 lines) — VM/kernel integration layer
- **Total**: 37 VM modules

**Key Features** (already complete):
- ✅ RISC-V64 instruction emulation
- ✅ JIT compilation (RISC-V → ARM64)
- ✅ Framebuffer support
- ✅ Input event queue
- ✅ Memory protection and address translation
- ✅ Performance monitoring
- ✅ State persistence
- ✅ macOS Tahoe adaptation
- ✅ Comprehensive statistics and debugging tools

## When to Report Back

- **Weekly/bi-weekly**: Regular check-ins with Vantage 3 Subcore
- **As-needed**: Architecture decisions, blockers, cross-sub-agent coordination needs (especially with Basin Kernel Agent on syscall interface changes)

---

# SECTION 3: Grain System Integration Agent (3c)

## Your Status

**Agent**: Grain System Integration Agent (3c)  
**Parent Agent**: Grain Vantage 3 Subcore Agent (3rd Agent, L1)  
**Status**: ⚠️ **COORDINATION NEEDED** — RISC-V compliance test suite created, AArch64 code finding requires guidance

## Previous Next Steps Status

**Completed**:
- ✅ Began RISC-V compliance validation (Priority 1, HIGH)
- ✅ Created RISC-V compliance test suite
  - Test file: `tests/riscv_compliance_validation_test.zig`
  - 10+ comprehensive test cases covering RISC-V instruction set compliance
  - Tests for: x0 register, ADDI, ADD, LUI, JAL, BEQ, instruction alignment, memory alignment, calling convention, instruction encoding, memory model
  - Follows Grain Style (explicit u32/u64 types, comprehensive assertions, bounded operations)
- ⚠️ **COORDINATION NEEDED**: Found AArch64 code in kernel (contradicts "RISC-V only" requirement)
  - Files: `src/kernel/platform_aarch64.zig`, `src/kernel/main_aarch64.zig`, `src/kernel/entry_aarch64.S`
  - Build target: `build.zig` has `kernel-aarch64` build target
  - **Question**: Should AArch64 code be removed per "RISC-V only" requirement, or has requirement changed?

## New Next Steps

**Immediate Priorities**:

1. **IMMEDIATE: Coordinate with Vantage 3 Subcore on AArch64 Finding** (CRITICAL priority, BLOCKING)
   - **Question**: Should AArch64 code be removed per "RISC-V only" requirement?
   - **Files Found**: `src/kernel/platform_aarch64.zig`, `src/kernel/main_aarch64.zig`, `src/kernel/entry_aarch64.S`
   - **Build Target**: `build.zig` has `kernel-aarch64` build target
   - **Context**: Contradicts "RISC-V only" requirement stated in responsibilities
   - **Options**:
     - Option A: Remove AArch64 code (enforce "RISC-V only" requirement)
     - Option B: Keep AArch64 code (requirement has changed, AArch64 support is allowed)
   - **Action**: Wait for Vantage 3 Subcore guidance before proceeding with "Validate kernel targets RISC-V only" task

2. **Continue RISC-V Compliance Validation** (HIGH priority, after AArch64 guidance)
   - Run RISC-V compliance test suite to validate VM emulation
   - Complete kernel RISC-V-only validation (if AArch64 code should be removed)
   - Document RISC-V compliance requirements
   - Expand test coverage as needed

3. **Integration Test Coverage Expansion** (HIGH priority, after RISC-V compliance)
   - Expand integration test coverage for more syscall combinations
   - Add edge case testing
   - Add stress testing
   - Improve integration test suite
   - Coordinate with Basin Kernel Agent (3a) and VM Runtime Agent (3b) on test needs

4. **Kernel/VM Boundary Performance Profiling** (MEDIUM priority)
   - Add kernel/VM boundary profiling tools
   - Profile syscall overhead across kernel/VM boundary
   - Identify performance bottlenecks
   - Optimize kernel/VM interface if needed
   - Document performance characteristics

## Your Instructions

**Continue as you and they best recommend, given the context.**

**Remember to follow Grain Style** (`~/xy-mathematics/docs/grain_style.md`) with:
- `grain_case` function names
- All strict rules with all compiler warnings turned on
- **Specifically enforce `grainwrap-100` and `grain validate-70`**
- Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms

**Continue the next phase of implementation** and when you're done update your sub-agent system-integration docs and plans and tasks, informing Vantage 3 Subcore Agent how to update the general Grain OS summary `~/xy-mathematics/docs/plan.md` and `~/xy-mathematics/docs/tasks.md` in thinking.

**Let us know when you need to check in with me about upcoming integration steps via Vantage 3 Subcore and core-coordination generally with the other agents so that we prevent accidental conflicts.**

**Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement your API contracts.**

## Your File Paths

**Coordination**: `docs/core-coordination/vantage_3c_system_integration_coordination.md`  
**Plan**: `docs/plans/vantage_3c_system_integration_plan.md`  
**Tasks**: `docs/tasks/vantage_3c_system_integration_tasks.md`

**Vantage 3 Subcore Documents** (read these for context):
- `docs/core-coordination/vantage_3_subcore_coordination.md`
- `docs/plans/vantage_3_subcore_plan.md`
- `docs/tasks/vantage_3_subcore_tasks.md`

**Coordination Plan**: `docs/agent-communications/vantage_3_subcore_coordination_plan_2025-12-29-223949-pst.md`

## Your Code Location

- **Integration Code**: `src/kernel_vm/integration.zig` — Kernel/VM integration
- **Integration Tests**: `tests/` — Integration test files (numbered tests)
- **RISC-V Compliance Tests**: `tests/riscv_compliance_validation_test.zig`

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
- ⚠️ **BLOCKING**: AArch64 code finding requires Vantage 3 Subcore guidance

## When to Report Back

- **IMMEDIATE**: Coordinate with Vantage 3 Subcore on AArch64 code finding (waiting for guidance)
- **Weekly/bi-weekly**: Regular check-ins with Vantage 3 Subcore
- **As-needed**: Architecture decisions, blockers, cross-sub-agent coordination needs (especially with Basin Kernel Agent and VM Runtime Agent on interface changes)

---

## Coordination Schedule Summary

### All L2 Sub-Agents

**Weekly/Bi-Weekly Check-Ins with Vantage 3 Subcore**:
1. Review Vantage 3 Subcore coordination doc: `docs/core-coordination/vantage_3_subcore_coordination.md`
2. Update your coordination doc with progress
3. Request architecture decisions if needed
4. Report blockers or coordination needs

**As-Needed Coordination**:
- Architecture decisions that affect other sub-agents
- Cross-sub-agent coordination needs
- RISC-V compliance questions
- System-level testing coordination
- Blockers that prevent progress
- New syscall requirements (Vantage 3 Subcore will coordinate with Core Agent)
- **Critical findings that contradict stated requirements** (e.g., AArch64 code finding)

**What NOT to Do**:
- ❌ DO NOT coordinate directly with Core Agent (1st Agent) or other full agents
- ❌ DO NOT make architecture decisions that affect other sub-agents without Vantage 3 Subcore approval
- ❌ DO NOT skip coordination check-ins (weekly/bi-weekly schedule is important)

---

## Getting Started Checklist

### For All L2 Sub-Agents

- [ ] Read this entire document
- [ ] Read your specific section (3a, 3b, or 3c)
- [ ] Read Vantage 3 Subcore coordination doc: `docs/core-coordination/vantage_3_subcore_coordination.md`
- [ ] Read coordination plan: `docs/agent-communications/vantage_3_subcore_coordination_plan_2025-12-29-223949-pst.md`
- [ ] Review your domain codebase
- [ ] Review your coordination, plan, and tasks files
- [ ] Choose priority area based on your section's recommendations
- [ ] Begin work following Grain Style (grainwrap-100, grain validate-70, explicit u32/u64 types)
- [ ] Update documentation after each work session
- [ ] Schedule weekly/bi-weekly check-ins with Vantage 3 Subcore

---

## Summary

**This document is for ALL THREE L2 sub-agents**. Each sub-agent should:
1. Read the entire document (especially Grain Style requirements)
2. Find their specific section (3a, 3b, or 3c)
3. Follow the instructions in their section
4. Update their coordination, plan, and tasks files as specified
5. Continue as you and they best recommend, given the context
6. Coordinate with Vantage 3 Subcore weekly/bi-weekly

**Key Points**:
- Only Vantage 3 Subcore (L1) communicates with Core Agent (1st Agent) directly
- L2 sub-agents coordinate through Vantage 3 Subcore only
- All file paths use `vantage_[AGENT_NUMBER]_[AGENT_NAME]_*` naming pattern
- Grain Style is non-negotiable and strictly enforced (grainwrap-100, grain validate-70, explicit u32/u64 types)
- Weekly/bi-weekly coordination check-ins are required
- All tests must pass before merging
- Update general summaries (`docs/plan.md`, `docs/tasks.md`) via Vantage 3 Subcore
- **3c has IMMEDIATE coordination need**: AArch64 code finding requires Vantage 3 Subcore guidance

---

**Date**: 2025-12-29-223949-pst  
**From**: Grain Vantage 3 Subcore Agent (3rd Agent, L1)  
**To**: All Vantage L2 Sub-Agents (3a, 3b, 3c)  
**Status**: Ready for L2 sub-agents to continue work on priorities
