# Vantage 3 Subcore Agent: Coordination Plan for L2 Sub-Agents

**Date**: 2025-12-29-214643-pst  
**From**: Grain Vantage 3 Subcore Agent (3rd Agent, L1)  
**To**: All Vantage L2 Sub-Agents (3a, 3b, 3c)  
**Purpose**: Coordination plan for L2 sub-agents with priorities and next steps

---

## Executive Summary

**Vantage 3 Subcore Status**: ✅ **READY TO COORDINATE** — All kernel/VM/integration features complete, production-ready, L2 sub-agents initialized

**Previous Next Steps** (from 2025-12-29-153000-pst coordination summary):
- ✅ **COMPLETE**: L2 sub-agents received coordination summary and instructions
- ✅ **COMPLETE**: All sub-agent coordination, plan, and tasks files created
- ✅ **COMPLETE**: Sub-agents reviewed codebases and updated documentation
- ⏳ **IN PROGRESS**: Sub-agents coordinating with Vantage 3 Subcore on priorities

**Current Status**:
- **3a. Basin Kernel Agent**: ✅ Codebase reviewed, requesting priority guidance
- **3b. VM Runtime Agent**: ⏳ Phase 1 codebase review in progress (~30%), coordinating on priorities
- **3c. System Integration Agent**: ✅ Codebase assessed, ready to coordinate on priorities

**New Next Steps** (this coordination plan):
- **3a**: Begin kernel development work (performance optimization, security hardening, or new features as prioritized)
- **3b**: Complete Phase 1 codebase review, then begin VM maintenance and optimization work
- **3c**: Begin RISC-V compliance validation and integration testing expansion

---

## Previous Coordination Summary Status

### Completed from Previous Coordination (2025-12-29-153000-pst)

**All L2 Sub-Agents**:
- ✅ Received coordination summary document (`docs/vantage_l2_sub_agents_coordination_summary.md`)
- ✅ Reviewed Grain Style requirements (all 10 core principles)
- ✅ Understood L1/L2 coordination model
- ✅ Created/updated coordination, plan, and tasks files
- ✅ Reviewed respective codebases (kernel, VM, integration)

**3a. Basin Kernel Agent**:
- ✅ Reviewed kernel codebase (8 modules, 140 syscalls, production-ready)
- ✅ Updated coordination, plan, and tasks files
- ✅ Verified zero technical debt (no TODOs/FIXMEs)
- ✅ Confirmed comprehensive test coverage exists
- ⏳ **READY**: Requesting priority guidance from Vantage 3 Subcore

**3b. VM Runtime Agent**:
- ✅ Received coordination summary and instructions
- ✅ Created plan and tasks files
- ✅ Started Phase 1 codebase review
- ⏳ **IN PROGRESS**: Phase 1 codebase review (~30% complete), coordinating on priorities

**3c. System Integration Agent**:
- ✅ Reviewed integration codebase (`src/kernel_vm/integration.zig`, 1,242 lines)
- ✅ Reviewed integration tests (multiple test files)
- ✅ Completed codebase assessment
- ✅ Created plan and tasks files
- ⏳ **READY**: Ready to coordinate on priorities

---

## Current Priorities for Each Sub-Agent

### 3a. Basin Kernel Agent: Kernel Development and Optimization

**Status**: ✅ **READY TO BEGIN WORK** — Codebase reviewed, zero technical debt, production-ready

**Immediate Priorities** (choose based on your assessment and coordination needs):

1. **Kernel Performance Optimization** (HIGH priority)
   - Profile syscall performance to identify hot paths
   - Optimize syscall handlers for common operations
   - Improve scheduler efficiency
   - Reduce syscall overhead
   - Performance benchmarking and validation

2. **Kernel Security Hardening** (MEDIUM priority)
   - Additional input validation review
   - Security audit of syscall handlers
   - Capability-based access control enhancements
   - Memory protection improvements
   - Security testing

3. **Kernel Maintenance and Code Quality** (ONGOING priority)
   - Monitor kernel stability
   - Fix any bugs discovered
   - Ensure all code follows Grain Style (grainwrap-100, grain validate-70)
   - Maintain zero technical debt policy
   - Keep documentation up to date

4. **JG Project Kernel Support** (AS NEEDED)
   - Monitor JG project implementation for kernel support needs
   - Coordinate with Vantage 3 Subcore on new syscall requirements
   - Optimize kernel performance for JG project workloads
   - Configure resource limits for JG project processes (if needed)

**Coordination Notes**:
- Coordinate with Vantage 3 Subcore weekly/bi-weekly on progress and priorities
- Coordinate immediately if new syscall requirements identified (Vantage 3 Subcore will coordinate with Core Agent)
- Coordinate with System Integration Agent (3c) on integration testing needs
- Coordinate with VM Runtime Agent (3b) on syscall interface changes (if any)

**Next Steps**:
1. Choose priority area (performance optimization recommended)
2. Begin implementation following Grain Style
3. Update coordination, plan, and tasks files after each work session
4. Coordinate with Vantage 3 Subcore weekly/bi-weekly

---

### 3b. VM Runtime Agent: VM Development and Optimization

**Status**: ⏳ **PHASE 1 IN PROGRESS** — Codebase review ~30% complete, coordinating on priorities

**Immediate Priorities**:

1. **Complete Phase 1: VM Codebase Review** (HIGH priority, IN PROGRESS)
   - Finish reviewing all VM modules (37 total files)
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

**Coordination Notes**:
- Continue Phase 1 codebase review (target: complete within 1 week)
- Coordinate with Vantage 3 Subcore weekly/bi-weekly on progress and priorities
- Coordinate with Basin Kernel Agent (3a) on syscall interface changes (if any)
- Coordinate with System Integration Agent (3c) on integration testing needs

**Next Steps**:
1. Continue Phase 1 codebase review (complete remaining ~70%)
2. Document findings and coordinate with Vantage 3 Subcore on priorities
3. Begin Phase 2 (VM Maintenance) after Phase 1 complete
4. Update coordination, plan, and tasks files after each work session

---

### 3c. System Integration Agent: Integration and RISC-V Compliance

**Status**: ✅ **READY TO BEGIN WORK** — Codebase assessed, ready to coordinate on priorities

**Immediate Priorities**:

1. **RISC-V Compliance Validation** (HIGH priority)
   - Create RISC-V compliance test suite
   - Validate kernel targets RISC-V only (no ARM64-specific code)
   - Validate VM emulates RISC-V correctly
   - Test RISC-V instruction set compliance
   - Document RISC-V compliance requirements

2. **Integration Test Coverage Expansion** (HIGH priority)
   - Expand integration test coverage for more syscall combinations
   - Add edge case testing
   - Add stress testing
   - Improve integration test suite
   - Coordinate with Basin Kernel Agent (3a) and VM Runtime Agent (3b) on test needs

3. **Kernel/VM Boundary Performance Profiling** (MEDIUM priority)
   - Add kernel/VM boundary profiling tools
   - Profile syscall overhead across kernel/VM boundary
   - Identify performance bottlenecks
   - Optimize kernel/VM interface if needed
   - Document performance characteristics

4. **Kernel/VM Interface Documentation** (MEDIUM priority)
   - Enhance kernel/VM interface documentation
   - Document syscall interface contracts
   - Document memory permission requirements
   - Document ELF loading process
   - Create integration development guidelines

**Coordination Notes**:
- Coordinate with Vantage 3 Subcore weekly/bi-weekly on progress and priorities
- Coordinate with Basin Kernel Agent (3a) on kernel interface changes
- Coordinate with VM Runtime Agent (3b) on VM interface changes
- Coordinate immediately if RISC-V compliance issues discovered

**Next Steps**:
1. Begin RISC-V compliance validation test suite (recommended first priority)
2. Expand integration test coverage
3. Update coordination, plan, and tasks files after each work session
4. Coordinate with Vantage 3 Subcore weekly/bi-weekly

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
1. Review Vantage 3 Subcore coordination doc: `docs/core-coordination/vantage_3_subcore_coordination.md`
2. Update your coordination doc with progress, status, blockers
3. Request architecture decisions if needed
4. Report blockers or coordination needs
5. Present findings and request priority guidance

**What Vantage 3 Subcore Will Do**:
1. Review all sub-agent coordination docs
2. Coordinate on architecture decisions
3. Provide priority guidance
4. Coordinate with Core Agent and other full agents as needed
5. Update Vantage 3 Subcore coordination doc with status

### As-Needed Coordination

**Coordinate Immediately When**:
- Architecture decisions needed that affect other sub-agents
- Cross-sub-agent coordination needed (kernel/VM interface changes, integration issues)
- RISC-V compliance questions arise
- System-level testing coordination needed
- Blockers encountered that prevent progress
- New syscall requirements identified (Vantage 3 Subcore will coordinate with Core Agent)

**What NOT to Do**:
- ❌ DO NOT coordinate directly with Core Agent (1st Agent) or other full agents
- ❌ DO NOT make architecture decisions that affect other sub-agents without Vantage 3 Subcore approval
- ❌ DO NOT skip coordination check-ins (weekly/bi-weekly schedule is important)

---

## Documentation Requirements

### Three-Document System

Each sub-agent maintains three documents that must be updated regularly:

1. **Coordination Document**: `docs/core-coordination/vantage_3[AGENT]_[NAME]_coordination.md`
   - Status, progress, blockers, coordination decisions
   - Update after each work session

2. **Plan Document**: `docs/plans/vantage_3[AGENT]_[NAME]_plan.md`
   - Implementation plan, phase descriptions, architecture decisions
   - Update when implementation plan changes

3. **Tasks Document**: `docs/tasks/vantage_3[AGENT]_[NAME]_tasks.md`
   - Detailed task list, task completion status, task dependencies
   - Update when tasks are completed or new tasks are added

### After Each Work Session

**Sub-Agents Must**:
1. Update coordination doc with status, progress, blockers
2. Update plan doc with implementation plan changes
3. Update tasks doc with task completion status
4. Coordinate with Vantage 3 Subcore if blockers or architecture decisions needed

### General Summary Updates

**Sub-Agents Should Inform Vantage 3 Subcore**:
- When significant milestones are reached
- When new features are complete
- When architecture decisions are made
- When coordination with other agents is needed

**Vantage 3 Subcore Will Update**:
- `docs/plan.md` — General project plan summary
- `docs/tasks.md` — General project tasks summary
- `docs/core-coordination/vantage_3_subcore_coordination.md` — Vantage 3 Subcore coordination status

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

**Test Validation**:
- Run all tests before committing
- Fix any failing tests immediately
- Document test coverage
- Coordinate with Vantage 3 Subcore if test failures indicate architecture issues

---

## Integration Coordination

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

## Summary

**Vantage 3 Subcore Status**: ✅ **READY TO COORDINATE** — All kernel/VM/integration features complete, production-ready

**Previous Next Steps**: ✅ **COMPLETE** — All sub-agents initialized, codebases reviewed, documentation updated

**New Next Steps**:
- **3a**: Begin kernel development work (performance optimization recommended)
- **3b**: Complete Phase 1 codebase review, then begin VM maintenance
- **3c**: Begin RISC-V compliance validation and integration testing expansion

**Coordination Schedule**: Weekly/bi-weekly check-ins, as-needed for architecture decisions

**Grain Style**: Strictly enforced (all 10 core principles, grainwrap-100, grain validate-70, explicit u32/u64 types)

**Documentation**: Three-document system (coordination, plan, tasks) — update after each work session

**Testing**: All tests must pass before merging

---

**Date**: 2025-12-29-214643-pst  
**From**: Grain Vantage 3 Subcore Agent (3rd Agent, L1)  
**To**: All Vantage L2 Sub-Agents (3a, 3b, 3c)  
**Status**: Ready for L2 sub-agents to begin work on priorities
