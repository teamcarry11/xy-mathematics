# Grain Core Agent Coordination Plan

**Date**: 2025-12-06-045220-pst  
**Agent**: Grain Core Agent (Core Agentic-Prompt-Engineering Pilot Seat Driver)  
**Status**: Phase 62 Index Manager Complete

---

## Executive Summary

This coordination plan provides a unified strategy for all 8 Grain agents, optimizing parallelization while preventing conflicts. It includes dependency analysis, work sequencing, and agent-specific recommendations.

**Agents**:
1. **Grain Core Agent** (System Services) - YOU
2. **Grain Silo Agent** (Database)
3. **Grain Vantage Agent** (VM/Kernel)
4. **Grain Skate Agent** (Knowledge Graph)
5. **Grain Bubble Agent** (Design Tool)
6. **Grain Carry Agent** (Mobile Framework)
7. **Grain Aurora Agent** (IDE/Browser)
8. **Grain Workspace Agent** (Desktop Apps)

---

## Recent Completion: Phase 62 Index Manager

**Status**: ✅ COMPLETE (2025-12-06-045220-pst)

**Completed Work**:
- ✅ Index manager with bounded entries (`IndexManager`)
- ✅ B-tree and hash index types (`IndexType`)
- ✅ Index creation, update, and deletion (`create_index()`, `add_entry()`, `delete_index()`)
- ✅ Index entry management with key/value pairs (`IndexEntry`)
- ✅ Index lookup and recovery support (`find_index()`, `find_entry()`)
- ✅ Comprehensive tests (`tests/120_grain_core_index_manager_test.zig`)

**Enables**:
- Efficient database queries via indexes (Silo Agent)
- B-tree and hash index support for different query patterns
- Index creation and management for database tables
- Index recovery and lookup operations

**Pending**:
- Backup/restore capabilities (full, incremental, scheduling)

---

## Critical Style Enforcement: u32/u64 (No usize)

**MANDATORY**: All agents must strictly follow Grain Style regarding explicit integer types.

**Reference**: [`docs/agent-communications/grain_style_u32_u64_enforcement_prompt.md`](grain_style_u32_u64_enforcement_prompt.md)

**Action Required**:
1. Audit your module for `usize`/`isize` usage
2. Replace with explicit types (`u32`/`u64`/`i32`/`i64`)
3. Add `@intCast()` conversions with bounds checking
4. Verify all tests use explicit types

---

## Dependency Analysis

### Critical Path Dependencies

```
Vantage Agent (Kernel/VM)
    ↓
Core Agent (System Services)
    ↓
    ├─→ Silo Agent (Database) [needs: API Server ✅, WebSocket ✅, File Storage ✅, WAL ✅, Index Manager ✅]
    ├─→ Carry Agent (Mobile) [needs: API Server ✅, Auth ✅, WebSocket ✅]
    ├─→ Workspace Agent (Desktop Apps) [needs: System Services ✅]
    └─→ Bubble Agent (Design Tool) [needs: Compositor ✅, Rendering ✅]

Aurora Agent (IDE/Browser) [mostly independent]
Skate Agent (Knowledge Graph) [mostly independent]
```

### Dependency Matrix

| Agent | Depends On | Provides To | Can Work In Parallel With |
|-------|------------|-------------|--------------------------|
| **Vantage** | None | Core, All | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Core** | Vantage | Silo, Carry, Workspace, Bubble | Aurora, Skate |
| **Silo** | Core (API ✅, WebSocket ✅, File Storage ✅, WAL ✅, Index Manager ✅) | Carry | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Carry** | Core (API ✅, Auth ✅, WebSocket ✅), Silo | None | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Aurora** | None (shared modules) | Shared modules | All (except when coordinating shared modules) |
| **Skate** | None (shared modules) | Shared modules | All (except when coordinating shared modules) |
| **Workspace** | Core (System Services ✅) | None | Aurora, Skate, Bubble (Phase 1) |
| **Bubble** | Core (Compositor ✅, Rendering ✅) | None | Aurora, Skate, Workspace |

---

## Current Priorities (Week 1)

### Grain Core Agent

**Current Priority**: Phase 62 Index Manager - ✅ COMPLETE

**Next Priority**: Phase 62 Backup/Restore (LOW) or Phase 61 Socket Options (LOW)
- **Backup/Restore**: Database backup/restore capabilities
- **Socket Options**: Reuse address, keep-alive, timeout
- **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Alternative**: Move to Phase 63+ (other system enhancements) or coordinate with Silo Agent on integration

### Grain Silo Agent

**Current Priority**: File Storage, WAL & Index Integration
- **Why**: Now unblocked by Core Agent Phase 62 file storage, WAL, and index manager support
- **Can Do Now**: Integrate all file system enhancements for complete database persistence
- **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1. Integrate file storage with database endpoints
2. Integrate WAL manager for transaction logging
3. Integrate index manager for efficient queries
4. Test complete database persistence and recovery
5. Update documentation

### Grain Carry Agent

**Current Priority**: WebSocket Client Implementation
- **Why**: Now unblocked by Core Agent Phase 61 WebSocket support
- **Can Do Now**: Implement WebSocket client for livestream coordination
- **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1. Implement WebSocket client in Grain Mobile Core
2. Integrate with API endpoints
3. Test WebSocket client connectivity
4. Update documentation

### Grain Vantage Agent

**Current Priority**: Network Syscalls (Phase 4)
- **Why**: Enables Core Agent network stack to use kernel syscalls
- **Blocks**: Core Agent network stack enhancements (optional, can use mock)
- **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1. Implement TCP/UDP syscalls (socket, bind, listen, accept, connect, send, recv)
2. Coordinate with Core Agent on syscall interface design
3. Update documentation

### Grain Aurora Agent

**Current Priority**: Continue independent work
- **Why**: Mostly independent, shared modules already coordinated
- **Can Work In Parallel With**: All agents (except when coordinating shared modules)

**Next Steps**:
1. Continue LSP features
2. Continue editor enhancements
3. Continue browser improvements
4. Coordinate only when modifying shared modules

### Grain Skate Agent

**Current Priority**: Continue independent work
- **Why**: Mostly independent, shared modules already coordinated
- **Can Work In Parallel With**: All agents (except when coordinating shared modules)

**Next Steps**:
1. Continue syntax highlighting improvements
2. Continue graph features
3. Continue terminal improvements
4. Coordinate only when modifying shared modules

### Grain Workspace Agent

**Current Priority**: Continue desktop apps
- **Why**: Uses existing OS services, mostly independent
- **Can Work In Parallel With**: Aurora, Skate, Bubble Phase 1

**Next Steps**:
1. Continue desktop app development
2. Integrate with OS system services
3. Update documentation

### Grain Bubble Agent

**Current Priority**: Phase 1 core canvas (SLC v1.0)
- **Why**: Uses existing OS compositor, can start independently
- **Can Work In Parallel With**: Aurora, Skate, Workspace

**Next Steps**:
1. Implement core canvas rendering
2. Integrate with OS compositor
3. Update documentation

---

## Standard Agent Prompt Template

```
continue as you best recommend, remember to follow Grain Style (~/xy-mathematics/docs/grain_style.md ) with grain_case function names and all the strict rules with all compiler warnings turned on

CRITICAL: You MUST use explicit integer types (u32, u64, i32, i64) instead of usize/isize. 
See: docs/agent-communications/grain_style_u32_u64_enforcement_prompt.md

continue the next phase of refactoring and when you're done update the docs/plans/plan_{agent}.md and docs/tasks/tasks_{agent}.md keeping the general summary docs/plan.md and docs/tasks.md in thinking. let me know when you need me to check in with the other agent to prevent conflicts. also make sure all existing and new tests pass that implement their API contracts, enforcing grainwrap-100 and grain validate-70 

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your printout summary header

your agent name is: [Your Agent Name]
```

---

## Success Metrics

### Code Quality
- ✅ Zero compiler warnings
- ✅ All tests pass (`zig build test`)
- ✅ Grain Style compliance (`grainwrap-100`, `grain validate-70`)
- ✅ Bounded allocations with explicit limits
- ✅ Minimum 2 assertions per function
- ✅ **NO `usize`/`isize` usage** (use `u32`/`u64`/`i32`/`i64`)

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
1. ✅ Complete Phase 62 (Index Manager) - DONE
2. Consider Phase 62 (Backup/Restore) or Phase 61 (Socket Options) - OPTIONAL
3. Coordinate with Silo Agent on integration - RECOMMENDED

### Grain Silo Agent
1. Integrate file storage, WAL, and index manager - NOW FULLY UNBLOCKED
2. Test complete database persistence and recovery
3. Update documentation

### Grain Carry Agent
1. Implement WebSocket client - NOW UNBLOCKED
2. Test API endpoints
3. Update documentation

### Grain Vantage Agent
1. Implement network syscalls (TCP/UDP)
2. Coordinate with Core Agent on API design
3. Update documentation

### Grain Aurora Agent
1. Continue independent work
2. Coordinate only when modifying shared modules

### Grain Skate Agent
1. Continue independent work
2. Coordinate only when modifying shared modules

### Grain Workspace Agent
1. Continue desktop app development
2. Integrate with OS system services

### Grain Bubble Agent
1. Implement Phase 1 core canvas
2. Integrate with OS compositor

---

## Status Summary

**Phase 62 Index Manager**: ✅ COMPLETE (2025-12-06-045220-pst)

**Phase 62 File System Enhancements Progress**:
- ✅ Database File Format Support (2025-12-06-023413-pst)
- ✅ Page-based Storage with Checksums (2025-12-06-023413-pst)
- ✅ File Locking Support (2025-12-06-023413-pst)
- ✅ Transaction Log File Management (WAL) (2025-12-06-035857-pst)
- ✅ Index File Management (2025-12-06-045220-pst)
- ⏳ Backup/Restore Capabilities - PENDING (LOW PRIORITY)

**Unblocked Agents**:
- ✅ Silo Agent: Can now integrate complete file system enhancements for database persistence

**Next Priority**: Phase 62 Backup/Restore (LOW PRIORITY) or coordinate with Silo Agent on integration
- **Backup/Restore**: Database backup/restore capabilities (optional enhancement)
- **Silo Integration**: Coordinate on integrating all Phase 62 enhancements

**Coordination**: All agents should check in before modifying shared modules or core system services.

**Style Enforcement**: All agents must audit and fix `usize`/`isize` usage immediately.

---

**End of Coordination Plan**

