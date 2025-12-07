# Grain Core Agent: Comprehensive Coordination Summary

**Date**: 2025-12-07-015717-pst
**Agent**: Grain Core Agent (Core Agentic-Prompt-Engineering Pilot Seat Driver)
**Status**: Phase 61 HTTP Client Complete ✅, Phase 62 File System Enhancements COMPLETE ✅

---

## Executive Summary for All Agents

This document provides comprehensive context and instructions for all 8 Grain agents. Each agent should read their specific section and follow the instructions to continue development in a coordinated, conflict-free manner.

**Agents**:
1.  **Grain Core Agent** (System Services) - Coordination Driver
2.  **Grain Silo Agent** (Database)
3.  **Grain Vantage Agent** (VM/Kernel)
4.  **Grain Skate Agent** (Knowledge Graph)
5.  **Grain Bubble Agent** (Design Tool)
6.  **Grain Carry Agent** (Mobile Framework)
7.  **Grain Aurora Agent** (IDE/Browser)
8.  **Grain Workspace Agent** (Desktop Apps)

---

## Critical Style Enforcement: MANDATORY FOR ALL AGENTS

**Grain Style Compliance**: All agents MUST strictly follow Grain Style guidelines.

**Reference**: [`docs/grain_style.md`](../grain_style.md)

### Required Rules:

1.  **Function Names**: Use `grain_case` (snake_case) for all functions
2.  **Explicit Types**: Use `u32`/`u64`/`i32`/`i64`, NEVER `usize`/`isize`
3.  **Line Length**: Maximum 100 characters per line (`grainwrap-100`)
4.  **Function Length**: Maximum 70 lines per function (`grain validate-70`)
5.  **Compiler Warnings**: All warnings must be enabled and resolved
6.  **Bounded Allocations**: Use `MAX_` constants for all bounded allocations
7.  **Assertions**: Minimum 2 assertions per function
8.  **No Recursion**: Avoid recursive functions

**Why Explicit Types Matter**:
-   `usize`/`isize` vary by architecture (32-bit vs. 64-bit)
-   Explicit types ensure consistent behavior across all target platforms (RISC-V, macOS Tahoe, etc.)
-   Prevents unexpected overflows or truncations
-   Makes code intent clearer and more maintainable

**Enforcement Reference**: [`docs/agent-communications/grain_style_u32_u64_enforcement_prompt.md`](grain_style_u32_u64_enforcement_prompt.md)

---

## Dependency Architecture: Corrected Understanding

### Critical Path Dependencies

```
macOS 26.1 Tahoe (Host OS)
    ↓ (runs)
Grain Vantage VM (ARM64, macOS only) [Development Host / VM Layer]
    ↓ (emulates RISC-V hardware for)
Grain Basin Kernel (RISC-V64) [Layer 2: Foundation]
    ↓ (provides syscalls to)
Grain Core Agent (System Services) [Layer 3: System Services]
    ↓ (provides services to)
    ├─→ Grain Silo Agent (Database) [needs: API Server ✅, WebSocket ✅, File System ✅, HTTP Client ✅ COMPLETE]
    ├─→ Grain Carry Agent (Mobile) [needs: API Server ✅, Auth ✅, WebSocket ✅, HTTP Client ✅]
    ├─→ Grain Workspace Agent (Desktop Apps) [needs: System Services ✅]
    └─→ Grain Bubble Agent (Design Tool) [needs: Compositor ✅, Rendering ✅]

Grain Aurora Agent (IDE/Browser) [Mostly independent, integrates with Core/Basin for specific features]
Grain Skate Agent (Knowledge Graph) [Mostly independent, integrates with Core/Basin for specific features]
```

**Key Points**:
-   **Vantage is NOT in the dependency chain** — it's the macOS host for development
-   **Core depends on Basin** (RISC-V kernel), NOT on Vantage
-   **All agents depend on Basin and Core**, NOT on Vantage
-   **Vantage is only for development** — production runs on RISC-V hardware

---

## Agent-Specific Instructions

### For Grain Silo Agent (Database)

**Current Status**: Phase 7 Database Persistence Integration — IN PROGRESS
-   Phase 6: API Server Integration ✅ COMPLETE
-   Phase 7: Database Persistence 🔄 IN PROGRESS (unblocked by Core Agent Phase 62)
-   Phase 9: Authentication Integration 🔄 IN PROGRESS

**Available from Grain Core Agent**:
-   ✅ API Server (Phase 59) — Complete
-   ✅ WebSocket Support (Phase 61) — Complete
-   ✅ File System Enhancements (Phase 62) — Complete
  -   File Storage Manager (`file_storage.zig`)
  -   WAL Manager (`wal_manager.zig`)
  -   Index Manager (`index_manager.zig`)
  -   Backup Manager (`backup_manager.zig`)
-   ✅ HTTP Client (Phase 61) — Complete

**Your Instructions**:
1.  Continue as you best recommend, given the context
2.  Remember to follow Grain Style (`~/xy-mathematics/docs/grain_style.md`) with `grain_case` function names and all the strict rules with all compiler warnings turned on
3.  Specifically enforce `grainwrap-100` and `grain validate-70`
4.  Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms
5.  Continue the next phase of implementation and when you're done update your `docs/plans/plan_database.md` and `docs/tasks/tasks_database.md` keeping the general summary `docs/plan.md` and `docs/tasks.md` in thinking
6.  Let us know when you need to check in with me about upcoming integration steps with the other agents so that we prevent accidental conflicts
7.  Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement their API contracts

**Next Steps**:
-   Integrate file storage with database endpoints
-   Integrate WAL manager for transaction logging
-   Integrate index manager for efficient queries
-   Integrate backup manager for data protection
-   Test complete database persistence and recovery
-   Update documentation

**Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

---

### For Grain Carry Agent (Mobile Framework)

**Current Status**: Email Service for OTP Delivery Complete
-   Phase 1-4: Core modules, crypto, authentication, style system ✅ Complete
-   API Client Module ✅ Complete
-   Email Service ✅ Complete

**Available from Grain Core Agent**:
-   ✅ API Server (Phase 59) — Complete
-   ✅ Authentication Service (Phase 60) — Complete
-   ✅ WebSocket Support (Phase 61) — Complete
-   ✅ HTTP Client (Phase 61) — Complete

**Your Instructions**:
1.  Continue as you best recommend, given the context
2.  Remember to follow Grain Style (`~/xy-mathematics/docs/grain_style.md`) with `grain_case` function names and all the strict rules with all compiler warnings turned on
3.  Specifically enforce `grainwrap-100` and `grain validate-70`
4.  Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms
5.  Continue the next phase of implementation and when you're done update your `docs/plans/plan_carry.md` and `docs/tasks/tasks_carry.md` keeping the general summary `docs/plan.md` and `docs/tasks.md` in thinking
6.  Let us know when you need to check in with me about upcoming integration steps with the other agents so that we prevent accidental conflicts
7.  Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement their API contracts

**Next Steps**:
-   Implement WebSocket client in Grain Mobile Core
-   Integrate with API endpoints
-   Test WebSocket client connectivity
-   Update documentation

**Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

---

### For Grain Vantage Agent (VM/Kernel)

**Current Status**: Phase 4 Complete ✅, Ready for Next Phase
-   Phase 4: Network Syscalls ✅ COMPLETE
-   Network Interface Management ✅
-   TCP Syscalls ✅
-   UDP Syscalls ✅
-   Network Tests ✅

**Your Instructions**:
1.  Continue as you best recommend, given the context
2.  Remember to follow Grain Style (`~/xy-mathematics/docs/grain_style.md`) with `grain_case` function names and all the strict rules with all compiler warnings turned on
3.  Specifically enforce `grainwrap-100` and `grain validate-70`
4.  Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms
5.  Continue the next phase of implementation and when you're done update your `docs/plans/plan_vantage.md` and `docs/tasks/tasks_vantage.md` keeping the general summary `docs/plan.md` and `docs/tasks.md` in thinking
6.  Let us know when you need to check in with me about upcoming integration steps with the other agents so that we prevent accidental conflicts
7.  Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement their API contracts

**Next Steps**:
-   Review plan for next kernel phase
-   Coordinate with Core Agent on syscall interface design
-   Update documentation

**Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

---

### For Grain Aurora Agent (IDE/Browser)

**Current Status**: Active — Foundation components, shared modules
-   Shared module refactoring (Phase 2) ✅
-   LSP implementation ✅
-   Editor enhancements ✅
-   DAG Integration Planning (with Bubble Agent) 🔄

**Your Instructions**:
1.  Continue as you best recommend, given the context
2.  Remember to follow Grain Style (`~/xy-mathematics/docs/grain_style.md`) with `grain_case` function names and all the strict rules with all compiler warnings turned on
3.  Specifically enforce `grainwrap-100` and `grain validate-70`
4.  Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms
5.  Continue the next phase of implementation and when you're done update your `docs/plans/plan_aurora.md` and `docs/tasks/tasks_aurora.md` keeping the general summary `docs/plan.md` and `docs/tasks.md` in thinking
6.  Let us know when you need to check in with me about upcoming integration steps with the other agents so that we prevent accidental conflicts
7.  Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement their API contracts

**Next Steps**:
-   Continue LSP features
-   Continue editor enhancements
-   Continue browser improvements
-   Coordinate only when modifying shared modules

**Can Work In Parallel With**: All agents (except when coordinating shared modules)

---

### For Grain Skate Agent (Knowledge Graph)

**Current Status**: Phase 3 Complete, Creative Enhancements Planned
-   Shared font renderer ✅
-   Bracket matching ✅
-   Language-specific syntax highlighting ✅
-   Core editor features ✅
-   Graph visualization ✅

**Your Instructions**:
1.  Continue as you best recommend, given the context
2.  Remember to follow Grain Style (`~/xy-mathematics/docs/grain_style.md`) with `grain_case` function names and all the strict rules with all compiler warnings turned on
3.  Specifically enforce `grainwrap-100` and `grain validate-70`
4.  Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms
5.  Continue the next phase of implementation and when you're done update your `docs/plans/plan_skate.md` and `docs/tasks/tasks_skate.md` keeping the general summary `docs/plan.md` and `docs/tasks.md` in thinking
6.  Let us know when you need to check in with me about upcoming integration steps with the other agents so that we prevent accidental conflicts
7.  Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement their API contracts

**Next Steps**:
-   Continue syntax highlighting improvements
-   Continue graph features
-   Continue terminal improvements
-   Coordinate only when modifying shared modules

**Can Work In Parallel With**: All agents (except when coordinating shared modules)

---

### For Grain Workspace Agent (Desktop Apps)

**Current Status**: Phase 10.2 WebSocket Integration Complete ✅
-   All Phases Complete ✅
-   Phase 1-9: All desktop applications complete
-   Phase 10.2: WebSocket Integration ✅

**Your Instructions**:
1.  Continue as you best recommend, given the context
2.  Remember to follow Grain Style (`~/xy-mathematics/docs/grain_style.md`) with `grain_case` function names and all the strict rules with all compiler warnings turned on
3.  Specifically enforce `grainwrap-100` and `grain validate-70`
4.  Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms
5.  Continue the next phase of implementation and when you're done update your `docs/plans/plan_workspace.md` and `docs/tasks/tasks_workspace.md` keeping the general summary `docs/plan.md` and `docs/tasks.md` in thinking
6.  Let us know when you need to check in with me about upcoming integration steps with the other agents so that we prevent accidental conflicts
7.  Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement their API contracts

**Next Steps**:
-   Continue desktop app development
-   Integrate with OS system services
-   Update documentation

**Can Work In Parallel With**: Aurora, Skate, Bubble Phase 1

---

### For Grain Bubble Agent (Design Tool)

**Current Status**: Phase 2 Core Complete ✅ — Component System (Core Features) ✅
-   Phase 1: Core Canvas (SLC v1.0) ✅ COMPLETE
-   Phase 2: Component System (Core Features) ✅ COMPLETE
-   Export PDF functionality ✅

**Your Instructions**:
1.  Continue as you best recommend, given the context
2.  Remember to follow Grain Style (`~/xy-mathematics/docs/grain_style.md`) with `grain_case` function names and all the strict rules with all compiler warnings turned on
3.  Specifically enforce `grainwrap-100` and `grain validate-70`
4.  Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms
5.  Continue the next phase of implementation and when you're done update your `docs/plans/plan_bubble.md` and `docs/tasks/tasks_bubble.md` keeping the general summary `docs/plan.md` and `docs/tasks.md` in thinking
6.  Let us know when you need to check in with me about upcoming integration steps with the other agents so that we prevent accidental conflicts
7.  Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement their API contracts

**Next Steps**:
-   Continue component system implementation
-   Integrate with OS compositor
-   Update documentation

**Can Work In Parallel With**: Aurora, Skate, Workspace

---

## Coordination and Conflict Prevention

### When to Check In

All agents should check in with Grain Core Agent when:
1.  Modifying shared modules (font renderer, text buffer, DAG, etc.)
2.  Changing API contracts that other agents depend on
3.  Adding new dependencies on other agents' modules
4.  Planning major refactoring that might affect other agents
5.  Encountering integration issues that require coordination

### Conflict Prevention Strategy

1.  **Shared Modules**: Coordinate before modifying shared modules
2.  **API Contracts**: Document and communicate API changes
3.  **Dependencies**: Update dependency matrix when adding new dependencies
4.  **Testing**: Ensure all tests pass before committing
5.  **Documentation**: Update plans and tasks immediately after completing work

---

## Testing Requirements

All agents must ensure:
1.  All existing tests pass
2.  All new tests pass
3.  Tests implement their API contracts correctly
4.  Tests follow Grain Style (`grainwrap-100`, `grain validate-70`)
5.  Tests use explicit types (`u32`/`u64`, not `usize`/`isize`)

---

## Documentation Requirements

All agents must update:
1.  `docs/plans/plan_{agent-name}.md` — Development plan
2.  `docs/tasks/tasks_{agent-name}.md` — Task list
3.  `docs/plan.md` — General summary (when major milestones reached)
4.  `docs/tasks.md` — General task summary (when major milestones reached)

---

## Standard Agent Prompt Template

When responding to Grain Core Agent, use this template:

```
continue as you best recommend, remember to follow Grain Style (~/xy-mathematics/docs/grain_style.md ) with grain_case function names and all the strict rules with all compiler warnings turned on

continue the next phase of implementation and when you're done update the docs/plans/plan_{agent-name}.md and docs/tasks/tasks_{agent-name}.md keeping the general summary docs/plan.md and docs/tasks.md in thinking. let me know when you need me to check in with the other agents to prevent conflicts. also make sure all existing and new tests pass that implement their API contracts, enforcing grainwrap-100 and grain validate-70

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your printout summary header

when you're done, git push add all to main with Grain Style commit message when done with same timestamp ,  and create and print a new core agent coordination plan for all agents with the same timestamp in the filename

your agent name is: {Agent Name}
```

---

## Grain Style Compliance: Explicit types (u32/u64, no usize) enforced.

**Status**: All agents must comply immediately.

---

**End of Coordination Summary**

