# Grain Core Agent Summary

**Date**: 2025-12-21-183510-pst  
**Agent**: Grain Core Agent (Core Agentic-Prompt-Engineering Pilot Seat Driver)  
**Status**: Basin Spec Freeze Complete ✅, Vantage Adaptation Priority Defined ✅, Prioritized Action Plan Created ✅

---

## Executive Summary

This summary provides comprehensive context for all 11 Grain agents, derived from the latest coordination plan. This summary includes the **Basin Kernel Specification Freeze** (frozen syscall interface, data structures, error codes, memory model), **Vantage VM Adaptation Priority** (macOS Tahoe beta version support), and **Prioritized Action Plan** for cross-agent coordination.

**Key Focus Areas**:
1. **Basin Spec Freeze**: Basin kernel specification frozen (syscall interface, data structures, error codes, memory model) — provides stable foundation for all agents
2. **Vantage Adaptation**: Vantage VM adaptation framework priority (macOS version detection, isolation layer, feature flags, JIT adaptation) — enables macOS Tahoe beta support
3. **SLC Products**: Nostr Profile Builder, DAG Website Builder, Workspace App Suite (building for people, not systems)
4. **ZON Format Integration**: Multi-agent coordination (Flow, Research, Court, Grainscript) for 35-70% token reduction
5. **Cross-Agent Coordination**: Prioritized action plan for unblocking agents and coordinating dependencies

**Agents**:
1.  **Grain Core Agent** (System Services)
2.  **Grain Silo Agent** (Database)
3.  **Grain Vantage Agent** (VM/Kernel)
4.  **Grain Skate Agent** (Knowledge Graph)
5.  **Grain Bubble Agent** (Design Tool)
6.  **Grain Carry Agent** (Mobile Framework)
7.  **Grain Aurora Agent** (IDE/Browser)
8.  **Grain Workspace Agent** (Desktop Apps)
9.  **Grain Flow Agent** (Workflow Orchestration)
10. **Grain Research Agent** (Research & Analysis)
11. **Grain Court Agent** (LLM Infrastructure)

---

## Previous Coordination Plan Completion Status

### Completed from Previous Plan (2025-12-21-141612-pst):

**Grain Core Agent**:
- ✅ Coordination plan created for 11 agents
- ✅ Comprehensive summary created
- ✅ All agent statuses updated
- ✅ Basin Spec Freeze document created (`docs/vantage_verification/basin_spec_freeze_2025-12-21-163457-pst.md`)
- ✅ Vantage/Basin Next Steps prioritized action plan created (`docs/agent-communications/vantage_basin_next_steps_2025-12-21-163457-pst.md`)

**Grain Vantage Agent**:
- ✅ Basin Kernel Specification Freeze Complete ✅ (2025-12-21-163457-pst)
  - Syscall interface frozen (all syscall numbers, signatures, behavior)
  - Data structures frozen (public API stable)
  - Error codes frozen (error semantics stable)
  - Memory model frozen (RISC-V64 memory layout stable)
- ✅ Phase 6.4 Cross-Platform Compatibility COMPLETE ✅
- ✅ Kernel-Level Verification COMPLETE ✅
- ⏳ Vantage VM Adaptation Framework (macOS Tahoe 26.3 Beta) — Priority 1

**All Agents**:
- ✅ Agent statuses updated across all plan files
- ✅ Core-coordination files maintained by all agents
- ✅ Documentation synchronized
- ✅ Git commits with Grain Style messages

**Previous Next Steps Verified (from 2025-12-21-141612-pst)**:
- ✅ Vantage Agent: Basin Spec Freeze Complete ✅ — Basin kernel specification frozen, Vantage adaptation priority defined
- ✅ Core Agent: Prioritized Action Plan Created ✅ — Vantage/Basin next steps and cross-agent coordination priorities identified
- ✅ All agents: Core-coordination files updated with latest statuses

**New Progress Since Last Plan (2025-12-21-141612-pst)**:
- ✅ **Basin Kernel Specification Freeze Complete ✅** - New milestone! (2025-12-21-163457-pst)
  - Basin kernel specification frozen (syscall interface, data structures, error codes, memory model)
  - Versioning strategy defined (MAJOR.MINOR.PATCH)
  - Change approval process defined
  - Provides stable foundation for all agents
- ✅ **Vantage/Basin Prioritized Action Plan Created ✅** - New milestone! (2025-12-21-163457-pst)
  - Priority 1: Vantage Agent — Vantage Adaptation Framework (CRITICAL, 7-12 days)
  - Priority 2: Core Agent — Coordination Decisions (HIGH, 3-5 days, unblocks 4 agents)
  - Priority 3: Court Agent — ZON Module Phase 1 (HIGH, 4-6 days, unblocks Flow Agent)
  - Priority 4: SLC Product Integration Testing (MEDIUM, 6-9 days, depends on Priority 1)
  - Priority 5: Other Agent Coordination (MEDIUM, can proceed in parallel)
- ✅ **Research Agent: ZON Format Phase 3 Complete ✅** - New milestone! (2025-12-21-154500-pst)
  - Cost savings calculator complete (13-16% cost savings, $10.37/month for 4 use cases)
  - Cost savings documentation complete
  - Phase 4 pending (requires Court Agent ZON module)
- ✅ **Aurora Agent: Phase 2.20 Complete ✅** - New milestone! (2025-12-21-180551-pst)
  - Crash Handler Comprehensive Tests complete
  - 16 modules with comprehensive test coverage
  - Dream Browser Spec v0 coordination request sent to Core Agent
- ✅ **Court Agent: Phase 1 Complete ✅** - New milestone! (2025-12-21-150000-pst)
  - Multi-Provider LLM API Foundation complete
  - Provider abstraction interface complete
  - OpenAI, Anthropic, Mistral providers complete
  - Ready for Phase 2 (ZON format integration)

---

## Major Milestones: Basin Spec Freeze ✅ & Vantage Adaptation Priority ✅ & Prioritized Action Plan ✅

### Basin Kernel Specification Freeze: Complete ✅
**Status**: ✅ FREEZE COMPLETE (2025-12-21-163457-pst)

**Frozen Components**:
- **Syscall Interface**: All 131 syscall numbers, signatures, and behavior frozen
- **Data Structures**: All public data structures frozen (stable API)
- **Error Codes**: All error code values and semantics frozen
- **Memory Model**: RISC-V64 memory layout frozen

**Versioning**: Basin kernel is now `1.0.0` (specification freeze)

**Change Policy**:
- ❌ **NO NEW SYSCALLS** without major version bump
- ❌ **NO CHANGES TO EXISTING SYSCALLS** (numbers, signatures, behavior)
- ✅ **ALLOWED**: Bug fixes that don't change behavior
- ✅ **ALLOWED**: Performance optimizations that preserve behavior

**Enables**:
- Stable foundation for all agents
- Predictable kernel API for userspace development
- Clear versioning and change approval process

**Location**: `docs/vantage_verification/basin_spec_freeze_2025-12-21-163457-pst.md`

### Vantage VM Adaptation Priority: Defined ✅
**Status**: ✅ PRIORITY DEFINED (2025-12-21-163457-pst)

**Priority**: **CRITICAL** — Enables macOS Tahoe beta version support while maintaining Basin spec stability

**Adaptation Framework Components**:
1. **macOS Version Detection System** (1-2 days)
2. **Isolation Layer Design** (2-3 days)
3. **Feature Flag System** (1-2 days)
4. **JIT Compilation Adaptation** (2-3 days)
5. **VM Statistics & Profiling Adaptation** (1-2 days)

**Total Estimated Time**: 7-12 days  
**Coordination**: Independent work, no blockers

**Enables**:
- macOS Tahoe 26.3 Beta support
- Future macOS Tahoe beta version support
- Basin spec stability (Vantage adapts, Basin stays frozen)

**Location**: `docs/agent-communications/vantage_basin_next_steps_2025-12-21-163457-pst.md`

### Prioritized Action Plan: Created ✅
**Status**: ✅ PLAN CREATED (2025-12-21-163457-pst)

**Priorities**:
1. **Priority 1**: Vantage Agent — Vantage Adaptation Framework (CRITICAL, 7-12 days)
2. **Priority 2**: Core Agent — Coordination Decisions (HIGH, 3-5 days, unblocks 4 agents)
3. **Priority 3**: Court Agent — ZON Module Phase 1 (HIGH, 4-6 days, unblocks Flow Agent)
4. **Priority 4**: SLC Product Integration Testing (MEDIUM, 6-9 days, depends on Priority 1)
5. **Priority 5**: Other Agent Coordination (MEDIUM, can proceed in parallel)

**Key Decisions Needed**:
1. **TigerBeetle Enhancement Priority**: High / Medium / Low?
2. **DNS Resolution Approach**: Wait for Zig 0.16.0 / Workaround / Defer?
3. **Async Response Handling**: Implement / Document / Defer?

**Location**: `docs/agent-communications/vantage_basin_next_steps_2025-12-21-163457-pst.md`

---

## Prioritized Action Plan

### Priority 1: Vantage Agent — Vantage Adaptation Framework (IMMEDIATE)

**Status**: ⏳ **IN PROGRESS** — Basin spec frozen, adaptation framework needed  
**Priority**: **CRITICAL** — Enables macOS Tahoe beta version support  
**Blocks**: None (independent work)

**Immediate Tasks**:
1. macOS Version Detection System (1-2 days)
2. Isolation Layer Design (2-3 days)
3. Feature Flag System (1-2 days)
4. JIT Compilation Adaptation (2-3 days)
5. VM Statistics & Profiling Adaptation (1-2 days)

**Total Estimated Time**: 7-12 days  
**Coordination**: Independent work, no blockers

---

### Priority 2: Core Agent — Coordination Decisions (IMMEDIATE)

**Status**: ⏳ **AWAITING DECISIONS** — Multiple agents waiting on Core Agent  
**Priority**: **HIGH** — Unblocks multiple agents  
**Blocks**: Flow Agent, Research Agent, Aurora Agent, Carry Agent

**Immediate Tasks**:
1. **TigerBeetle Enhancement Priority Decision** (1 day)
   - **Requested By**: Research Agent, Flow Agent
   - **Decision Needed**: Prioritize TigerBeetle enhancement coordination?
   - **Impact**: Unblocks Research Agent, Flow Agent
   - **Recommendation**: Option B (Medium Priority) — Focus on SLC products and Vantage adaptation first

2. **DNS Resolution for Aurora Agent** (1 day)
   - **Requested By**: Aurora Agent
   - **Status**: Aurora Agent blocked by Zig 0.15.2 comptime issue
   - **Decision Needed**: 
   - **Recommendation**: Option A (Wait for Zig 0.16.0) — Defer until Zig 0.16.0 is stable

3. **Async Response Handling Pattern** (1 day)
   - **Requested By**: Carry Agent
   - **Decision Needed**: Define async HTTP response handling pattern
   - **Impact**: Unblocks Carry Agent database integration
   - **Recommendation**: Option B (Provide Pattern Documentation) — Document pattern for Carry Agent

**Total Estimated Time**: 3-5 days  
**Coordination**: Unblocks Flow, Research, Aurora, Carry agents

---

### Priority 3: Court Agent — ZON Module Phase 1 (HIGH)

**Status**: ⏳ **READY TO START** — Court Agent Phase 1 foundation complete  
**Priority**: **HIGH** — Unblocks Flow Agent ZON integration  
**Blocks**: Flow Agent ZON format integration

**Immediate Tasks**:
1. ZON Format Module Implementation (3-5 days)
   - Core ZON encoder/decoder
   - Type-safe Zig data ↔ ZON conversion
   - Tabular array encoding (efficient)
   - Integration with Grain Court LLM provider

2. Flow Agent Coordination (1 day)
   - Coordinate API contracts with Flow Agent
   - Define integration points
   - Test ZON format with Flow Agent metrics

**Total Estimated Time**: 4-6 days  
**Coordination**: Unblocks Flow Agent ZON format integration

---

### Priority 4: SLC Product Integration Testing (MEDIUM)

**Status**: ⏳ **AWAITING VANTAGE ADAPTATION** — Vantage adaptation needed first  
**Priority**: **MEDIUM** — Depends on Vantage adaptation completion  
**Blocks**: None (depends on Priority 1)

**Tasks (After Vantage Adaptation Complete)**:
1. Nostr Profile Builder Testing (2-3 days)
2. DAG Website Builder Testing (2-3 days)
3. Workspace App Suite Testing (2-3 days)

**Total Estimated Time**: 6-9 days  
**Coordination**: Requires Vantage adaptation completion, multi-agent coordination

---

### Priority 5: Other Agent Coordination (MEDIUM)

**Status**: ⏳ **READY FOR COORDINATION** — Multiple agents ready  
**Priority**: **MEDIUM** — Can proceed in parallel with other priorities

**Ready Agents**:
- **Workspace Agent**: Ready for coordination, no blockers
- **Bubble Agent**: Ready for coordination, waiting on Core Agent
- **Skate Agent**: Ready for Court Agent migration (Court Agent Phase 1 is COMPLETE ✅)
- **Silo Agent**: Ready for production use, no blockers

---

## Agent Status Summary

### Grain Vantage Agent (1st Agent)

**Status**: Phase 6.4 COMPLETE ✅, Basin Spec Freeze Complete ✅, Vantage Adaptation Priority 1 ⏳

**Completed**:
- ✅ Phase 6.4 Cross-Platform Compatibility COMPLETE
- ✅ Kernel-Level Verification COMPLETE
- ✅ Basin Kernel Specification Freeze Complete (2025-12-21-163457-pst)

**Current Work**:
- ⏳ **Priority 1**: Vantage VM Adaptation Framework (macOS Tahoe 26.3 Beta)
  - macOS version detection system
  - Isolation layer design
  - Feature flag system
  - JIT compilation adaptation
  - VM statistics & profiling adaptation

**Next Steps**:
1. **IMMEDIATE**: Start Vantage adaptation framework implementation
2. **SHORT-TERM**: Complete adaptation framework (7-12 days)
3. **MEDIUM-TERM**: Support SLC product integration testing

**Coordination**:
- **Providing To**: Core Agent (kernel syscalls), All agents (VM capabilities, kernel foundation)
- **Using From**: Core Agent (feature priorities, API design coordination)
- **Coordinating With**: Core Agent (SLC product integration testing coordination)

---

### Grain Core Agent (System Services)

**Status**: Coordination and Infrastructure, Prioritized Action Plan Created ✅

**Completed**:
- ✅ Phase 61 HTTP Client Complete
- ✅ Phase 62 File System Enhancements Complete
- ✅ Basin Spec Freeze coordination complete
- ✅ Prioritized Action Plan created

**Current Work**:
- ⏳ **Priority 2**: Coordination Decisions (IMMEDIATE)
  1. TigerBeetle Enhancement Priority Decision (unblocks Flow/Research)
  2. DNS Resolution Approach (unblocks Aurora)
  3. Async Response Handling Pattern (unblocks Carry)

**Next Steps**:
1. **IMMEDIATE**: Make coordination decisions (TigerBeetle priority, DNS resolution, async handling)
2. **SHORT-TERM**: Implement coordination decisions
3. **MEDIUM-TERM**: Support SLC product integration testing

**Coordination**:
- **Providing To**: All agents (API Server, Auth, WebSocket, HTTP Client, File System)
- **Coordinating With**: All agents (coordination plans, status updates, conflict prevention)

---

### Grain Court Agent (11th Agent)

**Status**: Phase 1 COMPLETE ✅, Phase 2 READY FOR COORDINATION ⏳

**Completed**:
- ✅ Phase 1 Multi-Provider LLM API Foundation COMPLETE
  - Provider abstraction interface complete
  - OpenAI, Anthropic, Mistral providers complete
  - Comprehensive tests complete

**Current Work**:
- ⏳ **Priority 3**: ZON Module Phase 1 (HIGH)
  - Core ZON encoder/decoder
  - Type-safe Zig data ↔ ZON conversion
  - Flow Agent coordination

**Next Steps**:
1. **IMMEDIATE**: Start ZON Module Phase 1 implementation (3-5 days)
2. **SHORT-TERM**: Coordinate with Flow Agent on API contracts
3. **MEDIUM-TERM**: Phase 3 Token Efficiency Optimization

**Coordination**:
- **Providing To**: Aurora Agent (AI provider abstraction), Skate Agent (AI insights), Flow Agent (ZON format)
- **Using From**: Core Agent (HTTP Client, WebSocket, API Server), Flow Agent (ZON format proposal)
- **Coordinating With**: Flow Agent (ZON format integration — READY FOR PHASE 2)

---

### Grain Flow Agent (9th Agent)

**Status**: All Phases Complete ✅, ZON Format Integration Coordinating ⏳

**Completed**:
- ✅ Phase 1-5 COMPLETE (all core phases)
- ✅ Phase 3 Validation COMPLETE
- ✅ ZON format proposal created

**Current Work**:
- ⏳ **Waiting on Court Agent**: ZON Module Phase 1 (blocks ZON format integration)
- ⏳ **Waiting on Core Agent**: TigerBeetle enhancement priority decision
- ⏳ **Waiting on Core Agent**: Build configuration guidance

**Next Steps**:
1. **IMMEDIATE**: Wait for Court Agent ZON module (Priority 3)
2. **SHORT-TERM**: Integrate ZON format with Court Agent ZON module
3. **MEDIUM-TERM**: TigerBeetle enhancement coordination (when Core Agent decides priority)

**Coordination**:
- **Providing To**: Research Agent (workflow metrics), Court Agent (ZON format proposal)
- **Using From**: Core Agent (API Server), Court Agent (ZON module — waiting)
- **Coordinating With**: Court Agent (ZON format integration), Research Agent (workflow observability)

---

### Grain Research Agent (10th Agent)

**Status**: Phase 1 IN PROGRESS, ZON Format Phase 1-3 Complete ✅, Phase 4 Pending ⏳

**Completed**:
- ✅ ZON Format Phase 1: Token Count Validation Complete (~34% average reduction)
- ✅ ZON Format Phase 2: Retrieval Accuracy Framework Complete
- ✅ ZON Format Phase 3: Cost Savings Estimation Complete (13-16% cost savings, $10.37/month)
- ✅ TigerBeetle code archival analysis complete

**Current Work**:
- ⏳ **Waiting on Court Agent**: ZON Module Phase 1 (blocks Phase 4 integration validation)
- ⏳ **Waiting on Core Agent**: TigerBeetle enhancement priority decision

**Next Steps**:
1. **IMMEDIATE**: Wait for Court Agent ZON module (Priority 3)
2. **SHORT-TERM**: Phase 4 Integration Validation (when Court Agent ZON module available)
3. **MEDIUM-TERM**: TigerBeetle enhancement coordination (when Core Agent decides priority)

**Coordination**:
- **Providing To**: Flow Agent (workflow metrics analysis), Court Agent (token efficiency validation)
- **Using From**: Flow Agent (workflow metrics data), Court Agent (ZON module — waiting)
- **Coordinating With**: Flow Agent (workflow observability), Court Agent (token efficiency validation)

---

### Grain Aurora Agent (7th Agent)

**Status**: Phase 2.20 Complete ✅, Dream Browser Spec v0 Coordination Requested ⏳

**Completed**:
- ✅ Phase 2.20 Crash Handler Comprehensive Tests Complete
- ✅ 16 modules with comprehensive test coverage
- ✅ Dream Browser Spec v0 coordination request sent to Core Agent

**Current Work**:
- ⏳ **Waiting on Core Agent**: DNS resolution approach decision (blocks Dream Browser Spec v0)
- ⏳ **Blocked**: Zig 0.15.2 comptime evaluation issue (Editor Comprehensive Tests)

**Next Steps**:
1. **IMMEDIATE**: Wait for Core Agent DNS resolution decision (Priority 2)
2. **SHORT-TERM**: Dream Browser Spec v0 integration (when DNS resolution available)
3. **MEDIUM-TERM**: Continue comprehensive test suites

**Coordination**:
- **Providing To**: All agents (shared modules), Court Agent (AI provider integration)
- **Using From**: Core Agent (DNS resolution — waiting), Court Agent (LLM infrastructure)
- **Coordinating With**: Core Agent (DNS resolution, network stack), Court Agent (AI provider abstraction)

---

### Grain Carry Agent (6th Agent)

**Status**: Database Integration Enhanced ✅, Async Response Handling Pending ⏳

**Completed**:
- ✅ Database integration foundation complete
- ✅ JSON request/response handling complete
- ✅ Silo Agent API contracts received and reviewed

**Current Work**:
- ⏳ **Waiting on Core Agent**: Async HTTP response handling pattern (blocks database integration)
- ⏳ **Coordinating**: Silo Agent integration approach confirmation

**Next Steps**:
1. **IMMEDIATE**: Wait for Core Agent async response handling pattern (Priority 2)
2. **SHORT-TERM**: Integrate async response handling into database operations
3. **MEDIUM-TERM**: Complete Silo Agent integration

**Coordination**:
- **Providing To**: None (mobile framework)
- **Using From**: Core Agent (HTTP Client, API Server, Auth), Silo Agent (database API)
- **Coordinating With**: Core Agent (async response handling), Silo Agent (database integration)

---

### Grain Workspace Agent (8th Agent)

**Status**: Phases 21-24 Complete ✅, Ready for Coordination ✅

**Completed**:
- ✅ Phase 21: DevTools Grain Style Linter Complete
- ✅ Phase 22: Standalone CLI Tool Complete
- ✅ Phase 23: Enhanced CLI Output and Configuration Complete
- ✅ Phase 24: Recursive Directory Linting Complete
- ✅ Production-ready Grain Style CLI tool

**Current Work**:
- ⏳ Ready for next phase implementation
- ⏳ Ready for SLC product integration

**Next Steps**:
1. **IMMEDIATE**: Continue next phase implementation (independent work)
2. **SHORT-TERM**: SLC product integration (Workspace App Suite)
3. **MEDIUM-TERM**: Continue desktop app development

**Coordination**:
- **Providing To**: All agents (Grain Style CLI tool)
- **Using From**: Core Agent (System Services)
- **Coordinating With**: Core Agent (SLC product integration), Aurora Agent (editor integration)

---

### Grain Bubble Agent (5th Agent)

**Status**: SLC UI Components Complete ✅, Ready for Coordination ✅

**Completed**:
- ✅ SLC UI components module complete
- ✅ Design patterns and animations complete
- ✅ Preset design patterns for SLC products complete

**Current Work**:
- ⏳ Ready for coordination with Aurora and Workspace agents
- ⏳ Waiting on Core Agent to facilitate coordination

**Next Steps**:
1. **IMMEDIATE**: Continue SLC UI component development (independent work)
2. **SHORT-TERM**: Coordinate with Aurora and Workspace agents (when Core Agent facilitates)
3. **MEDIUM-TERM**: SLC product design integration

**Coordination**:
- **Providing To**: All agents (design tools, UI components)
- **Using From**: Core Agent (Compositor, Rendering)
- **Coordinating With**: Core Agent (coordination facilitation), Aurora Agent (editor integration), Workspace Agent (desktop app integration)

---

### Grain Skate Agent (4th Agent)

**Status**: Ready for Court Agent Migration ✅, Court Agent Phase 1 COMPLETE ✅

**Completed**:
- ✅ All core functionality complete
- ✅ AI insights functions complete and validated
- ✅ Ready for LLM infrastructure migration

**Current Work**:
- ⏳ **Court Agent Phase 1 is COMPLETE ✅** — you're ready to start migration!
- ⏳ Ready to coordinate API contracts and integration approach with Court Agent

**Next Steps**:
1. **IMMEDIATE**: Start coordinating with Court Agent on LLM infrastructure migration
2. **SHORT-TERM**: Coordinate with Court Agent on API contracts and integration approach
3. **MEDIUM-TERM**: Complete Court Agent migration

**Coordination**:
- **Providing To**: All agents (knowledge graph, AI insights)
- **Using From**: Court Agent (LLM infrastructure — ready for migration)
- **Coordinating With**: Court Agent (LLM infrastructure migration)

---

### Grain Silo Agent (2nd Agent)

**Status**: Production Ready ✅, No Blockers ✅

**Completed**:
- ✅ Performance optimizations complete
- ✅ Batch operations complete
- ✅ Statistics functions complete
- ✅ Validation helpers complete
- ✅ Production-ready

**Current Work**:
- ⏳ Ready for SLC product integration
- ⏳ Coordinating with Carry Agent on database integration

**Next Steps**:
1. **IMMEDIATE**: Continue production use (independent work)
2. **SHORT-TERM**: SLC product integration (database support)
3. **MEDIUM-TERM**: Continue performance optimizations

**Coordination**:
- **Providing To**: Carry Agent (database API), All agents (database services)
- **Using From**: Core Agent (API Server, WebSocket, File System)
- **Coordinating With**: Carry Agent (database integration), Core Agent (SLC product integration)

---

## Grain Style Enforcement

**All agents must follow Grain Style** (`docs/grain_style.md`):

- ✅ **grain_case** function names (not camelCase or snake_case)
- ✅ **Explicit types** (`u32`/`u64`, never `usize`/`isize`)
- ✅ **Bounded allocations** (`MAX_` constants)
- ✅ **Minimum 2 assertions per function** (pair assertions)
- ✅ **Max 70 lines per function** (`grain validate-70`)
- ✅ **Max 103 characters per line** (`grainwrap-100` — updated for 103×80 graincards)
- ✅ **All compiler warnings enabled**
- ✅ **No recursion** (iteration only)
- ✅ **Explicit error handling** (error unions, not generic `anyerror`)

**Graincard Constraints**:
- **Line width**: 103 characters (hard wrap)
- **Function length**: max 70 lines
- **Total size**: 103×80 monospace teaching cards (content-only, optimized for portrait 8.5×11" paper)

---

## Instructions for All Agents

**Continue as you and they best recommend**, given the context. Remember to follow Grain Style (`~/xy-mathematics/docs/grain_style.md`) with `grain_case` function names and all the strict rules with all compiler warnings turned on, and specifically enforce `grainwrap-100` and `grain validate-70` and tell them to use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms.

**Continue the next phase of implementation** and when you're done update your `docs/plans/plan_{agent-name}.md` and `docs/tasks/tasks_{agent-name}.md` keeping the general summary `docs/plan.md` and `docs/tasks.md` in thinking. Let us know when you need to check in about upcoming integration steps with the other agents so that we prevent accidental conflicts. Also make sure that all your agent-specific and integration new tests as well as existing tests pass that implement your API contracts.

**Update your core-coordination file** (`docs/core-coordination/core-coordination_{agent-name}.md`) with your latest status, active work, and coordination needs. This helps synchronize cross-agent progress and collaboration.

---

## References

- **Basin Spec Freeze**: [`docs/vantage_verification/basin_spec_freeze_2025-12-21-163457-pst.md`](../vantage_verification/basin_spec_freeze_2025-12-21-163457-pst.md)
- **Vantage/Basin Next Steps**: [`docs/agent-communications/vantage_basin_next_steps_2025-12-21-163457-pst.md`](vantage_basin_next_steps_2025-12-21-163457-pst.md)
- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Master Plan**: [`docs/plan.md`](../plan.md)
- **Coordination Plan**: [`docs/agent-communications/core_agent_coordination_plan_2025-12-21-183510-pst.md`](core_agent_coordination_plan_2025-12-21-183510-pst.md)

---

**Date**: 2025-12-21-183510-pst  
**Agent**: Grain Core Agent  
**Status**: Basin Spec Freeze Complete ✅, Vantage Adaptation Priority Defined ✅, Prioritized Action Plan Created ✅
