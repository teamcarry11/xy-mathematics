# Grain Field → Grain Court Rename: All Agents Coordination

**Date**: 2025-12-05-144942-pst  
**To**: Grain Skate Agent, Grain Mobile Agent, Grain Aurora Agent, Grain Bubble Agent  
**From**: Project Coordination  
**Priority**: HIGH — Architecture clarification and rename

---

## Summary

We are renaming **Grain Field** to **Grain Court** to better represent the WSE-wafer-scale SRAM spatial computing abstraction for self-hostable LLM backend. This rename reflects the vision of Grain Court as scalable fast agentic compute with Cerebras GLM4.6 API as the starting target for WSE hardware.

**New Architecture**:
- **Grain Silo**: Scalable cheap storage (object storage, general-purpose database foundation)
- **Grain Court** (formerly Grain Field): Scalable fast agentic compute (WSE spatial computing, LLM backend)

---

## What's Changing

**Old Name**: Grain Field (`grain_field`)  
**New Name**: Grain Court (`grain_court`)  
**Inspiration**: Basketball courts (spatial, organized, fast-paced)

**Rationale**:
- Better represents spatial computing nature (organized space like a basketball court)
- More intuitive for WSE-wafer-scale SRAM abstraction
- Aligns with vision of fast agentic compute (fast-paced action)
- Target: Cerebras GLM4.6 API for WSE hardware

---

## Your Tasks

### For Grain Skate Agent (Primary Owner)

**You own**: `src/grain_field/` → `src/grain_court/`

**Tasks**:
1. Rename directory: `src/grain_field/` → `src/grain_court/`
2. Update module exports in `src/grain_court/root.zig`
3. Update all internal references in `src/grain_court/compute.zig`
4. Update `src/grain_skate/storage_integration.zig` (uses `grain_field`)
5. Update `src/grain_silo/storage.zig` comments (remove Grain Field, add Grain Court)
6. Update `build.zig` module references
7. Update test files if they reference `grain_field`
8. Update `docs/plans/plan_skate.md` and `docs/tasks/tasks_skate.md`
9. Update all documentation references

**Files to Check**:
- `src/grain_skate/storage_integration.zig`
- `src/grain_silo/storage.zig`
- All documentation files

### For Grain Mobile Agent

**Tasks**:
1. Search codebase for "Grain Field" or `grain_field` references
2. Update any documentation that mentions Grain Field
3. Update `docs/plans/plan_mobile.md` if it references Grain Field
4. Update `docs/tasks/tasks_mobile.md` if it references Grain Field

**Note**: Mobile Agent primarily uses Database Agent, so may have minimal references.

### For Grain Aurora Agent

**Tasks**:
1. Search codebase for "Grain Field" or `grain_field` references
2. Update any documentation that mentions Grain Field
3. Update `docs/plans/plan_aurora.md` if it references Grain Field
4. Update `docs/tasks/tasks_aurora.md` if it references Grain Field

**Note**: Aurora Agent may reference Grain Field for vector search or LLM integration.

### For Grain Bubble Agent

**Tasks**:
1. Search codebase for "Grain Field" or `grain_field` references
2. Update `docs/plans/plan_bubble.md` (mentions Grain Field for vector search)
3. Update `docs/tasks/tasks_bubble.md` if it references Grain Field
4. Update `docs/proposals/grain_bubble_proposal.md` (mentions Grain Field)

**Note**: Bubble Agent proposal mentions Grain Field for vector search and LLM integration.

---

## Architecture Clarification

### Grain Silo (Skate Agent)
- **Purpose**: Scalable cheap storage
- **Function**: Object storage, general-purpose database foundation
- **Use Cases**: Object storage (S3-compatible), database foundation, cold data storage

### Grain Court (formerly Grain Field) (Skate Agent)
- **Purpose**: Scalable fast agentic compute
- **Function**: WSE-wafer-scale SRAM spatial computing for self-hostable LLM backend
- **Target**: Cerebras GLM4.6 API for WSE hardware
- **Use Cases**: LLM inference, vector search, spatial computing, hot cache

### Grain Database Agent
- **Purpose**: General-purpose database
- **Function**: Hybrid database (key-value + relational + graph + full-text search)
- **Foundation**: Extends Grain Silo's object storage
- **Use Cases**: Mobile backend database, structured data, graph relationships

### Grain Mobile Agent
- **Purpose**: Mobile app backend
- **Function**: REST API endpoints, authentication, user management
- **Database**: Uses Grain Database Agent (decoupled via REST API)
- **Note**: Mobile Agent should use Database Agent's REST API, not directly access Grain Silo

---

## Code Changes Required

1. **Module Imports**:
   - `@import("grain_field")` → `@import("grain_court")`
   - `grain_field.Compute` → `grain_court.Compute`

2. **Comments and Documentation**:
   - "Grain Field" → "Grain Court"
   - Update descriptions to mention Cerebras GLM4.6 API target

3. **Build System**:
   - Update `build.zig` module references

---

## Testing Requirements

1. All existing tests must pass after rename
2. Update test imports to use `grain_court`
3. Verify no compilation errors
4. Run `zig build test --summary all`

---

## Documentation Updates

Update all references in:
- `docs/plan.md`
- `docs/tasks.md`
- Agent-specific plans and tasks files
- Any coordination documents

---

## Success Criteria

- ✅ All code compiles without errors
- ✅ All tests pass
- ✅ All references updated
- ✅ Documentation updated
- ✅ No broken references

---

**Status**: Ready for implementation  
**Coordination**: Skate Agent should go first since it owns the module. Other agents can work in parallel once Skate Agent completes the rename.

