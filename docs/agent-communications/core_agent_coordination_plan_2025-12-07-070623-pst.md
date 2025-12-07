# Grain Core Agent Coordination Plan

**Date**: 2025-12-07-070623-pst
**Agent**: Grain Core Agent (Core Agentic-Prompt-Engineering Pilot Seat Driver)
**Status**: Phase 61 HTTP Client Complete ✅, Phase 62 File System Enhancements COMPLETE ✅

---

## Executive Summary

This coordination plan provides a unified strategy for all 10 Grain agents, optimizing parallelization while preventing conflicts. It includes dependency analysis, work sequencing, and agent-specific recommendations.

**Agents**:
1.  **Grain Core Agent** (System Services) - YOU
2.  **Grain Silo Agent** (Database)
3.  **Grain Vantage Agent** (VM/Kernel)
4.  **Grain Skate Agent** (Knowledge Graph)
5.  **Grain Bubble Agent** (Design Tool)
6.  **Grain Carry Agent** (Mobile Framework)
7.  **Grain Aurora Agent** (IDE/Browser)
8.  **Grain Workspace Agent** (Desktop Apps)
9.  **Grain Flow Agent** (Workflow Orchestration)
10. **Grain Research Agent** (Research & Analysis)

---

## Previous Coordination Plan Completion Status

### Completed from Previous Plan (2025-12-07-053107-pst):

**Grain Core Agent**:
- ✅ Phase 61 HTTP Client implementation complete
- ✅ Phase 62 File System Enhancements complete
- ✅ Coordination plan created for 10 agents
- ✅ Comprehensive summary created
- ✅ All agent statuses updated

**All Agents**:
- ✅ Agent statuses updated across all plan files
- ✅ Flow Agent plan created (`docs/plans/plan_flow.md`)
- ✅ Research Agent plan created (`docs/plans/plan_research.md`)
- ✅ Documentation synchronized
- ✅ Git commits with Grain Style messages

**New Progress Since Last Plan**:
- ✅ Vantage Agent: Audio Device Management (Phase 5.1) ✅, Audio I/O Syscalls (Phase 5.3) ✅, Audio Tests (Phase 5.4) ✅, **Phase 5: Audio Device Management — COMPLETE** ✅
- ✅ Flow Agent: **Phase 1 Event Bus Foundation COMPLETE** ✅ (2025-12-07-054000-pst)
  - Event type definitions (enum-based, 13 event types) ✅
  - Event publishing/subscription APIs ✅
  - Event routing engine (iterative matching) ✅
  - Bounded event queue and subscribers ✅
  - Comprehensive tests (11 test cases) ✅
- ✅ Skate Agent: Phase 4 & Phase 5 IN PROGRESS — Core Complete, UI/GLM-4.6 Integration Pending
- ✅ Aurora Agent: Continued LSP and editor enhancements
- ✅ Silo Agent: Continued Phase 7 Database Persistence Integration (Index entry serialization ✅, Index file persistence ✅)
- ✅ Bubble Agent: Phase 4 Export Pipeline Core Complete ✅
- ✅ Carry Agent: OAuth tests added (`tests/128_grain_carry_core_oauth_test.zig`) ✅

---

## Major Milestones: Phase 61 HTTP Client & Phase 62 COMPLETE ✅

### Phase 61: Network Stack Enhancements — HTTP Client Complete ✅
**Status**: ✅ HTTP Client COMPLETE (2025-12-07-004326-pst)

**All Components Completed**:
-   ✅ TCP/UDP Socket Support
-   ✅ WebSocket Support
-   ✅ DNS Resolution
-   ✅ Socket Options (Reuse Address, Keep-Alive, Timeout)
-   ✅ HTTP Client (GET, POST, PUT, DELETE requests)

**Enables**:
-   Full network communication for API Server
-   Real-time features via WebSockets
-   Reliable hostname resolution
-   Configurable socket behavior for performance and stability
-   External API requests for agents (Carry, Silo, Flow, Research, etc.)

**Location**: All modules in `src/grain_core/`:
-   `network_stack.zig` - TCP/UDP sockets, socket options
-   `websocket.zig` - WebSocket protocol implementation
-   `websocket_handshake.zig` - WebSocket HTTP upgrade
-   `dns_resolver.zig` - DNS resolution and caching
-   `http_client.zig` - HTTP client for external API requests

### Phase 62: File System Enhancements — COMPLETE ✅
**Status**: ✅ COMPLETE (2025-12-06-113038-pst)

**All Components Completed**:
-   ✅ Database File Format Support
-   ✅ Page-based Storage with Checksums
-   ✅ File Locking Support
-   ✅ Transaction Log File Management (WAL)
-   ✅ Index File Management
-   ✅ Backup/Restore Capabilities

**Enables**:
-   Complete database persistence for Silo Agent
-   ACID transaction guarantees
-   Efficient database queries via indexes
-   Data protection via backup/restore

**Location**: All modules in `src/grain_core/`:
-   `file_storage.zig` - Database file format and storage
-   `wal_manager.zig` - Write-ahead log for transactions
-   `index_manager.zig` - Index management for queries
-   `backup_manager.zig` - Backup and restore capabilities

---

## Critical Style Enforcement: MANDATORY FOR ALL AGENTS

**Grain Style Compliance**: All agents MUST strictly follow Grain Style guidelines.

**Reference**: `~/xy-mathematics/docs/grain_style.md`

**Required Rules**:
1. **Function Names**: Use `grain_case` (snake_case) for all functions
2. **Explicit Types**: Use `u32`/`u64`/`i32`/`i64`, NEVER `usize`/`isize`
3. **Line Length**: Maximum 100 characters per line (`grainwrap-100`)
4. **Function Length**: Maximum 70 lines per function (`grain validate-70`)
5. **Compiler Warnings**: All warnings must be enabled and resolved
6. **Bounded Allocations**: Use `MAX_` constants for all bounded allocations
7. **Assertions**: Minimum 2 assertions per function
8. **No Recursion**: Avoid recursive functions

**Why Explicit Types Matter**:
- `usize`/`isize` vary by architecture (32-bit vs. 64-bit)
- Explicit types ensure consistent behavior across all target platforms (RISC-V, macOS Tahoe, etc.)
- Prevents unexpected overflows or truncations
- Makes code intent clearer and more maintainable

**Enforcement Reference**: `docs/agent-communications/grain_style_u32_u64_enforcement_prompt.md`

---

## Dependency Analysis: Corrected Architecture

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
    ├─→ Grain Flow Agent (Workflow Orchestration) [needs: API Server ✅, WebSocket ✅, Auth ✅]
    ├─→ Grain Silo Agent (Database) [needs: API Server ✅, WebSocket ✅, File System ✅, HTTP Client ✅ COMPLETE]
    ├─→ Grain Carry Agent (Mobile) [needs: API Server ✅, Auth ✅, WebSocket ✅, HTTP Client ✅]
    ├─→ Grain Workspace Agent (Desktop Apps) [needs: System Services ✅]
    └─→ Grain Bubble Agent (Design Tool) [needs: Compositor ✅, Rendering ✅]

Grain Aurora Agent (IDE/Browser) [Mostly independent, integrates with Core/Basin for specific features]
Grain Skate Agent (Knowledge Graph) [Mostly independent, integrates with Core/Basin for specific features, uses HTTP Client for AI]
Grain Research Agent (Research & Analysis) [Mostly independent, may integrate with Core for data access]
```

**Key Points**:
-   **Vantage is NOT in the dependency chain** — it's the macOS host for development
-   **Core depends on Basin** (RISC-V kernel), NOT on Vantage
-   **All agents depend on Basin and Core**, NOT on Vantage
-   **Vantage is only for development** — production runs on RISC-V hardware
-   **Flow Agent depends on Core** — uses Core's API Server, WebSocket, Auth
-   **Research Agent** — mostly independent, may integrate with Core for data access
-   **Skate Agent** — uses Core's HTTP Client for AI API calls

### Dependency Matrix

| Agent       | Depends On                                     | Provides To                                   | Can Work In Parallel With                 |
|-------------|------------------------------------------------|-----------------------------------------------|-------------------------------------------|
| **Vantage** | macOS 26.1 Tahoe only                          | None (runs Basin, but not a dependency)       | All (separate host layer)                 |
| **Basin**   | None (pure RISC-V)                             | Core, All agents                              | None (foundation layer)                   |
| **Core**    | **Basin** (RISC-V kernel) ✅                   | Flow, Silo, Carry, Workspace, Bubble          | Aurora, Skate, Research                    |
| **Flow**    | **Core** (API ✅, WebSocket ✅, Auth ✅)        | All agents (orchestration)                    | Aurora, Skate, Workspace, Bubble (when not coordinating) |
| **Silo**    | Core (API ✅, WebSocket ✅, File System ✅, HTTP Client ✅ COMPLETE) | Carry                                         | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Carry**   | Core (API ✅, Auth ✅, WebSocket ✅, HTTP Client ✅), Silo       | None                                          | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Aurora**  | None (shared modules)                          | Shared modules                                | All (except when coordinating shared modules) |
| **Skate**   | None (shared modules), Core HTTP Client ✅      | Shared modules                                | All (except when coordinating shared modules) |
| **Workspace** | Core (System Services ✅)                      | None                                          | Aurora, Skate, Bubble (Phase 1)           |
| **Bubble**  | Core (Compositor ✅, Rendering ✅)             | None                                          | Aurora, Skate, Workspace                  |
| **Research** | None (may use Core for data access)            | Analysis and insights                         | All (mostly independent)                   |

---

## Current Priorities & Next Steps for Each Agent

### Grain Core Agent

**Current Priority**: Phase 61 HTTP Client Complete ✅, Phase 62 Complete ✅

**Next Priority**: Coordinate with Flow Agent and Silo Agent on integration or move to next phase
-   **Flow Integration**: Coordinate on Flow Agent's use of Core services (API, WebSocket, Auth)
-   **Silo Integration**: Coordinate on integrating all Phase 61 & Phase 62 enhancements
-   **Next Phase**: Review plan for Phase 63+ or other system enhancements
-   **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1, Research

**Recommendation**: Coordinate with Flow Agent and Silo Agent to ensure integration is smooth, then proceed with next priorities.

### Grain Flow Agent

**Current Priority**: Phase 1 Event Bus Foundation ✅ COMPLETE (2025-12-07-054000-pst)
-   **Status**: Phase 1 COMPLETE — Ready for Phase 2 (Agent Coordinator)
-   **Completed**: Event type definitions, publishing/subscription APIs, routing engine, bounded queues, comprehensive tests
-   **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble (when not coordinating)

**Next Steps**:
1.  Start Phase 2: Agent Coordinator
2.  Implement agent registry (track active agents, MAX_AGENTS: u32 = 64)
3.  Implement agent health monitoring
4.  Implement agent capability discovery
5.  Implement agent-to-agent RPC (via Core API Server)
6.  Create comprehensive tests
7.  Update documentation

### Grain Research Agent

**Current Priority**: Initial Planning — Ready for Phase 1
-   **Why**: Research and analysis capabilities for the Grain OS ecosystem
-   **Can Do Now**: Start Phase 1 planning and implementation
-   **Can Work In Parallel With**: All agents (mostly independent)

**Next Steps**:
1.  Create `src/grain_research/` directory structure
2.  Define research agent scope and goals
3.  Plan integration points with Core Agent (if needed)
4.  Create initial plan document (`docs/plans/plan_research.md`) — ✅ Already created
5.  Create initial task list (`docs/tasks/tasks_research.md`) — ✅ Already created
6.  Begin Phase 1: Research Engine Foundation

### Grain Silo Agent

**Current Priority**: Phase 7 Database Persistence Integration
-   **Why**: Now fully unblocked by Core Agent Phase 62 File System Enhancements (COMPLETE)
-   **Can Do Now**: Integrate all file system enhancements for complete database persistence
-   **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Recent Progress**:
- Index entry serialization (`src/grain_database/index_entry_serialization.zig`) ✅
- Index file persistence (write/read index entries to/from pages) ✅

**Next Steps**:
1.  Continue database persistence integration
2.  Test complete database persistence and recovery
3.  Update documentation

### Grain Carry Agent

**Current Priority**: WebSocket Client Implementation
-   **Why**: Now unblocked by Core Agent Phase 61 WebSocket support
-   **Can Do Now**: Implement WebSocket client for livestream coordination
-   **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Recent Progress**:
- OAuth tests added (`tests/128_grain_carry_core_oauth_test.zig`) ✅

**Next Steps**:
1.  Implement WebSocket client in Grain Mobile Core
2.  Integrate with API endpoints
3.  Test WebSocket client connectivity
4.  Update documentation

### Grain Vantage Agent

**Current Priority**: Phase 5 Audio Device Management COMPLETE ✅
-   **Status**: Phase 5.1 Audio Device Management ✅, Phase 5.3 Audio I/O Syscalls ✅, Phase 5.4 Audio Tests ✅, **Phase 5 COMPLETE** ✅
-   **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1.  Review plan for next kernel phase
2.  Coordinate with Core Agent on syscall interface design
3.  Update documentation

### Grain Aurora Agent

**Current Priority**: Continue independent work
-   **Why**: Mostly independent, shared modules already coordinated
-   **Can Work In Parallel With**: All agents (except when coordinating shared modules)

**Next Steps**:
1.  Continue LSP features
2.  Continue editor enhancements
3.  Continue browser improvements
4.  Coordinate only when modifying shared modules
5.  Coordinate with Skate Agent on GLM-4.6 client integration

### Grain Skate Agent

**Current Status**: Phase 4 & Phase 5 IN PROGRESS — Core Complete, UI/GLM-4.6 Integration Pending
- Phase 2: Text Buffer Unification ✅ COMPLETE
- Phase 3: DAG Integration ✅ COMPLETE
- Phase 4: Temporal Knowledge Graph 🔄 IN PROGRESS (Core Complete, UI Pending)
- Phase 5: AI-Powered Graph Insights 🔄 IN PROGRESS (Foundation Complete, GLM-4.6 Integration Pending)

**Available from Grain Core Agent**:
- ✅ HTTP Client (Phase 61) — Complete (for AI API calls)
- ✅ WebSocket Support (Phase 61) — Complete (for future collaborative features)

**Your Instructions**:
1. Continue as you best recommend, given the context
2. Remember to follow Grain Style (`~/xy-mathematics/docs/grain_style.md`) with `grain_case` function names and all the strict rules with all compiler warnings turned on
3. Specifically enforce `grainwrap-100` and `grain validate-70`
4. Use explicitly bound `u32`/`u64` not `usize`/`isize`, so our code is consistent across all compile target platforms
5. Continue the next phase of implementation and when you're done update your `docs/plans/plan_skate.md` and `docs/tasks/tasks_skate.md` keeping the general summary `docs/plan.md` and `docs/tasks.md` in thinking
6. Let us know when you need to check in with me about upcoming integration steps with the other agents so that we prevent accidental conflicts
7. Make sure that all your agent-specific and integration new tests as well as existing tests pass that implement their API contracts

**Next Steps**:
- Phase 4: Add time slider UI component to graph renderer
- Phase 4: Add animated transitions showing graph growth
- Phase 5: Integrate with `src/aurora_glm46.zig` (GLM-4.6 client from Aurora)
- Phase 5: Implement actual AI analysis (replace placeholders with GLM-4.6 calls)
- Phase 5: Add visual indicators for AI-suggested connections
- Test thoroughly with UI and AI integration

**Can Work In Parallel With**: All agents (except when coordinating shared modules or Aurora's GLM-4.6 client)

### Grain Workspace Agent

**Current Priority**: Continue desktop apps
-   **Why**: Uses existing OS services, mostly independent
-   **Can Work In Parallel With**: Aurora, Skate, Bubble Phase 1

**Next Steps**:
1.  Continue desktop app development
2.  Integrate with OS system services
3.  Update documentation

### Grain Bubble Agent

**Current Priority**: Phase 4 Export Pipeline Core Complete ✅
-   **Status**: Phase 1 Core Canvas ✅, Phase 2 Component System ✅, Phase 4 Export Pipeline Core ✅
-   **Can Work In Parallel With**: Aurora, Skate, Workspace

**Next Steps**:
1.  Continue component system implementation
2.  Complete export pipeline optimization and preview
3.  Integrate with OS compositor
4.  Update documentation

---

## Standard Agent Prompt Template

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

**End of Coordination Plan**
