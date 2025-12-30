# Vantage 3 Core Agent: Coordination Plan for L2 Sub-Agents

**Date**: 2025-12-29-223949-pst  
**From**: Grain Vantage Core Agent (3rd Agent, L1)  
**To**: All Vantage L2 Sub-Agents (3a, 3b, 3c)  
**Purpose**: Coordination plan for L2 sub-agents with priorities and next steps

---

## Executive Summary

**Vantage Core Status**: ✅ **READY TO COORDINATE** — All kernel/VM/integration features complete, production-ready, L2 sub-agents making progress

**Previous Next Steps** (from 2025-12-29-214643-pst coordination plan):
- ✅ **COMPLETE**: 3a began kernel development work (profiler infrastructure complete)
- ⏳ **IN PROGRESS**: 3b Phase 1 codebase review continuing (~30% complete)
- ✅ **COMPLETE**: 3c began RISC-V compliance validation (test suite created, coordination needed on AArch64 finding)

**Current Status**:
- **3a. Basin Kernel Agent**: ✅ Profiler infrastructure complete, ready for performance data collection and optimization
- **3b. VM Runtime Agent**: ⏳ Phase 1 codebase review in progress (~30% complete, ~70% remaining)
- **3c. System Integration Agent**: ⚠️ RISC-V compliance test suite created, **COORDINATION NEEDED** on AArch64 code finding

**New Next Steps** (this coordination plan):
- **3a**: Continue kernel performance optimization (collect performance data, identify hot paths, optimize)
- **3b**: Continue Phase 1 codebase review, complete remaining ~70%, then proceed to Phase 2 (VM Maintenance)
- **3c**: **IMMEDIATE**: Coordinate with Vantage Core on AArch64 code finding, then continue RISC-V compliance validation

---

## Previous Coordination Summary Status

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
- ⏳ **NEXT**: Collect performance data, identify hot paths, optimize syscall handlers

**3b. VM Runtime Agent**:
- ✅ **COMPLETE**: Priorities confirmed from Vantage Core
- ⏳ **IN PROGRESS**: Phase 1 codebase review (~30% complete, ~70% remaining)
  - Reviewed: `vm.zig` core (in progress), `jit.zig` JIT compiler (in progress), `integration.zig` (in progress)
  - Remaining: Complete review of all 37 VM modules, document architecture, identify improvements
- ⏳ **NEXT**: Complete Phase 1, then proceed to Phase 2 (VM Maintenance and Stability)

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
- ⏳ **NEXT**: After AArch64 guidance, continue RISC-V compliance validation

---

## Current Priorities for Each Sub-Agent

### 3a. Basin Kernel Agent: Continue Performance Optimization

**Status**: ✅ **PROFILER INFRASTRUCTURE COMPLETE** — Ready for performance data collection and optimization

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

**Coordination Notes**:
- Profiler infrastructure complete and ready for use
- Coordinate with Vantage Core weekly/bi-weekly on progress
- Coordinate immediately if new syscall requirements identified (Vantage Core will coordinate with Core Agent)
- Coordinate with System Integration Agent (3c) on integration testing needs

**Next Steps**:
1. Enable profiler and collect performance data
2. Analyze data to identify optimization opportunities
3. Optimize hot paths and slow paths
4. Update coordination, plan, and tasks files after each work session

---

### 3b. VM Runtime Agent: Continue Phase 1, Then Phase 2

**Status**: ⏳ **PHASE 1 IN PROGRESS** — Codebase review ~30% complete, ~70% remaining

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
   - Coordinate with Vantage Core on findings

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
   - Coordinate with Vantage Core on performance goals

4. **Phase 6: VM Testing and Validation** (ONGOING priority)
   - Maintain comprehensive test coverage
   - Add tests for uncovered code paths
   - Add integration tests with Basin kernel
   - Validate RISC-V instruction emulation correctness
   - Ensure all tests pass

**Coordination Notes**:
- Phase 1 codebase review in progress (~30% complete, ~70% remaining)
- Continue review systematically through all 37 VM modules
- Coordinate with Vantage Core weekly/bi-weekly on progress
- Coordinate with Basin Kernel Agent (3a) on syscall interface changes (if any)
- Coordinate with System Integration Agent (3c) on integration testing needs

**Next Steps**:
1. Continue Phase 1 codebase review (complete remaining ~70%)
2. Document findings and coordinate with Vantage Core
3. Begin Phase 2 (VM Maintenance) after Phase 1 complete
4. Update coordination, plan, and tasks files after each work session

---

### 3c. System Integration Agent: Coordinate on AArch64, Continue RISC-V Compliance

**Status**: ⚠️ **COORDINATION NEEDED** — RISC-V compliance test suite created, AArch64 code finding requires guidance

**Immediate Priorities**:

1. **IMMEDIATE: Coordinate with Vantage Core on AArch64 Finding** (CRITICAL priority, BLOCKING)
   - **Question**: Should AArch64 code be removed per "RISC-V only" requirement?
   - **Files Found**: `src/kernel/platform_aarch64.zig`, `src/kernel/main_aarch64.zig`, `src/kernel/entry_aarch64.S`
   - **Build Target**: `build.zig` has `kernel-aarch64` build target
   - **Context**: Contradicts "RISC-V only" requirement stated in responsibilities
   - **Options**:
     - Option A: Remove AArch64 code (enforce "RISC-V only" requirement)
     - Option B: Keep AArch64 code (requirement has changed, AArch64 support is allowed)
   - **Action**: Wait for Vantage Core guidance before proceeding with "Validate kernel targets RISC-V only" task

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

**Coordination Notes**:
- **IMMEDIATE COORDINATION NEEDED**: AArch64 code finding requires Vantage Core guidance
- RISC-V compliance test suite created and ready for use
- Coordinate with Vantage Core immediately on AArch64 guidance
- Coordinate with Basin Kernel Agent (3a) on kernel interface changes
- Coordinate with VM Runtime Agent (3b) on VM interface changes

**Next Steps**:
1. **IMMEDIATE**: Coordinate with Vantage Core on AArch64 code finding (waiting for guidance)
2. After AArch64 guidance, continue RISC-V compliance validation
3. Expand integration test coverage
4. Update coordination, plan, and tasks files after each work session

---

## Grain Style Requirements (CRITICAL)

**ALL code must follow Grain Style** (TigerStyle-compliant). This is non-negotiable.

### Core Principles

1. **Function Naming**: `grain_case` (snake_case)
2. **Explicit Types**: Use `u32`, `u64`, `i64` instead of `usize`/`isize` (for consistency across all compile target platforms)
3. **No Recursion**: Convert all recursive functions to iterative (stack-based) algorithms
4. **Bounded Allocations**: All dynamic data structures must have `MAX_` constants and assertions
5. **Assertions**: Minimum 2 assertions per function (preconditions, postconditions, invariants)
6. **Compiler Warnings**: All warnings must be enabled and resolved
7. **No Hidden Allocations**: All memory allocation must be explicit
8. **Static Allocation Preferred**: Avoid heap allocation after startup where possible
9. **Function Length**: Maximum 70 lines per function (`grain validate-70`)
10. **Line Length**: Maximum 100 characters per line (`grainwrap-100`)

### Reference Documents

- **Grain Style Guide**: `docs/grain_style.md`
- **TigerStyle Reference**: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md

### Zig Version

- **MUST use Zig 0.15.2** everywhere
- Download: https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz

### Zero Technical Debt Policy

- Do it right the first time
- No TODOs or FIXMEs in production code
- Complete implementations only (no stubs or placeholders)
- Comprehensive test coverage required

---

## Coordination Schedule

### Weekly/Bi-Weekly Check-Ins

**Frequency**: Weekly or bi-weekly (as scheduled)

**What Sub-Agents Should Do**:
1. Review Vantage Core coordination doc: `docs/core-coordination/vantage_3_core_coordination.md`
2. Update your coordination doc with progress, status, blockers
3. Request architecture decisions if needed
4. Report blockers or coordination needs
5. Present findings and request priority guidance

**What Vantage Core Will Do**:
1. Review all sub-agent coordination docs
2. Coordinate on architecture decisions
3. Provide priority guidance
4. Coordinate with Core Agent and other full agents as needed
5. Update Vantage Core coordination doc with status

### As-Needed Coordination

**Coordinate Immediately When**:
- Architecture decisions needed that affect other sub-agents
- Cross-sub-agent coordination needed (kernel/VM interface changes, integration issues)
- RISC-V compliance questions arise
- System-level testing coordination needed
- Blockers encountered that prevent progress
- New syscall requirements identified (Vantage Core will coordinate with Core Agent)
- **Critical findings that contradict stated requirements** (e.g., AArch64 code finding)

---

## Documentation Requirements

### Three-Document System

Each sub-agent maintains three documents that must be updated regularly:

1. **Coordination Document**: `docs/core-coordination/vantage_3[AGENT]_[NAME]_coordination.md`
2. **Plan Document**: `docs/plans/vantage_3[AGENT]_[NAME]_plan.md`
3. **Tasks Document**: `docs/tasks/vantage_3[AGENT]_[NAME]_tasks.md`

### After Each Work Session

**Sub-Agents Must**:
1. Update coordination doc with status, progress, blockers
2. Update plan doc with implementation plan changes
3. Update tasks doc with task completion status
4. Coordinate with Vantage Core if blockers or architecture decisions needed

### General Summary Updates

**Sub-Agents Should Inform Vantage Core**:
- When significant milestones are reached
- When new features are complete
- When architecture decisions are made
- When coordination with other agents is needed

**Vantage Core Will Update**:
- `docs/plan.md` — General project plan summary
- `docs/tasks.md` — General project tasks summary
- `docs/core-coordination/vantage_3_core_coordination.md` — Vantage Core coordination status

---

## Testing Requirements

### All Sub-Agents

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

---

## Summary

**Vantage Core Status**: ✅ **READY TO COORDINATE** — All kernel/VM/integration features complete, production-ready

**Previous Next Steps**: ✅ **PROGRESS MADE** — 3a profiler complete, 3b Phase 1 in progress, 3c test suite created (coordination needed)

**New Next Steps**:
- **3a**: Continue performance optimization (collect data, analyze, optimize)
- **3b**: Complete Phase 1 codebase review (~70% remaining), then Phase 2
- **3c**: **IMMEDIATE**: Coordinate on AArch64 finding, then continue RISC-V compliance

**Coordination Schedule**: Weekly/bi-weekly check-ins, as-needed for architecture decisions

**Grain Style**: Strictly enforced (all 10 core principles, grainwrap-100, grain validate-70, explicit u32/u64 types)

---

**Date**: 2025-12-29-223949-pst  
**From**: Grain Vantage Core Agent (3rd Agent, L1)  
**To**: All Vantage L2 Sub-Agents (3a, 3b, 3c)  
**Status**: Ready for L2 sub-agents to continue work on priorities
