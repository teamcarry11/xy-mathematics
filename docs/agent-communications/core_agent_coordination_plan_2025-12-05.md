# Grain Core Agent: Professional-Grade Maximally Parallel Safe Performant Coordination Plan

**Date**: 2025-12-05-170522-pst  
**Agent**: Grain Core Agent (Core Agentic-Prompt-Engineering Pilot Seat Driver)  
**Status**: Master Coordination Document for All 8 Agents  
**Purpose**: Maximize parallelization, ensure safety, optimize performance, prevent conflicts

---

## Executive Summary

This document provides a professional-grade, maximally parallel, safe, performant Grain Style procedural generation plan for all 8 Grain agents. It optimizes work sequencing, prevents race conditions, and ensures all agents can work safely in parallel where possible.

**Agents**:
1. **Grain Core Agent** (System Services, API Server, Authentication, Network Stack)
2. **Grain Silo Agent** (Database, Storage Engine, Graph, Index)
3. **Grain Vantage Agent** (VM/Kernel, Syscalls, Process Management)
4. **Grain Skate Agent** (Knowledge Graph, Terminal, Editor)
5. **Grain Bubble Agent** (Design Tool, Canvas, Export)
6. **Grain Carry Agent** (Mobile Framework, API Client, Auth)
7. **Grain Aurora Agent** (IDE/Browser, LSP, Editor)
8. **Grain Workspace Agent** (Desktop Apps, System Tools)

---

## Core Principles

### 1. Safety First (Grain Style)
- All code follows Grain Style: `grain_case` function names, `u32`/`u64` types, bounded allocations
- Maximum 70 lines per function, maximum 100 characters per line
- Minimum 2 assertions per function
- All compiler warnings enabled
- No recursion, no dynamic allocations
- All tests must pass: `grainwrap-100` and `grain validate-70`

### 2. Maximize Parallelization
- Work in parallel where dependencies allow
- Prepare integration code while waiting for dependencies
- Coordinate only when necessary (shared modules, API contracts)

### 3. Performance Matters
- Bounded allocations with explicit `MAX_*` constants
- Zero-copy where possible
- Efficient data structures
- Profile before optimizing

### 4. Coordination Protocol
- Update `docs/plans/plan_{agent}.md` and `docs/tasks/tasks_{agent}.md` after each phase
- Update master `docs/plan.md` and `docs/tasks.md` with progress
- Notify user when coordination with another agent is needed
- Use `docs/agent-communications/` for inter-agent coordination

---

## Dependency Analysis & Parallelization Strategy

### Critical Path Dependencies

```
Vantage Agent (Kernel/VM)
    ↓
Core Agent (System Services)
    ↓
    ├─→ Silo Agent (Database) [needs: API Server, WebSocket]
    ├─→ Carry Agent (Mobile) [needs: API Server, Auth, WebSocket]
    ├─→ Workspace Agent (Desktop Apps) [needs: System Services]
    └─→ Bubble Agent (Design Tool) [needs: Compositor, Rendering]

Aurora Agent (IDE/Browser) [mostly independent]
Skate Agent (Knowledge Graph) [mostly independent]
```

### Parallelization Tiers

**Tier 1: Fully Independent (Can Work Simultaneously)**
- **Aurora Agent**: LSP features, editor enhancements, browser improvements
- **Skate Agent**: Syntax highlighting, graph features, terminal improvements
- **Workspace Agent**: Desktop apps (uses existing OS services)
- **Bubble Agent**: Phase 1 core canvas (uses existing OS compositor)

**Tier 2: Infrastructure-Dependent (Sequential with Parallel Prep)**
- **Vantage Agent** → Network syscalls (enables Core Phase 61)
- **Core Agent** → WebSocket support (Phase 61) → Unblocks Silo & Carry
- **Silo Agent** → WebSocket integration (after Core Phase 61) [can prepare now]
- **Carry Agent** → WebSocket client (after Core Phase 61) [can prepare now]

**Tier 3: Application Layer (Mostly Independent)**
- All agents can work on application features in parallel once infrastructure is ready

---

## Agent-Specific Work Plans

### 1. Grain Core Agent (Current Phase: 58.7 - Test System Fixes)

**Priority**: **HIGH** — Required for test suite to pass after Grain OS → Grain Core rename

**Current Work**:
- Phase 58.7: Test System Fixes After Rename ⏳ **IN PROGRESS**
  - Rename 67 test files: `tests/*_grain_os_*` → `tests/*_grain_core_*`
  - Update test configurations in `build.zig`
  - Verify all tests compile and pass
  - Fix remaining `grain_os` references

**Next Phases**:
- Phase 61: WebSocket Support (HIGH PRIORITY - unblocks Silo & Carry)
- Phase 61: DNS Resolution
- Phase 62: File System Enhancements (for Silo Agent)

**Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Coordination Needs**:
- None currently (test fixes are isolated)
- Will coordinate with Silo & Carry when WebSocket is ready

---

### 2. Grain Silo Agent (Database)

**Priority**: **MEDIUM** — Prepare for WebSocket integration

**Current Work**:
- Prepare WebSocket integration code (waiting for Core Phase 61)
- Test database endpoints with Core API server
- Continue database core features (storage engine, graph, index)

**Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Coordination Needs**:
- Coordinate with Core Agent on WebSocket protocol (when Phase 61 is ready)
- Coordinate with Core Agent on API Server interface (ongoing)

**Blocked By**: Core Agent Phase 61 (WebSocket support)

---

### 3. Grain Vantage Agent (VM/Kernel)

**Priority**: **HIGH** — Network syscalls enable Core Phase 61

**Current Work**:
- Network syscalls (TCP/UDP) for Core Agent Phase 61
- Continue kernel features (process management, file I/O)

**Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Coordination Needs**:
- Coordinate with Core Agent on syscall interface design
- Coordinate on network syscall API contracts

**Enables**: Core Agent Phase 61 (Network Stack Enhancements)

---

### 4. Grain Skate Agent (Knowledge Graph)

**Priority**: **LOW** — Mostly independent work

**Current Work**:
- Continue syntax highlighting improvements
- Continue graph features
- Continue terminal improvements
- Shared module coordination (when needed)

**Can Work In Parallel With**: All agents (except when coordinating shared modules)

**Coordination Needs**:
- Coordinate only when modifying shared modules (font renderer, text buffer, DAG)

---

### 5. Grain Bubble Agent (Design Tool)

**Priority**: **LOW** — Phase 1 core canvas (SLC v1.0)

**Current Work**:
- Phase 1: Core canvas implementation
- Integrate with Core compositor
- Basic rendering and export features

**Can Work In Parallel With**: Aurora, Skate, Workspace, Core (except compositor changes)

**Coordination Needs**:
- Coordinate with Core Agent on compositor API (if changes needed)
- Coordinate with Silo Agent on storage (if needed)

---

### 6. Grain Carry Agent (Mobile Framework)

**Priority**: **MEDIUM** — Prepare for WebSocket client

**Current Work**:
- Prepare WebSocket client code (waiting for Core Phase 61)
- Test API endpoints with Core API server
- Continue mobile framework features

**Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Coordination Needs**:
- Coordinate with Core Agent on WebSocket protocol (when Phase 61 is ready)
- Coordinate with Core Agent on API Server interface (ongoing)
- Coordinate with Silo Agent on database integration

**Blocked By**: Core Agent Phase 61 (WebSocket support)

---

### 7. Grain Aurora Agent (IDE/Browser)

**Priority**: **LOW** — Mostly independent work

**Current Work**:
- Continue LSP features
- Continue editor enhancements
- Continue browser improvements
- Shared module coordination (when needed)

**Can Work In Parallel With**: All agents (except when coordinating shared modules)

**Coordination Needs**:
- Coordinate only when modifying shared modules (font renderer, text buffer, DAG)

---

### 8. Grain Workspace Agent (Desktop Apps)

**Priority**: **LOW** — Desktop apps using existing services

**Current Work**:
- Continue desktop app development
- Integrate with Core system services
- Build workspace tools

**Can Work In Parallel With**: Aurora, Skate, Bubble Phase 1

**Coordination Needs**:
- Coordinate with Core Agent on system service APIs (if changes needed)

---

## Recommended Work Sequence (Next 2-4 Weeks)

### Week 1: Foundation & Infrastructure

**Priority 1: Core Agent** (Blocks Others)
- **Phase 58.7**: Test System Fixes (HIGH - required for test suite)
- **Phase 61**: WebSocket Support (HIGH - unblocks Silo & Carry)
  - Estimated: 1-2 weeks

**Priority 2: Vantage Agent** (Enables Core)
- **Network Syscalls**: TCP/UDP syscalls for Core Phase 61
  - Estimated: 1 week

**Parallel Work**:
- **Silo Agent**: Prepare WebSocket integration code
- **Carry Agent**: Prepare WebSocket client code
- **Aurora Agent**: Continue independent work
- **Skate Agent**: Continue independent work
- **Workspace Agent**: Continue desktop apps
- **Bubble Agent**: Continue Phase 1 core canvas

### Week 2-3: Integration & Enhancement

**After Core Phase 61 Complete**:
- **Silo Agent**: WebSocket integration (1 week)
- **Carry Agent**: WebSocket client (1 week)
- **Core Agent**: DNS Resolution (Phase 61), File System Enhancements (Phase 62)

**Parallel Work**:
- **Aurora Agent**: Continue independent work
- **Skate Agent**: Continue independent work
- **Workspace Agent**: Continue desktop apps
- **Bubble Agent**: Continue Phase 1 core canvas

---

## Coordination Protocol

### When to Coordinate

1. **Shared Modules**: When modifying `src/shared/`, `src/grain_buffer.zig`, `src/dag_core.zig`
2. **API Contracts**: When changing API interfaces that other agents depend on
3. **Build System**: When modifying `build.zig` or `build/*.zig`
4. **Test Files**: When renaming or restructuring test files
5. **Documentation**: When updating master `docs/plan.md` or `docs/tasks.md`

### How to Coordinate

1. **Create Coordination Document**: `docs/agent-communications/{agent1}_to_{agent2}_coordination.md`
2. **Notify User**: "I need to coordinate with [Agent Name] on [Topic]"
3. **Wait for Approval**: User will facilitate coordination
4. **Update Documentation**: After coordination, update plans and tasks

### Update Protocol

After each phase completion:
1. Update `docs/plans/plan_{agent}.md` with phase completion
2. Update `docs/tasks/tasks_{agent}.md` with completed tasks
3. Update master `docs/plan.md` with progress summary
4. Update master `docs/tasks.md` with progress summary
5. Include timestamp: `yyyy-mm-dd-hhmmss-pst`

---

## Grain Style Enforcement

### Code Quality Requirements

- **Function Names**: `grain_case` (e.g., `parse_http_request`, `generate_jwt_token`)
- **Types**: `u32`/`u64` (no `usize` unless absolutely necessary)
- **Bounded Allocations**: Explicit `MAX_*` constants (e.g., `MAX_REQUEST_SIZE = 8192`)
- **Assertions**: Minimum 2 per function
- **Line Limits**: Max 70 lines per function, max 100 characters per line
- **No Recursion**: Iterative algorithms only
- **No Dynamic Allocation**: Stack-allocated arrays only
- **All Warnings**: Compiler warnings enabled, zero warnings allowed

### Test Requirements

- **All Tests Pass**: `zig build test` must succeed
- **Grain Wrap**: `grainwrap-100` (100 character line limit)
- **Grain Validate**: `grain validate-70` (70 line function limit)
- **API Contracts**: All tests must implement their API contracts correctly

---

## Standard Agent Prompt Template

```
continue as you best recommend, remember to follow Grain Style (~/xy-mathematics/docs/grain_style.md) with grain_case function names and all the strict rules with all compiler warnings turned on

continue the next phase of implementation and when you're done update the docs/plans/plan_{agent}.md and docs/tasks/tasks_{agent}.md keeping the general summary docs/plan.md and docs/tasks.md in thinking. let me know when you need me to check in with the other agent to prevent conflicts. also make sure all existing and new tests pass that implement their API contracts, enforcing grainwrap-100 and grain validate-70

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your printout summary header

your agent name is: [Your Agent Name]
```

---

## Status Tracking

### Current Priorities (Week 1)

1. **Core Agent**: Phase 58.7 (Test System Fixes) - **IN PROGRESS**
2. **Core Agent**: Phase 61 (WebSocket Support) - **NEXT**
3. **Vantage Agent**: Network Syscalls - **ENABLES CORE**
4. **Silo Agent**: Prepare WebSocket Integration - **PARALLEL PREP**
5. **Carry Agent**: Prepare WebSocket Client - **PARALLEL PREP**

### Blocking Relationships

- **Silo Agent** blocked by **Core Agent** Phase 61 (WebSocket)
- **Carry Agent** blocked by **Core Agent** Phase 61 (WebSocket)
- **Core Agent** Phase 61 enabled by **Vantage Agent** (Network Syscalls)

### Independent Work (Can Proceed Now)

- **Aurora Agent**: All independent work
- **Skate Agent**: All independent work
- **Workspace Agent**: Desktop apps
- **Bubble Agent**: Phase 1 core canvas

---

## Success Metrics

### Code Quality
- ✅ Zero compiler warnings
- ✅ All tests pass (`zig build test`)
- ✅ Grain Style compliance (`grainwrap-100`, `grain validate-70`)
- ✅ Bounded allocations with explicit limits
- ✅ Minimum 2 assertions per function

### Coordination
- ✅ No merge conflicts
- ✅ API contracts maintained
- ✅ Shared modules coordinated
- ✅ Documentation updated

### Performance
- ✅ Bounded memory usage
- ✅ Efficient algorithms
- ✅ Zero-copy where possible

---

## Next Steps for Each Agent

### Grain Core Agent
1. Complete Phase 58.7 (Test System Fixes)
2. Start Phase 61 (WebSocket Support)
3. Coordinate with Vantage Agent on network syscalls

### Grain Silo Agent
1. Prepare WebSocket integration code
2. Test database endpoints
3. Wait for Core Agent Phase 61

### Grain Vantage Agent
1. Implement network syscalls (TCP/UDP)
2. Coordinate with Core Agent on API design
3. Update documentation

### Grain Skate Agent
1. Continue independent work
2. Coordinate only when modifying shared modules

### Grain Bubble Agent
1. Continue Phase 1 core canvas
2. Integrate with Core compositor

### Grain Carry Agent
1. Prepare WebSocket client code
2. Test API endpoints
3. Wait for Core Agent Phase 61

### Grain Aurora Agent
1. Continue independent work
2. Coordinate only when modifying shared modules

### Grain Workspace Agent
1. Continue desktop apps
2. Integrate with Core system services

---

**Document Version**: 1.0  
**Last Updated**: 2025-12-05-170522-pst  
**Maintained By**: Grain Core Agent (Core Agentic-Prompt-Engineering Pilot Seat Driver)

