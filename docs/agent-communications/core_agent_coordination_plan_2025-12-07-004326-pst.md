# Grain Core Agent Coordination Plan

**Date**: 2025-12-07-004326-pst
**Agent**: Grain Core Agent (Core Agentic-Prompt-Engineering Pilot Seat Driver)
**Status**: Phase 61 HTTP Client Complete ✅, Phase 62 File System Enhancements COMPLETE ✅

---

## Executive Summary

This coordination plan provides a unified strategy for all 8 Grain agents, optimizing parallelization while preventing conflicts. It includes dependency analysis, work sequencing, and agent-specific recommendations.

**Agents**:
1.  **Grain Core Agent** (System Services) - YOU
2.  **Grain Silo Agent** (Database)
3.  **Grain Vantage Agent** (VM/Kernel)
4.  **Grain Skate Agent** (Knowledge Graph)
5.  **Grain Bubble Agent** (Design Tool)
6.  **Grain Carry Agent** (Mobile Framework)
7.  **Grain Aurora Agent** (IDE/Browser)
8.  **Grain Workspace Agent** (Desktop Apps)

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
-   External API requests for agents (Carry, Silo, etc.)

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

## Critical Style Enforcement: u32/u64 (No usize)

**MANDATORY**: All agents must strictly follow Grain Style regarding explicit integer types.

**Reference**: [`docs/agent-communications/grain_style_u32_u64_enforcement_prompt.md`](grain_style_u32_u64_enforcement_prompt.md)

**Action Required**:
1.  Audit your module for `usize`/`isize` usage
2.  Replace with explicit types (`u32`/`u64`/`i32`/`i64`)
3.  Add `@intCast()` conversions with bounds checking
4.  Verify all tests use explicit types

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

### Dependency Matrix

| Agent       | Depends On                                     | Provides To                                   | Can Work In Parallel With                 |
|-------------|------------------------------------------------|-----------------------------------------------|-------------------------------------------|
| **Vantage** | macOS 26.1 Tahoe only                          | None (runs Basin, but not a dependency)       | All (separate host layer)                 |
| **Basin**   | None (pure RISC-V)                             | Core, All agents                              | None (foundation layer)                   |
| **Core**    | **Basin** (RISC-V kernel) ✅                   | Silo, Carry, Workspace, Bubble                | Aurora, Skate                             |
| **Silo**    | Core (API ✅, WebSocket ✅, File System ✅, HTTP Client ✅ COMPLETE) | Carry                                         | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Carry**   | Core (API ✅, Auth ✅, WebSocket ✅, HTTP Client ✅), Silo       | None                                          | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Aurora**  | None (shared modules)                          | Shared modules                                | All (except when coordinating shared modules) |
| **Skate**   | None (shared modules)                          | Shared modules                                | All (except when coordinating shared modules) |
| **Workspace** | Core (System Services ✅)                      | None                                          | Aurora, Skate, Bubble (Phase 1)           |
| **Bubble**  | Core (Compositor ✅, Rendering ✅)             | None                                          | Aurora, Skate, Workspace                  |

---

## Current Priorities & Next Steps for Each Agent

### Grain Core Agent

**Current Priority**: Phase 61 HTTP Client Complete ✅, Phase 62 Complete ✅

**Next Priority**: Coordinate with Silo Agent on Phase 61 & Phase 62 integration or move to next phase
-   **Silo Integration**: Coordinate on integrating all Phase 61 & Phase 62 enhancements
-   **Next Phase**: Review plan for Phase 63+ or other system enhancements
-   **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Recommendation**: Coordinate with Silo Agent to ensure Phase 61 & Phase 62 integration is smooth, then proceed with next priorities.

### Grain Silo Agent

**Current Priority**: Phase 7 Database Persistence Integration
-   **Why**: Now fully unblocked by Core Agent Phase 62 File System Enhancements (COMPLETE)
-   **Can Do Now**: Integrate all file system enhancements for complete database persistence
-   **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1.  Integrate file storage with database endpoints
2.  Integrate WAL manager for transaction logging
3.  Integrate index manager for efficient queries
4.  Integrate backup manager for data protection
5.  Test complete database persistence and recovery
6.  Update documentation

### Grain Carry Agent

**Current Priority**: WebSocket Client Implementation
-   **Why**: Now unblocked by Core Agent Phase 61 WebSocket support
-   **Can Do Now**: Implement WebSocket client for livestream coordination
-   **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1.  Implement WebSocket client in Grain Mobile Core
2.  Integrate with API endpoints
3.  Test WebSocket client connectivity
4.  Update documentation

### Grain Vantage Agent

**Current Priority**: Network Syscalls (Phase 4)
-   **Why**: Enables Core Agent network stack to use kernel syscalls
-   **Blocks**: Core Agent network stack enhancements (optional, can use mock)
-   **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1.  Implement TCP/UDP syscalls (socket, bind, listen, accept, connect, send, recv)
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

### Grain Skate Agent

**Current Priority**: Continue independent work
-   **Why**: Mostly independent, shared modules already coordinated
-   **Can Work In Parallel With**: All agents (except when coordinating shared modules)

**Next Steps**:
1.  Continue syntax highlighting improvements
2.  Continue graph features
3.  Continue terminal improvements
4.  Coordinate only when modifying shared modules

### Grain Workspace Agent

**Current Priority**: Continue desktop apps
-   **Why**: Uses existing OS services, mostly independent
-   **Can Work In Parallel With**: Aurora, Skate, Bubble Phase 1

**Next Steps**:
1.  Continue desktop app development
2.  Integrate with OS system services
3.  Update documentation

### Grain Bubble Agent

**Current Priority**: Phase 1 core canvas (SLC v1.0)
-   **Why**: Uses existing OS compositor, can start independently
-   **Can Work In Parallel With**: Aurora, Skate, Workspace

**Next Steps**:
1.  Implement core canvas rendering
2.  Integrate with OS compositor
3.  Update documentation

---

## Standard Agent Prompt Template

```
continue as you best recommend, remember to follow Grain Style (~/xy-mathematics/docs/grain_style.md ) with grain_case function names and all the strict rules with all compiler warnings turned on

continue the next phase of implementation and when you're done update the docs/plans/plan_core.md and docs/tasks/tasks_core.md keeping the general summary docs/plan.md and docs/tasks.md in thinking. let me know when you need me to check in with the other agents to prevent conflicts. also make sure all existing and new tests pass that implement their API contracts, enforcing grainwrap-100 and grain validate-70

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your printout summary header

when you're done, git push add all to main with Grain Style commit message when done with same timestamp ,  and create and print a new core agent coordination plan for all agents with the same timestamp in the filename

your agent name is: Grain Core Agent
```

---

## Grain Style Compliance: Explicit types (u32/u64, no usize) enforced.

