# Unified Agent Coordination: Holistic Development Strategy

**Date**: 2025-12-05-161256-pst  
**Status**: Master Coordination Document  
**Purpose**: Optimize parallel work, prevent race conditions, coordinate all 8 agents

---

## Executive Summary

This document provides a unified coordination strategy for all 8 Grain agents, optimizing parallelization while preventing conflicts. It includes dependency analysis, work sequencing, directory cleanup recommendations, and a unified prompt for all agents.

**Agents**:
1. **Grain Vantage Agent** (VM/Kernel)
2. **Grain Aurora Agent** (IDE/Browser)
3. **Grain Skate Agent** (Knowledge Graph)
4. **Grain Core Agent** (System Services)
5. **Grain Workspace Agent** (Desktop Apps)
6. **Grain Carry Agent** (Mobile Framework)
7. **Grain Silo Agent** (Database)
8. **Grain Bubble Agent** (Design Tool)

---

## Dependency Analysis

### Critical Path Dependencies

```
Vantage Agent (Kernel/VM)
    ↓
OS Agent (System Services)
    ↓
    ├─→ Silo Agent (Database) [needs: API Server, WebSocket]
    ├─→ Carry Agent (Mobile) [needs: API Server, Auth, WebSocket]
    ├─→ Workspace Agent (Desktop Apps) [needs: System Services]
    └─→ Bubble Agent (Design Tool) [needs: Compositor, Rendering]

Aurora Agent (IDE/Browser) [mostly independent]
Skate Agent (Knowledge Graph) [mostly independent]
```

### Dependency Matrix

| Agent | Depends On | Provides To | Can Work In Parallel With |
|-------|------------|-------------|--------------------------|
| **Vantage** | None | OS, All | Aurora, Skate, Workspace (partially) |
| **OS** | Vantage | Silo, Carry, Workspace, Bubble | Aurora, Skate |
| **Silo** | OS (API, WebSocket) | Carry | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Carry** | OS (API, Auth, WebSocket), Silo | None | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Aurora** | None (shared modules) | Shared modules | All (except when coordinating shared modules) |
| **Skate** | None (shared modules) | Shared modules | All (except when coordinating shared modules) |
| **Workspace** | OS (System Services) | None | Aurora, Skate, Bubble (Phase 1) |
| **Bubble** | OS (Compositor), Court, Silo | None | Aurora, Skate, Workspace (partially) |

---

## Parallelization Strategy

### Tier 1: Fully Independent (Can Work Simultaneously)

**Agents**: Aurora, Skate

**Work**:
- **Aurora**: Continue LSP features, editor enhancements, browser improvements
- **Skate**: Continue syntax highlighting, graph features, terminal improvements

**Coordination**: Only when working on shared modules (font renderer, text buffer, DAG)

### Tier 2: Infrastructure-Dependent (Sequential)

**Sequence**:
1. **Vantage Agent** → Network syscalls (needed by OS Phase 61)
2. **OS Agent** → WebSocket support (Phase 61) → Unblocks Silo & Carry
3. **Silo Agent** → WebSocket integration (after OS Phase 61)
4. **Carry Agent** → WebSocket client (after OS Phase 61)

**Parallel Opportunities**:
- While OS works on WebSocket, Silo can prepare integration code
- While OS works on WebSocket, Carry can prepare client code
- Silo and Carry can work in parallel once OS WebSocket is ready

### Tier 3: Application Layer (Mostly Independent)

**Agents**: Workspace, Bubble

**Work**:
- **Workspace**: Desktop apps (uses existing OS services)
- **Bubble**: Phase 1 core canvas (uses existing OS compositor)

**Coordination**: Minimal, both use OS services independently

---

## Recommended Work Order (Next 2-4 Weeks)

### Week 1: Foundation & Infrastructure

**Priority 1: OS Agent** (Blocks Others)
- **Phase 61**: WebSocket support (HIGH PRIORITY)
  - Unblocks Silo Agent (WebSocket connection management)
  - Unblocks Carry Agent (WebSocket client for livestream)
  - Estimated: 1-2 weeks

**Priority 2: Vantage Agent** (Enables OS)
- **Network Syscalls**: TCP/UDP syscalls for OS Phase 61
  - Enables OS to use kernel network syscalls instead of std.net
  - Estimated: 1 week

**Parallel Work**:
- **Aurora Agent**: Continue independent features (LSP, editor)
- **Skate Agent**: Continue independent features (syntax, graph)
- **Workspace Agent**: Continue desktop apps (independent)
- **Bubble Agent**: Start Phase 1 core canvas (uses existing OS)

### Week 2-3: Integration & Backend

**After OS WebSocket Complete**:

**Priority 1: Silo Agent** (Database)
- WebSocket integration with OS API server
- Database endpoint handlers (using OS API server)
- Estimated: 1 week

**Priority 2: Carry Agent** (Mobile)
- WebSocket client implementation
- Handler integration with OS API server
- End-to-end API testing
- Estimated: 1 week

**Parallel Work**:
- **Aurora Agent**: Continue independent work
- **Skate Agent**: Continue independent work
- **Workspace Agent**: Continue desktop apps
- **Bubble Agent**: Continue Phase 1 (core canvas)

### Week 4: Enhancement & Polish

**All Agents**:
- Integration testing
- Bug fixes
- Documentation updates
- Performance optimization

---

## Race Condition Prevention

### Shared Resources & Coordination Points

1. **Shared Modules** (`src/shared/`):
   - **Font Renderer**: ✅ Complete (Aurora, Skate, OS migrated)
   - **Text Buffer**: ⏳ Planned (Skate Phase 2)
   - **DAG Core**: ✅ Shared (Aurora, Skate use it)
   - **Coordination**: Agents must coordinate before modifying shared modules

2. **OS API Server** (`src/grain_core/api_server.zig`):
   - **Owner**: OS Agent
   - **Users**: Silo Agent, Carry Agent
   - **Coordination**: Silo and Carry register routes, don't modify core server

3. **Build System** (`build.zig`):
   - **Coordination**: Agents should coordinate before major build changes
   - **Current**: Modular structure in `build/` directory (good)

4. **Documentation** (`docs/plans/`, `docs/tasks/`):
   - **Coordination**: Update master `docs/plan.md` and `docs/tasks.md` after agent-specific updates

### Coordination Protocol

**Before Starting Work**:
1. Check `docs/plan.md` and `docs/tasks.md` for conflicts
2. Check agent-specific plans (`docs/plans/plan_{agent}.md`)
3. Check `docs/agent-communications/` for recent coordination
4. If modifying shared modules, check in with affected agents

**During Work**:
1. Update agent-specific plan/tasks files
2. Create coordination documents if affecting other agents
3. Update master `docs/plan.md` and `docs/tasks.md` when complete

**After Completing Work**:
1. Update documentation
2. Verify tests pass
3. Create coordination summary if needed
4. Update master documentation

---

## Directory Structure Recommendations

### Current Issues

1. **Documentation Root Clutter**: Many old prompt files, coordination docs in `docs/` root
2. **Old Backup Files**: `build.zig.backup`, `build.zig.old2` in root
3. **Legacy Files**: Old `zyx*` timestamped files in `docs/` root
4. **Empty/Unused Directories**: `src/grain_field/` (renamed to `grain_court/`)

### Recommended Cleanup

#### 1. Archive Old Documentation

**Move to `archaeology/docs/`**:
- `docs/*_agent_*_prompt.md` (old agent prompts, keep only current)
- `docs/zyx*.md` (old timestamped coordination docs)
- `docs/kernel_agent_*.md` (old kernel agent docs, now Vantage)
- `docs/grain_mobile_agent_prompt.md` (now Carry)
- `docs/grain_database_agent_prompt.md` (now Silo)
- `docs/mobile_agent_*.md` (old mobile docs)
- `docs/database_agent_*.md` (old database docs)

**Keep in `docs/`**:
- `docs/grain_style.md` (active style guide)
- `docs/plan.md`, `docs/tasks.md` (master summaries)
- `docs/plans/`, `docs/tasks/` (agent-specific plans/tasks)
- `docs/agent-communications/` (active coordination)
- `docs/proposals/` (active proposals)
- `docs/learning-course/` (active learning materials)

#### 2. Clean Up Root Directory

**Remove**:
- `build.zig.backup`
- `build.zig.old2`
- Any other `.backup` or `.old*` files

**Keep**:
- `build.zig` (active)
- `build/` (modular build system)

#### 3. Remove Empty/Unused Directories

**Check and Remove**:
- `src/grain_field/` (if empty, renamed to `grain_court/`)

#### 4. Organize Source Code

**Current Structure** (Good):
```
src/
├── grain_core/          # OS Agent
├── grain_aurora/      # Aurora Agent (via aurora_*.zig files)
├── grain_skate/       # Skate Agent
├── grain_workspace/   # Workspace Agent
├── grain_carry_core/  # Carry Agent (renamed from mobile)
├── grain_database/    # Silo Agent
├── grain_bubble/      # Bubble Agent
├── grain_court/       # Court (formerly Field, Skate Agent)
├── grain_silo/        # Silo storage (Skate Agent)
├── kernel/            # Vantage Agent
├── kernel_vm/         # Vantage Agent
└── shared/            # Shared modules
```

**Recommendation**: Keep current structure, it's well-organized.

---

## Unified Agent Prompt

**Copy-paste this to all agents**:

```
continue as you best recommend, remember to follow Grain Style (~/xy-mathematics/docs/grain_style.md ) with grain_case function names and all the strict rules with all compiler warnings turned on

Please review docs/agent-communications/unified_agent_coordination_prompt.md for holistic coordination strategy, dependency analysis, and parallelization opportunities.

Key coordination points:

1. **Check Dependencies**: Review what you need from other agents before starting work
2. **Coordinate Shared Modules**: Check in before modifying src/shared/ modules
3. **Update Documentation**: Update your docs/plans/plan_{agent}.md and docs/tasks/tasks_{agent}.md, then update master docs/plan.md and docs/tasks.md
4. **Create Coordination Docs**: If your work affects other agents, create docs in docs/agent-communications/
5. **Prevent Race Conditions**: Check docs/agent-communications/ for recent coordination before starting overlapping work

Current priorities (from unified coordination):
- OS Agent: Phase 61 WebSocket support (HIGH - unblocks Silo & Carry)
- Vantage Agent: Network syscalls (enables OS Phase 61)
- Silo Agent: Prepare WebSocket integration (after OS Phase 61)
- Carry Agent: Prepare WebSocket client (after OS Phase 61)
- Aurora/Skate: Continue independent work
- Workspace/Bubble: Continue independent work

When you're done update the docs/plans/plan_{agent}.md and docs/tasks/tasks_{agent}.md keeping the general summary docs/plan.md and docs/tasks.md in thinking. let me know when you need me to check in with the other agent to prevent conflicts. also make sure all existing and new tests pass that implement their API contracts, enforcing grainwrap-100 and grain validate-70 

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your printout summary header

your agent name is: [Your Agent Name]
```

---

## Agent-Specific Recommendations

### Grain Vantage Agent

**Current Priority**: Network syscalls (Phase 4)
- **Why**: Enables OS Agent Phase 61 to use kernel syscalls
- **Blocks**: OS Agent network stack enhancements
- **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1. Implement TCP/UDP syscalls (socket, bind, listen, accept, connect, send, recv)
2. Coordinate with OS Agent on syscall interface design
3. Update documentation

### Grain Core Agent

**Current Priority**: Phase 61 WebSocket support (HIGH)
- **Why**: Unblocks Silo Agent and Carry Agent
- **Blocks**: Silo WebSocket integration, Carry WebSocket client
- **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1. Implement WebSocket handshake (HTTP upgrade)
2. Implement WebSocket frame parsing/generation
3. Integrate with API server for WebSocket routes
4. Create tests
5. Update documentation

**After WebSocket**: DNS resolution (Phase 61), then File System Enhancements (Phase 62)

### Grain Silo Agent

**Current Priority**: Prepare for WebSocket integration
- **Why**: Waiting for OS Agent Phase 61 WebSocket support
- **Can Do Now**: Prepare integration code, test database endpoints
- **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1. Prepare WebSocket integration code (waiting for OS)
2. Test database endpoints with OS API server
3. Coordinate with OS Agent on WebSocket protocol
4. Update documentation

### Grain Carry Agent

**Current Priority**: Prepare for WebSocket client
- **Why**: Waiting for OS Agent Phase 61 WebSocket support
- **Can Do Now**: Prepare client code, test API endpoints
- **Can Work In Parallel With**: Aurora, Skate, Workspace, Bubble Phase 1

**Next Steps**:
1. Prepare WebSocket client code (waiting for OS)
2. Test API endpoints with OS API server
3. Coordinate with OS Agent on WebSocket protocol
4. Update documentation

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
1. Start Phase 1: Core canvas implementation
2. Use existing OS compositor and rendering modules
3. Coordinate with Court Agent for vector search (Phase 3)
4. Coordinate with Silo Agent for design asset storage (Phase 3)
5. Update documentation

---

## Directory Cleanup Plan

### Phase 1: Archive Old Documentation

**Move to `archaeology/docs/legacy_prompts/`**:
- All `*_agent_*_prompt.md` files (except current ones)
- All `zyx*.md` timestamped files
- Old coordination documents

**Action**: Create `archaeology/docs/legacy_prompts/` and move files

### Phase 2: Remove Backup Files

**Remove from root**:
- `build.zig.backup`
- `build.zig.old2`
- Any other `.backup` or `.old*` files

**Action**: Delete backup files (git history preserves them)

### Phase 3: Clean Empty Directories

**Check and Remove**:
- `src/grain_field/` (if empty, renamed to `grain_court/`)

**Action**: Verify and remove if empty

### Phase 4: Organize Agent Communications

**Current**: `docs/agent-communications/` (good structure)

**Recommendation**: Keep as-is, it's well-organized

---

## Repository Structure Recommendations

### Current Structure (Good)

```
xy-mathematics/
├── src/
│   ├── grain_core/          # OS Agent
│   ├── grain_aurora/       # Aurora (via aurora_*.zig)
│   ├── grain_skate/       # Skate Agent
│   ├── grain_workspace/   # Workspace Agent
│   ├── grain_carry_core/  # Carry Agent
│   ├── grain_database/    # Silo Agent
│   ├── grain_bubble/      # Bubble Agent
│   ├── grain_court/       # Court (Skate Agent)
│   ├── grain_silo/        # Silo storage (Skate Agent)
│   ├── kernel/            # Vantage Agent
│   ├── kernel_vm/         # Vantage Agent
│   └── shared/            # Shared modules
├── docs/
│   ├── plans/             # Agent-specific plans
│   ├── tasks/             # Agent-specific tasks
│   ├── agent-communications/  # Active coordination
│   ├── proposals/         # Active proposals
│   ├── learning-course/    # Learning materials
│   └── [active docs]      # Current documentation
├── archaeology/           # Archived documentation
├── build/                 # Modular build system
├── tests/                 # All tests
└── build.zig              # Main build file
```

### Recommended Improvements

1. **Consolidate Aurora Files**: Consider moving `aurora_*.zig` files into `src/grain_aurora/` subdirectory
2. **Organize Tests**: Tests are well-organized by number, keep as-is
3. **Archive Old Docs**: Move old prompts and coordination docs to `archaeology/`

---

## Success Metrics

### Coordination Success

- **No Race Conditions**: Agents coordinate before modifying shared resources
- **Parallel Work**: Maximum parallelization without conflicts
- **Clear Dependencies**: All agents understand what they need from others
- **Timely Integration**: Agents integrate smoothly when dependencies are ready

### Technical Success

- **All Tests Pass**: `grainwrap-100`, `grain validate-70`
- **Build Works**: All modules compile successfully
- **Documentation Updated**: Master and agent-specific docs stay in sync
- **Grain Style**: All code follows Grain Style guidelines

---

## Next Steps

1. **All Agents**: Review this coordination document
2. **OS Agent**: Prioritize Phase 61 WebSocket support
3. **Vantage Agent**: Prioritize network syscalls
4. **Silo & Carry Agents**: Prepare integration code (waiting for OS)
5. **Other Agents**: Continue independent work
6. **All Agents**: Follow coordination protocol before starting work

---

**End of Unified Coordination Document**

**Status**: Ready for distribution to all agents  
**Last Updated**: 2025-12-05-161256-pst

